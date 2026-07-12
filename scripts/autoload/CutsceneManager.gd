# CutsceneManager.gd — orchestrates scripted multi-actor sequences (interactive cutscenes).
# Sequence = ordered action list loaded from JSON. Action types auto-discovered from
# scripts/cutscene_actions/ at startup — adding a new action type never touches this file.
extends Node

signal cutscene_started(cutscene_id: String)
signal cutscene_finished(cutscene_id: String)

var _actions: Dictionary = {}   # type string -> action instance (has .action_type(), .execute())
var _actors: Dictionary = {}    # actor_id -> Node, populated by participants in their own _ready()
var _playing: bool = false

func _ready() -> void:
	_discover_actions()

func _discover_actions() -> void:
	var dir = DirAccess.open("res://scripts/cutscene_actions")
	if dir == null:
		push_error("CutsceneManager: scripts/cutscene_actions folder missing")
		return
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.ends_with(".gd"):
			var inst = load("res://scripts/cutscene_actions/%s" % file).new()
			_actions[inst.action_type()] = inst
		file = dir.get_next()
	dir.list_dir_end()

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

func _run_step(step: Dictionary) -> void:
	var type: String = step.get("type", "")
	if type == "parallel":
		await _run_parallel(step.get("actions", []))
		return
	if not _actions.has(type):
		push_error("CutsceneManager: unknown action type '%s'" % type)
		return
	await _actions[type].execute(step, self)

func _run_parallel(branches: Array) -> void:
	# calling an async func without awaiting starts it running to its first `await`;
	# collecting the returned states and awaiting them after starts all branches concurrently
	var tasks: Array = []
	for branch in branches:
		tasks.append(_run_step(branch))
	for t in tasks:
		await t
