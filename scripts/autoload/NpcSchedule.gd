# NpcSchedule.gd -- moves the family to where data/npc_schedule.json says they
# should be for the current time, day and story state. Only runs once Chapter 2
# scene 0 has been seen.
#
# Each NPC's "blocks" are checked top to bottom and the first match wins:
#   from/to  hours, wrapping past midnight when from > to (19 -> 6 is overnight)
#   days     weekdays the block applies to (0 = Sunday), all days when absent
#   when     story condition, see _condition()
#   room     key in "rooms"; "marker" is a Marker2D in that room (MarkerUtil.find)
#   facing   up/down/left/right
#   asleep   true = can't be talked to
#   away     true = out of the house (the "outside" room)
# An NPC can also have a "talk_cutscene", see _apply_talk_cutscene().
#
# What the player sees:
#   - NPCs walk to their new spot (npc_walker.gd), never jump. To change rooms
#     they walk out of a door and walk in through the next one, using "doors":
#     room -> neighbouring room -> the door's marker in that room.
#   - NPCs are only placed instantly when nobody can see it: on entering a room,
#     or while the screen is black (sleeping, warps, the trip to mass).
#   - Walks freeze during cutscenes and dialogue. Schedule changes wait for them
#     to end. Cutscene-spawned NPCs are reused, since they share the actor id.
extends Node

## A scheduled NPC finished walking. Story beats waiting on someone's arrival
## re-check on this.
signal npc_arrived(actor_id: String)

const MarkerUtil := preload("res://scripts/util/marker_util.gd")
const WalkerScript := preload("res://scripts/entities/npc/npc_walker.gd")

const DATA_PATH := "res://data/npc_schedule.json"
const ACTIVE_FLAG := "seen_chapter2_scene0"
const FIRST_SLEEP_FLAG := "chapter2_slept"
const OUTSIDE := "outside"
const TILE: float = 16.0
const FACINGS := {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}
const NEIGHBOURS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
## Route search gives up past this many tiles. Far more than any room has.
const MAX_SEARCH_CELLS: int = 2000
## Physics frames a new level needs before collision checks can be trusted.
const PHYSICS_SETTLE_FRAMES: int = 2

var _rooms: Dictionary = {}
var _doors: Dictionary = {}
var _npcs: Dictionary = {}
var _level: Node = null
var _level_path: String = ""
## Room key of the loaded level, empty outside the house.
var _room: String = ""
## actor id -> room key that actor is logically in.
var _room_of: Dictionary = {}
## actor id -> door tile they're waiting to walk in through, once it's clear.
var _waiting_at_door: Dictionary = {}
## tile -> true if furniture or walls block it. Reset per level.
var _blocked_cache: Dictionary = {}
var _level_loaded_frame: int = 0

func _ready() -> void:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("NpcSchedule: missing %s" % DATA_PATH)
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		push_error("NpcSchedule: bad JSON in %s" % DATA_PATH)
		return
	_rooms = data.get("rooms", {})
	_doors = data.get("doors", {})
	_npcs = data.get("npcs", {})
	DayNightManager.hour_changed.connect(func(_hour: int): sync())
	GameState.flag_changed.connect(func(_flag: String, _value: bool): sync())
	CutsceneManager.cutscene_started.connect(func(_id: String): _cancel_walks())
	CutsceneManager.cutscene_finished.connect(func(_id: String): sync())
	# Deferred: DialogueUI may still report active while emitting this.
	DialogueUI.dialogue_finished.connect(sync, CONNECT_DEFERRED)

## Called by Game.gd after every level swap, with the player already inside it.
## The player wasn't watching, so everyone is placed straight at their spot.
func on_level_loaded(level: Node, path: String) -> void:
	_level = level
	_level_path = path
	_room = str(_rooms.find_key(path)) if _rooms.values().has(path) else ""
	_waiting_at_door.clear()
	_blocked_cache.clear()
	_level_loaded_frame = Engine.get_physics_frames()
	_sync(true)

