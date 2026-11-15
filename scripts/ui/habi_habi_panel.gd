# habi_habi_panel.gd -- "Habi-Habi", Manang Loleng's word-weaving game: the
# replayable loom activity in the Haboean gallery after Chapter 3's story.
#
# Loleng calls a word (Akeanon + English, shown the whole time). The player
# traces its letters across a grid of thread-spool tiles; adjacent tiles in any
# of the 8 directions connect. A correct trace weaves one row of cloth in the
# word's thread colour, its tiles drop out and new ones fall in. Each word has a
# time limit (the shuttle crossing the loom), shorter every stage: hinay -> paspas.
# Running out of time leaves a crooked row; the game always moves on.
#
# Driven by a dialogue line of type "minigame_trigger", minigame_type "habi_habi":
#   {
#     "type": "minigame_trigger", "minigame_type": "habi_habi",
#     "word_pool": ["w199", "w031", ...],      # words Loleng may call (A-Z spellings)
#     "word_colors": {"w199": "ffffff"},      # optional thread colour per word
#     "stages": [{"name": "hinay", "seconds": 10, "words": 3},   # optional
#                {"name": "", "seconds": 7, "words": 3},
#                {"name": "paspas", "seconds": 5, "words": 3}],
#     "between_stages": ["Dasigi it sangkiri.", "Paspas!"],  # optional, Loleng after stage i
#     "pass_ratio": 0.6,                      # optional, share of clean rows to pass
#     "grid_size": 5,                          # optional, 4-6
#     "success": 2, "failure": 3
#   }
#
# Input: drag across tiles and let go; or tap tiles one by one and tap the last
# again (or Weave); or type the letters and press Enter. Tapping the previous
# tile steps back. Words are picked weighted toward ones the player sees least
# (WordBank.get_weighted_review_word), a correct row is +1 mastery, and a fully
# clean cloth sets the "habi_habi_clean_cloth" flag (for Journal designs later).
# No rapport/patience/reward effects (no-punishment rule, GDD 7). Bad data never
# softlocks: it reports and resolves as a pass.
extends PanelContainer

signal resolved(passed: bool)

const DEFAULT_STAGES: Array = [
	{"name": "hinay", "seconds": 13.0, "words": 3},
	{"name": "", "seconds": 10.0, "words": 3},
	{"name": "paspas", "seconds": 8.0, "words": 3},
]
## Seconds Loleng's line between stages stays up before the next word.
const STAGE_HOLD: float = 1.6
const DEFAULT_PASS_RATIO: float = 0.6
const DEFAULT_GRID: int = 5
const MIN_LETTERS: int = 3
const CLEAN_CLOTH_FLAG: String = "habi_habi_clean_cloth"
const TILE_SIZE: float = 38.0
const TILE_GAP: int = 4
const ROW_HOLD: float = 0.9
const MISS_HOLD: float = 1.6
const END_HOLD: float = 2.0
const LOOM_WOOD := Color("7a5230")
const CLOTH_BG := Color("f3e6c8")
const MISS_COLOR := Color("8a8079")
## Thread colours for words with no colour of their own.
const THREADS: Array = ["c0392b", "1e5fd0", "e0a800", "2e9e44", "8e44ad", "d35400", "16a085"]
## Tile thread tints, one per column, so the board reads like a warp of threads.
## Mid-tones: dark letters on them stay well above 7:1 contrast.
const WARP: Array = ["e8c393", "dca5bf", "a9c8e3", "bcd9a4", "ecd27a", "d6b494"]
## Tile states. Traced tiles go dark with light letters so the path stands out
## against the light board; result flashes use deep fills for the same reason.
const TILE_INK := Color("2b1a10")
const TILE_INK_ON_DARK := Color("fff8ec")
const TRACE_FILL := Color("4a2c14")
const OK_FILL := Color("2e7d32")
const BAD_FILL := Color("b3261e")
const ANSWER_FILL := Color("f2c14e")
## Feedback text on the light panel (the theme's success green is too pale here).
const OK_TEXT := Color("256b2c")
const BAD_TEXT := Color("9e2a2a")
const OK_TEXT_CB := Color("005a8c")
const BAD_TEXT_CB := Color("a3470a")
## Woven rows get a dark edge so white and yellow threads show on the cloth.
const ROW_EDGE := Color("3b2a1a")

