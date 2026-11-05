extends Control

const InstructionsPanel := preload("res://scripts/ui/instructions_panel.gd")

@onready var master_volume_label: Label = $Scroll/VBoxContainer/MasterVolumeLabel
@onready var volume_slider: HSlider = $Scroll/VBoxContainer/MasterVolumeSlider
@onready var music_label: Label = $Scroll/VBoxContainer/MusicLabel
@onready var music_toggle: CheckButton = $Scroll/VBoxContainer/MusicToggle
@onready var sfx_label: Label = $Scroll/VBoxContainer/SFXLabel
@onready var sfx_toggle: CheckButton = $Scroll/VBoxContainer/SFXToggle
@onready var ui_scale_label: Label = $Scroll/VBoxContainer/UIScaleLabel
@onready var ui_scale_row: HBoxContainer = $Scroll/VBoxContainer/UIScaleRow
@onready var accessibility_label: Label = $Scroll/VBoxContainer/AccessibilityLabel
@onready var color_blind_label: Label = $Scroll/VBoxContainer/ColorBlindLabel
@onready var color_blind_hint: Label = $Scroll/VBoxContainer/ColorBlindHint
@onready var color_blind_toggle: CheckButton = $Scroll/VBoxContainer/ColorBlindToggle
@onready var dev_mode_label: Label = $Scroll/VBoxContainer/DevModeLabel
@onready var dev_mode_toggle: CheckButton = $Scroll/VBoxContainer/DevModeToggle
@onready var quit_btn: Button = $Scroll/VBoxContainer/QuitBtn

func _ready() -> void:
	for lbl in [master_volume_label, music_label, sfx_label, ui_scale_label, color_blind_label, dev_mode_label]:
		lbl.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
		lbl.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_M)
	accessibility_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	accessibility_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_XL)
	color_blind_hint.add_theme_color_override("font_color", UIThemeApplier.TEXT_DISABLED)
	color_blind_hint.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_XS)
	color_blind_toggle.toggled.connect(Accessibility.set_color_blind)

	volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(0)) * 100
	volume_slider.value_changed.connect(_on_volume_changed)
	music_toggle.toggled.connect(_on_music_toggled)
	sfx_toggle.toggled.connect(_on_sfx_toggled)
	dev_mode_toggle.toggled.connect(_on_dev_mode_toggled)
	_build_ui_scale_row()
	UIThemeApplier.apply_button_theme(quit_btn, "danger")
	quit_btn.pressed.connect(func(): BookUI.confirm_exit_to_menu())
	_build_instructions_button()

	music_toggle.button_pressed = true
	sfx_toggle.button_pressed = true
	volume_slider.value = 50

## BookUI pages are instantiated once and toggled via .visible on every
## subsequent open (TDD §8 page pattern) — _ready() never runs again after
## the first open. dev_mode lives on GameState (session-only), not on this
## page — re-sync the checkbox to it every time Settings opens so it can
## never drift stale from whatever Journal's dev page is actually reading.
##
## Quit button lives here again (moved back from BookUI's tab bar) — hidden
## when opened from MainMenu itself, same guard BookUI.open() used to apply
## to the tab-bar button (no active session there, nothing sane to return to).
func refresh() -> void:
	TutorialManager.start("ui_scale")
	dev_mode_toggle.set_pressed_no_signal(GameState.dev_mode)
	color_blind_toggle.set_pressed_no_signal(Accessibility.color_blind)
	for i in UIScale.OPTIONS.size():
		ui_scale_row.get_child(i).set_pressed_no_signal(UIScale.OPTIONS[i] == UIScale.value)
	quit_btn.visible = not BookUI.is_main_menu_context()

func _on_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(value / 100.0))

func _on_music_toggled(muted: bool) -> void:
	AudioManager.set_music_volume(1.0 if muted else 0.0)

func _on_sfx_toggled(muted: bool) -> void:
	AudioManager.set_sfx_volume(1.0 if muted else 0.0)

## Dev-only: flips GameState.dev_mode, which shows/hides BookUI's Dev tab
## (warp + cutscene menu, page_dev.gd) immediately via refresh_dev_tab().
func _on_dev_mode_toggled(enabled: bool) -> void:
	GameState.dev_mode = enabled
	BookUI.refresh_dev_tab()
	GameState.set_flag("story_done_papa_jobert_scene1")
	GameState.set_flag("seen_chapter1_scene1")
	GameState.set_flag("story_done_lola_jonabel_scene1")

## First row of Settings, so the how-to-play help is easy to find mid-game.
func _build_instructions_button() -> void:
	var btn := Button.new()
	btn.text = "Instructions"
	UIThemeApplier.apply_button_theme(btn, "primary")
	btn.pressed.connect(func():
		AudioManager.play_sfx("menu_click")
		InstructionsPanel.open(get_tree())
	)
	var rows: Node = quit_btn.get_parent()
	rows.add_child(btn)
	rows.move_child(btn, 0)

## One radio button per UIScale option. Applies on press.
func _build_ui_scale_row() -> void:
	var group := ButtonGroup.new()
	for option: float in UIScale.OPTIONS:
		var btn := Button.new()
		btn.text = "%sx" % String.num(option).trim_suffix(".0")
		btn.toggle_mode = true
		btn.button_group = group
		btn.custom_minimum_size = Vector2(36, 24)
		UIThemeApplier.apply_button_theme(btn, "primary")
		btn.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
		btn.pressed.connect(UIScale.set_value.bind(option))
		ui_scale_row.add_child(btn)
