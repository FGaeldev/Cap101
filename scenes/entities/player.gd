# Player.gd
extends CharacterBody2D

const SPEED = 80.0
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var state_machine: StateMachine = $StateMachine

## Current facing, one of: "down", "up", "side"
var direction: String = "down"
## True when direction == "side" and moving left (mirrors the side anim)
var facing_left: bool = false

func _ready() -> void:
	add_to_group("player")

## Raw input axis, snapped to 4-directional (no diagonals).
## Locked to zero while dialogue is active.
func get_input_dir() -> Vector2:
	if DialogueUI._current_component != null:
		return Vector2.ZERO
	var raw := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)
	if raw == Vector2.ZERO:
		return Vector2.ZERO
	# Keep only dominant axis -> pure up/down/left/right, no diagonal.
	if abs(raw.x) > abs(raw.y):
		return Vector2(sign(raw.x), 0)
	else:
		return Vector2(0, sign(raw.y))

## Resolves a movement vector into direction + flip_h. Called by WalkState.
func update_facing(dir: Vector2) -> void:
	DirectionUtil.resolve(dir)
