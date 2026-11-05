# bakhawan_outdoors.gd -- root script for bakhawan_outdoors.tscn. One stop of the trip
# Rose offers once chapter 2's tour is done (scene_rose_walk_to_park):
#   Home -> street -> park (chapter2_walk_to_bakhawan) -> here -> back the same way.
# TourGuide handles leaving from here. A save made here puts Rose back at her spot.
extends Node2D

const ActorPath := preload("res://scripts/util/actor_path.gd")
const MarkerUtil := preload("res://scripts/util/marker_util.gd")

const WITH_ROSE_FLAG: String = "chapter2_with_rose"
const AT_BAKHAWAN_FLAG: String = "chapter2_at_bakhawan"
const ROSE_SCENE: String = "res://scenes/entities/npc_Rose.tscn"
const ROSE_ID: String = "Rose"
const ARRIVAL_CUTSCENE_ID: String = "chapter2_walk_into_bakhawan"

func _ready() -> void:
	if not GameState.get_flag(WITH_ROSE_FLAG):
		return  # here without Rose (dev warps)
	await ActorPath.settle(get_tree())
	while CutsceneManager.is_playing():
		await get_tree().process_frame
	if not is_inside_tree():
		return
	if GameState.get_flag(AT_BAKHAWAN_FLAG):
		_place_rose()
	else:
		CutsceneManager.play(ARRIVAL_CUTSCENE_ID)

func _place_rose() -> void:
	if CutsceneManager.has_actor(ROSE_ID):
		return
	var npc: Node2D = (load(ROSE_SCENE) as PackedScene).instantiate()
	npc.position = to_local(MarkerUtil.find(self, "Trip/Rose").global_position)
	add_child(npc)
	CutsceneManager.register_actor(ROSE_ID, npc)
