# name_entry.gd — new-game name prompt, drawn as a BookUI spread without tabs.
# Flow: MainMenu "Start" -> this scene -> Game.tscn.
# Chrome (cover / banner / two pages) mirrors book_ui.tscn anchors and textures
# so it reads as the same book. Built in code: the .tscn stays a bare root.
# Commits GameState.player_name, saves, then loads the world.
extends Control

## World entry scene (same target main_menu.gd uses for Continue).
const WORLD_SCENE_PATH: String = "res://scenes/Game.tscn"
const MENU_SCENE_PATH: String = "res://scenes/ui/MainMenu.tscn"

# Book chrome textures + nine-slice margins (UI_STYLE_GUIDE §6).
const COVER_TEX := preload("res://assets/ui/book/cover.png")
const BANNER_TEX := preload("res://assets/ui/book/banner.png")
const PAGE_LEFT_TEX := preload("res://assets/ui/book/page_left.png")
const PAGE_RIGHT_TEX := preload("res://assets/ui/book/page_right.png")
const FIELD_TEX := preload("res://assets/ui/book/text_field.png")
const FIELD_SLICE_MARGIN: int = 3

## Fixed width (px) of the input field / button column on the right page.
const INPUT_WIDTH: float = 150.0

var _name_field: LineEdit
var _confirm_btn: Button


func _ready() -> void:
	_build_ui()
	_name_field.grab_focus()


## Cover + banner + spread. Anchors copied from book_ui.tscn.
func _build_ui() -> void:
	var cover := Panel.new()
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.offset_left = 4
	cover.offset_top = 4
	cover.offset_right = -4
	cover.offset_bottom = -4
	cover.add_theme_stylebox_override("panel", _make_style(COVER_TEX, 12, 12, 12, 12))
	add_child(cover)

	var banner := PanelContainer.new()
	banner.anchor_left = 0.1
	banner.anchor_top = 0.05
	banner.anchor_right = 0.9
	banner.anchor_bottom = 0.1
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.custom_minimum_size = Vector2(0, 24)
	var banner_style := _make_style(BANNER_TEX, 12, 12, 12, 4)
	banner_style.content_margin_top = 2
	banner_style.content_margin_bottom = 2
	banner.add_theme_stylebox_override("panel", banner_style)
	add_child(banner)

	var title := Label.new()
	title.text = "NEW GAME"
	title.size_flags_vertical = Control.SIZE_SHRINK_END
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
	banner.add_child(title)

	var spread := HBoxContainer.new()
	spread.anchor_left = 0.02
	spread.anchor_top = 0.22
	spread.anchor_right = 0.98
	spread.anchor_bottom = 0.95
	spread.grow_horizontal = Control.GROW_DIRECTION_BOTH
	spread.grow_vertical = Control.GROW_DIRECTION_BOTH
	spread.add_theme_constant_override("separation", 0)
	add_child(spread)

	var page_left := _make_page(PAGE_LEFT_TEX)
	var page_right := _make_page(PAGE_RIGHT_TEX)
	spread.add_child(page_left)
	spread.add_child(page_right)

	_build_left_page(page_left)
	_build_right_page(page_right)


## Left page: prompt text.
func _build_left_page(page: Panel) -> void:
	var center := _make_centered(page)
	var prompt := Label.new()
	prompt.text = "What is your name?"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
	prompt.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_XXL)
	UIThemeApplier.apply_display_font(prompt)
	center.add_child(prompt)


## Right page: input field + confirm button.
func _build_right_page(page: Panel) -> void:
	var center := _make_centered(page)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(INPUT_WIDTH, 0)
	center.add_child(box)

	_name_field = LineEdit.new()
	_name_field.max_length = TextUtil.MAX_NAME_LENGTH
	_name_field.placeholder_text = "Your name"
	_name_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var field_style := _make_style(FIELD_TEX, FIELD_SLICE_MARGIN, FIELD_SLICE_MARGIN, FIELD_SLICE_MARGIN, FIELD_SLICE_MARGIN)
	field_style.content_margin_left = 6
	field_style.content_margin_right = 6
	field_style.content_margin_top = 4
	field_style.content_margin_bottom = 4
	_name_field.add_theme_stylebox_override("normal", field_style)
	_name_field.add_theme_stylebox_override("focus", field_style)
	_name_field.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
	_name_field.add_theme_color_override("font_placeholder_color", UIThemeApplier.TEXT_DISABLED)
	_name_field.add_theme_color_override("caret_color", UIThemeApplier.TEXT_DEFAULT)
	_name_field.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_M)
	_name_field.text_changed.connect(_on_text_changed)
	_name_field.text_submitted.connect(func(_t: String) -> void: _on_confirm())
	box.add_child(_name_field)

	_confirm_btn = Button.new()
	_confirm_btn.text = "Begin"
	_confirm_btn.disabled = true
	UIThemeApplier.apply_button_theme(_confirm_btn, "confirm")
	_confirm_btn.pressed.connect(_on_confirm)
	box.add_child(_confirm_btn)


## Page panel, styled like PageLeft/PageRight (nine-slice 7/3/7/7).
func _make_page(tex: Texture2D) -> Panel:
	var page := Panel.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_stylebox_override("panel", _make_style(tex, 7, 3, 7, 7))
	return page


## Full-rect CenterContainer inside a page, for centered content.
func _make_centered(page: Panel) -> CenterContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.add_child(center)
	return center


## Nine-slice StyleBoxTexture with per-side margins (left, top, right, bottom).
func _make_style(tex: Texture2D, left: int, top: int, right: int, bottom: int) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = left
	sb.texture_margin_top = top
	sb.texture_margin_right = right
	sb.texture_margin_bottom = bottom
	return sb


## Blocks empty / whitespace-only / marker-only names.
func _on_text_changed(new_text: String) -> void:
	_confirm_btn.disabled = TextUtil.sanitize_name(new_text).is_empty()


func _on_confirm() -> void:
	var chosen: String = TextUtil.sanitize_name(_name_field.text)
	if chosen.is_empty():
		return
	AudioManager.play_sfx("menu_click")
	GameState.player_name = chosen
	GameState.save_game()  # persist now so Continue always has the name
	get_tree().change_scene_to_file(WORLD_SCENE_PATH)


## ui_cancel (also Android back via BackButtonBridge) returns to main menu.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(MENU_SCENE_PATH)
