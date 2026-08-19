# main_menu.gd — Stardew-style tropical main menu
extends Control

@onready var title_label:   Label  = $BookPanel/Spread/LeftSide/CenterContainer/VBoxContainer/TitleLabel
@onready var sub_label:     Label  = $BookPanel/Spread/LeftSide/CenterContainer/VBoxContainer/SubLabel
@onready var start_btn:     Button = $BookPanel/Spread/RightPage/CenterContainer/Buttons/StartBtn
@onready var continue_btn:  Button = $BookPanel/Spread/RightPage/CenterContainer/Buttons/ContinueBtn
@onready var settings_btn:  Button = $BookPanel/Spread/RightPage/CenterContainer/Buttons/SettingsBtn
@onready var quit_btn:      Button = $BookPanel/Spread/RightPage/CenterContainer/Buttons/QuitBtn

const MAIN = "res://scenes/Game.tscn"

func _ready() -> void:
	_apply_bg()
	_apply_style()
	_check_save()
	start_btn.pressed.connect(_on_start)
	continue_btn.pressed.connect(_on_continue)
	settings_btn.pressed.connect(_on_settings)
	quit_btn.pressed.connect(func():
		AudioManager.play_sfx("menu_click")
		get_tree().quit()
	)

func _check_save() -> void:
	continue_btn.disabled = not FileAccess.file_exists(GameState.SAVE_PATH)

func _on_start() -> void:
	AudioManager.play_sfx("menu_click")
	if FileAccess.file_exists(GameState.SAVE_PATH):
		DirAccess.remove_absolute(GameState.SAVE_PATH)
	get_tree().change_scene_to_file(MAIN)

func _on_continue() -> void:
	AudioManager.play_sfx("menu_click")
	GameState.load_game()
	get_tree().change_scene_to_file(MAIN)

func _on_settings() -> void:
	AudioManager.play_sfx("menu_click")
	BookUI.open("settings")
	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()

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
	# Title — book-cover gold (UI_STYLE_GUIDE §2)
	title_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	title_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_HERO)
	UIThemeApplier.apply_display_font(title_label)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Subtitle — secondary/meta text role (UI_STYLE_GUIDE §2)
	sub_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DISABLED)
	sub_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_L)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Buttons
	_style_btn(start_btn, "secondary")
	_style_btn(continue_btn, "secondary")
	_style_btn(settings_btn, "secondary")
	_style_btn(quit_btn,     "secondary")

func _style_btn(btn: Button, variant: String) -> void:
	UIThemeApplier.apply_button_theme(btn, variant)
