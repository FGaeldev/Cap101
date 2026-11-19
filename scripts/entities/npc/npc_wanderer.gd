# npc_wanderer.gd -- ambient crowd NPC, spawned and routed by random_npc_spawner.gd.
# Walks its route a tile at a time and waits when someone stands in the way.
# Talking to one opens the usual NPC menu; "Talk" plays generated idle talk
# (idle_talk.gd), since a passerby has no story lines, and "Ask directions"
# (directions.gd) points the way to places this map's warps lead to. Freezes during dialogue like
# scheduled NPCs, but keeps walking through cutscene walks so the park doesn't stop
# around the player.
# A routine (set by the spawner from data/ambient_routines.json) replaces the
# random walk with fixed waypoints walked in order: "mode" loop / pingpong /
# once (then it leaves, see random_npc_spawner.routine_finished), optional
# "speed", "pause" [min, max] or per-waypoint "pauses", and per-waypoint
# "faces" (up/down/left/right) to turn to on arrival. One waypoint = stands there.
extends CharacterBody2D

const Directions := preload("res://scripts/util/directions.gd")

## Chapter 2 "Help Rose find Nong Pedring": while it is active, every passerby
## can be asked "Are you Nong Pedring?" and answers with one of the lines in
## chapter2.json ask_pedring_passerby (line 0 is the player's question; one of
## the rest is picked at random. They are chained in the file only so the
## static check sees them as reachable).
const FIND_PEDRING_QUEST: String = "q022"
const FIND_PEDRING_SCENE: String = "ask_pedring_passerby"

## Dialogue speaker name, also the idle-talk and rapport key. Every passerby shares
## it, so the crowd counts as one stranger for idle-talk progress.
@export var npc_id: String = "Passerby"

const TILE: float = 16.0
const SPEED_MIN: float = 36.0
const SPEED_MAX: float = 48.0
const PAUSE_MIN: float = 0.5
const PAUSE_MAX: float = 3.0
## Seconds blocked before giving up on this route and planning a new one.
const REROUTE_AFTER: float = 2.0

## Routine from the spawner ({} = random crowd walker) and its index there.
var routine: Dictionary = {}
var routine_index: int = -1
var _waypoint: int = 0
var _waypoint_dir: int = 1
const FACES := {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}

## Tile this NPC stands on or is stepping onto; others keep off it.
var next_cell: Vector2i = Vector2i.ZERO
var is_stepping: bool = false

var _spawner: Node = null
var _route: Array[Vector2i] = []
var _pause: float = 0.0
var _blocked: float = 0.0
var _speed: float = SPEED_MAX
## Whoever last talked to this NPC (the player).
var _talker: Node2D = null

@onready var _anim: CutsceneAnimComponent = $CutsceneAnimComponent
@onready var _interactable: InteractableComponent = $InteractableComponent
@onready var _dialogue: DialogueComponent = $DialogueComponent

func _ready() -> void:
	_dialogue.npc_id = npc_id
	_interactable.interacted.connect(_on_interacted)

func _on_interacted(interactor: Node) -> void:
	_talker = interactor as Node2D
	# Turn to face whoever is talking (the step tween, if any, still finishes).
	if _talker != null:
		_face(_talker.global_position - global_position)
	var extras: Array = []
	if FIND_PEDRING_QUEST in QuestManager.active_quests:
		extras.append({"id": "ask_pedring", "label": "Are you Nong Pedring?"})
	if _talker != null and not _places_here().is_empty():
		extras.append({"id": "directions", "label": "Ask directions"})
	DialogueUI.show_npc_interaction_menu(npc_id, _on_menu_choice, extras)

func _on_menu_choice(choice: String) -> void:
	match choice:
		"talk":
			_dialogue.start_idle_dialogue()
		"directions":
			_dialogue.dialogue_lines = Directions.build_lines(npc_id, _talker, _places_here(), _face)
			_dialogue.start_dialogue()
		"ask_pedring":
			_dialogue.dialogue_lines = _ask_pedring_lines()
			_dialogue.start_dialogue()
		"review":
			DialogueUI.show_review()

