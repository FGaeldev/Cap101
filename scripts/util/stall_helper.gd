# stall_helper.gd -- "Help at the stall" at Nong Pedring's (docs/MINIGAMES_PLAN.md).
# Static helper, preload it like side_quests.gd:
#   const StallHelper := preload("res://scripts/util/stall_helper.gd")
#
# Offered in a vendor's NPC menu when their shop has "helper": true
# (data/items.json) and is_available(). Flow: Pedring's invite with a choice,
# his lesson on "Tig pila?" / "Pilang bato?" before the first shift only, the
# shift (stall_panel.gd), then his pay line: PAY_PER_CUSTOMER per customer
# served. One shift per daily day (GameState.stall_helped_date).
extends RefCounted

const PAY_PER_CUSTOMER: int = 2
const LESSON_FLAG: String = "stall_lesson_seen"
const STALL_LINE := {
	"minigame_type": "stall",
	"stock": ["bugas", "uga", "isda", "tubi"],
	"price_items": ["uga", "isda", "tubi"],
	"customers": 5,
	"max_misses": 3,
}

## Remembers which choice ended the dialogue (as market_panel.gd does).
class ChoiceDialogue extends DialogueComponent:
	var picked: String = ""
	func choose(choice: Dictionary) -> void:
		picked = str(choice.get("id", ""))
		super.choose(choice)

## Open from the Sunday after-mass market on, or once Chapter 2 is over.
static func is_available() -> bool:
	return GameState.get_flag("chapter2_mass_went") or GameState.get_flag("chapter2_complete")

static func done_today() -> bool:
	return GameState.stall_helped_date == GameState.daily_date()

## Runs the whole visit. host = the vendor NPC (the dialogue nodes live under it).
static func start(host: Node) -> void:
	if done_today():
		await _say(host, [_line("stall_done_today")])
		return
	var invite: Dictionary = _line("stall_invite")
	invite["choices"] = [
		{"label": str(Economy.line("stall_invite_yes")["text"]), "next": 1, "id": "yes"},
		{"label": str(Economy.line("stall_invite_no")["text"]), "next": 1, "id": "no"},
	]
	if await _say(host, [invite]) != "yes":
		return
	if not GameState.get_flag(LESSON_FLAG):
		await _say(host, [_line("stall_lesson_1"), _line("stall_lesson_2")])
		GameState.set_flag(LESSON_FLAG)
	var shift: Dictionary = STALL_LINE.duplicate(true)
	var done := [false]
	DialogueUI.show_standalone_minigame(shift, func(_passed: bool): done[0] = true)
	while not done[0]:
		await host.get_tree().process_frame
		if not is_instance_valid(host):
			return
	DialogueUI.hide()
	GameState.stall_helped_date = GameState.daily_date()
	var served: int = int(shift.get("served", 0))
	if served > 0:
		RewardManager.award_pesos(served * PAY_PER_CUSTOMER, "Stall help")
	GameState.save_game()
	await _say(host, [_line("stall_pay")])

## A dialogue line from economy_lines.json, chained to the next one by index.
static func _line(key: String) -> Dictionary:
	var l: Dictionary = Economy.line(key)
	return {"type": "dialogue", "speaker": l["speaker"], "text": l["text"],
			"translation": l["translation"], "word_ids": l["word_ids"]}

## Plays lines in order; returns the id of the choice that ended them, if any.
static func _say(host: Node, lines: Array) -> String:
	for i in lines.size():
		if not lines[i].has("choices"):
			lines[i]["next"] = i + 1 if i + 1 < lines.size() else null
	var dialogue := ChoiceDialogue.new()
	dialogue.npc_id = "Nong Pedring"
	host.add_child(dialogue)
	dialogue.dialogue_lines = lines
	dialogue.start_dialogue()
	await dialogue.dialogue_ended
	var picked: String = dialogue.picked
	dialogue.queue_free()
	return picked
