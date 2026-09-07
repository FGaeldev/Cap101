# TaskManager.gd — autoload. Environmental/world-task puzzles (GDD §6.10,
# TDD Addendum WorldTask). Distinct from ChallengeManager (mcq/fill_blank,
# answer-select) — this is action-in-world (collect/interact), triggered by
# NPC/object, no answer-select UI. Additive system, does not touch
# ChallengeManager or puzzle_panel.
extends Node

signal task_started(task_id: String)
signal task_step_advanced(task_id: String, step_index: int)
signal task_completed(task_id: String)

# Hardcoded — DirAccess.list_dir_begin() silently returns zero files in
# exported Android PCK builds (TDD §9 item 1). Any new task file must be
# added here by hand, same rule as ChallengeManager.CHALLENGE_FILES /
# CutsceneManager.ACTION_SCRIPTS.
const TASK_FILES := [
	"res://data/tasks/chapter1.json"
]

var task_defs: Dictionary = {} # task_id -> task data (steps, on_complete, etc)

func _ready() -> void:
	_load_tasks()

func _load_tasks() -> void:
	for path in TASK_FILES:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			push_error("TaskManager: failed to open %s" % path)
			continue
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if typeof(parsed) != TYPE_DICTIONARY:
			push_error("TaskManager: %s malformed, expected top-level Dictionary" % path)
			continue
		for task_id in parsed:
			task_defs[task_id] = parsed[task_id]

## Idempotent — no-op if task already active or already completed. Called by
## Comp_WorldTask (giver mode) on interact.
func start_task(task_id: String) -> void:
	if not task_defs.has(task_id):
		push_error("TaskManager: unknown task_id '%s'" % task_id)
		return
	if GameState.active_tasks.has(task_id) or GameState.completed_tasks.has(task_id):
		return
	GameState.active_tasks[task_id] = 0
	GameState.save_game()
	task_started.emit(task_id)

func is_task_active(task_id: String) -> bool:
	return GameState.active_tasks.has(task_id)

func is_task_completed(task_id: String) -> bool:
	return GameState.completed_tasks.get(task_id, false)

## Current step index for an active task, or -1 if not active. Comp_WorldTask
## (target mode) checks this against its own required_step before advancing.
func get_current_step(task_id: String) -> int:
	return GameState.active_tasks.get(task_id, -1)

## HUD-facing helpers — mirrors QuestManager.quests/active_quests shape so
## hud.gd can render task rows the same way it renders quest rows.
func get_task_title(task_id: String) -> String:
	return task_defs.get(task_id, {}).get("title", task_id)

func get_step_count(task_id: String) -> int:
	return task_defs.get(task_id, {}).get("steps", []).size()

func get_active_task_ids() -> Array:
	return GameState.active_tasks.keys()

## Called by Comp_WorldTask (target mode) once its required_step matches
## get_current_step(). Advances to next step, or completes the task if that
## was the last one.
func advance_task_step(task_id: String) -> void:
	if not is_task_active(task_id):
		return
	var idx: int = GameState.active_tasks[task_id]
	var steps: Array = task_defs[task_id].get("steps", [])
	idx += 1
	if idx >= steps.size():
		_complete_task(task_id)
	else:
		GameState.active_tasks[task_id] = idx
		GameState.save_game()
		task_step_advanced.emit(task_id, idx)

func _complete_task(task_id: String) -> void:
	GameState.active_tasks.erase(task_id)
	GameState.completed_tasks[task_id] = true
	var def: Dictionary = task_defs.get(task_id, {})
	var on_complete: Dictionary = def.get("on_complete", {})
	if on_complete.has("reward"):
		# first_try hardcoded false: world tasks have no mastery/attempt-count
		# concept like ChallengeManager's first-try check, so memory_page
		# rewards (first_try-gated in RewardManager.grant_reward) won't fire
		# from a task unless this is revisited as a deliberate design choice.
		RewardManager.grant_reward(on_complete["reward"], false)
	if on_complete.has("flag") and on_complete["flag"] != "":
		GameState.set_flag(on_complete["flag"])
	GameState.save_game()
	task_completed.emit(task_id)
