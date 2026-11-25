# chapter_goals.gd -- what holds the next chapter back. Since v1.1.9 each
# chapter's goals are a Kalibo goals level (kalibo_goals.gd): Level 1 before
# Chapter 3, Level 2 before Chapter 4. The next chapter's morning brief
# (aklan_living.gd and the NpcSchedule "chN_brief_pending" blocks) waits until
# met() is true. Failing a Review or a game costs nothing and can be retried any
# time, so it stays no-punishment. Kept as its own helper so callers don't change.
extends RefCounted

const KaliboGoals := preload("res://scripts/util/kalibo_goals.gd")

## Finished side quests ("category": "side").
static func errands_done() -> int:
	return KaliboGoals.errands_done()

## True while a chapter's opening is being held back by missed story lessons
## (its goals are up and some lesson isn't retaken). Rose's marker shows only
## then; earlier, a missed lesson just waits in her menu (v1.1.7).
static func waiting_on_lessons() -> bool:
	if GameState.missed_lessons.is_empty():
		return false
	for s: Dictionary in KaliboGoals.SETS:
		if s.has("chapter") and s["quest"] in QuestManager.active_quests:
			return true
	return false

## True for the quests that show Kalibo goals (any level).
static func is_goal_quest(quest_id: String) -> bool:
	return KaliboGoals.is_goal_quest(quest_id)

## True once everything the chapter needs is done (chapters with no set: true).
static func met(chapter_id: String) -> bool:
	var s: Dictionary = KaliboGoals.set_for_chapter(chapter_id)
	return s.is_empty() or KaliboGoals.set_met(s)

static func check() -> void:
	KaliboGoals.check()
