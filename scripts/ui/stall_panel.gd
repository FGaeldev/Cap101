# stall_panel.gd -- "Help at the stall": serve customers at Nong Pedring's stall.
#
# Driven by a line of minigame_type "stall" (StallHelper builds it):
#   { "minigame_type": "stall",
#     "stock": ["bugas", "uga", "isda", "tubi"],   # item ids with Akeanon words
#     "price_items": ["uga", "isda", "tubi"],      # items sold by the piece
#     "customers": 5, "max_misses": 3 }
# Writes line["served"] (customers served) before resolving, for the pay.
#
# Two kinds of customer (docs/MINIGAMES_PLAN.md, lines reviewed 2026-11-22):
#   request: "Pangabay it {item}, gha." -> tap the right goods.
#   price:   "Tig pila ro {item}, gha?" -> tap that item's row on the price
#            board (the player says the price), tap "Pilang bato?", the customer
#            says "Tatlong bato." -> tap the count.
# Misses cost (rule change 2026-11-22): a wrong tap sends the customer away
# unpaid, and max_misses ends the shift early. Money already held is never taken.
# Hidden mastery +1 on the item word for each customer served.
#
# Ownership: renders and reports only, same contract as hangman_panel.
# Bad data never softlocks: reports and resolves as a pass.
extends PanelContainer

## Emitted once, after the end-of-shift hold.
signal resolved(passed: bool)

const DEFAULT_CUSTOMERS: int = 5
const DEFAULT_MAX_MISSES: int = 3
## Counts a price customer can ask for. 1 is left out: its "bato" form is unreviewed.
const COUNT_MIN: int = 2
const COUNT_MAX: int = 5
## Share of customers who ask the price instead of naming the item.
const PRICE_CHANCE: float = 0.5
## Seconds between a customer's last line and the next customer.
const NEXT_HOLD: float = 1.4
const END_HOLD: float = 2.0
const BATO_WORD_ID: String = "w369"

var _line: Dictionary = {}
var _stock: Array = []
var _price_items: Array = []
var _customers: int = DEFAULT_CUSTOMERS
var _max_misses: int = DEFAULT_MAX_MISSES
var _index: int = 0               # customer number, 0-based
var _served: int = 0
var _misses: int = 0
var _item: String = ""            # what this customer wants
var _count: int = 0               # how many (price customers)
var _locked: bool = true
var _session: int = 0

var _status: Label
var _speaker: Label
var _text: RichTextLabel
var _reply: RichTextLabel
var _hint: Label
var _buttons: HFlowContainer

func _ready() -> void:
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 0.5
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_right = 0.0
	offset_top = 0.0
	offset_bottom = 0.0
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UIThemeApplier.make_dialogue_style())
	_build_layout()
	HelpButton.pin(self, "stall")
	visible = false

# --- public API ----------------------------------------------------------------

func open(line: Dictionary) -> void:
	_session += 1
	_line = line
	_stock = Array(line.get("stock", [])).filter(func(id): return _has_word(str(id)))
	_price_items = Array(line.get("price_items", [])).filter(func(id): return _stock.has(id))
	if _stock.size() < 2:
		push_error("Stall: fewer than 2 items with Akeanon words, auto-passing.")
		line["served"] = 0
		call_deferred("_emit_resolved", true)
		return
	_customers = int(line.get("customers", DEFAULT_CUSTOMERS))
	_max_misses = int(line.get("max_misses", DEFAULT_MAX_MISSES))
	_index = 0
	_served = 0
	_misses = 0
	visible = true
	_next_customer()

func close() -> void:
	_session += 1
	_locked = true
	visible = false

## Autoplay/test hook: what the current customer wants.
func expected() -> Dictionary:
	return {"item": _item, "count": _count}

# --- layout ----------------------------------------------------------------------

func _build_layout() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 4)
	add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_XS)
	_status.add_theme_color_override("font_color", UIThemeApplier.TEXT_DISABLED)
	vbox.add_child(_status)

	_speaker = Label.new()
	_speaker.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
	_speaker.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	vbox.add_child(_speaker)

	_text = _rich(UIThemeApplier.FONT_SIZE_M)
	vbox.add_child(_text)
	_reply = _rich(UIThemeApplier.FONT_SIZE_S)
	vbox.add_child(_reply)

	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_XS)
	_hint.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_hint)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	_buttons = HFlowContainer.new()
	_buttons.add_theme_constant_override("h_separation", 4)
	_buttons.add_theme_constant_override("v_separation", 4)
	vbox.add_child(_buttons)

func _rich(font_size: int) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_size_override("normal_font_size", font_size)
	r.add_theme_color_override("default_color", UIThemeApplier.TEXT_DEFAULT)
	return r

func _button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 26)
	UIThemeApplier.apply_button_theme(b, "secondary")
	b.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
	b.pressed.connect(func():
		if _locked:
			return
		AudioManager.play_sfx("menu_click")
		on_press.call())
	_buttons.add_child(b)
	return b

func _clear_buttons() -> void:
	for child in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()

# --- customers -------------------------------------------------------------------

