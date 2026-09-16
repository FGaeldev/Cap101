# ChapterLoader.gd — loads dialogue JSON, hands array to DialogueComponent at runtime
# Reusability: one loader, N chapters, N NPCs. No per-scene inspector authoring.
# Perf: parse once per chapter entry, cache in memory, drop on chapter exit.
extends Node

var _cache: Dictionary = {}  # chapter_id -> parsed Dictionary

func get_scene_lines(chapter_id: String, scene_key: String) -> Array:
	if not _cache.has(chapter_id):
		_load_chapter(chapter_id)
	return _cache.get(chapter_id, {}).get(scene_key, [])

## Idle pools live as sibling top-level keys in the same chapter JSON
## (e.g. "idle_pool_lola_jonabel"), but are rapport-TIERED, not a flat line
## array like a scene: {"low": [lines], "med": [lines], "high": [lines]}.
## Returns the raw Dictionary -- tier selection is Comp_Dialogue's job
## (it has npc_id + reads GameState.rapport), not ChapterLoader's.
func get_idle_pool(chapter_id: String, pool_key: String) -> Dictionary:
	if not _cache.has(chapter_id):
		_load_chapter(chapter_id)
	return _cache.get(chapter_id, {}).get(pool_key, {})

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

func unload_chapter(chapter_id: String) -> void:
	_cache.erase(chapter_id)
