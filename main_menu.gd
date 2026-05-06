# main_menu.gd — Main menu screen
extends Control

@onready var title_label:  Label  = $TitleBlock/TitleLabel
@onready var sub_label:    Label  = $TitleBlock/SubLabel
@onready var start_btn:    Button = $ButtonBlock/StartBtn
@onready var continue_btn: Button = $ButtonBlock/ContinueBtn
@onready var quit_btn:     Button = $ButtonBlock/QuitBtn
@onready var title_block:  VBoxContainer = $TitleBlock
@onready var button_block: VBoxContainer = $ButtonBlock

const VILLAGE_SCENE = "res://scenes/world/village_area.tscn"

func _ready() -> void:
	_apply_style()
	_check_save()
	start_btn.pressed.connect(_on_start)
	continue_btn.pressed.connect(_on_continue)
	quit_btn.pressed.connect(func(): get_tree().quit())

func _check_save() -> void:
	# Disable continue if no save exists
	continue_btn.disabled = not FileAccess.file_exists(GameState.SAVE_PATH)

func _on_start() -> void:
	# Wipe save, fresh run
	if FileAccess.file_exists(GameState.SAVE_PATH):
		DirAccess.remove_absolute(GameState.SAVE_PATH)
	get_tree().change_scene_to_file(VILLAGE_SCENE)

func _on_continue() -> void:
	GameState.load_game()
	get_tree().change_scene_to_file(VILLAGE_SCENE)

func _apply_style() -> void:
	# BG — deep tropical night
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color("0d1f12")
	var bg_panel = $BG
	bg_panel.add_theme_stylebox_override("panel", bg_style)

	# Position title block — upper third
	title_block.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title_block.position = Vector2(
		get_viewport_rect().size.x / 2.0 - 100,
		60
	)
	title_block.alignment = BoxContainer.ALIGNMENT_CENTER

	# Title text
	title_label.add_theme_color_override("font_color", Color("e8b84b"))
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Subtitle
	sub_label.add_theme_color_override("font_color", Color("a8c5a0"))
	sub_label.add_theme_font_size_override("font_size", 11)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Button block — center
	button_block.set_anchors_preset(Control.PRESET_CENTER)
	button_block.position = Vector2(
		get_viewport_rect().size.x / 2.0 - 60,
		get_viewport_rect().size.y / 2.0 - 40
	)
	button_block.alignment = BoxContainer.ALIGNMENT_CENTER
	button_block.add_theme_constant_override("separation", 10)

	# Style each button
	for btn in [start_btn, continue_btn]:
		_style_btn(btn, Color("4a7c59"), Color("fdf6e3"))
	_style_btn(quit_btn, Color("5c3a1e"), Color("fdf6e3"))

func _style_btn(btn: Button, bg: Color, text_col: Color) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color     = bg
	normal.border_color = bg.darkened(0.3)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(3)
	normal.set_content_margin(SIDE_LEFT, 40)
	normal.set_content_margin(SIDE_RIGHT, 40)
	normal.set_content_margin(SIDE_TOP, 8)
	normal.set_content_margin(SIDE_BOTTOM, 8)
	var hover = normal.duplicate()
	hover.bg_color = bg.lightened(0.15)
	var pressed = normal.duplicate()
	pressed.bg_color = bg.darkened(0.2)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_font_size_override("font_size", 13)
	btn.custom_minimum_size = Vector2(160, 0)
