# TourGuide.gd -- keeps the player with Rose while she's showing them around
# (flag chapter2_with_rose). If the player tries a warp in a map where Rose is,
# the warp doesn't fire: Rose walks over and asks where they want to go instead.
# After dark she walks over and takes them home. Comp_Warp asks intercept()
# before doing anything else.
extends Node

const WITH_ROSE_FLAG := "chapter2_with_rose"
const ROSE_ID := "Rose"
## Pace of Rose's walk over to the player. Same game speed as the long walks.
const APPROACH_SPEED: float = 48.0
const APPROACH_GAME_SPEED: float = 2.0
## First trip: set on reaching a stop, where the player roams until they talk to Rose
## (the level scripts). Cleared if she takes them home first, so the stop starts over.
const ARRIVAL_FLAGS: Array[String] = ["chapter2_arrived_park", "chapter2_arrived_market", "chapter2_arrived_cathedral"]
## Rose takes the player home from this hour until morning.
const HOME_BY_HOUR: int = 18
const MORNING_HOUR: int = 6
## Per map (by scene file): cutscene home, and the places offered under "Somewhere
## else" once their flag is set (no flag = always).
const STOPS: Dictionary = {
	# The cathedral door (WarpArea7) stays open: the tour's cathedral stop sends
	# the player inside to hear the parish priest while Rose waits outside.
	# The souvenir shop (WarpArea8) opens once the first tour's stop in it is done;
	# before that, walking in would start the tour's practice round early.
	"pastrana_outdoors.tscn": {
		"home": "chapter2_walk_home_park",
		"places": [{"label": "The market", "flag": "map_open_market", "cutscene": "chapter2_park_to_market"}],
		"free_warps": ["WarpArea7"],
		"free_warps_after": {"WarpArea8": "chapter2_tour_done"},
	},
	# Rose waits on the plaza; the visitor centre (and the trail behind it) stays open.
	# "go" places have no walk cutscene: a short trip straight to that map (_go).
	"bakhawan_outdoors.tscn": {
		"home": "chapter2_walk_home_bakhawan",
		"places": [{"label": "The park", "flag": "", "unless": "chapter4_going_bakhawan", "go": {
			"to": "res://scenes/world/chapter2/pastrana_outdoors.tscn", "spawn": "FromBakhawan",
			"flags": {"chapter2_going_bakhawan": false, "chapter2_at_bakhawan": false}}}],
		"free_warps": ["WarpArea"],
	},
	"market_indoors.tscn": {
		"home": "chapter2_walk_home_market",
		"places": [{"label": "The park", "flag": "", "cutscene": "chapter2_market_to_park"}],
	},
	# Later visits to the weavers: Rose waits on the plaza. The gallery and cafe
	# doors stay open ("free_warps"); only the gate back to Pastrana asks.
	"habuean_outdoors.tscn": {
		"home": "chapter3_revisit_home",
		"places": [{"label": "The park", "flag": "", "go": {
			"to": "res://scenes/world/chapter2/pastrana_outdoors.tscn", "spawn": "FromHabuean",
			"flags": {"chapter3_going_haboean": false, "chapter3_at_haboean": false}}}],
		"free_warps": ["ToGallery", "ToCafe"],
	},
}

const ActorPath := preload("res://scripts/util/actor_path.gd")
const Objective := preload("res://scripts/util/objective.gd")

func _ready() -> void:
	DayNightManager.hour_changed.connect(_on_hour_changed)

## True if Rose took over this warp attempt.
func intercept(warp: Node, player: Node2D) -> bool:
	if _rose_nearby(player) == null:
		return false
	# A "go there yourself" goal (objective.gd): its door is free, the others
	# get Rose pointing the way.
	if Objective.is_target_warp(warp):
		return false
	if Objective.is_here(GameState.current_level_path):
		_redirect(_rose_nearby(player), player, warp)
		return true
	var stop: Dictionary = _stop_for(_rose_nearby(player))
	if stop.get("free_warps", []).has(String(warp.name)):
		return false
	var opens_after: String = stop.get("free_warps_after", {}).get(String(warp.name), "")
	if not opens_after.is_empty() and GameState.get_flag(opens_after):
		return false
	if _is_waiting_to_resume(_rose_nearby(player)):
		_tell_to_stay(_rose_nearby(player), player, warp)
		return true
	_call_over(_rose_nearby(player), player, warp)
	return true

