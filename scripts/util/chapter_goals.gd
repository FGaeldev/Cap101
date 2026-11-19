# chapter_goals.gd -- what the player does between chapters before the next one
# starts. Each goal is a main quest the Quests panel shows once the chapter
# before is complete; the next chapter's morning brief (aklan_living.gd and the
# NpcSchedule "chN_brief_pending" blocks) waits until met() is true.
#
# Goals count effort, not right answers (no-punishment rule): family errands
# (any finished side quest) and Review activities tried (GameState.reviews_done).
# check() runs on every flag change (Game.gd) and after each Review.
extends RefCounted

## chapter id -> what it needs. errands / reviews are totals across the game.
const GOALS: Dictionary = {
	"chapter3": {"after_flag": "chapter2_complete", "errands": 1, "reviews": 3,
			"errand_quest": "q023", "review_quest": "q024"},
	"chapter4": {"after_flag": "chapter3_complete", "errands": 2, "reviews": 6,
			"errand_quest": "q025", "review_quest": "q026"},
}

## Finished side quests ("category": "side"): Susan's list, the merienda, the pasalubong...
static func errands_done() -> int:
	var count: int = 0
	for qid: String in QuestManager.quests:
		var q: Dictionary = QuestManager.quests[qid]
		if q.get("category", "") == "side" and GameState.get_flag(str(q.get("completion_flag", ""))):
			count += 1
	return count

## True for the quests that show a chapter's goals (q023-q026).
static func is_goal_quest(quest_id: String) -> bool:
	for goal: Dictionary in GOALS.values():
		if quest_id == goal["errand_quest"] or quest_id == goal["review_quest"]:
			return true
	return false

## True once everything the chapter needs is done (unknown chapters: true).
static func met(chapter_id: String) -> bool:
	var goal: Dictionary = GOALS.get(chapter_id, {})
	if goal.is_empty():
		return true
	return errands_done() >= int(goal["errands"]) and GameState.reviews_done >= int(goal["reviews"])

## Set while check() runs: completing a quest sets its flag, and flag changes
## call check() again (Game.gd) before the quest counts as completed.
static var _checking: bool = false

## Completes each goal quest whose goal is met, once its chapter is over.
static func check() -> void:
	if _checking:
		return
	_checking = true
	_check_all()
	_checking = false

static func _check_all() -> void:
	for chapter_id: String in GOALS:
		var goal: Dictionary = GOALS[chapter_id]
		if not GameState.get_flag(str(goal["after_flag"])):
			continue
		if errands_done() >= int(goal["errands"]):
			_complete(str(goal["errand_quest"]))
		if GameState.reviews_done >= int(goal["reviews"]):
			_complete(str(goal["review_quest"]))

static func _complete(quest_id: String) -> void:
	if quest_id in QuestManager.active_quests:
		QuestManager.complete_quest(quest_id)
