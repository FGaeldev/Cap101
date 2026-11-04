# word_search_panel.gd -- find hidden words by dragging across their letters.
#
# Driven by a line of minigame_type "word_search":
#   { "type": "minigame_trigger", "minigame_type": "word_search",
#     "word_pool": ["w090", "w054"] }  # word_ids, highest priority first (required)
#
# Press on a word's first or last letter and drag to the other end; the selection
# snaps to a straight line. Letting go checks it: a remaining word is found (+1
# mastery, reveals its gloss), any other line of 2+ letters flashes red. No timer
# and no way to fail (no-punishment rule, GDD 7); Quit resolves false.
#
# Ownership: renders and reports only, same contract as memory_match_panel.
# Bad data never softlocks: reports and resolves as a pass.
extends PanelContainer

## Emitted once: true when all words are found, false when quit.
signal resolved(passed: bool)

const WORD_COUNT: int = 5
const COLS: int = 12
const ROWS: int = 9
const CELL_SIZE: float = 32.0
const WRONG_HOLD: float = 0.4
const END_HOLD: float = 1.5

const COLOR_CELL := Color("f4ecd8")
const COLOR_SELECTED := Color("d9a441")
const COLOR_LINE := Color("39290f")

## The letter grid. Draws from the panel's state, reports the drag. A Control
## keeps receiving mouse events until release, even past its edge; emulated
## touch (project default) arrives the same way.
class Grid extends Control:
	signal drag_started(cell: Vector2i)
	signal drag_moved(cell: Vector2i)
	signal drag_ended

	var panel: Node = null

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				drag_started.emit(_cell_at(event.position))
			else:
				drag_ended.emit()
		elif event is InputEventMouseMotion:
			drag_moved.emit(_cell_at(event.position))

	func _cell_at(pos: Vector2) -> Vector2i:
		return Vector2i(pos / CELL_SIZE).clamp(Vector2i.ZERO, Vector2i(COLS - 1, ROWS - 1))

	func _draw() -> void:
		var font: Font = UIThemeApplier.FONT_DISPLAY
		for r in range(panel._grid_letters.size()):
			var row: Array = panel._grid_letters[r]
			for c in range(row.size()):
				var cell := Vector2i(c, r)
				var rect := Rect2(Vector2(cell) * CELL_SIZE, Vector2.ONE * CELL_SIZE)
				draw_rect(rect, panel._cell_color(cell))
				draw_rect(rect, COLOR_LINE, false, 1.0)
				draw_string(font, rect.position + Vector2(0, 24), row[c],
						HORIZONTAL_ALIGNMENT_CENTER, CELL_SIZE, 19, COLOR_LINE)

var _grid_letters: Array = []     # rows of letters
var _entries: Array = []          # [{id, letters, found, label}]
var _selection: Array = []        # cells of the line being dragged
var _drag_start: Vector2i = Vector2i.ZERO
var _dragging: bool = false
var _found_cells: Dictionary = {} # cell -> true
var _wrong_cells: Array = []      # flashing red
var _locked: bool = true          # true during flash / end / closed
var _session: int = 0             # bumped on open/close; stale timers bail

var _grid: Grid
var _status_label: Label
var _word_list: VBoxContainer

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UIThemeApplier.make_puzzle_panel_style(8))
	_build_layout()
	visible = false

# --- public API ----------------------------------------------------------------

## Start the game for one word_search line. Safe to call repeatedly.
func open(line: Dictionary) -> void:
	_session += 1
	var pool: Array = []
	for raw in line.get("word_pool", []):
		var letters: String = WordBank.puzzle_letters(str(raw))
		if not letters.is_empty() and letters.length() <= ROWS:
			pool.append({"id": str(raw), "letters": letters})

	var picked: Array = WordSearchGenerator.pick_words(pool, WORD_COUNT)
	var puzzle: Dictionary = WordSearchGenerator.generate(picked, COLS, ROWS) if not picked.is_empty() else {}
	if puzzle.is_empty():
		push_error("WordSearch: no playable words in 'word_pool', auto-passing.")
		call_deferred("_emit_resolved", true)
		return

	_grid_letters = puzzle["grid"]
	_selection.clear()
	_dragging = false
	_found_cells.clear()
	_wrong_cells.clear()
	_build_word_list(picked)
	_status_label.text = "Drag across each word's letters."
	_status_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
	_grid.queue_redraw()
	_locked = false
	visible = true

## Hide without resolving (dialogue torn down / ended elsewhere).
func close() -> void:
	_session += 1
	_locked = true
	_dragging = false
	visible = false

# --- setup -----------------------------------------------------------------------

