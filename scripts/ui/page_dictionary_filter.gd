# page_dictionary_filter.gd — search + category filter for Dictionary tab.
# Lives on PageLeft. Emits filters_changed(query, category); BookUI wires
# this directly to page_dictionary.gd's apply_filter() on PageRight.
extends Control

signal filters_changed(query: String, category: String)

const TEXT_FIELD := preload("res://assets/ui/book/text_field.png")
const TEXTFIELD_SLICE_MARGIN := 5  # placeholder — measure text_field.png's actual corner px

@onready var search_box: LineEdit = $VBox/SearchBox
@onready var category_dropdown: OptionButton = $VBox/CategoryDropdown

func _ready() -> void:
	_style_search_box()
	_populate_categories()
	search_box.text_changed.connect(_on_filters_changed)
	category_dropdown.item_selected.connect(func(_idx): _on_filters_changed(search_box.text))

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
	search_box.placeholder_text = "Search..."

func _populate_categories() -> void:
	category_dropdown.clear()
	category_dropdown.add_item("All")
	var seen: Dictionary = {}
	for word_data in WordBank.words.values():
		var cat: String = word_data.get("category", "")
		if cat.is_empty() or seen.has(cat):
			continue
		seen[cat] = true
		category_dropdown.add_item(cat.capitalize())
	# item index 0 = "All" = no category filter

func _on_filters_changed(_text: String = "") -> void:
	var query := search_box.text
	var idx := category_dropdown.selected
	var category := "" if idx <= 0 else category_dropdown.get_item_text(idx).to_lower()
	filters_changed.emit(query, category)
