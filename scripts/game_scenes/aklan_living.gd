# aklan_living.gd -- root script for aklan_living.tscn (Chapter 2 hub: family
# home in Aklan). Plays the one-shot Chapter 2 scene 0 cutscene ("home at
# last") on first entry only: the family + player conga in through the front
# door (mirrors how Chapter 1 scene 4 walked them off the airport map), then
# Lola Susan's welcome line.
#
# Normal entry: the player walks into airport_ourdoors' EdgeExit_Ch2 warp after
# chapter1_scene4 (MapManager.warp_to_scene). The level loads mid-warp while
# the screen is still black, so the cutscene starts right away instead of
# waiting for the warp's fade-in -- waiting would show the empty room first,
# then the cutscene's own fade-in would snap back to black. Its fade-in and
# the warp's overlap, so the reveal reads as one fade.
# Still waits for any playing cutscene: play() ignores calls while one runs.
extends Node2D

const CUTSCENE_ID: String = "chapter2_scene0"
## Must match the "flag" set by the cutscene's own set_flag step.
const SEEN_FLAG: String = "seen_chapter2_scene0"

func _ready() -> void:
	if GameState.get_flag(SEEN_FLAG):
		return
	await get_tree().process_frame
	while CutsceneManager.is_playing():
		await get_tree().process_frame
	# Level may be swapped out while waiting (e.g. dev warp).
	if not is_inside_tree() or GameState.get_flag(SEEN_FLAG):
		return
	CutsceneManager.play(CUTSCENE_ID)
