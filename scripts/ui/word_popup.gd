# word_popup.gd -- the small bubble over a tapped Akeanon word in dialogue (see
# DialogueBox.gd). Ignores taps, so the dialogue box underneath decides what they do.
extends PanelContainer

const SCREEN_MARGIN: float = 4.0
const MAX_GLOSS_WIDTH: float = 220.0
## Space between the tap and the tip of the tail.
const TAP_GAP: float = 6.0
const TAIL_HALF_WIDTH: float = 5.0
const TAIL_HEIGHT: float = 5.0
## Sampled from the edge and middle of UIThemeApplier.DIALOGUE_BOX.
const TAIL_FILL := Color("ffd6a8")
const TAIL_EDGE := Color("7d3f4b")

var _word_label: Label
var _gloss_label: Label
var _tail_x: float = 0.0
## Bumped per show, so a newer word or a close cancels a placement still waiting.
var _show_serial: int = 0


func _ready() -> void:
	top_level = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var style := StyleBoxTexture.new()
	style.texture = UIThemeApplier.DIALOGUE_BOX
	style.set_texture_margin_all(6)
	style.set_content_margin_all(7)
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	add_child(column)
	_word_label = _make_label(UIThemeApplier.FONT_SIZE_M)
	column.add_child(_word_label)
	_gloss_label = _make_label(UIThemeApplier.FONT_SIZE_S)
	_gloss_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
	column.add_child(_gloss_label)


func _make_label(font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	return label


## Opens above `tap` (global position), kept on screen. Its size is only right
## after a layout pass, so it stays clear until then.
func show_word(akeanon: String, gloss: String, tap: Vector2) -> void:
	_show_serial += 1
	var serial := _show_serial
	_word_label.text = akeanon
	_word_label.add_theme_color_override("font_color", Accessibility.akeanon_color())
	_gloss_label.text = gloss
	_wrap_if_long(gloss)
	size = Vector2.ZERO
	modulate.a = 0.0
	visible = true
	# Two passes: wrapped text only reports its height once it has a width.
	for i in 2:
		await get_tree().process_frame
		if serial != _show_serial:
			return
		size = Vector2.ZERO
	var view: Vector2 = get_viewport_rect().size
	var x: float = clampf(tap.x - size.x / 2.0, SCREEN_MARGIN, view.x - size.x - SCREEN_MARGIN)
	var y: float = maxf(SCREEN_MARGIN, tap.y - TAP_GAP - TAIL_HEIGHT - size.y)
	global_position = Vector2(x, y)
	_tail_x = clampf(tap.x - x, TAIL_HALF_WIDTH + 3.0, size.x - TAIL_HALF_WIDTH - 3.0)
	queue_redraw()
	modulate.a = 1.0


## Short meanings size the popup to fit. A few are whole sentences.
func _wrap_if_long(gloss: String) -> void:
	var font: Font = _gloss_label.get_theme_font("font")
	var font_size: int = _gloss_label.get_theme_font_size("font_size")
	var long: bool = font.get_string_size(gloss, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > MAX_GLOSS_WIDTH
	_gloss_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if long else TextServer.AUTOWRAP_OFF
	_gloss_label.custom_minimum_size.x = MAX_GLOSS_WIDTH if long else 0.0


func close() -> void:
	_show_serial += 1
	visible = false


func _draw() -> void:
	var bottom: float = size.y - 2.0
	var left := Vector2(_tail_x - TAIL_HALF_WIDTH, bottom)
	var right := Vector2(_tail_x + TAIL_HALF_WIDTH, bottom)
	var tip := Vector2(_tail_x, bottom + TAIL_HEIGHT + 2.0)
	draw_colored_polygon(PackedVector2Array([left, right, tip]), TAIL_FILL)
	draw_polyline(PackedVector2Array([left, tip, right]), TAIL_EDGE, 1.0)