## Brings every scheduled NPC in line with the schedule. Instant while the
## screen is black, walking otherwise.
func sync() -> void:
	_sync(MapManager.is_transitioning)

func _sync(instant: bool) -> void:
	if not GameState.get_flag(ACTIVE_FLAG) or not is_instance_valid(_level) or _room.is_empty():
		return
	if not instant and is_paused():
		return  # retried on cutscene_finished / dialogue_finished
	for actor_id: String in _npcs:
		var block := get_block(actor_id)
		_apply_talk_cutscene(actor_id)
		var target: String = _target_room(block)
		var previous: String = _room_of.get(actor_id, target)
		_room_of[actor_id] = target
		if instant:
			_waiting_at_door.erase(actor_id)
			if target == _room:
				_place(actor_id, block)
			else:
				_remove(actor_id)
		else:
			_update_walk(actor_id, previous, target)

## Starts whatever walk this NPC now needs in the loaded room, if any.
func _update_walk(actor_id: String, previous: String, target: String) -> void:
	if CutsceneManager.has_actor(actor_id):
		_send_on_way(actor_id)
		return
	if _waiting_at_door.has(actor_id):
		return
	var route := _route(previous, target)
	var index: int = route.find(_room)
	if index == -1:
		return  # moving between rooms the player can't see
	if index == 0:
		# Belongs here but isn't here (schedule just became active).
		if target == _room:
			_place(actor_id, get_block(actor_id))
		return
	var door := MarkerUtil.find(_level, _doors.get(_room, {}).get(route[index - 1], ""))
	if door == null:
		push_error("NpcSchedule: no door from '%s' into '%s'" % [route[index - 1], _room])
		return
	_waiting_at_door[actor_id] = cell_of(door.global_position)

## Walks an NPC already in the room to its spot, or to the door it leaves by.
func _send_on_way(actor_id: String) -> void:
	var npc: Node2D = CutsceneManager.get_actor(actor_id)
	var walker: Node = _walker_of(npc)
	var block := get_block(actor_id)
	var target: String = _room_of.get(actor_id, _room)
	var marker: Node2D
	var face: Vector2 = Vector2.DOWN
	if target == _room:
		marker = MarkerUtil.find(_level, block.get("marker", ""))
		face = FACINGS.get(block.get("facing", "down"), Vector2.DOWN)
	else:
		var route := _route(_room, target)
		if route.size() < 2:
			push_error("NpcSchedule: no route from '%s' to '%s'" % [_room, target])
			return
		marker = MarkerUtil.find(_level, _doors[_room][route[1]])
	if marker == null:
		push_error("NpcSchedule: no marker for '%s' in '%s'" % [actor_id, _level_path])
		return
	_set_awake(npc)
	walker.walk_to(cell_of(marker.global_position), face, target == _room and block.get("in_bed", false))

func _on_walker_arrived(actor_id: String) -> void:
	if not CutsceneManager.has_actor(actor_id):
		return
	if _room_of.get(actor_id, _room) != _room:
		_remove(actor_id)  # reached the door they leave by
	else:
		var block := get_block(actor_id)
		var interactable: Node = CutsceneManager.get_actor(actor_id).get_node_or_null("InteractableComponent")
		if interactable:
			interactable.disabled = block.get("asleep", false)
	npc_arrived.emit(actor_id)

## Lets in NPCs waiting at a door, once the door tile is clear.
func _physics_process(_delta: float) -> void:
	if _waiting_at_door.is_empty() or is_paused() or not is_instance_valid(_level):
		return
	for actor_id: String in _waiting_at_door.keys():
		var door: Vector2i = _waiting_at_door[actor_id]
		if is_occupied(door, null):
			continue
		_waiting_at_door.erase(actor_id)
		_spawn(actor_id, Vector2(door) * TILE)
		_send_on_way(actor_id)

# --- schedule ------------------------------------------------------------------

## First block matching the current time and story state. Empty when none does.
func get_block(actor_id: String) -> Dictionary:
	for block: Dictionary in _npcs.get(actor_id, {}).get("blocks", []):
		if _matches(block):
			return block
	return {}

