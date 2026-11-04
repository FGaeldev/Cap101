# npc_walker.gd -- walks one scheduled NPC to a tile, one tile at a time. Added
# as a child of the NPC by NpcSchedule.
#
# The route is re-planned before every step, around furniture, other NPCs and
# the player. The next tile is reserved before stepping onto it (NpcSchedule.
# is_occupied), so two NPCs can never share or swap tiles. No route = wait.
extends Node

## Fired on reaching the goal tile. Not fired if the walk is cancelled.
signal arrived

## Pixels per second, same as the cutscenes' walking pace.
const SPEED: float = 48.0
const TILE: float = 16.0
## Seconds stuck next to another NPC before stepping aside, so two NPCs meeting
## head-on in a narrow spot don't wait on each other forever.
const SIDESTEP_AFTER: float = 1.5

var is_walking: bool = false
var goal: Vector2i = Vector2i.ZERO
## Tile this NPC has claimed for its current step.
var next_cell: Vector2i = Vector2i.ZERO
var is_stepping: bool = false

var _face: Vector2 = Vector2.DOWN
var _into_bed: bool = false
var _waited: float = 0.0
var _tween: Tween = null
var _anim: Node = null

func _ready() -> void:
	_anim = get_parent().get_node_or_null("CutsceneAnimComponent")

## Starts walking, or just re-aims if already walking.
## into_bed lets the last step enter the goal tile even though the bed's collision
## fills it (getting under the blanket), the one exception to staying out of solids.
func walk_to(cell: Vector2i, face: Vector2, into_bed: bool = false) -> void:
	goal = cell
	_face = face
	_into_bed = into_bed
	is_walking = true
	_waited = 0.0

## Stops where it stands, finishing any step instantly so it stays on the grid.
func cancel() -> void:
	finish_step()
	is_walking = false

func finish_step() -> void:
	if not is_stepping:
		return
	if _tween:
		_tween.kill()
	is_stepping = false
	get_parent().global_position = Vector2(next_cell) * TILE

func _physics_process(delta: float) -> void:
	if not is_walking or is_stepping:
		return
	if NpcSchedule.is_paused():
		_set_anim("idle", Vector2.ZERO)
		return
	var npc: Node2D = get_parent()
	var here: Vector2i = NpcSchedule.cell_of(npc.global_position)
	if here == goal:
		is_walking = false
		_set_anim("idle", _face)
		arrived.emit()
		return
	var path: Array[Vector2i] = NpcSchedule.find_path(here, goal, npc, _into_bed)
	if not path.is_empty():
		_waited = 0.0
		_step(here, path[0])
		return
	_set_anim("idle", Vector2.ZERO)
	_waited += delta
	if _waited >= SIDESTEP_AFTER:
		_waited = 0.0
		var aside: Variant = NpcSchedule.find_sidestep(here, goal, npc)
		if aside != null:
			_step(here, aside)

func _step(from: Vector2i, to: Vector2i) -> void:
	next_cell = to
	is_stepping = true
	_set_anim("walk", Vector2(to - from))
	_tween = create_tween()
	_tween.tween_property(get_parent(), "global_position", Vector2(to) * TILE, TILE / SPEED)
	_tween.finished.connect(func(): is_stepping = false)

func _set_anim(state: String, dir: Vector2) -> void:
	if _anim:
		_anim.set_cutscene_anim_state(state, dir)
