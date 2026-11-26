# culture_spots.gd -- people and things that explain Aklan's culture where it
# happens: the parish priest on the Santo Niño, an elder in Pastrana Park on the
# Nineteen Martyrs, the Haboean curator on piña, a KASAMA volunteer at Bakhawan.
# Data: data/culture_spots.json, keyed by level scene path. Game.load_level()
# calls place() for every level.
#   "npcs":        {id, scene, at [x, y] or "marker", face, chapter, scene_key,
#                   hours [from, to], days [weekday 0=Sun..], shop_id,
#                   requires_flag, unless_flag, chance (0-100: out on that share
#                   of days, the same all day; random events)}. Story lines play
#                   the first time (story_done_flag "culture_<id>_heard"), idle
#                   talk after. is_spot_out(id) tells side quests (offer_spot)
#                   whether a spot's person is out right now.
#   "examinables": {at, size [w, h], chapter, scene_key} -- examinable.gd areas
#                   for objects already in the map (altar, exhibit cabinets).
#   "props":       {texture, region [x, y, w, h], at, solid [w, h]} -- a solid
#                   sprite standing on `at` (bottom centre), y-sorted with the
#                   level, e.g. the Pastrana Park statues. Pair with an
#                   examinable in front for its plaque.
#   "pickups":     {id, item, at, requires_flag, unless_flag, text} -- pickup.gd
#                   glints for side quests (shown only while the quest wants them).
extends RefCounted

const DATA_PATH: String = "res://data/culture_spots.json"
const MarkerUtil := preload("res://scripts/util/marker_util.gd")
const EXAMINABLE := preload("res://scripts/entities/examinable.gd")
const PICKUP := preload("res://scripts/entities/pickup.gd")
const FACES := {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}

static var _data: Dictionary = {}

static func _load() -> void:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_data = parsed if parsed is Dictionary else {"_bad": true}

## True if the spot NPC with this id (any level) is out right now.
static func is_spot_out(spot_id: String) -> bool:
	_load()
	for path: String in _data:
		if not _data[path] is Dictionary:
			continue
		for entry: Dictionary in _data[path].get("npcs", []):
			if str(entry.get("id", "")) == spot_id:
				return _is_out(entry)
	return false

static func place(level: Node2D, path: String) -> void:
	_load()
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
		if entry.has("activity"):
			npc.activity = str(entry["activity"])
		level.add_child(npc)
		var anim: Node = npc.get_node_or_null("CutsceneAnimComponent")
		if anim != null and FACES.has(str(entry.get("face", ""))):
			anim.set_cutscene_anim_state("idle", FACES[str(entry["face"])])
	for entry: Dictionary in spots.get("props", []):
		level.add_child(_make_prop(level, entry))
	for entry: Dictionary in spots.get("examinables", []):
		var spot := Node2D.new()
		spot.set_script(EXAMINABLE)
		spot.chapter = str(entry.get("chapter", "chapter2"))
		spot.scene_key = str(entry.get("scene_key", ""))
		var size: Array = entry.get("size", [16, 16])
		spot.area_size = Vector2(size[0], size[1])
		spot.position = _resolve(level, entry.get("at"))
		level.add_child(spot)
	for entry: Dictionary in spots.get("pickups", []):
		var pickup := Node2D.new()
		pickup.set_script(PICKUP)
		pickup.pickup_id = str(entry.get("id", ""))
		pickup.item_id = str(entry.get("item", ""))
		pickup.requires_flag = str(entry.get("requires_flag", ""))
		pickup.unless_flag = str(entry.get("unless_flag", ""))
		pickup.found_text = str(entry.get("text", ""))
		pickup.position = _resolve(level, entry.get("at"))
		level.add_child(pickup)

static func _make_prop(level: Node2D, entry: Dictionary) -> Node2D:
	var prop := Node2D.new()
	prop.position = _resolve(level, entry.get("at"))
	var region: Array = entry.get("region", [0, 0, 16, 16])
	var sprite := Sprite2D.new()
	sprite.texture = load(str(entry.get("texture", "")))
	sprite.centered = false
	sprite.region_enabled = true
	sprite.region_rect = Rect2(region[0], region[1], region[2], region[3])
	sprite.position = Vector2(-float(region[2]) / 2.0, -float(region[3]))
	prop.add_child(sprite)
	var solid: Array = entry.get("solid", [])
	if solid.size() == 2:
		var body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(solid[0], solid[1])
		shape.shape = rect
		shape.position = Vector2(0, -float(solid[1]) / 2.0)
		body.add_child(shape)
		prop.add_child(body)
	return prop

## Present right now: inside its hours and its unless_flag not set.
static func _is_out(entry: Dictionary) -> bool:
	var unless: String = str(entry.get("unless_flag", ""))
	if not unless.is_empty() and GameState.get_flag(unless):
		return false
	var requires: String = str(entry.get("requires_flag", ""))
	if not requires.is_empty() and not GameState.get_flag(requires):
		return false
	# Random events: the same answer all day (seeded by the daily date and id).
	if entry.has("chance"):
		var roll: int = absi(hash("%s:%d" % [str(entry.get("id", "")), GameState.daily_date()])) % 100
		if roll >= int(entry["chance"]):
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