## True if this NPC is in the loaded room and belongs there right now.
func is_here(actor_id: String) -> bool:
	return is_instance_valid(_level) and CutsceneManager.has_actor(actor_id) \
			and _rooms.get(get_block(actor_id).get("room", ""), "") == _level_path

## Scheduled NPCs in the loaded room. Anyone leaving with the player isn't one,
## since the "on_walk" and "mass_trip" blocks put them away.
func npcs_here() -> Array[String]:
	var here: Array[String] = []
	for actor_id: String in _npcs:
		if is_here(actor_id):
			here.append(actor_id)
	return here

## True once this NPC has finished walking.
func is_settled(actor_id: String) -> bool:
	if _waiting_at_door.has(actor_id):
		return false
	if not CutsceneManager.has_actor(actor_id):
		return true
	var walker: Node = CutsceneManager.get_actor(actor_id).get_node_or_null("NpcWalker")
	return walker == null or not walker.is_walking

## True while Susan and Rose are at the door waiting to invite the player to mass.
func is_mass_pending() -> bool:
	return is_here("Lola Susan") and is_here("Rose") \
			and is_settled("Lola Susan") and is_settled("Rose") \
			and get_block("Lola Susan").get("when", "") == "mass_pending"

## True while walks should hold still: a cutscene, dialogue or fade is running.
func is_paused() -> bool:
	return CutsceneManager.is_playing() or DialogueUI.is_active() or MapManager.is_transitioning

func _matches(block: Dictionary) -> bool:
	if block.has("days"):
		var weekday: int = DayNightManager.get_date()["weekday"]
		var on_day := false
		for day: Variant in block["days"]:
			on_day = on_day or int(day) == weekday
		if not on_day:
			return false
	if block.has("from"):
		var hour: float = DayNightManager.get_hour()
		var from: float = block["from"]
		var to: float = block["to"]
		var in_hours: bool = (hour >= from and hour < to) if from < to else (hour >= from or hour < to)
		if not in_hours:
			return false
	return not block.has("when") or _condition(block["when"])

func _condition(name: String) -> bool:
	match name:
		"first_day":
			return not GameState.get_flag(FIRST_SLEEP_FLAG)
		"mass_pending":
			return GameState.mass_invite_date != GameState.date_unix
		"mass_skipped":
			return GameState.mass_invite_date == GameState.date_unix and not GameState.get_flag("chapter2_mass_went")
		"on_walk":
			return GameState.get_flag("chapter2_with_rose")
		"mass_trip":
			return GameState.get_flag("chapter2_mass_trip")
		"tour_pending":
			return not GameState.get_flag("chapter2_tour_done")
	push_error("NpcSchedule: unknown condition '%s'" % name)
	return false

func _target_room(block: Dictionary) -> String:
	return OUTSIDE if block.get("away", false) else str(block.get("room", OUTSIDE))

## Rooms from `from` to `to` through "doors", both ends included.
func _route(from: String, to: String) -> Array:
	var came_from: Dictionary = {from: ""}
	var queue: Array = [from]
	while not queue.is_empty():
		var room: String = queue.pop_front()
		if room == to:
			var route: Array = [to]
			while route[0] != from:
				route.push_front(came_from[route[0]])
			return route
		for next: String in _doors.get(room, {}):
			if not came_from.has(next):
				came_from[next] = room
				queue.append(next)
	return []

# --- placing -------------------------------------------------------------------

func _place(actor_id: String, block: Dictionary) -> void:
	var marker := MarkerUtil.find(_level, block.get("marker", ""))
	if marker == null:
		push_error("NpcSchedule: marker '%s' not found in '%s'" % [block.get("marker", ""), _level_path])
		return
	var npc: Node2D = CutsceneManager.get_actor(actor_id) if CutsceneManager.has_actor(actor_id) \
			else _spawn(actor_id, _level.to_local(marker.global_position))
	_walker_of(npc).cancel()
	npc.global_position = marker.global_position
	var anim: Node = npc.get_node_or_null("CutsceneAnimComponent")
	if anim:
		anim.set_cutscene_anim_state("idle", FACINGS.get(block.get("facing", "down"), Vector2.DOWN))
	var interactable: Node = npc.get_node_or_null("InteractableComponent")
	if interactable:
		interactable.disabled = block.get("asleep", false)

