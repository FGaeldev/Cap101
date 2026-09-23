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

var _blocked_dialogue_active: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	# Ignore overlaps caused by the level swap itself: Game.load_level() reparents
	# the persistent Player into the new level at its OLD position for a frame
	# (both doors share coordinates), before _place_player_at_spawn() moves it.
	# warp_to_scene() already ignored these via the same flag; the blocked-door
	# path below must too, or the message + step-back fire on scene load.
	if MapManager.is_transitioning:
		return
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
