# WordBank.gd — Loads and queries Akeanon word data
extends Node

var words: Dictionary = {}  # id -> word data

func _ready() -> void:
	_load()

func _load() -> void:
	var file = FileAccess.open("res://data/word_bank.json", FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	file.close()
	var raw: Array = json.get_data()["words"]
	for w in raw:
		words[w["id"]] = w

func get_word(id: String) -> Dictionary:
	return words.get(id, {})

func get_words_for_area(area: String) -> Array:
	return words.values().filter(func(w): return w["area"] == area)

## Returns a word_id weighted toward low-exposure words. Does NOT replace
## get_word(id) — this only picks WHICH id to surface, from a candidate pool
## the caller already narrowed (e.g. one NPC's idle_pool word_ids, or one
## challenge's word_ids). Answers PROF_FEEDBACK_RESPONSE.md §1 "static" —
## selection is now a runtime decision keyed off the player's own
## GameState.word_exposures, not fixed author order.
## Used by: idle dialogue picker (GDD §6.9), ChallengeManager distractor/
## word_ids pick once chapter2.json word_ids arrays are filled (Phase B).
func get_weighted_review_word(candidate_ids: Array) -> String:
	if candidate_ids.is_empty():
		return ""
	var weights: Dictionary = {}
	for id in candidate_ids:
		var exposure: int = GameState.get_exposure(id)
		# Lower exposure = higher weight. Floored at 1 so a word is never
		# unreachable even after many exposures (spaced-repetition grounding,
		# GDD §5.2 — a word doesn't vanish from rotation once "learned").
		weights[id] = max(1, 10 - exposure)
	return _weighted_pick(weights)

func _weighted_pick(weights: Dictionary) -> String:
	var total: int = 0
	for w in weights.values():
		total += w
	var roll: int = randi() % total
	var cursor: int = 0
	for id in weights.keys():
		cursor += weights[id]
		if roll < cursor:
			return id
	return weights.keys()[0]  # fallback, should not reach
