@tool
extends RefCounted
## Loads, queries and writes data/word_bank.json for the Word Bank screen.
##
## Word IDs are permanent: player saves key word_mastery by ID and dialogue
## refers to words through word_ids, so nothing here renumbers existing words.
## Holds no UI and uses no editor-only classes, so it can run in headless tests.

signal changed

enum Status { ALL, UNVERIFIED, PROBLEMS, NO_GLOSS, NO_CATEGORY }

const DEFAULT_PATH := "res://data/word_bank.json"
const DEFAULT_AREA := "chapter1"

var path: String
var words: Array = []
var dirty := false

var _root: Dictionary = {}
var _disk_text := ""
var _loaded := false
var _id_regex := RegEx.create_from_string("^w(\\d+)$")
var _symbol_regex := RegEx.create_from_string("[^\\p{L}\\s/-]")  # same as WordBank.clean_form


func _init(file_path: String = DEFAULT_PATH) -> void:
	path = file_path


func is_loaded() -> bool:
	return _loaded


## Reads the file. Returns "" on success or a message describing the failure.
## After a failure the store refuses to save, so a bad parse can't wipe the file.
func load_from_disk() -> String:
	_loaded = false
	dirty = false
	words = []
	_root = {}
	if not FileAccess.file_exists(path):
		changed.emit()
		return "File not found: %s" % path
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK:
		changed.emit()
		return "Invalid JSON on line %d: %s" % [json.get_error_line(), json.get_error_message()]
	var data = json.get_data()
	if not data is Dictionary or not data.get("words", null) is Array:
		changed.emit()
		return "Expected a root object with a 'words' array."
	for index in range(data["words"].size()):
		if not data["words"][index] is Dictionary:
			changed.emit()
			return "Entry %d in 'words' is not an object. Fix it in the JSON first." % index
	_root = data
	words = data["words"]
	_disk_text = text
	_loaded = true
	changed.emit()
	return ""


## Writes the file. Returns "" on success or a message describing the failure.
func save() -> String:
	if not _loaded:
		return "Nothing to save: the word bank did not load."
	var text := _serialize()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "Could not write %s: %s" % [path, error_string(FileAccess.get_open_error())]
	var wrote := file.store_string(text)
	file.close()
	if not wrote:
		return "Writing %s failed partway. Check the file before closing Godot." % path
	_disk_text = text
	dirty = false
	changed.emit()
	return ""


## True when something other than this store has changed the file since it was
## last read or written.
func disk_changed() -> bool:
	return _loaded and FileAccess.get_file_as_string(path) != _disk_text


## Accepts the current file as the baseline, so the user's edits can overwrite
## an outside change on the next save.
func acknowledge_disk() -> void:
	if _loaded:
		_disk_text = FileAccess.get_file_as_string(path)
		dirty = _serialize() != _disk_text
		changed.emit()


func snapshot() -> Array:
	return words.duplicate(true)


## Replaces all words. Undo and redo go through here.
func restore(state: Array) -> void:
	words = state.duplicate(true)
	dirty = _serialize() != _disk_text
	changed.emit()


func find(id: String) -> Dictionary:
	for word in words:
		if str(word.get("id", "")) == id:
			return word
	return {}


## Copy of the word list with one field changed. Returns [] if nothing would change.
func with_field(id: String, key: String, value: Variant) -> Array:
	var state := snapshot()
	for word in state:
		if str(word.get("id", "")) == id:
			if word.has(key) and word[key] == value:
				return []
			word[key] = value
			return state
	return []


func with_added(word: Dictionary) -> Array:
	var state := snapshot()
	state.append(word.duplicate(true))
	return state


func with_removed(id: String) -> Array:
	var state := snapshot()
	for index in range(state.size()):
		if str(state[index].get("id", "")) == id:
			state.remove_at(index)
			break
	return state


func new_word(akeanon: String = "", area: String = DEFAULT_AREA) -> Dictionary:
	return {
		"id": next_id(),
		"akeanon": akeanon,
		"category": "",
		"area": area,
		"gloss": "",
		"verified": false,
		"source": "",
	}


## One past the highest existing number, so gaps left by deleted words are never
## reused and can't inherit an old word's saved mastery.
func next_id() -> String:
	var highest := 0
	var width := 3
	for word in words:
		var found := _id_regex.search(str(word.get("id", "")))
		if found:
			highest = maxi(highest, found.get_string(1).to_int())
			width = maxi(width, found.get_string(1).length())
	return "w%s" % str(highest + 1).pad_zeros(width)


