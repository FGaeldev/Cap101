# UIThemeApplier.gd
# Central button theming. Slices one sprite sheet into per-state StyleBoxTexture.
# Sheet layout: 320x144px, 5 cols x 6 rows, cell 64x24.
# Row 0 = header labels (skipped, not drawn art).
# Rows 1-5 = 5 cosmetic variations of the same button (hand-painted for
# organic variety, not semantically distinct like the old primary/secondary/
# confirm/danger rows) — one is picked at random per apply_button_theme()
# call. Cols 0-4 = states.
extends Node

const SHEET := preload("res://assets/ui/buttons_sheet.png")
const ICON_SHEET := preload("res://assets/ui/icon_buttons_sheet.png")
const DIALOGUE_BOX := preload("res://assets/ui/dialogue_box.png")

# Generic floating-panel chrome (popups, HUD readouts)
const PANEL := preload("res://assets/ui/book/banner.png")
const PANEL_SLICE_MARGIN := 4

# puzzle_panel's main panel background.
const PUZZLE_PANEL_BG := preload("res://assets/ui/book/puzzel.png")
const PUZZLE_PANEL_SLICE_MARGIN := 8

# Thin single-line readout strip (HUD quest label, top-left). 
const HEADER := preload("res://assets/ui/book/quest.png")
const HEADER_SLICE_MARGIN := 8

# Display face — HERO/XXL sizes only (main menu title, modal headers).
# Body text uses the project-wide default font (Project Settings > GUI >
# Theme > Custom Font), not this — don't add a FONT_BODY const/override here,
# it'd just duplicate the default and risk drifting out of sync with it.
const FONT_DISPLAY := preload("res://assets/ui/fonts/AlegreyaSC-Bold.ttf")

# Button Sprite Size
const CELL_W := 64
const CELL_H := 24

# Row index INSIDE the sheet (0-based, row 0 is the skipped header row).
# 5 rows of purely cosmetic variation.
const VARIANT_ROW_START := 0
const NUM_VARIANT_ROWS  := 4

# Column index (0-based) per state
const COL_DEFAULT  := 0
const COL_HOVER    := 1
const COL_PRESSED  := 2
const COL_DISABLED := 3
const COL_FOCUSED  := 4

# Nine-slice margin
const SLICE_MARGIN := 3

# Text colors (5 in the whole system — SUCCESS/ERROR added for challenge/
# puzzle correct-wrong feedback, GDD §6 open question 6 / TDD §8. Chosen to
# read clearly against the book/parchment panel bg, not reused from the
# legacy tropical palette (#2d9a5a/#8b2e2e) that puzzle_panel.gd still
# hardcodes — that's a separate migration, tracked, not done here.)
const TEXT_DEFAULT  := Color("4C2020")  # inky, default label color
const TEXT_EMPHASIS := Color("39290F")  # book-cover red, pops against tan buttons
const TEXT_DISABLED := Color("332B24")  # muted tan-gray, low contrast on purpose
const COLOR_SUCCESS := Color("50ac61ff")  # correct-answer feedback, challenge/puzzle panels
const COLOR_ERROR   := Color("ab3838ff")  # wrong-answer feedback, challenge/puzzle panels

# Font size scale
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


## chops 1 cell out of a sprite sheet + wraps as nine-slice. used by both
## button sheet + icon sheet, only the atlas/cell-size/margin numbers differ.
func _make_sheet_cell_style(sheet: Texture2D, row: int, col: int, cell_w: int, cell_h: int, slice: int) -> StyleBoxTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(col * cell_w, row * cell_h, cell_w, cell_h)
	return _make_panel_style(atlas, slice)

## Builds one StyleBoxTexture for a given row/col cell of the sheet.
func _make_style(row: int, col: int) -> StyleBoxTexture:
	return _make_sheet_cell_style(SHEET, row, col, CELL_W, CELL_H, SLICE_MARGIN)

## Applies all 5 states to a Button at once.
## variant: kept for call-site compatibility (existing scripts still pass
## "primary"/"secondary"/"confirm"/"danger") but no longer selects a row —
## row art is now 5 cosmetic variations of one button, chosen at random
## here rather than looked up by name. Picked once per call, so a button
## keeps the same look for its lifetime unless apply_button_theme() is
## called on it again (e.g. from a refresh()).
func apply_button_theme(btn: Button, _variant: String) -> void:
	var row: int = VARIANT_ROW_START + randi() % NUM_VARIANT_ROWS

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
	return _make_sheet_cell_style(ICON_SHEET, row, col, ICON_CELL_W, ICON_CELL_H, ICON_SLICE_MARGIN)

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
	return _make_panel_style(DIALOGUE_BOX, DIALOGUE_SLICE_MARGIN)

## one func, all nine-slice panels. texture + slice (border px) required.
## content_margin: inset for stuff sitting inside panel. 0 = skip (dialogue box
## doesn't want one). pad_lr/pad_tb: override content pad L/R vs T/B separately
## (header wants tight top/bottom, wide left/right) — leave -1 to use
## content_margin for all 4 sides.
func _make_panel_style(texture: Texture2D, slice: int, content_margin: int = 0, pad_lr: int = -1, pad_tb: int = -1) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = texture
	sb.texture_margin_left   = slice
	sb.texture_margin_top    = slice
	sb.texture_margin_right  = slice
	sb.texture_margin_bottom = slice
	if pad_lr >= 0 or pad_tb >= 0:
		# header-style: L/R differ from T/B
		sb.content_margin_left   = pad_lr if pad_lr >= 0 else content_margin
		sb.content_margin_right  = pad_lr if pad_lr >= 0 else content_margin
		sb.content_margin_top    = pad_tb if pad_tb >= 0 else content_margin
		sb.content_margin_bottom = pad_tb if pad_tb >= 0 else content_margin
	elif content_margin > 0:
		# normal case: same pad all 4 sides
		sb.content_margin_left   = content_margin
		sb.content_margin_top    = content_margin
		sb.content_margin_right  = content_margin
		sb.content_margin_bottom = content_margin
	return sb

## generic popup chrome (puzzle_panel's nested SentenceBox, any future popup).
## smaller content_margin for nested sub-panels so padding don't double up.
func make_panel_style(content_margin: int = 14) -> StyleBoxTexture:
	return _make_panel_style(PANEL, PANEL_SLICE_MARGIN, content_margin)

## puzzle_panel's own outer bg (puzzel.png). separate from make_panel_style
## above cuz that one still backs SentenceBox etc on old placeholder tex —
## this is the real dedicated art for main panel only.
func make_puzzle_panel_style(content_margin: int = 14) -> StyleBoxTexture:
	return _make_panel_style(PUZZLE_PANEL_BG, PUZZLE_PANEL_SLICE_MARGIN, content_margin)

## thin 1-line readout bg (HUD quest label top-left). quest.png = real art,
## header.png was old placeholder.
func make_header_style() -> StyleBoxTexture:
	return _make_panel_style(HEADER, HEADER_SLICE_MARGIN, 0, 10, 4)
