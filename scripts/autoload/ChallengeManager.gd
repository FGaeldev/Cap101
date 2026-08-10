# ChallengeManager.gd — autoload. Discrete pass/fail challenges (TDD §6.5).
# Distinct from QuestManager (cumulative exposure gate) — one challenge_id,
# one pass/fail, retryable, reward-bearing. Chapter 2 node-map lock uses
# this, not QuestManager.
extends Node

signal challenge_passed(challenge_id: String, first_try: bool)
signal challenge_failed(challenge_id: String, attempt_count: int)

# Hardcoded — DirAccess.list_dir_begin() silently returns zero files in
# exported Android PCK builds (TDD §9 item 1). Any new challenge file must
# be added here by hand, same rule as CutsceneManager.ACTION_SCRIPTS.
const CHALLENGE_FILES := [
	"res://data/challenges/chapter2.json"
]

var challenges: Dictionary = {} # challenge_id -> challenge data

func _ready() -> void:
	_load_challenges()

func _load_challenges() -> void:
	for path in CHALLENGE_FILES:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			push_error("ChallengeManager: failed to open %s" % path)
			continue
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if typeof(parsed) != TYPE_DICTIONARY:
			push_error("ChallengeManager: %s malformed, expected top-level Dictionary" % path)
			continue
		for challenge_id in parsed:
			challenges[challenge_id] = parsed[challenge_id]

func is_passed(challenge_id: String) -> bool:
	return GameState.is_challenge_passed(challenge_id)

## answer_idx is ignored for fill_blank until that mode is built (TDD §6.5
## backlog item — puzzle_panel is mcq-only today).
func attempt(challenge_id: String, answer_idx: int) -> Dictionary:
	var data: Dictionary = challenges.get(challenge_id, {})
	if data.is_empty():
		push_error("ChallengeManager: unknown challenge_id '%s'" % challenge_id)
		return {"correct": false, "first_try": false, "hint": ""}

	var attempt_count := GameState.record_challenge_attempt(challenge_id)
	var correct: bool = answer_idx == data.get("correct_index", -1)

	if correct:
		var first_try := attempt_count == 1
		GameState.mark_challenge_passed(challenge_id)
		_grant_reward(data.get("reward", {}), first_try)
		GameState.save_game()
		challenge_passed.emit(challenge_id, first_try)
		return {"correct": true, "first_try": first_try, "hint": ""}

	# Fail-twice rule: on 2nd wrong attempt, open Dictionary before a 3rd retry.
	if attempt_count >= 2:
		BookUI.open("dictionary")

	challenge_failed.emit(challenge_id, attempt_count)
	return {"correct": false, "first_try": false, "hint": data.get("hint_on_wrong", "")}

## Rose Hint Token spend — eliminates one wrong choice. Returns the removed
## choice index, or -1 if no token available or challenge has <=2 choices left.
## Actual "already-removed" tracking lives in puzzle_panel.gd's render state,
## not here — this only authorizes the spend and picks which index to remove.
func remove_wrong_option(challenge_id: String) -> int:
	if not GameState.spend_hint_token():
		return -1
	var data: Dictionary = challenges.get(challenge_id, {})
	var correct_index: int = data.get("correct_index", -1)
	var choices: Array = data.get("choices", [])
	for i in choices.size():
		if i != correct_index:
			return i
	return -1

# Temporary: writes GameState directly. TDD §7 names RewardManager as sole
# writer for these fields, with popup sequencing (stars first, then
# badge/unlock) — replace this function's body with a RewardManager call
# once that autoload exists; keep the GameState mutation methods as-is.
func _grant_reward(reward: Dictionary, first_try: bool) -> void:
	if reward.get("stars", 0) > 0:
		GameState.add_stars(reward["stars"])
	if reward.get("badge", "") != "":
		GameState.add_badge(reward["badge"])
	if reward.get("stamp", "") != "":
		GameState.add_stamp(reward["stamp"])
	if first_try and reward.get("memory_page", "") != "":
		GameState.add_memory_page(reward["memory_page"])
	if reward.get("hint_tokens", 0) > 0:
		GameState.add_hint_tokens(reward["hint_tokens"])
