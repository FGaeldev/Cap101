extends Node2D
## stub_area.gd

@onready var return_to_map_button: Button = $ReturnToMapButton

func _ready() -> void:
	# Button was unthemed (default engine flat gray) — sheet texture never
	# applied. secondary = lower-emphasis action, per UI Style Guide §4.
	UIThemeApplier.apply_button_theme(return_to_map_button, "secondary")

func _on_return_to_map_pressed() -> void:
	MapManager.open_map()
