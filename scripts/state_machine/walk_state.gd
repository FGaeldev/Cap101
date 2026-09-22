# walk_state.gd
# Grid-locked walk: one tile per tween. While input held, chains the next
# step on finish. No input or blocked tile -> Idle. Never rests mid-tile.
extends State

var _stepping: bool = false
var _tween: Tween

func enter(_prev_state: String = "") -> void:
	_stepping = false
	_try_step(actor.get_input_dir())

func exit() -> void:
	# Interrupted mid-step (dialogue, BookUI, cutscene): kill tween and
	# snap to nearest tile so the player never stays off-grid.
	if _tween:
		_tween.kill()
	if _stepping:
		_snap_to_grid()
	_stepping = false

## Start one tile step in `dir`, or fall back to Idle.
func _try_step(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		state_machine.transition_to("Idle")
		return

	var prev_dir: String = actor.direction
	actor.update_facing(dir)
	var motion: Vector2 = dir * actor.tile_size

	# Blocked only if the collider opposes motion. Grazing contact with a
	# surface we are sliding along (normal perpendicular to dir) is ignored.
	var hit := KinematicCollision2D.new()
	if actor.test_move(actor.global_transform, motion, hit) \
			and hit.get_normal().dot(dir) < -0.5:
		actor.sprite.play("idle_" + actor.direction)
		state_machine.transition_to("Idle")
		return

	# Swap clip only if needed so walk cycle doesn't restart each tile.
	if actor.sprite.animation != "walk_" + actor.direction or actor.direction != prev_dir:
		actor.sprite.play("walk_" + actor.direction)

	_stepping = true
	_tween = create_tween()
	_tween.tween_property(actor, "global_position",
			actor.global_position + motion, actor.step_time)
	_tween.finished.connect(_on_step_finished)

func _on_step_finished() -> void:
	_stepping = false
	# Fires once per completed grid step. Replaces the old free-form-movement
	# notify (removed when movement became tile-locked) — ch1_basics tutorial
	# step 1 ("Use the joystick to move") was otherwise unreachable.
	TutorialManager.notify("player_moved")
	_try_step(actor.get_input_dir())

## Round position to nearest tile multiple.
func _snap_to_grid() -> void:
	var t: float = float(actor.tile_size)
	actor.global_position = (actor.global_position / t).round() * t
