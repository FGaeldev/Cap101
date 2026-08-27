extends Control

@onready var master_volume_label: Label = $VBoxContainer/MasterVolumeLabel
@onready var volume_slider: HSlider = $VBoxContainer/MasterVolumeSlider
@onready var music_label: Label = $VBoxContainer/MusicLabel
@onready var music_toggle: CheckButton = $VBoxContainer/MusicToggle
@onready var sfx_label: Label = $VBoxContainer/SFXLabel
@onready var sfx_toggle: CheckButton = $VBoxContainer/SFXToggle
@onready var dev_mode_label: Label = $VBoxContainer/DevModeLabel
@onready var dev_mode_toggle: CheckButton = $VBoxContainer/DevModeToggle

func _ready() -> void:
	for lbl in [master_volume_label, music_label, sfx_label, dev_mode_label]:
		lbl.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
		lbl.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_M)

	volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(0)) * 100
	volume_slider.value_changed.connect(_on_volume_changed)
	music_toggle.toggled.connect(_on_music_toggled)
	sfx_toggle.toggled.connect(_on_sfx_toggled)
	dev_mode_toggle.toggled.connect(_on_dev_mode_toggled)

## BookUI pages are instantiated once and toggled via .visible on every
## subsequent open (TDD §8 page pattern) — _ready() never runs again after
## the first open. dev_mode lives on GameState (session-only), not on this
## page — re-sync the checkbox to it every time Settings opens so it can
## never drift stale from whatever Journal's dev page is actually reading.
##
## "Exit to main menu" moved out of this page entirely -- now BookUI's
## TabExit tab-bar button (see BookUI.gd::_on_exit_pressed()). No
## main-menu-context guard needed here anymore; that guard now lives in
## BookUI.open() instead, gating the tab button itself.
func refresh() -> void:
	dev_mode_toggle.set_pressed_no_signal(GameState.dev_mode)

func _on_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(value / 100.0))

func _on_music_toggled(muted: bool) -> void:
	AudioManager.set_music_volume(0.0 if muted else 1.0)

func _on_sfx_toggled(muted: bool) -> void:
	AudioManager.set_sfx_volume(0.0 if muted else 1.0)

## Dev-only: flips GameState.dev_mode, which Journal's page_journal.gd reads
## on its own refresh() to decide whether to open on the hidden warp page.
func _on_dev_mode_toggled(enabled: bool) -> void:
	GameState.dev_mode = enabled
	GameState.set_flag("story_done_papa_jobert_scene1")
	GameState.set_flag("seen_chapter1_scene1")
	GameState.set_flag("story_done_lola_jonabel_scene1")
