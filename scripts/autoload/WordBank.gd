# WordBank.gd — Loads, validates, and queries Akeanon word data.
extends Node

var words: Dictionary = {}  # Stable word ID -> normalized word record.

func _ready() -> void:
	_load()

## Load word_bank.json defensively. Invalid records are skipped so one bad
## entry cannot prevent the rest of the vocabulary from loading.
func _load() -> void:
	words.clear()
	var path := "res://data/word_bank.json"
	if not FileAccess.file_exists(path):
		push_error("WordBank: missing file %s" % path)
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("WordBank: could not open %s" % path)
		return

	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()
	if error != OK:
		push_error("WordBank: invalid JSON in %s: %s" % [path, json.get_error_message()])
		return

	var payload = json.get_data()
	if not payload is Dictionary or not payload.get("words", null) is Array:
		push_error("WordBank: expected root object with a 'words' array.")
		return

	for index in range(payload["words"].size()):
		var record = payload["words"][index]
		if not record is Dictionary:
			push_warning("WordBank: skipping non-object word at index %d." % index)
			continue

		var word_id := str(record.get("id", "")).strip_edges()
		var akeanon := str(record.get("akeanon", "")).strip_edges()
		if word_id.is_empty() or akeanon.is_empty():
			push_warning("WordBank: skipping word at index %d; id and akeanon are required." % index)
			continue
		if words.has(word_id):
			push_error("WordBank: duplicate word ID '%s'; keeping first record." % word_id)
			continue

		var normalized: Dictionary = record.duplicate(true)
		normalized["id"] = word_id
		normalized["akeanon"] = akeanon
		normalized["category"] = _normalize_category(str(record.get("category", "")))
		normalized["area"] = str(record.get("area", "all")).strip_edges()
		normalized["gloss"] = str(record.get("gloss", "")).strip_edges()
		normalized["verified"] = bool(record.get("verified", false))
		normalized["source"] = str(record.get("source", "")).strip_edges()
		words[word_id] = normalized

	if words.is_empty():
		push_error("WordBank: no valid word records loaded from %s." % path)

## Converts abbreviated and expanded part-of-speech labels to stable filter values.
func _normalize_category(raw_category: String) -> String:
	var category := raw_category.strip_edges().to_lower()
	if category.is_empty():
		return "uncategorized"
	if category.contains("proper noun"):
		return "proper noun"
	if category.contains("noun") or category == "n":
		return "noun"
	if category.contains("verb") or category == "v":
		return "verb"
	if category.contains("adjective") or category == "adj":
		return "adjective"
	if category.contains("pronoun") or category == "pro":
		return "pronoun"
	if category.contains("conjunction") or category == "conj":
		return "conjunction"
	if category.contains("negative") or category == "neg":
		return "negative"
	return category

func get_word(id: String) -> Dictionary:
	return words.get(id, {})

func get_words_for_area(area: String) -> Array:
	return words.values().filter(
		func(w): return w.get("area", "all") == area or w.get("area", "all") == "all"
	)

## Select a valid candidate with higher weight for words seen less often.
func get_weighted_review_word(candidate_ids: Array) -> String:
	var weights: Dictionary = {}
	for candidate in candidate_ids:
		var word_id := str(candidate)
		if word_id.is_empty() or not words.has(word_id) or weights.has(word_id):
			continue
		var exposure: int = GameState.get_exposure(word_id)
		weights[word_id] = maxi(1, 10 - exposure)
	if weights.is_empty():
		return ""
	return _weighted_pick(weights)

func _weighted_pick(weights: Dictionary) -> String:
	var total := 0
	for weight in weights.values():
		total += int(weight)
	if total <= 0:
		return ""
	var roll := randi() % total
	var cursor := 0
	for word_id in weights.keys():
		cursor += int(weights[word_id])
		if roll < cursor:
			return str(word_id)
	return str(weights.keys()[0])
