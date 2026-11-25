# weave_sort_panel.gd -- "Help hang the weaves" in the Haboean gallery (v1.1.9,
# tester report: Chapter 3 is only weaving). The curator's new piña weaves
# arrive in a basket; the player hangs each one on the display rack labelled
# with its colour in Akeanon, and from tier 1 on, on the row for its size
# (mabahoe = big, maisot = small).
#
# Driven by a line of minigame_type "weave_sort" (daily_games.json):
#   { "minigame_type": "weave_sort", "colors": 4 (optional), "sizes": 2 (optional),
#     "max_misses": 3 (optional) }
# Left out, colours and sizes follow the player's difficulty tier.
#
# Tap a weave in the basket, then tap a rack. Right rack: it hangs there and
# its words gain mastery. Wrong rack: a miss, and it goes back to the basket.
# All hung = pass; more than max_misses = fail (no-punishment: just no pay).
#
# Art: placeholder swatches and racks are drawn in code until the sprites from
# art_requests/WEAVE_SORT_ART_REQUEST.md land in assets/ui/weaves/; any file
# found there is used instead (weave_<color>.png, rack.png).
#
# Ownership: renders and reports only. Emits `resolved(passed)`.
extends PanelContainer

signal resolved(passed: bool)

## Colour id -> word id, swatch colour. Order = order racks are added in.
const COLORS: Array = [
	{"id": "puea", "word": "w198", "color": Color("b83a2e")},
	{"id": "asul", "word": "w021", "color": Color("2e5fa8")},
	{"id": "berde", "word": "w038", "color": Color("3e8e41")},
	{"id": "dueaw", "word": "w056", "color": Color("ddb233")},
	{"id": "puti", "word": "w199", "color": Color("efe8d8")},
	{"id": "itom", "word": "w094", "color": Color("2b2724")},
]
const SIZES: Array = [
	{"id": "mabahoe", "word": "w128", "scale": 1.0},
	{"id": "maisot", "word": "w145", "scale": 0.6},
]
const ART_DIR: String = "res://assets/ui/weaves/"
const DEFAULT_MAX_MISSES: int = 3
const END_HOLD: float = 1.4
## Swatch size at scale 1, before UI scale.
const SWATCH := Vector2(34, 42)

## A piña cloth swatch (or rack hook) drawn in code.
class Swatch extends Control:
	var fill: Color = Color.WHITE
	var scale_factor: float = 1.0
	var texture: Texture2D = null
	var selected: bool = false
	const BASE := Vector2(34, 42)

	func _draw() -> void:
		var s: Vector2 = BASE * scale_factor
		var at: Vector2 = (size - s) * 0.5
		if selected:
			draw_rect(Rect2(at - Vector2(3, 3), s + Vector2(6, 6)), UIThemeApplier.TEXT_EMPHASIS, false, 2.0)
		if texture != null:
			draw_texture_rect(texture, Rect2(at, s), false)
			return
		draw_rect(Rect2(at, s), fill)
		# Piña lattice: fine diagonal threads a shade off the cloth.
		var thread: Color = fill.darkened(0.25) if fill.get_luminance() > 0.3 else fill.lightened(0.25)
		# Small diamonds on a grid, like the pineapple-lattice map icon.
		var step: float = maxf(4.0, 6.0 * scale_factor)
		var y: float = step * 0.5
		while y < s.y:
			var x0: float = step * 0.5
			while x0 < s.x:
				var c: Vector2 = at + Vector2(x0, y)
				draw_line(c + Vector2(-1.5, 0), c + Vector2(0, -1.5), thread, 1.0)
				draw_line(c + Vector2(0, -1.5), c + Vector2(1.5, 0), thread, 1.0)
				draw_line(c + Vector2(1.5, 0), c + Vector2(0, 1.5), thread, 1.0)
				draw_line(c + Vector2(0, 1.5), c + Vector2(-1.5, 0), thread, 1.0)
				x0 += step
			y += step
		# Fringe along the bottom edge.
		var x: float = at.x + 2.0
		while x < at.x + s.x - 1.0:
			draw_line(Vector2(x, at.y + s.y), Vector2(x, at.y + s.y + 3.0 * scale_factor), thread, 1.0)
			x += 3.0
		draw_rect(Rect2(at, s), fill.darkened(0.45), false, 1.0)