func _spawn(actor_id: String, at: Vector2) -> Node2D:
	var npc: Node2D = (load(_npcs[actor_id]["scene"]) as PackedScene).instantiate()
	npc.position = at
	_level.add_child(npc)
	CutsceneManager.register_actor(actor_id, npc)
	_apply_talk_cutscene(actor_id)
	return npc

## "talk_cutscene": talking to this NPC plays a cutscene instead of their usual
## menu, from when "after_flag" is set and while "seen_flag" isn't. "ids" picks
## the cutscene by the room they're in. Outside its hours ("first_hours" until
## "first_flag" is set, "later_hours" after that) "not_now" plays instead.
func _apply_talk_cutscene(actor_id: String) -> void:
	var talk: Dictionary = _npcs[actor_id].get("talk_cutscene", {})
	if talk.is_empty() or not CutsceneManager.has_actor(actor_id):
		return
	var npc: Node = CutsceneManager.get_actor(actor_id)
	npc.cutscene_seen_flag = talk["seen_flag"]
	if not GameState.get_flag(talk["after_flag"]):
		npc.cutscene_id = ""
		return
	var hours: Array = talk["later_hours"] if GameState.get_flag(talk["first_flag"]) else talk["first_hours"]
	var hour: float = DayNightManager.get_hour()
	npc.cutscene_id = talk["ids"].get(_room, "") if hour >= hours[0] and hour < hours[1] else talk["not_now"]

func _remove(actor_id: String) -> void:
	if not CutsceneManager.has_actor(actor_id):
		return
	var npc: Node = CutsceneManager.get_actor(actor_id)
	CutsceneManager.unregister_actor(actor_id)
	npc.queue_free()

func _set_awake(npc: Node) -> void:
	var interactable: Node = npc.get_node_or_null("InteractableComponent")
	if interactable:
		interactable.disabled = false

func _walker_of(npc: Node2D) -> Node:
	var walker: Node = npc.get_node_or_null("NpcWalker")
	if walker == null:
		walker = WalkerScript.new()
		walker.name = "NpcWalker"
		npc.add_child(walker)
		walker.arrived.connect(_on_walker_arrived.bind(_actor_id_of(npc)))
	return walker

func _actor_id_of(npc: Node) -> String:
	for actor_id: String in _npcs:
		if CutsceneManager.has_actor(actor_id) and CutsceneManager.get_actor(actor_id) == npc:
			return actor_id
	return ""

func _cancel_walks() -> void:
	for actor_id: String in _npcs:
		if not CutsceneManager.has_actor(actor_id):
			continue
		var walker: Node = CutsceneManager.get_actor(actor_id).get_node_or_null("NpcWalker")
		if walker:
			walker.cancel()

# --- grid ----------------------------------------------------------------------
# A tile's cell is its marker position / 16: NPC origins sit on the tile's
# bottom-left corner.

func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i((pos / TILE).round())

## True if another NPC or the player is on, moving through or claiming this tile.
## `me` is left out of the check; null checks everyone.
func is_occupied(cell: Vector2i, me: Node2D) -> bool:
	var player: Node2D = CutsceneManager.get_actor("player") if CutsceneManager.has_actor("player") else null
	if player != null and player != me and _covers(player.global_position, cell):
		return true
	for actor_id: String in _npcs:
		if not CutsceneManager.has_actor(actor_id):
			continue
		var npc: Node2D = CutsceneManager.get_actor(actor_id)
		if npc == me:
			continue
		if _covers(npc.global_position, cell):
			return true
		var walker: Node = npc.get_node_or_null("NpcWalker")
		if walker != null and walker.is_stepping and walker.next_cell == cell:
			return true
	return false

