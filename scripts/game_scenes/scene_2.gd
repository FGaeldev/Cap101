# scene_2.gd -- root script for airport_ourdoors.tscn (Chapter 1, scenes 2-3).
# Scene 2: arrival cutscene, plays once, walking Lola Jonabel + Papa Jobert +
# the player to their SceneMarkers/S3 spots. Lola Susan + Rose wait in the
# parking lot (quest q003). Interacting with Lola Susan completes q003 and
# plays scene 3 (chapter1_scene3: Susan, Rose and the player walk to their
# SceneMarkers/S4 spots, ready for Rose's scene 4).
# The whole lot cast despawns when the "chapter1_complete" flag is set.
extends Node2D

const SCENE2_CUTSCENE_ID: String = "chapter1_scene2"
## Set by the scene-2 cutscene's own set_flag step; also q003's requires_flag.
const SCENE2_SEEN_FLAG: String = "seen_chapter1_scene2"
## Set by the scene-3 cutscene's own set_flag step.
const SCENE3_SEEN_FLAG: String = "seen_chapter1_scene3"
## Joint story-done flag: flips every lot NPC to its idle pool. Set by the
## scene-3 cutscene.
const STORY_DONE_FLAG: String = "story_done_scene_3_reunion"
## Scene 4 (Rose vocab drill). Only Rose uses these: her idle pool starts after the drill.
const SCENE4_SEEN_FLAG: String = "seen_chapter1_scene4"
const ROSE_STORY_DONE_FLAG: String = "story_done_scene_4_rose"
## Completed by interacting with Rose (post scene 3) ONLY.
const PRACTICE_QUEST_ID: String = "q004"
## Must be set by whatever ends Chapter 1 (cutscene set_flag step, dialogue
## hook, etc). Cast despawns on the flip and never respawns afterwards.
const CHAPTER_DONE_FLAG: String = "chapter1_complete"
## Completed by interacting with Lola Susan ONLY.
const FIND_QUEST_ID: String = "q003"

const MarkerUtil := preload("res://scripts/util/marker_util.gd")

## Lot cast. Positions come from the level's SceneMarkers: "S3/<marker>" is
## where everyone stands before scene 3 (where scene 2 leaves them), and
## "S4/<marker>" before scene 4 (where scene 3 walks them). The cutscene JSON
## targets the same markers, so moving a marker in the editor moves both.
const SUSAN: Dictionary = {"scene": "res://scenes/entities/npc_LolaSusan.tscn", "actor": "Lola Susan", "marker": "Susan"}
const ROSE: Dictionary = {"scene": "res://scenes/entities/npc_Rose.tscn", "actor": "Rose", "marker": "Rose"}
const JONABEL: Dictionary = {"scene": "res://scenes/entities/npc_LolaJonabel.tscn", "actor": "Lola Jonabel", "marker": "Jonabel"}
const PAPA: Dictionary = {"scene": "res://scenes/entities/npc_PapaJobert.tscn", "actor": "Papa Jobert", "marker": "Jobert"}

## actor_id values of every NPC this script may own (for chapter-end despawn).
const LOT_ACTOR_IDS: Array[String] = ["Lola Susan", "Rose", "Lola Jonabel", "Papa Jobert"]

func _ready() -> void:
	AudioManager.play_bgm("village")     # TODO: swap if scene2 needs its own track
	FadeManager.fade_in(0.6)
	GameState.flag_changed.connect(_on_flag_changed)
	if GameState.get_flag(CHAPTER_DONE_FLAG):
		return  # chapter over: lot stays empty
	if GameState.get_flag(SCENE2_SEEN_FLAG):
		_spawn_lot_cast()
	else:
		_play_scene2_then_spawn()

## One-frame defer mirrors the old call_deferred("play"). play() is a
## coroutine, so await resumes after the cutscene's last step.
func _play_scene2_then_spawn() -> void:
	await get_tree().process_frame
	await CutsceneManager.play(SCENE2_CUTSCENE_ID)
	# Level may be freed mid-cutscene (quit-to-menu), or play() bailed early.
	if not is_inside_tree() or not GameState.get_flag(SCENE2_SEEN_FLAG):
		return
	_spawn_lot_cast()

## Whole cast, on the S3 markers until scene 3 has played, S4 after. Anyone a
## cutscene already placed (scene 2 spawns Jonabel + Papa) is left alone.
func _spawn_lot_cast() -> void:
	var group: String = "S4" if GameState.get_flag(SCENE3_SEEN_FLAG) else "S3"
	_spawn(JONABEL, group)
	_spawn(PAPA, group)

	var susan: Node2D = _spawn(SUSAN, group)
	if susan != null:
		susan.quest_id = FIND_QUEST_ID                 # quest marker
		susan.interact_quest_id = FIND_QUEST_ID        # completes on interact
		susan.cutscene_id = "chapter1_scene3"
		susan.cutscene_seen_flag = SCENE3_SEEN_FLAG
		susan.dialogue_scene_key = ""                  # all story lives in the cutscene
		susan.story_done_flag = STORY_DONE_FLAG

	var rose: Node2D = _spawn(ROSE, group)
	if rose != null:
		rose.unlock_flag = SCENE3_SEEN_FLAG            # silent until the reunion
		rose.dialogue_scene_key = ""
		rose.quest_id = PRACTICE_QUEST_ID              # quest marker
		rose.interact_quest_id = PRACTICE_QUEST_ID     # completes on interact
		rose.cutscene_id = "chapter1_scene4"
		rose.cutscene_seen_flag = SCENE4_SEEN_FLAG
		rose.story_done_flag = ROSE_STORY_DONE_FLAG

## Instantiates an NPC under this y-sorted level root at SceneMarkers/<group>/
## <marker>. Returns null without spawning if that actor is already in the
## level (placed by a cutscene) or its marker is missing.
func _spawn(entry: Dictionary, group: String) -> Node2D:
	var actor_id: String = entry["actor"]
	if CutsceneManager.has_actor(actor_id):
		return null
	var marker_ref: String = "%s/%s" % [group, entry["marker"]]
	var marker := MarkerUtil.find(self, marker_ref)
	if marker == null:
		push_error("scene_2: marker '%s' missing under SceneMarkers; '%s' not spawned" % [marker_ref, actor_id])
		return null

	var npc: Node2D = (load(entry["scene"]) as PackedScene).instantiate()
	npc.position = to_local(marker.global_position)
	add_child(npc)
	return npc

func _on_flag_changed(flag_name: String, value: bool) -> void:
	# Scene 4 sets the flag before its exit conga (the edge-exit warp aborts the
	# cutscene, skipping later steps); the conga frees the cast itself.
	if flag_name == CHAPTER_DONE_FLAG and value and not CutsceneManager.is_playing():
		_despawn_lot_cast()

## Frees every lot NPC (incl. cutscene-spawned Jonabel/Papa) and drops their
## actor registrations so CutsceneManager holds no dangling refs.
func _despawn_lot_cast() -> void:
	for child in get_children():
		var id: Variant = child.get("actor_id")
		if id != null and id in LOT_ACTOR_IDS:
			CutsceneManager.unregister_actor(id)
			child.queue_free()
