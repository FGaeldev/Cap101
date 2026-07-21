# page_journal.gd — PageLeft for Journal (bucket_list) tab.
extends Control

const MAP_TEXTURE := preload("res://assets/ui/book/aklan_map.png")

@onready var map_button: TextureButton = $MapButton
@onready var label_philippines: Label = $LabelPhilippines
@onready var label_aklan: Label = $LabelAklan

func _ready() -> void:
	map_button.texture_normal = MAP_TEXTURE
	map_button.ignore_texture_size = false
	map_button.stretch_mode = TextureButton.STRETCH_SCALE
	map_button.pressed.connect(_on_map_pressed)

	label_philippines.text = "Philippines"
	label_aklan.text = "Aklan"
	label_philippines.add_theme_color_override("font_color", UIThemeApplier.TEXT_DISABLED)
	label_aklan.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	label_philippines.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
	label_aklan.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_L)

## Trigger for the aklan_map.png tap target: closes BookUI, opens the
## node-map travel scene.
func _on_map_pressed() -> void:
	AudioManager.play_sfx("menu_click")
	BookUI.close()
	MapManager.open_map()
