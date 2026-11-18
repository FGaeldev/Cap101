# bakhawan_outdoors.gd -- root script for bakhawan_outdoors.tscn: the Bakhawan
# Eco-Park plaza and parking. The visitor centre's front door leads to
# bakhawan_indoors, and its back door to the mangrove trail (bakhawan_trail).
#
# Chapter 4 (docs/CHAPTER4_PLAN.md): the walk from Pastrana ends here.
#   chapter4_arrive         Rose leads Papa Jobert and the player into the visitor centre
#   chapter4_walk_plaza_out on the way home: out of the visitor centre, on to Pastrana
#
# Any other visit with Rose (her trip menu, after Chapter 4):
#   Home -> street -> park (chapter2_walk_to_bakhawan) -> here -> back the same way.
# Rose waits on the plaza; the visitor centre stays open (TourGuide "free_warps").
# TourGuide handles leaving from here. A save made here puts Rose back at her spot.
extends Node2D

const ActorPath := preload("res://scripts/util/actor_path.gd")
const MarkerUtil := preload("res://scripts/util/marker_util.gd")

const WITH_ROSE_FLAG: String = "chapter2_with_rose"
const AT_BAKHAWAN_FLAG: String = "chapter2_at_bakhawan"
const WALKING_HOME_FLAG: String = "chapter2_walking_home"
const ROSE_SCENE: String = "res://scenes/entities/npc_Rose.tscn"
const ROSE_ID: String = "Rose"
const ARRIVAL_CUTSCENE_ID: String = "chapter2_walk_into_bakhawan"

const CH4_TRIP_FLAG: String = "chapter4_going_bakhawan"
const CH4_ARRIVE_CUTSCENE_ID: String = "chapter4_arrive"
const CH4_HOME_CUTSCENE_ID: String = "chapter4_walk_plaza_out"

func _ready() -> void:
	if not GameState.get_flag(WITH_ROSE_FLAG):
		return  # here without Rose (dev warps)
	await ActorPath.settle(get_tree())
	while CutsceneManager.is_playing():
		await get_tree().process_frame
	if not is_inside_tree():
		return
	if _ch4_trip():
		if GameState.get_flag(WALKING_HOME_FLAG):
			CutsceneManager.play(CH4_HOME_CUTSCENE_ID)
		elif not GameState.get_flag("seen_chapter4_scene1"):
			CutsceneManager.play(CH4_ARRIVE_CUTSCENE_ID)
		return  # otherwise Rose and Jobert are out on the trail
	if GameState.get_flag(AT_BAKHAWAN_FLAG):
		_place_rose()
	else:
		CutsceneManager.play(ARRIVAL_CUTSCENE_ID)

## On Chapter 4's trip (the brief sets the flag; the walk home clears it).
func _ch4_trip() -> bool:
	return GameState.get_flag(CH4_TRIP_FLAG) and GameState.get_flag("chapter4_started")

func _place_rose() -> void:
	if CutsceneManager.has_actor(ROSE_ID):
		return
	var npc: Node2D = (load(ROSE_SCENE) as PackedScene).instantiate()
	npc.position = to_local(MarkerUtil.find(self, "Trip/Rose").global_position)
	add_child(npc)
	CutsceneManager.register_actor(ROSE_ID, npc)
