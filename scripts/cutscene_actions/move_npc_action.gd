# move_npc_action.gd — grid-locked cutscene movement for a registered actor.
#
# Why grid-locked: the player is tile-locked (see walk_state.gd). If cutscene
# actors end a move off-grid, the player later collides with them at
# misaligned edges. This action guarantees every actor starts and ends a move
# on a tile boundary, and only travels along one axis at a time (no diagonals).
#
# Movement is tweened, not physics-driven, so intermediate tiles are NOT
# collision-checked. Cutscene authors must pick routes that are clear.
class_name MoveNpcCutsceneAction
extends RefCounted

## Tile edge length in px. Must match Player.tile_size (scripts/entities/player.gd).
const TILE_SIZE: int = 16

func action_type() -> String:
	return "move_npc"

## step schema:
## {
##   "type":  "move_npc",
##   "actor": "father",        # id registered via CutsceneManager.register_actor
##   "to":    [128, 80],       # target px; snapped to nearest tile multiple
##   "speed": 40,              # px/sec (optional, default 40)
##   "order": "xy"             # optional: "xy" (default) = horizontal leg first,
##                             #           "yx" = vertical leg first
## }
## Coordinates are snapped to multiples of TILE_SIZE. Off-grid values in JSON
## still work but emit a warning so the data can be corrected at the source.
func execute(step: Dictionary, mgr: Node) -> void:
	var actor: Node2D = mgr.get_actor(step.get("actor", ""))
	if actor == null:
		return

	var to: Array = step.get("to", [0, 0])
	var raw_target := Vector2(to[0], to[1])
	var target: Vector2 = _snap(raw_target)
	if target != raw_target:
		push_warning("move_npc: '%s' target %s is off-grid, snapped to %s"
				% [step.get("actor", ""), raw_target, target])

	# Start may be off-grid if the actor was placed by hand in the editor.
	# Snap instantly (max half a tile) so every leg begins on a boundary.
	actor.global_position = _snap(actor.global_position)

	var speed: float = max(float(step.get("speed", 40.0)), 1.0)
	var legs: Array[Vector2] = _build_legs(actor.global_position, target,
			String(step.get("order", "xy")))

	var last_dir: Vector2 = Vector2.ZERO
	for leg_end in legs:
		var dir: Vector2 = (leg_end - actor.global_position).normalized()
		last_dir = dir
		_set_anim(actor, "walk", dir)
		var duration: float = actor.global_position.distance_to(leg_end) / speed
		var tween := actor.create_tween()
		tween.tween_property(actor, "global_position", leg_end, duration)
		await tween.finished

	# Idle facing the last direction travelled (ZERO if no movement was needed).
	_set_anim(actor, "idle", last_dir)

## Round a position to the nearest tile multiple. Mirrors WalkState._snap_to_grid().
func _snap(pos: Vector2) -> Vector2:
	var t: float = float(TILE_SIZE)
	return (pos / t).round() * t

## Split start->target into at most two axis-aligned legs. Zero-length legs
## are dropped so no empty tween or anim flip is produced.
func _build_legs(from: Vector2, target: Vector2, order: String) -> Array[Vector2]:
	var corner: Vector2 = Vector2(target.x, from.y) if order != "yx" \
			else Vector2(from.x, target.y)
	var legs: Array[Vector2] = []
	if corner != from:
		legs.append(corner)
	if target != corner:
		legs.append(target)
	return legs

func _set_anim(actor: Node, state_name: String, dir: Vector2 = Vector2.ZERO) -> void:
	var anim = actor.get_node_or_null("CutsceneAnimComponent")
	if anim:
		anim.set_cutscene_anim_state(state_name, dir)
