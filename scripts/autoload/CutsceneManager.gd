# CutsceneManager.gd — orchestrates scripted multi-actor sequences (interactive cutscenes).
# Sequence = ordered action list loaded from JSON. Action types auto-discovered from

extends Node

signal cutscene_started(cutscene_id: String)
signal cutscene_finished(cutscene_id: String)

# Explicit list, not runtime directory scan -- DirAccess enumeration of res://
# is unreliable in exported Android builds (confirmed: silently returns zero
# files on device, empty _actions dict, every action type fails). Add new
# action types here -- one line, no folder-scan dependency.
const ACTION_SCRIPTS := [
	"res://scripts/cutscene_actions/dialogue_action.gd",
	"res://scripts/cutscene_actions/move_npc_action.gd",
	"res://scripts/cutscene_actions/set_flag_action.gd",
	"res://scripts/cutscene_actions/set_visible_action.gd",
	"res://scripts/cutscene_actions/wait_action.gd",
	"res://scripts/cutscene_actions/fade_action.gd",
	"res://scripts/cutscene_actions/camera_action.gd",
]

var _actions: Dictionary = {}
var _actors: Dictionary = {}
var _playing: bool = false

func _ready() -> void:
	_register_actions()

func _register_actions() -> void:
	for path in ACTION_SCRIPTS:
		var inst = load(path).new()
		_actions[inst.action_type()] = inst

# --- actor registry: same pattern as DialogueUI.register_box -----------------
func register_actor(actor_id: String, node: Node) -> void:
	_actors[actor_id] = node

func unregister_actor(actor_id: String) -> void:
	_actors.erase(actor_id)

func get_actor(actor_id: String) -> Node:
	if not _actors.has(actor_id):
		push_error("CutsceneManager: unknown actor_id '%s'" % actor_id)
	return _actors.get(actor_id, null)

# --- playback ------------------------------------------------------------------
func play(cutscene_id: String) -> void:
	if _playing:
		push_warning("CutsceneManager: already playing, ignoring '%s'" % cutscene_id)
		return
	var path := "res://data/cutscenes/%s.json" % cutscene_id
	if not FileAccess.file_exists(path):
		push_error("CutsceneManager: missing %s" % path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_error("CutsceneManager: bad JSON in %s (%s)" % [path, json.get_error_message()])
		return

	_playing = true
	cutscene_started.emit(cutscene_id)
	await _run_sequence(json.get_data())
	_playing = false
	cutscene_finished.emit(cutscene_id)

func _run_sequence(steps: Array) -> void:
	for step in steps:
		await _run_step(step)

func _run_step(step: Dictionary) -> Variant:
	var type: String = step.get("type", "")
	if type == "parallel":
		await _run_parallel(step.get("actions", []))
		return null
	if not _actions.has(type):
		push_error("CutsceneManager: unknown action type '%s'" % type)
		return null
	await _actions[type].execute(step, self)
	return null

func _run_parallel(branches: Array) -> void:
	# calling an async func without awaiting starts it running to its first `await`;
	# collecting the returned states and awaiting them after starts all branches concurrently
	var tasks: Array = []
	for branch in branches:
		tasks.append(Callable(self, "_run_step").call(branch))
	for t in tasks:
		await t

func is_playing() -> bool:
	return _playing

## Call when the scene tree is being torn down mid-cutscene (e.g. quit to
## menu). Without this, an interrupted cutscene's coroutine is left awaiting
## a signal that can never fire (its DialogueBox died with the old scene),
## and _playing stays stuck true forever — silently blocking every future
## play() call via the guard above.
func abort() -> void:
	if not _playing:
		return
	_playing = false
	var cam: Camera2D = get_actor("camera")
	var player: Node2D = get_actor("player")
	if cam and player:
		cam.global_position = player.global_position
		cam.top_level = false
		cam.position = Vector2.ZERO
	_cam_follow_target = null
	for child in get_children():
		child.queue_free()

## -- Camera Functions --
var _cam_follow_target: Node2D = null

func _process(_delta: float) -> void:
	if _cam_follow_target == null:
		return
	if not is_instance_valid(_cam_follow_target):
		_cam_follow_target = null
		return
	var cam: Camera2D = get_actor("camera")
	if cam == null or not is_instance_valid(cam):
		_cam_follow_target = null
		return
	cam.global_position = _cam_follow_target.global_position

func camera_follow(target: Node2D) -> void:
	var cam: Camera2D = get_actor("camera")
	if cam == null:
		return
	cam.top_level = true
	_cam_follow_target = target

func camera_release() -> void:
	var cam: Camera2D = get_actor("camera")
	if cam == null:
		return
	_cam_follow_target = get_actor("player")