var _pool: Array = []              # playable word ids
var _letters_of: Dictionary = {}   # word id -> uppercase letters
var _colors: Dictionary = {}       # word id -> Color
var _stages: Array = []
var _between: Array = []
var _pass_ratio: float = DEFAULT_PASS_RATIO
var _n: int = DEFAULT_GRID
var _letter_bag: String = ""

var _grid: Array = []              # [_n * _n] uppercase letters, index = y * _n + x
var _path: Array = []              # traced cell indices
var _dragging: bool = false
var _dragged: bool = false
var _typed: String = ""

var _stage: int = 0
var _word_in_stage: int = 0
var _target: String = ""
var _used: Array = []
var _time_left: float = 0.0
var _limit: float = 1.0
var _live: bool = false
var _clean: int = 0
var _rows_total: int = 0
var _score: int = 0
var _session: int = 0
var _thread_i: int = 0

var _title: Label
var _call_word: Label
var _call_gloss: Label
var _feedback: Label
var _trace_label: Label
var _shuttle_track: Control
var _shuttle: ColorRect
var _board: Control
var _tiles: Array = []             # PanelContainer per cell
var _tile_labels: Array = []
var _cloth: VBoxContainer
var _score_label: Label
var _weave_btn: Button
var _clear_btn: Button

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UIThemeApplier.make_dialogue_style())
	_build_layout()
	HelpButton.pin(self, "habi_habi")
	visible = false
	set_process(false)

# --- public API ----------------------------------------------------------------

func open(line: Dictionary) -> void:
	_session += 1
	_pool.clear()
	_letters_of.clear()
	_colors.clear()
	_n = clampi(int(line.get("grid_size", DEFAULT_GRID)), 4, 6)
	var hexes: Dictionary = line.get("word_colors", {})
	for raw in line.get("word_pool", []):
		var id: String = str(raw).strip_edges()
		var letters: String = WordBank.puzzle_letters(id) if not WordBank.get_word(id).is_empty() else ""
		if letters.length() < MIN_LETTERS or letters.length() > _n * _n - 2 or _pool.has(id):
			continue
		_pool.append(id)
		_letters_of[id] = letters
		_colors[id] = Color(str(hexes[id])) if hexes.has(id) else Color(THREADS[_pool.size() % THREADS.size()])
	if _pool.size() < 2:
		push_error("HabiHabi: needs 2+ playable words in word_pool, auto-passing.")
		call_deferred("_emit_resolved", true)
		return
	_stages = line.get("stages", DEFAULT_STAGES)
	if _stages.is_empty():
		_stages = DEFAULT_STAGES
	_between = line.get("between_stages", [])
	_pass_ratio = clampf(float(line.get("pass_ratio", DEFAULT_PASS_RATIO)), 0.0, 1.0)
	_letter_bag = "".join(_letters_of.values())
	_stage = 0
	_word_in_stage = 0
	_clean = 0
	_rows_total = 0
	_score = 0
	_used.clear()
	for child in _cloth.get_children():
		_cloth.remove_child(child)
		child.queue_free()
	_build_board()
	_fill_random()
	visible = true
	_score_label.text = "Score 0"
	_next_word()

func close() -> void:
	_session += 1
	_live = false
	_dragging = false
	set_process(false)
	visible = false

# --- flow ------------------------------------------------------------------------

