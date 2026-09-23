extends Node2D

func _ready() -> void:
	var tween := create_tween().set_loops()

	tween.tween_property($PointLight2D, "energy", 1.5, 0.7)
	tween.tween_property($PointLight2D, "energy", 0.5, 0.7)

	
