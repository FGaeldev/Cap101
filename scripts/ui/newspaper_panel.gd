# newspaper_panel.gd -- the daily paper: word of the day, next calendar event and
# today's puzzle.
#
# Opened by DialogueUI.show_newspaper() (scripts/entities/newspaper.gd). Reading
# it exposes the word of the day, adding it to the Dictionary. The puzzle swaps
# between crossword and word search with the in-game date, and is built from
# known words with the fewest mastery points first, sized by the difficulty tier.
# One solved puzzle per day: quitting keeps its progress to continue that day.
# Everything refreshes when the date rolls over, even with the paper open. Puzzles
# only ever change mastery (no-punishment rule, GDD 7).
extends PanelContainer

const CalendarUtil := preload("res://scripts/util/calendar_util.gd")

const MASTHEAD: String = "The Aklan Daily"
## Fewest playable known words a puzzle can be built from.
const MIN_PUZZLE_WORDS: int = 4
## Longest word that fits both puzzle grids (they have 9 rows).
const MAX_WORD_LENGTH: int = 9
const MIN_WORD_LENGTH: int = 3
## Puzzles are drawn from this many of the lowest-mastery words, giving the
## crossword spares when its first choices don't interlock.
const PUZZLE_POOL_SIZE: int = 40

var _date_label: Label
var _word_label: Label
var _gloss_label: Label
var _event_title_label: Label
var _event_detail_label: Label
var _puzzle_label: Label
var _solve_button: Button
var _puzzle_type: String = ""
var _puzzle_date: int = 0         # the day the running puzzle belongs to
var _pool: Array = []

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UIThemeApplier.make_puzzle_panel_style(10))
	_build_layout()
	DayNightManager.day_changed.connect(_on_day_changed)
	visible = false

# --- public API ----------------------------------------------------------------

func open() -> void:
	_refresh()
	visible = true

## Hide without saving; DialogueUI calls this when overlays are torn down.
func close() -> void:
	visible = false

# --- content ---------------------------------------------------------------------

## Even in-game days print a crossword, odd days a word search.
static func puzzle_type_for(date_unix: int) -> String:
	return "crossword" if (date_unix / DayNightManager.SECONDS_PER_DAY) % 2 == 0 else "word_search"

func _refresh() -> void:
	var date: Dictionary = DayNightManager.get_date()
	_date_label.text = "%s, %s" % [DayNightManager.WEEKDAY_SHORT[date["weekday"]], _format_day(date["month"], date["day"])]
	_refresh_word()
	_refresh_event(date)
	_refresh_puzzle()

func _format_day(month: int, day: int) -> String:
	return "%s %d" % [DayNightManager.MONTH_NAMES[month - 1], day]

func _refresh_word() -> void:
	var word_id: String = WordBank.get_word_of_the_day()
	var word: Dictionary = WordBank.get_word(word_id)
	_word_label.text = WordBank.clean_form(word.get("akeanon", ""))
	_gloss_label.text = word.get("gloss", "")
	if not GameState.is_in_dictionary(word_id):
		GameState.expose_word(word_id)

func _refresh_event(date: Dictionary) -> void:
	var next: Dictionary = CalendarUtil.next_event(date["year"], date["month"], date["day"])
	if next.is_empty():
		_event_title_label.text = "Nothing coming up."
		_event_detail_label.text = ""
		return
	var today: bool = next["month"] == date["month"] and next["day"] == date["day"]
	_event_title_label.text = next["event"].get("title", "")
	_event_detail_label.text = "Today" if today else _format_day(next["month"], next["day"])

func _refresh_puzzle() -> void:
	_puzzle_type = puzzle_type_for(GameState.date_unix)
	_pool = WordBank.get_known_puzzle_words(MIN_WORD_LENGTH, MAX_WORD_LENGTH).slice(0, PUZZLE_POOL_SIZE)
	var name_text: String = "Crossword" if _puzzle_type == "crossword" else "Word Search"
	var solved: bool = GameState.is_puzzle_solved_today()
	var started: bool = _has_progress_today()
	var playable: bool = started or _pool.size() >= MIN_PUZZLE_WORDS
	if solved:
		_puzzle_label.text = "%s\nSolved! Come back tomorrow." % name_text
	elif not playable:
		_puzzle_label.text = "%s\nLearn more words to play." % name_text
	else:
		_puzzle_label.text = name_text
	_solve_button.text = "Continue" if started and not solved else "Solve"
	_solve_button.disabled = solved or not playable

