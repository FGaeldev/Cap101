# haboean_cafe.gd -- root script for haboean_cafe.tscn. Chapter 3 scene 4 (Rose's
# verbs-over-coffee round) plays here after the loom, then the walk home starts.
# See haboean_gallery.gd for the whole chain.
extends Node2D

const ActorPath := preload("res://scripts/util/actor_path.gd")

const WITH_ROSE_FLAG: String = "chapter2_with_rose"
const GOING_HABOEAN_FLAG: String = "chapter3_going_haboean"
const CAFE_CUTSCENE_ID: String = "chapter3_scene4"

func _ready() -> void:
	if not GameState.get_flag(WITH_ROSE_FLAG) or not GameState.get_flag(GOING_HABOEAN_FLAG):
		return  # here without Rose (dev warps, later visits)
	if not GameState.get_flag("seen_chapter3_scene3") or GameState.get_flag("seen_chapter3_scene4"):
		return
	await ActorPath.settle(get_tree())
	while CutsceneManager.is_playing():
		await get_tree().process_frame
	if is_inside_tree():
		CutsceneManager.play(CAFE_CUTSCENE_ID)
