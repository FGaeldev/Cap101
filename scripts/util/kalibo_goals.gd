# kalibo_goals.gd -- what to do after Chapter 4 (v1.1.3 playtest: "end of
# chapter 4, nothing to do"). The post-story quest QUEST ("Kalibo goals") lists
# six counters in the HUD; each pays its reward the first time it's reached,
# and the quest completes when all six are, which plays the family's closing
# scene (aklan_living.gd). Totals count from the start of the game.
# Static helper, preload it like chapter_goals.gd. check() runs from Game.gd.
extends RefCounted

const ChapterGoals := preload("res://scripts/util/chapter_goals.gd")

const QUEST: String = "q020"
## In HUD order. target is the count, reward the pesos paid once on reaching it.
const GOALS: Array[Dictionary] = [
	{"id": "stall", "label": "Stall shifts", "target": 3, "reward": 20},
	{"id": "visitors", "label": "Visitors guided", "target": 6, "reward": 20},
	{"id": "puzzles", "label": "Daily puzzles", "target": 5, "reward": 20},
	{"id": "errands", "label": "Errands done", "target": 7, "reward": 30},
	{"id": "words", "label": "Words learned", "target": 220, "reward": 30},
	{"id": "hearts", "label": "Hearts with someone", "target": 10, "reward": 20},
]

static func count(goal_id: String) -> int:
	match goal_id:
		"stall":
			return GameState.stall_shifts
		"visitors":
			return GameState.plaza_visitors_helped
		"puzzles":
			return GameState.puzzles_solved
		"errands":
			return ChapterGoals.errands_done()
		"words":
			return GameState.word_exposures.size()
		"hearts":
			var best: float = 0.0
			for v in GameState.rapport.values():
				best = maxf(best, float(v))
			return floori(best)
	return 0

static func reached_flag(goal_id: String) -> String:
	return "kalibo_goal_%s" % goal_id

## [{text, state}] for the HUD, as hud.gd quest_requirements() returns them.
static func lines() -> Array:
	var out: Array = []
	for goal: Dictionary in GOALS:
		var need: int = int(goal["target"])
		var have: int = mini(count(str(goal["id"])), need)
		out.append({"text": "%s %d/%d" % [goal["label"], have, need], "state": "done" if have >= need else "todo"})
	return out

## A string that changes whenever any count does (the HUD redraws on change).
static func snapshot() -> String:
	if not QUEST in QuestManager.active_quests:
		return ""
	return ",".join(GOALS.map(func(g: Dictionary) -> String: return str(count(str(g["id"])))))

## Pays each newly reached goal and completes the quest once all are reached.
static func check() -> void:
	if not QUEST in QuestManager.active_quests:
		return
	var all_done: bool = true
	for goal: Dictionary in GOALS:
		var flag: String = reached_flag(str(goal["id"]))
		if GameState.get_flag(flag):
			continue
		if count(str(goal["id"])) >= int(goal["target"]):
			GameState.set_flag(flag)
			RewardManager.award_pesos(int(goal["reward"]), "Kalibo goal: %s" % goal["label"])
		else:
			all_done = false
	if all_done:
		QuestManager.complete_quest(QUEST)
