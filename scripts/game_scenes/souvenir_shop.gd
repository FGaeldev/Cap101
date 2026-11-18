# souvenir_shop.gd -- root script for souvenir_shop.tscn. One stop of the first
# trip with Rose (see pastrana_outdoors.gd): after the cathedral talk she leads the
# player in here for the scene 4 practice round, then out to Pastrana and home.
# _next_cutscene() reads the flags, so a save made partway picks it up on entry.
extends Node2D

const ActorPath := preload("res://scripts/util/actor_path.gd")
const MarkerUtil := preload("res://scripts/util/marker_util.gd")

const WITH_ROSE_FLAG: String = "chapter2_with_rose"
const ROSE_SCENE: String = "res://scenes/entities/npc_Rose.tscn"
const ROSE_ID: String = "Rose"

func _ready() -> void:
	if not GameState.get_flag(WITH_ROSE_FLAG):
		return  # here on their own, or a dev warp
	await ActorPath.settle(get_tree())
	CutsceneManager.cutscene_finished.connect(func(_id: String): _play_next())
	while CutsceneManager.is_playing():
		await get_tree().process_frame
	_play_next()

func _play_next() -> bool:
	if is_queued_for_deletion() or not is_inside_tree() or CutsceneManager.is_playing():
		return false
	if not GameState.get_flag(WITH_ROSE_FLAG):
		return false
	var cutscene_id: String = _next_cutscene()
	if cutscene_id.is_empty():
		return false
	if cutscene_id == "chapter2_tour_leave_souvenir":
		_place_rose()
	CutsceneManager.play(cutscene_id)
	return true

func _next_cutscene() -> String:
	if GameState.get_flag("chapter2_tour_done") or GameState.get_flag("chapter2_walking_home"):
		return ""
	if not GameState.get_flag("seen_chapter2_scene4"):
		return "chapter2_souvenir_practice"
	return "chapter2_tour_leave_souvenir"

## Rose by the shelves, unless she's already here (a save made after the practice).
func _place_rose() -> void:
	if CutsceneManager.has_actor(ROSE_ID):
		return
	var npc: Node2D = (load(ROSE_SCENE) as PackedScene).instantiate()
	npc.position = to_local(MarkerUtil.find(self, "S4/Rose").global_position)
	add_child(npc)
	CutsceneManager.register_actor(ROSE_ID, npc)
