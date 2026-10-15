# scene_2.gd -- root script for airport_ourdoors.tscn (Chapter 1, scenes 2-3).
# Scene 2: arrival cutscene, plays once. Afterwards Lola Susan + Rose wait in
# the parking lot (quest q003). Interacting with Lola Susan completes q003 and
# plays scene 3 (chapter1_scene3 cutscene: Lola Jonabel + Papa Jobert walk in).
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

## Level-local coords, lower parking lot. Jonabel/Papa spots MUST match the
## "to" targets in data/cutscenes/chapter1_scene3.json.
const SUSAN: Dictionary = {"scene": "res://scenes/entities/npc_LolaSusan.tscn", "at": Vector2(244, 520)}
const ROSE: Dictionary = {"scene": "res://scenes/entities/npc_Rose.tscn", "at": Vector2(268, 520)}
const JONABEL: Dictionary = {"scene": "res://scenes/entities/npc_LolaJonabel.tscn", "at": Vector2(250, 492)}
const PAPA: Dictionary = {"scene": "res://scenes/entities/npc_PapaJobert.tscn", "at": Vector2(274, 492)}

## actor_id values of every NPC this script may own (for chapter-end despawn).
const LOT_ACTOR_IDS: Array[String] = ["Lola Susan", "Rose", "Lola Jonabel", "Papa Jobert"]

func _ready() -> void:
	GameState.current_area = "village"  # TODO: update once scene2 has its own area id
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

## Susan + Rose always; Jonabel + Papa only once scene 3 has played (during
## scene 3 itself the cutscene spawns them and walks them in).
func _spawn_lot_cast() -> void:
	var susan: Node2D = _spawn(SUSAN)
	susan.quest_id = FIND_QUEST_ID                 # quest marker
	susan.interact_quest_id = FIND_QUEST_ID        # completes on interact
	susan.cutscene_id = "chapter1_scene3"
	susan.cutscene_seen_flag = SCENE3_SEEN_FLAG
	susan.dialogue_scene_key = ""                  # all story lives in the cutscene
	susan.story_done_flag = STORY_DONE_FLAG

	var rose: Node2D = _spawn(ROSE)
	rose.unlock_flag = SCENE3_SEEN_FLAG            # silent until the reunion
	rose.dialogue_scene_key = ""
	rose.quest_id = PRACTICE_QUEST_ID              # quest marker
	rose.interact_quest_id = PRACTICE_QUEST_ID     # completes on interact
	rose.cutscene_id = "chapter1_scene4"
	rose.cutscene_seen_flag = SCENE4_SEEN_FLAG
	rose.story_done_flag = ROSE_STORY_DONE_FLAG

	if GameState.get_flag(SCENE3_SEEN_FLAG):
		_spawn(JONABEL)
		_spawn(PAPA)

## Instantiates + places an NPC under this (y-sorted) level root.
func _spawn(entry: Dictionary) -> Node2D:
	var npc: Node2D = (load(entry["scene"]) as PackedScene).instantiate()
	npc.position = entry["at"]
	add_child(npc)
	return npc

func _on_flag_changed(flag_name: String, value: bool) -> void:
	if flag_name == CHAPTER_DONE_FLAG and value:
		_despawn_lot_cast()

## Frees every lot NPC (incl. cutscene-spawned Jonabel/Papa) and drops their
## actor registrations so CutsceneManager holds no dangling refs.
func _despawn_lot_cast() -> void:
	for child in get_children():
		var id: Variant = child.get("actor_id")
		if id != null and id in LOT_ACTOR_IDS:
			CutsceneManager.unregister_actor(id)
			child.queue_free()