func _next_word() -> void:
	if _word_in_stage >= int(_stages[_stage].get("words", 3)):
		_stage += 1
		_word_in_stage = 0
		if _stage >= _stages.size():
			_end_game()
			return
		# Loleng speeds the player up between stages.
		var say: String = str(_between[_stage - 1]) if _stage - 1 < _between.size() else ""
		if not say.is_empty():
			var session := _session
			_clear_path()
			_feedback.text = "Manang Loleng: " + say
			_feedback.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
			await get_tree().create_timer(STAGE_HOLD).timeout
			if session != _session:
				return
	var stage: Dictionary = _stages[_stage]
	var stage_name: String = str(stage.get("name", ""))
	_title.text = "Habi-Habi  ·  stage %d of %d%s" % [_stage + 1, _stages.size(),
			("  ·  " + stage_name) if not stage_name.is_empty() else ""]
	_target = _pick_word()
	_used.append(_target)
	_call_word.text = WordBank.puzzle_word(_target).capitalize()
	_call_word.add_theme_color_override("font_color", Accessibility.akeanon_color())
	_call_gloss.text = str(WordBank.get_word(_target).get("gloss", ""))
	_feedback.text = ""
	_ensure_spellable(_letters_of[_target])
	_clear_path()
	_limit = maxf(1.0, float(stage.get("seconds", 10.0)))
	_time_left = _limit
	_live = true
	set_process(true)

func _pick_word() -> String:
	var fresh: Array = _pool.filter(func(id): return not _used.has(id))
	if fresh.is_empty():
		fresh = _pool.filter(func(id): return id != _target)
	return WordBank.get_weighted_review_word(fresh)

func _process(delta: float) -> void:
	if not _live:
		return
	_time_left -= delta
	_set_shuttle(1.0 - _time_left / _limit)
	if _time_left <= 0.0:
		_time_out()

func _submit() -> void:
	if not _live or _path.size() < 2:
		return
	var word: String = _path_word()
	if word == _letters_of[_target]:
		_woven()
	else:
		_feedback.text = "%s isn't it. Try again." % word.capitalize()
		_feedback.add_theme_color_override("font_color", _bad_text())
		_flash_path(BAD_FILL)
		var session := _session
		await get_tree().create_timer(0.35).timeout
		if session == _session:
			_clear_path()

func _woven() -> void:
	_live = false
	set_process(false)
	var session := _session
	var letters: String = _letters_of[_target]
	_clean += 1
	_rows_total += 1
	var points: int = letters.length() * 10 * (_stage + 1) + int(ceil(_time_left)) * 2
	_score += points
	_score_label.text = "Score %d" % _score
	GameState.adjust_mastery(_target, 1)
	AudioManager.play_sfx("advance")
	_feedback.text = "Mayad!  +%d" % points
	_feedback.add_theme_color_override("font_color", _ok_text())
	_add_row(_colors[_target], false)
	_flash_path(OK_FILL)
	await get_tree().create_timer(ROW_HOLD).timeout
	if session != _session:
		return
	_drop_path_tiles()
	_word_in_stage += 1
	_next_word()

func _time_out() -> void:
	_live = false
	set_process(false)
	var session := _session
	_rows_total += 1
	_feedback.text = "Hinay-hinay…  It's spelled %s." % _letters_of[_target]
	_feedback.add_theme_color_override("font_color", _bad_text())
	_add_row(MISS_COLOR, true)
	_show_answer()
	await get_tree().create_timer(MISS_HOLD).timeout
	if session != _session:
		return
	_word_in_stage += 1
	_next_word()

func _end_game() -> void:
	var session := _session
	var passed: bool = _rows_total == 0 or float(_clean) / _rows_total >= _pass_ratio
	if _clean == _rows_total and _rows_total > 0:
		GameState.set_flag(CLEAN_CLOTH_FLAG)
	_title.text = "Habi-Habi  ·  %d of %d rows woven clean" % [_clean, _rows_total]
	_call_word.text = "Mayad!" if passed else "Hinay-hinay"
	_call_gloss.text = "a whole piece of cloth" if passed else "a little crooked, but it's cloth"
	_feedback.text = "Score %d" % _score
	_feedback.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	_clear_path()
	await get_tree().create_timer(END_HOLD).timeout
	if session != _session:
		return
	_emit_resolved(passed)

func _emit_resolved(passed: bool) -> void:
	resolved.emit(passed)

# --- grid logic --------------------------------------------------------------------

