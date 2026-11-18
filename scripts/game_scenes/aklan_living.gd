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
const LEAVE_ALONE_CUTSCENE_ID: String = "chapter2_leave_alone"
## Chapter 2 dinner after the tour (docs/CHAPTER2_PLAN.md step 5): plays once,
## in the 6-7 PM block when the family sits at the dining table (npc_schedule.json).
const TOUR_DONE_FLAG: String = "chapter2_tour_done"
const DINNER_CUTSCENE_ID: String = "chapter2_scene5"
const DINNER_SEEN_FLAG: String = "chapter2_evening_seen"
const DINNER_HOUR: int = 18
const DINNER_CAST: Array = ["Rose", "Lola Susan", "Lola Jonabel", "Papa Jobert"]
## Chapter 3 (see docs/CHAPTER3_PLAN.md): the morning brief that starts the trip
## to Haboean, and the evening scene once the player is back from the cafe.
const CH2_COMPLETE_FLAG: String = "chapter2_complete"
const CH3_BRIEF_CUTSCENE_ID: String = "chapter3_scene0"
const CH3_BRIEF_SEEN_FLAG: String = "seen_chapter3_scene0"
const CH3_CAFE_SEEN_FLAG: String = "seen_chapter3_scene4"
const CH3_EVENING_CUTSCENE_ID: String = "chapter3_scene5"
const CH3_EVENING_SEEN_FLAG: String = "seen_chapter3_scene5"
## Chapter 4 (see docs/CHAPTER4_PLAN.md): the morning brief that sends Rose, Papa
## Jobert and the player to Bakhawan, and the evening scene once they're home.
const CH3_COMPLETE_FLAG: String = "chapter3_complete"
const CH4_BRIEF_CUTSCENE_ID: String = "chapter4_scene0"
const CH4_BRIEF_SEEN_FLAG: String = "seen_chapter4_scene0"
const CH4_BRIEF_CAST: Array = ["Rose", "Lola Susan", "Lola Jonabel", "Papa Jobert"]
const CH4_SUNSET_SEEN_FLAG: String = "seen_chapter4_scene5"
const CH4_EVENING_CUTSCENE_ID: String = "chapter4_scene6"
const CH4_EVENING_SEEN_FLAG: String = "seen_chapter4_scene6"
const CH4_EVENING_CAST: Array = ["Lola Jonabel", "Lola Susan", "Papa Jobert"]

func _ready() -> void:
	# Walks with Rose never reach this door's warp: they're cutscenes, or TourGuide stops them.
	$Warps/WarpArea5.before_warp = func(): await CutsceneManager.play(LEAVE_ALONE_CUTSCENE_ID)
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
	# A walk home with Rose ends with its own cutscene (_ready); beats wait for it.
	if GameState.get_flag(WALKING_HOME_FLAG):
		return
	if not GameState.get_flag(WAKE_SEEN_FLAG):
		if NpcSchedule.is_here("Lola Susan"):
			CutsceneManager.play(WAKE_CUTSCENE_ID)
		return
	if NpcSchedule.is_mass_pending():
		GameState.set_flag(MASS_WENT_FLAG, false)  # last Sunday's answer
		CutsceneManager.play(MASS_CUTSCENE_ID)
		return
	if _dinner_due():
		CutsceneManager.play(DINNER_CUTSCENE_ID)
		return
	if _ch3_brief_due():
		CutsceneManager.play(CH3_BRIEF_CUTSCENE_ID)
		return
	if GameState.get_flag(CH3_CAFE_SEEN_FLAG) and not GameState.get_flag(CH3_EVENING_SEEN_FLAG) \
			and _all_here_and_settled(["Lola Jonabel", "Lola Susan"]):
		CutsceneManager.play(CH3_EVENING_CUTSCENE_ID)
		return
	if _ch4_brief_due():
		CutsceneManager.play(CH4_BRIEF_CUTSCENE_ID)
		return
	if GameState.get_flag(CH4_SUNSET_SEEN_FLAG) and not GameState.get_flag(CH4_EVENING_SEEN_FLAG) \
			and _all_here_and_settled(CH4_EVENING_CAST):
		CutsceneManager.play(CH4_EVENING_CUTSCENE_ID)

## Chapter 4's morning brief: the first morning after Chapter 3 is complete
## (and Chapter 4 is out), once all four are at their brief spots.
func _ch4_brief_due() -> bool:
	if GameState.get_flag(CH4_BRIEF_SEEN_FLAG) or not GameState.get_flag(CH3_COMPLETE_FLAG):
		return false
	if NpcSchedule.get_block("Rose").get("when", "") != "ch4_brief_pending":
		return false
	return _all_here_and_settled(CH4_BRIEF_CAST)

## The first evening after the tour, once all four are at the table. If the
## player is out or asleep then, it waits for the next evening.
func _dinner_due() -> bool:
	if GameState.get_flag(DINNER_SEEN_FLAG) or not GameState.get_flag(TOUR_DONE_FLAG):
		return false
	if int(DayNightManager.get_hour()) != DINNER_HOUR:
		return false
	return _all_here_and_settled(DINNER_CAST)

## Chapter 3's morning brief: the first morning after Chapter 2 is complete,
## once Rose, Susan and Jonabel are at their brief spots (npc_schedule.json).
func _ch3_brief_due() -> bool:
	if GameState.get_flag(CH3_BRIEF_SEEN_FLAG) or not GameState.get_flag(CH2_COMPLETE_FLAG):
		return false
	if NpcSchedule.get_block("Rose").get("when", "") != "ch3_brief_pending":
		return false
	return _all_here_and_settled(["Rose", "Lola Susan", "Lola Jonabel"])

func _all_here_and_settled(actor_ids: Array) -> bool:
	for actor_id: String in actor_ids:
		if not NpcSchedule.is_here(actor_id) or not NpcSchedule.is_settled(actor_id):
			return false
	return true

