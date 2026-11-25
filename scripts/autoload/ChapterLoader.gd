# ChapterLoader.gd — loads dialogue JSON, hands array to DialogueComponent at runtime
# Reusability: one loader, N chapters, N NPCs. No per-scene inspector authoring.
# Perf: parse once per chapter entry, cache in memory, drop on chapter exit.
extends Node

var _cache: Dictionary = {}  # chapter_id -> parsed Dictionary

func get_scene_lines(chapter_id: String, scene_key: String) -> Array:
	if not _cache.has(chapter_id):
		_load_chapter(chapter_id)
	return _cache.get(chapter_id, {}).get(scene_key, [])


## The chapter's "remarks": {remark_id: {speaker, requires, unless, lines}}, the
## one-time story reactions IdleTalk plays before normal idle talk. {} if none.
func get_remarks(chapter_id: String) -> Dictionary:
	if not _cache.has(chapter_id):
		_load_chapter(chapter_id)
	var remarks = _cache.get(chapter_id, {}).get("remarks", {})
	return remarks if remarks is Dictionary else {}

func _load_chapter(chapter_id: String) -> void:
	var path = "res://data/dialogue/%s.json" % chapter_id
	if not FileAccess.file_exists(path):
		push_error("ChapterLoader: missing file %s" % path)
		_cache[chapter_id] = {}
		return
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_error("ChapterLoader: bad JSON in %s (%s)" % [path, json.get_error_message()])
		_cache[chapter_id] = {}
		return
	_cache[chapter_id] = json.get_data()
	# Story minigames become lessons the next chapter waits on (lessons.gd).
	preload("res://scripts/util/lessons.gd").stamp_chapter(chapter_id, _cache[chapter_id])
	_time_quizzes(chapter_id, _cache[chapter_id])

## Chapters whose story quizzes are timed, and the seconds per question when a
## line doesn't set "seconds_per_question" itself (v1.1.7 difficulty).
const TIMED_QUIZ_CHAPTERS: Array[String] = ["chapter3", "chapter4"]
const QUIZ_SECONDS_PER_QUESTION: float = 15.0

func _time_quizzes(chapter_id: String, data: Variant) -> void:
	if not TIMED_QUIZ_CHAPTERS.has(chapter_id) or not data is Dictionary:
		return
	for scene_key in data:
		var lines: Variant = data[scene_key]
		if not lines is Array:
			continue
		for line: Variant in lines:
			if line is Dictionary and str(line.get("type", "")) == "quiz" and not line.has("seconds_per_question"):
				line["seconds_per_question"] = QUIZ_SECONDS_PER_QUESTION

func unload_chapter(chapter_id: String) -> void:
	_cache.erase(chapter_id)