## Rose in the same map as the player, while out with her and nothing's running.
func _rose_nearby(player: Node2D) -> Node2D:
	if not GameState.get_flag(WITH_ROSE_FLAG) or CutsceneManager.is_playing():
		return null
	if player == null or not CutsceneManager.has_actor(ROSE_ID):
		return null
	var rose: Node2D = CutsceneManager.get_actor(ROSE_ID)
	return rose if rose.get_parent() == player.get_parent() else null

func _on_hour_changed(hour: int) -> void:
	if hour >= MORNING_HOUR and hour < HOME_BY_HOUR:
		return
	if DialogueUI.is_active() or MapManager.is_transitioning or not CutsceneManager.has_actor("player"):
		return
	var player: Node2D = CutsceneManager.get_actor("player")
	var rose: Node2D = _rose_nearby(player)
	if rose != null:
		_approach_then(rose, player, _say_getting_late)

func _approach_then(rose: Node2D, player: Node2D, next: Callable, warp: Node = null) -> void:
	# Same lock warps use: freezes player input while she walks over.
	MapManager.is_transitioning = true
	if warp != null:
		warp._walk_player_back(player)
		await get_tree().create_timer(player.step_time).timeout
	await _walk_rose_over(rose, player)
	MapManager.is_transitioning = false
	if is_instance_valid(rose):
		next.call(rose)

## Walks Rose to the clear tile beside the player that's nearest her.
func _walk_rose_over(rose: Node2D, player: Node2D) -> void:
	var player_tile: Vector2 = _snap(player.global_position)
	var from: Vector2 = _snap(rose.global_position)
	var spots: Array[Vector2] = []
	for dir: Vector2 in ActorPath.DIRECTIONS:
		var spot: Vector2 = player_tile + dir * ActorPath.TILE_SIZE
		if not ActorPath._is_solid(rose, spot):
			spots.append(spot)
	spots.sort_custom(func(a: Vector2, b: Vector2): return a.distance_to(from) < b.distance_to(from))
	if spots.is_empty() or spots.has(from):
		_set_anim(rose, "idle", player_tile - from)
		return
	Engine.time_scale = APPROACH_GAME_SPEED
	var prev: Vector2 = from
	for leg_end: Vector2 in ActorPath.around_actors(CutsceneManager, rose, from, spots[0]):
		_set_anim(rose, "walk", (leg_end - prev).normalized())
		var tween := rose.create_tween()
		tween.tween_property(rose, "global_position", leg_end, prev.distance_to(leg_end) / APPROACH_SPEED)
		await tween.finished
		prev = leg_end
	Engine.time_scale = 1.0
	_set_anim(rose, "idle", player_tile - prev)

func _stop_for(rose: Node2D) -> Dictionary:
	return STOPS.get(rose.get_parent().scene_file_path.get_file(), {})

func _say_getting_late(rose: Node2D) -> void:
	var dialogue := DialogueComponent.new()
	dialogue.dialogue_lines = [{"speaker": "Rose", "text": "It's getting late, balikbayan. Let's head home.", "next": null}]
	rose.add_child(dialogue)
	dialogue.dialogue_ended.connect(func():
		dialogue.queue_free()
		_play_home(rose))
	dialogue.start_dialogue()

## First trip stop: talking to her continues the tour (npc_generic.gd cutscene_id).
func _is_waiting_to_resume(rose: Node2D) -> bool:
	return not rose.cutscene_id.is_empty() and not GameState.get_flag(rose.cutscene_seen_flag)

func _tell_to_stay(rose: Node2D, player: Node2D, warp: Node) -> void:
	MapManager.is_transitioning = true
	warp._walk_player_back(player)
	await get_tree().create_timer(player.step_time).timeout
	MapManager.is_transitioning = false
	var dialogue := DialogueComponent.new()
	dialogue.dialogue_lines = [{"speaker": "Rose", "text": "Not yet, balikbayan. Talk to me when you are ready to keep going.", "next": null}]
	rose.add_child(dialogue)
	dialogue.dialogue_ended.connect(dialogue.queue_free)
	dialogue.start_dialogue()