## True when a puzzle was quit earlier today (more saved than just its date).
func _has_progress_today() -> bool:
	return GameState.puzzle_progress.get("date", -1) == GameState.date_unix and GameState.puzzle_progress.size() > 1

# --- setup -----------------------------------------------------------------------

func _build_layout() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	var masthead := Label.new()
	masthead.text = MASTHEAD
	masthead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIThemeApplier.apply_display_font(masthead)
	masthead.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_XXL)
	masthead.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	vbox.add_child(masthead)

	_date_label = _make_label(UIThemeApplier.FONT_SIZE_XS, UIThemeApplier.TEXT_DEFAULT)
	_date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_date_label)
	vbox.add_child(HSeparator.new())

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 8)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(columns)

	# Left column: word of the day over the next calendar event, equal heights.
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left)

	var word_section := _make_section(left)
	word_section.add_child(_make_heading("Word of the Day"))
	_word_label = _make_label(UIThemeApplier.FONT_SIZE_XL, UIThemeApplier.TEXT_EMPHASIS)
	word_section.add_child(_word_label)
	_gloss_label = _make_label(UIThemeApplier.FONT_SIZE_S, UIThemeApplier.TEXT_DEFAULT)
	word_section.add_child(_gloss_label)

	left.add_child(HSeparator.new())

	var event_section := _make_section(left)
	event_section.add_child(_make_heading("Coming Up"))
	_event_title_label = _make_label(UIThemeApplier.FONT_SIZE_M, UIThemeApplier.TEXT_EMPHASIS)
	event_section.add_child(_event_title_label)
	_event_detail_label = _make_label(UIThemeApplier.FONT_SIZE_S, UIThemeApplier.TEXT_DEFAULT)
	event_section.add_child(_event_detail_label)

	columns.add_child(VSeparator.new())

	# Right column: the daily minigame.
	var right := _make_section(columns)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(_make_heading("Today's Puzzle"))
	_puzzle_label = _make_label(UIThemeApplier.FONT_SIZE_M, UIThemeApplier.TEXT_DEFAULT)
	right.add_child(_puzzle_label)
	_solve_button = _make_button("Solve")
	_solve_button.pressed.connect(_on_solve_pressed)
	right.add_child(_solve_button)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(spacer)

	var close_button := _make_button("Put it down")
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_button.pressed.connect(_put_down)
	right.add_child(close_button)

func _make_section(parent: Control) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 4)
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(section)
	return section

func _make_heading(text: String) -> Label:
	var label := _make_label(UIThemeApplier.FONT_SIZE_S, UIThemeApplier.TEXT_DEFAULT)
	label.text = text
	return label

func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(110, 26)
	UIThemeApplier.apply_button_theme(btn, "primary")
	btn.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_M)
	return btn

# --- flow ------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not visible or BookUI.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_put_down()
	elif event is InputEventKey:
		get_viewport().set_input_as_handled()

func _on_day_changed() -> void:
	if visible:
		_refresh()

func _on_solve_pressed() -> void:
	visible = false
	_puzzle_date = GameState.date_unix
	if GameState.puzzle_progress.get("date", -1) != _puzzle_date:
		GameState.puzzle_progress = {"date": _puzzle_date}
	DialogueUI.show_standalone_minigame({
		"minigame_type": _puzzle_type,
		"word_pool": _pool,
		"word_count": GameState.get_minigame_word_count(),
		"progress": GameState.puzzle_progress,
	}, _on_puzzle_resolved)

## A puzzle finished past midnight counts for the day it was started, so the new
## day's puzzle is still open.
func _on_puzzle_resolved(passed: bool) -> void:
	if passed:
		GameState.puzzle_solved_date = _puzzle_date
		GameState.puzzle_progress = {}
	GameState.save_game()
	_refresh()
	visible = true

func _put_down() -> void:
	DialogueUI.hide()
