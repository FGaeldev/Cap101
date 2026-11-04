# sleep_bed.gd — bed the player can sleep in to skip to the next morning
extends StaticBody2D

## Sleeping always wakes the player at the next 6 AM.
const WAKE_HOUR: float = 6.0

@onready var interactable: InteractableComponent = $InteractableComponent

## False for decorative beds (NPC rooms) -- interacting does nothing.
@export var sleepable: bool = true
## Optional GameState flag that must be true before sleeping is allowed
## (e.g. keep the player awake until a story beat is done). Empty = no gate.
@export var required_flag: String = ""
@export var prompt_text: String = "Go to sleep?"
@export var not_sleepy_text: String = "I'm not sleepy yet."

var _sleeping: bool = false

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)

func _on_interacted(interactor: Node) -> void:
	if not sleepable or _sleeping or interactor == null \
			or DialogueUI._current_component != null:
		return
	var gated := not required_flag.is_empty() and not GameState.get_flag(required_flag)
	if gated or not DayNightManager.is_night():
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

## Fade to black, jump the clock to the next 6 AM, save, fade back in.
## The player stays where they are.
func _sleep() -> void:
	_sleeping = true
	# Same lock warps use: freezes player input (Player.get_input_dir) and
	# stops doors from firing while the screen is black.
	MapManager.is_transitioning = true
	await FadeManager.fade_out()

	DayNightManager.advance_minutes(_minutes_until(WAKE_HOUR))
	GameState.save_game()

	await FadeManager.fade_in()
	MapManager.is_transitioning = false
	_sleeping = false

## Minutes from now until the next occurrence of `hour` (a full day if it's
## exactly that hour now), so advance_minutes() rolls the date correctly.
func _minutes_until(hour: float) -> float:
	var hours := fposmod(hour - DayNightManager.get_hour(), 24.0)
	if is_zero_approx(hours):
		hours = 24.0
	return hours * 60.0
