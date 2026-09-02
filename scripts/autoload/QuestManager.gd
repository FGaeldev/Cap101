# QuestManager.gd — Quest state, gating, completion
extends Node

## Emitted when a quest becomes available and is added to active_quests.
## HUD/journal listen to this to grow their quest lists.
signal quest_started(quest_id: String)
signal quest_completed(quest_id: String)

var quests: Dictionary = {}          # id -> quest data
var active_quests: Array[String] = [] # all currently available, uncompleted quests

func _ready() -> void:
	_load()
	_refresh_active_quests()

func _load() -> void:
	var file = FileAccess.open("res://data/quest_data.json", FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	file.close()
	var raw: Array = json.get_data()["quests"]
	for q in raw:
		quests[q["id"]] = q

## Re-scans all quests, adds any newly-available one to active_quests.
## Call this whenever a gating condition could have changed — quest
## completion (handled internally) and word exposure (GameState.expose_word).
func _refresh_active_quests() -> void:
	for id in quests:
		if id in active_quests:
			continue
		if is_quest_available(id):
			active_quests.append(id)
			quest_started.emit(id)

## Public entry point for external systems (GameState) to trigger a re-check.
func refresh_active_quests() -> void:
	_refresh_active_quests()

func is_quest_available(quest_id: String) -> bool:
	var q = quests.get(quest_id, {})
	if q.is_empty(): return false
	if GameState.get_flag(q["completion_flag"]): return false
	# Check exposure gate
	var total_exposure = 0
	for wid in q.get("target_words", []):
		total_exposure += GameState.get_exposure(wid)
	return total_exposure >= q.get("required_exposures", 0)

## Completes any active quest whose "completion_trigger" field matches
## trigger_name. For quests that resolve via a world/gameplay event rather
## than word exposure or dialogue — e.g. the movement tutorial completes on
## the player's first move, not on any word being seen. Callers (player FSM,
## etc.) stay quest-agnostic — they fire a named trigger, not a quest id.
func complete_quests_with_trigger(trigger_name: String) -> void:
	for qid in active_quests.duplicate(): # duplicate: complete_quest mutates active_quests
		var q = quests.get(qid, {})
		if q.get("completion_trigger", "") == trigger_name:
			complete_quest(qid)

func complete_quest(quest_id: String) -> void:
	var q = quests.get(quest_id, {})
	if q.is_empty(): return
	GameState.set_flag(q["completion_flag"])
	GameState.completed_quests.append(quest_id)
	GameState.save_game()
	active_quests.erase(quest_id)
	quest_completed.emit(quest_id)
	_refresh_active_quests() # pick up any quest newly unlocked by this completion