func _build_word_list(picked: Array) -> void:
	for child in _word_list.get_children():
		_word_list.remove_child(child)   # remove before free: avoids stale-cell layout
		child.queue_free()
	_entries.clear()
	for entry in picked:
		var word: String = WordBank.puzzle_word(entry["id"])
		var label := Label.new()
		label.text = word
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_M)
		label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
		_word_list.add_child(label)
		_entries.append({"id": entry["id"], "word": word, "letters": entry["letters"], "found": false, "label": label})

func _build_layout() -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	add_child(hbox)

	var grid_holder := CenterContainer.new()
	hbox.add_child(grid_holder)
	_grid = Grid.new()
	_grid.panel = self
	_grid.custom_minimum_size = Vector2(COLS, ROWS) * CELL_SIZE
	_grid.drag_started.connect(_on_drag_started)
	_grid.drag_moved.connect(_on_drag_moved)
	_grid.drag_ended.connect(_on_drag_ended)
	grid_holder.add_child(_grid)

	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 4)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(side)

	var top := HBoxContainer.new()
	side.add_child(top)
	var title := Label.new()
	title.text = "Word Search"
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

	_word_list = VBoxContainer.new()
	_word_list.add_theme_constant_override("separation", 4)
	_word_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(_word_list)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
	side.add_child(_status_label)

# --- flow ------------------------------------------------------------------------

## Physical keys only matter for ui_cancel (Esc, Android back), but all are
## swallowed so they can't fire gameplay actions like "interact" behind the panel.
func _input(event: InputEvent) -> void:
	if not visible or BookUI.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_quit()
	elif event is InputEventKey:
		get_viewport().set_input_as_handled()

func _cell_color(cell: Vector2i) -> Color:
	if _wrong_cells.has(cell):
		return UIThemeApplier.COLOR_ERROR
	if _selection.has(cell):
		return COLOR_SELECTED
	if _found_cells.has(cell):
		return UIThemeApplier.COLOR_SUCCESS
	return COLOR_CELL

func _on_drag_started(cell: Vector2i) -> void:
	if _locked:
		return
	_dragging = true
	_drag_start = cell
	_selection = [cell]
	_grid.queue_redraw()

func _on_drag_moved(cell: Vector2i) -> void:
	if not _dragging:
		return
	_selection = _line_to(cell)
	_grid.queue_redraw()

func _on_drag_ended() -> void:
	if not _dragging:
		return
	_dragging = false
	_check_selection()
	_grid.queue_redraw()

## Cells from the drag start toward `cell`, snapped to the nearest of the 8
## straight directions and cut off at the grid edge.
func _line_to(cell: Vector2i) -> Array:
	var delta: Vector2i = cell - _drag_start
	var length: int = maxi(absi(delta.x), absi(delta.y))
	if length == 0:
		return [_drag_start]
	var angle: float = snappedf(Vector2(delta).angle(), PI / 4.0)
	var dir := Vector2i(roundi(cos(angle)), roundi(sin(angle)))
	var line: Array = []
	for i in range(length + 1):
		var at: Vector2i = _drag_start + dir * i
		if at.x < 0 or at.y < 0 or at.x >= COLS or at.y >= ROWS:
			break
		line.append(at)
	return line

## Found or wrong, read from either end of the line. A single cell is just a
## tap or a change of mind.
func _check_selection() -> void:
	var typed: String = ""
	for cell in _selection:
		typed += _grid_letters[cell.y][cell.x]
	if typed.length() < 2:
		_selection.clear()
		return
	var reversed: String = typed.reverse()
	for entry in _entries:
		if not entry["found"] and (typed == entry["letters"] or reversed == entry["letters"]):
			_on_word_found(entry)
			return
	_flash_wrong()

func _on_word_found(entry: Dictionary) -> void:
	entry["found"] = true
	GameState.adjust_mastery(entry["id"], 1)
	for cell in _selection:
		_found_cells[cell] = true
	_selection.clear()
	var gloss: String = WordBank.get_word(entry["id"]).get("gloss", "")
	entry["label"].text = "%s = %s" % [entry["word"], gloss]
	entry["label"].add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
	entry["label"].add_theme_color_override("font_color", UIThemeApplier.COLOR_SUCCESS)
	if _entries.all(func(e): return e["found"]):
		_end_game()

func _flash_wrong() -> void:
	_locked = true
	_wrong_cells = _selection.duplicate()
	_selection.clear()
	var session: int = _session
	await get_tree().create_timer(WRONG_HOLD).timeout
	if session != _session:
		return
	_wrong_cells.clear()
	_grid.queue_redraw()
	_locked = false

func _end_game() -> void:
	_locked = true
	_status_label.text = "Insakto! All words found."
	_status_label.add_theme_color_override("font_color", UIThemeApplier.COLOR_SUCCESS)
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
	_dragging = false
	_emit_resolved(false)

func _emit_resolved(passed: bool) -> void:
	resolved.emit(passed)
