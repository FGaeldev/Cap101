# fishing_panel.gd -- Chapter 4's fishing at the Bakhawan pier (storyboard 3.8).
#
# Driven by a dialogue line of type "minigame_trigger", minigame_type "fishing":
#   {
#     "type": "minigame_trigger", "minigame_type": "fishing",
#     "catch_pool": ["w091", "w355"],          # word ids the catch can be (required)
#     "catch_icons": {"w091": "fish", "w355": "crab"},  # picture per catch (data/bubble_icons.json)
#     "distractors": ["w350", "w349", "w238"], # wrong answers to choose from (required)
#     "casts": 3,                              # optional, default 3
#     "pass_count": 2,                         # optional: catches named right to pass, default 2
#     "success": 11, "failure": 14
#   }
#
# Each cast: wait for the bobber to dip, tap "Reel in" (or Space/Enter) before
# it gets away, then name the catch from three Akeanon words. Reeling in too
# early or too late loses that cast. Naming it right is +1 mastery for the word.
# No punishment either way (GDD 7): the line's "failure" branch just carries on.
#
# Ownership: renders and reports only. Emits `resolved(passed)`; DialogueUI
# forwards it to the owning DialogueComponent. Bad data never softlocks:
# reports and resolves as a pass.
extends PanelContainer

## Emitted once, after the end-of-game feedback hold.
signal resolved(passed: bool)

const DEFAULT_CASTS: int = 3
const DEFAULT_PASS_COUNT: int = 2
const CHOICE_COUNT: int = 3
## Seconds before a bite: random between these.
const BITE_MIN: float = 1.6
const BITE_MAX: float = 3.8
## Seconds the player has to reel in once the bobber dips.
const BITE_WINDOW: float = 1.4
## Seconds a cast's result shows before the next one.
const RESULT_HOLD: float = 1.4
const END_HOLD: float = 1.4
const BOB_HEIGHT: float = 3.0
const ICON_SCALE: float = 4.0
const WATER_COLOR := Color("4a90e0")
const WATER_DARK := Color("2c5ca8")
const BOBBER_COLOR := Color("e8473f")

enum Phase { IDLE, WAITING, BITE, NAMING, RESULT }

var _pool: Array = []
var _icons: Dictionary = {}
var _distractors: Array = []
var _casts: int = DEFAULT_CASTS
var _pass_count: int = DEFAULT_PASS_COUNT
var _cast_i: int = 0
var _named: int = 0
var _phase: int = Phase.IDLE
var _catch: String = ""
var _session: int = 0
var _bite_session: int = 0
var _t: float = 0.0

var _status: Label
var _hint: Label
var _water: ColorRect
var _bobber: Label
var _catch_icon: TextureRect
var _reel_btn: Button
var _choices: HBoxContainer

func _ready() -> void:
	# Same footprint as the dialogue box (bottom 45%), so the pier stays in view.
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 0.55
	anchor_bottom = 1.0
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UIThemeApplier.make_dialogue_style())
	_build_layout()
	HelpButton.pin(self, "fishing")
	visible = false
	set_process(false)

# --- public API ----------------------------------------------------------------

func open(line: Dictionary) -> void:
	_session += 1
	_pool = _valid_ids(line.get("catch_pool", []))
	_distractors = _valid_ids(line.get("distractors", [])).filter(func(id): return not _pool.has(id))
	_icons = line.get("catch_icons", {})
	if _pool.is_empty() or _distractors.size() < CHOICE_COUNT - 1:
		push_error("Fishing: needs a catch_pool and %d+ distractors, auto-passing." % (CHOICE_COUNT - 1))
		call_deferred("_emit_resolved", true)
		return
	_casts = maxi(int(line.get("casts", DEFAULT_CASTS)), 1)
	_pass_count = clampi(int(line.get("pass_count", DEFAULT_PASS_COUNT)), 1, _casts)
	_cast_i = 0
	_named = 0
	visible = true
	set_process(true)
	_start_cast()

func close() -> void:
	_session += 1
	_phase = Phase.IDLE
	set_process(false)
	visible = false

# --- flow ------------------------------------------------------------------------

func _start_cast() -> void:
	_cast_i += 1
	_catch = _pool[randi() % _pool.size()]
	_phase = Phase.WAITING
	_clear_choices()
	_catch_icon.visible = false
	_water.visible = true
	_bobber.text = "o"
	_bobber.add_theme_color_override("font_color", BOBBER_COLOR)
	_reel_btn.visible = true
	_reel_btn.disabled = false
	_reel_btn.grab_focus()
	_hint.text = "Wait for a bite, then reel in."
	_hint.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
	_refresh_status()
	_bite_session += 1
	var bite: int = _bite_session
	await get_tree().create_timer(randf_range(BITE_MIN, BITE_MAX)).timeout
	if bite != _bite_session or _phase != Phase.WAITING:
		return
	_phase = Phase.BITE
	_bobber.text = "!"
	_hint.text = "A bite! Reel in!"
	_hint.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	await get_tree().create_timer(BITE_WINDOW).timeout
	if bite != _bite_session or _phase != Phase.BITE:
		return
	_lose_cast("It got away.")

func _on_reel() -> void:
	match _phase:
		Phase.WAITING:
			_bite_session += 1
			_lose_cast("Too early. The fish swam off.")
		Phase.BITE:
			_bite_session += 1
			_show_catch()

