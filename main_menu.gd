# main_menu.gd — Stardew-style tropical main menu
extends Control

@onready var title_label:   Label  = $CenterContainer/VBoxContainer/TitleLabel
@onready var sub_label:     Label  = $CenterContainer/VBoxContainer/SubLabel
@onready var start_btn:     Button = $CenterContainer/VBoxContainer/Buttons/StartBtn
@onready var continue_btn:  Button = $CenterContainer/VBoxContainer/Buttons/ContinueBtn
@onready var quit_btn:      Button = $CenterContainer/VBoxContainer/Buttons/QuitBtn

const VILLAGE_SCENE = "res://scenes/world/village_area.tscn"

func _ready() -> void:
	_apply_bg()
	_apply_style()
	_check_save()
	start_btn.pressed.connect(_on_start)
	continue_btn.pressed.connect(_on_continue)
	quit_btn.pressed.connect(func(): get_tree().quit())

func _check_save() -> void:
	continue_btn.disabled = not FileAccess.file_exists(GameState.SAVE_PATH)

func _on_start() -> void:
	if FileAccess.file_exists(GameState.SAVE_PATH):
		DirAccess.remove_absolute(GameState.SAVE_PATH)
	get_tree().change_scene_to_file(VILLAGE_SCENE)

func _on_continue() -> void:
	GameState.load_game()
	get_tree().change_scene_to_file(VILLAGE_SCENE)

func _apply_bg() -> void:
	# Dark forest night bg — deep green-black gradient feel via ColorRect
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("0a1a0e")
	add_child(bg)
	move_child(bg, 0)

	# Subtle vignette overlay
	var vignette = ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color(0.0, 0.0, 0.0, 0.35)
	add_child(vignette)
	move_child(vignette, 1)

func _apply_style() -> void:
	# Title — large warm gold
	title_label.add_theme_color_override("font_color", Color("e8b84b"))
	title_label.add_theme_font_size_override("font_size", 42)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Subtitle — muted green
	sub_label.add_theme_color_override("font_color", Color("7aad7a"))
	sub_label.add_theme_font_size_override("font_size", 13)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Buttons
	_style_btn(start_btn, "primary")
	_style_btn(continue_btn, "primary")
	_style_btn(quit_btn,     "danger")

func _style_btn(btn: Button, variant: String) -> void:
	UIThemeApplier.apply_button_theme(btn, variant)
