# bakhawan_indoors.gd -- root script for bakhawan_indoors.tscn, the Bakhawan
# Eco-Park visitor centre: the way from the plaza (front door) to the mangrove
# trail (back door). Built by art_requests/tools/build_bakhawan_maps.gd.txt.
#
# On Chapter 4's trip Rose leads Papa Jobert and the player straight through:
#   in:  chapter4_walk_centre_in   front door -> back door -> bakhawan_trail
#   out: chapter4_walk_centre_out  back door -> front door -> plaza (walking home)
# Any other visit the room is just open to walk through.
extends Node2D

const ActorPath := preload("res://scripts/util/actor_path.gd")

const WITH_ROSE_FLAG: String = "chapter2_with_rose"
const WALKING_HOME_FLAG: String = "chapter2_walking_home"
const CH4_TRIP_FLAG: String = "chapter4_going_bakhawan"
const WALK_IN_CUTSCENE_ID: String = "chapter4_walk_centre_in"
const WALK_OUT_CUTSCENE_ID: String = "chapter4_walk_centre_out"

func _ready() -> void:
	if not GameState.get_flag(WITH_ROSE_FLAG) or not GameState.get_flag(CH4_TRIP_FLAG):
		return
	var cutscene_id: String = ""
	if GameState.get_flag(WALKING_HOME_FLAG):
		cutscene_id = WALK_OUT_CUTSCENE_ID
	elif not GameState.get_flag("seen_chapter4_scene1"):
		cutscene_id = WALK_IN_CUTSCENE_ID
	if cutscene_id.is_empty():
		return
	await ActorPath.settle(get_tree())
	while CutsceneManager.is_playing():
		await get_tree().process_frame
	if is_inside_tree():
		CutsceneManager.play(cutscene_id)