func _show_catch() -> void:
	_phase = Phase.NAMING
	_reel_btn.visible = false
	_water.visible = false
	var tex: Texture2D = PictureBubbles.icon_texture(str(_icons.get(_catch, "")))
	_catch_icon.texture = tex
	_catch_icon.visible = tex != null
	_hint.text = "You caught something! What is it in Akeanon?"
	_hint.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	var options: Array = [_catch]
	var wrong: Array = _distractors.duplicate()
	wrong.shuffle()
	options.append_array(wrong.slice(0, CHOICE_COUNT - 1))
	options.shuffle()
	for id: String in options:
		var btn := Button.new()
		btn.text = str(WordBank.get_word(id).get("akeanon", "?"))
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UIThemeApplier.apply_button_theme(btn, "primary")
		btn.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_M)
		btn.pressed.connect(_on_choice.bind(id))
		_choices.add_child(btn)
	(_choices.get_child(0) as Button).grab_focus()

func _on_choice(id: String) -> void:
	if _phase != Phase.NAMING:
		return
	_phase = Phase.RESULT
	var right: bool = id == _catch
	var word: String = str(WordBank.get_word(_catch).get("akeanon", ""))
	var gloss: String = str(WordBank.get_word(_catch).get("gloss", ""))
	for btn: Button in _choices.get_children():
		btn.disabled = true
	GameState.expose_word(_catch)
	if right:
		GameState.adjust_mastery(_catch, 1)
		_named += 1
		_hint.text = "Insakto! %s, %s." % [word.capitalize(), gloss]
		_hint.add_theme_color_override("font_color", UIThemeApplier.COLOR_SUCCESS)
	else:
		_hint.text = "Not quite. It's %s, %s." % [word, gloss]
		_hint.add_theme_color_override("font_color", UIThemeApplier.COLOR_ERROR)
	_refresh_status()
	_after_cast()

func _lose_cast(message: String) -> void:
	_phase = Phase.RESULT
	_reel_btn.disabled = true
	_bobber.text = "o"
	_hint.text = message
	_hint.add_theme_color_override("font_color", UIThemeApplier.COLOR_ERROR)
	_after_cast()

func _after_cast() -> void:
	var session: int = _session
	await get_tree().create_timer(RESULT_HOLD).timeout
	if session != _session:
		return
	if _cast_i < _casts:
		_start_cast()
		return
	var passed: bool = _named >= _pass_count
	_phase = Phase.IDLE
	set_process(false)
	_clear_choices()
	_catch_icon.visible = false
	_reel_btn.visible = false
	_hint.text = "Good fishing!" if passed else "The fish won this time."
	_hint.add_theme_color_override("font_color", UIThemeApplier.COLOR_SUCCESS if passed else UIThemeApplier.COLOR_ERROR)
	await get_tree().create_timer(END_HOLD).timeout
	if session != _session:
		return
	_emit_resolved(passed)

func _emit_resolved(passed: bool) -> void:
	resolved.emit(passed)

# --- input and animation -----------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if (_phase == Phase.WAITING or _phase == Phase.BITE) \
			and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		_on_reel()
		get_viewport().set_input_as_handled()
	elif _phase == Phase.NAMING and event.keycode >= KEY_1 and event.keycode < KEY_1 + _choices.get_child_count():
		(_choices.get_child(event.keycode - KEY_1) as Button).pressed.emit()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	_t += delta
	if _bobber == null:
		return
	var dip: float = 6.0 if _phase == Phase.BITE else 0.0
	_bobber.position.x = _water.size.x * 0.5 - _bobber.size.x * 0.5
	_bobber.position.y =_water.size.y * 0.5 - _bobber.size.y * 0.5 + sin(_t * 4.0) * BOB_HEIGHT + dip

# --- setup -----------------------------------------------------------------------

func _valid_ids(raw_ids: Array) -> Array:
	var out: Array = []
	for raw in raw_ids:
		var id: String = str(raw).strip_edges()
		if id.is_empty() or out.has(id):
			continue
		if WordBank.get_word(id).is_empty():
			push_warning("Fishing: unknown word id '%s' dropped." % id)
			continue
		out.append(id)
	return out

func _clear_choices() -> void:
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()

func _refresh_status() -> void:
	_status.text = "Cast %d of %d   ·   Named %d (need %d)" % [_cast_i, _casts, _named, _pass_count]

func _build_layout() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 4)
	add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
	_status.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	vbox.add_child(_status)

	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_M)
	vbox.add_child(_hint)

	var stage := Control.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(stage)

	_water = ColorRect.new()
	_water.color = WATER_COLOR
	_water.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.add_child(_water)
	var ripple := ColorRect.new()
	ripple.color = WATER_DARK
	ripple.anchor_left = 0.0
	ripple.anchor_right = 1.0
	ripple.anchor_top = 0.75
	ripple.anchor_bottom = 1.0
	_water.add_child(ripple)
	_bobber = Label.new()
	_bobber.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_XXL)
	_bobber.anchor_left = 0.5
	_bobber.anchor_right = 0.5
	_bobber.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_water.add_child(_bobber)

	_catch_icon = TextureRect.new()
	_catch_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_catch_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_catch_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_catch_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	_catch_icon.custom_minimum_size = Vector2(16, 16) * ICON_SCALE
	_catch_icon.visible = false
	stage.add_child(_catch_icon)

	_reel_btn = Button.new()
	_reel_btn.text = "Reel in!"
	UIThemeApplier.apply_button_theme(_reel_btn, "primary")
	_reel_btn.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_M)
	_reel_btn.pressed.connect(_on_reel)
	vbox.add_child(_reel_btn)

	_choices = HBoxContainer.new()
	_choices.add_theme_constant_override("separation", 4)
	vbox.add_child(_choices)