## Another door while a goal waits here: Rose points the way (the arrow shows it).
func _redirect(rose: Node2D, player: Node2D, warp: Node) -> void:
	MapManager.is_transitioning = true
	warp._walk_player_back(player)
	await get_tree().create_timer(player.step_time).timeout
	MapManager.is_transitioning = false
	var dialogue := DialogueComponent.new()
	dialogue.dialogue_lines = [{"speaker": "Rose", "text": "Not that way, balikbayan. %s first. Follow the arrow." % Objective.label(), "next": null}]
	rose.add_child(dialogue)
	dialogue.dialogue_ended.connect(dialogue.queue_free)
	dialogue.start_dialogue()

func _play_home(rose: Node2D) -> void:
	for flag: String in ARRIVAL_FLAGS:
		GameState.set_flag(flag, false)
	var home: String = _stop_for(rose).get("home", "")
	if not home.is_empty():
		CutsceneManager.play(home)

## Choices jump past the last line to report the answer (same trick as
## sleep_bed.gd): dialogue_lines.size() + choice index. -1 stays where they are.
## True when Rose's talk menu should offer "Let's go somewhere": out with her
## in a map she guides, and no required stop of the trip is waiting on her.
func can_offer_trip(rose: Node2D) -> bool:
	return GameState.get_flag(WITH_ROSE_FLAG) and _rose_nearby(rose) == rose \
			and not _stop_for(rose).is_empty() and not _is_waiting_to_resume(rose)

## The "where to?" choices, from Rose's talk menu (npc_generic.gd).
func ask(rose: Node2D) -> void:
	_ask(rose)

func _ask(rose: Node2D) -> void:
	var places: Array[Dictionary] = []
	for place: Dictionary in _stop_for(rose).get("places", []):
		if not str(place.get("unless", "")).is_empty() and GameState.get_flag(place["unless"]):
			continue
		if place["flag"].is_empty() or GameState.get_flag(place["flag"]):
			places.append(place)
	var home_choice: int = 2
	var lines: Array = [
		{"speaker": "Rose", "text": "Leaving already? Where do you want to go?", "choices": [
			{"label": "Somewhere else", "next": 1},
			{"label": "Home", "next": home_choice},
			{"label": "Stay here a bit", "next": -1},
		]},
	]
	if places.is_empty():
		lines.append({"speaker": "Rose", "text": "Nowhere else is ready for us yet, balikbayan. Look around here a little more.", "next": null})
	else:
		var choices: Array = []
		for i in places.size():
			choices.append({"label": places[i]["label"], "next": home_choice + 1 + i})
		choices.append({"label": "Never mind", "next": -1})
		lines.append({"speaker": "Rose", "text": "Where to, then?", "choices": choices})
	var dialogue := DialogueComponent.new()
	dialogue.dialogue_lines = lines
	rose.add_child(dialogue)
	dialogue.dialogue_ended.connect(func():
		var answer: int = dialogue._current_line
		dialogue.queue_free()
		if answer == home_choice:
			_walk_or_ride(rose, _stop_for(rose).get("home", ""))
		elif answer > home_choice:
			var place: Dictionary = places[answer - home_choice - 1]
			if place.has("go"):
				_go_walk_or_ride(rose, place["go"])
			else:
				_walk_or_ride(rose, place["cutscene"]))
	dialogue.start_dialogue()

## Minutes a direct trip ("go" place) takes on the clock.
const GO_MINUTES: float = 20.0
## Set on every direct trip to the park: Rose and the player just standing there
## (pastrana_outdoors.gd then plays no leg and places Rose).
const GO_FLAGS: Dictionary = {"chapter2_left_home": true, "chapter2_walking_home": false,
		"chapter2_from_market": false, "chapter2_at_park": true}

