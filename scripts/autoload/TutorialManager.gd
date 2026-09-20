# TutorialManager.gd — data-driven, event-driven in-game tutorial prompts.
#
# Design:
#   - Tutorials live in JSON (TUTORIAL_DATA_PATH). Path is a hardcoded const:
#     DirAccess scanning silently fails on exported Android PCK (TDD §9 item 1).
#   - A tutorial = ordered steps. Each step waits for ONE named event, delivered
#     via notify(event_id). Systems fire events; this manager never reaches into
#     scene nodes (register-on-ready, call-through-autoload, TDD §2).
#   - Completion persists as a GameState flag ("tutorial_<id>_done"). Flags are
#     already in the save contract, so no save schema change.
#   - Overlay never blocks input (mouse_filter = IGNORE on every control).
#   - Overlay layer sits BELOW BookUI/ScreenFade (both layer 100) so it hides
#     naturally when the Book is open.
#
# Usage:
#   TutorialManager.start("ch1_basics")                    # no-op if done/running
#   TutorialManager.notify("player_moved")                 # from any system
#   TutorialManager.register_target("interact_button", b)  # optional highlight
extends CanvasLayer

signal tutorial_started(tutorial_id: String)
signal step_changed(tutorial_id: String, step_index: int)
signal tutorial_completed(tutorial_id: String)

## Hardcoded on purpose (Android PCK). Add new data files here by hand.
const TUTORIAL_DATA_PATH: String = "res://data/tutorials/tutorials.json"
const FLAG_PREFIX: String = "tutorial_"
const FLAG_SUFFIX: String = "_done"
## Below BookUI (100) and ScreenFade (100).
const OVERLAY_LAYER: int = 90
## Seconds per half-cycle (dim -> bright). Full flash = 2x. Raise to slow down.
const PULSE_TIME: float = 1.0
## Brightening pulse. Deliberately NOT a new palette color (UI Style Guide §2:
## no new colors without updating the constant list) — just a modulate lift.
const HIGHLIGHT_MODULATE: Color = Color(1.6, 1.5, 1.0)
## Peak scale of the "breathe" (expand/contract), synced to the flash: expands
## while brightening, contracts while dimming. 1.0 = no size change.
const HIGHLIGHT_SCALE: float = 1.1

## tutorial_id -> { "steps": Array }
var _tutorials: Dictionary = {}
## target_id -> CanvasItem available for highlight
var _targets: Dictionary = {}

var _active_id: String = ""
var _step_index: int = -1
## notify() hits still required for the current step (step "count").
var _remaining: int = 0

var _panel: PanelContainer
var _label: Label
var _pulse_tween: Tween
var _highlighted: CanvasItem
## Original scale/pivot of the highlighted node, restored on clear so the
## breathe never leaves a HUD control permanently resized or off-pivot.
var _highlight_base_scale: Vector2 = Vector2.ONE
var _highlight_base_pivot: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Keep running while tree is paused (BookUI pauses the game on open).
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = OVERLAY_LAYER
	_load_data()
	_build_overlay()
	_panel.hide()


# ── Public API ──────────────────────────────────────────────────────────────

## Starts a tutorial. Idempotent: no-op if already done, another is running,
## or id is unknown. Skipped entirely in dev mode.
func start(tutorial_id: String) -> void:
	if GameState.dev_mode or is_done(tutorial_id) or _active_id != "":
		return
	if not _tutorials.has(tutorial_id):
		push_warning("TutorialManager: unknown tutorial '%s'" % tutorial_id)
		return
	_active_id = tutorial_id
	tutorial_started.emit(tutorial_id)
	_go_to_step(0)


## True if tutorial was completed (or skipped) in this save.
func is_done(tutorial_id: String) -> bool:
	return GameState.get_flag(FLAG_PREFIX + tutorial_id + FLAG_SUFFIX)


func is_running() -> bool:
	return _active_id != ""


