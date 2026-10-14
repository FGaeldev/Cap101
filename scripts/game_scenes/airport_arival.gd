# airport_arival.gd -- root script for airport_arival.tscn (Chapter 1, scene 1.5).
# Plays the one-shot arrival cutscene on first entry only. The cutscene itself
# ends by loading airport_ourdoors.tscn, whose scene_2.gd plays scene 2.
extends Node2D

const CUTSCENE_ID: String = "chapter1_scene1_5"
## Must match the "flag" set by the cutscene's own set_flag step.
const SEEN_FLAG: String = "seen_chapter1_scene1_5"

func _ready() -> void:
	if GameState.get_flag(SEEN_FLAG):
		return
	# Hide the persistent player before the first rendered frame. Without this
	# it shows at DefaultSpawn until the cutscene's first set_visible step runs
	# (after the warp-fade wait), then hides, then reappears in the conga line.
	var player: Node2D = CutsceneManager.get_actor("player")
	if player:
		player.visible = false
	# Entry arrives via Comp_Warp -> MapManager.warp_to_scene(), which owns the
	# fade. Wait it out so the cutscene doesn't start under a half-faded screen.
	while MapManager.is_transitioning:
		await get_tree().process_frame
	CutsceneManager.play(CUTSCENE_ID)