func _fill_random() -> void:
	_grid.resize(_n * _n)
	for i in _grid.size():
		_grid[i] = _random_letter()
	_refresh_tiles()

func _random_letter() -> String:
	return _letter_bag[randi() % _letter_bag.length()]

## Letters of the traced cells fall out; the column above drops down; new
## letters thread in at the top.
func _drop_path_tiles() -> void:
	var gone: Dictionary = {}
	for idx in _path:
		gone[idx] = true
	for x in _n:
		var keep: Array = []
		for y in range(_n - 1, -1, -1):
			var i: int = y * _n + x
			if not gone.has(i):
				keep.append(_grid[i])
		for y in range(_n - 1, -1, -1):
			var k: int = _n - 1 - y
			_grid[y * _n + x] = keep[k] if k < keep.size() else _random_letter()
	_path.clear()
	_refresh_tiles()

## Makes sure `word` can be traced; if not, Loleng re-threads one random path.
func _ensure_spellable(word: String) -> void:
	if not _find_path(word).is_empty():
		_refresh_tiles()
		return
	for _attempt in 40:
		var path: Array = _random_walk(word.length())
		if path.size() == word.length():
			for i in path.size():
				_grid[path[i]] = word[i]
			break
	_refresh_tiles()

func _random_walk(length: int) -> Array:
	var start: int = randi() % (_n * _n)
	return _walk_from([start], length)

func _walk_from(path: Array, length: int) -> Array:
	if path.size() == length:
		return path
	var options: Array = _neighbours(path[-1]).filter(func(c): return not path.has(c))
	options.shuffle()
	for c in options:
		var res: Array = _walk_from(path + [c], length)
		if not res.is_empty():
			return res
	return []

func _neighbours(idx: int) -> Array:
	var out: Array = []
	var x: int = idx % _n
	var y: int = idx / _n
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var nx: int = x + dx
			var ny: int = y + dy
			if nx >= 0 and ny >= 0 and nx < _n and ny < _n:
				out.append(ny * _n + nx)
	return out

## A traceable path spelling `word`, or [].
func _find_path(word: String) -> Array:
	if word.is_empty():
		return []
	for i in _grid.size():
		if _grid[i] == word[0]:
			var res: Array = _search(word, [i])
			if not res.is_empty():
				return res
	return []

func _search(word: String, path: Array) -> Array:
	if path.size() == word.length():
		return path
	for c in _neighbours(path[-1]):
		if not path.has(c) and _grid[c] == word[path.size()]:
			var res: Array = _search(word, path + [c])
			if not res.is_empty():
				return res
	return []

func _path_word() -> String:
	var s: String = ""
	for idx in _path:
		s += _grid[idx]
	return s

# --- input -------------------------------------------------------------------------

func _on_board_input(event: InputEvent) -> void:
	if not _live:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press(_cell_at(event.position))
		else:
			_dragging = false
			if _dragged and _path.size() >= 2:
				_submit()
	elif event is InputEventMouseMotion and _dragging:
		_drag_over(_cell_at(event.position))

func _press(cell: int) -> void:
	if cell < 0:
		return
	_typed = ""
	_dragging = true
	_dragged = false
	if not _path.is_empty():
		if cell == _path[-1] and _path.size() >= 2:
			_dragging = false
			_submit()
			return
		if _path.size() >= 2 and cell == _path[-2]:
			_path.pop_back()
			_refresh_path()
			return
		if not _path.has(cell) and _neighbours(_path[-1]).has(cell):
			_path.append(cell)
			_refresh_path()
			return
	_path = [cell]
	_refresh_path()

func _drag_over(cell: int) -> void:
	if cell < 0 or _path.is_empty() or cell == _path[-1]:
		return
	if _path.size() >= 2 and cell == _path[-2]:
		_path.pop_back()
		_dragged = true
		_refresh_path()
	elif not _path.has(cell) and _neighbours(_path[-1]).has(cell):
		_path.append(cell)
		_dragged = true
		_refresh_path()

