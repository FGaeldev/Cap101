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

## Seconds the player must keep holding the trigger direction, when they step
## onto the door already pressing it, before the door fires.
@export_range(0.0, 2.0, 0.05) var hold_delay: float = 0.5

## Absolute res:// path to the destination scene, e.g.
## "res://scenes/world/us_living.tscn".
@export var target_scene: String

## Name of the Marker2D in the destination scene to spawn the Player at.
## Falls back to "DefaultSpawn" if left blank or not found there.
@export var target_spawn_id: String = "DefaultSpawn"

## Optional GameState flag that must be true before this warp works (e.g.
## "quest_002_done" keeps the airport door shut until the book quest is done).
## Empty = always open (default, most doors). Bypassed in GameState.dev_mode.
@export var required_flag: String = ""

## One-line player remark shown when the warp is blocked by required_flag.
@export var blocked_message: String = "I should finish what I'm doing here first."

## Fire as soon as a cutscene walks the player onto this area (no input needed),
## e.g. Ch1 scene 4's exit conga carrying the player off the map edge. Still
## honours required_flag (silently: no blocked message mid-cutscene). The warp
## aborts the running cutscene, so any steps after the walk are skipped.
@export var fire_during_cutscene: bool = false

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

func _ready() -> void:
	_refresh_shape()
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

## Polls while a player overlaps. Two ways to fire:
## 1) Fresh press: door saw the player NOT pressing the trigger direction
##    after entering (_armed), then they press it -> fires immediately.
## 2) Held through: player entered still pressing it -> fires once the key has
##    been held continuously for hold_delay seconds.
## Reads input, not Walk state, because a wall behind the door blocks the step
## and Walk never starts.
func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _player == null or _fired:
		return
	if fire_during_cutscene and CutsceneManager.is_playing():
		if required_flag.is_empty() or GameState.dev_mode or GameState.get_flag(required_flag):
			_fire(_player)
		return
	var want: Vector2 = TRIGGER_VECTORS[trigger_direction]
	if _player.get_input_dir() != want:
		_armed = true
		_hold_time = 0.0
		return
	if _armed:
		_fire(_player)
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
	if not required_flag.is_empty() and not GameState.dev_mode and not GameState.get_flag(required_flag):
		_show_blocked_message(body)
		return
	MapManager.warp_to_scene(target_scene, target_spawn_id)

## Reuses the normal dialogue pipeline (tap to dismiss) via a throwaway
## DialogueComponent, same approach as us_bedroom.gd's opening line.
func _show_blocked_message(player) -> void:
	if _blocked_dialogue_active or CutsceneManager.is_playing():
		return
	_blocked_dialogue_active = true
	var dialogue := DialogueComponent.new()
	dialogue.dialogue_lines = [{"speaker": "Player", "text": blocked_message, "next": null}]
	add_child(dialogue)
	dialogue.dialogue_ended.connect(func():
		_blocked_dialogue_active = false
		dialogue.queue_free())
	dialogue.start_dialogue()
	# After start_dialogue(): dialogue is now active, so player input is
	# already locked (Player.get_input_dir) and can't fight the step-back tween.
	_walk_player_back(player)

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
