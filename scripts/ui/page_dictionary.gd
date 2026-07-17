# page_dictionary.gd — Dictionary tab content for BookUI.
# Ported from dictionary_panel.gd: list-building logic (_rebuild/_add_entry)
# kept as-is, styling swapped from old tropical palette to UIThemeApplier's
# book/parchment theme. No own title/close button — BookUI Root owns those.
extends Control

@onready var word_list: VBoxContainer = $ScrollContainer/WordList

const CARD_BG    := Color("fffdf5")  # parchment card background
const CARD_BORDER := Color("a89484")  # matches UIThemeApplier.TEXT_DISABLED tone

## Called by BookUI.switch_tab() right before this page becomes visible,
## so the list is always current instead of stale from _ready().
func refresh() -> void:
	_rebuild()

func _rebuild() -> void:
	for child in word_list.get_children():
		word_list.remove_child(child)
		child.free()

	for word_id in GameState.word_exposures:
		var word_data: Dictionary = WordBank.get_word(word_id)
		if word_data.is_empty():
			continue
		_add_entry(word_id, word_data)

func _add_entry(word_id: String, word_data: Dictionary) -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = CARD_BG
	card_style.border_color = CARD_BORDER
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(3)
	card_style.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", card_style)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(vbox)

	# Row 1: [word, tag, encounters]
	var top_row := HBoxContainer.new()
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(top_row)

	# Akeanon word — big, emphasis color
	var word_label := Label.new()
	word_label.text = word_data.get("akeanon", "???")
	word_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	word_label.add_theme_font_size_override("font_size", 14)
	word_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(word_label)

	# Category tag
	var cat_label := Label.new()
	cat_label.text = "[%s]" % word_data.get("category", "")
	cat_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DISABLED)
	cat_label.add_theme_font_size_override("font_size", 9)
	top_row.add_child(cat_label)

	# Encounters — compact, shares the row now instead of owning one
	var enc := Label.new()
	enc.text = "x%d" % GameState.get_exposure(word_id)
	enc.add_theme_color_override("font_color", UIThemeApplier.TEXT_DISABLED)
	enc.add_theme_font_size_override("font_size", 9)
	top_row.add_child(enc)

	# Row 2: [meaning]
	# [CLAUDE NOTE] gloss field currently blank/unverified for some words
	# in word_bank.json. Falls back to placeholder until verified.
	var meaning_label := Label.new()
	var gloss: String = word_data.get("gloss", "")
	meaning_label.text = gloss if not gloss.is_empty() else "(meaning pending verification)"
	meaning_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
	meaning_label.add_theme_font_size_override("font_size", 10)
	meaning_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(meaning_label)

	word_list.add_child(card)

	# Gap between cards
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	word_list.add_child(spacer)
