# idle_state.gd
# Player stands still, plays idle_<direction>.
# Pokemon rule: input toward a NEW direction only turns; walk starts if the
# input is still held after TURN_DELAY. Same direction = walk immediately.
extends State

## Hold time before a turn becomes a step. Taps shorter than this = pure turn.
const TURN_DELAY: float = 0.1

var _turn_timer: float = 0.0

func enter(_prev_state: String = "") -> void:
	_turn_timer = 0.0
	actor.velocity = Vector2.ZERO
	actor.sprite.play("idle_" + actor.direction)

func physics_update(delta: float) -> void:
	var dir: Vector2 = actor.get_input_dir()
	if dir == Vector2.ZERO:
		_turn_timer = 0.0
		return

	# Already facing input direction -> step now.
	if dir == actor.facing_vec:
		state_machine.transition_to("Walk")
		return

	# New direction -> turn in place, arm the delay.
	if _turn_timer <= 0.0:
		actor.update_facing(dir)
		actor.sprite.play("idle_" + actor.direction)
		_turn_timer = TURN_DELAY
		return

	# Delay running; step if input still held in the turned direction.
	_turn_timer -= delta
	if _turn_timer <= 0.0:
		state_machine.transition_to("Walk")
