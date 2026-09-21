# Player.gd
extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var state_machine: StateMachine = $StateMachine

## Current facing, one of: "down", "up", "side"
var direction: String = "down"
## True when direction == "side" and moving left (mirrors the side anim)
var facing_left: bool = false

## Grid step size in px. Multiples of 8 only (base 16). Match active tilemap.
@export_range(8, 64, 8) var tile_size: int = 16
## Seconds per tile step. ~0.2 = brisk, 0.25 = GBA feel.
@export var step_time: float = 0.3
## Last facing as raw 4-dir vector. Used by Idle turn-in-place check.
var facing_vec: Vector2 = Vector2.DOWN

func _ready() -> void:
	add_to_group("player")
	CutsceneManager.register_actor("camera", $Camera2D)
	CutsceneManager.register_actor("player", self)
	CutsceneManager.camera_follow(self)

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
	var facing: Dictionary = DirectionUtil.resolve(dir)
	direction = facing["direction"]
	facing_left = facing["facing_left"]
	facing_vec = dir  # Raw vector for turn/step logic.
	sprite.flip_h = facing_left
