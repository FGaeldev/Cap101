# cathedral_indoors.gd -- root script for cathedral_indoors.tscn. One stop of Sunday
# mass (see pastrana_outdoors.gd): the family walks up the aisle, hears mass, and
# walks back out. Runs on any entry during the trip until mass is over, so a save
# made partway picks it up.
extends Node2D

const ActorPath := preload("res://scripts/util/actor_path.gd")

const MASS_TRIP_FLAG: String = "chapter2_mass_trip"
## Set by the cutscene once mass is over.
const DONE_FLAG: String = "chapter2_mass_cathedral"
const CUTSCENE_ID: String = "chapter2_mass_service"

func _ready() -> void:
	if not GameState.get_flag(MASS_TRIP_FLAG) or GameState.get_flag(DONE_FLAG):
		return
	await ActorPath.settle(get_tree())
	while CutsceneManager.is_playing():
		await get_tree().process_frame
	if is_inside_tree():
		CutsceneManager.play(CUTSCENE_ID)