## Board-local position -> cell index; only the inner part of a tile counts while
## dragging, so diagonal moves don't clip a neighbour's corner.
func _cell_at(pos: Vector2) -> int:
	var step: float = TILE_SIZE + TILE_GAP
	var x: int = int(pos.x / step)
	var y: int = int(pos.y / step)
	if x < 0 or y < 0 or x >= _n or y >= _n:
		return -1
	var local := Vector2(pos.x - x * step, pos.y - y * step)
	if local.x >= TILE_SIZE or local.y >= TILE_SIZE:
		return -1  # in the gap between tiles
	var margin: float = TILE_SIZE * 0.18
	var in_core: bool = local.x >= margin and local.y >= margin \
			and local.x <= TILE_SIZE - margin and local.y <= TILE_SIZE - margin
	if _dragging and not _path.is_empty() and not in_core:
		return -1
	return y * _n + x

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _live or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var handled := true
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		var path: Array = _find_path(_typed) if _typed.length() >= 2 else []
		if not path.is_empty():
			_path = path
			_submit()
		elif not _path.is_empty():
			_submit()
		_typed = ""
	elif event.keycode == KEY_BACKSPACE:
		_typed = _typed.left(-1) if _typed.length() > 0 else ""
		_path = _find_path(_typed)
		_refresh_path()
	elif event.keycode == KEY_ESCAPE:
		_clear_path()
	elif event.unicode >= 65 and event.unicode <= 122 and char(event.unicode).to_upper() >= "A" and char(event.unicode).to_upper() <= "Z":
		_typed += char(event.unicode).to_upper()
		_path = _find_path(_typed)
		_refresh_path()
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()

func _clear_path() -> void:
	_path.clear()
	_typed = ""
	_dragging = false
	_refresh_path()

# --- layout & visuals ----------------------------------------------------------------

func _build_layout() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	margin.add_child(outer)

	_title = _label(UIThemeApplier.FONT_SIZE_S, UIThemeApplier.TEXT_DEFAULT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(_title)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 24)
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(hbox)

	# Left: the thread grid, with Weave / Clear under it.
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(left)
	_board = Control.new()
	_board.mouse_filter = Control.MOUSE_FILTER_STOP
	_board.gui_input.connect(_on_board_input)
	left.add_child(_board)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 8)
	left.add_child(buttons)
	_weave_btn = _button("Weave", _submit)
	_clear_btn = _button("Clear", _clear_path)
	buttons.add_child(_weave_btn)
	buttons.add_child(_clear_btn)

	# Right: Loleng's call, the shuttle timer, the trace, and the cloth.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.custom_minimum_size = Vector2(220, 0)
	hbox.add_child(right)
	var who := _label(UIThemeApplier.FONT_SIZE_XS, UIThemeApplier.TEXT_DEFAULT)
	who.text = "Manang Loleng calls:"
	right.add_child(who)
	_call_word = _label(UIThemeApplier.FONT_SIZE_XXL, Accessibility.akeanon_color())
	right.add_child(_call_word)
	_call_gloss = _label(UIThemeApplier.FONT_SIZE_S, UIThemeApplier.TEXT_EMPHASIS)
	right.add_child(_call_gloss)

	_shuttle_track = Control.new()
	_shuttle_track.custom_minimum_size = Vector2(200, 10)
	right.add_child(_shuttle_track)
	var beam := ColorRect.new()
	beam.color = LOOM_WOOD
	beam.anchor_right = 1.0
	beam.anchor_top = 0.5
	beam.anchor_bottom = 0.5
	beam.offset_top = -1
	beam.offset_bottom = 1
	_shuttle_track.add_child(beam)
	_shuttle = ColorRect.new()
	_shuttle.color = Color("c8873a")
	_shuttle.size = Vector2(16, 10)
	_shuttle_track.add_child(_shuttle)

	_trace_label = _label(UIThemeApplier.FONT_SIZE_L, UIThemeApplier.TEXT_DEFAULT)
	_trace_label.custom_minimum_size = Vector2(0, 20)
	right.add_child(_trace_label)
	_feedback = _label(UIThemeApplier.FONT_SIZE_XS, UIThemeApplier.TEXT_DEFAULT)
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.custom_minimum_size = Vector2(200, 30)
	right.add_child(_feedback)

	var loom := PanelContainer.new()
	var frame := StyleBoxFlat.new()
	frame.bg_color = CLOTH_BG
	frame.border_color = LOOM_WOOD
	frame.set_border_width_all(3)
	frame.set_content_margin_all(4)
	loom.add_theme_stylebox_override("panel", frame)
	loom.custom_minimum_size = Vector2(200, 0)
	right.add_child(loom)
	_cloth = VBoxContainer.new()
	_cloth.add_theme_constant_override("separation", 1)
	_cloth.custom_minimum_size = Vector2(0, 9 * 8)
	loom.add_child(_cloth)
	_score_label = _label(UIThemeApplier.FONT_SIZE_XS, UIThemeApplier.TEXT_DEFAULT)
	right.add_child(_score_label)

