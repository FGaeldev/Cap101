extends Control

const InstructionsPanel := preload("res://scripts/ui/instructions_panel.gd")

@onready var master_volume_label: Label = $Scroll/VBoxContainer/MasterVolumeLabel
@onready var volume_slider: HSlider = $Scroll/VBoxContainer/MasterVolumeSlider
@onready var music_label: Label = $Scroll/VBoxContainer/MusicLabel
@onready var music_slider: HSlider = $Scroll/VBoxContainer/MusicSlider
@onready var sfx_label: Label = $Scroll/VBoxContainer/SFXLabel
@onready var sfx_slider: HSlider = $Scroll/VBoxContainer/SFXSlider
@onready var ui_scale_label: Label = $Scroll/VBoxContainer/UIScaleLabel
@onready var ui_scale_row: HBoxContainer = $Scroll/VBoxContainer/UIScaleRow
@onready var accessibility_label: Label = $Scroll/VBoxContainer/AccessibilityLabel
@onready var color_blind_label: Label = $Scroll/VBoxContainer/ColorBlindLabel
@onready var color_blind_hint: Label = $Scroll/VBoxContainer/ColorBlindHint
@onready var color_blind_toggle: CheckButton = $Scroll/VBoxContainer/ColorBlindToggle
## The "Help" button (built in code, first row): opens the instructions.
var instructions_btn: Button
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
	# Subtitle under "UI Scale" (was a tutorial pop-up that covered this page).
	var scale_hint := Label.new()
	scale_hint.text = "Makes the screen bigger or smaller."
	scale_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scale_hint.add_theme_color_override("font_color", UIThemeApplier.TEXT_DISABLED)
	scale_hint.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_XS)
	ui_scale_label.add_sibling(scale_hint)

	# Start from the saved volumes (AudioManager loads them at boot).
	volume_slider.set_value_no_signal(_bus_percent("Master"))
	music_slider.set_value_no_signal(_bus_percent(AudioManager.MUSIC_BUS))
	sfx_slider.set_value_no_signal(_bus_percent(AudioManager.SFX_BUS))
	volume_slider.value_changed.connect(_on_volume_changed)
	music_slider.value_changed.connect(func(v: float): AudioManager.set_music_volume(v / 100.0))
	sfx_slider.value_changed.connect(func(v: float): AudioManager.set_sfx_volume(v / 100.0))
	dev_mode_toggle.toggled.connect(_on_dev_mode_toggled)
	_build_ui_scale_row()
	UIThemeApplier.apply_button_theme(quit_btn, "danger")
	quit_btn.pressed.connect(func(): BookUI.confirm_exit_to_menu())
	_build_instructions_button()


## BookUI pages are instantiated once and toggled via .visible on every
## subsequent open (TDD §8 page pattern) — _ready() never runs again after
## the first open. dev_mode lives on GameState (saved in settings.cfg), not on this
## page — re-sync the checkbox to it every time Settings opens so it can
## never drift stale from whatever Journal's dev page is actually reading.
##
## Quit button lives here again (moved back from BookUI's tab bar) — hidden
## when opened from MainMenu itself, same guard BookUI.open() used to apply
## to the tab-bar button (no active session there, nothing sane to return to).
func refresh() -> void:
	dev_mode_toggle.set_pressed_no_signal(GameState.dev_mode)
	color_blind_toggle.set_pressed_no_signal(Accessibility.color_blind)
	# Read the buses, not this page's last values: the book and the separated
	# menus each have their own copy of this page.
	volume_slider.set_value_no_signal(_bus_percent("Master"))
	music_slider.set_value_no_signal(_bus_percent(AudioManager.MUSIC_BUS))
	sfx_slider.set_value_no_signal(_bus_percent(AudioManager.SFX_BUS))
	for i in UIScale.OPTIONS.size():
		ui_scale_row.get_child(i).set_pressed_no_signal(UIScale.OPTIONS[i] == UIScale.value)
	if _movement_row:
		for btn: Button in _movement_row.get_children():
			btn.set_pressed_no_signal(btn.get_meta("kind") == Accessibility.movement_controls)
	# separated menus: Exit to menu lives on the pause menu instead.
	quit_btn.visible = not BookUI.is_main_menu_context() and not BookUI.separate_menus
	# separated menus: Help is on the pause menu (and the main menu has its own).
	instructions_btn.visible = not BookUI.separate_menus

func _on_volume_changed(value: float) -> void:
	AudioManager.set_master_volume(value / 100.0)

## Dev-only: flips GameState.dev_mode, which shows/hides BookUI's Dev tab
## (warp + cutscene menu, page_dev.gd) immediately via refresh_dev_tab().
func _on_dev_mode_toggled(enabled: bool) -> void:
	GameState.set_dev_mode(enabled)
	BookUI.refresh_dev_tab()
	GameState.set_flag("story_done_papa_jobert_scene1")
	GameState.set_flag("seen_chapter1_scene1")
	GameState.set_flag("story_done_lola_jonabel_scene1")

## First row of Settings, so the how-to-play help is easy to find mid-game.
func _build_instructions_button() -> void:
	var btn := Button.new()
	btn.text = "Help"
	instructions_btn = btn
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

var _movement_row: HBoxContainer = null

## "Movement controls": joystick or D-pad (Accessibility, shown by the HUD).
## Placed right under the UI scale row.
func _build_movement_row() -> void:
	var rows: Node = ui_scale_row.get_parent()
	var label := Label.new()
	label.text = "Movement controls"
	label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
	label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_M)
	_movement_row = HBoxContainer.new()
	_movement_row.add_theme_constant_override("separation", ui_scale_row.get_theme_constant("separation"))
	var group := ButtonGroup.new()
	for kind: String in Accessibility.MOVEMENT_OPTIONS:
		var btn := Button.new()
		btn.text = Accessibility.MOVEMENT_OPTIONS[kind]
		btn.toggle_mode = true
		btn.button_group = group
		btn.set_meta("kind", kind)
		btn.custom_minimum_size = Vector2(72, 24)
		UIThemeApplier.apply_button_theme(btn, "primary")
		btn.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
		btn.button_pressed = kind == Accessibility.movement_controls
		btn.pressed.connect(func():
			AudioManager.play_sfx("menu_click")
			Accessibility.set_movement_controls(kind))
		_movement_row.add_child(btn)
	var at := ui_scale_row.get_index() + 1
	rows.add_child(label)
	rows.move_child(label, at)
	rows.add_child(_movement_row)
	rows.move_child(_movement_row, at + 1)

## A bus's volume as the sliders' 0-100.
func _bus_percent(bus_name: String) -> float:
	return AudioManager.get_volume(bus_name) * 100.0
