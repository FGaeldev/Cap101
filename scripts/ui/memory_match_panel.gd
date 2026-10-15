# memory_match_panel.gd -- flip-card matching minigame (akeanon word <-> gloss).
#
# Driven by a dialogue line of type "minigame_trigger", minigame_type "memory_match":
#   {
#     "type": "minigame_trigger", "minigame_type": "memory_match",
#     "word_pool": ["w090", "w054", "w227"],  # word_ids a pair may use (required)
#     "pair_count": 4,                         # optional, default 4, max 6
#     "max_mistakes": 8,                       # optional, default pair_count * 2
#     "success": 21, "failure": 22
#   }
#
# Each pair = one card showing the akeanon word + one showing its English gloss.
# Flip two: match stays face-up, mismatch counts as a mistake and flips back.
# All pairs matched with mistakes <= max_mistakes -> success. Over the limit
# -> failure (immediate). No rapport/patience/reward effects: no-punishment
# rule (GDD 7), failure just routes to the authored "try again later" line.
#
# Pair words are drawn weighted by WordBank.get_weighted_review_word (GDD 6.8),
# so low-exposure words show up more.
#
# Ownership: renders and reports only. Emits `resolved(passed)`; DialogueUI
# forwards it to the owning DialogueComponent. Bad data never softlocks:
# reports and resolves as a pass.
extends PanelContainer

## Emitted once, after the end-of-game feedback hold.
signal resolved(passed: bool)

## Pair count when the line sets none.
const DEFAULT_PAIR_COUNT: int = 4
## Hard cap: more cards than this stop fitting the dialogue-height footprint.
const MAX_PAIR_COUNT: int = 6
## Seconds a mismatched pair stays visible before flipping back.
const MISMATCH_HOLD: float = 0.8
## Seconds the final win/lose message shows before resolving.
const END_HOLD: float = 1.2
## Card back text.
const CARD_BACK_TEXT: String = "?"
## Cards are laid out in this many rows; columns = ceil(cards / rows).
const GRID_ROWS: int = 2
## Minimum card height (px).
const CARD_MIN_HEIGHT: float = 30.0
## Gloss fallback when a word has none yet.
const GLOSS_FALLBACK: String = "(pending)"

var _cards: Array = []            # [{pair_id, text, btn, matched}]
var _flipped: Array = []          # card indices currently face-up and unresolved (0-2)
var _matched_pairs: int = 0
var _pair_total: int = 0
var _mistakes: int = 0
var _max_mistakes: int = 0
var _locked: bool = true          # true while resolving a mismatch / closed
var _session: int = 0             # bumped on open/close; stale timers bail

var _status_label: Label
var _card_grid: GridContainer

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

## Start the game for one minigame_trigger line. Safe to call repeatedly.
func open(line: Dictionary) -> void:
	_session += 1
	_flipped.clear()
	_matched_pairs = 0
	_mistakes = 0

	var pair_ids: Array = _pick_pairs(line)
	if pair_ids.is_empty():
		push_error("MemoryMatch: no valid words in 'word_pool', auto-passing.")
		call_deferred("_emit_resolved", true)
		return

	_pair_total = pair_ids.size()
	_max_mistakes = int(line.get("max_mistakes", _pair_total * 2))
	_build_cards(pair_ids)
	_refresh_status("Match each word with its meaning")
	_locked = false
	visible = true

## Hide without resolving (dialogue torn down / ended elsewhere).
func close() -> void:
	_session += 1
	_locked = true
	visible = false

# --- setup -----------------------------------------------------------------------

## Draws up to pair_count distinct, valid word ids from word_pool, weighted.
func _pick_pairs(line: Dictionary) -> Array:
	var pool: Array = []
	for raw in line.get("word_pool", []):
		var id: String = str(raw).strip_edges()
		if id.is_empty() or pool.has(id):
			continue
		if WordBank.get_word(id).is_empty():
			push_warning("MemoryMatch: unknown word id '%s' dropped." % id)
			continue
		pool.append(id)

	var count: int = clampi(int(line.get("pair_count", DEFAULT_PAIR_COUNT)), 1, MAX_PAIR_COUNT)
	count = mini(count, pool.size())

	var picked: Array = []
	while picked.size() < count:
		var remaining: Array = pool.filter(func(id): return not picked.has(id))
		picked.append(WordBank.get_weighted_review_word(remaining))
	return picked

