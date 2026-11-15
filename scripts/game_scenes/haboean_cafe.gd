# haboean_cafe.gd -- root script for haboean_cafe.tscn. A barista works the
# counter on every visit. On Chapter 3's story visit (after the loom) Rose's
# verbs-over-coffee round plays here, with the directions walk in the middle
# (storyboard 4.4a-g). See haboean_gallery.gd for the whole chapter chain.
#
#   chapter3_scene4          sit down, verbs, the direction words, then Rose's
#                            leg 1 instruction in Akeanon -> flag ch3_cafe_leg1
#   (player walks)           arrow over the counter; straight up, then right
#   chapter3_scene4_counter  the barista serves, bakae/baligya, Rose's leg 2
#                            instruction -> flag ch3_cafe_leg2
#   (player walks)           arrow over the table; left, then straight down
#   chapter3_scene4_table    sit, the rest of the round, then the walk home
#
# While a leg is on, a wrong turn makes Rose call out the English once, and
# talking to her repeats it (her resume cutscene, see TourGuide). A save made
# mid-leg picks the leg up again on entry.
extends Node2D

const ActorPath := preload("res://scripts/util/actor_path.gd")
const SitAction := preload("res://scripts/cutscene_actions/sit_action.gd")

const WITH_ROSE_FLAG: String = "chapter2_with_rose"
const GOING_HABOEAN_FLAG: String = "chapter3_going_haboean"
const STORY_SEEN_FLAG: String = "seen_chapter3_scene4"
const LEG1_FLAG: String = "ch3_cafe_leg1"
const LEG2_FLAG: String = "ch3_cafe_leg2"
const CAFE_CUTSCENE_ID: String = "chapter3_scene4"
const ROSE_SCENE: String = "res://scenes/entities/npc_Rose.tscn"
const BARISTA_SCENE: String = "res://scenes/entities/npc_Weaver.tscn"
const INDICATOR_SCENE: String = "res://scenes/components/interactable_component.tscn"
const ROSE_ID: String = "Rose"
const BARISTA_ID: String = "Barista"
## Behind the counter, between its two bars (tile 4,3).
const BARISTA_AT: Vector2 = Vector2(64, 64)
## leg -> target tile, cutscene played on arrival, hint cutscene.
const LEGS: Dictionary = {
	1: {"tile": Vector2i(4, 5), "arrive": "chapter3_scene4_counter", "hint": "chapter3_cafe_leg1_hint"},
	2: {"tile": Vector2i(0, 8), "arrive": "chapter3_scene4_table", "hint": "chapter3_cafe_leg2_hint"},
}
## Tiles further from the target than where the leg started before Rose calls out.
const WRONG_WAY_SLACK: int = 2

var _leg: int = 0
var _start_distance: int = 0
var _warned: bool = false
var _arrow: Node2D = null

func _ready() -> void:
	_spawn_barista()
	set_physics_process(false)
	if not GameState.get_flag(WITH_ROSE_FLAG) or not GameState.get_flag(GOING_HABOEAN_FLAG):
		return  # here alone, or a later visit
	if not GameState.get_flag("seen_chapter3_scene3") or GameState.get_flag(STORY_SEEN_FLAG):
		return
	await ActorPath.settle(get_tree())
	CutsceneManager.cutscene_finished.connect(func(_id: String): _refresh())
	while CutsceneManager.is_playing():
		await get_tree().process_frame
	if not is_inside_tree():
		return
	if _current_leg() == 0:
		CutsceneManager.play(CAFE_CUTSCENE_ID)
	else:
		_seat_rose()
		_refresh()

func _spawn_barista() -> void:
	var barista: Node2D = (load(BARISTA_SCENE) as PackedScene).instantiate()
	barista.npc_id = BARISTA_ID
	barista.actor_id = BARISTA_ID
	barista.dialogue_scene_key = "scene_cafe_barista"
	barista.position = BARISTA_AT
	add_child(barista)
	CutsceneManager.register_actor(BARISTA_ID, barista)

func _current_leg() -> int:
	if GameState.get_flag(LEG1_FLAG):
		return 1
	if GameState.get_flag(LEG2_FLAG):
		return 2
	return 0

## Starts the leg the flags say is on (after a cutscene, or on entry).
func _refresh() -> void:
	if is_queued_for_deletion() or not is_inside_tree() or CutsceneManager.is_playing():
		return
	var leg: int = _current_leg()
	if leg == _leg:
		return
	_leg = leg
	_clear_arrow()
	if leg == 0 or GameState.get_flag(STORY_SEEN_FLAG):
		set_physics_process(false)
		return
	var target: Vector2i = LEGS[leg]["tile"]
	_start_distance = _distance(_player_tile(), target)
	_warned = false
	_show_arrow(target)
	if CutsceneManager.has_actor(ROSE_ID):
		var rose: Node = CutsceneManager.get_actor(ROSE_ID)
		rose.cutscene_id = LEGS[leg]["hint"]
		rose.cutscene_seen_flag = STORY_SEEN_FLAG
	set_physics_process(true)

func _physics_process(_delta: float) -> void:
	if _leg == 0 or CutsceneManager.is_playing() or DialogueUI.is_active() or MapManager.is_transitioning:
		return
	var here: Vector2i = _player_tile()
	var target: Vector2i = LEGS[_leg]["tile"]
	if here == target:
		set_physics_process(false)
		_clear_arrow()
		var arrive: String = LEGS[_leg]["arrive"]
		_leg = -1  # until the flags change again
		CutsceneManager.play(arrive)
		return
	if not _warned and _distance(here, target) > _start_distance + WRONG_WAY_SLACK:
		_warned = true
		CutsceneManager.play(LEGS[_leg]["hint"])

## On a reload mid-leg: Rose back in her chair.
func _seat_rose() -> void:
	if CutsceneManager.has_actor(ROSE_ID):
		return
	var rose: Node2D = (load(ROSE_SCENE) as PackedScene).instantiate()
	add_child(rose)
	CutsceneManager.register_actor(ROSE_ID, rose)
	SitAction.find_pew(self, "Table1Right").sit(rose, 0)

func _player_tile() -> Vector2i:
	if not CutsceneManager.has_actor("player"):
		return Vector2i(-99, -99)
	var p: Vector2 = CutsceneManager.get_actor("player").global_position - global_position
	return Vector2i(floori(p.x / 16.0), floori((p.y - 1.0) / 16.0))

func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

## The quest-marker arrow, hovering over the target tile.
func _show_arrow(tile: Vector2i) -> void:
	var component: Node = (load(INDICATOR_SCENE) as PackedScene).instantiate()
	var indicator: Node2D = component.get_node("Indicator")
	component.remove_child(indicator)
	component.free()
	# On the target tile itself, not above it: above the counter it would sit
	# under the HUD's quest tracker in the top-left corner.
	indicator.position = Vector2(tile.x * 16 + 8, tile.y * 16 + 2)
	indicator.z_index = 5
	indicator.visible = true
	add_child(indicator)
	_arrow = indicator

func _clear_arrow() -> void:
	if _arrow != null and is_instance_valid(_arrow):
		_arrow.queue_free()
	_arrow = null

## Autoplay/test hook: where the current leg wants the player, or (-99,-99).
func walk_goal() -> Vector2i:
	return LEGS[_leg]["tile"] if LEGS.has(_leg) else Vector2i(-99, -99)
