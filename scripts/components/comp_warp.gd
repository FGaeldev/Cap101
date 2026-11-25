@tool
extends Area2D
class_name Comp_Warp
## Comp_Warp.gd
## Door/warp trigger component. Attach to an Area2D covering a doorway tile;
## on player entry, warps the persistent Player (see Game.gd) to
## target_scene, positioned at the Marker2D named target_spawn_id in that
## scene.
##
## Editor-settable per door instance (target_scene / target_spawn_id) — no
## central JSON registry, matches the "set it in editor, per-door" decision.
## Actual scene-swap work is delegated to MapManager.warp_to_scene(), which
## reuses the same abort/fade/save/load_level sequence as node-map region
## travel (MapManager.travel_to_region) — keeps CutsceneManager softlock
## safety (TDD §9 item 8) and save consistency identical across both warp
## paths instead of duplicating that sequence here.

## Direction the player must be walking to trigger this door. Player movement
## is grid-tweened (walk_state.gd) so CharacterBody2D.velocity is always zero;
## trigger is read from Player.get_input_dir() instead.
## LEFT/RIGHT (appended -- existing UP=0/DOWN=1 values in saved .tscn files
## keep their meaning) turn the area into a side exit, e.g. walking off a map
## edge. Side exits lay the detection shape out vertically (see _refresh_shape).
enum TriggerDirection { UP, DOWN, LEFT, RIGHT }

## Input vector that fires each TriggerDirection.
const TRIGGER_VECTORS: Dictionary = {
	TriggerDirection.UP: Vector2.UP,
	TriggerDirection.DOWN: Vector2.DOWN,
	TriggerDirection.LEFT: Vector2.LEFT,
	TriggerDirection.RIGHT: Vector2.RIGHT,
}

## Door width in tiles. Drives detection width: ONE = 16px, TWO = 32px.
enum DoorWidth { ONE = 1, TWO = 2 }

const UNIT_WIDTH_PX: float = 16.0
const NO_TARGET_MESSAGE: String = "I don't need to go that way right now."

## Walk direction that fires the warp. Set per door instance in the editor.
## Changing it re-lays the shape (UP/DOWN = horizontal span, LEFT/RIGHT = vertical).
@export var trigger_direction: TriggerDirection = TriggerDirection.UP:
	set(value):
		trigger_direction = value
		_refresh_shape()

## 1 or 2 tiles wide. Resizes this node's CollisionShape2D width live in the
## editor (height and position untouched). Door art is the parent Sprite2D's
## texture, set per instance in the Inspector.
@export var door_width: DoorWidth = DoorWidth.ONE:
	set(value):
		door_width = value
		_refresh_shape()

## Overrides door_width when > 0. For openings wider than a door, e.g. a
## 6-tile road leaving the map edge. 0 = use door_width (default, all doors).
@export_range(0, 32) var span_tiles_override: int = 0:
	set(value):
		span_tiles_override = value
		_refresh_shape()

## How the player goes through (v0.1.19 playtest: walking into doors kept
## bouncing players in and out; back to walking in with the D-pad). BUTTON:
## stand on the door and press the interact button (HUD button, E, or tap the
## door). WALK: walk into it while holding the trigger direction. AUTO: WALK.
enum Entry { AUTO, BUTTON, WALK }
@export var entry: Entry = Entry.AUTO

const OpeningHours := preload("res://scripts/util/opening_hours.gd")
const Objective := preload("res://scripts/util/objective.gd")
const InteractableScene := preload("res://scenes/components/interactable_component.tscn")
## Extra reach (px) around the door for the interact box, so standing on the
## door tile or just in front of it both work.
const BUTTON_REACH: float = 6.0

## Seconds the player must keep holding the trigger direction, when they step
## onto the door already pressing it, before the door fires.
@export_range(0.0, 2.0, 0.05) var hold_delay: float = 0.5

## Absolute res:// path to the destination scene, e.g.
## "res://scenes/world/us_living.tscn".
@export var target_scene: String

## Name of the Marker2D in the destination scene to spawn the Player at.
## Falls back to "DefaultSpawn" if left blank or not found there.
@export var target_spawn_id: String = "DefaultSpawn"

## In-game minutes that pass while travelling through this warp (the
## day/night clock jumps forward during the fade). 0 = instant (doors).
## E.g. 30 for a jeepney ride across town, 240 for a long road trip.
@export_range(0, 4320, 5) var travel_minutes: int = 0

## Hour the trip always lands at (e.g. 8.75 = 8:45 AM). travel_minutes then
## becomes the minimum trip length, extended to the next time the clock reads
## this hour. -1 = no fixed arrival (default): land after exactly travel_minutes.
@export_range(-1.0, 23.75, 0.25) var arrival_hour: float = -1.0

## Optional GameState flag that must be true before this warp works (e.g.
## "chapter1_slept" keeps the airport door shut until the night before the flight).
## Empty = always open (default, most doors). Bypassed in GameState.dev_mode.
@export var required_flag: String = ""

