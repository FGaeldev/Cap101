# page_calendar.gd — Calendar tab, LEFT page: month grid.
#
# Real Gregorian layout (weekday columns Sun..Sat, correct month lengths,
# leap years) for the in-game date (GameState.date_unix, advanced by
# DayNightManager). Highlights today, marks days that have events
# (data/calendar_events.json via calendar_util.gd), and pages months with
# BookUI's arrow bar (next_page/prev_page contract, see BookUI._update_bottom_bar).
#
# The right page (page_calendar_events.gd) always lists the shown month's
# events (month_changed); day_selected only highlights that day's rows there.
extends Control

signal month_changed(year: int, month: int)
signal day_selected(year: int, month: int, day: int)

const CalendarUtil := preload("res://scripts/util/calendar_util.gd")

const WEEKDAY_LETTERS := ["S", "M", "T", "W", "T", "F", "S"]
## 6 weeks covers every month layout.
const GRID_CELLS := 42
const CELL_MIN_HEIGHT := 18.0

var _year: int = 2026
var _month: int = 1
var _selected_day: int = -1

var _header: Label
var _grid: GridContainer

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
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	_header.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_L)
	vbox.add_child(_header)

	var weekdays := GridContainer.new()
	weekdays.columns = 7
	vbox.add_child(weekdays)
	for letter in WEEKDAY_LETTERS:
		var label := Label.new()
		label.text = letter
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DISABLED)
		label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_XS)
		weekdays.add_child(label)

	_grid = GridContainer.new()
	_grid.columns = 7
	_grid.add_theme_constant_override("h_separation", 2)
	_grid.add_theme_constant_override("v_separation", 2)
	vbox.add_child(_grid)
	for i in GRID_CELLS:
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, CELL_MIN_HEIGHT)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_XS)
		btn.pressed.connect(_on_cell_pressed.bind(i))
		_grid.add_child(btn)

## BookUI calls this every time the tab opens: jump back to today.
func refresh() -> void:
	var today: Dictionary = DayNightManager.get_date()
	_year = today["year"]
	_month = today["month"]
	_selected_day = today["day"]
	_render()
	month_changed.emit(_year, _month)
	day_selected.emit(_year, _month, _selected_day)

# --- BookUI pagination contract (months) -------------------------------------

func next_page() -> void:
	_shift_month(1)

func prev_page() -> void:
	_shift_month(-1)

func has_next_page() -> bool:
	return true

func has_prev_page() -> bool:
	return true

func _shift_month(delta: int) -> void:
	var index: int = _year * 12 + (_month - 1) + delta
	_year = index / 12
	_month = index % 12 + 1
	_selected_day = -1
	_render()
	month_changed.emit(_year, _month)

# --- Rendering ---------------------------------------------------------------

func _first_cell_offset() -> int:
	return CalendarUtil.weekday_of(_year, _month, 1)

func _render() -> void:
	_header.text = DayNightManager.MONTH_NAMES[_month - 1]
	var today: Dictionary = DayNightManager.get_date()
	var event_days: Dictionary = {}
	for entry in CalendarUtil.events_in_month(_year, _month):
		event_days[entry["day"]] = true

	var offset: int = _first_cell_offset()
	var count: int = CalendarUtil.days_in_month(_year, _month)
	for i in GRID_CELLS:
		var btn: Button = _grid.get_child(i)
		var day: int = i - offset + 1
		var in_month: bool = day >= 1 and day <= count
		btn.text = str(day) if in_month else ""
		btn.disabled = not in_month
		var is_today: bool = in_month and day == today["day"] and _month == today["month"] and _year == today["year"]
		_style_cell(btn, in_month, is_today, event_days.has(day), day == _selected_day)

## Today = filled, selected = outlined, event day = underlined accent.
func _style_cell(btn: Button, in_month: bool, is_today: bool, has_event: bool, selected: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UIThemeApplier.TEXT_EMPHASIS, 0.22) if is_today else Color(0, 0, 0, 0)
	sb.set_corner_radius_all(2)
	if selected:
		sb.border_color = UIThemeApplier.TEXT_EMPHASIS
		sb.set_border_width_all(1)
	if has_event:
		sb.border_color = UIThemeApplier.TEXT_EMPHASIS
		sb.border_width_bottom = 2
	for state in ["normal", "hover", "pressed", "disabled"]:
		btn.add_theme_stylebox_override(state, sb)
	var color: Color = UIThemeApplier.TEXT_EMPHASIS if has_event or is_today else UIThemeApplier.TEXT_DEFAULT
	if not in_month:
		color = Color(0, 0, 0, 0)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		btn.add_theme_color_override(key, color)

func _on_cell_pressed(index: int) -> void:
	var day: int = index - _first_cell_offset() + 1
	if day < 1 or day > CalendarUtil.days_in_month(_year, _month):
		return
	AudioManager.play_sfx("menu_click")
	_selected_day = day
	_render()
	day_selected.emit(_year, _month, day)
