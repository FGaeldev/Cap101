# move_npc_action.gd — grid-locked cutscene movement for a registered actor.
#
# Supports concise relative movement ("direction" + "tiles") and legacy absolute
# pixel targets ("to"). Relative moves are easier to author and preserve the
# actor's current tile as their origin. Legacy targets remain supported so old
# cutscene JSON does not need an immediate migration.
#
# Movement is tweened, not physics-driven, so intermediate tiles are NOT
# collision-checked. Cutscene authors must choose clear routes.

class_name MoveNpcCutsceneAction
extends RefCounted

## Tile edge length in pixels. Must match the project's grid and Player.tile_size.
const TILE_SIZE: int = 16

## Screen-space direction vectors; Godot's positive Y axis points down.
const DIRECTIONS: Dictionary = {
	"up": Vector2.UP,
	"down": Vector2.DOWN,
	"left": Vector2.LEFT,
	"right": Vector2.RIGHT,
}

func action_type() -> String:
	return "move_npc"

## Supported step schemas:
## Relative (preferred):
##   {"type":"move_npc", "actor":"father", "direction":"right", "tiles":3}
## Optional "from": [x, y] snaps actor to a start tile before movement.
## Absolute (legacy):
##   {"type":"move_npc", "actor":"father", "to":[128,80], "speed":40, "order":"xy"}
## Optional speed is measured in pixels per second. Legacy order controls which
## axis moves first when both coordinates change ("xy" by default, or "yx").
func execute(step: Dictionary, mgr: Node) -> void:
	var actor: Node2D = mgr.get_actor(step.get("actor", ""))
	if actor == null:
		return

	# Optional placement lets persistent actors (e.g. the player) join spawned
	# actors at the same tile without tweening from their previous location.
	if step.has("from"):
		var from: Array = step.get("from", [])
		if from.size() != 2:
			push_error("move_npc: 'from' must be a two-number [x, y] position")
			return
		actor.global_position = _snap(Vector2(float(from[0]), float(from[1])))

	var start: Vector2 = _snap(actor.global_position)
	if actor.global_position != start:
		actor.global_position = start

	var target: Vector2
	if step.has("direction") or step.has("tiles"):
		if not step.has("direction") or not step.has("tiles"):
			push_error("move_npc: relative movement requires both 'direction' and 'tiles'")
			return

		var direction: String = String(step.get("direction", "")).to_lower()
		if not DIRECTIONS.has(direction):
			push_error("move_npc: invalid direction '%s'; use up, down, left, or right" % direction)
			return

		var tiles: int = int(step.get("tiles", -1))
		if tiles < 0:
			push_error("move_npc: 'tiles' must be zero or greater")
			return

		target = start + DIRECTIONS[direction] * TILE_SIZE * tiles
	else:
		var to: Array = step.get("to", [])
		if to.size() != 2:
			push_error("move_npc: provide 'direction' + 'tiles', or legacy 'to' [x, y]")
			return
		var raw_target := Vector2(float(to[0]), float(to[1]))
		target = _snap(raw_target)
		if target != raw_target:
			push_warning("move_npc: '%s' target %s is off-grid, snapped to %s"
					% [step.get("actor", ""), raw_target, target])

	var speed: float = max(float(step.get("speed", 40.0)), 1.0)
	var legs: Array[Vector2] = _build_legs(start, target,
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

	# Leave the actor idle facing its last movement direction.
	_set_anim(actor, "idle", last_dir)

## Round position to the nearest tile multiple.
func _snap(pos: Vector2) -> Vector2:
	var tile: float = float(TILE_SIZE)
	return (pos / tile).round() * tile

## Split start-to-target into up to two axis-aligned legs; omit zero-length legs.
func _build_legs(from: Vector2, target: Vector2, order: String) -> Array[Vector2]:
	var corner: Vector2 = Vector2(target.x, from.y) if order != "yx" \
			else Vector2(from.x, target.y)
	var legs: Array[Vector2] = []
	if corner != from:
		legs.append(corner)
	if target != corner:
		legs.append(target)
	return legs

## Route animation through the actor's optional cutscene animation component.
func _set_anim(actor: Node, state_name: String, dir: Vector2 = Vector2.ZERO) -> void:
	var anim = actor.get_node_or_null("CutsceneAnimComponent")
	if anim:
		anim.set_cutscene_anim_state(state_name, dir)
