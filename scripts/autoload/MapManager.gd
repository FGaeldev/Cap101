extends Node
## MapManager.gd
## Autoload. Node-map travel system (Tier 0 deliverable — GDD §2, §9 item 3;
## Roadmap Phase A). Loads region -> destination-scene registry from
## data/map_data/regions.json and writes through to GameState.current_area /
## GameState.current_level_path on successful travel, per the
## register-on-ready / call-through-autoload pattern used by every other
## system (TDD §2).
##
## Region data model and travel logic are J. Gumban's original prototype,
## unchanged. Front-end changed: the Map is now a BookUI tab (page_map.gd)
## instead of a separate MapUI CanvasLayer overlay — see page_map.gd for the
## icon-button replacement of the old color-mask polygon regions
## (region_area.gd, now retired, see scenes/map/ + scripts/map/ deprecation
## note). -- J.Gumban --

const REGION_DATA_PATH := "res://data/map_data/regions.json"
## level scene path -> area id. Covers every level, including ones no map
## region points at (doors, cutscene loads). See area_for_scene().
const LEVEL_AREA_DATA_PATH := "res://data/map_data/level_areas.json"

const ActorPath := preload("res://scripts/util/actor_path.gd")
## dev_skip_to_date(): where and when the player wakes up.
const DEV_SKIP_WAKE_HOUR: float = 6.0
const DEV_BEDROOM_AKLAN := "res://scenes/world/chapter2/aklan_BR_Player.tscn"
const DEV_BEDROOM_US := "res://scenes/world/chapter1/us_bedroom.tscn"
## Beside the bed, where the player stands after getting up.
const DEV_GET_UP_OFFSET := Vector2(-16, 0)

## The player's own bedroom for how far the story has got. Where a save goes if
## the level it was in no longer exists.
func home_level() -> String:
	return DEV_BEDROOM_AKLAN if GameState.get_flag("seen_chapter2_scene0") else DEV_BEDROOM_US

## A skip ends whatever trip with Rose was going on.
const DEV_SKIP_CLEARED_FLAGS: Array[String] = [
	"chapter2_with_rose", "chapter2_left_house", "chapter2_left_home", "chapter2_at_park",
	"chapter2_at_market", "chapter2_from_market", "chapter2_leaving_market",
	"chapter2_walking_home", "chapter2_mass_trip", "chapter2_mass_cathedral",
	"chapter2_at_bakhawan", "chapter2_going_bakhawan", "chapter3_going_haboean", "chapter3_at_haboean",
	"chapter4_going_bakhawan", "chapter4_at_bakhawan",
]

## True from the moment a warp/travel starts (fade-out) until its fade-in
## finishes. Player.get_input_dir() reads this to zero movement input during
## the transition — without it, a held direction carries through the
## black-screen fade into the newly-loaded scene and can walk straight into
## another door standing near the arrival spawn point, chain-triggering a
## second warp mid-fade (seen as both an unwanted instant scene-chain AND an
## overlapping fade_out/fade_in "pulse", same root cause, one flag fixes both).
var is_transitioning: bool = false

## region_id (String, matches regions.json key and its own "id" field)
## -> Dictionary { display_name: String, scene_path: String, unlocked: bool }
var regions: Dictionary = {}

## scene_path (String) -> area id (String), from LEVEL_AREA_DATA_PATH.
var level_areas: Dictionary = {}

func _ready() -> void:
	_load_regions()
	_load_level_areas()