var _session: int = 0
var _locked: bool = true
var _misses: int = 0
var _max_misses: int = DEFAULT_MAX_MISSES
var _total: int = 0
var _hung: int = 0
## Basket weaves: [{color: Dictionary, size: Dictionary, button: Button, swatch: Swatch}]
var _weaves: Array = []
var _selected: int = -1
## "color_id/size_id" -> {button, swatch, filled}
var _racks: Dictionary = {}
var _with_sizes: bool = false

var _status: Label
var _hint: Label
var _rack_grid: GridContainer
var _basket: HFlowContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UIThemeApplier.make_puzzle_panel_style(10))
	_build_layout()
	visible = false

# --- public API ----------------------------------------------------------------

func open(line: Dictionary) -> void:
	_session += 1
	var tier: int = GameState.get_difficulty_tier()
	var color_count: int = clampi(int(line.get("colors", 3 + tier)), 2, COLORS.size())
	var size_count: int = clampi(int(line.get("sizes", 2 if tier >= 1 else 1)), 1, SIZES.size())
	# Two size rows double the weaves: keep the basket to 8 at most.
	if size_count > 1:
		color_count = mini(color_count, 4)
	_max_misses = int(line.get("max_misses", DEFAULT_MAX_MISSES))
	var colors: Array = COLORS.duplicate()
	colors.shuffle()
	colors = colors.slice(0, color_count)
	var sizes: Array = SIZES.slice(0, size_count)
	_build_racks(colors, sizes)
	_build_basket(colors, sizes)
	_misses = 0
	_hung = 0
	_selected = -1
	_hint.text = "Tap a weave, then the rack it belongs on."
	_refresh_status()
	_locked = false
	visible = true

func close() -> void:
	_session += 1
	_locked = true
	visible = false

# --- layout --------------------------------------------------------------------

func _build_layout() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)
	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := Label.new()
	title.text = "Hang the weaves"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_M)
	title.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	header.add_child(title)
	header.add_child(HelpButton.new("weave_sort"))
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_XS)
	_status.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
	vbox.add_child(_status)
	_rack_grid = GridContainer.new()
	_rack_grid.add_theme_constant_override("h_separation", 6)
	_rack_grid.add_theme_constant_override("v_separation", 4)
	_rack_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rack_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(_rack_grid)
	vbox.add_child(UIThemeApplier.make_divider())
	var basket_label := Label.new()
	basket_label.text = "Basket"
	basket_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_XS)
	basket_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DISABLED)
	vbox.add_child(basket_label)
	_basket = HFlowContainer.new()
	_basket.add_theme_constant_override("h_separation", 4)
	_basket.alignment = FlowContainer.ALIGNMENT_CENTER
	vbox.add_child(_basket)
	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
	_hint.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	vbox.add_child(_hint)

## Racks: a header row of colour words, then one row per size, its size word first.
func _build_racks(colors: Array, sizes: Array) -> void:
	for child in _rack_grid.get_children():
		child.queue_free()
	_racks.clear()
	_with_sizes = sizes.size() > 1
	var with_sizes: bool = _with_sizes
	_rack_grid.columns = colors.size() + (1 if with_sizes else 0)
	if with_sizes:
		_rack_grid.add_child(Control.new())
	for c: Dictionary in colors:
		_rack_grid.add_child(_word_label(str(c["word"])))
	for s: Dictionary in sizes:
		if with_sizes:
			_rack_grid.add_child(_word_label(str(s["word"])))
		for c: Dictionary in colors:
			var button := Button.new()
			button.custom_minimum_size = Vector2(SWATCH.x + 16, SWATCH.y * float(s["scale"]) + 18)
			UIThemeApplier.apply_button_theme(button, "secondary")
			var rack_tex: Texture2D = _art("rack.png")
			if rack_tex != null:
				button.icon = rack_tex
				button.expand_icon = true
			var swatch := Swatch.new()
			swatch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
			swatch.scale_factor = float(s["scale"])
			swatch.visible = false
			button.add_child(swatch)
			var key: String = "%s/%s" % [c["id"], s["id"]]
			button.pressed.connect(_on_rack.bind(key))
			_rack_grid.add_child(button)
			_racks[key] = {"button": button, "swatch": swatch, "filled": false, "color": c, "size": s}

