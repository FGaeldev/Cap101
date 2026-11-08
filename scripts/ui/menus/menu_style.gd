# menu_style.gd — art helpers for the separated menus (assets/ui/seperated_menus).
# Preload it (no class_name):
#   const MenuStyle := preload("res://scripts/ui/menus/menu_style.gd")
#
# backgrounds.png: a row of 128x128 tiles, each with a drawn border, so any
# tile nine-slices to any size. Add tiles to the right; never move existing
# ones (the TILE_* indexes below point at them).
#
# icons.png: a row of 24x24 white icons on transparent. White so code can tint
# them (Godot multiplies texture by color): change ICON_COLOR below and every
# menu icon follows. Add icons to the right; never move existing ones.
extends RefCounted

const BACKGROUNDS := preload("res://assets/ui/seperated_menus/backgrounds.png")
const TILE_SIZE := 128
## Widest drawn border (the thick outer edge); thin edges fit inside it.
const TILE_BORDER := 6

## Thick border on the left, thin elsewhere: left half of a two-column panel.
const TILE_LEFT := 0
## Thick border all round: one-piece panels and the pause menu.
const TILE_WHOLE := 1
## Thick border on the right, thin elsewhere: right half of a two-column panel.
const TILE_RIGHT := 2
## Thin 2px frame, transparent middle: cards inside a panel.
const TILE_CARD := 3

const ICONS := preload("res://assets/ui/seperated_menus/icons.png")
const ICON_SIZE := 24

## hud_btns.png: 32x32 HUD button frames, [normal, pressed]. A 4px border
## leaves exactly one 24px icon inside.
const HUD_BUTTONS := preload("res://assets/ui/seperated_menus/hud_btns.png")
const HUD_BUTTON_SIZE := 32
const HUD_BUTTON_BORDER := 4

## bars.png: 16x16 cells, [track, fill]. The fill cell keeps a transparent row
## above and below so it sits inside the track's outline.
const BARS := preload("res://assets/ui/seperated_menus/bars.png")
const BAR_HEIGHT := 8

## scrollbar.png: 16x16 cells, [track, grabber, grabber highlighted]. Both are
## 6px wide, centered in their cells.
const SCROLLBAR := preload("res://assets/ui/seperated_menus/scrollbar.png")

## chips.png: 32x32 cells, [normal, selected]: option buttons (UI scale).
const CHIPS := preload("res://assets/ui/seperated_menus/chips.png")
const CHIP_SIZE := 32

## slider.png: 16x12 cells, [empty track, filled track, 12x12 knob].
const SLIDER := preload("res://assets/ui/seperated_menus/slider.png")

## toggles.png: 32x32 cells, [on (dot), off (empty)]: CheckButton switches.
const TOGGLES := preload("res://assets/ui/seperated_menus/toggles.png")
const TOGGLE_SIZE := 32

## Cell indexes in icons.png.
const ICON_MAP := 0
const ICON_DICTIONARY := 1
const ICON_CALENDAR := 2
const ICON_DAY := 3
const ICON_NIGHT := 4
const ICON_QUEST := 5
const ICON_CONTINUE := 6
const ICON_MENU := 7
const ICON_SETTINGS := 8
const ICON_EXIT := 9
const ICON_ENTER := 10
const ICON_BACK := 11
const ICON_NEXT := 12
const ICON_LOCKED := 13
const ICON_DONE := 14
const ICON_ACTIVE := 15
const ICON_LOCATION := 16
const ICON_SEARCH := 17
const ICON_ACHIEVEMENTS := 18
const ICON_DEV := 19
const ICON_PREV := ICON_BACK

## Icon tints. Icons are drawn white, so these are the colors they show as.
const ICON_COLOR := UIThemeApplier.TEXT_DEFAULT
const ICON_COLOR_DISABLED := Color(UIThemeApplier.TEXT_DEFAULT, 0.35)
const ICON_COLOR_DONE := UIThemeApplier.COLOR_SUCCESS
## Unlocked achievements: a deep gold that still reads on the tan cards.
const ICON_COLOR_GOLD := Color("b8861b")
## Clock sun and moon: warm amber and dusk indigo, dark enough to read on the tan header.
const ICON_COLOR_DAY := Color("c8661a")
const ICON_COLOR_NIGHT := Color("4a4878")

static var _icon_cache: Dictionary = {}

