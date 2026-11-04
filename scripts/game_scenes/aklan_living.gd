# aklan_living.gd -- root script for aklan_living.tscn (Chapter 2 hub: family
# home in Aklan). Plays this room's story beats when they come due:
#   chapter2_scene0       one-shot "home at last": the family + player conga in
#                         through the front door, then Lola Susan sends everyone
#                         to bed.
#   chapter2_scene0b      one-shot, first time here after sleeping: Lola Susan
#                         says to ask Rose before looking around. Finishes scene
#                         0 and opens the front door.
#   chapter2_sunday_mass  each Sunday morning: Susan and Rose invite the player
#                         to mass and the market. Saying yes starts the walk
#                         (see pastrana_outdoors.gd).
#
# Normal entry: the player walks into airport_ourdoors' EdgeExit_Ch2 warp after
# chapter1_scene4 (MapManager.warp_to_scene). The level loads mid-warp while
# the screen is still black, so scene 0 starts right away instead of waiting
# for the warp's fade-in -- waiting would show the empty room first, then the
# cutscene's own fade-in would snap back to black. Its fade-in and the warp's
# overlap, so the reveal reads as one fade.
# Still waits for any playing cutscene: play() ignores calls while one runs.
extends Node2D

const ActorPath := preload("res://scripts/util/actor_path.gd")

const CUTSCENE_ID: String = "chapter2_scene0"
## Must match the "flag" set by the cutscene's own set_flag step.
const SEEN_FLAG: String = "seen_chapter2_scene0"
const WAKE_CUTSCENE_ID: String = "chapter2_scene0b"
const WAKE_SEEN_FLAG: String = "seen_chapter2_scene0b"
const SLEPT_FLAG: String = "chapter2_slept"
const MASS_CUTSCENE_ID: String = "chapter2_sunday_mass"
## Set by the "I'll come" branch of the mass dialogue.
const MASS_WENT_FLAG: String = "chapter2_mass_went"
const MASS_WALK_CUTSCENE_ID: String = "chapter2_mass_walk_living"
## Walks with Rose that pass through this room (see aklan_home_outdoors.gd).
const WITH_ROSE_FLAG: String = "chapter2_with_rose"
const LEFT_HOUSE_FLAG: String = "chapter2_left_house"
const WALKING_HOME_FLAG: String = "chapter2_walking_home"
const WALK_OUT_CUTSCENE_ID: String = "chapter2_walk_living"
const WALK_HOME_CUTSCENE_ID: String = "chapter2_walk_home_living"

func _ready() -> void:
	DayNightManager.hour_changed.connect(func(_hour: int): _check_beats())
	CutsceneManager.cutscene_finished.connect(_on_cutscene_finished)
	NpcSchedule.npc_arrived.connect(func(_actor_id: String): _check_beats())
	await ActorPath.settle(get_tree())
	while CutsceneManager.is_playing():
		await get_tree().process_frame
	# Level may be swapped out while waiting (e.g. dev warp).
	if not is_inside_tree():
		return
	if not GameState.get_flag(SEEN_FLAG):
		CutsceneManager.play(CUTSCENE_ID)
		return
	if GameState.get_flag(WALKING_HOME_FLAG):
		CutsceneManager.play(WALK_HOME_CUTSCENE_ID)
		return
	if GameState.get_flag(WITH_ROSE_FLAG) and not GameState.get_flag(LEFT_HOUSE_FLAG):
		CutsceneManager.play(WALK_OUT_CUTSCENE_ID)
		return
	_check_beats()

func _on_cutscene_finished(cutscene_id: String) -> void:
	if cutscene_id == MASS_CUTSCENE_ID:
		GameState.mass_invite_date = GameState.date_unix
		if GameState.get_flag(MASS_WENT_FLAG):
			CutsceneManager.play(MASS_WALK_CUTSCENE_ID)
		else:
			NpcSchedule.sync()  # Susan and Rose head out without the player
		return
	_check_beats()

## Plays whichever beat is due. Waits out a warp's fade so the line doesn't
## appear over a half-faded screen; NPCs are already placed by then.
func _check_beats() -> void:
	while MapManager.is_transitioning:
		await get_tree().process_frame
	if not is_inside_tree() or CutsceneManager.is_playing() or DialogueUI.is_active():
		return
	if not GameState.get_flag(SEEN_FLAG) or not GameState.get_flag(SLEPT_FLAG):
		return
	if not GameState.get_flag(WAKE_SEEN_FLAG):
		if NpcSchedule.is_here("Lola Susan"):
			CutsceneManager.play(WAKE_CUTSCENE_ID)
		return
	if NpcSchedule.is_mass_pending():
		GameState.set_flag(MASS_WENT_FLAG, false)  # last Sunday's answer
		CutsceneManager.play(MASS_CUTSCENE_ID)

