# page_list_column.gd — shared base for every "Header + List" BookUI column.
#
# Layout lives in ONE scene: scenes/ui/page_list_column.tscn (Control >
# VBoxContainer > Header(Label) + List(VBoxContainer)). That scene carries no
# script; BookUI._make_list_column() instantiates it and attaches the
# concrete subclass script (quests / achievements / dev) before add_child().
# Every list tab therefore renders through the exact same node layout — only
# the row content differs.
#
# Two-column spread pattern (same idea as page_relationship.gd):
#   - BookUI instantiates TWO columns per tab, one on PageLeft, one on PageRight.
#   - The LEFT column gets partner_column = right column and is the "primary":
#     it owns pagination for the whole spread and pushes the right half's
#     content into the partner via render_rows().
#   - The RIGHT column (partner_column == null) never computes content on its
#     own — its refresh() is a no-op, content only arrives from the primary.
#   Subclasses that don't paginate across columns (page_dev.gd) skip this and
#   just override refresh() per column.
#
# Pagination contract (picked up generically by BookUI._get_paginated_page()):
#   next_page() / prev_page() / has_next_page() / has_prev_page()
# Implemented here for any subclass that provides _get_items(), ROWS_PER_COLUMN
# via rows_per_column(), and _add_item_row(item). Only the primary exposes
# meaningful values; BookUI only ever queries the "page" (left) side for these
# tabs since the right column reports no pages.
class_name PageListColumn
extends Control

@export var header_path: NodePath = ^"VBoxContainer/Header"
@export var list_path: NodePath = ^"VBoxContainer/List"

@onready var header: Label = get_node(header_path)
@onready var list: VBoxContainer = get_node(list_path)

const LINE_TEXTURE := preload("res://assets/ui/book/line.png")

## Set by BookUI on the LEFT column only. Non-null = this column is primary.
var partner_column: PageListColumn = null

## Index of the first item shown on the current spread (left column's first row).
var _offset: int = 0
## Snapshot of _get_items() taken on refresh(), so paging is stable while open.
var _items: Array = []

func _ready() -> void:
	clip_contents = true
	header.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	header.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_L)
	header.text = _get_header_text()

# --- Subclass hooks ---------------------------------------------------------

## Header text for this column. Right column of a paginated pair defaults to
## blank so the spread reads as one continuous list; the Header node keeps
## its 32px min height either way, so both columns' rows stay aligned.
func _get_header_text() -> String:
	return ""

## Full item list for the spread (any type — passed back to _add_item_row()).
## Override in paginated subclasses.
func _get_items() -> Array:
	return []

## Max rows that fit one column. Override per row height.
func rows_per_column() -> int:
	return 1

## Builds one item's row(s) into `list`. Override in paginated subclasses.
func _add_item_row(_item) -> void:
	pass

## Shown in the left column when _get_items() is empty.
func _get_empty_text() -> String:
	return "Nothing here yet."

# --- Two-column pagination --------------------------------------------------

func refresh() -> void:
	if partner_column == null:
		return  # right column: content only arrives via the primary's render_rows()
	_items = _get_items()
	_offset = 0
	_render_spread()

func next_page() -> void:
	if has_next_page():
		_offset += _spread_size()
		_render_spread()

func prev_page() -> void:
	if has_prev_page():
		_offset = maxi(0, _offset - _spread_size())
		_render_spread()

func has_next_page() -> bool:
	return partner_column != null and _offset + _spread_size() < _items.size()

func has_prev_page() -> bool:
	return partner_column != null and _offset > 0

func _spread_size() -> int:
	return rows_per_column() * 2

func _render_spread() -> void:
	var per_col: int = rows_per_column()
	var left_end: int = mini(_offset + per_col, _items.size())
	var right_end: int = mini(_offset + per_col * 2, _items.size())
	render_rows(_items.slice(_offset, left_end))
	partner_column.render_rows(_items.slice(left_end, right_end))
	if _items.is_empty():
		add_meta_line(_get_empty_text())

## Public — called on self by the primary and on the partner by the primary.
func render_rows(items: Array) -> void:
	clear_list()
	for item in items:
		_add_item_row(item)

# --- Shared row helpers -----------------------------------------------------

## free() (not queue_free) so the old rows are gone before new ones are
## measured this frame. Do NOT use from inside a row button's own pressed
## handler — use queue_free there instead.
func clear_list() -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.free()

func add_meta_line(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DISABLED)
	label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
	list.add_child(label)

func add_separator() -> void:
	var sep := HSeparator.new()
	var sep_style := StyleBoxTexture.new()
	sep_style.texture = LINE_TEXTURE
	sep_style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sep_style.content_margin_top = 2
	sep_style.content_margin_bottom = 2
	sep.add_theme_stylebox_override("separator", sep_style)
	list.add_child(sep)

func add_button(label: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = label
	UIThemeApplier.apply_button_theme(btn, "secondary")
	btn.pressed.connect(callback)
	list.add_child(btn)
	return btn

## "[x] Title" row used by quests and achievements.
func add_status_row(checked: bool, active: bool, title: String, dim_title: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(row)

	var status := Label.new()
	status.text = "[x]" if checked else ("[>]" if active else "[ ]")
	status.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS if checked else UIThemeApplier.TEXT_DEFAULT)
	status.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_M)
	row.add_child(status)

	var title_label := Label.new()
	title_label.text = title
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.clip_text = true
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DISABLED if dim_title else UIThemeApplier.TEXT_DEFAULT)
	title_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_M)
	row.add_child(title_label)
	return row
