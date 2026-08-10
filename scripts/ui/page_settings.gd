extends Control

@onready var volume_slider: HSlider = $VBoxContainer/MasterVolumeSlider
@onready var music_toggle: CheckButton = $VBoxContainer/MusicToggle
@onready var quit_btn: Button = $VBoxContainer/QuitBtn

func _ready() -> void:
	volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(0)) * 100
	volume_slider.value_changed.connect(_on_volume_changed)
	music_toggle.toggled.connect(_on_music_toggled)
	UIThemeApplier.apply_button_theme(quit_btn, "danger")

## BookUI pages are instantiated once and toggled via .visible on every
## subsequent open (TDD §8 page pattern) — _ready() never runs again after
## the first open. The MainMenu-context check below MUST live here, not in
## _ready(), or it only ever evaluates against whichever scene happened to
## be active the first time Settings was opened, then stays stale for the
## rest of the session (e.g. opened once from MainMenu -> quit_btn hidden
## forever, even after starting a game and reopening Settings mid-session).
func refresh() -> void:
	## Settings can be opened from MainMenu itself (no active session).
	## "Exit to main menu" makes no sense there, and its GameState.save_game()
	## call would silently overwrite an existing save with whatever stale or
	## default data currently sits in the GameState singleton's memory.
	var in_main_menu := get_tree().current_scene != null \
		and get_tree().current_scene.scene_file_path == "res://scenes/ui/MainMenu.tscn"
	quit_btn.visible = not in_main_menu
	if not in_main_menu and not quit_btn.pressed.is_connected(_on_quit_pressed):
		quit_btn.pressed.connect(_on_quit_pressed)

func _on_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(value / 100.0))
	
func _on_music_toggled(muted: bool) -> void:
	AudioManager.set_music_volume(0.0 if muted else 1.0)

func _on_quit_pressed() -> void:
	CutsceneManager.abort()
	GameState.save_game()
	BookUI.close()
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
