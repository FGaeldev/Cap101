# sleep_bed.gd — bed the player can sleep in to skip to the next morning
extends StaticBody2D

## Sleeping always wakes the player at the next 6 AM.
const WAKE_HOUR: float = 6.0
## From the bed's position to where a sleeper lies, under the blanket. The cover
## sprite sorts in front of this spot, the base behind it.
const SLEEPER_OFFSET: Vector2 = Vector2(8, -18)
## Seconds the player is shown in bed before getting up.
const WAKE_PAUSE: float = 0.8

const ActorPath := preload("res://scripts/util/actor_path.gd")

@onready var interactable: InteractableComponent = $InteractableComponent

## False for decorative beds (NPC rooms) -- interacting does nothing.
@export var sleepable: bool = true
## Optional GameState flag that must be true before sleeping is allowed
## (e.g. keep the player awake until a story beat is done). Empty = no gate.
@export var required_flag: String = ""
@export var prompt_text: String = "Go to sleep?"
@export var not_sleepy_text: String = "I'm not sleepy yet."
## Optional GameState flag set after sleeping here (e.g. story beats waiting
## on the player's first night). Empty = sets nothing.
@export var sleep_flag: String = ""

var _sleeping: bool = false

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	interactable.disabled = not sleepable

func _on_interacted(interactor: Node) -> void:
	if not sleepable or _sleeping or interactor == null \
			or DialogueUI._current_component != null:
		return
	if not required_flag.is_empty() and not GameState.get_flag(required_flag):
		_say(not_sleepy_text)
		return
	_ask_to_sleep()

## One-off line through the normal dialogue pipeline (same approach as
## comp_warp.gd's blocked message).
func _say(text: String) -> void:
	var dialogue := DialogueComponent.new()
	dialogue.dialogue_lines = [{"speaker": "Player", "text": text, "next": null}]
	add_child(dialogue)
	dialogue.dialogue_ended.connect(dialogue.queue_free)
	dialogue.start_dialogue()

## Yes/no via the dialogue choice box. "Sleep" jumps to index 1, which is past
## the end, so the dialogue ends with _current_line == 1; "Not yet" ends at -1
## and leaves _current_line on 0. That's how the answer is read back.
func _ask_to_sleep() -> void:
	var dialogue := DialogueComponent.new()
	dialogue.dialogue_lines = [{
		"speaker": "Player",
		"text": prompt_text,
		"choices": [
			{"label": "Sleep", "next": 1},
			{"label": "Not yet", "next": -1},
		],
	}]
	add_child(dialogue)
	dialogue.dialogue_ended.connect(func():
		var accepted: bool = dialogue._current_line == 1
		dialogue.queue_free()
		if accepted:
			_sleep())
	dialogue.start_dialogue()

## Fade to black, jump the clock to the next 6 AM, save, fade back in with the
## player under the blanket, then they get up and walk back to where they stood.
func _sleep() -> void:
	_sleeping = true
	# Same lock warps use: freezes player input (Player.get_input_dir) and
	# stops doors from firing while the screen is black.
	MapManager.is_transitioning = true
	await FadeManager.fade_out()

	var player: Node2D = CutsceneManager.get_actor("player")
	var stood_at: Vector2 = player.global_position
	var in_bed: Vector2 = lay_down(player)
	DayNightManager.advance_minutes(_minutes_until(WAKE_HOUR))
	if not sleep_flag.is_empty():
		GameState.set_flag(sleep_flag)
	GameState.save_game()

	await FadeManager.fade_in()
	await get_up(player, in_bed, stood_at)
	MapManager.is_transitioning = false
	_sleeping = false

## Puts the player under the blanket. Do this while the screen is black. Returns
## the spot they're lying on, for get_up().
func lay_down(player: Node2D) -> Vector2:
	var in_bed: Vector2 = global_position + SLEEPER_OFFSET
	player.global_position = in_bed
	player.update_facing(Vector2.DOWN)
	player.sprite.play("idle_down")
	CutsceneManager.snap_camera()
	return in_bed

## Holds a moment in bed, then walks the player out to `to`.
func get_up(player: Node2D, from: Vector2, to: Vector2) -> void:
	await get_tree().create_timer(WAKE_PAUSE).timeout
	var prev: Vector2 = from
	for leg_end: Vector2 in ActorPath.around_actors(CutsceneManager, player, from, to):
		player.update_facing((leg_end - prev).normalized())
		player.sprite.play("walk_" + player.direction)
		var tween := create_tween()
		tween.tween_property(player, "global_position", leg_end, prev.distance_to(leg_end) / player.tile_size * player.step_time)
		await tween.finished
		prev = leg_end
	player.sprite.play("idle_" + player.direction)

## Minutes from now until the next occurrence of `hour` (a full day if it's
## exactly that hour now), so advance_minutes() rolls the date correctly.
func _minutes_until(hour: float) -> float:
	var hours := fposmod(hour - DayNightManager.get_hour(), 24.0)
	if is_zero_approx(hours):
		hours = 24.0
	return hours * 60.0
