# kalibo_goals.gd -- Kalibo goals: counters to reach, one set per level, each
# shown as one quest in the HUD with its difficulty (v1.1.9 tester report: "put
# Kalibo Goals in each chapter, with difficulty gradually increasing", "put a
# difficulty indicator", "no purpose of Kalibo Goals once you've finished").
#
#   Level 1 Easy    Chapter 2, from the end of the town tour. Holds Chapter 3 back.
#   Level 2 Medium  after Chapter 3. Holds Chapter 4 back.
#   Level 3 Hard    after Chapter 4 (the v1.1.4 "Kalibo goals"); completing it
#                   plays the family's closing scene (aklan_living.gd).
#   Level 4 Expert, Level 5 Master   after that, bigger targets and pay.
#
# A set's goals pay their reward the first time each is reached, and the set's
# quest completes when every goal is (plus, for a chapter's set, every missed
# story lesson retaken: lessons.gd). Counts are totals from the start of the game.
# Static helper, preload it. check() runs from Game.gd (flags, a 2 s timer).
extends RefCounted

## Level 3's quest. Its old flags ("kalibo_goal_<id>") are kept for saves.
const QUEST: String = "q020"

const SETS: Array[Dictionary] = [
	{"quest": "q024", "level": 1, "difficulty": "Easy", "chapter": "chapter3", "after_flag": "chapter2_tour_done",
		"goals": [
			{"id": "errands", "label": "Errands done", "target": 1, "reward": 5},
			{"id": "reviews", "label": "Reviews passed", "target": 3, "reward": 5},
			{"id": "games", "label": "Daily games won", "target": 1, "reward": 5},
		]},
	{"quest": "q026", "level": 2, "difficulty": "Medium", "chapter": "chapter4", "after_flag": "chapter3_complete",
		"goals": [
			{"id": "errands", "label": "Errands done", "target": 2, "reward": 10},
			{"id": "reviews", "label": "Reviews passed", "target": 6, "reward": 10},
			{"id": "games", "label": "Daily games won", "target": 3, "reward": 10},
		]},
	{"quest": QUEST, "level": 3, "difficulty": "Hard", "after_flag": "chapter4_complete",
		"goals": [
			{"id": "stall", "label": "Stall shifts", "target": 3, "reward": 20},
			{"id": "visitors", "label": "Visitors guided", "target": 6, "reward": 20},
			{"id": "puzzles", "label": "Daily puzzles", "target": 5, "reward": 20},
			{"id": "errands", "label": "Errands done", "target": 7, "reward": 30},
			{"id": "words", "label": "Words learned", "target": 220, "reward": 30},
			{"id": "hearts", "label": "Hearts with someone", "target": 10, "reward": 20},
		]},
	{"quest": "q032", "level": 4, "difficulty": "Expert", "after_flag": "quest_020_done", "bonus": 100,
		"goals": [
			{"id": "stall", "label": "Stall shifts", "target": 6, "reward": 30},
			{"id": "visitors", "label": "Visitors guided", "target": 12, "reward": 30},
			{"id": "puzzles", "label": "Daily puzzles", "target": 10, "reward": 30},
			{"id": "games", "label": "Daily games won", "target": 10, "reward": 30},
			{"id": "reviews", "label": "Reviews passed", "target": 20, "reward": 30},
			{"id": "hearts", "label": "Hearts with someone", "target": 15, "reward": 30},
		]},
	{"quest": "q033", "level": 5, "difficulty": "Master", "after_flag": "quest_032_done", "bonus": 200,
		"goals": [
			{"id": "stall", "label": "Stall shifts", "target": 12, "reward": 50},
			{"id": "visitors", "label": "Visitors guided", "target": 24, "reward": 50},
			{"id": "puzzles", "label": "Daily puzzles", "target": 20, "reward": 50},
			{"id": "games", "label": "Daily games won", "target": 20, "reward": 50},
			{"id": "reviews", "label": "Reviews passed", "target": 40, "reward": 50},
			{"id": "hearts", "label": "Hearts with someone", "target": 20, "reward": 50},
		]},
]
## Levels a set can show on its difficulty line ("Level 2 of 5").
const LEVELS: int = 5

# --- counters ------------------------------------------------------------------

## Finished side quests ("category": "side"): Susan's list, the merienda, the pasalubong...
static func errands_done() -> int:
	var total: int = 0
	for qid: String in QuestManager.quests:
		var q: Dictionary = QuestManager.quests[qid]
		if q.get("category", "") == "side" and GameState.get_flag(str(q.get("completion_flag", ""))):
			total += 1
	return total