func categories() -> PackedStringArray:
	return _distinct("category")


func areas() -> PackedStringArray:
	return _distinct("area")


## Every spelling a word answers to: "adto/agto" gives "adto" and "agto".
func forms_of(word: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	var clean := _symbol_regex.sub(str(word.get("akeanon", "")), "", true).strip_edges().to_lower()
	for form in clean.split("/", false):
		var trimmed := form.strip_edges()
		if not trimmed.is_empty():
			result.append(trimmed)
	return result


## Set of every spelling in the bank, as a Dictionary of lowercase form -> true.
func all_forms() -> Dictionary:
	var result := {}
	for word in words:
		for form in forms_of(word):
			result[form] = true
	return result


## Word ID -> list of human-readable problems. Words without problems are absent.
func problems() -> Dictionary:
	var result := {}
	var id_counts := {}
	var spelled := {}
	for word in words:
		var id := str(word.get("id", ""))
		id_counts[id] = id_counts.get(id, 0) + 1
		var spelling := str(word.get("akeanon", "")).strip_edges().to_lower()
		if not spelling.is_empty():
			if not spelled.has(spelling):
				spelled[spelling] = []
			spelled[spelling].append(id)

	for word in words:
		var id := str(word.get("id", ""))
		var akeanon := str(word.get("akeanon", "")).strip_edges()
		var category := str(word.get("category", "")).strip_edges().to_lower()
		var found := PackedStringArray()
		if id.is_empty():
			found.append("No ID, so the game skips this word. Fix it in the JSON.")
		elif id_counts[id] > 1:
			found.append("Duplicate ID, so the game keeps only the first. Fix it in the JSON.")
		if akeanon.is_empty():
			found.append("No Akeanon form, so the game skips this word.")
		if str(word.get("gloss", "")).strip_edges().is_empty():
			found.append("No gloss, so clue-based minigames can't use it.")
		if not category.is_empty() and not category.contains("proper noun") and akeanon != akeanon.to_lower():
			found.append("Capitalized, but the category isn't Proper Noun.")
		var same: Array = spelled.get(akeanon.to_lower(), [])
		if same.size() > 1:
			var others := same.filter(func(other): return other != id)
			if not others.is_empty():
				found.append("Same spelling as %s." % ", ".join(others))
		if not found.is_empty():
			result[id] = found
	return result


## Filtered, sorted copy of the list. Sorting never changes the file's order.
func query(search: String, area: String, status: int, sort_key: String, ascending: bool) -> Array:
	var needle := search.strip_edges().to_lower()
	var problem_map := problems() if status == Status.PROBLEMS else {}
	var rows: Array = []
	for word in words:
		if not area.is_empty() and str(word.get("area", "")) != area:
			continue
		if not _matches_status(word, status, problem_map):
			continue
		if not needle.is_empty() and not _matches_search(word, needle):
			continue
		rows.append(word)
	rows.sort_custom(func(a, b):
		var order := str(a.get(sort_key, "")).naturalnocasecmp_to(str(b.get(sort_key, "")))
		if order == 0:
			return str(a.get("id", "")).naturalnocasecmp_to(str(b.get("id", ""))) < 0
		return order < 0 if ascending else order > 0)
	return rows


func _matches_status(word: Dictionary, status: int, problem_map: Dictionary) -> bool:
	match status:
		Status.UNVERIFIED:
			return not bool(word.get("verified", false))
		Status.PROBLEMS:
			return problem_map.has(str(word.get("id", "")))
		Status.NO_GLOSS:
			return str(word.get("gloss", "")).strip_edges().is_empty()
		Status.NO_CATEGORY:
			return str(word.get("category", "")).strip_edges().is_empty()
	return true


func _matches_search(word: Dictionary, needle: String) -> bool:
	for key in ["id", "akeanon", "gloss", "category", "area", "source"]:
		if str(word.get(key, "")).to_lower().contains(needle):
			return true
	return false


func _distinct(key: String) -> PackedStringArray:
	var seen := {}
	for word in words:
		var value := str(word.get(key, "")).strip_edges()
		if not value.is_empty():
			seen[value] = true
	var result := PackedStringArray(seen.keys())
	result.sort()
	return result


func _serialize() -> String:
	_root["words"] = words
	return JSON.stringify(_root, "  ", false)