## Two cards per pair (word + gloss), shuffled into the grid.
func _build_cards(pair_ids: Array) -> void:
	for child in _card_grid.get_children():
		_card_grid.remove_child(child)   # remove before free: avoids stale-cell layout
		child.queue_free()
	_cards.clear()

	var defs: Array = []
	for id in pair_ids:
		var word: Dictionary = WordBank.get_word(id)
		var gloss: String = str(word.get("gloss", "")).strip_edges()
		defs.append({"pair_id": id, "text": str(word.get("akeanon", "???"))})
		defs.append({"pair_id": id, "text": gloss if not gloss.is_empty() else GLOSS_FALLBACK})
	defs.shuffle()

	_card_grid.columns = ceili(float(defs.size()) / GRID_ROWS)
	for i in range(defs.size()):
		var btn := Button.new()
		btn.text = CARD_BACK_TEXT
		btn.custom_minimum_size = Vector2(0, CARD_MIN_HEIGHT)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UIThemeApplier.apply_button_theme(btn, "primary")
		btn.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
		btn.pressed.connect(_on_card_pressed.bind(i))
		_card_grid.add_child(btn)
		_cards.append({"pair_id": defs[i]["pair_id"], "text": defs[i]["text"], "btn": btn, "matched": false})

func _build_layout() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 3)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
	_status_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	vbox.add_child(_status_label)

	_card_grid = GridContainer.new()
	_card_grid.add_theme_constant_override("h_separation", 3)
	_card_grid.add_theme_constant_override("v_separation", 3)
	_card_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_card_grid)

# --- flow ------------------------------------------------------------------------

func _on_card_pressed(idx: int) -> void:
	if _locked:
		return
	var card: Dictionary = _cards[idx]
	if card["matched"] or _flipped.has(idx):
		return

	_face_up(idx)
	_flipped.append(idx)
	if _flipped.size() < 2:
		return

	_locked = true
	var a: Dictionary = _cards[_flipped[0]]
	var b: Dictionary = _cards[_flipped[1]]

	if a["pair_id"] == b["pair_id"]:
		_mark_matched(_flipped[0])
		_mark_matched(_flipped[1])
		_flipped.clear()
		_matched_pairs += 1
		if _matched_pairs >= _pair_total:
			_end_game(true)
		else:
			_refresh_status()
			_locked = false
		return

	_mistakes += 1
	_flash(a["btn"], UIThemeApplier.COLOR_ERROR)
	_flash(b["btn"], UIThemeApplier.COLOR_ERROR)
	_refresh_status()
	if _mistakes > _max_mistakes:
		_end_game(false)
		return

	var session: int = _session
	await get_tree().create_timer(MISMATCH_HOLD).timeout
	if session != _session:
		return   # closed or reopened during the hold
	for fi in _flipped:
		_face_down(fi)
	_flipped.clear()
	_locked = false

func _end_game(passed: bool) -> void:
	_locked = true
	if passed:
		_status_label.text = "Insakto! All pairs matched."
		_status_label.add_theme_color_override("font_color", UIThemeApplier.COLOR_SUCCESS)
	else:
		_status_label.text = "Too many misses."
		_status_label.add_theme_color_override("font_color", UIThemeApplier.COLOR_ERROR)

	var session: int = _session
	await get_tree().create_timer(END_HOLD).timeout
	if session != _session:
		return
	_emit_resolved(passed)

func _emit_resolved(passed: bool) -> void:
	resolved.emit(passed)

# --- card visuals ----------------------------------------------------------------

func _face_up(idx: int) -> void:
	var card: Dictionary = _cards[idx]
	card["btn"].text = card["text"]
	card["btn"].modulate = Color.WHITE

func _face_down(idx: int) -> void:
	var card: Dictionary = _cards[idx]
	card["btn"].text = CARD_BACK_TEXT
	card["btn"].modulate = Color.WHITE

func _mark_matched(idx: int) -> void:
	var card: Dictionary = _cards[idx]
	card["matched"] = true
	card["btn"].disabled = true
	_flash(card["btn"], UIThemeApplier.COLOR_SUCCESS)

## Tint only, never swap the button texture (same approach as puzzle_panel).
func _flash(btn: Button, color: Color) -> void:
	btn.modulate = Color(color.r, color.g, color.b, 0.5)
	btn.add_theme_color_override("font_color_disabled", UIThemeApplier.TEXT_DEFAULT)

func _refresh_status(message: String = "") -> void:
	_status_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	var counts: String = "Pairs %d/%d   Misses %d/%d" % [_matched_pairs, _pair_total, _mistakes, _max_mistakes]
	_status_label.text = counts if message.is_empty() else "%s\n%s" % [message, counts]
