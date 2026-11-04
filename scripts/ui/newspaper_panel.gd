# newspaper_panel.gd -- the daily paper: word of the day plus today's puzzle.
#
# Opened by DialogueUI.show_newspaper() (scripts/entities/newspaper.gd). Reading
# it exposes the word of the day, adding it to the Dictionary. The puzzle swaps
# between crossword and word search with the in-game date, and is built from
# known words with the fewest mastery points first. Puzzles can be replayed;
# they only ever change mastery (no-punishment rule, GDD 7).
extends PanelContainer

const MASTHEAD: String = "The Aklan Daily"
## Fewest playable known words a puzzle can be built from.
const MIN_PUZZLE_WORDS: int = 4
## Longest word that fits both puzzle grids (word search has 9 rows).
const MAX_WORD_LENGTH: int = 9
const MIN_WORD_LENGTH: int = 3
## Puzzles are drawn from this many of the lowest-mastery words, giving the
## crossword spares when its first choices don't interlock.
const PUZZLE_POOL_SIZE: int = 40

var _date_label: Label
var _word_label: Label
var _gloss_label: Label
var _puzzle_label: Label
var _solve_button: Button
var _puzzle_type: String = ""
var _pool: Array = []

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UIThemeApplier.make_puzzle_panel_style(14))
	_build_layout()
	visible = false

# --- public API ----------------------------------------------------------------

func open() -> void:
	var word_id: String = WordBank.get_word_of_the_day()
	var word: Dictionary = WordBank.get_word(word_id)
	_word_label.text = word.get("akeanon", "")
	_gloss_label.text = word.get("gloss", "")
	GameState.expose_word(word_id)

	var date: Dictionary = DayNightManager.get_date()
	_date_label.text = "%s, %s %d, %d" % [DayNightManager.WEEKDAY_SHORT[date["weekday"]],
			DayNightManager.MONTH_NAMES[date["month"] - 1], date["day"], date["year"]]
	_refresh_puzzle()
	visible = true

## Hide without saving; DialogueUI calls this when overlays are torn down.
func close() -> void:
	visible = false

# --- setup -----------------------------------------------------------------------

## Even in-game days print a crossword, odd days a word search.
static func puzzle_type_for(date_unix: int) -> String:
	return "crossword" if (date_unix / DayNightManager.SECONDS_PER_DAY) % 2 == 0 else "word_search"

func _refresh_puzzle() -> void:
	_puzzle_type = puzzle_type_for(GameState.date_unix)
	_pool = WordBank.get_known_puzzle_words(MIN_WORD_LENGTH, MAX_WORD_LENGTH).slice(0, PUZZLE_POOL_SIZE)
	var ready_to_play: bool = _pool.size() >= MIN_PUZZLE_WORDS
	var name_text: String = "Crossword" if _puzzle_type == "crossword" else "Word Search"
	_puzzle_label.text = name_text if ready_to_play else "%s\nLearn more words to play." % name_text
	_solve_button.disabled = not ready_to_play

func _build_layout() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
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
	columns.add_theme_constant_override("separation", 12)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(columns)

	var word_col := _make_column(columns)
	word_col.add_child(_make_heading("Word of the Day"))
	_word_label = _make_label(UIThemeApplier.FONT_SIZE_XL, UIThemeApplier.TEXT_EMPHASIS)
	word_col.add_child(_word_label)
	_gloss_label = _make_label(UIThemeApplier.FONT_SIZE_M, UIThemeApplier.TEXT_DEFAULT)
	word_col.add_child(_gloss_label)

	columns.add_child(VSeparator.new())

	var puzzle_col := _make_column(columns)
	puzzle_col.add_child(_make_heading("Today's Puzzle"))
	_puzzle_label = _make_label(UIThemeApplier.FONT_SIZE_M, UIThemeApplier.TEXT_DEFAULT)
	puzzle_col.add_child(_puzzle_label)
	_solve_button = _make_button("Solve")
	_solve_button.pressed.connect(_on_solve_pressed)
	puzzle_col.add_child(_solve_button)

	var close_button := _make_button("Put it down")
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_button.pressed.connect(_put_down)
	vbox.add_child(close_button)

func _make_column(parent: Control) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_stretch_ratio = 1.0
	parent.add_child(col)
	return col

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

func _on_solve_pressed() -> void:
	visible = false
	DialogueUI.show_standalone_minigame({"minigame_type": _puzzle_type, "word_pool": _pool}, _on_puzzle_resolved)

## Back to the paper, with the pool re-sorted by the mastery the puzzle just changed.
func _on_puzzle_resolved(_passed: bool) -> void:
	GameState.save_game()
	_refresh_puzzle()
	visible = true

func _put_down() -> void:
	DialogueUI.hide()
