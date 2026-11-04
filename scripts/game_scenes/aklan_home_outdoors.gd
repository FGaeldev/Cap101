# aklan_home_outdoors.gd -- root script for aklan_home_outdoors.tscn. This street
# is part of every walk with Rose, which runs as a chain of cutscenes, one per
# map, each ending by loading the next:
#   Out:  chapter2_rose_walk_room -> chapter2_walk_living -> chapter2_walk_outdoors
#         -> chapter2_scene1 or chapter2_walk_to_park (or start from the living room
#         with chapter2_rose_walk_living)
#   Home: chapter2_walk_home_park -> chapter2_walk_home_street -> chapter2_walk_home_living
# Flags say how far along it is, so a save made partway picks it up on entry.
extends Node2D

const ActorPath := preload("res://scripts/util/actor_path.gd")

const WITH_ROSE_FLAG: String = "chapter2_with_rose"
const LEFT_HOME_FLAG: String = "chapter2_left_home"
const WALKING_HOME_FLAG: String = "chapter2_walking_home"
const WALK_OUT_CUTSCENE_ID: String = "chapter2_walk_outdoors"
const WALK_HOME_CUTSCENE_ID: String = "chapter2_walk_home_street"

func _ready() -> void:
	var cutscene_id: String = ""
	if GameState.get_flag(WALKING_HOME_FLAG):
		cutscene_id = WALK_HOME_CUTSCENE_ID
	elif GameState.get_flag(WITH_ROSE_FLAG) and not GameState.get_flag(LEFT_HOME_FLAG):
		cutscene_id = WALK_OUT_CUTSCENE_ID
	if cutscene_id.is_empty():
		return
	await ActorPath.settle(get_tree())
	while CutsceneManager.is_playing():
		await get_tree().process_frame
	if is_inside_tree():
		CutsceneManager.play(cutscene_id)