## The player's question, then one passerby's "no" (speaker set to this NPC).
func _ask_pedring_lines() -> Array:
	var lines: Array = ChapterLoader.get_scene_lines("chapter2", FIND_PEDRING_SCENE)
	if lines.size() < 2:
		return []
	var ask: Dictionary = (lines[0] as Dictionary).duplicate()
	var answer: Dictionary = (lines.slice(1).pick_random() as Dictionary).duplicate()
	ask["next"] = 1
	answer["speaker"] = npc_id
	answer["next"] = null
	return [ask, answer]

## Places this map's open warps lead to (Directions.places_here), nearest warp each.
func _places_here() -> Array:
	var level: Node = _spawner.owner if _spawner != null and _spawner.owner != null else get_parent()
	return Directions.places_here(level, _talker.global_position if _talker else global_position)

func _face(dir: Vector2) -> void:
	if dir != Vector2.ZERO:
		_anim.set_cutscene_anim_state("idle", dir)

func setup(spawner: Node, cell: Vector2i) -> void:
	_spawner = spawner
	next_cell = cell
	_speed = randf_range(SPEED_MIN, SPEED_MAX)

func _physics_process(delta: float) -> void:
	if is_stepping or _spawner == null:
		return
	if DialogueUI.is_active() or MapManager.is_transitioning:
		_anim.set_cutscene_anim_state("idle")
		return
	if _pause > 0.0:
		_pause -= delta
		return
	if _route.is_empty() and not routine.is_empty():
		_plan_routine()
		return
	if _route.is_empty():
		_route = _spawner.plan_route(self)
		if _route.is_empty():
			_pause = PAUSE_MAX
		return
	if _spawner.is_taken(_route[0], self):
		_anim.set_cutscene_anim_state("idle")
		_blocked += delta
		if _blocked >= REROUTE_AFTER:
			_blocked = 0.0
			_route.clear()
		return
	_blocked = 0.0
	_step(_route.pop_front())

func _step(cell: Vector2i) -> void:
	var from: Vector2i = next_cell
	next_cell = cell
	is_stepping = true
	_anim.set_cutscene_anim_state("walk", Vector2(cell - from))
	var tween := create_tween()
	tween.tween_property(self, "global_position", Vector2(cell) * TILE, TILE / _speed)
	tween.finished.connect(_on_step_finished)

func _on_step_finished() -> void:
	is_stepping = false
	if _route.is_empty():
		_anim.set_cutscene_anim_state("idle")
		if routine.is_empty():
			_pause = randf_range(PAUSE_MIN, PAUSE_MAX)

# --- routines -----------------------------------------------------------------

func _plan_routine() -> void:
	_speed = float(routine.get("speed", _speed))
	var cells: Array = routine["cells"]
	var goal: Vector2i = cells[_waypoint]
	if next_cell == goal:
		_arrive_waypoint(cells.size())
		return
	_route = _spawner.plan_route_to(self, goal)
	if _route.is_empty():
		_pause = 1.0  # someone is in the way; try again shortly

## Face and pause as the routine says, then aim at the next waypoint.
func _arrive_waypoint(count: int) -> void:
	var faces: Array = routine.get("faces", [])
	if _waypoint < faces.size() and FACES.has(str(faces[_waypoint])):
		_face(FACES[str(faces[_waypoint])])
	var pauses: Array = routine.get("pauses", [])
	var span: Array = routine.get("pause", [PAUSE_MIN, PAUSE_MAX])
	_pause = float(pauses[_waypoint]) if _waypoint < pauses.size() else randf_range(float(span[0]), float(span[1]))
	if count <= 1:
		return
	match str(routine.get("mode", "loop")):
		"once":
			if _waypoint == count - 1:
				_spawner.routine_finished(self)
				return
			_waypoint += 1
		"pingpong":
			if _waypoint + _waypoint_dir < 0 or _waypoint + _waypoint_dir >= count:
				_waypoint_dir = -_waypoint_dir
			_waypoint += _waypoint_dir
		_:
			_waypoint = (_waypoint + 1) % count
