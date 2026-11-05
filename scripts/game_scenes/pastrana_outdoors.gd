# pastrana_outdoors.gd -- root script for pastrana_outdoors.tscn. One stop of the
# walks with Rose (see aklan_home_outdoors.gd). _next_cutscene() reads the flags
# and picks the leg to play, so a save made partway picks it up on entry.
#   First trip, Rose leads and at each stop the player roams until they talk to her:
#     scene 1 at the plaza -> market (market_indoors.gd)
#     -> back here for scenes 3 and 4 at the cathedral -> home.
#   Sunday mass: cathedral_indoors.gd -> market -> back here -> home.
#   Later trips: walk to the plaza; Rose then waits for the player (TourGuide).
#   Bakhawan trip: straight through this map, both ways (bakhawan_outdoors.gd).
extends Node2D

const ActorPath := preload("res://scripts/util/actor_path.gd")

const WITH_ROSE_FLAG: String = "chapter2_with_rose"
const LEFT_HOME_FLAG: String = "chapter2_left_home"
const WALKING_HOME_FLAG: String = "chapter2_walking_home"
const FROM_MARKET_FLAG: String = "chapter2_from_market"
const MASS_TRIP_FLAG: String = "chapter2_mass_trip"
const MASS_CATHEDRAL_FLAG: String = "chapter2_mass_cathedral"
const AT_PARK_FLAG: String = "chapter2_at_park"
const TOUR_DONE_FLAG: String = "chapter2_tour_done"
const GOING_BAKHAWAN_FLAG: String = "chapter2_going_bakhawan"
const ARRIVED_FLAG: String = "chapter2_arrived_park"
const ARRIVED_CATHEDRAL_FLAG: String = "chapter2_arrived_cathedral"
const ROSE_SCENE: String = "res://scenes/entities/npc_Rose.tscn"
const ROSE_ID: String = "Rose"
## Legs that need Rose already standing in the map.
const NEEDS_ROSE: Array[String] = ["chapter2_walk_home_park", "chapter2_tour_to_market"]

const MarkerUtil := preload("res://scripts/util/marker_util.gd")

func _ready() -> void:
	if not GameState.get_flag(WITH_ROSE_FLAG) or not GameState.get_flag(LEFT_HOME_FLAG):
		return  # here without Rose (dev warps)
	await ActorPath.settle(get_tree())
	# Connected only now: the cutscene that loaded this map is finishing as it loads,
	# and the next leg needs the settled collisions.
	CutsceneManager.cutscene_finished.connect(func(_id: String): _play_next())
	while CutsceneManager.is_playing():
		await get_tree().process_frame
	if not _play_next() and is_inside_tree():
		_place_rose()

## Starts the next leg. False if there's none: Rose and the player are just here.
func _play_next() -> bool:
	if is_queued_for_deletion() or not is_inside_tree() or CutsceneManager.is_playing():
		return false
	if not GameState.get_flag(WITH_ROSE_FLAG):
		return false
	var cutscene_id: String = _next_cutscene()
	if cutscene_id.is_empty():
		_place_rose()
		return false
	if NEEDS_ROSE.has(cutscene_id):
		_place_rose()
	CutsceneManager.play(cutscene_id)
	return true

func _next_cutscene() -> String:
	if GameState.get_flag(MASS_TRIP_FLAG):
		if not GameState.get_flag(MASS_CATHEDRAL_FLAG):
			return "chapter2_mass_to_cathedral"
		if not GameState.get_flag(WALKING_HOME_FLAG):
			return "chapter2_mass_to_market"
		return "chapter2_walk_home_from_market"
	if GameState.get_flag(GOING_BAKHAWAN_FLAG):
		return "chapter2_walk_home_from_bakhawan" if GameState.get_flag(WALKING_HOME_FLAG) else "chapter2_walk_to_bakhawan"
	if GameState.get_flag(WALKING_HOME_FLAG):
		return "chapter2_walk_home_from_market" if GameState.get_flag(FROM_MARKET_FLAG) else "chapter2_walk_home_park"
	if not GameState.get_flag("seen_chapter2_scene1"):
		return "" if GameState.get_flag(ARRIVED_FLAG) else "chapter2_scene1"
	if not GameState.get_flag("seen_chapter2_scene2"):
		return "chapter2_tour_to_market"
	if not GameState.get_flag("seen_chapter2_scene4"):
		return "" if GameState.get_flag(ARRIVED_CATHEDRAL_FLAG) else "chapter2_tour_to_cathedral"
	if not GameState.get_flag(TOUR_DONE_FLAG):
		GameState.set_flag(TOUR_DONE_FLAG)
		TutorialManager.start("bakhawan_trip")
		return "chapter2_walk_home_park"
	if GameState.get_flag(FROM_MARKET_FLAG):
		return "chapter2_walk_gate_to_park"
	return "" if GameState.get_flag(AT_PARK_FLAG) else "chapter2_walk_to_park"

## Rose waiting at her spot, unless she's already here.
func _place_rose() -> void:
	if not CutsceneManager.has_actor(ROSE_ID):
		var at_cathedral: bool = GameState.get_flag("seen_chapter2_scene2") and not GameState.get_flag("seen_chapter2_scene4")
		var npc: Node2D = (load(ROSE_SCENE) as PackedScene).instantiate()
		npc.position = to_local(MarkerUtil.find(self, "S3/Rose" if at_cathedral else "S1/Rose").global_position)
		add_child(npc)
		CutsceneManager.register_actor(ROSE_ID, npc)
	_set_rose_resume()

## While the player roams a stop of the first trip, talking to Rose continues it.
func _set_rose_resume() -> void:
	var rose: Node = CutsceneManager.get_actor(ROSE_ID)
	if GameState.get_flag(ARRIVED_FLAG) and not GameState.get_flag("seen_chapter2_scene1"):
		rose.cutscene_id = "chapter2_park_meet_pedring"
		TutorialManager.start("tour_roam")
		rose.cutscene_seen_flag = "seen_chapter2_scene1"
	elif GameState.get_flag(ARRIVED_CATHEDRAL_FLAG) and not GameState.get_flag("seen_chapter2_scene4"):
		rose.cutscene_id = "chapter2_cathedral_talk"
		TutorialManager.start("tour_roam")
		rose.cutscene_seen_flag = "seen_chapter2_scene4"
	else:
		rose.cutscene_id = ""
