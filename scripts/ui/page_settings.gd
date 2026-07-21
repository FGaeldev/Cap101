extends Control

@onready var volume_slider: HSlider = $VBoxContainer/MasterVolumeSlider
@onready var music_toggle: CheckButton = $VBoxContainer/MusicToggle
@onready var quit_btn: Button = $VBoxContainer/QuitBtn

func _ready() -> void:
	volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(0)) * 100
	volume_slider.value_changed.connect(_on_volume_changed)
	quit_btn.pressed.connect(_on_quit_pressed)
	UIThemeApplier.apply_button_theme(quit_btn, "danger")

func _on_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(value / 100.0))

func _on_quit_pressed() -> void:
	CutsceneManager.abort()
	GameState.save_game()
	MapUI.close()
	BookUI.close()
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
