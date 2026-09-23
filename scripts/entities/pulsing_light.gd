extends PointLight2D

func _ready() -> void:
	var tween := create_tween().set_loops()

	tween.tween_property(self, "energy", 1.5, 0.7)
	tween.tween_property(self, "energy", 0.5, 0.7)