## One-line player remark shown when the warp is blocked by required_flag.
@export var blocked_message: String = "I should finish what I'm doing here first."

## A door to a place that isn't built (or isn't open) yet: with target_scene
## empty, it acts as a wall and the player says this. Setting it marks the
## door as closed on purpose (the playtest checker then stops flagging it).
## Empty = NO_TARGET_MESSAGE.
@export var closed_message: String = ""

## Hour from which this warp is closed until 6 AM (e.g. 20.0: no going out
## alone at night). -1 = never closes (default). Dev mode ignores it.
@export_range(-1.0, 23.75, 0.25) var curfew_hour: float = -1.0
const CURFEW_END_HOUR: float = 6.0
## Player remark shown when the curfew closes the warp.
@export var curfew_message: String = "It's late. I should stay home."

## A door into a shop or public building (opening_hours.gd) shuts at night.
## True keeps this one open anyway (the "unless stated otherwise").
@export var ignore_closing_time: bool = false

## Fire as soon as a cutscene walks the player onto this area (no input needed),
## e.g. Ch1 scene 4's exit conga carrying the player off the map edge. Still
## honours required_flag (silently: no blocked message mid-cutscene). The warp
## aborts the running cutscene, so any steps after the walk are skipped.
@export var fire_during_cutscene: bool = false

## Awaited right before the warp, once the door is known to be open. Levels set
## this for a door that needs a beat first, e.g. a goodbye at the front door.
var before_warp: Callable

var _blocked_dialogue_active: bool = false

## Player currently overlapping this area, null if none.
var _player: Node = null
## True once this overlap already fired (warp or blocked message). Re-armed on
## exit so a blocked door does not spam its message while the player stands in it.
var _fired: bool = false
## True once the player has released the trigger direction inside the area.
var _armed: bool = false
## Seconds the trigger direction has been held since entering (held-through path).
var _hold_time: float = 0.0
## Player arrived inside this area by a warp (spawned on it): no held-through
## firing until they let go, so holding a direction can't bounce them back.
var _arrived_inside: bool = false
## BUTTON doors: the interact box over the door (_add_interactable).
var _door_ic: InteractableComponent = null

## True when this warp opens with the interact button (see entry).
## AUTO is walk-in again for every door (2026-11-20: with the D-pad, stepping
## into a door no longer bounces players; the arrived-inside and hold_delay
## guards below still stop an instant bounce back).
func uses_button() -> bool:
	return entry == Entry.BUTTON

func _ready() -> void:
	_refresh_shape()
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if uses_button():
		_add_interactable.call_deferred()

## Polls while a player overlaps. Two ways to fire:
## 1) Fresh press: door saw the player NOT pressing the trigger direction
##    after entering (_armed), then they press it -> fires immediately.
## 2) Held through: player entered still pressing it -> fires once the key has
##    been held continuously for hold_delay seconds.
## Reads input, not Walk state, because a wall behind the door blocks the step
## and Walk never starts.
func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_update_door_facing()
	if Engine.is_editor_hint() or _player == null or _fired:
		return
	if fire_during_cutscene and CutsceneManager.is_playing():
		if required_flag.is_empty() or GameState.dev_mode or GameState.get_flag(required_flag):
			_fire(_player)
		return
	if uses_button():
		return  # opened by the interact button instead (_on_interacted)
	var want: Vector2 = TRIGGER_VECTORS[trigger_direction]
	if _player.get_input_dir() != want:
		_armed = true
		_arrived_inside = false
		_hold_time = 0.0
		return
	if _armed:
		_fire(_player)
		return
	if _arrived_inside:
		return
	_hold_time += delta
	if _hold_time >= hold_delay:
		_fire(_player)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_player = body
	_armed = false
	_hold_time = 0.0
	_arrived_inside = MapManager.is_transitioning

func _on_body_exited(body: Node) -> void:
	if body == _player:
		_player = null
		_fired = false
		_armed = false
		_hold_time = 0.0

## Resizes detection span from door_width / span_tiles_override. Fresh
## RectangleShape2D per door: door.tscn's sub-resource is shared across
## instances, so mutating it in place would resize every door.
## UP/DOWN: span along X, depth along Y. LEFT/RIGHT: span along Y, depth along X.
## Depth is read back from the current shape's short side so switching
## direction in the editor keeps the authored depth.
func _refresh_shape() -> void:
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col == null:
		return
	var depth: float = 12.0
	if col.shape is RectangleShape2D:
		var old_size: Vector2 = (col.shape as RectangleShape2D).size
		depth = min(old_size.x, old_size.y)
	var tiles: int = span_tiles_override if span_tiles_override > 0 else int(door_width)
	var span: float = UNIT_WIDTH_PX * float(tiles)
	var rect := RectangleShape2D.new()
	if trigger_direction == TriggerDirection.LEFT or trigger_direction == TriggerDirection.RIGHT:
		rect.size = Vector2(depth, span)
	else:
		rect.size = Vector2(span, depth)
	col.shape = rect

