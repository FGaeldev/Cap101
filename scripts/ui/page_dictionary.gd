# page_dictionary.gd — Dictionary word LIST, lives on PageRight.
# Companion to page_dictionary_filter.gd (PageLeft), which drives
# apply_filter() via BookUI's wiring. Cards replaced with line.png
# separators per panel feedback — boxed cards wasted width at half-page.
#
# Paginated, not scrolled — implements next_page()/prev_page()/
# has_next_page()/has_prev_page(), which BookUI's bottom bar picks up
# generically (see BookUI.gd::_update_bottom_bar()). WORDS_PER_PAGE is a
# hardcoded row-count guess, same placeholder-constant approach as
# page_relationship's MAX_ROWS — adjust once real content makes overflow
# visible on-device.
extends Control

@onready var word_list: VBoxContainer = $WordList

const LINE_TEXTURE := preload("res://assets/ui/book/line.png")
const WORDS_PER_PAGE := 6

var _filter_query: String = ""
var _filter_category: String = ""  # "" = all categories
var _filtered_entries: Array = []  # word_ids passing current filter
var _offset: int = 0

## Called by BookUI's generic page-refresh hook. No-op-safe from a cold
## start — GameState.word_exposures may be empty pre-Dictionary-unlock.
func refresh() -> void:
	_offset = 0
	_apply_filter_and_rebuild()

## Called by page_dictionary_filter.gd via signal whenever search text
## or category dropdown changes.
func apply_filter(query: String, category: String) -> void:
	_filter_query = query.to_lower()
	_filter_category = category
	_offset = 0
	_apply_filter_and_rebuild()

func next_page() -> void:
	if has_next_page():
		_offset += WORDS_PER_PAGE
		_render_page()

func prev_page() -> void:
	if has_prev_page():
		_offset -= WORDS_PER_PAGE
		_render_page()

func has_next_page() -> bool:
	return _offset + WORDS_PER_PAGE < _filtered_entries.size()

func has_prev_page() -> bool:
	return _offset > 0

func _apply_filter_and_rebuild() -> void:
	_filtered_entries.clear()
	for word_id in GameState.word_exposures.keys():
		var word_data: Dictionary = WordBank.get_word(word_id)
		if word_data.is_empty():
			continue
		if not _passes_filter(word_data):
			continue
		_filtered_entries.append(word_id)
	_render_page()

func _render_page() -> void:
	for child in word_list.get_children():
		word_list.remove_child(child)
		child.free()

	var page_end: int = mini(_offset + WORDS_PER_PAGE, _filtered_entries.size())
	var page_slice: Array = _filtered_entries.slice(_offset, page_end)
	for word_id in page_slice:
		_add_entry(word_id, WordBank.get_word(word_id))

func _passes_filter(word_data: Dictionary) -> bool:
	if not _filter_category.is_empty() and word_data.get("category", "") != _filter_category:
		return false
	if _filter_query.is_empty():
		return true
	var akeanon: String = word_data.get("akeanon", "").to_lower()
	return akeanon.contains(_filter_query)

func _add_entry(word_id: String, word_data: Dictionary) -> void:
	# Row 1: [word, tag, encounters]
	var top_row := HBoxContainer.new()
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	word_list.add_child(top_row)

	var word_label := Label.new()
	word_label.text = word_data.get("akeanon", "???")
	word_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	word_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_XL)
	word_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(word_label)

	var cat_label := Label.new()
	cat_label.text = "[%s]" % word_data.get("category", "")
	cat_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DISABLED)
	cat_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_XS)
	top_row.add_child(cat_label)

	var enc := Label.new()
	enc.text = "x%d" % GameState.get_exposure(word_id)
	enc.add_theme_color_override("font_color", UIThemeApplier.TEXT_DISABLED)
	enc.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_XS)
	top_row.add_child(enc)

	# Row 2: [meaning]
	# [CLAUDE NOTE] gloss field currently blank/unverified for some words
	# in word_bank.json. Falls back to placeholder until verified.
	var meaning_label := Label.new()
	var gloss: String = word_data.get("gloss", "")
	meaning_label.text = gloss if not gloss.is_empty() else "(meaning pending verification)"
	meaning_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
	meaning_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
	meaning_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	word_list.add_child(meaning_label)

	# Separator — line.png, tiled to fill width instead of stretched thin
	var sep := HSeparator.new()
	var sep_style := StyleBoxTexture.new()
	sep_style.texture = LINE_TEXTURE
	sep_style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sep_style.content_margin_top = 2
	sep_style.content_margin_bottom = 2
	sep.add_theme_stylebox_override("separator", sep_style)
	word_list.add_child(sep)