## True if a body at `pos` touches this tile, including mid-step between tiles.
func _covers(pos: Vector2, cell: Vector2i) -> bool:
	var grid: Vector2 = pos / TILE
	return cell.x >= floori(grid.x) and cell.x <= ceili(grid.x) \
			and cell.y >= floori(grid.y) and cell.y <= ceili(grid.y)

## Tiles to walk from `start` towards `goal`, not counting `start`. If the goal
## can't be reached right now, leads to the reachable tile nearest it instead;
## empty if `start` already is that tile. Never enters a tile with a collision
## shape, except the goal when into_bed is set ("in_bed" blocks). Physics frames only.
func find_path(start: Vector2i, goal: Vector2i, me: Node2D, into_bed: bool = false) -> Array[Vector2i]:
	var came_from: Dictionary = {start: start}
	var queue: Array[Vector2i] = [start]
	var nearest: Vector2i = start
	var nearest_dist: int = _distance(start, goal)
	while not queue.is_empty() and came_from.size() < MAX_SEARCH_CELLS:
		var cell: Vector2i = queue.pop_front()
		var dist: int = _distance(cell, goal)
		if dist < nearest_dist:
			nearest = cell
			nearest_dist = dist
		if cell == goal:
			break
		for step: Vector2i in NEIGHBOURS:
			var next: Vector2i = cell + step
			if came_from.has(next) or is_occupied(next, me):
				continue
			if is_blocked(next) and not (into_bed and next == goal):
				continue
			came_from[next] = cell
			queue.append(next)
	var result: Array[Vector2i] = []
	while nearest != start:
		result.push_front(nearest)
		nearest = came_from[nearest]
	return result

func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

## A clear tile to step aside to, only when another NPC is right next to `here`
## (so a player standing on someone's seat doesn't set them pacing). Else null.
func find_sidestep(here: Vector2i, goal: Vector2i, me: Node2D) -> Variant:
	var npc_adjacent := false
	for step: Vector2i in NEIGHBOURS:
		npc_adjacent = npc_adjacent or _has_other_npc(here + step, me)
	if not npc_adjacent:
		return null
	var options: Array[Vector2i] = NEIGHBOURS.duplicate()
	options.shuffle()
	for step: Vector2i in options:
		var next: Vector2i = here + step
		if next != goal and not is_blocked(next) and not is_occupied(next, me):
			return next
	return null

func _has_other_npc(cell: Vector2i, me: Node2D) -> bool:
	for actor_id: String in _npcs:
		if CutsceneManager.has_actor(actor_id):
			var npc: Node2D = CutsceneManager.get_actor(actor_id)
			if npc != me and _covers(npc.global_position, cell):
				return true
	return false

## True if anything with a collision shape overlaps this tile. Scheduled NPCs and
## the player don't count, they move and are handled by is_occupied().
func is_blocked(cell: Vector2i) -> bool:
	if _blocked_cache.has(cell):
		return _blocked_cache[cell]
	var shape := RectangleShape2D.new()
	shape.size = Vector2(14, 14)  # same as the NPC's own collision box
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, Vector2(cell) * TILE + Vector2(8, -8))
	var blocked := false
	for hit: Dictionary in _level.get_world_2d().direct_space_state.intersect_shape(query, 16):
		if not _is_moving_body(hit["collider"]):
			blocked = true
			break
	# A just-loaded level's tile collisions aren't in the physics world yet, so
	# don't remember answers from its first frames.
	if Engine.get_physics_frames() - _level_loaded_frame > PHYSICS_SETTLE_FRAMES:
		_blocked_cache[cell] = blocked
	return blocked

func _is_moving_body(collider: Object) -> bool:
	if collider == CutsceneManager.get_actor("player"):
		return true
	for actor_id: String in _npcs:
		if CutsceneManager.has_actor(actor_id) and CutsceneManager.get_actor(actor_id) == collider:
			return true
	return false
