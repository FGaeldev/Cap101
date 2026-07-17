# hearts_display.gd — rapport shown as 10 hearts, full/empty per point.
# [CLAUDE NOTE] No heart art exists yet in assets/ui/book/ — using
# star_icon.png as a placeholder (empty = dimmed via modulate, full =
# TEXT_EMPHASIS tint) so this is testable now. Swap HEART_ICON for real
# heart_full.png/heart_empty.png once drawn; if using two separate sprites
# instead of one tinted icon, replace _update() accordingly.
extends HBoxContainer

const HEART_ICON := preload("res://assets/ui/book/heart_full.png")
const HEART_COUNT := 10  # matches GameState.RAPPORT_MAX

var _hearts: Array[TextureRect] = []

func _ready() -> void:
	for i in HEART_COUNT:
		var heart := TextureRect.new()
		heart.texture = HEART_ICON
		heart.custom_minimum_size = Vector2(12, 11)
		_hearts.append(heart)
		add_child(heart)

## value expected 0-10 (GameState.RAPPORT_MAX)
func set_value(value: int) -> void:
	for i in _hearts.size():
		if i < value:
			_hearts[i].modulate = UIThemeApplier.TEXT_EMPHASIS
		else:
			_hearts[i].modulate = UIThemeApplier.TEXT_DISABLED
