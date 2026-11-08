# menu_panel.gd — full-screen frame shared by every separated-menu panel.
#
# One piece (TILE_WHOLE): Settings, Map, Achievements
#   ┌──────────────────────────────────────────┐
#   │ <  Title                    header_extra │
#   │ content                                  │
#   └──────────────────────────────────────────┘
#
# Two columns (TILE_LEFT + TILE_RIGHT, meeting in the middle like a book
# spread): Quests, Dictionary, Calendar, Dev
#   ┌─────────────────────┬────────────────────┐
#   │ <  Title            │       header_extra │
#   │ left                │ right              │
#   └─────────────────────┴────────────────────┘
#
# Built in _init so callers can fill `content` (or `left`/`right`) right after
# new(). add_spread() hosts two of the book's page scenes, one per column, each
# with the book's prev/next arrows when that page paginates (next_page/
# prev_page/has_next_page/has_prev_page, the contract
# BookUI._get_paginated_page() uses).
extends Control

const MenuStyle := preload("res://scripts/ui/menus/menu_style.gd")

## Gap between the screen edge and the panel frame.
const SCREEN_MARGIN := 4
## Gap between side-by-side boxes inside one tile (Quests list and details).
const SPREAD_GAP := 10
## Inner padding of the tiles. 8 leaves exactly the book map's 616px width.
const PAD := 8
const HEADER_HEIGHT := 26

signal back_pressed

## One-piece panels: the area under the header. Two-column panels: same as `left`.
var content: VBoxContainer
## Two-column panels only: the area under each column's header row.
var left: VBoxContainer
var right: VBoxContainer
## Right end of the header row (right column's top in two-column panels).
var header_extra: HBoxContainer
var title_label: Label

## [{page: Control, bar: HBoxContainer, prev: Button, next: Button}]
var _sides: Array = []

func _init(title: String, two_columns: bool = false) -> void:
	name = title.to_pascal_case() + "Panel"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = HEADER_HEIGHT
	header.add_theme_constant_override("separation", 6)
	var back := MenuStyle.icon_button(MenuStyle.ICON_BACK)
	back.pressed.connect(func(): back_pressed.emit())
	header.add_child(back)
	title_label = MenuStyle.label(title, UIThemeApplier.FONT_SIZE_XXL, UIThemeApplier.TEXT_EMPHASIS)
	UIThemeApplier.apply_display_font(title_label)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	header_extra = HBoxContainer.new()
	header_extra.alignment = BoxContainer.ALIGNMENT_END
	header_extra.add_theme_constant_override("separation", 4)

	if not two_columns:
		var col := _add_column(self, MenuStyle.TILE_WHOLE)
		col.add_child(header)
		header.add_child(header_extra)
		content = _add_body(col)
		return

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, SCREEN_MARGIN)
	add_child(row)
	var left_col := _add_column(row, MenuStyle.TILE_LEFT)
	left_col.add_child(header)
	left = _add_body(left_col)
	content = left
	var right_col := _add_column(row, MenuStyle.TILE_RIGHT)
	header_extra.custom_minimum_size.y = HEADER_HEIGHT
	right_col.add_child(header_extra)
	right = _add_body(right_col)

## A tile filling its parent (one piece) or half the row (two columns).
func _add_column(parent: Control, tile: int) -> VBoxContainer:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", MenuStyle.tile_style(tile, PAD))
	if parent == self:
		frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, SCREEN_MARGIN)
	else:
		frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(frame)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	frame.add_child(col)
	return col

func _add_body(col: VBoxContainer) -> VBoxContainer:
	var body := VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	return body

## Called by separated_menus.gd each time the panel is shown.
func show_panel() -> void:
	MenuStyle.style_scrollbars(self)
	for side in _sides:
		if side["page"].has_method("refresh"):
			side["page"].refresh()
	update_arrows()
	_on_show()

## Subclass hook: rebuild content for the current game state.
func _on_show() -> void:
	pass

## Two book pages, one per column (two-column panels only). Each page keeps
## its own anchors inside its column, exactly as it does on a book page.
func add_spread(left_page: Control, right_page: Control) -> void:
	assert(right != null, "add_spread needs a two-column panel")
	for pair in [[left, left_page], [right, right_page]]:
		var col: VBoxContainer = pair[0]
		var page: Control = pair[1]
		var holder := Control.new()
		holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
		holder.clip_contents = true
		col.add_child(holder)
		holder.add_child(page)
		page.visible = true
		var bar := HBoxContainer.new()
		col.add_child(bar)
		var prev := MenuStyle.icon_button(MenuStyle.ICON_PREV, Vector2(20, 20))
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var next := MenuStyle.icon_button(MenuStyle.ICON_NEXT, Vector2(20, 20))
		bar.add_child(prev)
		bar.add_child(spacer)
		bar.add_child(next)
		var side := {"page": page, "bar": bar, "prev": prev, "next": next}
		prev.pressed.connect(_on_arrow.bind(side, false))
		next.pressed.connect(_on_arrow.bind(side, true))
		_sides.append(side)

## One book page filling the content area (Settings), or centered at a fixed
## size (Map: its markers are placed in pixels for the book's 616x289 spread).
## Refreshed on show like a spread page; no arrows.
func add_page(page: Control, fixed_size: Vector2 = Vector2.ZERO) -> void:
	var holder := Control.new()
	if fixed_size == Vector2.ZERO:
		holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
		holder.clip_contents = true
		content.add_child(holder)
	else:
		holder.custom_minimum_size = fixed_size
		var center := CenterContainer.new()
		center.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_child(center)
		center.add_child(holder)
	holder.add_child(page)
	page.visible = true
	_sides.append({"page": page, "bar": null})

## Arrow bars only show for pages that have somewhere to go. The bar keeps its
## space (modulate, not visible) so the pages don't jump when it appears.
func update_arrows() -> void:
	for side in _sides:
		if side["bar"] == null:
			continue
		var page: Control = side["page"]
		var paginates: bool = page.has_method("next_page")
		var has_prev: bool = paginates and page.has_prev_page()
		var has_next: bool = paginates and page.has_next_page()
		side["bar"].modulate.a = 1.0 if (has_prev or has_next) else 0.0
		side["prev"].disabled = not has_prev
		side["next"].disabled = not has_next

func _on_arrow(side: Dictionary, forward: bool) -> void:
	var page: Control = side["page"]
	if not page.has_method("next_page"):
		return
	AudioManager.play_sfx("menu_click")
	if forward:
		page.next_page()
	else:
		page.prev_page()
	update_arrows()
