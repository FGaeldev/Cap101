# plaza_directions_panel.gd -- "Help with directions" in Pastrana Park
# (docs/MINIGAMES_PLAN.md). A miniature of the live map; the visitor's figure
# walks it non-stop, one tile at a time, and the player steers with Akeanon
# words until it reaches the place it asked for.
#
# Driven by a line of minigame_type "plaza_directions" (PlazaGame builds it):
#   { "minigame_type": "plaza_directions",
#     "level": <the level Node2D>, "start": Vector2 (visitor's world position),
#     "rounds": [{"place": <places.json entry>, "warp": <Comp_Warp>}, ...] }
# Writes line["helped"] (visitors who arrived) before resolving, for the pay.
#
# Steering (decided 2026-11-22): Abante (go / keep going), Atras (turn back),
# liko pa waea (turn left), liko pa tuo (turn right); left and right are from
# the walker's own heading. The walker waits for the first word.
# Misses: out a wrong exit = that visitor is lost. A wall just stops them
# until the next word (v1.1.9; it used to lose them too).
#
# Ownership: renders and reports only. Bad data never softlocks: resolves as a pass.
extends PanelContainer

signal resolved(passed: bool)

const Directions := preload("res://scripts/util/directions.gd")
const ActorPath := preload("res://scripts/util/actor_path.gd")

const TILE: int = 16
## Seconds per tile. Slow enough to read the map and turn in time (0.3 until
## v1.1.9: testers found it too hard).
const STEP_TIME: float = 0.5
const NEXT_HOLD: float = 1.6
const END_HOLD: float = 2.0
## Map layers copied into the miniature (Roof is left out so streets show).
const MAP_LAYERS: Array[String] = ["Floor", "FloorDecals", "Shadows", "Walls", "Objects", "Edge"]
const CELLS_PER_FRAME: int = 1500
const BUTTONS: Array = [
	{"text": "Abante", "hint": "go", "word_ids": ["w371"], "turn": "go"},
	{"text": "Atras", "hint": "turn back", "word_ids": ["w336"], "turn": "back"},
	{"text": "liko pa waea", "hint": "turn left", "word_ids": ["w273", "w275"], "turn": "left"},
	{"text": "liko pa tuo", "hint": "turn right", "word_ids": ["w273", "w274"], "turn": "right"},
]

## Solid tiles per level path, built once (the map doesn't change).
static var _solid_cache: Dictionary = {}

