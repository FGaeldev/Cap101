# market_panel.gd -- the money exchanges (docs/ECONOMY_PLAN.md), built in code
# and owned by the Economy autoload:
#   pay  : someone says a price in Akeanon; the player taps coins to count it
#          out and pays. A wrong amount repeats the price with its English and
#          gives the coins back. Cancel never costs anything.
#   shop : a vendor's stall. Each good shows its Akeanon word, English and
#          price; tapping one orders it ("Pangabay it ___") and opens pay.
# finished(paid) fires when a pay exchange ends. Runs while the tree is paused
# (the Map lives in the paused BookUI).
extends CanvasLayer

signal finished(paid: bool)

const COINS: Array[int] = [1, 5, 10]
const PANEL_WIDTH := 400.0

var _panel: PanelContainer
## What the player just said (their order), shown above the reply.
var _said: RichTextLabel
var _speaker: Label
var _text: RichTextLabel
var _hint: Label
var _body: VBoxContainer
var _wallet: Label

## Pay state.
var _price: int = 0
var _tray: int = 0
var _paying: bool = false
var _tray_label: Label
var _pay_button: Button
var _coin_buttons: Array[Button] = []
var _price_line: Dictionary = {}

## Shop state: id of the open stall, "" when paying for a fare.
var _shop_id: String = ""
var _buying: bool = false

func _init() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)  # also stops taps reaching the world
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size.x = PANEL_WIDTH
	_panel.add_theme_stylebox_override("panel", UIThemeApplier.make_panel_style())
	center.add_child(_panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_panel.add_child(vbox)
	_said = RichTextLabel.new()
	_said.bbcode_enabled = true
	_said.fit_content = true
	_said.scroll_active = false
	_said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_said.add_theme_color_override("default_color", UIThemeApplier.TEXT_DISABLED)
	_said.add_theme_font_size_override("normal_font_size", UIThemeApplier.FONT_SIZE_S)
	vbox.add_child(_said)
	_speaker = _label(UIThemeApplier.FONT_SIZE_S, UIThemeApplier.TEXT_EMPHASIS)
	vbox.add_child(_speaker)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_color_override("default_color", UIThemeApplier.TEXT_DEFAULT)
	_text.add_theme_font_size_override("normal_font_size", UIThemeApplier.FONT_SIZE_L)
	vbox.add_child(_text)
	_hint = _label(UIThemeApplier.FONT_SIZE_S, UIThemeApplier.TEXT_DISABLED)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_hint)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 4)
	vbox.add_child(_body)
	_wallet = _label(UIThemeApplier.FONT_SIZE_S, UIThemeApplier.TEXT_DEFAULT)
	_wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(_wallet)
	GameState.pesos_changed.connect(func(_t, _d): _refresh_wallet())

func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _button(text: String, variant: String = "secondary") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 26)
	UIThemeApplier.apply_button_theme(b, variant)
	b.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
	return b

func _clear_body() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_coin_buttons.clear()

func _say(l: Dictionary, said: Dictionary = {}) -> void:
	_said.visible = not said.is_empty()
	if _said.visible:
		_said.text = "%s: %s" % [TextUtil.resolve_speaker(str(said.get("speaker", ""))), TextUtil.resolve_rich(str(said.get("text", "")))]
		Economy.expose_line_words(said)
	_speaker.text = TextUtil.resolve_speaker(str(l.get("speaker", "")))
	_text.text = TextUtil.resolve_rich(str(l.get("text", "")))
	Economy.expose_line_words(l)

func _refresh_wallet() -> void:
	if _wallet != null:
		_wallet.text = "You have ₱%d" % GameState.pesos

# --- pay -----------------------------------------------------------------------

