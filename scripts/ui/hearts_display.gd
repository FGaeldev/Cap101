# hearts_display.gd — rapport shown as 10 hearts, half-heart granularity.
# rapport is a float 0-10 in 0.5 steps; each heart covers 1.0 point.
extends HBoxContainer

const HEART_FULL := preload("res://assets/ui/book/heart_full.png")
const HEART_HALF := preload("res://assets/ui/book/heart_half.png")
const HEART_EMPTY := preload("res://assets/ui/book/heart_empty.png")
const HEART_COUNT := 10  # matches GameState.RAPPORT_MAX

var _hearts: Array[TextureRect] = []

func _ready() -> void:
	for i in HEART_COUNT:
		var heart := TextureRect.new()
		heart.texture = HEART_EMPTY
		heart.custom_minimum_size = Vector2(13, 10)
		_hearts.append(heart)
		add_child(heart)

## value expected 0.0-10.0 in 0.5 steps (GameState.RAPPORT_MAX / get_rapport)
func set_value(value: float) -> void:
	for i in _hearts.size():
		var remaining := value - float(i)
		if remaining >= 1.0:
			_hearts[i].texture = HEART_FULL
		elif remaining >= 0.5:
			_hearts[i].texture = HEART_HALF
		else:
			_hearts[i].texture = HEART_EMPTY