## A place with no walk cutscene: fade, set the trip flags, and load the map at
## its spawn. Rose stays with the player (WITH_ROSE_FLAG); the map places her.
func _go(go: Dictionary) -> void:
	for flag: String in ARRIVAL_FLAGS:
		GameState.set_flag(flag, false)
	for flag: String in GO_FLAGS:
		GameState.set_flag(flag, bool(GO_FLAGS[flag]))
	var extra: Dictionary = go.get("flags", {})
	for flag: String in extra:
		GameState.set_flag(flag, bool(extra[flag]))
	MapManager.warp_to_scene(str(go["to"]), str(go.get("spawn", "DefaultSpawn")), float(go.get("minutes", GO_MINUTES)))

## v1.1.9 ("no ride after Bakhawan"): a direct trip from a far stop (Bakhawan,
## Haboean) asks walk or ride like the walks home do. The fare and ride time are
## the stop's own region's (regions.json); walking takes its walk_minutes.
func _go_walk_or_ride(rose: Node2D, go: Dictionary) -> void:
	var region: Dictionary = MapManager.get_region(MapManager.area_for_scene(GameState.current_level_path))
	var fare: int = int(region.get("fare", 0))
	if fare <= 0:
		_go(go)
		return
	var vehicle: String = str(region.get("vehicle", "Tricycle")).to_lower()
	var dialogue := DialogueComponent.new()
	dialogue.dialogue_lines = [
		{"speaker": "Rose", "text": "Walk, or take a %s? It's ₱%d." % [vehicle, fare], "choices": [
			{"label": "Let's walk.", "next": 1},
			{"label": "Take a %s (₱%d)" % [vehicle, fare], "next": 2},
		]},
	]
	rose.add_child(dialogue)
	dialogue.start_dialogue()
	await dialogue.dialogue_ended
	var picked_ride: bool = dialogue._current_line == 2
	dialogue.queue_free()
	var trip: Dictionary = go.duplicate()
	if picked_ride and await Economy.pay(fare, "fare_price"):
		trip["minutes"] = float(region.get("ride_minutes", GO_MINUTES))
	else:
		trip["minutes"] = float(region.get("walk_minutes", GO_MINUTES))
	_go(trip)

# --- riding instead of walking (v1.1.3 playtest: "can't ride with someone") --
#
# Walks with Rose chain across maps, each map playing the next leg from the
# trip flags. A ride pays the fare, sets the flags the walk would have, and
# loads the walk's last map, whose own script plays the arrival as usual.
# Keyed by walk cutscene: "region" gives fare, vehicle and ride time
# (regions.json); "to" is the last map; "flags" are set besides the walk's own.
const RIDES: Dictionary = {
	"chapter2_park_to_market": {"region": "market", "to": "res://scenes/world/market/market_indoors.tscn",
			"flags": {"chapter2_leaving_market": false}},
	"chapter2_market_to_park": {"region": "pastrana", "to": "res://scenes/world/chapter2/pastrana_outdoors.tscn",
			"flags": {"chapter2_leaving_market": false}},
	"chapter2_walk_home_park": {"region": "aklan_home", "to": "res://scenes/world/chapter2/aklan_living.tscn"},
	"chapter2_walk_home_market": {"region": "aklan_home", "to": "res://scenes/world/chapter2/aklan_living.tscn",
			"flags": {"chapter2_leaving_market": false}},
	"chapter2_walk_home_bakhawan": {"region": "bakhawan_ecopark", "to": "res://scenes/world/chapter2/aklan_living.tscn"},
	"chapter3_revisit_home": {"region": "haboean", "to": "res://scenes/world/chapter2/aklan_living.tscn"},
}

## Rose asks walk or ride; walking (or a ride not paid) plays the walk as before.
func _walk_or_ride(rose: Node2D, walk_id: String) -> void:
	if walk_id.is_empty():
		return
	if walk_id == _stop_for(rose).get("home", ""):
		for flag: String in ARRIVAL_FLAGS:
			GameState.set_flag(flag, false)
	var ride: Dictionary = RIDES.get(walk_id, {})
	var region: Dictionary = MapManager.get_region(str(ride.get("region", "")))
	var fare: int = int(region.get("fare", 0))
	if ride.is_empty() or fare <= 0:
		CutsceneManager.play(walk_id)
		return
	var vehicle: String = str(region.get("vehicle", "Tricycle")).to_lower()
	var dialogue := DialogueComponent.new()
	dialogue.dialogue_lines = [
		{"speaker": "Rose", "text": "Walk, or take a %s? It's ₱%d." % [vehicle, fare], "choices": [
			{"label": "Let's walk.", "next": 1},
			{"label": "Take a %s (₱%d)" % [vehicle, fare], "next": 2},
		]},
	]
	rose.add_child(dialogue)
	dialogue.start_dialogue()
	await dialogue.dialogue_ended
	var picked_ride: bool = dialogue._current_line == 2
	dialogue.queue_free()
	if not picked_ride:
		CutsceneManager.play(walk_id)
		return
	# The driver names the fare; cancelling or a short wallet means walking.
	if not await Economy.pay(fare, "fare_price"):
		_say_then(rose, "Walking it is, then.", func(): CutsceneManager.play(walk_id))
		return
	_ride(walk_id, ride, region)

