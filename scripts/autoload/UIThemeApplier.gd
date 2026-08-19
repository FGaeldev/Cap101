# UIThemeApplier.gd
# Central button theming. Slices one sprite sheet into per-state StyleBoxTexture.
# Sheet layout: 320x120px, 5 cols x 5 rows, cell 64x24.
# Row 0 = header labels (skipped, not drawn art).
# Rows 1-4 = button variants. Cols 0-4 = states.
extends Node

const SHEET := preload("res://assets/ui/buttons_sheet.png")
const ICON_SHEET := preload("res://assets/ui/icon_buttons_sheet.png")
const DIALOGUE_BOX := preload("res://assets/ui/dialogue_box.png")

# Display face — HERO/XXL sizes only (main menu title, modal headers).
# Body text uses the project-wide default font (Project Settings > GUI >
# Theme > Custom Font), not this — don't add a FONT_BODY const/override here,
# it'd just duplicate the default and risk drifting out of sync with it.
const FONT_DISPLAY := preload("res://assets/ui/fonts/AlegreyaSC-Bold.ttf")

# Button Sprite Size
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
const SLICE_MARGIN := 10

# Text colors (only 3 in the whole system)
const TEXT_DEFAULT  := Color("4C2020")  # inky, default label color
const TEXT_EMPHASIS := Color("39290F")  # book-cover red, pops against tan buttons
const TEXT_DISABLED := Color("332B24")  # muted tan-gray, low contrast on purpose

# Font size scale — inferred from every add_theme_font_size_override in the
# project (raw values found: 8, 9, 10, 11, 12, 13, 14, 16, 42). Near-duplicate
# one-offs (9 vs 11, 10 vs 11) are organic drift, not intentional distinctions —
# consolidated here into 7 steps. Migrate call sites to these over time instead
# of hardcoding new numbers.
const FONT_SIZE_HERO    := 38  # full-screen display text — main menu title only
const FONT_SIZE_XXL     := 14  # modal/popup headers — quest complete title
const FONT_SIZE_XL      := 12  # emphasized inline text — dictionary word (akeanon), card highlights
const FONT_SIZE_L       := 11  # supporting subtitle / instructional text — puzzle hints, menu subtitle
const FONT_SIZE_M       := 10  # default body/button text — most buttons, panel titles, feedback text
const FONT_SIZE_S       := 8  # secondary/compact text — meta labels, quest names, small buttons
const FONT_SIZE_XS      := 6   # smallest — tags, encounter counts, fine-print annotations

# Icon Button Sprite Size
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

## Applies the display face to a Label/Button/RichTextLabel-type control.
## Call alongside a FONT_SIZE_HERO/FONT_SIZE_XXL size override — display face
## is only for those two sizes, per UI Style Guide §3. Pairs with the existing
## add_theme_font_size_override("font_size", ...) call at each call site;
## doesn't replace it.
func apply_display_font(control: Control) -> void:
	control.add_theme_font_override("font", FONT_DISPLAY)


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
	btn.add_theme_color_override("font_pressed_color", TEXT_DISABLED)
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

# Nine-slice margin
const DIALOGUE_SLICE_MARGIN := 12

func make_dialogue_style() -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = DIALOGUE_BOX
	sb.texture_margin_left   = DIALOGUE_SLICE_MARGIN
	sb.texture_margin_top    = DIALOGUE_SLICE_MARGIN
	sb.texture_margin_right  = DIALOGUE_SLICE_MARGIN
	sb.texture_margin_bottom = DIALOGUE_SLICE_MARGIN
	return sb
