# bakhawan_trail.gd -- root script for bakhawan_trail.tscn: the mangrove boardwalk
# behind the visitor centre (plaza -> bakhawan_indoors -> here). Built by
# art_requests/tools/build_bakhawan_maps.gd.txt; see docs/CHAPTER4_MAP_PLAN.md.
#
# Chapter 4 "Roots of Bakhawan" (docs/CHAPTER4_PLAN.md, storyboard scenes 1-5).
# Rose, Papa Jobert and the player come through the visitor centre's back door;
# each beat plays when the player walks to the next spot. The flags say which beat
# is next, so a save made partway picks it up:
#   chapter4_arrive_gate  at the bamboo gate: Manong Ambo greets them (scene 1)
#   (player walks)        arrow at the roots platform        -> chapter4_scene2
#   (player walks)        arrow at the east end of the T-deck -> chapter4_scene3 (fishing)
#   (player walks)        arrow at the west end, by the sand  -> chapter4_scene4 (word round)
#   (player walks)        arrow at the planting spot          -> chapter4_plant
#   (player walks)        arrow by the cottage                -> chapter4_scene5 (sunset),
#                         which walks everyone home through the visitor centre
# Each cutscene walks the cast on to the next stop; _place_cast() puts anyone
# missing (after a reload) straight at the stop the flags point to.
# Any other visit: Manong Ambo waits by the gate for idle talk once he's met.
extends Node2D

const ActorPath := preload("res://scripts/util/actor_path.gd")
const MarkerUtil := preload("res://scripts/util/marker_util.gd")

const WITH_ROSE_FLAG: String = "chapter2_with_rose"
const ROSE_SCENE: String = "res://scenes/entities/npc_Rose.tscn"
const JOBERT_SCENE: String = "res://scenes/entities/npc_PapaJobert.tscn"
const AMBO_SCENE: String = "res://scenes/entities/npc_Ambo.tscn"
const INDICATOR_SCENE: String = "res://scenes/components/interactable_component.tscn"
const ROSE_ID: String = "Rose"
const JOBERT_ID: String = "Papa Jobert"
const AMBO_ID: String = "Manong Ambo"

const CH4_STARTED_FLAG: String = "chapter4_started"
const ARRIVE_CUTSCENE_ID: String = "chapter4_arrive_gate"
const AMBO_STORY_DONE_FLAG: String = "story_done_ch4_ambo"
const PLANTED_FLAG: String = "planted_mangrove"
## In order. "seen" is the flag the beat's cutscene sets; "goal" the cell the
## arrow marks; "zone" the cells that start it; "cast" where Ambo, Rose and
## Jobert wait for it (SceneMarkers/Ch4/...).
const BEATS: Array[Dictionary] = [
	{"seen": "seen_chapter4_scene2", "cutscene": "chapter4_scene2", "goal": Vector2i(10, 40),
		"zone": Rect2i(10, 38, 4, 4), "cast": {AMBO_ID: "Ch4/S2_Ambo", ROSE_ID: "Ch4/S2_Rose", JOBERT_ID: "Ch4/S2_Jobert"}},
	{"seen": "seen_chapter4_scene3", "cutscene": "chapter4_scene3", "goal": Vector2i(32, 7),
		"zone": Rect2i(31, 7, 3, 1), "cast": {AMBO_ID: "Ch4/S3_Ambo", ROSE_ID: "Ch4/S3_Rose", JOBERT_ID: "Ch4/S3_Jobert"}},
	{"seen": "seen_chapter4_scene4", "cutscene": "chapter4_scene4", "goal": Vector2i(11, 6),
		"zone": Rect2i(9, 5, 5, 4), "cast": {AMBO_ID: "Ch4/S4_Ambo", ROSE_ID: "Ch4/S4_Rose", JOBERT_ID: "Ch4/S4_Jobert"}},
	{"seen": PLANTED_FLAG, "cutscene": "chapter4_plant", "goal": Vector2i(9, 12),
		"zone": Rect2i(9, 12, 1, 1), "cast": {AMBO_ID: "Ch4/S4_Ambo", ROSE_ID: "Ch4/S4_Rose", JOBERT_ID: "Ch4/S4_Jobert"}},
	{"seen": "seen_chapter4_scene5", "cutscene": "chapter4_scene5", "goal": Vector2i(10, 3),
		"zone": Rect2i(10, 3, 1, 2), "cast": {AMBO_ID: "Ch4/S4_Ambo", ROSE_ID: "Ch4/S5_Rose", JOBERT_ID: "Ch4/S5_Jobert"}},
]

var _beat: int = -1
var _arrow: Node2D = null