## Draws the walker, its trail and the goal over the miniature, in world px.
class Overlay extends Node2D:
	var goal: Rect2 = Rect2()
	var walker: Vector2 = Vector2.ZERO     # world px, tile centre
	var heading: Vector2i = Vector2i.UP
	var trail: PackedVector2Array = []
	var lost: bool = false

	func _draw() -> void:
		if goal.size != Vector2.ZERO:
			draw_rect(goal.grow(24), Color(UIThemeApplier.COLOR_SUCCESS, 0.35))
			draw_rect(goal.grow(24), UIThemeApplier.COLOR_SUCCESS, false, 10.0)
		if trail.size() > 1:
			draw_polyline(trail, Color(UIThemeApplier.TEXT_EMPHASIS, 0.6), 8.0)
		var c: Color = UIThemeApplier.COLOR_ERROR if lost else UIThemeApplier.TEXT_EMPHASIS
		draw_circle(walker, 26.0, Color.WHITE)
		draw_circle(walker, 20.0, c)
		var tip: Vector2 = walker + Vector2(heading) * 44.0
		var side: Vector2 = Vector2(-heading.y, heading.x) * 16.0
		draw_colored_polygon(PackedVector2Array([tip, walker + Vector2(heading) * 22.0 + side,
				walker + Vector2(heading) * 22.0 - side]), c)
		if not lost:
			_draw_side_hints()

	## "L" and "R" beside the walker, on its own left and right (the way liko pa
	## waea / liko pa tuo turn it), so turning doesn't depend on screen sides.
	func _draw_side_hints() -> void:
		var left := Vector2(heading.y, -heading.x)   # same turn as _on_word's "left"
		var font: Font = ThemeDB.fallback_font
		for pair: Array in [[left, "L"], [-left, "R"]]:
			var dir: Vector2 = pair[0]
			var at: Vector2 = walker + dir * 54.0
			var perp: Vector2 = Vector2(-dir.y, dir.x) * 16.0
			draw_colored_polygon(PackedVector2Array([at + dir * 26.0, at + perp, at - perp]),
					Color(UIThemeApplier.TEXT_EMPHASIS, 0.55))
			var text_at: Vector2 = walker + dir * 118.0 + Vector2(-22.0, 26.0)
			draw_string_outline(font, text_at, pair[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 72, 18, Color.WHITE)
			draw_string(font, text_at, pair[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 72, UIThemeApplier.TEXT_EMPHASIS)

var _line: Dictionary = {}
var _level: Node2D
var _rounds: Array = []
var _round: int = 0
var _helped: int = 0
var _solid: Dictionary = {}       # Vector2i tile -> true
var _bounds: Rect2i
var _exits: Dictionary = {}       # Vector2i tile -> warp
var _goal_warp: Node = null
var _pos: Vector2i = Vector2i.ZERO
var _start: Vector2i = Vector2i.ZERO
var _heading: Vector2i = Vector2i.UP
var _walking: bool = false
var _step_left: float = 0.0
var _locked: bool = true
var _session: int = 0

var _map_box: SubViewportContainer
var _viewport: SubViewport
var _world: Node2D
var _overlay: Overlay
var _status: Label
var _text: RichTextLabel
var _hint: Label
var _buttons: GridContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UIThemeApplier.make_puzzle_panel_style(10))
	_build_layout()
	visible = false
	set_process(false)

# --- public API ----------------------------------------------------------------

func open(line: Dictionary) -> void:
	_session += 1
	_line = line
	_level = line.get("level") as Node2D
	_rounds = Array(line.get("rounds", []))
	if _level == null or _rounds.is_empty():
		push_error("PlazaDirections: no level or no places, auto-passing.")
		line["helped"] = 0
		call_deferred("_emit_resolved", true)
		return
	_helped = 0
	_round = 0
	visible = true
	_status.text = ""
	_text.text = "Loading the map..."
	_hint.text = ""
	_set_buttons_enabled(false)
	var session: int = _session
	await _prepare_map()
	if session != _session:
		return
	var start: Vector2 = line.get("start", Vector2.ZERO)
	_start = _tile_of(start)
	_start_round()

func close() -> void:
	_session += 1
	_locked = true
	_walking = false
	set_process(false)
	visible = false
	if _world != null:
		for child in _world.get_children():
			child.queue_free()

## Autoplay/test hook: the walker's tile, heading, goal tiles and solid tiles.
func state() -> Dictionary:
	var goal: Array = []
	for t: Vector2i in _exits:
		if _exits[t] == _goal_warp:
			goal.append(t)
	return {"pos": _pos, "heading": _heading, "walking": _walking, "goal": goal,
			"solid": _solid, "exits": _exits, "bounds": _bounds}

# --- layout ----------------------------------------------------------------------

func _build_layout() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	add_child(margin)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	margin.add_child(hbox)

	_map_box = SubViewportContainer.new()
	_map_box.stretch = true
	_map_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_map_box)
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_map_box.add_child(_viewport)

	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 6)
	hbox.add_child(side)

	var title := Label.new()
	title.text = "Help with directions"
	title.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_M)
	title.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var header := HBoxContainer.new()
	header.add_child(title)
	header.add_child(HelpButton.new("plaza_directions"))
	side.add_child(header)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_XS)
	_status.add_theme_color_override("font_color", UIThemeApplier.TEXT_DISABLED)
	side.add_child(_status)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_size_override("normal_font_size", UIThemeApplier.FONT_SIZE_M)
	_text.add_theme_color_override("default_color", UIThemeApplier.TEXT_DEFAULT)
	side.add_child(_text)
	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_XS)
	_hint.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
	side.add_child(_hint)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(spacer)

	_buttons = GridContainer.new()
	_buttons.columns = 2
	_buttons.add_theme_constant_override("h_separation", 6)
	_buttons.add_theme_constant_override("v_separation", 6)
	side.add_child(_buttons)
	for spec: Dictionary in BUTTONS:
		var b := Button.new()
		# v1.1.9: the English under each word, so the game is about steering.
		b.text = "%s\n(%s)" % [spec["text"], spec["hint"]]
		b.custom_minimum_size = Vector2(0, 40)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UIThemeApplier.apply_button_theme(b, "secondary")
		b.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
		b.pressed.connect(_on_word.bind(spec))
		_buttons.add_child(b)

