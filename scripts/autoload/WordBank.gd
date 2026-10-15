# WordBank.gd — Loads, validates, and queries Akeanon word data.
extends Node

var words: Dictionary = {}  # Stable word ID -> normalized word record.
var _form_index: Dictionary = {}  # lowercase akeanon form -> first word ID with that form.

## Minimum size dynamic quizzes / phrase banks are padded up to.
const MIN_POOL_SIZE: int = 6

func _ready() -> void:
	_load()

## Load word_bank.json defensively. Invalid records are skipped so one bad
## entry cannot prevent the rest of the vocabulary from loading.
func _load() -> void:
	words.clear()
	_form_index.clear()
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
		var form_key := akeanon.to_lower()
		if not _form_index.has(form_key):
			_form_index[form_key] = word_id

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

## Reverse lookup: akeanon surface form (case-insensitive) -> word ID, or "".
## Duplicate forms resolve to the first record loaded.
func find_id_by_form(form: String) -> String:
	return _form_index.get(form.strip_edges().to_lower(), "")

## Pads `pool` (word IDs) up to `min_size` with words the player already knows
## (present in GameState.word_exposures), lowest mastery first. Returns a new
## array; the input is untouched. Padding skips words whose gloss duplicates one
## already in the pool (avoids two "correct" options). `require_gloss` also
## skips blank-gloss words -- use for gloss-displaying quizzes. If the player
## knows too few words the result stays under `min_size`.
func top_up_pool(pool: Array, min_size: int = MIN_POOL_SIZE, require_gloss: bool = false) -> Array:
	var result: Array = pool.duplicate()
	if result.size() >= min_size:
		return result

	var taken: Dictionary = {}  # gloss keys already represented
	for id in result:
		var key := _gloss_key(str(id))
		if not key.is_empty():
			taken[key] = true

	var candidates: Array = []
	for id in GameState.word_exposures.keys():
		var word_id := str(id)
		if not words.has(word_id) or result.has(word_id):
			continue
		var key := _gloss_key(word_id)
		if key.is_empty():
			if require_gloss:
				continue
		elif taken.has(key):
			continue
		candidates.append(word_id)

	while result.size() < min_size and not candidates.is_empty():
		var pick := get_weighted_review_word(candidates)
		if pick.is_empty():
			break
		result.append(pick)
		candidates.erase(pick)
		var pick_key := _gloss_key(pick)
		if not pick_key.is_empty():
			candidates = candidates.filter(func(c): return _gloss_key(str(c)) != pick_key)
	return result

## Up to `count` known single-token akeanon forms (mastery-weighted) not in
## `exclude` (case-insensitive). Phrase-builder distractor source.
func pick_known_akeanon(exclude: Array, count: int) -> Array:
	var skip: Dictionary = {}
	for s in exclude:
		skip[str(s).strip_edges().to_lower()] = true

	var candidates: Array = []
	for id in GameState.word_exposures.keys():
		var record: Dictionary = get_word(str(id))
		if record.is_empty():
			continue
		var form: String = record["akeanon"]
		if form.contains(" ") or skip.has(form.to_lower()):
			continue
		candidates.append(str(id))

	var out: Array = []
	while out.size() < count and not candidates.is_empty():
		var pick := get_weighted_review_word(candidates)
		if pick.is_empty():
			break
		candidates.erase(pick)
		var pick_form: String = words[pick]["akeanon"]
		if skip.has(pick_form.to_lower()):
			continue   # same surface form as an earlier pick under another id
		skip[pick_form.to_lower()] = true
		out.append(pick_form)
	return out

func _gloss_key(word_id: String) -> String:
	return str(words.get(word_id, {}).get("gloss", "")).strip_edges().to_lower()

func get_words_for_area(area: String) -> Array:
	return words.values().filter(
		func(w): return w.get("area", "all") == area or w.get("area", "all") == "all"
	)

## Select a valid candidate; weight rises as the player's mastery score falls
## (GameState.word_mastery). Unseen/unpracticed words (mastery 0) weigh most.
func get_weighted_review_word(candidate_ids: Array) -> String:
	var weights: Dictionary = {}
	for candidate in candidate_ids:
		var word_id := str(candidate)
		if word_id.is_empty() or not words.has(word_id) or weights.has(word_id):
			continue
		weights[word_id] = maxi(1, GameState.MASTERY_MAX - GameState.get_mastery(word_id))
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