## One 24x24 cell of icons.png.
static func icon(index: int) -> Texture2D:
	if not _icon_cache.has(index):
		var atlas := AtlasTexture.new()
		atlas.atlas = ICONS
		atlas.region = Rect2(index * ICON_SIZE, 0, ICON_SIZE, ICON_SIZE)
		_icon_cache[index] = atlas
	return _icon_cache[index]

## Icon as a TextureRect, tinted.
static func icon_rect(index: int, color: Color = ICON_COLOR, size: int = ICON_SIZE) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = icon(index)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(size, size)
	rect.self_modulate = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

## Tints a button's icon in every state.
static func tint_button_icon(btn: Button, color: Color = ICON_COLOR) -> void:
	for state in ["icon_normal_color", "icon_hover_color", "icon_focus_color", "icon_hover_pressed_color"]:
		btn.add_theme_color_override(state, color)
	btn.add_theme_color_override("icon_pressed_color", color.darkened(0.3))
	btn.add_theme_color_override("icon_disabled_color", Color(color, 0.35))

## Nine-slice StyleBox from one tile. `pad` is the inner content margin.
static func tile_style(tile: int, pad: int = 8) -> StyleBoxTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = BACKGROUNDS
	atlas.region = Rect2(tile * TILE_SIZE, 0, TILE_SIZE, TILE_SIZE)
	var sb := StyleBoxTexture.new()
	sb.texture = atlas
	sb.texture_margin_left = TILE_BORDER
	sb.texture_margin_top = TILE_BORDER
	sb.texture_margin_right = TILE_BORDER
	sb.texture_margin_bottom = TILE_BORDER
	sb.content_margin_left = pad
	sb.content_margin_top = pad
	sb.content_margin_right = pad
	sb.content_margin_bottom = pad
	return sb

## Card around rows and boxes inside a panel: the thin TILE_CARD frame, with
## the panel showing through its transparent middle.
static func card_style(pad: int = 6) -> StyleBoxTexture:
	return tile_style(TILE_CARD, pad)

## Label in the book's text colors.
static func label(text: String, size: int = UIThemeApplier.FONT_SIZE_M, color: Color = UIThemeApplier.TEXT_DEFAULT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	return l

## Flat icon-only button (back, page arrows).
static func icon_button(index: int, size: Vector2 = Vector2(ICON_SIZE, ICON_SIZE)) -> Button:
	var btn := Button.new()
	btn.icon = icon(index)
	btn.flat = true
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.custom_minimum_size = size
	btn.focus_mode = Control.FOCUS_NONE
	tint_button_icon(btn)
	return btn

## Square HUD button: hud_btns.png frame behind a tinted icon.
static func hud_button(index: int) -> Button:
	var btn := Button.new()
	btn.icon = icon(index)
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.focus_mode = Control.FOCUS_NONE
	var normal := _hud_button_style(0)
	for state in ["normal", "hover", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, normal)
	btn.add_theme_stylebox_override("pressed", _hud_button_style(1))
	tint_button_icon(btn)
	return btn

static func _hud_button_style(frame: int) -> StyleBoxTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = HUD_BUTTONS
	atlas.region = Rect2(frame * HUD_BUTTON_SIZE, 0, HUD_BUTTON_SIZE, HUD_BUTTON_SIZE)
	var sb := StyleBoxTexture.new()
	sb.texture = atlas
	sb.set_texture_margin_all(HUD_BUTTON_BORDER)
	sb.set_content_margin_all(HUD_BUTTON_BORDER)
	return sb

## Book-themed text button with an optional leading icon (an icons.png index,
## or a Texture2D for art that is already colored).
static func text_button(text: String, icon_ref: Variant = null, variant: String = "primary") -> Button:
	var btn := Button.new()
	btn.text = text
	UIThemeApplier.apply_button_theme(btn, variant)
	btn.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_M)
	if icon_ref is int:
		btn.icon = icon(icon_ref)
		tint_button_icon(btn)
	elif icon_ref is Texture2D:
		btn.icon = icon_ref
	if btn.icon != null:
		btn.add_theme_constant_override("icon_max_width", 12)  # half of 24: even pixels
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return btn

## Learning-tier bar: bars.png track behind, gold fill on top.
static func tier_bar() -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.step = 0.0
	bar.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	bar.add_theme_stylebox_override("background", _sheet_style(BARS, Rect2(0, 4, 16, BAR_HEIGHT), 3, 2))
	var fill := _sheet_style(BARS, Rect2(16, 4, 16, BAR_HEIGHT), 2, 2)
	# ProgressBar draws the fill from the bar's very edge; pull it in 1px each
	# side so the track's outline stays visible around it.
	fill.expand_margin_left = -1
	fill.expand_margin_right = -1
	bar.add_theme_stylebox_override("fill", fill)
	return bar

