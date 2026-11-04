# pastrana_outdoors.gd -- root script for pastrana_outdoors.tscn. One stop of the
# walks with Rose (see aklan_home_outdoors.gd). _next_cutscene() reads the flags
# and picks the leg to play, so a save made partway picks it up on entry.
#   First trip, Rose leads: scene 1 at the plaza -> market (market_indoors.gd)
#     -> back here for scenes 3 and 4 at the cathedral -> home.
#   Sunday mass: cathedral_indoors.gd -> market -> back here -> home.
#   Later trips: walk to the plaza; Rose then waits for the player (TourGuide).
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
	if GameState.get_flag(WALKING_HOME_FLAG):
		return "chapter2_walk_home_from_market" if GameState.get_flag(FROM_MARKET_FLAG) else "chapter2_walk_home_park"
	if not GameState.get_flag("seen_chapter2_scene1"):
		return "chapter2_scene1"
	if not GameState.get_flag("seen_chapter2_scene2"):
		return "chapter2_tour_to_market"
	if not GameState.get_flag("seen_chapter2_scene4"):
		return "chapter2_tour_to_cathedral"
	if not GameState.get_flag(TOUR_DONE_FLAG):
		GameState.set_flag(TOUR_DONE_FLAG)
		return "chapter2_walk_home_park"
	if GameState.get_flag(FROM_MARKET_FLAG):
		return "chapter2_walk_gate_to_park"
	return "" if GameState.get_flag(AT_PARK_FLAG) else "chapter2_walk_to_park"

## Rose waiting at the plaza, unless she's already here.
func _place_rose() -> void:
	if CutsceneManager.has_actor(ROSE_ID):
		return
	var npc: Node2D = (load(ROSE_SCENE) as PackedScene).instantiate()
	npc.position = to_local(MarkerUtil.find(self, "S1/Rose").global_position)
	add_child(npc)
	CutsceneManager.register_actor(ROSE_ID, npc)