func _load_level_areas() -> void:
	var file := FileAccess.open(LEVEL_AREA_DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("MapManager: failed to open %s" % LEVEL_AREA_DATA_PATH)
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("MapManager: level_areas.json malformed, expected a top-level Dictionary")
		return

	level_areas = parsed

## Area id a level scene belongs to. level_areas.json wins; otherwise the id
## of any region whose scene_path matches; "" if the scene is unknown.
## Game.gd::load_level() writes this to GameState.current_area on every level
## swap, so quests with an "area" field see the level the player is really in.
func area_for_scene(scene_path: String) -> String:
	if level_areas.has(scene_path):
		return str(level_areas[scene_path])
	for region_id in regions:
		if regions[region_id].get("scene_path", "") == scene_path:
			return str(regions[region_id].get("id", region_id))
	return ""

func _load_regions() -> void:
	var file := FileAccess.open(REGION_DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("MapManager: failed to open %s" % REGION_DATA_PATH)
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("MapManager: regions.json malformed, expected a top-level Dictionary")
		return

	regions = parsed

func get_region(region_id: String) -> Dictionary:
	return regions.get(region_id, {})

## region entry may optionally set "gate_challenge_id": String. If present,
## the node's lock state comes from ChallengeManager.is_passed(gate_id)
## instead of the static "unlocked" bool (TDD §9 item 10 — Ch2 node-map
## needs per-node challenge gating, not just static reveal). Regions with
## no gate_challenge_id keep the old static-unlock behavior unchanged.
func is_node_unlocked(region_id: String) -> bool:
	var region: Dictionary = regions.get(region_id, {})
	if region.is_empty():
		return false
	# Dev switch: every place that has a scene opens.
	if GameState.dev_toggle("unlock_all_locations"):
		return not str(region.get("scene_path", "")).is_empty()
	# "unless_flag": locked once that story flag is set (the US house after the
	# flight: going back there stranded the player behind the airport door).
	var unless_flag: String = region.get("unless_flag", "")
	if not unless_flag.is_empty() and GameState.get_flag(unless_flag):
		return false
	# "requires_flag": stays locked until that story flag is set (Kalibo places
	# once Rose hands over her map).
	var requires_flag: String = region.get("requires_flag", "")
	if not requires_flag.is_empty() and not GameState.get_flag(requires_flag):
		return false
	var gate_id: String = region.get("gate_challenge_id", "")
	if not gate_id.is_empty():
		return ChallengeManager.is_passed(gate_id)
	return region.get("unlocked", false)

func is_unlocked(region_id: String) -> bool:
	return is_node_unlocked(region_id)

const RIDE := "ride"
const WALK := "walk"

## Fare for a map trip there (0 = free).
func fare_for(region_id: String) -> int:
	if GameState.dev_toggle("fair_price_zero"):
		return 0
	return int(get_region(region_id).get("fare", 0))

## Why the map can't take the player there right now, or "" if it can: already
## there, or out on a trip with Rose or the family (the story is driving).
func travel_blocked_reason(region_id: String) -> String:
	var region := get_region(region_id)
	if str(region.get("scene_path", "")) == GameState.current_level_path:
		return "You are here."
	# v1.1.9: inside the house the Home ride was still offered. Same area = walk.
	var here: String = area_for_scene(GameState.current_level_path)
	if not here.is_empty() and here == area_for_scene(str(region.get("scene_path", ""))):
		return "You're already home." if here == "aklan_home" else "It's a short walk from here."
	if CutsceneManager.is_playing():
		return "Not now."
	for flag: String in DEV_SKIP_CLEARED_FLAGS:
		if GameState.get_flag(flag):
			return "Not now: you're out with the family."
	return ""

## Called by RegionPopup's go_button. Fades out (if FadeManager is wired),
## switches scene, persists travel state to GameState, fades back in.
##
## Routes through Game.gd::load_level() (swaps LevelContainer's child), NOT
## get_tree().change_scene_to_file() — the latter would replace the whole
## running scene tree (Game.tscn itself, the current_scene once past
## MainMenu), destroying HUD/ScreenFade/DialogueRoot/WordReveal/
## QuestCompletePopup/PuzzlePanel, all of which live in Game.tscn's UILayer
## and are meant to persist across area travel.
## mode (regions with a "fare"): "ride" pays the fare first with the coin
## exchange (Economy.pay) and takes ride_minutes; "walk" is free and advances
## the clock by walk_minutes instead. Regions without a fare ignore it. Story
## trips never come through here (they are cutscenes), so they stay free.
func travel_to_region(region_id: String, mode: String = RIDE) -> void:
	var region := get_region(region_id)
	if region.is_empty():
		push_error("MapManager: unknown region_id '%s'" % region_id)
		return
	if not is_node_unlocked(region_id):
		push_warning("MapManager: refused travel to locked region '%s'" % region_id)
		return
	if not travel_blocked_reason(region_id).is_empty():
		return

	var scene_path: String = region.get("scene_path", "")
	if scene_path.is_empty():
		push_error("MapManager: region '%s' is unlocked but has no scene_path set" % region_id)
		return
	if not ResourceLoader.exists(scene_path):
		push_error("MapManager: region '%s' points to a missing scene: %s" % [region_id, scene_path])
		return

	var game := get_tree().current_scene
	if game == null or not game.has_method("load_level"):
		push_error("MapManager: current_scene has no load_level() — not running inside Game.tscn")
		return
	if is_transitioning:
		return

	var fare: int = fare_for(region_id)
	var minutes: float = 0.0
	if fare > 0:
		minutes = float(region.get("walk_minutes" if mode == WALK else "ride_minutes", 0))
	CutsceneManager.abort()
	BookUI.close()
	if fare > 0 and mode != WALK:
		# The driver names the fare; cancelling or a short wallet costs nothing.
		if not await Economy.pay(fare, "fare_price"):
			return
	is_transitioning = true
	await FadeManager.fade_out()

	DayNightManager.advance_minutes(minutes)
	GameState.current_level_path = scene_path
	# "spawn_id": where the ride drops the player (the cathedral and souvenir
	# shop rides stop outside their doors on the plaza, v1.1.9).
	game.load_level(scene_path, str(region.get("spawn_id", "DefaultSpawn")))  # sets GameState.current_area
	GameState.save_game()

	await FadeManager.fade_in()
	is_transitioning = false

## Dev tool (Calendar tab): jumps to 6 AM on a date, with the player waking up in
## their own bed. Ends any trip with Rose, since the family is home in the morning.
func dev_skip_to_date(year: int, month: int, day: int) -> void:
	var game := get_tree().current_scene
	if is_transitioning or game == null or not game.has_method("load_level"):
		return
	CutsceneManager.abort()
	DialogueUI.hide()
	BookUI.close()
	is_transitioning = true
	await FadeManager.fade_out()

	var in_aklan: bool = GameState.get_flag("seen_chapter2_scene0")
	if in_aklan:
		GameState.set_flag("chapter2_slept")
	for flag: String in DEV_SKIP_CLEARED_FLAGS:
		GameState.set_flag(flag, false)
	DayNightManager.jump_to(year, month, day, DEV_SKIP_WAKE_HOUR)
	var bedroom: String = DEV_BEDROOM_AKLAN if in_aklan else DEV_BEDROOM_US
	GameState.current_level_path = bedroom
	game.load_level(bedroom)
	await ActorPath.settle(get_tree())

	var player: Node2D = CutsceneManager.get_actor("player")
	var bed: Node = _player_bed(game.get_node("LevelContainer").get_child(-1))
	if bed == null:
		push_warning("MapManager: no usable bed in '%s'" % bedroom)
	else:
		var in_bed: Vector2 = bed.lay_down(player)
		GameState.save_game()
		await FadeManager.fade_in()
		await bed.get_up(player, in_bed, in_bed + DEV_GET_UP_OFFSET)
		is_transitioning = false
		return
	GameState.save_game()
	await FadeManager.fade_in()
	is_transitioning = false

## The bed in this level the player can actually sleep in, or null.
func _player_bed(level: Node) -> Node:
	for bed: Node in level.find_children("BedroomBed", "", true, false):
		if bed.get("sleepable"):
			return bed
	return null

## Opens the Map tab. Kept as the stable call site for gameplay code
## (stub_area.gd etc.) so nothing outside BookUI needs to know the map lives
## in a tab now instead of its own overlay.
func open_map() -> void:
	BookUI.open("map")

## Direct scene warp for doors (Comp_Warp). Unlike travel_to_region(), there
## is no region/unlock concept here — doors are always usable — but reuses
## the identical abort/fade/save/load_level sequence so CutsceneManager
## softlock safety (TDD §9 item 8) and save consistency stay in one place
## instead of duplicated per warp path. spawn_id is forwarded to
## Game.gd::load_level() to position the persistent Player (see Game.gd).
## travel_minutes advances the in-game clock while the screen is black
## (Comp_Warp.travel_minutes), before the save so the new time persists.
func warp_to_scene(scene_path: String, spawn_id: String = "DefaultSpawn", travel_minutes: float = 0.0) -> void:
	if scene_path.is_empty():
		push_error("MapManager: warp_to_scene called with empty scene_path")
		return
	if not ResourceLoader.exists(scene_path):
		push_error("MapManager: warp_to_scene called with a missing scene: %s" % scene_path)
		return

	if is_transitioning:
		return

	var game := get_tree().current_scene
	if game == null or not game.has_method("load_level"):
		push_error("MapManager: current_scene has no load_level() — not running inside Game.tscn")
		return

	CutsceneManager.abort()
	BookUI.close()
	is_transitioning = true
	await FadeManager.fade_out()

	DayNightManager.advance_minutes(travel_minutes)
	GameState.current_level_path = scene_path
	game.load_level(scene_path, spawn_id)  # sets GameState.current_area
	GameState.save_game()

	await FadeManager.fade_in()
	is_transitioning = false
