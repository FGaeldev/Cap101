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
const PANEL := preload("res://assets/ui/book/selection_frame_unselected.png")
const PANEL_SLICE_MARGIN := 4

# puzzle_panel's main panel background. Border measured at ~4px (fill starts
# y=5) — margin below matches that, not guessed, per the SLICE_MARGIN=10
# lesson (buttons_sheet.png tear postmortem).
const PUZZLE_PANEL_BG := preload("res://assets/ui/book/puzzel.png")
const PUZZLE_PANEL_SLICE_MARGIN := 5

# Thin single-line readout strip (HUD quest label, top-left). Border
# measured at ~1px (fill starts y=1) — margin 2 leaves headroom without
# repeating the oversized-margin seam bug.
const HEADER := preload("res://assets/ui/book/quest.png")
const HEADER_SLICE_MARGIN := 2

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

# Nine-slice margin. Real border in buttons_sheet.png measures ~1px —
# margin kept at 3 (not 1:1) for headroom, but was 10 before this fix,
# which caused a seam/tear on any button under 20px tall (MainMenu buttons
# included, since they set no explicit height). Carried forward from
# earlier fix — see UI Style Guide / prior chat for the seam repro.
const SLICE_MARGIN := 3

# Text colors (5 in the whole system — SUCCESS/ERROR added for challenge/
# puzzle correct-wrong feedback, GDD §6 open question 6 / TDD §8. Chosen to
# read clearly against the book/parchment panel bg, not reused from the
# legacy tropical palette (#2d9a5a/#8b2e2e) that puzzle_panel.gd still
# hardcodes — that's a separate migration, tracked, not done here.)
const TEXT_DEFAULT  := Color("4C2020")  # inky, default label color
const TEXT_EMPHASIS := Color("39290F")  # book-cover red, pops against tan buttons
const TEXT_DISABLED := Color("332B24")  # muted tan-gray, low contrast on purpose
const COLOR_SUCCESS := Color("2F6B3A")  # correct-answer feedback, challenge/puzzle panels
const COLOR_ERROR   := Color("8B2E2E")  # wrong-answer feedback, challenge/puzzle panels

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

## Generic popup/floating-panel chrome (puzzle_panel, any future non-BookUI
## popup). content_margin defaults to 14 all sides; pass a smaller value for
## nested sub-panels (e.g. puzzle_panel's SentenceBox) so nesting doesn't
## double up the inset.
func make_panel_style(content_margin: int = 14) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = PANEL
	sb.texture_margin_left   = PANEL_SLICE_MARGIN
	sb.texture_margin_top    = PANEL_SLICE_MARGIN
	sb.texture_margin_right  = PANEL_SLICE_MARGIN
	sb.texture_margin_bottom = PANEL_SLICE_MARGIN
	sb.content_margin_left   = content_margin
	sb.content_margin_top    = content_margin
	sb.content_margin_right  = content_margin
	sb.content_margin_bottom = content_margin
	return sb

## puzzle_panel's main outer panel background (puzzel.png). Distinct from
## make_panel_style() — that one still backs puzzle_panel's nested
## SentenceBox and any other generic popup chrome on the old placeholder
## texture; this is specifically the new dedicated art for the main panel.
func make_puzzle_panel_style(content_margin: int = 14) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = PUZZLE_PANEL_BG
	sb.texture_margin_left   = PUZZLE_PANEL_SLICE_MARGIN
	sb.texture_margin_top    = PUZZLE_PANEL_SLICE_MARGIN
	sb.texture_margin_right  = PUZZLE_PANEL_SLICE_MARGIN
	sb.texture_margin_bottom = PUZZLE_PANEL_SLICE_MARGIN
	sb.content_margin_left   = content_margin
	sb.content_margin_top    = content_margin
	sb.content_margin_right  = content_margin
	sb.content_margin_bottom = content_margin
	return sb

## Thin single-line readout background (HUD quest label, top-left). Now
## quest.png (dedicated art) — was header.png (generic placeholder).
func make_header_style() -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = HEADER
	sb.texture_margin_left   = HEADER_SLICE_MARGIN
	sb.texture_margin_top    = HEADER_SLICE_MARGIN
	sb.texture_margin_right  = HEADER_SLICE_MARGIN
	sb.texture_margin_bottom = HEADER_SLICE_MARGIN
	sb.content_margin_left   = 10
	sb.content_margin_right  = 10
	sb.content_margin_top    = 4
	sb.content_margin_bottom = 4
	return sb
