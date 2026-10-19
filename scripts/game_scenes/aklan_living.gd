# aklan_living.gd -- root script for aklan_living.tscn (Chapter 2 hub: family
# home in Aklan). Plays the one-shot Chapter 2 scene 0 cutscene ("home at
# last") on first entry only: the family + player conga in through the front
# door (mirrors how Chapter 1 scene 4 walked them off the airport map), then
# Lola Susan's welcome line.
#
# Normal entry: chapter1_scene4's final load_scene step. That step runs while
# CutsceneManager is still playing scene 4, so play() here would be ignored by
# its already-playing guard -- wait until scene 4 has fully returned first.
# Other entries (MapManager warp/travel) own a fade; wait that out too.
# Screen arrives black either way; the cutscene's own fade-in step reveals it.
extends Node2D

const CUTSCENE_ID: String = "chapter2_scene0"
## Must match the "flag" set by the cutscene's own set_flag step.
const SEEN_FLAG: String = "seen_chapter2_scene0"

func _ready() -> void:
	if GameState.get_flag(SEEN_FLAG):
		return
	await get_tree().process_frame
	while CutsceneManager.is_playing() or MapManager.is_transitioning:
		await get_tree().process_frame
	# Level may be swapped out while waiting (e.g. dev warp).
	if not is_inside_tree() or GameState.get_flag(SEEN_FLAG):
		return
	CutsceneManager.play(CUTSCENE_ID)
