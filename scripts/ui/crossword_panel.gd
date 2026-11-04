# crossword_panel.gd -- crossword with English glosses as clues.
#
# Driven by a line of minigame_type "crossword":
#   { "type": "minigame_trigger", "minigame_type": "crossword",
#     "word_pool": ["w090", "w054"] }  # word_ids, highest priority first (required)
#
# Tap a cell to select its word (tap again to switch across/down), then type with
# the on-screen or a physical keyboard. A filled word is checked right away:
# correct locks it green (+1 mastery), wrong flashes red and clears (-1 mastery).
# No timer and no way to fail (no-punishment rule, GDD 7); Quit resolves false.
#
# Ownership: renders and reports only, same contract as memory_match_panel.
# Bad data never softlocks: reports and resolves as a pass.
extends PanelContainer

## Emitted once: true when solved, false when quit.
signal resolved(passed: bool)

const MAX_COLS: int = 12
const MAX_ROWS: int = 11
const TARGET_WORDS: int = 8
const CELL_SIZE: float = 27.0
const WRONG_HOLD: float = 0.6
const END_HOLD: float = 1.5

const COLOR_CELL := Color("f4ecd8")
const COLOR_WORD := Color("e6d28f")
const COLOR_CURSOR := Color("d9a441")
const COLOR_LINE := Color("39290f")

## The letter grid. Draws from the panel's state, reports taps.
class Grid extends Control:
	signal cell_tapped(cell: Vector2i)

	var panel: Node = null

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			cell_tapped.emit(Vector2i(event.position / CELL_SIZE))

	func _draw() -> void:
		var font: Font = UIThemeApplier.FONT_DISPLAY
		for cell in panel._answers.keys():
			var rect := Rect2(Vector2(cell) * CELL_SIZE, Vector2.ONE * CELL_SIZE)
			draw_rect(rect, panel._cell_color(cell))
			draw_rect(rect, COLOR_LINE, false, 1.0)
			if panel._numbers.has(cell):
				draw_string(font, rect.position + Vector2(2, 9), str(panel._numbers[cell]),
						HORIZONTAL_ALIGNMENT_LEFT, -1, 9, COLOR_LINE)
			if panel._typed.has(cell):
				draw_string(font, rect.position + Vector2(0, 22), panel._typed[cell],
						HORIZONTAL_ALIGNMENT_CENTER, CELL_SIZE, 17, COLOR_LINE)

var _placements: Array = []       # [{id, letters, cell, dir, number, solved, clue_btn}]
var _answers: Dictionary = {}     # cell -> correct letter
var _numbers: Dictionary = {}     # cell -> clue number
var _typed: Dictionary = {}       # cell -> typed letter
var _solved_cells: Dictionary = {}  # cell -> true, locked by a solved word
var _wrong_cells: Dictionary = {}   # cell -> true, flashing red
var _selected: int = -1           # index into _placements
var _cursor: Vector2i = Vector2i.ZERO
var _locked: bool = true          # true during the wrong-word flash / end / closed
var _session: int = 0             # bumped on open/close; stale timers bail

var _grid: Grid
var _clue_label: Label
var _clue_list: VBoxContainer
var _keyboard: LetterKeyboard

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UIThemeApplier.make_puzzle_panel_style(8))
	_build_layout()
	visible = false

# --- public API ----------------------------------------------------------------

## Start the game for one crossword line. Safe to call repeatedly.
func open(line: Dictionary) -> void:
	_session += 1
	var entries: Array = []
	for raw in line.get("word_pool", []):
		var letters: String = WordBank.puzzle_letters(str(raw))
		if not letters.is_empty():
			entries.append({"id": str(raw), "letters": letters})

	var layout: Dictionary = CrosswordGenerator.generate(entries, MAX_COLS, MAX_ROWS, TARGET_WORDS)
	if layout.is_empty():
		push_error("Crossword: no playable words in 'word_pool', auto-passing.")
		call_deferred("_emit_resolved", true)
		return

	_load_layout(layout)
	_select(0, _placements[0]["cell"])
	_locked = false
	visible = true

## Hide without resolving (dialogue torn down / ended elsewhere).
func close() -> void:
	_session += 1
	_locked = true
	visible = false

# --- setup -----------------------------------------------------------------------

