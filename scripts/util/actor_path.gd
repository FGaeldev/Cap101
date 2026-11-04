# actor_path.gd -- grid routes for cutscene walks whose start or surroundings
# aren't known in advance. Preload it (no class_name, same as marker_util.gd):
#   const ActorPath := preload("res://scripts/util/actor_path.gd")
extends RefCounted

const TILE_SIZE: int = 16
## How far past the straight-line distance a route may wander.
const SEARCH_MARGIN_TILES: int = 48
const DIRECTIONS: Array[Vector2] = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]

## Shortest straight legs from `from` to `target` around walls, furniture and every
## other visible actor's tile. Others are taken as they stand right now. If the
## target can't be reached, leads to the reachable tile nearest it instead. Empty
## if already there. Needs a few physics frames after a level loads, see settle().
static func around_actors(mgr: Node, actor: Node2D, from: Vector2, target: Vector2) -> Array[Vector2]:
	var taken: Dictionary = {}
	for other_id: String in mgr._actors:
		if not mgr.has_actor(other_id):
			continue
		var other: Node = mgr.get_actor(other_id)
		if other != actor and other is CharacterBody2D and other.is_visible_in_tree():
			taken[(other.global_position / TILE_SIZE).round() * TILE_SIZE] = true
	var search: float = from.distance_to(target) + SEARCH_MARGIN_TILES * TILE_SIZE
	var came_from: Dictionary = {from: from}
	var queue: Array[Vector2] = [from]
	var nearest: Vector2 = from
	while not queue.is_empty():
		var cell: Vector2 = queue.pop_front()
		if cell.distance_squared_to(target) < nearest.distance_squared_to(target):
			nearest = cell
		if cell == target:
			break
		for dir: Vector2 in DIRECTIONS:
			var next: Vector2 = cell + dir * TILE_SIZE
			if came_from.has(next) or taken.has(next) or next.distance_to(from) > search \
					or _is_solid(actor, next):
				continue
			came_from[next] = cell
			queue.append(next)
	var tiles: Array[Vector2] = [nearest]
	while tiles[0] != from:
		tiles.push_front(came_from[tiles[0]])
	# Merge runs in one direction so the walk doesn't stutter at every tile.
	var legs: Array[Vector2] = []
	for i in range(1, tiles.size()):
		if i == tiles.size() - 1 or tiles[i + 1] - tiles[i] != tiles[i] - tiles[i - 1]:
			legs.append(tiles[i])
	return legs

## True if something with a collision shape, other than a character, fills the
## tile whose bottom-left corner is `cell`.
static func _is_solid(actor: Node2D, cell: Vector2) -> bool:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(14, 14)  # same as the actors' collision boxes
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, cell + Vector2(8, -8))
	for hit: Dictionary in actor.get_world_2d().direct_space_state.intersect_shape(query, 16):
		if not hit["collider"] is CharacterBody2D:
			return true
	return false

## Waits until a just-loaded level's tile collisions are in the physics world.
## Route searches made before this see no walls at all.
static func settle(tree: SceneTree) -> void:
	for i in 3:
		await tree.process_frame  # a load hitch can run several physics frames at once
		await tree.physics_frame