## Any system reports that something happened. Cheap and safe to call every
## physics tick or with no tutorial running: unmatched events are ignored.
func notify(event_id: String) -> void:
	if _active_id == "":
		return
	if _current_step().get("event", "") != event_id:
		return
	_remaining -= 1
	if _remaining <= 0:
		_go_to_step(_step_index + 1)


## Registers a node the manager may pulse when a step's "highlight" key matches
## target_id. Call from the owning scene's _ready().
func register_target(target_id: String, node: CanvasItem) -> void:
	_targets[target_id] = node


## Marks the active tutorial done without playing remaining steps.
func skip() -> void:
	if _active_id != "":
		_finish()


## Hides overlay and drops active state WITHOUT marking done. Call on every
## "leave the game" path (BookUI return-to-menu) so the tutorial resumes next
## session instead of leaving _active_id stuck.
func abort() -> void:
	_clear_highlight()
	_panel.hide()
	_active_id = ""
	_step_index = -1


# ── Internals ───────────────────────────────────────────────────────────────

func _current_step() -> Dictionary:
	var steps: Array = _tutorials[_active_id].get("steps", [])
	if _step_index < 0 or _step_index >= steps.size():
		return {}
	return steps[_step_index]


func _go_to_step(index: int) -> void:
	_clear_highlight()
	var steps: Array = _tutorials[_active_id].get("steps", [])
	if index >= steps.size():
		_finish()
		return
	_step_index = index
	var step: Dictionary = steps[index]
	_remaining = maxi(1, int(step.get("count", 1)))
	_label.text = str(step.get("text", ""))
	_panel.show()
	_apply_highlight(str(step.get("highlight", "")))
	step_changed.emit(_active_id, _step_index)


func _finish() -> void:
	var done_id: String = _active_id
	GameState.set_flag(FLAG_PREFIX + done_id + FLAG_SUFFIX, true)
	abort()
	GameState.save_game()
	tutorial_completed.emit(done_id)


func _apply_highlight(target_id: String) -> void:
	if target_id == "" or not _targets.has(target_id):
		return
	var node: CanvasItem = _targets[target_id]
	# Target may have been freed on scene change.
	if not is_instance_valid(node):
		_targets.erase(target_id)
		return
	_highlighted = node
	_highlight_base_scale = node.get("scale")
	# Controls scale around pivot_offset (top-left by default) -> center it so
	# the node breathes in place instead of drifting toward a corner.
	if node is Control:
		_highlight_base_pivot = node.pivot_offset
		node.pivot_offset = node.size / 2.0
	var peak: Vector2 = _highlight_base_scale * HIGHLIGHT_SCALE
	# Sine easing = soft breathing instead of a linear blink. Flash and scale
	# tweeners are chained with .parallel() so both share the same half-cycle.
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(node, "self_modulate", HIGHLIGHT_MODULATE, PULSE_TIME)
	_pulse_tween.parallel().tween_property(node, "scale", peak, PULSE_TIME)
	_pulse_tween.tween_property(node, "self_modulate", Color.WHITE, PULSE_TIME)
	_pulse_tween.parallel().tween_property(node, "scale", _highlight_base_scale, PULSE_TIME)


func _clear_highlight() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
	if is_instance_valid(_highlighted):
		_highlighted.self_modulate = Color.WHITE
		_highlighted.set("scale", _highlight_base_scale)
		if _highlighted is Control:
			_highlighted.pivot_offset = _highlight_base_pivot
	_highlighted = null


func _load_data() -> void:
	var file: FileAccess = FileAccess.open(TUTORIAL_DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("TutorialManager: cannot open %s" % TUTORIAL_DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_tutorials = parsed
	else:
		push_error("TutorialManager: bad JSON in %s" % TUTORIAL_DATA_PATH)


func _build_overlay() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", UIThemeApplier.make_panel_style(8))
	# Top-center; keeps clear of bottom dialogue box + joystick.
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.position.y = 8

	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_M)
	_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
	_panel.add_child(_label)
	add_child(_panel)