func _ride(walk_id: String, ride: Dictionary, region: Dictionary) -> void:
	for action in _cutscene_steps(walk_id):
		if action is Dictionary and str(action.get("type", "")) == "set_flag":
			GameState.set_flag(str(action["flag"]), bool(action.get("value", true)))
	var extra: Dictionary = ride.get("flags", {})
	for flag: String in extra:
		GameState.set_flag(flag, bool(extra[flag]))
	MapManager.is_transitioning = true
	await FadeManager.fade_out()
	DayNightManager.advance_minutes(float(region.get("ride_minutes", 0)))
	var to: String = str(ride["to"])
	GameState.current_level_path = to
	get_tree().current_scene.load_level(to)
	GameState.save_game()
	# The last map's arrival cutscene fades in, as after a walk's load_scene.
	MapManager.is_transitioning = false

## A walk cutscene's steps, read straight from its JSON.
func _cutscene_steps(cutscene_id: String) -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/cutscenes/%s.json" % cutscene_id))
	return parsed if parsed is Array else []

func _say_then(rose: Node2D, text: String, next: Callable) -> void:
	var dialogue := DialogueComponent.new()
	dialogue.dialogue_lines = [{"speaker": "Rose", "text": text, "next": null}]
	rose.add_child(dialogue)
	dialogue.dialogue_ended.connect(func():
		dialogue.queue_free()
		next.call())
	dialogue.start_dialogue()

func _set_anim(rose: Node2D, state: String, dir: Vector2) -> void:
	var anim: Node = rose.get_node_or_null("CutsceneAnimComponent")
	if anim:
		anim.set_cutscene_anim_state(state, dir)

func _snap(pos: Vector2) -> Vector2:
	return (pos / ActorPath.TILE_SIZE).round() * ActorPath.TILE_SIZE

## Rose waiting to be asked where to go next, after calling the player over.
var _pending_ask: Node2D = null

## A locked/away warp while out with Rose: instead of making the player wait
## while she walks over, she calls out and marks herself; talking to her then
## asks where to go (take_pending_ask, npc_generic.gd).
func _call_over(rose: Node2D, player: Node2D, warp: Node) -> void:
	MapManager.is_transitioning = true
	warp._walk_player_back(player)
	await get_tree().create_timer(player.step_time).timeout
	MapManager.is_transitioning = false
	if not is_instance_valid(rose):
		return
	_pending_ask = rose
	_set_marker(rose, true)
	var dialogue := DialogueComponent.new()
	dialogue.dialogue_lines = [{"speaker": "Rose", "text": "Balikbayan, over here! Come talk to me if you want to go somewhere.", "next": null}]
	rose.add_child(dialogue)
	dialogue.dialogue_ended.connect(dialogue.queue_free)
	dialogue.start_dialogue()

## True (and opens the "where to?" choices) if Rose called the player over.
func take_pending_ask(rose: Node2D) -> bool:
	if _pending_ask != rose or not is_instance_valid(rose) or not GameState.get_flag(WITH_ROSE_FLAG):
		_pending_ask = null
		return false
	_pending_ask = null
	_set_marker(rose, false)
	_ask(rose)
	return true

func _set_marker(rose: Node2D, on: bool) -> void:
	var ic: Node = rose.get_node_or_null("InteractableComponent")
	if ic:
		ic.is_active = on
		ic.refresh_quest_marker()
