# QuestManager.gd — Quest state, gating, completion
extends Node

signal quest_completed(quest_id: String)

var quests: Dictionary = {}   # id -> quest data
var active_quest: String = "" # currently tracked quest

func _ready() -> void:
	_load()
	_set_initial_active()

func _load() -> void:
	var file = FileAccess.open("res://data/quest_data.json", FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	file.close()
	var raw: Array = json.get_data()["quests"]
	for q in raw:
		quests[q["id"]] = q

func _set_initial_active() -> void:
	# First quest not yet completed = active
	for id in quests:
		if not GameState.get_flag(quests[id]["completion_flag"]):
			active_quest = id
			return

func is_quest_available(quest_id: String) -> bool:
	var q = quests.get(quest_id, {})
	if q.is_empty(): return false
	if GameState.get_flag(q["completion_flag"]): return false
	# Check exposure gate
	var total_exposure = 0
	for wid in q.get("target_words", []):
		total_exposure += GameState.get_exposure(wid)
	return total_exposure >= q.get("required_exposures", 0)

func complete_quest(quest_id: String) -> void:
	var q = quests.get(quest_id, {})
	if q.is_empty(): return
	GameState.set_flag(q["completion_flag"])
	GameState.completed_quests.append(quest_id)
	GameState.save_game()
	quest_completed.emit(quest_id)
	_set_initial_active() # advance to next
