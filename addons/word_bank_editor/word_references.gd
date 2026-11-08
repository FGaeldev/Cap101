@tool
extends RefCounted
## Read-only scan of the game's JSON for places that use words: exact word IDs
## ("w173", usually inside word_ids) and backslash markers in text ("\Aklan").

const DATA_ROOT := "res://data"
const SKIPPED_FILE := "word_bank.json"

var errors: PackedStringArray = []

var _by_id: Dictionary = {}  # word ID -> Array of uses
var _by_form: Dictionary = {}  # lowercase marker -> Array of uses
var _marker_labels: Dictionary = {}  # lowercase marker -> spelling as first written
var _id_regex := RegEx.create_from_string("^w\\d{3,}$")
var _marker_regex := RegEx.create_from_string("\\\\([^\\s\\\\,.;!?()\\[\\]{}\"']+)")


func scan(root: String = DATA_ROOT) -> void:
	errors = PackedStringArray()
	_by_id.clear()
	_by_form.clear()
	_marker_labels.clear()
	_scan_folder(root, root)


## Every place a word is used, once per line, whether found by ID or by marker.
func uses_of(word_id: String, forms: PackedStringArray) -> Array:
	var seen := {}
	var result: Array = []
	var candidates: Array = _by_id.get(word_id, []).duplicate()
	for form in forms:
		candidates.append_array(_by_form.get(form, []))
	for use in candidates:
		var key: String = use["file"] + "|" + use["where"]
		if not seen.has(key):
			seen[key] = true
			result.append(use)
	return result


## Markers with no matching word, most used first, as
## { "form": String, "count": int, "example": Dictionary }.
func missing_markers(known_forms: Dictionary) -> Array:
	var result: Array = []
	for form in _by_form.keys():
		if known_forms.has(form):
			continue
		result.append({
			"form": _marker_labels[form],
			"count": _by_form[form].size(),
			"example": _by_form[form][0],
		})
	result.sort_custom(func(a, b):
		if a["count"] == b["count"]:
			return a["form"].naturalnocasecmp_to(b["form"]) < 0
		return a["count"] > b["count"])
	return result


func _scan_folder(folder: String, root: String) -> void:
	for file_name in DirAccess.get_files_at(folder):
		if file_name.get_extension() == "json" and file_name != SKIPPED_FILE:
			_scan_file(folder.path_join(file_name), root)
	for sub_folder in DirAccess.get_directories_at(folder):
		_scan_folder(folder.path_join(sub_folder), root)


func _scan_file(file_path: String, root: String) -> void:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(file_path)) != OK:
		errors.append("%s: %s" % [file_path, json.get_error_message()])
		return
	var label := file_path.trim_prefix(root).trim_prefix("/")
	_walk(json.get_data(), label, "", {})


func _walk(value: Variant, file: String, where: String, owner_record: Dictionary) -> void:
	if value is Dictionary:
		for key in value.keys():
			_walk(value[key], file, _join(where, str(key)), value)
	elif value is Array:
		# Arrays keep the enclosing record, so an ID in word_ids is tied to its line.
		var inside_record := not owner_record.is_empty()
		for index in range(value.size()):
			var item = value[index]
			var item_where: String = where if item is String and inside_record else _join(where, str(index))
			_walk(item, file, item_where, owner_record)
	elif value is String:
		_record_string(value, file, where, owner_record)


func _record_string(text: String, file: String, where: String, owner_record: Dictionary) -> void:
	# A use is identified by its record, not by which field of it held the match.
	var line := where.get_base_dir() if not owner_record.is_empty() else where
	var use := {
		"file": file,
		"where": line,
		"speaker": str(owner_record.get("speaker", "")),
		"text": str(owner_record.get("text", text)),
	}
	if _id_regex.search(text):
		_add(_by_id, text, use)
		return
	if not text.contains("\\"):
		return
	for found in _marker_regex.search_all(text):
		var marker := found.get_string(1)
		var form := marker.to_lower()
		_marker_labels.get_or_add(form, marker)
		_add(_by_form, form, use)


func _add(table: Dictionary, key: String, use: Dictionary) -> void:
	if not table.has(key):
		table[key] = []
	for existing in table[key]:
		if existing["file"] == use["file"] and existing["where"] == use["where"]:
			return
	table[key].append(use)


func _join(where: String, part: String) -> String:
	return part if where.is_empty() else where + "/" + part