func _build_basket(colors: Array, sizes: Array) -> void:
	for child in _basket.get_children():
		child.queue_free()
	_weaves.clear()
	for s: Dictionary in sizes:
		for c: Dictionary in colors:
			_weaves.append({"color": c, "size": s})
	_weaves.shuffle()
	_total = _weaves.size()
	for i in _weaves.size():
		var w: Dictionary = _weaves[i]
		var button := Button.new()
		button.custom_minimum_size = SWATCH + Vector2(10, 12)
		button.flat = true
		var swatch := Swatch.new()
		swatch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		swatch.fill = w["color"]["color"]
		swatch.scale_factor = float(w["size"]["scale"])
		swatch.texture = _art("weave_%s.png" % w["color"]["id"])
		button.add_child(swatch)
		button.pressed.connect(_on_weave.bind(i))
		_basket.add_child(button)
		w["button"] = button
		w["swatch"] = swatch

func _word_label(word_id: String) -> Label:
	var label := Label.new()
	label.text = str(WordBank.words.get(word_id, {}).get("akeanon", word_id))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
	label.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	return label

func _art(file: String) -> Texture2D:
	var path: String = ART_DIR + file
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

# --- play ----------------------------------------------------------------------

func _on_weave(index: int) -> void:
	if _locked:
		return
	AudioManager.play_sfx("menu_click")
	_select(index if index != _selected else -1)

func _select(index: int) -> void:
	for i in _weaves.size():
		var swatch: Swatch = _weaves[i]["swatch"]
		swatch.selected = i == index
		swatch.queue_redraw()
	_selected = index
	_hint.text = "Now tap its rack." if index >= 0 else "Tap a weave, then the rack it belongs on."

func _on_rack(key: String) -> void:
	if _locked or _selected < 0:
		return
	var rack: Dictionary = _racks[key]
	if rack["filled"]:
		return
	var weave: Dictionary = _weaves[_selected]
	var right: bool = rack["color"]["id"] == weave["color"]["id"] and rack["size"]["id"] == weave["size"]["id"]
	var words: Array = [str(rack["color"]["word"])]
	if _with_sizes:
		words.append(str(rack["size"]["word"]))
	Economy.expose_line_words({"word_ids": words})
	if right:
		_hang(rack, weave)
	else:
		_miss(rack)

func _hang(rack: Dictionary, weave: Dictionary) -> void:
	AudioManager.play_sfx("advance")
	rack["filled"] = true
	var swatch: Swatch = rack["swatch"]
	swatch.fill = weave["color"]["color"]
	swatch.texture = weave["swatch"].texture
	swatch.visible = true
	swatch.queue_redraw()
	(rack["button"] as Button).disabled = true
	GameState.adjust_mastery(str(weave["color"]["word"]), 1)
	if _with_sizes:
		GameState.adjust_mastery(str(weave["size"]["word"]), 1)
	(weave["button"] as Button).visible = false
	_hung += 1
	_select(-1)
	_refresh_status()
	if _hung >= _total:
		_end(true)

func _miss(rack: Dictionary) -> void:
	AudioManager.play_sfx("wrong")
	_misses += 1
	var button: Button = rack["button"]
	button.modulate = Color(UIThemeApplier.COLOR_ERROR, 0.7)
	var session: int = _session
	get_tree().create_timer(0.5).timeout.connect(func():
		if session == _session and is_instance_valid(button):
			button.modulate = Color.WHITE)
	_select(-1)
	_hint.text = "Not that rack. Read the words again."
	_refresh_status()
	if _misses > _max_misses:
		_end(false)

func _end(passed: bool) -> void:
	_locked = true
	_hint.text = "All hung. Beautiful!" if passed else "Too many on the wrong racks."
	_hint.add_theme_color_override("font_color", UIThemeApplier.COLOR_SUCCESS if passed else UIThemeApplier.COLOR_ERROR)
	var session: int = _session
	await get_tree().create_timer(END_HOLD).timeout
	if session != _session:
		return
	_hint.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	resolved.emit(passed)

func _refresh_status() -> void:
	_status.text = "Hung %d/%d   Misses %d/%d" % [_hung, _total, _misses, _max_misses]