func _set_buttons_enabled(on: bool) -> void:
	for b in _buttons.get_children():
		(b as Button).disabled = not on

# --- map -------------------------------------------------------------------------

## Copies the level's tile layers into the miniature and reads which tiles are
## solid and which are exits (warps).
func _prepare_map() -> void:
	for child in _viewport.get_children():
		child.queue_free()
	_world = Node2D.new()
	_viewport.add_child(_world)
	var floor: TileMapLayer = _level.get_node_or_null("Floor")
	_bounds = floor.get_used_rect() if floor != null else Rect2i(0, 0, 64, 64)
	for layer_name in MAP_LAYERS:
		var layer: TileMapLayer = _level.get_node_or_null(layer_name)
		if layer == null:
			continue
		var copy := TileMapLayer.new()
		copy.tile_set = layer.tile_set
		copy.tile_map_data = layer.tile_map_data
		copy.z_index = layer.z_index
		copy.material = layer.material
		_world.add_child(copy)
	_overlay = Overlay.new()
	_overlay.z_index = 50
	_world.add_child(_overlay)
	_fit_map()

	_exits.clear()
	for warp in Directions._warps(_level):
		var cs := warp.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if cs == null or not cs.shape is RectangleShape2D:
			continue
		var size: Vector2 = (cs.shape as RectangleShape2D).size * cs.global_scale
		var r := Rect2(cs.global_position - _level.global_position - size / 2.0, size)
		for ty in range(floori(r.position.y / TILE), ceili(r.end.y / TILE)):
			for tx in range(floori(r.position.x / TILE), ceili(r.end.x / TILE)):
				_exits[Vector2i(tx, ty)] = warp

	var key: String = str(_level.scene_file_path)
	if _solid_cache.has(key):
		_solid = _solid_cache[key]
		return
	_solid = {}
	var probe: Node2D = get_tree().get_first_node_in_group("player")
	if probe == null:
		probe = _level
	var checked: int = 0
	for ty in range(_bounds.position.y, _bounds.end.y):
		for tx in range(_bounds.position.x, _bounds.end.x):
			var corner := _level.global_position + Vector2(tx * TILE, (ty + 1) * TILE)
			if ActorPath._is_solid(probe, corner):
				_solid[Vector2i(tx, ty)] = true
			checked += 1
			if checked % CELLS_PER_FRAME == 0:
				await get_tree().physics_frame
				if not visible:
					return
	_solid_cache[key] = _solid

## Scales the miniature to fill the map box's height.
func _fit_map() -> void:
	var view_h: float = maxf(get_viewport_rect().size.y - 24.0, 120.0)
	var world_size := Vector2(_bounds.size * TILE)
	var s: float = view_h / world_size.y
	# The container stretches the viewport to this size itself (stretch = true);
	# setting _viewport.size too only drew an engine warning.
	_map_box.custom_minimum_size = Vector2(world_size.x * s, view_h)
	_world.scale = Vector2(s, s)
	_world.position = -Vector2(_bounds.position * TILE) * s

# --- rounds ----------------------------------------------------------------------

func _start_round() -> void:
	if _round >= _rounds.size():
		_end_game()
		return
	var entry: Dictionary = _rounds[_round]
	_goal_warp = entry["warp"]
	var plaza: Dictionary = (entry["place"] as Dictionary).get("plaza", {})
	var ask: Dictionary = Economy.line("plaza_ask")
	var text: String = str(ask["text"]).replace("{place}", str(plaza.get("text", "")))
	_text.text = "%s: %s" % [TextUtil.resolve_speaker("Visitor"), TextUtil.resolve_rich(text)]
	Economy.expose_line_words({"word_ids": Array(ask["word_ids"]) + Array(plaza.get("word_ids", []))})
	_hint.text = "Steer them to the green spot. Tap Abante to start."
	_pos = _start
	_heading = Vector2i.UP
	_walking = false
	_overlay.lost = false
	_overlay.trail = PackedVector2Array([_centre(_pos)])
	var goal := Rect2()
	for t: Vector2i in _exits:
		if _exits[t] == _goal_warp:
			var r := Rect2(Vector2(t * TILE), Vector2(TILE, TILE))
			goal = r if goal.size == Vector2.ZERO else goal.merge(r)
	_overlay.goal = goal
	_refresh_status()
	_redraw()
	_locked = false
	_set_buttons_enabled(true)