func open_pay(price: int, price_line: Dictionary, said: Dictionary = {}) -> void:
	_price = price
	_tray = 0
	_paying = true
	_price_line = price_line
	_clear_body()
	_say(price_line, said)
	if GameState.pesos < price:
		_hint.text = "You need ₱%d. You have ₱%d." % [price, GameState.pesos]
	else:
		_hint.text = "Tap the coins to count out the price."
	_tray_label = _label(UIThemeApplier.FONT_SIZE_M, UIThemeApplier.TEXT_EMPHASIS)
	_body.add_child(_tray_label)
	var coins := HBoxContainer.new()
	coins.add_theme_constant_override("separation", 4)
	_body.add_child(coins)
	for coin: int in COINS:
		var b := _button("₱%d" % coin)
		b.custom_minimum_size.x = 56
		b.pressed.connect(_on_coin.bind(coin))
		coins.add_child(b)
		_coin_buttons.append(b)
	var clear := _button("Take back")
	clear.pressed.connect(func():
		AudioManager.play_sfx("menu_click")
		_tray = 0
		_refresh_tray())
	coins.add_child(clear)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	_body.add_child(actions)
	_pay_button = _button("Pay", "confirm")
	_pay_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pay_button.pressed.connect(_on_pay)
	actions.add_child(_pay_button)
	var cancel := _button("Cancel")
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(_on_cancel_pay)
	actions.add_child(cancel)
	_refresh_tray()
	_refresh_wallet()
	visible = true

func _on_coin(coin: int) -> void:
	AudioManager.play_sfx("menu_click")
	_tray += coin
	_refresh_tray()

func _refresh_tray() -> void:
	_tray_label.text = "Giving: ₱%d" % _tray
	for i in COINS.size():
		_coin_buttons[i].disabled = _tray + COINS[i] > GameState.pesos
	_pay_button.disabled = _tray <= 0

func _on_pay() -> void:
	if _tray == _price and RewardManager.spend_pesos(_price):
		AudioManager.play_sfx("menu_click")
		_end_pay(true)
		return
	# Wrong amount: coins come back, the price is repeated with its English.
	var word: String = Economy.number_word(_price)
	var gloss: String = str(WordBank.get_word(Economy.number_word_id(_price)).get("gloss", ""))
	if word.is_empty():
		_hint.text = "Not quite. The price is ₱%d. Try again." % _price
	else:
		_hint.text = "Not quite. %s = %s, so ₱%d. Try again." % [word.capitalize(), gloss, _price]
	_tray = 0
	_refresh_tray()

func _on_cancel_pay() -> void:
	AudioManager.play_sfx("menu_click")
	_end_pay(false)

func _end_pay(paid: bool) -> void:
	_paying = false
	if _shop_id.is_empty():
		visible = false
	finished.emit(paid)

# --- shop ----------------------------------------------------------------------

func open_shop(shop_id: String) -> void:
	_shop_id = shop_id
	_show_stall(Economy.line("shop_greet"), "")
	visible = true

func _show_stall(l: Dictionary, hint: String) -> void:
	_clear_body()
	_say(l)
	_hint.text = hint if not hint.is_empty() else "Tap something to ask for it."
	var shop: Dictionary = Economy.shops.get(_shop_id, {})
	for item_id: String in shop.get("stock", []):
		var price: int = int(Economy.get_item(item_id).get("base_price", 0))
		var have: int = GameState.get_item_count(item_id)
		var text: String = "%s  (%s)   ₱%d" % [Economy.item_word(item_id), Economy.item_name(item_id).to_lower(), price]
		if have > 0:
			text += "   you have %d" % have
		var b := _button(text)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = GameState.pesos < price
		b.pressed.connect(_on_item.bind(item_id))
		_body.add_child(b)
	var close := _button("Goodbye")
	close.pressed.connect(close_shop)
	_body.add_child(close)
	_refresh_wallet()

func _on_item(item_id: String) -> void:
	if _buying:
		return
	_buying = true
	AudioManager.play_sfx("menu_click")
	# The player asks for it in Akeanon, then Pedring names the price.
	var bought: bool = await Economy.buy(item_id)
	_buying = false
	if not visible:
		return
	if bought:
		_show_stall(Economy.line("shop_paid"), "Got %s (%s)." % [Economy.item_word(item_id), Economy.item_name(item_id).to_lower()])
	else:
		_show_stall(Economy.line("shop_greet"), "")

func close_shop() -> void:
	AudioManager.play_sfx("menu_click")
	_shop_id = ""
	visible = false
	if _paying:
		_end_pay(false)
