# QuestManager.gd — Quest state, gating, completion
extends Node

## Emitted when a quest becomes available and is added to active_quests.
## HUD/journal listen to this to grow their quest lists.
signal quest_started(quest_id: String)
signal quest_completed(quest_id: String)
## Emitted when active quest state changes without a gameplay completion event.
## HUD uses this to refresh silently, without showing QuestCompletePopup.
signal quest_list_changed

var quests: Dictionary = {}          # id -> quest data
var active_quests: Array[String] = [] # all currently available, uncompleted quests

func _ready() -> void:
	_load()
	print("QuestManager loaded ids: ", quests.keys())
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
	# Optional prerequisite: quest stays hidden until this flag is set.
	# Lets a quest unlock off story progress (e.g. a cutscene's set_flag)
	# instead of word exposure. Absent/empty = no prerequisite.
	var required_flag: String = q.get("requires_flag", "")
	if not required_flag.is_empty() and not GameState.get_flag(required_flag): return false
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
## Quests with an "area" field only complete while GameState.current_area
## matches — lets the same trigger_name be reused per-scene without needing
## per-node scene guards on the emitting component.
func complete_quests_with_trigger(trigger_name: String) -> void:
	for qid in active_quests.duplicate(): # duplicate: complete_quest mutates active_quests
		var q = quests.get(qid, {})
		if q.get("completion_trigger", "") != trigger_name:
			continue
		if q.has("area") and q["area"] != GameState.current_area:
			continue
		complete_quest(qid)

## Mark quest complete without popup/signal. Use for dev shortcuts that bypass gameplay.
func complete_quest_silently(quest_id: String) -> void:
	var q: Dictionary = quests.get(quest_id, {})
	if q.is_empty() or quest_id in GameState.completed_quests:
		return
	GameState.set_flag(q["completion_flag"])
	GameState.completed_quests.append(quest_id)
	active_quests.erase(quest_id)
	GameState.save_game()
	_refresh_active_quests()
	quest_list_changed.emit()

## Dev-skip helper: un-completes a quest (clears its completion flag) and
## drops it from active_quests, then re-adds it only if its gate is met by the
## current flags. No popup.
func reset_quest_silently(quest_id: String) -> void:
	var q: Dictionary = quests.get(quest_id, {})
	if q.is_empty():
		return
	GameState.set_flag(q["completion_flag"], false)
	GameState.completed_quests.erase(quest_id)
	active_quests.erase(quest_id)
	_refresh_active_quests()
	quest_list_changed.emit()

func complete_quest(quest_id: String) -> void:
	var q = quests.get(quest_id, {})
	if q.is_empty(): return
	# Idempotent: NPC dialogue components call this on EVERY dialogue end
	# (incl. idle chat), so a repeat call must not re-popup/re-save.
	if quest_id in GameState.completed_quests: return
	GameState.set_flag(q["completion_flag"])
	GameState.completed_quests.append(quest_id)
	GameState.save_game()
	active_quests.erase(quest_id)
	quest_completed.emit(quest_id)
	_refresh_active_quests() # pick up any quest newly unlocked by this completion
