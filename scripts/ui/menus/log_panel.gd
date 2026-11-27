# log_panel.gd — Conversation log: every line shown since the save was loaded
# (DialogueUI.conversation_log), oldest at the top, opened scrolled to the
# newest. Akeanon words keep their color and can be tapped for their meaning,
# like in the dialogue box.
extends "res://scripts/ui/menus/menu_panel.gd"

const WordPopup := preload("res://scripts/ui/word_popup.gd")
const ENTRY_GAP := 6

var _scroll: ScrollContainer
var _list: VBoxContainer
var _popup: Control
## "<entry>:<meta>" of the word whose popup is open, "" if none.
var _open_word: String = ""

func _init() -> void:
	super("Conversation log")
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", ENTRY_GAP)
	_scroll.add_child(_list)
	_popup = WordPopup.new()
	add_child(_popup)
	_scroll.get_v_scroll_bar().scrolling.connect(_close_word)

func _on_show() -> void:
	_close_word()
	for child in _list.get_children():
		child.queue_free()
	var entries: Array = DialogueUI.conversation_log
	if entries.is_empty():
		_list.add_child(MenuStyle.label("Nobody has said anything yet.", UIThemeApplier.FONT_SIZE_S, UIThemeApplier.TEXT_DISABLED))
		return
	for i in entries.size():
		_list.add_child(_make_entry(i, entries[i]))
	# Newest at the bottom; the bar only knows its length after a layout pass.
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)

## "Speaker: line" in one label; narration (no speaker) is the line alone.
func _make_entry(index: int, entry: Dictionary) -> RichTextLabel:
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.meta_underlined = false
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_color_override("default_color", UIThemeApplier.TEXT_DEFAULT)
	var speaker: String = TextUtil.resolve_speaker(entry["speaker"])
	var prefix: String = "" if speaker.is_empty() else \
		"[color=#%s]%s:[/color] " % [UIThemeApplier.TEXT_EMPHASIS.to_html(false), speaker.replace("[", "[lb]")]
	text.text = prefix + TextUtil.resolve_rich(entry["text"])
	text.meta_clicked.connect(_on_word.bind(index))
	return text

## meta is "<index>:<word>", see TextUtil.resolve_rich().
func _on_word(meta: Variant, entry: int) -> void:
	var key := "%d:%s" % [entry, meta]
	if key == _open_word:
		_close_word()
		return
	var form: String = str(meta).split(":", true, 1)[1]
	var word: Dictionary = WordBank.get_word(WordBank.find_id_by_form(form))
	if word.is_empty():
		return
	_open_word = key
	_popup.show_word(word["akeanon"], WordBank.glosses_for_form(form), get_global_mouse_position())

func _close_word(_value: Variant = null) -> void:
	_open_word = ""
	_popup.close()
