# pastrana_outdoors.gd -- root script for pastrana_outdoors.tscn. One stop of the
# walks with Rose (see aklan_home_outdoors.gd). _next_cutscene() reads the flags
# and picks the leg to play, so a save made partway picks it up on entry.
#   First trip, Rose leads and at each stop the player roams until they talk to her:
#     scene 1 at the plaza -> market (market_indoors.gd)
#     -> back here for scene 3 at the cathedral -> souvenir shop for scene 4
#     (souvenir_shop.gd) -> back here -> home.
#   Sunday mass: cathedral_indoors.gd -> market -> back here -> home.
#   Later trips: walk to the plaza; Rose then waits for the player (TourGuide).
#   Bakhawan trip: straight through this map, both ways (bakhawan_outdoors.gd).
#   Chapter 3 Haboean trip: the same, to habuean_outdoors (haboean_gallery.gd).
extends Node2D

const ActorPath := preload("res://scripts/util/actor_path.gd")

const WITH_ROSE_FLAG: String = "chapter2_with_rose"
const LEFT_HOME_FLAG: String = "chapter2_left_home"
const WALKING_HOME_FLAG: String = "chapter2_walking_home"
const FROM_MARKET_FLAG: String = "chapter2_from_market"
const MASS_TRIP_FLAG: String = "chapter2_mass_trip"
const MASS_CATHEDRAL_FLAG: String = "chapter2_mass_cathedral"
const AT_PARK_FLAG: String = "chapter2_at_park"
const TOUR_DONE_FLAG: String = "chapter2_tour_done"
const GOING_BAKHAWAN_FLAG: String = "chapter2_going_bakhawan"
## Chapter 3's trip to the weavers: straight through this map, both ways (haboean_gallery.gd).
const GOING_HABOEAN_FLAG: String = "chapter3_going_haboean"
const ARRIVED_FLAG: String = "chapter2_arrived_park"
const ARRIVED_CATHEDRAL_FLAG: String = "chapter2_arrived_cathedral"
const ROSE_SCENE: String = "res://scenes/entities/npc_Rose.tscn"
const ROSE_ID: String = "Rose"
## "Help Rose find Nong Pedring" (q022): after scene 1 he waits on the south
## sidewalk by the planters; passersby say they aren't him (npc_wanderer.gd)
## and talking to him plays chapter2_park_meet_pedring.
const PEDRING_SCENE: String = "res://scenes/entities/npc_Pedring.tscn"
const PEDRING_ID: String = "Nong Pedring"
const PEDRING_SPOT := Vector2(1008, 1200)
const FIND_PEDRING_QUEST: String = "q022"
var _pedring: Node2D = null
## Legs that need Rose already standing in the map.
const NEEDS_ROSE: Array[String] = ["chapter2_walk_home_park", "chapter2_tour_to_market", "chapter2_tour_to_souvenir"]

const MarkerUtil := preload("res://scripts/util/marker_util.gd")

func _ready() -> void:
	if not GameState.get_flag(WITH_ROSE_FLAG) or not GameState.get_flag(LEFT_HOME_FLAG):
		return  # here without Rose (dev warps)
	await ActorPath.settle(get_tree())
	# Connected only now: the cutscene that loaded this map is finishing as it loads,
	# and the next leg needs the settled collisions.
	CutsceneManager.cutscene_finished.connect(func(_id: String): _play_next())
	while CutsceneManager.is_playing():
		await get_tree().process_frame
	if not _play_next() and is_inside_tree():
		_place_rose()

## Starts the next leg. False if there's none: Rose and the player are just here.
func _play_next() -> bool:
	if is_queued_for_deletion() or not is_inside_tree() or CutsceneManager.is_playing():
		return false
	if not GameState.get_flag(WITH_ROSE_FLAG):
		return false
	var cutscene_id: String = _next_cutscene()
	if cutscene_id.is_empty():
		_place_rose()
		return false
	if NEEDS_ROSE.has(cutscene_id):
		_place_rose()
	CutsceneManager.play(cutscene_id)
	return true