func _build_board() -> void:
	for child in _board.get_children():
		_board.remove_child(child)
		child.queue_free()
	_tiles.clear()
	_tile_labels.clear()
	var step: float = TILE_SIZE + TILE_GAP
	_board.custom_minimum_size = Vector2(step * _n - TILE_GAP, step * _n - TILE_GAP)
	for i in _n * _n:
		var tile := PanelContainer.new()
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.position = Vector2((i % _n) * step, (i / _n) * step)
		tile.size = Vector2(TILE_SIZE, TILE_SIZE)
		var lbl := Label.new()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_L)
		lbl.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
		tile.add_child(lbl)
		_board.add_child(tile)
		_tiles.append(tile)
		_tile_labels.append(lbl)

func _refresh_tiles() -> void:
	for i in _tiles.size():
		_tile_labels[i].text = _grid[i]
	_refresh_path()

func _refresh_path() -> void:
	for i in _tiles.size():
		if _path.has(i):
			_set_tile(i, TRACE_FILL, TILE_INK_ON_DARK, true)
		else:
			_set_tile(i, Color(WARP[(i % _n) % WARP.size()]), TILE_INK, false)
	var shown: String = _path_word() if not _path.is_empty() else _typed
	_trace_label.text = shown
	_weave_btn.disabled = _path.size() < 2 or not _live

## Fills the traced tiles with a result colour (letters pick light or dark ink).
func _flash_path(fill: Color) -> void:
	var ink: Color = TILE_INK if fill.get_luminance() > 0.5 else TILE_INK_ON_DARK
	for idx in _path:
		_set_tile(idx, fill, ink, true)

## Shows where the word was, after a time-out.
func _show_answer() -> void:
	_path = _find_path(_letters_of[_target])
	_flash_path(ANSWER_FILL)

func _set_tile(i: int, fill: Color, ink: Color, marked: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(10)
	sb.border_color = UIThemeApplier.COLOR_POINTER if marked else LOOM_WOOD
	sb.set_border_width_all(3 if marked else 2)
	_tiles[i].add_theme_stylebox_override("panel", sb)
	_tile_labels[i].add_theme_color_override("font_color", ink)

func _ok_text() -> Color:
	return OK_TEXT_CB if Accessibility.color_blind else OK_TEXT

func _bad_text() -> Color:
	return BAD_TEXT_CB if Accessibility.color_blind else BAD_TEXT

## One woven row, edged so white and yellow threads show on the cream cloth.
func _add_row(color: Color, crooked: bool) -> void:
	var row := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = ROW_EDGE
	sb.set_border_width_all(1)
	row.add_theme_stylebox_override("panel", sb)
	row.custom_minimum_size = Vector2(0, 7)
	if crooked:
		row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		row.custom_minimum_size = Vector2(120, 5)
	_cloth.add_child(row)

func _set_shuttle(t: float) -> void:
	_shuttle.position = Vector2(clampf(t, 0.0, 1.0) * maxf(_shuttle_track.size.x - _shuttle.size.x, 0.0), 0)

func _label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l

func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	UIThemeApplier.apply_button_theme(b, "primary")
	b.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
	b.pressed.connect(cb)
	return b
