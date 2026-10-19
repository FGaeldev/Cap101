# conga_action.gd -- leader + followers walk one shared tile trail, single file.
#
# Unlike several staggered move_npc branches (each actor walks its OWN route,
# so the line only looks right if every start position is hand-tuned), conga
# builds ONE trail from the leader's route and makes every follower step onto
# the exact tile the actor ahead of it just left. Works from any start
# positions, so it survives a save/reload that puts the cast back on their
# spawn markers instead of where the previous cutscene left them.
#
# Two phases:
#   1. Gather -- followers walk (L-shaped, parallel) to queue slots lined up
#      behind the leader. Leader waits, facing its first step.
#   2. Lockstep -- every tick, each actor advances one tile along the combined
#      trail [queue slots..., leader start, leader route...].
#
# Movement is tweened like move_npc: intermediate tiles are NOT collision-
# checked, so authors must pick clear routes (and a clear queue direction).
#
# JSON usage:
#   {
#   	"type": "conga",
#   	"leader": "Rose",
#   	"followers": ["Lola Susan", "Lola Jonabel", "Papa Jobert"],
#   	"waypoints": [[-464, 320]],   # level-space px, snapped to the 16px grid
#   	"order": "yx",                # leg order per waypoint: "xy" (default) or "yx"
#   	"queue_direction": "right",   # optional; default = opposite of first step
#   	"gap": 1,                     # optional; tiles between actors (default 1)
#   	"speed": 40,                  # optional; px/sec (default 40)
#   	"despawn": true,              # optional; free each actor at trail end / once off-screen
#   	"keep": ["player"],           # optional; never despawned (player is ALWAYS kept)
#   	"hold_at": [-432, 320]        # optional; tile where kept actors stop
#   }
#
# The player can join like any follower (actor id "player"). It is never
# freed -- it is the persistent Game.tscn player -- even if "keep" omits it.
#
# Stop rules per actor:
#   - Despawned actors walk to the trail end. They are freed on arrival, or
#     earlier as soon as they are on the leader's route AND outside the camera
#     view (plus margin), so a long exit walk ends once nobody is visible.
#   - Kept actors stop at "hold_at" (or the trail end if unset), each one
#     "gap" tiles behind the kept actor ahead of it, so they never stack.
#   - With "despawn": false every actor is kept: the line halts with its
#     spacing intact when the leader reaches the end.
# Despawned actors are unregistered from CutsceneManager first (same rule as
# despawn_npc_action.gd).
class_name CongaCutsceneAction
extends RefCounted

## Tile edge length in pixels. Must match move_npc_action.gd and Player.tile_size.
const TILE_SIZE: int = 16

## Extra pixels past the viewport edge before an actor counts as off-screen,
## so sprites are fully out of view (not half-clipped) when freed.
const OFFSCREEN_MARGIN: float = 24.0

## Persistent player actor id; never freed by this action.
const PLAYER_ID: String = "player"

## Screen-space direction vectors; Godot's positive Y axis points down.
const DIRECTIONS: Dictionary = {
	"up": Vector2.UP,
	"down": Vector2.DOWN,
	"left": Vector2.LEFT,
	"right": Vector2.RIGHT,
}

func action_type() -> String:
	return "conga"

