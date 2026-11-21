# us_living.gd -- root script for us_living.tscn (Chapter 1, the US home).
# The morning of the flight (slept, scene 1.5 not seen yet) Papa Jobert and
# Lola Jonabel wait by the front door with the bags. Talking to Papa plays
# chapter1_leave_home: the three of them walk out together, then the trip to
# Kalibo (airport_arival.tscn) loads. The front door stays shut until then, so
# the player never leaves on their own.
extends Node2D

const LEAVE_CUTSCENE_ID: String = "chapter1_leave_home"
const SLEPT_FLAG: String = "chapter1_slept"
## Set by chapter1_scene1_5 (the arrival in Kalibo); the room is left behind after.
const LEFT_FLAG: String = "seen_chapter1_scene1_5"
## Main quest shown and completed by talking to Papa at the door.
const LEAVE_QUEST_ID: String = "q021"

const PAPA_SCENE: String = "res://scenes/entities/npc_PapaJobert.tscn"
## Beside the front door (WarpArea2 at 32,121, two tiles wide), on the row under the rug.
const PAPA_SPOT := Vector2(48, 112)
const JONABEL_SPOT := Vector2(80, 112)

func _ready() -> void:
	if not GameState.get_flag(SLEPT_FLAG) or GameState.get_flag(LEFT_FLAG):
		return
	var door: Node = get_node_or_null("WarpArea2")
	if door != null:
		door.required_flag = LEFT_FLAG
		door.blocked_message = "Papa and Lola are waiting for me by the door."
	var jonabel: Node2D = get_node_or_null("NpcLolaJonabel")
	if jonabel != null:
		jonabel.position = JONABEL_SPOT
	if CutsceneManager.has_actor("Papa Jobert"):
		return
	var papa: Node2D = (load(PAPA_SCENE) as PackedScene).instantiate()
	papa.position = PAPA_SPOT
	papa.dialogue_chapter = "chapter1"
	papa.dialogue_scene_key = ""
	papa.quest_id = LEAVE_QUEST_ID
	papa.interact_quest_id = LEAVE_QUEST_ID
	papa.cutscene_id = LEAVE_CUTSCENE_ID
	papa.cutscene_seen_flag = "seen_chapter1_leave_home"
	add_child(papa)