func _next_cutscene() -> String:
	if GameState.get_flag(MASS_TRIP_FLAG):
		if not GameState.get_flag(MASS_CATHEDRAL_FLAG):
			return "chapter2_mass_to_cathedral"
		if not GameState.get_flag(WALKING_HOME_FLAG):
			return "chapter2_mass_to_market"
		return "chapter2_walk_home_from_market"
	if GameState.get_flag(GOING_HABOEAN_FLAG):
		return "chapter3_walk_home_from_haboean" if GameState.get_flag(WALKING_HOME_FLAG) else "chapter3_walk_to_haboean"
	if GameState.get_flag(GOING_BAKHAWAN_FLAG):
		return "chapter2_walk_home_from_bakhawan" if GameState.get_flag(WALKING_HOME_FLAG) else "chapter2_walk_to_bakhawan"
	if GameState.get_flag(WALKING_HOME_FLAG):
		return "chapter2_walk_home_from_market" if GameState.get_flag(FROM_MARKET_FLAG) else "chapter2_walk_home_park"
	if not GameState.get_flag("seen_chapter2_scene1"):
		return "" if GameState.get_flag(ARRIVED_FLAG) else "chapter2_scene1"
	if not GameState.get_flag("seen_chapter2_scene2"):
		return "chapter2_tour_to_market"
	if not GameState.get_flag("seen_chapter2_scene4"):
		if not GameState.get_flag(ARRIVED_CATHEDRAL_FLAG):
			return "chapter2_tour_to_cathedral"
		# After the cathedral talk Rose takes them into the souvenir shop for the
		# practice round (souvenir_shop.gd); until then the player roams.
		return "chapter2_tour_to_souvenir" if GameState.get_flag("seen_chapter2_scene3") else ""
	if not GameState.get_flag(TOUR_DONE_FLAG):
		# Back out of the souvenir shop: straight home.
		GameState.set_flag(TOUR_DONE_FLAG)
		TutorialManager.start("bakhawan_trip")
		return "chapter2_walk_home_souvenir"
	if GameState.get_flag(FROM_MARKET_FLAG):
		return "chapter2_walk_gate_to_park"
	return "" if GameState.get_flag(AT_PARK_FLAG) else "chapter2_walk_to_park"

## Rose waiting at her spot, unless she's already here.
func _place_rose() -> void:
	if not CutsceneManager.has_actor(ROSE_ID):
		var at_cathedral: bool = GameState.get_flag("seen_chapter2_scene2") and not GameState.get_flag("seen_chapter2_scene4")
		var npc: Node2D = (load(ROSE_SCENE) as PackedScene).instantiate()
		npc.position = to_local(MarkerUtil.find(self, "S3/Rose" if at_cathedral else "S1/Rose").global_position)
		add_child(npc)
		CutsceneManager.register_actor(ROSE_ID, npc)
	_set_rose_resume()

## Lola Susan and Lola Jonabel wait in front of the cathedral for the
## cathedral talk (chapter2_tour_to_cathedral spawns them on arrival; this puts
## them back after the player roams off and returns, and covers older saves).
const LOLAS: Array = [
	["Lola Susan", "res://scenes/entities/npc_LolaSusan.tscn", "S3/Susan", "right"],
	["Lola Jonabel", "res://scenes/entities/npc_LolaJonabel.tscn", "S3/Jonabel", "left"],
]

func _place_lolas() -> void:
	for lola: Array in LOLAS:
		if CutsceneManager.has_actor(lola[0]):
			continue
		var npc: Node2D = (load(lola[1]) as PackedScene).instantiate()
		npc.position = to_local(MarkerUtil.find(self, lola[2]).global_position)
		add_child(npc)
		CutsceneManager.register_actor(lola[0], npc)
		var anim = npc.get_node_or_null("CutsceneAnimComponent")
		if anim:
			anim.set_cutscene_anim_state("idle", Vector2.RIGHT if lola[3] == "right" else Vector2.LEFT)

## Nong Pedring, somewhere in the park for the player to find (q022).
func _place_pedring() -> void:
	# Registration is deferred, so has_actor() misses one placed this frame.
	if is_instance_valid(_pedring) or CutsceneManager.has_actor(PEDRING_ID):
		return
	var npc: Node2D = (load(PEDRING_SCENE) as PackedScene).instantiate()
	npc.position = PEDRING_SPOT
	npc.quest_id = FIND_PEDRING_QUEST
	npc.interact_quest_id = FIND_PEDRING_QUEST
	npc.cutscene_id = "chapter2_park_meet_pedring"
	npc.cutscene_seen_flag = "seen_chapter2_scene1"
	add_child(npc)
	_pedring = npc

## While the player roams a stop of the first trip, talking to Rose continues it.
func _set_rose_resume() -> void:
	var rose: Node = CutsceneManager.get_actor(ROSE_ID)
	if GameState.get_flag(ARRIVED_FLAG) and not GameState.get_flag("seen_chapter2_scene1"):
		# Rose waits; the player goes looking for Nong Pedring.
		rose.cutscene_id = ""
		_place_pedring()
	elif GameState.get_flag(ARRIVED_CATHEDRAL_FLAG) and not GameState.get_flag("seen_chapter2_scene4"):
		if not GameState.get_flag("seen_chapter2_scene3"):
			_place_lolas()
		rose.cutscene_id = "chapter2_cathedral_talk"
		TutorialManager.start("tour_roam")
		rose.cutscene_seen_flag = "seen_chapter2_scene3"
	else:
		rose.cutscene_id = ""
