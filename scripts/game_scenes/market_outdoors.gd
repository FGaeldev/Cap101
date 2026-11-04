# market_outdoors.gd -- root script for market_outdoors.tscn, the street between
# the park and the market hall. Walks with Rose pass through here both ways:
# in from the park to the hall door, or back out (flag chapter2_leaving_market).
extends Node2D

const ActorPath := preload("res://scripts/util/actor_path.gd")

const WITH_ROSE_FLAG: String = "chapter2_with_rose"
const LEAVING_FLAG: String = "chapter2_leaving_market"
const WALK_IN_CUTSCENE_ID: String = "chapter2_walk_market_street"
const WALK_OUT_CUTSCENE_ID: String = "chapter2_walk_street_back"

func _ready() -> void:
	if not GameState.get_flag(WITH_ROSE_FLAG):
		return  # here without Rose (dev warps)
	await ActorPath.settle(get_tree())
	while CutsceneManager.is_playing():
		await get_tree().process_frame
	if is_inside_tree():
		CutsceneManager.play(WALK_OUT_CUTSCENE_ID if GameState.get_flag(LEAVING_FLAG) else WALK_IN_CUTSCENE_ID)