func _ready() -> void:
	set_physics_process(false)
	_show_planted()
	CutsceneManager.cutscene_finished.connect(func(_id: String): _show_planted())
	if not _ch4_on():
		_place_ambo_idle()
		return
	await ActorPath.settle(get_tree())
	while CutsceneManager.is_playing():
		await get_tree().process_frame
	if not is_inside_tree():
		return
	CutsceneManager.cutscene_finished.connect(func(_id: String): _refresh())
	if not GameState.get_flag("seen_chapter4_scene1"):
		CutsceneManager.play(ARRIVE_CUTSCENE_ID)
	else:
		_place_cast()
		_refresh()

## Chapter 4's trip is on: started with Rose, and the sunset scene not played yet.
func _ch4_on() -> bool:
	return GameState.get_flag(WITH_ROSE_FLAG) and GameState.get_flag(CH4_STARTED_FLAG) \
			and not GameState.get_flag("seen_chapter4_scene5")

## The seedling the player planted stays on the shore.
func _show_planted() -> void:
	var seedling: Node = get_node_or_null("Props/PlantedSeedling")
	if seedling:
		seedling.visible = GameState.get_flag(PLANTED_FLAG)

## Index of the next beat in BEATS, or -1 once they've all played.
func _next_beat() -> int:
	for i in BEATS.size():
		if not GameState.get_flag(BEATS[i]["seen"]):
			return i
	return -1

## Shows the arrow for the next beat (after a cutscene, or on entry).
func _refresh() -> void:
	if is_queued_for_deletion() or not is_inside_tree() or CutsceneManager.is_playing():
		return
	if not _ch4_on() or not GameState.get_flag("seen_chapter4_scene1"):
		_clear_arrow()
		set_physics_process(false)
		return
	var beat: int = _next_beat()
	if beat == _beat:
		return
	_beat = beat
	_clear_arrow()
	if beat < 0:
		set_physics_process(false)
		return
	_show_arrow(BEATS[beat]["goal"])
	set_physics_process(true)

func _physics_process(_delta: float) -> void:
	if _beat < 0 or CutsceneManager.is_playing() or DialogueUI.is_active() or MapManager.is_transitioning:
		return
	var zone: Rect2i = BEATS[_beat]["zone"]
	if zone.has_point(_player_tile()):
		set_physics_process(false)
		_clear_arrow()
		var cutscene_id: String = BEATS[_beat]["cutscene"]
		_beat = -2  # until the flags change again
		CutsceneManager.play(cutscene_id)

## Puts Ambo, Rose and Jobert at the next beat's spots, unless already here.
func _place_cast() -> void:
	var beat: int = _next_beat()
	var cast: Dictionary = BEATS[beat]["cast"] if beat >= 0 else {}
	var scenes: Dictionary = {AMBO_ID: AMBO_SCENE, ROSE_ID: ROSE_SCENE, JOBERT_ID: JOBERT_SCENE}
	for actor_id: String in cast:
		_spawn(actor_id, scenes[actor_id], cast[actor_id])

## Manong Ambo by the gate for idle talk, once Chapter 4 has introduced him.
func _place_ambo_idle() -> void:
	if GameState.get_flag(AMBO_STORY_DONE_FLAG):
		_spawn(AMBO_ID, AMBO_SCENE, "Ch4/Ambo_Gate")

func _spawn(actor_id: String, scene_path: String, marker_name: String) -> void:
	if CutsceneManager.has_actor(actor_id):
		return
	var marker: Node2D = MarkerUtil.find(self, marker_name)
	if marker == null:
		push_error("bakhawan_trail: marker '%s' not found" % marker_name)
		return
	var npc: Node2D = (load(scene_path) as PackedScene).instantiate()
	npc.position = to_local(marker.global_position)
	add_child(npc)
	CutsceneManager.register_actor(actor_id, npc)

func _player_tile() -> Vector2i:
	if not CutsceneManager.has_actor("player"):
		return Vector2i(-99, -99)
	var p: Vector2 = CutsceneManager.get_actor("player").global_position - global_position
	return Vector2i(floori(p.x / 16.0), floori((p.y - 1.0) / 16.0))

## The quest-marker arrow, hovering over the goal cell (haboean_cafe.gd does the same).
func _show_arrow(tile: Vector2i) -> void:
	var component: Node = (load(INDICATOR_SCENE) as PackedScene).instantiate()
	var indicator: Node2D = component.get_node("Indicator")
	component.remove_child(indicator)
	component.free()
	indicator.position = Vector2(tile.x * 16 + 8, tile.y * 16 + 2)
	indicator.z_index = 5
	indicator.visible = true
	add_child(indicator)
	_arrow = indicator

func _clear_arrow() -> void:
	if _arrow != null and is_instance_valid(_arrow):
		_arrow.queue_free()
	_arrow = null

## Autoplay/test hook: the cell the next Chapter 4 beat wants the player on, or (-99,-99).
func walk_goal() -> Vector2i:
	return BEATS[_beat]["goal"] if _beat >= 0 and _beat < BEATS.size() else Vector2i(-99, -99)
