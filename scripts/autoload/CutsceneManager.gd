# CutsceneManager.gd — orchestrates scripted multi-actor sequences (interactive cutscenes).
# Sequence = ordered action list loaded from JSON. Action types auto-discovered from

extends Node

signal cutscene_started(cutscene_id: String)
signal cutscene_finished(cutscene_id: String)
signal _parallel_branch_done

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
	"res://scripts/cutscene_actions/load_scene_action.gd",
	"res://scripts/cutscene_actions/spawn_npc_action.gd",
	"res://scripts/cutscene_actions/despawn_npc_action.gd",
	"res://scripts/cutscene_actions/conga_action.gd",
]

var _actions: Dictionary = {}
var _actors: Dictionary = {}
var _playing: bool = false
## Bumped by every play() and abort(). A coroutine whose captured id no
## longer matches has been aborted: it stops at its next await instead of
## running more steps or clearing _playing for a newer cutscene.
var _run_id: int = 0
## Tweens started by the current run (track_tween). abort() kills them so an
## aborted move can't keep walking a persistent actor (the player) after a
## level swap.
var _tweens: Array[Tween] = []

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

## True if actor_id is registered to a live node. Unlike get_actor(), never
## logs: callers use it to avoid double-spawning cast a cutscene already
## placed. Entries for freed or queued-for-deletion nodes count as absent:
## Game.load_level() queue_frees the old level in the same frame the new
## level's _ready() runs, so its actors are still "valid" at that point.
func has_actor(actor_id: String) -> bool:
	var node: Variant = _actors.get(actor_id)
	if not is_instance_valid(node):
		return false
	# queue_free() only flags the node it was called on, so an NPC inside the
	# outgoing level root is not flagged itself: walk up the ancestors.
	var n: Node = node
	while n != null:
		if n.is_queued_for_deletion():
			return false
		n = n.get_parent()
	return true

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

	_run_id += 1
	var run_id := _run_id
	_tweens.clear()
	_playing = true
	cutscene_started.emit(cutscene_id)
	await _run_sequence(json.get_data(), run_id)
	if run_id != _run_id:
		return  # aborted: abort() already reset state, a newer run may own it
	_playing = false
	_tweens.clear()
	cutscene_finished.emit(cutscene_id)

func _run_sequence(steps: Array, run_id: int) -> void:
	for step in steps:
		if run_id != _run_id:
			return
		await _run_step(step, run_id)

func _run_step(step: Dictionary, run_id: int) -> Variant:
	var type: String = step.get("type", "")
	# "parallel" step be its own multi-step chain (per-actor conga timing).
	if type == "parallel":
		await _run_parallel(step.get("actions", []), run_id)
		return null
	# "sequence": ordered sub-steps run as ONE step. Lets each branch of a
	if type == "sequence":
		await _run_sequence(step.get("actions", []), run_id)
		return null
	if not _actions.has(type):
		push_error("CutsceneManager: unknown action type '%s'" % type)
		return null
	await _actions[type].execute(step, self)
	return null

## Id of the run currently playing. Actions that loop over several awaits
## capture this at the start of execute() and check is_run_current() after
## each await, so an abort stops them mid-action.
func current_run() -> int:
	return _run_id

func is_run_current(run_id: int) -> bool:
	return _playing and run_id == _run_id

## Registers a tween an action started so abort() can kill it. Returns the
## tween for chaining: `var t := mgr.track_tween(actor.create_tween())`.
func track_tween(tween: Tween) -> Tween:
	_tweens.append(tween)
	return tween

func _run_parallel(branches: Array, run_id: int) -> void:
	# GDScript forbids capturing a coroutine's return value without `await`
	# (hard compile error, not just a warning), so branches can't be started
	# and collected as "tasks" the way _run_sequence awaits a single step.
	# Instead: fire each branch as a discarded bare-statement call (allowed --
	# only the return value capture is forbidden) and count completions.
	#
	# `remaining` is a 1-element Array used as a mutable box (Arrays pass by
	# reference in GDScript) so _run_parallel_branch can decrement it directly.
	# This matters because a branch can complete fully synchronously (e.g.
	# move_npc with a missing actor returns with no real suspension) and emit
	# its done-signal before this function ever reaches the `await` below --
	# if completion were only tracked by catching that signal, the emit would
	# be lost and the loop would hang forever. Decrementing directly makes the
	# `while remaining[0] > 0` check correct regardless of timing.
	if branches.is_empty():
		return
	var remaining: Array = [branches.size()]
	for branch in branches:
		_run_parallel_branch(branch, remaining, run_id)
	# run_id check: abort() emits _parallel_branch_done once to wake this loop,
	# since aborted branches may never finish (their tweens were killed).
	while remaining[0] > 0 and run_id == _run_id:
		await _parallel_branch_done

## Fire-and-forget wrapper: runs one branch, decrements the shared counter,
## then signals. Never call this awaited from _run_parallel -- the counter
## check above is what provides "wait for all branches", not this signal alone.
func _run_parallel_branch(branch: Dictionary, remaining: Array, run_id: int) -> void:
	await _run_step(branch, run_id)
	remaining[0] -= 1
	_parallel_branch_done.emit()

func is_playing() -> bool:
	return _playing

## Call when the scene tree is being torn down mid-cutscene (e.g. quit to
## menu). Without this, an interrupted cutscene's coroutine is left awaiting
## a signal that can never fire (its DialogueBox died with the old scene),
## and _playing stays stuck true forever — silently blocking every future
## play() call via the guard above.
## The aborted run's coroutines are left suspended or return at their next
## run-id check; none of them touch _playing or emit cutscene_finished.
func abort() -> void:
	if not _playing:
		return
	_run_id += 1
	_playing = false
	for tween in _tweens:
		if tween.is_valid():
			tween.kill()
	_tweens.clear()
	# A cutscene dialogue line would otherwise stay on screen and keep the
	# player input-locked (DialogueUI._current_component) after the abort.
	if DialogueUI.is_active():
		DialogueUI.hide()
	_parallel_branch_done.emit()
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
