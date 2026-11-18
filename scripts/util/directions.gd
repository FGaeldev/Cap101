# directions.gd -- preload it (no class_name, same as idle_talk.gd):
#   const Directions := preload("res://scripts/util/directions.gd")
extends RefCounted
## A passerby's "Ask directions": which places the open warps in the current map
## lead to, and dialogue lines that say how to get there. Places and the answer
## wording live in data/map_data/places.json. The answer is from the way the player
## is facing (usually toward the passerby), turn by turn only: straight / back, then
## left / right. The passerby turns toward the place as they answer.

const PLACES_PATH: String = "res://data/map_data/places.json"
const TILE: float = 16.0
## A leg shorter than this (tiles) is left out of the answer.
const LEG_MIN_TILES: float = 3.0

static var _data: Dictionary = {}

static func _load() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PLACES_PATH))
		if parsed is Dictionary:
			_data = parsed
		else:
			push_error("Directions: %s is missing or malformed." % PLACES_PATH)
	return _data

## Open warps under `level` that lead to a known place, one per place (the nearest
## to `from`), sorted by menu label: [{"place": Dictionary, "warp": Node2D}].
## Locked, closed and draft places are left out; dev mode shows drafts.
static func places_here(level: Node, from: Vector2) -> Array:
	var places: Dictionary = _load().get("places", {})
	var nearest: Dictionary = {}
	for warp in _warps(level):
		var place: Dictionary = places.get(str(warp.target_scene), {})
		if place.is_empty() or (place.get("draft", false) and not GameState.dev_mode):
			continue
		if not str(warp.required_flag).is_empty() and not GameState.get_flag(str(warp.required_flag)) \
				and not GameState.dev_mode:
			continue
		var key: String = str(warp.target_scene)
		if not nearest.has(key) or from.distance_squared_to(warp_point(warp)) \
				< from.distance_squared_to(warp_point(nearest[key]["warp"])):
			nearest[key] = {"place": place, "warp": warp}
	var out: Array = nearest.values()
	out.sort_custom(func(a, b): return str(a["place"]["label"]) < str(b["place"]["label"]))
	return out

static func _warps(node: Node) -> Array:
	var out: Array = []
	for child in node.get_children():
		if child is Comp_Warp:
			out.append(child)
		out.append_array(_warps(child))
	return out

## Where the warp's trigger area is, in world coordinates.
static func warp_point(warp: Node2D) -> Vector2:
	var cs := warp.get_node_or_null("CollisionShape2D") as Node2D
	return cs.global_position if cs != null else warp.global_position

## The whole exchange: the passerby asks where to, the player picks a place, asks
## for it, and the passerby answers (turning toward it via `point`, called with the
## world direction). Uses `player`'s position and facing_vec at the time of asking.
static func build_lines(speaker: String, player: Node2D, places: Array, point: Callable) -> Array:
	var prompt: Dictionary = _line(speaker, {"text": "Where do you want to go?"})
	var lines: Array = [prompt]
	var choices: Array = []
	for entry: Dictionary in places:
		var place: Dictionary = entry["place"]
		choices.append({"label": str(place["label"]), "next": lines.size()})
		lines.append(_line("Player", place.get("ask", {})))
		var to_place: Vector2 = warp_point(entry["warp"]) - player.global_position
		var answer: Dictionary = _line(speaker, answer_piece(to_place, _facing(player)))
		answer["next"] = null
		answer["on_enter"] = point.bind(to_place)
		lines.append(answer)
	choices.append({"label": "Never mind."})
	prompt["choices"] = choices
	return lines

static func _facing(player: Node2D) -> Vector2:
	var f = player.get("facing_vec")
	return (f as Vector2).normalized() if f is Vector2 and f != Vector2.ZERO else Vector2.DOWN

## The answer to "where is it?" for a place `offset` away (world px) from someone
## facing `facing`, as {"text", "translation", "word_ids"}.
static func answer_piece(offset: Vector2, facing: Vector2) -> Dictionary:
	var answers: Dictionary = _load().get("answers", {})
	var right_vec := Vector2(-facing.y, facing.x)
	var ahead: float = offset.dot(facing) / TILE
	var side: float = offset.dot(right_vec) / TILE
	var parts: Array = []
	if absf(ahead) >= LEG_MIN_TILES:
		parts.append(answers.get("ahead" if ahead > 0.0 else "back", {}))
	if absf(side) >= LEG_MIN_TILES:
		if not parts.is_empty():
			parts.append(answers.get("then", {}))
		parts.append(answers.get("right" if side > 0.0 else "left", {}))
	# Both legs short (it's close by): name the longer one.
	if parts.is_empty():
		var key: String = ("ahead" if ahead > 0.0 else "back") if absf(ahead) >= absf(side) \
				else ("right" if side > 0.0 else "left")
		parts.append(answers.get(key, {}))
	var route: Dictionary = _join(parts)
	route["text"] = _capitalize(str(route["text"])) + "."
	route["translation"] = _capitalize(str(route["translation"])) + "."
	return route

static func _join(parts: Array) -> Dictionary:
	var out := {"text": "", "translation": "", "word_ids": []}
	for p: Dictionary in parts:
		out["text"] += str(p.get("text", ""))
		out["translation"] += str(p.get("translation", ""))
		out["word_ids"].append_array(p.get("word_ids", []))
	return out

## Upper-cases the first letter, skipping a leading \ word marker.
static func _capitalize(s: String) -> String:
	for i in s.length():
		if s[i] != "\\":
			return s.substr(0, i) + s[i].to_upper() + s.substr(i + 1)
	return s

static func _line(speaker: String, piece: Dictionary) -> Dictionary:
	return {"speaker": speaker, "text": str(piece.get("text", "")),
			"translation": str(piece.get("translation", "")),
			"word_ids": piece.get("word_ids", []).duplicate(), "type": "dialogue"}
