# hangman_panel.gd -- guess a known word letter by letter, its gloss as the clue.
#
# Driven by a line of minigame_type "hangman":
#   { "type": "minigame_trigger", "minigame_type": "hangman",
#     "word_pool": ["w090", "w054"],   # word_ids the word may come from (required)
#     "max_misses": 6 }                # optional
#
# The word is drawn weighted by WordBank.get_weighted_review_word (GDD 6.8). A
# win is +1 mastery, a loss -1; no other effects (no-punishment rule, GDD 7).
#
# Ownership: renders and reports only, same contract as memory_match_panel.
# Bad data never softlocks: reports and resolves as a pass.
extends PanelContainer

## Emitted once, after the end-of-game feedback hold.
signal resolved(passed: bool)

const DEFAULT_MAX_MISSES: int = 6
## Seconds the win/lose message shows before resolving. Longer than other panels
## so the player can read the revealed word after losing.
const END_HOLD: float = 2.0
const FIGURE_WIDTH: float = 76.0
const BLANK: String = "_"

## Draws the gallows and one more body part per miss.
class Figure extends Control:
	var misses: int = 0:
		set(value):
			misses = value
			queue_redraw()

	func _draw() -> void:
		var ink: Color = UIThemeApplier.TEXT_DEFAULT
		var h: float = size.y
		var w: float = size.x
		var head := Vector2(w * 0.62, h * 0.32)
		var radius: float = h * 0.09
		var neck := head + Vector2(0, radius)
		var hips := neck + Vector2(0, h * 0.26)
		draw_line(Vector2(w * 0.1, h * 0.96), Vector2(w * 0.9, h * 0.96), ink, 2.0)
		draw_line(Vector2(w * 0.25, h * 0.96), Vector2(w * 0.25, h * 0.06), ink, 2.0)
		draw_line(Vector2(w * 0.25, h * 0.06), Vector2(head.x, h * 0.06), ink, 2.0)
		draw_line(Vector2(head.x, h * 0.06), head - Vector2(0, radius), ink, 1.0)
		if misses >= 1:
			draw_arc(head, radius, 0.0, TAU, 16, ink, 1.5)
		if misses >= 2:
			draw_line(neck, hips, ink, 1.5)
		if misses >= 3:
			draw_line(neck + Vector2(0, 4), neck + Vector2(-11, 13), ink, 1.5)
		if misses >= 4:
			draw_line(neck + Vector2(0, 4), neck + Vector2(11, 13), ink, 1.5)
		if misses >= 5:
			draw_line(hips, hips + Vector2(-10, 14), ink, 1.5)
		if misses >= 6:
			draw_line(hips, hips + Vector2(10, 14), ink, 1.5)

var _word_id: String = ""
var _letters: String = ""
var _guessed: Dictionary = {}     # letter -> true
var _misses: int = 0
var _max_misses: int = DEFAULT_MAX_MISSES
var _locked: bool = true          # true while the end message shows / closed
var _session: int = 0             # bumped on open/close; stale timers bail

var _clue_label: Label
var _word_label: Label
var _figure: Figure
var _keyboard: LetterKeyboard

func _ready() -> void:
	# Same footprint as DialogueRoot / phrase_builder (bottom 45% of viewport).
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 0.55
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_right = 0.0
	offset_top = 0.0
	offset_bottom = 0.0
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UIThemeApplier.make_dialogue_style())
	_build_layout()
	visible = false

# --- public API ----------------------------------------------------------------

## Start the game for one hangman line. Safe to call repeatedly.
func open(line: Dictionary) -> void:
	_session += 1
	_word_id = _pick_word(line)
	_letters = WordBank.puzzle_letters(_word_id)
	if _letters.is_empty():
		push_error("Hangman: no playable word in 'word_pool', auto-passing.")
		call_deferred("_emit_resolved", true)
		return

	_guessed.clear()
	_misses = 0
	_max_misses = int(line.get("max_misses", DEFAULT_MAX_MISSES))
	_figure.misses = 0
	_keyboard.reset()
	_clue_label.text = "Clue: %s" % WordBank.get_word(_word_id).get("gloss", "")
	_clue_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	_refresh_word()
	_locked = false
	visible = true

## Hide without resolving (dialogue torn down / ended elsewhere).
func close() -> void:
	_session += 1
	_locked = true
	visible = false

# --- setup -----------------------------------------------------------------------

func _pick_word(line: Dictionary) -> String:
	var pool: Array = line.get("word_pool", []).filter(func(id):
		return not WordBank.puzzle_letters(str(id)).is_empty())
	return WordBank.get_weighted_review_word(pool)

func _build_layout() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 3)
	add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	margin.add_child(hbox)

	_figure = Figure.new()
	_figure.custom_minimum_size = Vector2(FIGURE_WIDTH, 0)
	hbox.add_child(_figure)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	_clue_label = Label.new()
	_clue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_clue_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
	vbox.add_child(_clue_label)

	_word_label = Label.new()
	_word_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_word_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_word_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_word_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_XL)
	_word_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
	vbox.add_child(_word_label)

	_keyboard = LetterKeyboard.new()
	_keyboard.letter_pressed.connect(_guess)
	vbox.add_child(_keyboard)

# --- flow ------------------------------------------------------------------------

## Physical keyboard. Runs before _unhandled_input so typed letters can't also
## fire gameplay actions like "interact".
func _input(event: InputEvent) -> void:
	if not visible or BookUI.visible or not event is InputEventKey:
		return
	get_viewport().set_input_as_handled()
	if event.pressed and not event.echo:
		var letter: String = LetterKeyboard.key_to_letter(event)
		if not letter.is_empty():
			_guess(letter)

func _guess(letter: String) -> void:
	if _locked or _guessed.has(letter):
		return
	_guessed[letter] = true
	var hit: bool = _letters.contains(letter)
	_keyboard.mark_used(letter, UIThemeApplier.COLOR_SUCCESS if hit else UIThemeApplier.COLOR_ERROR)
	if not hit:
		_misses += 1
		_figure.misses = _misses
	_refresh_word()
	if _misses >= _max_misses:
		_end_game(false)
	elif not _word_label.text.contains(BLANK):
		_end_game(true)

func _end_game(passed: bool) -> void:
	_locked = true
	GameState.adjust_mastery(_word_id, 1 if passed else -1)
	var word: String = WordBank.get_word(_word_id).get("akeanon", "")
	_clue_label.text = ("Insakto! " if passed else "The word was ") + word
	_clue_label.add_theme_color_override("font_color",
			UIThemeApplier.COLOR_SUCCESS if passed else UIThemeApplier.COLOR_ERROR)

	var session: int = _session
	await get_tree().create_timer(END_HOLD).timeout
	if session != _session:
		return
	_emit_resolved(passed)

func _emit_resolved(passed: bool) -> void:
	resolved.emit(passed)

func _refresh_word() -> void:
	var shown: PackedStringArray = []
	for letter in _letters:
		shown.append(letter if _guessed.has(letter) else BLANK)
	_word_label.text = "  ".join(shown)
