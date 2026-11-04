# market_indoors.gd -- root script for market_indoors.tscn. One stop of the walks
# with Rose (see aklan_home_outdoors.gd). _next_cutscene() reads the flags and
# picks the leg to play, so a save made partway picks it up on entry.
#   First trip, Rose leads: in by the north door for scene 2, then back to the park.
#   Sunday mass: a short stop, then home.
#   Later trips: walk in; Rose then waits for the player (TourGuide).
extends Node2D

const ActorPath := preload("res://scripts/util/actor_path.gd")

const WITH_ROSE_FLAG: String = "chapter2_with_rose"
const MASS_TRIP_FLAG: String = "chapter2_mass_trip"
const WALKING_HOME_FLAG: String = "chapter2_walking_home"
const AT_MARKET_FLAG: String = "chapter2_at_market"
const ROSE_SCENE: String = "res://scenes/entities/npc_Rose.tscn"
const ROSE_ID: String = "Rose"

const MarkerUtil := preload("res://scripts/util/marker_util.gd")

func _ready() -> void:
	if not GameState.get_flag(WITH_ROSE_FLAG):
		return  # here without Rose (dev warps)
	await ActorPath.settle(get_tree())
	# Connected only now: the cutscene that loaded this map is finishing as it loads,
	# and the next leg needs the settled collisions.
	CutsceneManager.cutscene_finished.connect(func(_id: String): _play_next())
	while CutsceneManager.is_playing():
		await get_tree().process_frame
	if not _play_next() and is_inside_tree():
		_place_rose()

func _play_next() -> bool:
	if is_queued_for_deletion() or not is_inside_tree() or CutsceneManager.is_playing():
		return false
	if not GameState.get_flag(WITH_ROSE_FLAG):
		return false
	var cutscene_id: String = _next_cutscene()
	if cutscene_id.is_empty():
		return false
	if cutscene_id == "chapter2_tour_leave_market" or cutscene_id == "chapter2_walk_home_market":
		_place_rose()
	CutsceneManager.play(cutscene_id)
	return true

func _next_cutscene() -> String:
	if GameState.get_flag(MASS_TRIP_FLAG):
		return "chapter2_mass_market"
	if GameState.get_flag(WALKING_HOME_FLAG):
		return "chapter2_walk_home_market"
	if not GameState.get_flag("seen_chapter2_scene2"):
		return "chapter2_scene2"
	if not GameState.get_flag("chapter2_tour_done"):
		return "chapter2_tour_leave_market"
	return "" if GameState.get_flag(AT_MARKET_FLAG) else "chapter2_walk_into_market"

## Rose waiting on the carpet, unless she's already here.
func _place_rose() -> void:
	if CutsceneManager.has_actor(ROSE_ID):
		return
	var npc: Node2D = (load(ROSE_SCENE) as PackedScene).instantiate()
	npc.position = to_local(MarkerUtil.find(self, "S2/Rose").global_position)
	add_child(npc)
	CutsceneManager.register_actor(ROSE_ID, npc)
