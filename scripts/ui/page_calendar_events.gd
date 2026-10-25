# page_calendar_events.gd — Calendar tab, RIGHT page: event list.
#
# Always lists every event in the month shown on the left page
# (page_calendar.gd), wired by BookUI:
#   show_month(year, month)     -> rebuild the list for that month
#   show_day(year, month, day)  -> keep the month list, highlight that day's rows
# Event data: data/calendar_events.json via calendar_util.gd.
extends Control

const CalendarUtil := preload("res://scripts/util/calendar_util.gd")
const LINE_TEXTURE := preload("res://assets/ui/book/line.png")

var _year: int = 2026
var _month: int = 1
## Day whose events are highlighted (-1 = none).
var _highlight_day: int = -1

var _header: Label
var _list: VBoxContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor_left = 0.04
	anchor_top = 0.03
	anchor_right = 0.96
	anchor_bottom = 0.97
	clip_contents = true

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	_header = Label.new()
	_header.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	_header.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_L)
	vbox.add_child(_header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)

func show_month(year: int, month: int) -> void:
	_year = year
	_month = month
	_highlight_day = -1
	_render()

func show_day(year: int, month: int, day: int) -> void:
	if year != _year or month != _month:
		_year = year
		_month = month
	_highlight_day = day
	_render()

func _render() -> void:
	_header.text = "Events — %s" % DayNightManager.MONTH_NAMES[_month - 1]
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var entries: Array = CalendarUtil.events_in_month(_year, _month)
	if entries.is_empty():
		_add_meta("No events this month.")
	for entry in entries:
		_add_event(entry["day"], entry["event"], entry["day"] == _highlight_day)

func _add_event(day: int, event: Dictionary, highlighted: bool) -> void:
	var title := Label.new()
	title.text = "%s %d — %s" % [DayNightManager.MONTH_NAMES[_month - 1].left(3), day, event.get("title", event.get("id", ""))]
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	title.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
	if highlighted:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(UIThemeApplier.TEXT_EMPHASIS, 0.18)
		sb.set_corner_radius_all(2)
		title.add_theme_stylebox_override("normal", sb)
	_list.add_child(title)
	var description: String = event.get("description", "")
	if not description.is_empty():
		var body := Label.new()
		body.text = description
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
		body.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_XS)
		_list.add_child(body)
	var sep := HSeparator.new()
	var sep_style := StyleBoxTexture.new()
	sep_style.texture = LINE_TEXTURE
	sep_style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sep.add_theme_stylebox_override("separator", sep_style)
	_list.add_child(sep)

func _add_meta(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DISABLED)
	label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
	_list.add_child(label)
