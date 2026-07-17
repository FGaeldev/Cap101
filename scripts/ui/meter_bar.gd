# meter_bar.gd — generic read-only progress meter (rapport, patience, etc).
# Deliberately decoupled from GameState/npc_id — takes a plain value/max pair
# so it's reusable for anything bounded, not just relationship stats.
extends Control

@onready var bar: TextureProgressBar = $TextureProgressBar

const BAR_FRAME := preload("res://assets/ui/book/bar_frame.png")
const BAR_FILL := preload("res://assets/ui/book/bar_fill.png")

func _ready() -> void:
	bar.texture_under = BAR_FRAME
	bar.texture_progress = BAR_FILL
	bar.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
	bar.min_value = 0
	bar.max_value = 100

## current/max as plain numbers — caller owns what those mean.
## e.g. set_value(GameState.get_patience(npc_id), GameState.PATIENCE_MAX)
func set_value(current: float, max_value: float) -> void:
	bar.max_value = max_value
	bar.value = current
