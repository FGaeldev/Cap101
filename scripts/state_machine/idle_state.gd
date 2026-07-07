# idle_state.gd
# Player stands still, plays idle_<direction>. Any input -> Walk.
extends State

func enter(_prev_state: String = "") -> void:
	actor.sprite.play("idle_" + actor.direction)

func physics_update(_delta: float) -> void:
	var dir: Vector2 = actor.get_input_dir()
	if dir != Vector2.ZERO:
		state_machine.transition_to("Walk")
		return
	actor.velocity = Vector2.ZERO
	actor.move_and_slide()
