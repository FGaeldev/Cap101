# UIThemeApplier.gd
# Central button theming. Slices one sprite sheet into per-state StyleBoxTexture.
# Sheet layout: 320x120px, 5 cols x 5 rows, cell 64x24.
# Row 0 = header labels (skipped, not drawn art).
# Rows 1-4 = button variants. Cols 0-4 = states.
extends Node

const SHEET := preload("res://assets/ui/buttons_sheet.png")

const CELL_W := 64
const CELL_H := 24

# Row index INSIDE the sheet (0-based, row 0 is the skipped header row)
const ROW_PRIMARY   := 1
const ROW_SECONDARY := 2
const ROW_CONFIRM   := 3
const ROW_DANGER    := 4

# Column index (0-based) per state
const COL_DEFAULT  := 0
const COL_HOVER    := 1
const COL_PRESSED  := 2
const COL_DISABLED := 3
const COL_FOCUSED  := 4

# Nine-slice margin (matches 6px corner spec)
const SLICE_MARGIN := 6

# Text colors (only 3 in the whole system)
const TEXT_DEFAULT  := Color("f0faf0")
const TEXT_EMPHASIS := Color("e8b84b")
const TEXT_DISABLED := Color("8a8f8a")

const ICON_SHEET := preload("res://assets/ui/icon_buttons_sheet.png")

const ICON_CELL_W := 24
const ICON_CELL_H := 24
const ICON_SLICE_MARGIN := 4

# Row index inside icon sheet (0-based)
const ICON_ROW_DICTIONARY := 0
const ICON_ROW_CLOSE      := 1
const ICON_ROW_MENU       := 2

# Map variant name -> row index, so callers use strings not magic numbers
const VARIANT_ROWS := {
	"primary":   ROW_PRIMARY,
	"secondary": ROW_SECONDARY,
	"confirm":   ROW_CONFIRM,
	"danger":    ROW_DANGER,
}

const ICON_VARIANT_ROWS := {
	"dictionary": ICON_ROW_DICTIONARY,
	"close":      ICON_ROW_CLOSE,
	"menu":       ICON_ROW_MENU,
}


## Builds one StyleBoxTexture for a given row/col cell of the sheet.
func _make_style(row: int, col: int) -> StyleBoxTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = SHEET
	atlas.region = Rect2(col * CELL_W, row * CELL_H, CELL_W, CELL_H)

	var sb := StyleBoxTexture.new()
	sb.texture = atlas
	sb.texture_margin_left = SLICE_MARGIN
	sb.texture_margin_top = SLICE_MARGIN
	sb.texture_margin_right = SLICE_MARGIN
	sb.texture_margin_bottom = SLICE_MARGIN
	return sb

## Applies all 5 states to a Button at once.
## variant: "primary" | "secondary" | "confirm" | "danger"
func apply_button_theme(btn: Button, variant: String) -> void:
	
	if not VARIANT_ROWS.has(variant):
		push_error("UIThemeApplier: unknown button variant '%s'" % variant)
		return
	var row: int = VARIANT_ROWS[variant]

	btn.add_theme_stylebox_override("normal",   _make_style(row, COL_DEFAULT))
	btn.add_theme_stylebox_override("hover",    _make_style(row, COL_HOVER))
	btn.add_theme_stylebox_override("pressed",  _make_style(row, COL_PRESSED))
	btn.add_theme_stylebox_override("disabled", _make_style(row, COL_DISABLED))
	btn.add_theme_stylebox_override("focus",    _make_style(row, COL_FOCUSED))

	# Text colors: default everywhere, gold on press (per spec), gray disabled
	btn.add_theme_color_override("font_color", TEXT_DEFAULT)
	btn.add_theme_color_override("font_hover_color", TEXT_DEFAULT)
	btn.add_theme_color_override("font_pressed_color", TEXT_EMPHASIS)
	btn.add_theme_color_override("font_disabled_color", TEXT_DISABLED)
	btn.add_theme_color_override("font_focus_color", TEXT_DEFAULT)

## Builds one StyleBoxTexture for a given row/col cell of the sheet.
func _make_icon_style(row: int, col: int) -> StyleBoxTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = ICON_SHEET
	atlas.region = Rect2(col * ICON_CELL_W, row * ICON_CELL_H, ICON_CELL_W, ICON_CELL_H)

	var sb := StyleBoxTexture.new()
	sb.texture = atlas
	sb.texture_margin_left = ICON_SLICE_MARGIN
	sb.texture_margin_top = ICON_SLICE_MARGIN
	sb.texture_margin_right = ICON_SLICE_MARGIN
	sb.texture_margin_bottom = ICON_SLICE_MARGIN
	return sb

## variant: "dictionary" | "close" | "menu"
func apply_icon_button_theme(btn: Button, variant: String) -> void:
	if not ICON_VARIANT_ROWS.has(variant):
		push_error("UIThemeApplier: unknown icon variant '%s'" % variant)
		return
	var row: int = ICON_VARIANT_ROWS[variant]

	btn.add_theme_stylebox_override("normal",   _make_icon_style(row, COL_DEFAULT))
	btn.add_theme_stylebox_override("hover",    _make_icon_style(row, COL_HOVER))
	btn.add_theme_stylebox_override("pressed",  _make_icon_style(row, COL_PRESSED))
	btn.add_theme_stylebox_override("disabled", _make_icon_style(row, COL_DISABLED))
	btn.add_theme_stylebox_override("focus",    _make_icon_style(row, COL_FOCUSED))

	btn.custom_minimum_size = Vector2(ICON_CELL_W*0.8, ICON_CELL_H*0.8)
	btn.text = ""  # icon-only, no label
