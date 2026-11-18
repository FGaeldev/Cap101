# Economy.gd -- autoload. Item data (data/items.json), the economy's lines
# (data/economy_lines.json), and the two money exchanges: paying a price with
# coins (fares, Pedring's stall) and the shop. Money itself is written only by
# RewardManager (award_pesos / spend_pesos); items by GameState.add_item.
# See docs/ECONOMY_PLAN.md. Rules kept here:
#   - paying is a short Akeanon exchange, not a button: the price is said as a
#     number word (1-10), the player counts out coins
#   - a wrong amount just repeats the price with the English, never charges
#   - cancelling never costs anything
extends Node

const ITEMS_PATH := "res://data/items.json"
const LINES_PATH := "res://data/economy_lines.json"
const MarketPanel := preload("res://scripts/ui/market_panel.gd")

## Akeanon number words 1..10 from Chapter 2 (word bank ids, index = number).
const NUMBER_WORD_IDS: Array[String] = ["", "w090", "w054", "w227", "w018", "w123", "w017", "w196", "w244", "w215", "w178"]

var items: Dictionary = {}   # item id -> data
var shops: Dictionary = {}   # shop id -> {vendor, area, stock}
var lines: Dictionary = {}   # line key -> {speaker, text, translation, word_ids}

var _panel: CanvasLayer = null

func _ready() -> void:
	var data: Variant = _read_json(ITEMS_PATH)
	if data is Dictionary:
		items = data.get("items", {})
		shops = data.get("shops", {})
	var line_data: Variant = _read_json(LINES_PATH)
	if line_data is Dictionary:
		lines = line_data

func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Economy: cannot open %s" % path)
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed == null:
		push_error("Economy: %s is not valid JSON" % path)
	return parsed

func get_item(item_id: String) -> Dictionary:
	return items.get(item_id, {})

## The item's Akeanon word from the word bank, or its English name.
func item_word(item_id: String) -> String:
	var word: Dictionary = WordBank.get_word(str(get_item(item_id).get("akeanon_word_id", "")))
	var akeanon: String = str(word.get("akeanon", ""))
	return akeanon.to_lower() if not akeanon.is_empty() else item_name(item_id)

func item_name(item_id: String) -> String:
	return str(get_item(item_id).get("name", item_id))

func is_sellable(item_id: String) -> bool:
	var item: Dictionary = get_item(item_id)
	return item.get("kind", "") != "keepsake" and bool(item.get("sellable", false))

## Akeanon word for 1..10 ("lima"), or "" above that.
func number_word(n: int) -> String:
	if n < 1 or n >= NUMBER_WORD_IDS.size():
		return ""
	return str(WordBank.get_word(NUMBER_WORD_IDS[n]).get("akeanon", "")).to_lower()

func number_word_id(n: int) -> String:
	return NUMBER_WORD_IDS[n] if n >= 1 and n < NUMBER_WORD_IDS.size() else ""

const PISO_WORD_ID := "w335"
const NGA_WORD_ID := "w180"

## A price said in Akeanon (user's rule, economy review 2026-11-18):
##   1                           -> "Piso" alone
##   number word ends in a vowel -> word + "ng piso"  (Limang piso)
##   ends in a consonant         -> word + " nga piso" (Siyam nga piso)
##   above 10                    -> digits + " pisos"   (15 pisos)
## Returns {text (Akeanon marked with \), word_ids}.
func price_phrase(n: int) -> Dictionary:
	if n == 1:
		return {"text": "\\Piso", "word_ids": [PISO_WORD_ID]}  # one peso is just "piso"
	var word: String = number_word(n)
	if word.is_empty():
		return {"text": "%d \\pisos" % n, "word_ids": [PISO_WORD_ID]}
	var shown: String = word.left(1).to_upper() + word.substr(1)
	if "aeiou".contains(word.right(1)):
		return {"text": "\\%sng \\piso" % shown, "word_ids": [number_word_id(n), PISO_WORD_ID]}
	return {"text": "\\%s \\nga \\piso" % shown, "word_ids": [number_word_id(n), NGA_WORD_ID, PISO_WORD_ID]}

## A line from economy_lines.json with its tokens filled. Returns a copy:
## {speaker, text, translation, word_ids}. Number words are marked as Akeanon
## and their ids added, so they reach the Dictionary like any dialogue word.
func line(key: String, tokens: Dictionary = {}) -> Dictionary:
	var src: Dictionary = lines.get(key, {})
	var out: Dictionary = {
		"speaker": str(src.get("speaker", "")),
		"text": str(src.get("text", "")),
		"translation": str(src.get("translation", "")),
		"word_ids": Array(src.get("word_ids", [])).duplicate(),
	}
	var price: int = int(tokens.get("price", 0))
	if price > 0:
		var phrase: Dictionary = price_phrase(price)
		out["text"] = out["text"].replace("{number}", phrase["text"])
		out["translation"] = out["translation"].replace("{price}", str(price))
		out["word_ids"].append_array(phrase["word_ids"])
	if tokens.has("item"):
		var item_id: String = tokens["item"]
		out["text"] = out["text"].replace("{item}", "\\" + item_word(item_id))
		out["translation"] = out["translation"].replace("{item_en}", item_name(item_id).to_lower())
		var wid: String = str(get_item(item_id).get("akeanon_word_id", ""))
		if not wid.is_empty():
			out["word_ids"].append(wid)
	return out

## Exposes a line's words (Dictionary unlock), as dialogue lines do.
func expose_line_words(l: Dictionary) -> void:
	for wid in l.get("word_ids", []):
		if not WordBank.get_word(str(wid)).is_empty():
			GameState.expose_word(str(wid))

# --- exchanges ---------------------------------------------------------------

func _get_panel() -> CanvasLayer:
	if _panel == null or not is_instance_valid(_panel):
		_panel = MarketPanel.new()
		get_tree().root.add_child(_panel)
	return _panel

## True while the pay/shop panel is up (HUD hides its controls, Player stops).
func is_open() -> bool:
	return _panel != null and is_instance_valid(_panel) and _panel.visible

## Coin-picking exchange: `price_line` says the price (a line key from
## economy_lines.json). Resolves true once the exact amount is paid (and spent),
## false if the player cancels or can't afford it (nothing spent).
func pay(price: int, price_line: String = "fare_price", said: Dictionary = {}) -> bool:
	if price <= 0:
		return true
	var panel := _get_panel()
	panel.open_pay(price, line(price_line, {"price": price}), said)
	var paid: bool = await panel.finished
	return paid

## Opens a shop's stall (data/items.json "shops"). Buying happens inside.
func open_shop(shop_id: String) -> void:
	if not shops.has(shop_id):
		push_error("Economy: unknown shop '%s'" % shop_id)
		return
	_get_panel().open_shop(shop_id)

## Shop id this NPC runs here, or "" (wrong area, or no shop).
func shop_here(shop_id: String) -> String:
	if shop_id.is_empty() or not shops.has(shop_id):
		return ""
	var area: String = str(shops[shop_id].get("area", ""))
	return shop_id if area.is_empty() or area == GameState.current_area else ""

## Buys one item at its price: coin exchange, then the item. True if bought.
func buy(item_id: String) -> bool:
	var price: int = int(get_item(item_id).get("base_price", 0))
	if not await pay(price, "shop_price", line("shop_order", {"item": item_id})):
		return false
	GameState.add_item(item_id)
	GameState.save_game()
	return true
