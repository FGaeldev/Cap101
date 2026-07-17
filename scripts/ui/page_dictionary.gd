# page_dictionary.gd — Dictionary word LIST, lives on PageRight.
# Companion to page_dictionary_filter.gd (PageLeft), which drives
# apply_filter() via BookUI's wiring. Cards replaced with line.png
# separators per panel feedback — boxed cards wasted width at half-page.
extends Control

@onready var word_list: VBoxContainer = $ScrollContainer/WordList

const LINE_TEXTURE := preload("res://assets/ui/book/line.png")

var _filter_query: String = ""
var _filter_category: String = ""  # "" = all categories

## Called by BookUI.switch_tab() right before this page becomes visible,
## so the list is always current instead of stale from _ready().
func refresh() -> void:
	_rebuild()

## Called by page_dictionary_filter.gd via signal whenever search text
## or category dropdown changes.
func apply_filter(query: String, category: String) -> void:
	_filter_query = query.to_lower()
	_filter_category = category
	_rebuild()

func _rebuild() -> void:
	for child in word_list.get_children():
		word_list.remove_child(child)
		child.free()

	var entries: Array = GameState.word_exposures.keys()
	for word_id in entries:
		var word_data: Dictionary = WordBank.get_word(word_id)
		if word_data.is_empty():
			continue
		if not _passes_filter(word_data):
			continue
		_add_entry(word_id, word_data)

func _passes_filter(word_data: Dictionary) -> bool:
	if not _filter_category.is_empty() and word_data.get("category", "") != _filter_category:
		return false
	if _filter_query.is_empty():
		return true
	var akeanon: String = word_data.get("akeanon", "").to_lower()
	var gloss: String = word_data.get("gloss", "").to_lower()
	return akeanon.contains(_filter_query) or gloss.contains(_filter_query)

func _add_entry(word_id: String, word_data: Dictionary) -> void:
	# Row 1: [word, tag, encounters]
	var top_row := HBoxContainer.new()
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	word_list.add_child(top_row)

	var word_label := Label.new()
	word_label.text = word_data.get("akeanon", "???")
	word_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	word_label.add_theme_font_size_override("font_size", 14)
	word_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(word_label)

	var cat_label := Label.new()
	cat_label.text = "[%s]" % word_data.get("category", "")
	cat_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DISABLED)
	cat_label.add_theme_font_size_override("font_size", 9)
	top_row.add_child(cat_label)

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
	word_list.add_child(meaning_label)

	# Separator — line.png, tiled to fill width instead of stretched thin
	var sep := HSeparator.new()
	var sep_style := StyleBoxTexture.new()
	sep_style.texture = LINE_TEXTURE
	sep_style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sep_style.content_margin_top = 4
	sep_style.content_margin_bottom = 4
	sep.add_theme_stylebox_override("separator", sep_style)
	word_list.add_child(sep)
