# banner_card.gd -- chapter-start / new-area banner in the game's own UI style:
# the parchment panel (UIThemeApplier.make_panel_style, book/banner.png) with an
# emblem on its top edge, a small header ("Chapter 2"), a big title ("Kalibo
# Town") and a tan tag ("Started"). It plays over the game and fades away by
# itself; it never takes input, so the player (or a cutscene's dialogue) carries
# on underneath.
#
# Owned by ChapterCard (added to the root as its own CanvasLayer). Banners queue
# up, and each waits until the screen isn't black (FadeManager.is_black()), so a
# banner asked for mid-warp shows once the new map has faded in.
extends CanvasLayer

## Under the dialogue UI (Game.tscn UILayer = 99) and the screen fade (100), over the HUD (89).
const BANNER_LAYER: int = 98
const BAND_SIZE := Vector2(340, 100)
## Band centre, a little above the middle of the 640x360 view.
const BAND_CENTER_Y: float = 150.0
const TITLE_FONT_SIZE: int = 26
const TITLE_MIN_FONT_SIZE: int = 16
## Space between the title and the panel's left/right edges.
const TITLE_PADDING: float = 22.0
## Closest the band may come to the screen's sides.
const TITLE_SCREEN_MARGIN: float = 12.0
const IN_SECONDS: float = 0.35
const HOLD_SECONDS: float = 3.2
const OUT_SECONDS: float = 0.6

## Picked from the UI art: the panel's maroon border and dark outline, its peach
## fill, the orange corner tabs, and the tan button face (buttons_sheet.png).
const MAROON := Color("a8505a")
const OUTLINE := Color("3a2828")
const PEACH := Color("ffd6a6")
const ORANGE := Color("f7a94a")
const PILL_COLOR := Color("c88a5e")
const PILL_TEXT := Color("fff2d6")

var _queue: Array[Dictionary] = []
var _playing: bool = false
var _root: Control
var _band: Control
var _header: Label
var _title: Label
var _pill_label: Label
var _panel_style: StyleBox = null

func _ready() -> void:
	layer = BANNER_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.hide()

## Queues a banner. header: small line on top; title: the big words; pill: the
## tag under them ("Started", "Discovered").
func show_banner(header: String, title: String, pill: String) -> void:
	_queue.append({"header": header, "title": title, "pill": pill})
	if not _playing:
		_play_next()

func is_playing() -> bool:
	return _playing

func _play_next() -> void:
	if _queue.is_empty():
		_playing = false
		return
	_playing = true
	var entry: Dictionary = _queue.pop_front()
	# Wait out a warp or a cutscene's black opening.
	while FadeManager.is_black():
		await get_tree().process_frame
	_header.text = entry["header"]
	_title.text = entry["title"]
	_pill_label.text = entry["pill"]
	_pill_label.get_parent().visible = not str(entry["pill"]).is_empty()
	_fit_title(str(entry["title"]))
	_root.modulate.a = 0.0
	_band.pivot_offset = _band.size / 2.0
	_band.scale = Vector2(0.94, 0.94)
	_root.show()
	AudioManager.play_sfx("menu_click")
	var tw := create_tween().set_parallel()
	tw.tween_property(_root, "modulate:a", 1.0, IN_SECONDS)
	tw.tween_property(_band, "scale", Vector2.ONE, IN_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	await get_tree().create_timer(HOLD_SECONDS).timeout
	var out := create_tween()
	out.tween_property(_root, "modulate:a", 0.0, OUT_SECONDS)
	await out.finished
	_root.hide()
	_play_next()

# --- layout ----------------------------------------------------------------------

## Widens the band for a long title ("Kalibo International Airport") so the words
## stay inside the panel, up to the screen's width minus a margin; past that the
## title's font steps down until it fits.
func _fit_title(title: String) -> void:
	var font: Font = _title.get_theme_font("font")
	var max_w: float = _root.get_viewport_rect().size.x - 2.0 * TITLE_SCREEN_MARGIN
	var font_size: int = TITLE_FONT_SIZE
	var text_w: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	while text_w + 2.0 * TITLE_PADDING > max_w and font_size > TITLE_MIN_FONT_SIZE:
		font_size -= 2
		text_w = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_title.add_theme_font_size_override("font_size", font_size)
	var band_w: float = clampf(ceilf(text_w + 2.0 * TITLE_PADDING), BAND_SIZE.x, maxf(BAND_SIZE.x, max_w))
	# Offsets from the centre anchor (setting position would place it absolutely).
	_band.offset_left = -band_w / 2.0
	_band.offset_right = band_w / 2.0
	_band.queue_redraw()

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_band = Control.new()
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_band.size = BAND_SIZE
	_band.position = Vector2(-BAND_SIZE.x / 2.0, BAND_CENTER_Y - BAND_SIZE.y / 2.0)
	_band.draw.connect(_draw_band)
	_root.add_child(_band)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_top = 16  # clear of the emblem on the top edge
	column.offset_bottom = -6
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 1)
	_band.add_child(column)

	_header = _label(column, UIThemeApplier.FONT_SIZE_S, UIThemeApplier.TEXT_DEFAULT)
	_title = _label(column, TITLE_FONT_SIZE, UIThemeApplier.TEXT_EMPHASIS)
	UIThemeApplier.apply_display_font(_title)

	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = PILL_COLOR
	style.border_color = OUTLINE
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 0
	style.content_margin_bottom = 1
	pill.add_theme_stylebox_override("panel", style)
	column.add_child(pill)
	_pill_label = _label(pill, UIThemeApplier.FONT_SIZE_S, PILL_TEXT)

func _label(parent: Control, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

## The parchment panel, then the emblem on its top edge: a peach medallion in the
## panel's maroon border with an orange four-point star like its corner tabs.
func _draw_band() -> void:
	var r := Rect2(Vector2.ZERO, _band.size)
	if _panel_style == null:
		_panel_style = UIThemeApplier.make_panel_style(0)
	_panel_style.draw(_band.get_canvas_item(), r)
	var e := Vector2(r.get_center().x, 2)
	_band.draw_circle(e, 19.0, OUTLINE)
	_band.draw_circle(e, 17.5, MAROON)
	_band.draw_circle(e, 15.0, PEACH)
	var star := PackedVector2Array()
	for i in 8:
		var angle: float = -PI / 2.0 + i * PI / 4.0
		var radius: float = 11.0 if i % 2 == 0 else 3.5
		star.append(e + Vector2(cos(angle), sin(angle)) * radius)
	_band.draw_colored_polygon(star, ORANGE)
	_band.draw_polyline(star + PackedVector2Array([star[0]]), OUTLINE, 1.0)
	# Small orange tabs either side of the medallion, like the panel's corners.
	_diamond(Vector2(r.get_center().x - 28, 4), 3.0, ORANGE)
	_diamond(Vector2(r.get_center().x + 28, 4), 3.0, ORANGE)

func _diamond(center: Vector2, half: float, color: Color) -> void:
	_band.draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -half), center + Vector2(half, 0),
		center + Vector2(0, half), center + Vector2(-half, 0)]), color)