func _next_customer() -> void:
	if _index >= _customers or _misses >= _max_misses:
		_end_shift()
		return
	_item = ""
	_count = 0
	_reply.text = ""
	_refresh_status()
	var price: bool = not _price_items.is_empty() and randf() < PRICE_CHANCE
	if price:
		_item = _price_items.pick_random()
		_show("stall_price_ask", {"item": _item})
		_hint.text = "Tell them the price: tap that item on the board."
		_show_board()
	else:
		_item = _stock.pick_random()
		_show("stall_ask", {"item": _item})
		_hint.text = "Hand over what they asked for."
		_show_goods()
	_locked = false

func _show(key: String, tokens: Dictionary = {}) -> void:
	var l: Dictionary = Economy.line(key, tokens)
	_speaker.text = TextUtil.resolve_speaker(str(l.get("speaker", "")))
	_text.text = TextUtil.resolve_rich(str(l.get("text", "")))
	Economy.expose_line_words(l)

func _say_reply(text: String, word_ids: Array) -> void:
	_reply.text = "%s: %s" % [TextUtil.resolve_speaker("Player"), TextUtil.resolve_rich(text)]
	Economy.expose_line_words({"word_ids": word_ids})

## Request customers: the goods, Akeanon word only.
func _show_goods() -> void:
	_clear_buttons()
	for item_id: String in _stock:
		_button(Economy.item_word(item_id), _on_goods.bind(item_id))

func _on_goods(item_id: String) -> void:
	if item_id == _item:
		_serve()
	else:
		_miss()

## Price customers, step 1: the board, each item's word and price.
func _show_board() -> void:
	_clear_buttons()
	for item_id: String in _stock:
		_button("%s  ₱%d" % [Economy.item_word(item_id), _price_of(item_id)], _on_board.bind(item_id))

func _on_board(item_id: String) -> void:
	if item_id != _item:
		_miss()
		return
	var phrase: Dictionary = Economy.price_phrase(_price_of(_item))
	_say_reply(str(phrase["text"]) + ".", phrase["word_ids"])
	_hint.text = "Ask how many they want."
	_clear_buttons()
	var ask: Dictionary = Economy.line("stall_how_many")
	_button(TextUtil.resolve(str(ask["text"])), _on_how_many)

## Step 2: "Pilang bato?" -> the customer says a count.
func _on_how_many() -> void:
	var ask: Dictionary = Economy.line("stall_how_many")
	_say_reply(str(ask["text"]), ask["word_ids"])
	_count = randi_range(COUNT_MIN, COUNT_MAX)
	var count: Dictionary = count_phrase(_count)
	_speaker.text = TextUtil.resolve_speaker("Customer")
	_text.text = TextUtil.resolve_rich(str(count["text"]) + ".")
	Economy.expose_line_words(count)
	_hint.text = "How many pieces?"
	_clear_buttons()
	for n in range(1, COUNT_MAX + 2):
		_button(str(n), _on_count.bind(n))

func _on_count(n: int) -> void:
	if n == _count:
		_serve()
	else:
		_miss()

## "Tatlong bato" / "Ap-at nga bato": joined like Economy.price_phrase joins piso.
static func count_phrase(n: int) -> Dictionary:
	var word: String = Economy.number_word(n)
	var shown: String = word.left(1).to_upper() + word.substr(1)
	if "aeiou".contains(word.right(1)):
		return {"text": "\\%sng \\bato" % shown, "word_ids": [Economy.number_word_id(n), BATO_WORD_ID]}
	return {"text": "\\%s \\nga \\bato" % shown,
			"word_ids": [Economy.number_word_id(n), Economy.NGA_WORD_ID, BATO_WORD_ID]}

func _serve() -> void:
	_locked = true
	_served += 1
	var wid: String = str(Economy.get_item(_item).get("akeanon_word_id", ""))
	if not wid.is_empty():
		GameState.adjust_mastery(wid, 1)
	_show("stall_thanks")
	_hint.text = "Served!"
	_finish_customer()

func _miss() -> void:
	_locked = true
	_misses += 1
	AudioManager.play_sfx("wrong")
	_speaker.text = ""
	_text.text = "The customer shakes their head and walks off."
	_hint.text = "Missed: %s was what they wanted." % Economy.item_word(_item) if _count == 0 \
			else "Missed: they wanted %d." % _count
	_finish_customer()

func _finish_customer() -> void:
	_clear_buttons()
	_index += 1
	_refresh_status()
	var session: int = _session
	await get_tree().create_timer(NEXT_HOLD).timeout
	if session != _session:
		return
	_next_customer()

func _end_shift() -> void:
	_locked = true
	_clear_buttons()
	_speaker.text = ""
	_reply.text = ""
	var early: bool = _misses >= _max_misses and _index < _customers
	_text.text = "Shift over. You served %d of %d customers." % [_served, _index]
	_hint.text = "Too many missed customers ended the shift early." if early else ""
	_line["served"] = _served
	var session: int = _session
	await get_tree().create_timer(END_HOLD).timeout
	if session != _session:
		return
	_emit_resolved(_served > 0)

func _emit_resolved(passed: bool) -> void:
	resolved.emit(passed)

func _refresh_status() -> void:
	_status.text = "Customer %d of %d  ·  Served %d  ·  Misses %d/%d" % [
			mini(_index + 1, _customers), _customers, _served, _misses, _max_misses]

func _price_of(item_id: String) -> int:
	return int(Economy.get_item(item_id).get("base_price", 0))

func _has_word(item_id: String) -> bool:
	return not str(Economy.get_item(item_id).get("akeanon_word_id", "")).is_empty()
