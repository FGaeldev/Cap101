# culture_spots.gd -- people and things that explain Aklan's culture where it
# happens: the parish priest on the Santo Niño, an elder in Pastrana Park on the
# Nineteen Martyrs, the Haboean curator on piña, a KASAMA volunteer at Bakhawan.
# Data: data/culture_spots.json, keyed by level scene path. Game.load_level()
# calls place() for every level.
#   "npcs":        {id, scene, at [x, y] or "marker", face, chapter, scene_key,
#                   hours [from, to], days [weekday 0=Sun..], shop_id,
#                   unless_flag}. Story lines play the first
#                   time (story_done_flag "culture_<id>_heard"), idle talk after.
#   "examinables": {at, size [w, h], chapter, scene_key} -- examinable.gd areas
#                   for objects already in the map (altar, exhibit cabinets).
extends RefCounted

const DATA_PATH: String = "res://data/culture_spots.json"
const MarkerUtil := preload("res://scripts/util/marker_util.gd")
const EXAMINABLE := preload("res://scripts/entities/examinable.gd")
const FACES := {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}

static var _data: Dictionary = {}

static func place(level: Node2D, path: String) -> void:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_data = parsed if parsed is Dictionary else {"_bad": true}
	var spots: Dictionary = _data.get(path, {})
	for entry: Dictionary in spots.get("npcs", []):
		if not _is_out(entry):
			continue
		var npc: Node2D = (load(str(entry["scene"])) as PackedScene).instantiate()
		npc.position = _resolve(level, entry.get("at"))
		npc.dialogue_chapter = str(entry.get("chapter", "chapter2"))
		npc.dialogue_scene_key = str(entry.get("scene_key", ""))
		npc.story_done_flag = "culture_%s_heard" % str(entry.get("id", ""))
		if entry.has("shop_id"):
			npc.shop_id = str(entry["shop_id"])
		level.add_child(npc)
		var anim: Node = npc.get_node_or_null("CutsceneAnimComponent")
		if anim != null and FACES.has(str(entry.get("face", ""))):
			anim.set_cutscene_anim_state("idle", FACES[str(entry["face"])])
	for entry: Dictionary in spots.get("examinables", []):
		var spot := Node2D.new()
		spot.set_script(EXAMINABLE)
		spot.chapter = str(entry.get("chapter", "chapter2"))
		spot.scene_key = str(entry.get("scene_key", ""))
		var size: Array = entry.get("size", [16, 16])
		spot.area_size = Vector2(size[0], size[1])
		spot.position = _resolve(level, entry.get("at"))
		level.add_child(spot)

## Present right now: inside its hours and its unless_flag not set.
static func _is_out(entry: Dictionary) -> bool:
	var unless: String = str(entry.get("unless_flag", ""))
	if not unless.is_empty() and GameState.get_flag(unless):
		return false
	var days: Array = entry.get("days", [])
	if not days.is_empty() and not days.has(float(DayNightManager.get_date()["weekday"])):
		return false
	var hours: Array = entry.get("hours", [])
	if hours.size() == 2:
		var hour: float = DayNightManager.get_hour()
		var from := float(hours[0])
		var to := float(hours[1])
		return hour >= from and hour < to if from <= to else hour >= from or hour < to
	return true

static func _resolve(level: Node2D, at: Variant) -> Vector2:
	if at is String:
		var marker: Node2D = MarkerUtil.find(level, at)
		return level.to_local(marker.global_position) if marker != null else Vector2.ZERO
	if at is Array and at.size() == 2:
		return Vector2(float(at[0]), float(at[1]))
	return Vector2.ZERO
