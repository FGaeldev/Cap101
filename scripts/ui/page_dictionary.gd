# page_dictionary.gd — Dictionary word LIST, lives on PageRight.
# Companion to page_dictionary_filter.gd (PageLeft), which drives
# apply_filter() via BookUI's wiring. Cards replaced with line.png
# separators per panel feedback — boxed cards wasted width at half-page.
#
# Paginated, not scrolled — implements next_page()/prev_page()/
# has_next_page()/has_prev_page(), picked up generically by BookUI's bottom
# bar (BookUI.gd::_update_bottom_bar()).
#
# PAGE_HEIGHT_BUDGET is measured, not guessed: Spread anchors in book_ui.tscn
# give ~210px tall page halves at 512x288 viewport, PageDictionary's own
# 0.02-0.98 anchor takes ~4% off each side -> ~202px content height. Matches
# page_relationship.gd's own "~202px row_list height" comment — same page,
# same budget.
#
# ENTRY_HEIGHT is a fixed ceiling, not a measurement of any one entry —
# meaning_label is hard-capped to 2 wrap lines (max_lines_visible + ellipsis
# overrun) specifically so every entry has the SAME worst-case height and
# WORDS_PER_PAGE can be a flat division instead of guessing at wrap behavior.
# Previously this wasn't capped: a long gloss could wrap to 3-4 lines and
# blow well past whatever WORDS_PER_PAGE assumed, spilling the list past the
# page art into whatever sits underneath — that was the overflow bug.
# clip_contents on the root is a hard backstop in case this estimate is off.
extends Control

@onready var word_list: VBoxContainer = $WordList

const LINE_TEXTURE := preload("res://assets/ui/book/line.png")

const PAGE_HEIGHT_BUDGET := 202.0
const ENTRY_HEIGHT := 47.0   # word line (~17) + 2 capped gloss lines (~24) + separator (~6)
const WORDS_PER_PAGE := 4    # floor(202/47) = 4, leaves ~14px slack for font-metric drift

var _filter_query: String = ""
var _filter_category: String = ""  # "" = all categories
var _filtered_entries: Array = []  # word_ids passing current filter
var _offset: int = 0

func _ready() -> void:
	clip_contents = true

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

	# Row 2: [meaning] — hard-capped to 2 lines, ellipsis on overrun. This cap
	# is what makes ENTRY_HEIGHT/WORDS_PER_PAGE trustworthy; without it a long
	# gloss wraps to however many lines it needs and blows the page budget.
	# [CLAUDE NOTE] gloss field currently blank/unverified for some words
	# in word_bank.json. Falls back to placeholder until verified.
	var meaning_label := Label.new()
	var gloss: String = word_data.get("gloss", "")
	meaning_label.text = gloss if not gloss.is_empty() else "(meaning pending verification)"
	meaning_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
	meaning_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
	meaning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meaning_label.max_lines_visible = 2
	meaning_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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
