# haboean_outdoors.gd -- root script for habuean_outdoors.tscn. Chapter 3's trip to
# the weavers passes through here both ways, as a chain of cutscenes (see
# haboean_gallery.gd for the whole chain):
#   Out:  chapter3_walk_to_haboean (Pastrana) -> chapter3_arrive -> gallery
#   Home: cafe -> chapter3_walk_home_outdoors -> Pastrana
# Later visits (Rose's "Can we go to the weavers?" once Chapter 3 is done):
#   chapter3_walk_to_haboean -> chapter3_revisit_arrive: Rose walks the player in
#   and waits on the plaza while they visit the gallery and cafe on their own.
#   Leaving through the Pastrana gate (or 18:00) she takes them home through
#   TourGuide, which plays chapter3_revisit_home.
extends Node2D

const ActorPath := preload("res://scripts/util/actor_path.gd")

const WITH_ROSE_FLAG: String = "chapter2_with_rose"
const GOING_HABOEAN_FLAG: String = "chapter3_going_haboean"
const WALKING_HOME_FLAG: String = "chapter2_walking_home"
## Set while Rose waits on the plaza during a later visit.
const AT_HABOEAN_FLAG: String = "chapter3_at_haboean"
const STORY_DONE_FLAG: String = "seen_chapter3_scene4"
const ARRIVE_CUTSCENE_ID: String = "chapter3_arrive"
const WALK_HOME_CUTSCENE_ID: String = "chapter3_walk_home_outdoors"
const REVISIT_CUTSCENE_ID: String = "chapter3_revisit_arrive"
const ROSE_SCENE: String = "res://scenes/entities/npc_Rose.tscn"
const ROSE_ID: String = "Rose"
## Rose's waiting spot on the plaza (tile 17,15), clear of the path and doors.
const ROSE_WAIT_AT: Vector2 = Vector2(272, 256)

func _ready() -> void:
	if not GameState.get_flag(WITH_ROSE_FLAG) or not GameState.get_flag(GOING_HABOEAN_FLAG):
		return  # here without Rose (dev warps)
	await ActorPath.settle(get_tree())
	while CutsceneManager.is_playing():
		await get_tree().process_frame
	if not is_inside_tree():
		return
	if GameState.get_flag(WALKING_HOME_FLAG):
		CutsceneManager.play(WALK_HOME_CUTSCENE_ID)
	elif not GameState.get_flag("seen_chapter3_scene1"):
		CutsceneManager.play(ARRIVE_CUTSCENE_ID)
	elif GameState.get_flag(STORY_DONE_FLAG):
		if GameState.get_flag(AT_HABOEAN_FLAG):
			_place_rose()
		else:
			CutsceneManager.play(REVISIT_CUTSCENE_ID)

## Rose back at her spot when the player comes out of the gallery or cafe.
func _place_rose() -> void:
	if CutsceneManager.has_actor(ROSE_ID):
		return
	var rose: Node2D = (load(ROSE_SCENE) as PackedScene).instantiate()
	rose.position = ROSE_WAIT_AT
	add_child(rose)
	CutsceneManager.register_actor(ROSE_ID, rose)
