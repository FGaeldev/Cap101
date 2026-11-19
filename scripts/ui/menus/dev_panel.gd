# dev_panel.gd — Dev: one scrollable, cascading list in place of the book's
# two paged columns.
#
#   Menus: separate (tap to switch)
#   + Skip to scene
#       + Ch1   US Home - Bedroom, ...
#       + Ch2   ...
#   + Time      Morning (08:00), ...
#   + Date      Next day, Next week
#   + Minigames & quizzes   Quiz: meanings (all words), Habi-Habi, ...
#   + Play cutscene
#       + Ch1   S1 — Lola Jonabel intro, ...
#
# Groups come from the entry labels in page_dev.gd ("Ch2 — Aklan - Hallway" ->
# group "Ch2", item "Aklan - Hallway"), so new entries there show up here with
# no change. Pressing an item runs page_dev.gd's own handler on a hidden copy
# of each book column, so warps and cutscene replays behave exactly as in the
# book.
extends "res://scripts/ui/menus/menu_panel.gd"

const PageDevScript := preload("res://scripts/ui/page_dev.gd")
const PageListColumnScene := preload("res://scenes/ui/page_list_column.tscn")

const INDENT := 12
const LABEL_SEPARATOR := " — "

var _warps: Control
var _cutscenes: Control
var _list: VBoxContainer

func _init() -> void:
	super("Dev")
	_warps = _make_hidden_column("warps")
	_cutscenes = _make_hidden_column("cutscenes")

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_list)

	var warps: Array = []
	var times: Array = []
	var dates: Array = []
	var money: Array = []
	var cards: Array = []
	for entry: Dictionary in PageDevScript.DEV_WARP_TARGETS:
		if entry.has("toggle_menus") or entry.has("toggle_cards") or entry.has("toggle_movement"):
			continue
		if entry.has("card"):
			cards.append(entry)
			continue
		if entry.has("pesos"):
			money.append(entry)
			continue
		if entry.has("time"):
			times.append(entry)
		elif entry.has("days"):
			dates.append(entry)
		else:
			warps.append(entry)

	_list.add_child(_item_button(_menus_label(), 0,
			func(): BookUI.set_separate_menus(not BookUI.separate_menus)))
	var move_btn: Button = _item_button(_movement_label(), 0, Callable())
	move_btn.pressed.connect(func():
		Accessibility.set_movement_controls(Accessibility.MOVEMENT_JOYSTICK if Accessibility.uses_dpad() else Accessibility.MOVEMENT_DPAD)
		move_btn.text = _movement_label())
	_list.add_child(move_btn)
	_add_group(_list, "Skip to scene", 0, _subgroups.bind(warps, _warps))
	_add_group(_list, "Time", 0, _items.bind(times, _warps, 1))
	_add_group(_list, "Date", 0, _items.bind(dates, _warps, 1))
	_add_group(_list, "Money", 0, _items.bind(money, _warps, 1))
	var cards_btn: Button = _item_button(PageDevScript.cards_label(), 0, Callable())
	cards_btn.pressed.connect(func():
		GameState.set_dev_show_cards(not GameState.dev_show_cards)
		cards_btn.text = PageDevScript.cards_label())
	_list.add_child(cards_btn)
	_add_group(_list, "Chapter cards", 0, _items.bind(cards, _warps, 1))
	_add_group(_list, "Minigames & quizzes", 0, _items.bind(PageDevScript.DEV_MINIGAMES, _cutscenes, 1))
	_add_group(_list, "Play cutscene", 0, _subgroups.bind(PageDevScript.DEV_CUTSCENES, _cutscenes))

func _menus_label() -> String:
	return "Menus: %s (tap to switch)" % ("separate" if BookUI.separate_menus else "book")

## Collapsed header; children are built into its body on the first expand.
func _add_group(parent: VBoxContainer, title: String, depth: int, build: Callable) -> void:
	var header := _item_button("+  " + title, depth, Callable())
	header.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	parent.add_child(header)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 2)
	body.visible = false
	parent.add_child(body)
	header.pressed.connect(func():
		AudioManager.play_sfx("menu_click")
		if body.get_child_count() == 0:
			build.call(body)
		body.visible = not body.visible
		header.text = ("-  " if body.visible else "+  ") + title)

## One sub-group per label prefix ("Ch1", "Ch2", ...), in first-seen order.
func _subgroups(body: VBoxContainer, entries: Array, column: Control) -> void:
	var groups: Dictionary = {}
	for entry: Dictionary in entries:
		var prefix: String = _split(entry["label"])[0].get_slice(" ", 0)
		if not groups.has(prefix):
			groups[prefix] = []
		groups[prefix].append(entry)
	for prefix: String in groups:
		_add_group(body, prefix, 1, _items.bind(groups[prefix], column, 2))

func _items(body: VBoxContainer, entries: Array, column: Control, depth: int) -> void:
	for entry: Dictionary in entries:
		var label: String = entry["label"]
		var parts: Array = _split(label)
		# "Ch1 S3 — Reunion" keeps "S3 — Reunion"; "Ch2 — Hallway" keeps "Hallway".
		var rest: String = parts[0].substr(parts[0].find(" ") + 1) + LABEL_SEPARATOR + parts[1] \
				if parts[0].contains(" ") else parts[1]
		var method: String = "_on_dev_warp_pressed" if column == _warps \
				else ("_on_dev_minigame_pressed" if entry.has("kind") else "_on_dev_cutscene_pressed")
		var handler := Callable(column, method)
		body.add_child(_item_button(rest, depth, handler.bind(entry)))

## [before, after] the first " — " (after = whole label when there is none).
func _split(label: String) -> Array:
	var at: int = label.find(LABEL_SEPARATOR)
	if at < 0:
		return [label, label]
	return [label.left(at), label.substr(at + LABEL_SEPARATOR.length())]

func _item_button(text: String, depth: int, on_press: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.flat = true
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(key, UIThemeApplier.TEXT_DEFAULT)
	var pad := StyleBoxEmpty.new()
	pad.content_margin_left = 4 + depth * INDENT
	pad.content_margin_top = 2
	pad.content_margin_bottom = 2
	var hover := MenuStyle.card_style(0)
	hover.content_margin_left = pad.content_margin_left
	hover.content_margin_top = 2
	hover.content_margin_bottom = 2
	for state in ["normal", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, pad)
	for state in ["hover", "pressed"]:
		btn.add_theme_stylebox_override(state, hover)
	if on_press.is_valid():
		btn.pressed.connect(on_press)
	return btn

## Hidden page_dev column, same setup as BookUI._make_list_column(): it owns
## the warp/cutscene handlers (and must sit in the tree for their awaits).
func _make_hidden_column(column: String) -> Control:
	var col: Control = PageListColumnScene.instantiate()
	col.set_script(PageDevScript)
	col.set("column", column)
	col.visible = false
	add_child(col)
	return col


func _movement_label() -> String:
	return "Movement: %s (tap to switch)" % Accessibility.MOVEMENT_OPTIONS[Accessibility.movement_controls]
