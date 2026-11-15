# haboean_gallery.gd -- root script for haboean_gallery.tscn, the weavers' gallery
# and loom loft. Manang Loleng and two weavers are always here.
#
# Chapter 3 runs as a chain of cutscenes, one per map; flags say how far along it
# is, so a save made partway picks it up on entry:
#   aklan_living chapter3_scene0 (morning brief) -> street -> Pastrana
#   -> chapter3_walk_to_haboean -> outdoors chapter3_arrive -> here:
#   chapter3_scene1  arrival, Loleng's welcome. The player then roams the loft
#                    until they talk to Loleng or Rose, which plays
#   chapter3_scene2  the loom (stand-in memory match) and the bookmark gift
#                    (dialogue scenes 2 and 3), then on to the cafe
#   -> haboean_cafe chapter3_scene4 -> walk home -> aklan_living chapter3_scene5.
extends Node2D

const ActorPath := preload("res://scripts/util/actor_path.gd")
const MarkerUtil := preload("res://scripts/util/marker_util.gd")
const SitAction := preload("res://scripts/cutscene_actions/sit_action.gd")

const WITH_ROSE_FLAG: String = "chapter2_with_rose"
const GOING_HABOEAN_FLAG: String = "chapter3_going_haboean"
const ROSE_SCENE: String = "res://scenes/entities/npc_Rose.tscn"
const LOLENG_SCENE: String = "res://scenes/entities/npc_Loleng.tscn"
const WEAVER_SCENE: String = "res://scenes/entities/npc_Weaver.tscn"
const ROSE_ID: String = "Rose"
const LOLENG_ID: String = "Manang Loleng"
const LOOM_CUTSCENE_ID: String = "chapter3_scene2"
const LOOM_SEEN_FLAG: String = "seen_chapter3_scene2"
const LOLENG_DONE_FLAG: String = "story_done_ch3_loleng"
## Loleng's replayable word-weaving game (habi_habi_panel.gd).
const HABI_HABI_SCENE: String = "scene_loleng_habi_habi"
## Where Rose waits while the player looks around the loft (tile 3,6).
const ROSE_WAIT_AT: Vector2 = Vector2(48, 112)
## stool name -> dialogue scene key in chapter3.json.
const WEAVERS: Dictionary = {"Loom2Stool": "scene_weaver_1", "Loom4Stool": "scene_weaver_2"}

func _ready() -> void:
	_spawn_regulars()
	if not GameState.get_flag(WITH_ROSE_FLAG) or not GameState.get_flag(GOING_HABOEAN_FLAG):
		return  # here without Rose (dev warps, later visits)
	await ActorPath.settle(get_tree())
	CutsceneManager.cutscene_finished.connect(func(_id: String): _refresh_roam())
	while CutsceneManager.is_playing():
		await get_tree().process_frame
	if not is_inside_tree():
		return
	if not GameState.get_flag("seen_chapter3_scene1"):
		CutsceneManager.play("chapter3_scene1")
	elif GameState.get_flag("seen_chapter3_scene3") and not GameState.get_flag("seen_chapter3_scene4"):
		CutsceneManager.play("chapter3_to_cafe")
	else:
		_refresh_roam()

## Loleng at her loom and two weavers at theirs, every visit.
func _spawn_regulars() -> void:
	var loleng: Node2D = (load(LOLENG_SCENE) as PackedScene).instantiate()
	loleng.position = to_local(MarkerUtil.find(self, "Staff/Weaver").global_position)
	add_child(loleng)
	CutsceneManager.register_actor(LOLENG_ID, loleng)
	_face(loleng, Vector2.UP)
	# Once her story is done, talking to her offers Habi-Habi (replays every time:
	# no story_done_flag).
	if GameState.get_flag(LOLENG_DONE_FLAG):
		loleng.dialogue_scene_key = HABI_HABI_SCENE
	for stool_name: String in WEAVERS:
		var weaver: Node2D = (load(WEAVER_SCENE) as PackedScene).instantiate()
		weaver.dialogue_scene_key = WEAVERS[stool_name]
		var stool: Node = SitAction.find_pew(self, stool_name)
		weaver.position = to_local(stool.global_position)
		add_child(weaver)
		stool.sit(weaver, 0)

## Between scene 1 and the loom, talking to Loleng or Rose starts the loom scene,
## and Rose keeps the player in the loft (TourGuide).
func _refresh_roam() -> void:
	if is_queued_for_deletion() or not is_inside_tree() or CutsceneManager.is_playing():
		return
	if not GameState.get_flag("seen_chapter3_scene1") or GameState.get_flag(LOOM_SEEN_FLAG):
		return
	if not CutsceneManager.has_actor(ROSE_ID):
		var rose: Node2D = (load(ROSE_SCENE) as PackedScene).instantiate()
		rose.position = ROSE_WAIT_AT
		add_child(rose)
		CutsceneManager.register_actor(ROSE_ID, rose)
	for actor_id: String in [ROSE_ID, LOLENG_ID]:
		var npc: Node = CutsceneManager.get_actor(actor_id)
		npc.cutscene_id = LOOM_CUTSCENE_ID
		npc.cutscene_seen_flag = LOOM_SEEN_FLAG
	TutorialManager.start("tour_roam")

func _face(npc: Node, dir: Vector2) -> void:
	var anim: Node = npc.get_node_or_null("CutsceneAnimComponent")
	if anim:
		anim.set_cutscene_anim_state("idle", dir)