func _on_word(spec: Dictionary) -> void:
	if _locked:
		return
	AudioManager.play_sfx("menu_click")
	Economy.expose_line_words({"word_ids": spec["word_ids"]})
	match str(spec["turn"]):
		"back":
			_heading = -_heading
		"left":
			_heading = Vector2i(_heading.y, -_heading.x)
		"right":
			_heading = Vector2i(-_heading.y, _heading.x)
	if not _walking:
		_walking = true
		_step_left = STEP_TIME
		_hint.text = "Keep them off the walls. Turns are from the way they face."
		set_process(true)
	_redraw()

func _process(delta: float) -> void:
	if not _walking:
		return
	_step_left -= delta
	if _step_left > 0.0:
		return
	_step_left += STEP_TIME
	_step()

func _step() -> void:
	var next: Vector2i = _pos + _heading
	if _exits.has(next):
		_pos = next
		_trail_to(next)
		if _exits[next] == _goal_warp:
			_arrive()
		else:
			_lose("That's not the place. The visitor wanders off, lost.")
		return
	if _solid.has(next) or not _bounds.has_point(next):
		# v1.1.9 (too hard): a wall stops them instead of losing them. They wait
		# for the next word, like at the start.
		_walking = false
		set_process(false)
		AudioManager.play_sfx("menu_click")
		_hint.text = "Bump! They stopped at a wall. Pick a new way to go."
		_redraw()
		return
	_pos = next
	_trail_to(next)

func _arrive() -> void:
	_stop_walking()
	_helped += 1
	var thanks: Dictionary = Economy.line("plaza_thanks")
	_text.text = "%s: %s" % [TextUtil.resolve_speaker("Visitor"), TextUtil.resolve_rich(str(thanks["text"]))]
	Economy.expose_line_words(thanks)
	_hint.text = "They made it!"
	for spec: Dictionary in BUTTONS:
		for wid in spec["word_ids"]:
			GameState.adjust_mastery(str(wid), 1)
	_next_round()

func _lose(message: String) -> void:
	_stop_walking()
	_overlay.lost = true
	_redraw()
	AudioManager.play_sfx("menu_click")
	_text.text = message
	_hint.text = ""
	_next_round()

func _stop_walking() -> void:
	_walking = false
	_locked = true
	set_process(false)
	_set_buttons_enabled(false)

func _next_round() -> void:
	_round += 1
	_refresh_status()
	var session: int = _session
	await get_tree().create_timer(NEXT_HOLD).timeout
	if session != _session:
		return
	_start_round()

func _end_game() -> void:
	_locked = true
	_set_buttons_enabled(false)
	_overlay.goal = Rect2()
	_redraw()
	var all: bool = _helped == _rounds.size()
	_text.text = "You helped %d of %d visitors." % [_helped, _rounds.size()]
	_hint.text = "All of them! That's a bonus." if all else ""
	_line["helped"] = _helped
	var session: int = _session
	await get_tree().create_timer(END_HOLD).timeout
	if session != _session:
		return
	_emit_resolved(_helped > 0)

func _emit_resolved(passed: bool) -> void:
	resolved.emit(passed)

# --- helpers ---------------------------------------------------------------------

func _refresh_status() -> void:
	_status.text = "Visitor %d of %d  ·  Helped %d" % [mini(_round + 1, _rounds.size()), _rounds.size(), _helped]

func _trail_to(t: Vector2i) -> void:
	_overlay.trail.append(_centre(t))
	_redraw()

func _redraw() -> void:
	_overlay.walker = _centre(_pos)
	_overlay.heading = _heading
	_overlay.queue_redraw()

func _centre(t: Vector2i) -> Vector2:
	return Vector2(t * TILE) + Vector2(TILE, TILE) / 2.0

## Tile under a world position given in the bottom-left-corner convention actors use.
func _tile_of(world: Vector2) -> Vector2i:
	var local: Vector2 = world - _level.global_position
	return Vector2i(floori(local.x / TILE), floori(local.y / TILE) - 1)