func _fire(body: Node) -> void:
	# Ignore overlaps caused by the level swap itself: Game.load_level() reparents
	# the persistent Player into the new level at its OLD position for a frame
	# (both doors share coordinates), before _place_player_at_spawn() moves it.
	# warp_to_scene() already ignored these via the same flag; the blocked-door
	# path below must too, or the message + step-back fire on scene load.
	if MapManager.is_transitioning:
		return
	_fired = true
	if TourGuide.intercept(self, body):
		return
	# The door a "go there yourself" goal leads to (objective.gd) is always open.
	var is_goal: bool = Objective.is_target_warp(self)
	if not is_goal and not required_flag.is_empty() and not GameState.dev_mode and not GameState.get_flag(required_flag):
		_show_blocked_message(body)
		return
	if _curfew_closed():
		_show_blocked_message(body, curfew_message)
		return
	if not is_goal and not ignore_closing_time and OpeningHours.is_establishment(target_scene) and OpeningHours.is_closed_now():
		_show_blocked_message(body, OpeningHours.CLOSED_MESSAGE)
		return
	# Doors whose destination isn't built yet act as a wall with a remark
	# instead of silently doing nothing.
	if target_scene.is_empty():
		_show_blocked_message(body, closed_message if not closed_message.is_empty() else NO_TARGET_MESSAGE)
		return
	if before_warp.is_valid():
		await before_warp.call()
		if not is_inside_tree():
			return
	var minutes: float = travel_minutes
	if arrival_hour >= 0.0:
		minutes = DayNightManager.minutes_until_arrival(travel_minutes, arrival_hour)
	MapManager.warp_to_scene(target_scene, target_spawn_id, minutes)

## Reuses the normal dialogue pipeline (tap to dismiss) via a throwaway
## DialogueComponent, same approach as us_bedroom.gd's opening line.
func _show_blocked_message(player, message: String = "") -> void:
	if _blocked_dialogue_active or CutsceneManager.is_playing():
		return
	_blocked_dialogue_active = true
	var dialogue := DialogueComponent.new()
	dialogue.dialogue_lines = [{"speaker": "Player", "text": message if not message.is_empty() else blocked_message, "next": null}]
	add_child(dialogue)
	dialogue.dialogue_ended.connect(func():
		_blocked_dialogue_active = false
		dialogue.queue_free())
	dialogue.start_dialogue()
	# After start_dialogue(): dialogue is now active, so player input is
	# already locked (Player.get_input_dir) and can't fight the step-back tween.
	_walk_player_back(player)

## True while curfew_hour closes this warp (from curfew_hour until 6 AM).
func _curfew_closed() -> bool:
	if curfew_hour < 0.0 or GameState.dev_mode:
		return false
	var hour: float = DayNightManager.get_hour()
	return hour >= curfew_hour or hour < CURFEW_END_HOUR

## Walks the player one tile back the way they came (opposite of facing),
## keeping their facing, so they don't stand inside the blocked doorway.
## Uses Player's own tile_size/step_time/facing_vec so it matches normal steps.
func _walk_player_back(player) -> void:
	# Idle's enter() -> Walk's exit() kills the in-flight step and snaps to grid.
	player.state_machine.transition_to("Idle")
	var back: Vector2 = -player.facing_vec
	var target: Vector2 = player.global_position + back * player.tile_size
	player.sprite.play("walk_" + player.direction)
	var tween := create_tween()
	tween.tween_property(player, "global_position", target, player.step_time)
	tween.finished.connect(func():
		player.sprite.play("idle_" + player.direction))

## BUTTON doors: an InteractableComponent over the door, so the HUD interact
## button, the interact key and a tap on the door all open it.
func _add_interactable() -> void:
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col == null or not col.shape is RectangleShape2D:
		return
	var ic: InteractableComponent = InteractableScene.instantiate()
	ic.name = "DoorInteract"
	ic.interact_label = "Enter"
	add_child(ic)
	ic.position = col.position
	ic.area_size = (col.shape as RectangleShape2D).size + Vector2.ONE * BUTTON_REACH * 2.0
	ic.interacted.connect(_on_interacted)
	_door_ic = ic

func _on_interacted(interactor: Node) -> void:
	var player: Node = interactor if interactor != null else _player
	if player == null or _blocked_dialogue_active:
		return
	_fire(player)

## A BUTTON door only offers itself while the player faces into it (its trigger
## direction), so an NPC or object standing beside a door still gets the
## interact button when the player faces them instead.
func _update_door_facing() -> void:
	if _door_ic == null or not is_instance_valid(_door_ic) or not _door_ic._in_range:
		return
	var player: Node = _door_ic._player_ref
	if player == null or player.get("facing_vec") == null:
		return
	_door_ic.disabled = Vector2(player.facing_vec) != TRIGGER_VECTORS[trigger_direction]
