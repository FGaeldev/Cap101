# Player.gd
extends CharacterBody2D

const SPEED = 120.0
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var state_machine: StateMachine = $StateMachine

## Current facing, one of: "down", "up", "side"
var direction: String = "down"
## True when direction == "side" and moving left (mirrors the side anim)
var facing_left: bool = false

func _ready() -> void:
	add_to_group("player")

## Raw input axis. Locked to zero while dialogue is active.
func get_input_dir() -> Vector2:
	if DialogueUI._current_component != null:
		return Vector2.ZERO
	return Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	).normalized()

## Resolves a movement vector into direction + flip_h. Called by WalkState.
func update_facing(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return
	if abs(dir.x) > abs(dir.y):
		direction = "side"
		facing_left = dir.x < 0
	else:
		direction = "up" if dir.y < 0 else "down"
	sprite.flip_h = (direction == "side" and facing_left)
