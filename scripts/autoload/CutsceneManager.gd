# CutsceneManager.gd — orchestrates scripted multi-actor sequences (interactive cutscenes).
# Sequence = ordered action list loaded from JSON. Action types auto-discovered from
# scripts/cutscene_actions/ at startup — adding a new action type never touches this file.
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