func _load_layout(layout: Dictionary) -> void:
	_placements = layout["placements"]
	_answers.clear()
	_numbers.clear()
	_typed.clear()
	_solved_cells.clear()
	_wrong_cells.clear()
	for p in _placements:
		p["solved"] = false
		_numbers[p["cell"]] = p["number"]
		var cells: Array = _word_cells(p)
		for i in range(cells.size()):
			_answers[cells[i]] = p["letters"][i]
	_clue_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
	_grid.custom_minimum_size = Vector2(layout["cols"], layout["rows"]) * CELL_SIZE
	_grid.size = _grid.custom_minimum_size
	_build_clues()
	_grid.queue_redraw()

func _build_clues() -> void:
	for child in _clue_list.get_children():
		_clue_list.remove_child(child)   # remove before free: avoids stale-cell layout
		child.queue_free()
	for dir in [CrosswordGenerator.ACROSS, CrosswordGenerator.DOWN]:
		var header := Label.new()
		header.text = "Across" if dir == CrosswordGenerator.ACROSS else "Down"
		header.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
		header.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
		_clue_list.add_child(header)
		var indices: Array = range(_placements.size()).filter(func(i): return _placements[i]["dir"] == dir)
		indices.sort_custom(func(a, b): return _placements[a]["number"] < _placements[b]["number"])
		for i in indices:
			var btn := Button.new()
			btn.text = _clue_text(_placements[i])
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			btn.focus_mode = Control.FOCUS_NONE
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			UIThemeApplier.apply_button_theme(btn, "secondary")
			btn.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_XS)
			btn.pressed.connect(func(): _select(i, _first_open_cell(_placements[i])))
			_clue_list.add_child(btn)
			_placements[i]["clue_btn"] = btn

func _build_layout() -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	add_child(hbox)

	var grid_holder := CenterContainer.new()
	grid_holder.custom_minimum_size = Vector2(MAX_COLS, MAX_ROWS) * CELL_SIZE
	hbox.add_child(grid_holder)
	_grid = Grid.new()
	_grid.panel = self
	_grid.cell_tapped.connect(_on_cell_tapped)
	grid_holder.add_child(_grid)

	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 3)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(side)

	var top := HBoxContainer.new()
	side.add_child(top)
	var title := Label.new()
	title.text = "Crossword"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_M)
	title.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	top.add_child(title)
	var quit := Button.new()
	quit.text = "Quit"
	quit.focus_mode = Control.FOCUS_NONE
	quit.custom_minimum_size = Vector2(56, 24)
	UIThemeApplier.apply_button_theme(quit, "secondary")
	quit.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
	quit.pressed.connect(_quit)
	top.add_child(quit)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(scroll)
	_clue_list = VBoxContainer.new()
	_clue_list.add_theme_constant_override("separation", 2)
	_clue_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_clue_list)

	_clue_label = Label.new()
	_clue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_clue_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
	_clue_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
	side.add_child(_clue_label)

	_keyboard = LetterKeyboard.new(true)
	_keyboard.letter_pressed.connect(_type_letter)
	_keyboard.erase_pressed.connect(_erase)
	side.add_child(_keyboard)

# --- word helpers ----------------------------------------------------------------

func _word_cells(p: Dictionary) -> Array:
	var cells: Array = []
	for i in range(p["letters"].length()):
		cells.append(p["cell"] + p["dir"] * i)
	return cells

func _clue_text(p: Dictionary) -> String:
	return "%d. %s" % [p["number"], WordBank.get_word(p["id"]).get("gloss", "")]

## Indices of the words running through `cell`.
func _words_at(cell: Vector2i) -> Array:
	return range(_placements.size()).filter(func(i): return _word_cells(_placements[i]).has(cell))

func _first_open_cell(p: Dictionary) -> Vector2i:
	for cell in _word_cells(p):
		if not _typed.has(cell):
			return cell
	return p["cell"]

func _cell_color(cell: Vector2i) -> Color:
	if _wrong_cells.has(cell):
		return UIThemeApplier.COLOR_ERROR
	if _selected >= 0 and cell == _cursor:
		return COLOR_CURSOR
	if _solved_cells.has(cell):
		return UIThemeApplier.COLOR_SUCCESS
	if _selected >= 0 and _word_cells(_placements[_selected]).has(cell):
		return COLOR_WORD
	return COLOR_CELL

# --- flow ------------------------------------------------------------------------

## Physical keyboard. Runs before _unhandled_input so typed letters can't also
## fire gameplay actions like "interact". ui_cancel covers Esc and Android back.
func _input(event: InputEvent) -> void:
	if not visible or BookUI.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_quit()
	elif event is InputEventKey:
		get_viewport().set_input_as_handled()
		if event.pressed and not event.echo:
			if event.keycode == KEY_BACKSPACE:
				_erase()
			else:
				var letter: String = LetterKeyboard.key_to_letter(event)
				if not letter.is_empty():
					_type_letter(letter)

