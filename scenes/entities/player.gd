# Player.gd
extends CharacterBody2D

const SPEED = 120.0

## Sprite direction frames — assumes 4-row spritesheet (down/left/right/up)
## If you only have a placeholder square, ignore @onready sprite lines for now
@onready var sprite: Sprite2D = $Sprite2D

var _facing: String = "down"

func _ready() -> void:
	add_to_group("player")

func _physics_process(_delta: float) -> void:
	# Lock movement while dialogue active
	if DialogueUI._current_component != null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var dir = Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	).normalized()

	velocity = dir * SPEED

	if dir != Vector2.ZERO:
		_update_facing(dir)

	move_and_slide()

func _update_facing(dir: Vector2) -> void:
	## Flip sprite horizontally for left/right — works with any placeholder
	if dir.x < 0:
		sprite.flip_h = true
	elif dir.x > 0:
		sprite.flip_h = false
