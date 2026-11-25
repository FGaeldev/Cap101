# page_dictionary_filter.gd — search + category filter for Dictionary tab.
# Lives on PageLeft. Emits filters_changed(query, category); BookUI wires
# this directly to page_dictionary.gd's apply_filter() on PageRight.
extends Control

signal filters_changed(query: String, category: String)

const TEXT_FIELD := preload("res://assets/ui/book/text_field.png")
const TEXTFIELD_SLICE_MARGIN := 3

@onready var search_box: LineEdit = $VBox/SearchBox
@onready var category_dropdown: OptionButton = $VBox/CategoryDropdown
## "Words known: 42 / 310", plus the selected category's share.
var _progress_label: Label

func _ready() -> void:
	_style_search_box()
	_populate_categories()
	search_box.text_changed.connect(_on_filters_changed)
	category_dropdown.item_selected.connect(func(_idx): _on_filters_changed(search_box.text))
	_build_progress_label()
	_update_progress()

func _style_search_box() -> void:
	var sb := StyleBoxTexture.new()
	sb.texture = TEXT_FIELD
	sb.texture_margin_left = TEXTFIELD_SLICE_MARGIN
	sb.texture_margin_top = TEXTFIELD_SLICE_MARGIN
	sb.texture_margin_right = TEXTFIELD_SLICE_MARGIN
	sb.texture_margin_bottom = TEXTFIELD_SLICE_MARGIN
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	search_box.add_theme_stylebox_override("normal", sb)
	search_box.add_theme_stylebox_override("focus", sb)
	search_box.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
	search_box.add_theme_color_override("font_placeholder_color", UIThemeApplier.TEXT_DISABLED)
	search_box.placeholder_text = "Search word or meaning..."

func _populate_categories() -> void:
	category_dropdown.clear()
	category_dropdown.add_item("All")
	var categories: Array[String] = []
	for word_data in WordBank.words.values():
		var category := str(word_data.get("category", "uncategorized"))
		if category.is_empty():
			category = "uncategorized"
		if category not in categories:
			categories.append(category)
	categories.sort()
	for category in categories:
		category_dropdown.add_item(category.capitalize())
	# Index 0 = All. WordBank normalizes categories before the UI reads them.

## Clears search + category and re-emits filters_changed (e.g. so a word the
## filters hide can be shown by BookUI.open_dictionary_entry()).
func clear_filters() -> void:
	search_box.text = ""
	category_dropdown.select(0)
	_on_filters_changed()

func _on_filters_changed(_text: String = "") -> void:
	var query := search_box.text
	var idx := category_dropdown.selected
	var category := "" if idx <= 0 else category_dropdown.get_item_text(idx).to_lower()
	filters_changed.emit(query, category)
	_update_progress()

## Called by BookUI each time the Dictionary tab opens.
func refresh() -> void:
	_update_progress()

func _build_progress_label() -> void:
	_progress_label = Label.new()
	_progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_progress_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
	_progress_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
	$VBox.add_child(_progress_label)

## Known words out of every word in the word bank, overall and for the chosen
## category. Only words the bank can show count (WordBank skips gloss-less ones).
func _update_progress() -> void:
	if _progress_label == null:
		return
	var idx := category_dropdown.selected
	var category := "" if idx <= 0 else category_dropdown.get_item_text(idx).to_lower()
	var known := 0
	var cat_known := 0
	var cat_total := 0
	for word_id in WordBank.words:
		var in_dict: bool = GameState.is_in_dictionary(word_id)
		if in_dict:
			known += 1
		if not category.is_empty() and str(WordBank.words[word_id].get("category", "")).to_lower() == category:
			cat_total += 1
			if in_dict:
				cat_known += 1
	var text := "Words known: %d / %d" % [known, WordBank.words.size()]
	if not category.is_empty():
		text += "\n%s: %d / %d" % [category_dropdown.get_item_text(idx), cat_known, cat_total]
	_progress_label.text = text
