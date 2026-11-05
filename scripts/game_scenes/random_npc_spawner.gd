# random_npc_spawner.gd -- ambient crowd for a map. Add to a level and point
# markers_path at a node holding Marker2Ds.
#   - Spawns up to max_npcs at a marker the camera can't currently see.
#   - Each NPC (npc_wanderer.gd) picks a random marker, walks there around walls
#     and furniture, pauses, and picks another.
# NPCs are children of this node, so they go away with the level.
extends Node2D

const ActorPath := preload("res://scripts/util/actor_path.gd")

const TILE: int = 16
## Route grid extends this far past the markers, for walking around obstacles.
const GRID_MARGIN_TILES: int = 16
## Collision checks per physics frame while building the grid.
const CELLS_PER_FRAME: int = 1500
## Extra world px around the view that counts as visible (a sprite is 32 px wide).
const VIEW_MARGIN: float = 32.0

@export var markers_path: NodePath = ^"../SceneMarkers/RandomNPC"
@export var npc_scenes: Array[PackedScene] = []
@export var max_npcs: int = 6
## Seconds between spawn attempts.
@export var spawn_interval: float = 4.0

var _grid := AStarGrid2D.new()
## Marker tiles that are walkable and connected to each other.
var _targets: Array[Vector2i] = []
var _scene_queue: Array[PackedScene] = []
var _spawn_timer: float = 0.0

func _ready() -> void:
	set_physics_process(false)
	await ActorPath.settle(get_tree())
	if not is_inside_tree():
		return
	await _build_grid()
	if not is_inside_tree() or _targets.is_empty() or npc_scenes.is_empty():
		return
	for i in max_npcs:
		_try_spawn()
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	_spawn_timer += delta
	if _spawn_timer >= spawn_interval:
		_spawn_timer = 0.0
		_try_spawn()

# --- route grid ------------------------------------------------------------------
# Same convention as NpcSchedule: a tile's cell is its marker position / 16, since
# NPC origins sit on the tile's bottom-left corner.

func _build_grid() -> void:
	var markers: Array[Vector2i] = []
	var bounds := Rect2i()
	for marker: Node2D in get_node(markers_path).get_children():
		var cell := Vector2i((marker.global_position / TILE).round())
		bounds = Rect2i(cell, Vector2i.ONE) if markers.is_empty() else bounds.expand(cell)
		markers.append(cell)
	_grid.region = bounds.grow(GRID_MARGIN_TILES)
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_grid.update()
	var checked: int = 0
	for y in range(_grid.region.position.y, _grid.region.end.y):
		for x in range(_grid.region.position.x, _grid.region.end.x):
			_grid.set_point_solid(Vector2i(x, y), ActorPath._is_solid(self, Vector2(x, y) * TILE))
			checked += 1
			if checked % CELLS_PER_FRAME == 0:
				await get_tree().physics_frame
				if not is_inside_tree():
					return
	_targets = _largest_connected(markers)
	if _targets.size() < markers.size():
		push_warning("%s: only %d of %d markers are walkable and connected." % [name, _targets.size(), markers.size()])

## The biggest set of markers that can all reach each other. Blocked markers are dropped.
func _largest_connected(markers: Array[Vector2i]) -> Array[Vector2i]:
	var best: Array[Vector2i] = []
	for from in markers:
		if _grid.is_point_solid(from):
			continue
		var group: Array[Vector2i] = []
		for to in markers:
			if not _grid.is_point_solid(to) and (from == to or not _grid.get_id_path(from, to).is_empty()):
				group.append(to)
		if group.size() > best.size():
			best = group
	return best

# --- spawning --------------------------------------------------------------------

func _try_spawn() -> void:
	if get_child_count() >= max_npcs:
		return
	var view: Rect2 = _world_view().grow(VIEW_MARGIN)
	var options: Array[Vector2i] = _targets.duplicate()
	options.shuffle()
	for cell in options:
		if not view.has_point(Vector2(cell) * TILE) and not is_taken(cell, null):
			_spawn_at(cell)
			return

func _spawn_at(cell: Vector2i) -> void:
	if _scene_queue.is_empty():
		_scene_queue = npc_scenes.duplicate()
		_scene_queue.shuffle()
	var npc: Node2D = _scene_queue.pop_back().instantiate()
	npc.setup(self, cell)
	add_child(npc)
	npc.global_position = Vector2(cell) * TILE

## The part of the map on screen right now, in world coordinates.
func _world_view() -> Rect2:
	var viewport := get_viewport()
	return viewport.get_canvas_transform().affine_inverse() * viewport.get_visible_rect()

# --- called by npc_wanderer.gd ----------------------------------------------------

## Tiles from the NPC's position to a random other marker, around anyone standing
## in the way right now. Empty if no route exists at the moment.
func plan_route(npc: Node2D) -> Array[Vector2i]:
	var here: Vector2i = npc.next_cell
	var options: Array[Vector2i] = _targets.duplicate()
	options.erase(here)
	if options.is_empty():
		return []
	var goal: Vector2i = options.pick_random()
	var blocked: Array[Vector2i] = _block_others(npc)
	var path: Array[Vector2i] = _grid.get_id_path(here, goal)
	for cell in blocked:
		_grid.set_point_solid(cell, false)
	if not path.is_empty():
		path.remove_at(0)  # the tile it's already on
	return path

## True if the player or another NPC is on, or stepping onto, this tile.
func is_taken(cell: Vector2i, me: Node2D) -> bool:
	var pos := Vector2(cell) * TILE
	for body in _others(me):
		if absf(body.global_position.x - pos.x) < TILE and absf(body.global_position.y - pos.y) < TILE:
			return true
		if body.get_parent() == self and body.is_stepping and body.next_cell == cell:
			return true
	return false

func _others(me: Node2D) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for body in get_tree().get_nodes_in_group("npc") + get_tree().get_nodes_in_group("player"):
		if body != me and body is Node2D:
			result.append(body)
	return result

## Blocks the tiles others stand on for one route search, and returns those. Marker
## tiles stay open so a goal is never unreachable: the walker waits at the person
## standing there, then re-plans.
func _block_others(me: Node2D) -> Array[Vector2i]:
	var changed: Array[Vector2i] = []
	for body in _others(me):
		var cell := Vector2i((body.global_position / TILE).round())
		if _grid.region.has_point(cell) and not _grid.is_point_solid(cell) and not _targets.has(cell):
			_grid.set_point_solid(cell)
			changed.append(cell)
	return changed
