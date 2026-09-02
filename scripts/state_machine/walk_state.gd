# walk_state.gd
# Player moves, plays walk_<direction>. No input -> Idle.
extends State

func enter(_prev_state: String = "") -> void:
	actor.sprite.play("walk_" + actor.direction)
	# Fires once per Idle->Walk transition. Quest-agnostic by design (see
	# QuestManager.complete_quests_with_trigger doc) — this state doesn't
	# know or care which quest, if any, is listening for "first_move".
	QuestManager.complete_quests_with_trigger("first_move")

func physics_update(_delta: float) -> void:
	var dir: Vector2 = actor.get_input_dir()
	if dir == Vector2.ZERO:
		state_machine.transition_to("Idle")
		return

	var prev_dir: String = actor.direction
	actor.update_facing(dir)
	actor.velocity = dir * actor.SPEED
	actor.move_and_slide()

	# Direction changed mid-walk (e.g. down -> side) -> swap clip.
	if actor.direction != prev_dir:
		actor.sprite.play("walk_" + actor.direction)