func execute(step: Dictionary, mgr: Node) -> void:
	var leader_id: String = step.get("leader", "")
	var leader: Node2D = mgr.get_actor(leader_id)
	if leader == null:
		return

	# Missing followers are skipped, not fatal -- a cast member that already
	# despawned should not stall the whole cutscene.
	var actors: Array[Node2D] = [leader]
	var actor_ids: Array[String] = [leader_id]
	for raw_id in step.get("followers", []):
		var id: String = String(raw_id)
		var node: Node2D = mgr.get_actor(id)
		if node == null:
			push_warning("conga: follower '%s' not registered, skipped" % id)
			continue
		actors.append(node)
		actor_ids.append(id)

	var speed: float = maxf(float(step.get("speed", 40.0)), 1.0)
	var gap: int = maxi(int(step.get("gap", 1)), 1)
	var order: String = String(step.get("order", "xy"))
	var despawn: bool = bool(step.get("despawn", false))

	# --- leader route, expanded to one entry per tile -------------------------
	var start: Vector2 = _snap(leader.global_position)
	leader.global_position = start
	var route: Array[Vector2] = [start]
	var cursor: Vector2 = start
	for wp in step.get("waypoints", []):
		if typeof(wp) != TYPE_ARRAY or wp.size() != 2:
			push_error("conga: each waypoint must be a two-number [x, y] position")
			return
		var target: Vector2 = _snap(Vector2(float(wp[0]), float(wp[1])))
		for corner in _build_legs(cursor, target, order):
			_append_tiles(route, corner)
		cursor = target
	if route.size() < 2:
		push_warning("conga: leader '%s' route is empty, nothing to do" % leader_id)
		return

	var first_dir: Vector2 = route[1] - route[0]
	first_dir = first_dir.normalized()
	var queue_dir: Vector2 = -first_dir
	if step.has("queue_direction"):
		var key: String = String(step.get("queue_direction", "")).to_lower()
		if not DIRECTIONS.has(key):
			push_error("conga: invalid queue_direction '%s'; use up, down, left, or right" % key)
			return
		queue_dir = DIRECTIONS[key]

	# --- combined trail: farthest queue slot first, then the leader route ----
	var slot_count: int = (actors.size() - 1) * gap
	var trail: Array[Vector2] = []
	for j in range(slot_count, 0, -1):
		trail.append(start + queue_dir * TILE_SIZE * j)
	trail.append_array(route)

	# Trail index per actor. Leader sits on its own start tile (= slot_count);
	# follower i (1-based) sits i*gap tiles behind it.
	var indices: Array[int] = []
	for a in actors.size():
		indices.append(slot_count - a * gap)

	# Which actors may be freed, and where each one stops (see header rules).
	var keep_ids: Array = step.get("keep", [])
	var last: int = trail.size() - 1
	var hold_index: int = last
	if step.has("hold_at"):
		var hold: Array = step.get("hold_at", [])
		if hold.size() != 2:
			push_error("conga: 'hold_at' must be a two-number [x, y] position")
			return
		var hold_tile: Vector2 = _snap(Vector2(float(hold[0]), float(hold[1])))
		hold_index = trail.find(hold_tile, slot_count)
		if hold_index == -1:
			push_warning("conga: hold_at %s is not on the leader route; kept actors stop at the end" % hold_tile)
			hold_index = last
	var removable: Array[bool] = []
	var stop_at: Array[int] = []
	var kept_ahead: int = 0
	for a in actors.size():
		var can_free: bool = despawn and actor_ids[a] != PLAYER_ID and not keep_ids.has(actor_ids[a])
		removable.append(can_free)
		if can_free:
			stop_at.append(last)
		else:
			stop_at.append(maxi(hold_index - kept_ahead * gap, indices[a]))
			kept_ahead += 1

	# --- phase 1: gather followers into the queue -----------------------------
	_set_anim(leader, "idle", first_dir)
	var gather_tweens: Array[Tween] = []
	for a in range(1, actors.size()):
		var tween: Tween = _walk_to(actors[a], trail[indices[a]], speed, order, first_dir)
		if tween != null:
			gather_tweens.append(tween)
	await _await_all(gather_tweens)

	# --- phase 2: lockstep along the shared trail -----------------------------
	var tick: float = float(TILE_SIZE) / speed
	var alive: Array[bool] = []
	for a in actors.size():
		alive.append(true)

	while true:
		var tweens: Array[Tween] = []
		for a in actors.size():
			if not alive[a] or not is_instance_valid(actors[a]):
				alive[a] = false
				continue
			if indices[a] >= stop_at[a]:
				continue
			indices[a] += 1
			var actor: Node2D = actors[a]
			var next_pos: Vector2 = trail[indices[a]]
			_set_anim(actor, "walk", (next_pos - actor.global_position).normalized())
			var tween: Tween = actor.create_tween()
			tween.tween_property(actor, "global_position", next_pos, tick)
			tweens.append(tween)
		if tweens.is_empty():
			break
		await _await_all(tweens)

		for a in actors.size():
			if not alive[a] or not is_instance_valid(actors[a]):
				continue
			var stopped: bool = indices[a] >= stop_at[a]
			if removable[a] and (stopped or (indices[a] > slot_count and _is_offscreen(actors[a]))):
				_free_actor(mgr, actor_ids[a], actors[a])
				alive[a] = false
			elif stopped:
				_set_anim(actors[a], "idle")

## Tweens actor to target via up to two axis-aligned legs, then idles facing
## face_dir. Returns null when already on target (nothing to await).
func _walk_to(actor: Node2D, target: Vector2, speed: float, order: String, face_dir: Vector2) -> Tween:
	var from: Vector2 = _snap(actor.global_position)
	actor.global_position = from
	var legs: Array[Vector2] = _build_legs(from, target, order)
	if legs.is_empty():
		_set_anim(actor, "idle", face_dir)
		return null
	var tween: Tween = actor.create_tween()
	var prev: Vector2 = from
	for leg_end in legs:
		tween.tween_callback(_set_anim.bind(actor, "walk", (leg_end - prev).normalized()))
		tween.tween_property(actor, "global_position", leg_end, prev.distance_to(leg_end) / speed)
		prev = leg_end
	tween.tween_callback(_set_anim.bind(actor, "idle", face_dir))
	return tween

## Awaits every tween. Checks is_running() first: awaiting `finished` on a tween
## that already completed would never resume.
func _await_all(tweens: Array[Tween]) -> void:
	for tween in tweens:
		if tween.is_valid() and tween.is_running():
			await tween.finished

## True once the actor is fully outside the current camera view.
func _is_offscreen(actor: Node2D) -> bool:
	var viewport: Viewport = actor.get_viewport()
	if viewport == null:
		return false
	var screen_pos: Vector2 = viewport.get_canvas_transform() * actor.global_position
	var view: Rect2 = Rect2(Vector2.ZERO, viewport.get_visible_rect().size).grow(OFFSCREEN_MARGIN)
	return not view.has_point(screen_pos)

## Unregister before freeing so CutsceneManager never holds a dangling ref.
func _free_actor(mgr: Node, actor_id: String, actor: Node2D) -> void:
	mgr.unregister_actor(actor_id)
	actor.queue_free()

## Appends every tile from the trail's last entry up to (and incl.) target.
## Target must share an axis with the last entry (callers pass leg corners).
func _append_tiles(trail: Array[Vector2], target: Vector2) -> void:
	var pos: Vector2 = trail.back()
	var dir: Vector2 = (target - pos).sign()
	while pos != target:
		pos += dir * TILE_SIZE
		trail.append(pos)

## Round position to the nearest tile multiple.
func _snap(pos: Vector2) -> Vector2:
	var tile: float = float(TILE_SIZE)
	return (pos / tile).round() * tile

## Split start-to-target into up to two axis-aligned legs; omit zero-length legs.
## Same rule as move_npc_action.gd so routes author identically.
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
	if not is_instance_valid(actor):
		return
	var anim = actor.get_node_or_null("CutsceneAnimComponent")
	if anim:
		anim.set_cutscene_anim_state(state_name, dir)