## Restyles every scrollbar under `root` (including the ones ScrollContainers
## create internally) with scrollbar.png. Safe to call repeatedly.
static func style_scrollbars(root: Node) -> void:
	var track := _sheet_style(SCROLLBAR, Rect2(5, 0, 6, 16), 0, 2)
	var grabber := _sheet_style(SCROLLBAR, Rect2(21, 5, 6, 6), 2, 2)
	var grabber_lit := _sheet_style(SCROLLBAR, Rect2(37, 5, 6, 6), 2, 2)
	# Content margins set the bar's width: 3 + 3 = the art's 6px.
	for sb: StyleBoxTexture in [track, grabber, grabber_lit]:
		sb.content_margin_left = 3
		sb.content_margin_right = 3
	for bar: Node in root.find_children("*", "VScrollBar", true, false):
		bar.add_theme_stylebox_override("scroll", track)
		bar.add_theme_stylebox_override("scroll_focus", track)
		bar.add_theme_stylebox_override("grabber", grabber)
		bar.add_theme_stylebox_override("grabber_highlight", grabber_lit)
		bar.add_theme_stylebox_override("grabber_pressed", grabber_lit)

## Option button (radio) with chips.png: normal frame, selected frame when on.
static func style_chip(btn: Button) -> void:
	var normal := _sheet_style(CHIPS, Rect2(0, 0, CHIP_SIZE, CHIP_SIZE), 3, 3)
	var selected := _sheet_style(CHIPS, Rect2(CHIP_SIZE, 0, CHIP_SIZE, CHIP_SIZE), 3, 3)
	for sb: StyleBoxTexture in [normal, selected]:
		sb.content_margin_left = 6
		sb.content_margin_right = 6
	for state in ["normal", "hover", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, normal)
	for state in ["pressed", "hover_pressed"]:
		btn.add_theme_stylebox_override(state, selected)
	btn.add_theme_color_override("font_pressed_color", UIThemeApplier.TEXT_EMPHASIS)
	btn.add_theme_color_override("font_hover_pressed_color", UIThemeApplier.TEXT_EMPHASIS)
	btn.modulate = Color.WHITE

## HSlider with slider.png: empty track, filled part up to the knob, knob icon.
static func style_slider(slider: HSlider) -> void:
	var track := _sheet_style(SLIDER, Rect2(0, 3, 16, 6), 2, 3)
	var filled := _sheet_style(SLIDER, Rect2(16, 3, 16, 6), 2, 3)
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", filled)
	slider.add_theme_stylebox_override("grabber_area_highlight", filled)
	var knob := _atlas(SLIDER, Rect2(34, 0, 12, 12))
	for name in ["grabber", "grabber_highlight", "grabber_disabled"]:
		slider.add_theme_icon_override(name, knob)

## CheckButton with toggles.png: dot frame when on, empty frame when off.
static func style_toggle(btn: CheckButton) -> void:
	var on := _atlas(TOGGLES, Rect2(0, 0, TOGGLE_SIZE, TOGGLE_SIZE))
	var off := _atlas(TOGGLES, Rect2(TOGGLE_SIZE, 0, TOGGLE_SIZE, TOGGLE_SIZE))
	for suffix in ["", "_disabled", "_mirrored", "_disabled_mirrored"]:
		btn.add_theme_icon_override("checked" + suffix, on)
		btn.add_theme_icon_override("unchecked" + suffix, off)

static func _atlas(sheet: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = region
	return atlas

## Nine-slice StyleBox from one region of a sheet: `x_margin` left/right,
## `y_margin` top/bottom, same values as content margins.
static func _sheet_style(sheet: Texture2D, region: Rect2, x_margin: int, y_margin: int) -> StyleBoxTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = region
	var sb := StyleBoxTexture.new()
	sb.texture = atlas
	sb.texture_margin_left = x_margin
	sb.texture_margin_right = x_margin
	sb.texture_margin_top = y_margin
	sb.texture_margin_bottom = y_margin
	sb.content_margin_left = x_margin
	sb.content_margin_right = x_margin
	sb.content_margin_top = y_margin
	sb.content_margin_bottom = y_margin
	return sb
