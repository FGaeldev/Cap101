# npc_wanderer.gd -- ambient crowd NPC, spawned and routed by random_npc_spawner.gd.
# Walks its route a tile at a time and waits when someone stands in the way.
# Talking to one opens the usual NPC menu; "Talk" plays generated idle talk
# (idle_talk.gd), since a passerby has no story lines, and "Ask directions"
# (directions.gd) points the way to places this map's warps lead to. Freezes during dialogue like
# scheduled NPCs, but keeps walking through cutscene walks so the park doesn't stop
# around the player.
extends CharacterBody2D

const Directions := preload("res://scripts/util/directions.gd")

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
		"review":
			DialogueUI.show_review()

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
		_pause = randf_range(PAUSE_MIN, PAUSE_MAX)
