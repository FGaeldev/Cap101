# haboean_outdoors.gd -- root script for habuean_outdoors.tscn. Chapter 3's trip to
# the weavers passes through here both ways, as a chain of cutscenes (see
# haboean_gallery.gd for the whole chain):
#   Out:  chapter3_walk_to_haboean (Pastrana) -> chapter3_arrive -> gallery
#   Home: cafe -> chapter3_walk_home_outdoors -> Pastrana
extends Node2D

const ActorPath := preload("res://scripts/util/actor_path.gd")

const WITH_ROSE_FLAG: String = "chapter2_with_rose"
const GOING_HABOEAN_FLAG: String = "chapter3_going_haboean"
const WALKING_HOME_FLAG: String = "chapter2_walking_home"
const ARRIVE_CUTSCENE_ID: String = "chapter3_arrive"
const WALK_HOME_CUTSCENE_ID: String = "chapter3_walk_home_outdoors"

func _ready() -> void:
	if not GameState.get_flag(WITH_ROSE_FLAG) or not GameState.get_flag(GOING_HABOEAN_FLAG):
		return  # here without Rose (dev warps, later visits)
	await ActorPath.settle(get_tree())
	while CutsceneManager.is_playing():
		await get_tree().process_frame
	if not is_inside_tree():
		return
	if GameState.get_flag(WALKING_HOME_FLAG):
		CutsceneManager.play(WALK_HOME_CUTSCENE_ID)
	elif not GameState.get_flag("seen_chapter3_scene1"):
		CutsceneManager.play(ARRIVE_CUTSCENE_ID)