static func count(goal_id: String) -> int:
	match goal_id:
		"stall":
			return GameState.stall_shifts
		"visitors":
			return GameState.plaza_visitors_helped
		"puzzles":
			return GameState.puzzles_solved
		"errands":
			return errands_done()
		"reviews":
			return GameState.reviews_passed
		"games":
			# Any once-a-day game won: the daily word games (daily_games.gd), a stall
			# shift, a plaza round or the newspaper puzzle.
			return GameState.activity_wins + GameState.stall_shifts + GameState.puzzles_solved
		"words":
			return GameState.word_exposures.size()
		"hearts":
			var best: float = 0.0
			for v in GameState.rapport.values():
				best = maxf(best, float(v))
			return floori(best)
	return 0

# --- sets ----------------------------------------------------------------------

static func set_for_quest(quest_id: String) -> Dictionary:
	for s: Dictionary in SETS:
		if s["quest"] == quest_id:
			return s
	return {}

static func set_for_chapter(chapter_id: String) -> Dictionary:
	for s: Dictionary in SETS:
		if str(s.get("chapter", "")) == chapter_id:
			return s
	return {}

static func is_goal_quest(quest_id: String) -> bool:
	return not set_for_quest(quest_id).is_empty()

## Flag set once a goal's reward is paid. Level 3 keeps its pre-v1.1.9 names.
static func reached_flag(s: Dictionary, goal_id: String) -> String:
	if int(s["level"]) == 3:
		return "kalibo_goal_%s" % goal_id
	return "kalibo_goal_l%d_%s" % [int(s["level"]), goal_id]

static func goals_met(s: Dictionary) -> bool:
	for goal: Dictionary in s["goals"]:
		if count(str(goal["id"])) < int(goal["target"]):
			return false
	return true

## A chapter's set also waits on every missed story lesson (lessons.gd).
static func set_met(s: Dictionary) -> bool:
	if not goals_met(s):
		return false
	return not s.has("chapter") or GameState.missed_lessons.is_empty()

## "Level 2 of 5 · Medium", the difficulty line over a set's counters.
static func difficulty_text(s: Dictionary) -> String:
	return "Level %d of %d · %s" % [int(s["level"]), LEVELS, s["difficulty"]]

## [{text, state}] for the HUD, as hud.gd quest_requirements() returns them.
static func lines(quest_id: String = QUEST) -> Array:
	var s: Dictionary = set_for_quest(quest_id)
	if s.is_empty():
		return []
	var out: Array = [{"text": difficulty_text(s), "state": "level"}]
	for goal: Dictionary in s["goals"]:
		var need: int = int(goal["target"])
		var have: int = mini(count(str(goal["id"])), need)
		out.append({"text": "%s %d/%d" % [goal["label"], have, need], "state": "done" if have >= need else "todo"})
	if s.has("chapter") and not GameState.missed_lessons.is_empty():
		out.append({"text": "Lessons to retake with Rose: %d" % GameState.missed_lessons.size(), "state": "todo"})
	return out

## A string that changes whenever any shown count does (the HUD redraws on change).
static func snapshot() -> String:
	var parts: Array[String] = []
	for s: Dictionary in SETS:
		if s["quest"] in QuestManager.active_quests:
			for goal: Dictionary in s["goals"]:
				parts.append(str(count(str(goal["id"]))))
			parts.append(str(GameState.missed_lessons.size()))
	return ",".join(parts)

## Set while check() runs: completing a quest sets its flag, and flag changes
## call check() again (Game.gd) before the quest counts as completed.
static var _checking: bool = false

## Pays each newly reached goal of every active set, and completes a set's quest
## once it's met.
static func check() -> void:
	if _checking:
		return
	_checking = true
	for s: Dictionary in SETS:
		if not s["quest"] in QuestManager.active_quests:
			continue
		for goal: Dictionary in s["goals"]:
			var flag: String = reached_flag(s, str(goal["id"]))
			if GameState.get_flag(flag) or count(str(goal["id"])) < int(goal["target"]):
				continue
			GameState.set_flag(flag)
			RewardManager.award_pesos(int(goal["reward"]), "Kalibo goal: %s" % goal["label"])
		if set_met(s):
			if int(s.get("bonus", 0)) > 0:
				RewardManager.award_pesos(int(s["bonus"]), "Kalibo goals level %d" % int(s["level"]))
			QuestManager.complete_quest(str(s["quest"]))
			if int(s["level"]) >= 3:
				var next: String = "Level %d is next." % (int(s["level"]) + 1) if int(s["level"]) < LEVELS else "Every level done!"
				ChapterCard.show_notice("Kalibo goals", "Level %d · %s complete" % [int(s["level"]), s["difficulty"]], next)
	_checking = false