func _on_cell_tapped(cell: Vector2i) -> void:
	if _locked or not _answers.has(cell):
		return
	var through: Array = _words_at(cell)
	var next: int = through[0]
	if through.has(_selected):
		# Tapping the cursor again switches to the crossing word, if any.
		next = _selected
		if cell == _cursor and through.size() > 1:
			next = through[(through.find(_selected) + 1) % through.size()]
	_select(next, cell)

func _select(index: int, cell: Vector2i) -> void:
	_selected = index
	_cursor = cell
	var p: Dictionary = _placements[index]
	var across: bool = p["dir"] == CrosswordGenerator.ACROSS
	_clue_label.text = "%d %s: %s" % [p["number"], "Across" if across else "Down",
			WordBank.get_word(p["id"]).get("gloss", "")]
	_grid.queue_redraw()

func _type_letter(letter: String) -> void:
	if _locked or _selected < 0:
		return
	var p: Dictionary = _placements[_selected]
	if p["solved"]:
		return
	if not _solved_cells.has(_cursor):
		_typed[_cursor] = letter
	_move_cursor(p, 1)
	_grid.queue_redraw()
	_check_words()

func _erase() -> void:
	if _locked or _selected < 0:
		return
	var p: Dictionary = _placements[_selected]
	if not _typed.has(_cursor) or _solved_cells.has(_cursor):
		_move_cursor(p, -1)
	if not _solved_cells.has(_cursor):
		_typed.erase(_cursor)
	_grid.queue_redraw()

## Steps along the word, stopping at its ends and hopping over locked letters.
func _move_cursor(p: Dictionary, step: int) -> void:
	var cells: Array = _word_cells(p)
	var i: int = cells.find(_cursor) + step
	while i >= 0 and i < cells.size():
		if not _solved_cells.has(cells[i]):
			_cursor = cells[i]
			return
		i += step

## Checks every completely filled word, since typing one can finish a crossing word.
func _check_words() -> void:
	for p in _placements:
		if p["solved"]:
			continue
		var cells: Array = _word_cells(p)
		if not cells.all(func(c): return _typed.has(c)):
			continue
		if cells.all(func(c): return _typed[c] == _answers[c]):
			_solve_word(p, cells)
		else:
			_reject_word(p, cells)
			return
	if _placements.all(func(p): return p["solved"]):
		_end_game()
	elif _placements[_selected]["solved"]:
		_select_next_open()

func _solve_word(p: Dictionary, cells: Array) -> void:
	p["solved"] = true
	GameState.adjust_mastery(p["id"], 1)
	for cell in cells:
		_solved_cells[cell] = true
	var btn: Button = p["clue_btn"]
	btn.disabled = true
	btn.modulate = Color(UIThemeApplier.COLOR_SUCCESS, 0.7)
	btn.text = "%s = %s" % [_clue_text(p), WordBank.get_word(p["id"]).get("akeanon", "")]
	_grid.queue_redraw()

## Red flash, then clears the word's unlocked letters and puts the cursor back.
func _reject_word(p: Dictionary, cells: Array) -> void:
	_locked = true
	GameState.adjust_mastery(p["id"], -1)
	for cell in cells:
		if not _solved_cells.has(cell):
			_wrong_cells[cell] = true
	_grid.queue_redraw()
	var session: int = _session
	await get_tree().create_timer(WRONG_HOLD).timeout
	if session != _session:
		return
	for cell in _wrong_cells.keys():
		_typed.erase(cell)
	_wrong_cells.clear()
	_select(_placements.find(p), _first_open_cell(p))
	_locked = false

func _select_next_open() -> void:
	for i in range(_placements.size()):
		if not _placements[i]["solved"]:
			_select(i, _first_open_cell(_placements[i]))
			return

func _end_game() -> void:
	_locked = true
	_selected = -1
	_clue_label.text = "Insakto! Crossword complete."
	_clue_label.add_theme_color_override("font_color", UIThemeApplier.COLOR_SUCCESS)
	_grid.queue_redraw()
	var session: int = _session
	await get_tree().create_timer(END_HOLD).timeout
	if session != _session:
		return
	_emit_resolved(true)

func _quit() -> void:
	if not visible:
		return
	_session += 1   # cancels a pending flash or end hold
	_locked = true
	_emit_resolved(false)

func _emit_resolved(passed: bool) -> void:
	resolved.emit(passed)
