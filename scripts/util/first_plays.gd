# first_plays.gd -- a world minigame starts by itself the first time it's
# available (v1.1.6): the first time the player is near Nong Pedring once the
# stall helper opens (after Sunday mass), and near the plaza visitor once the
# tour is done. After that they're offered from the NPC's menu as before.
# npc_generic.gd calls maybe_start() when an NPC enters a level.
extends RefCounted

const StallHelper := preload("res://scripts/util/stall_helper.gd")
const PlazaGame := preload("res://scripts/util/plaza_game.gd")

## Flag set once each first play has started, so it never forces again.
const STALL_FLAG: String = "first_play_stall_done"
const PLAZA_FLAG: String = "first_play_plaza_done"
## Seconds after the level settles before the NPC calls the player over.
const DELAY: float = 1.5

## The first play this NPC owes the player, or "".
static func pending_for(npc: Node) -> String:
	if npc.activity == "plaza_directions" and not GameState.get_flag(PLAZA_FLAG) \
			and GameState.plaza_visitors_helped == 0 and not PlazaGame.done_today():
		return "plaza"
	var shop_id: String = npc.shop_id
	# Only at his stall: Nong Pedring also turns up in the park and the gallery.
	if not shop_id.is_empty() and not Economy.shop_here(shop_id).is_empty() \
			and bool(Economy.shops.get(shop_id, {}).get("helper", false)) \
			and not GameState.get_flag(STALL_FLAG) and GameState.stall_shifts == 0 \
			and StallHelper.is_available() and not StallHelper.done_today():
		return "stall"
	return ""

## Waits for a quiet moment, then starts the NPC's first play if still owed.
static func maybe_start(npc: Node2D) -> void:
	if pending_for(npc).is_empty():
		return
	await npc.get_tree().create_timer(DELAY).timeout
	while is_instance_valid(npc) and (CutsceneManager.is_playing() or DialogueUI.is_active() or MapManager.is_transitioning):
		await npc.get_tree().create_timer(0.5).timeout
	if not is_instance_valid(npc) or not npc.is_inside_tree():
		return
	match pending_for(npc):
		"plaza":
			GameState.set_flag(PLAZA_FLAG)
			var hello := DialogueComponent.new()
			hello.dialogue_lines = [{"speaker": npc.npc_id, "text": "Excuse me! Can you help me find my way around here?", "next": null}]
			npc.add_child(hello)
			hello.start_dialogue()
			await hello.dialogue_ended
			hello.queue_free()
			if is_instance_valid(npc):
				PlazaGame.start(npc)
		"stall":
			GameState.set_flag(STALL_FLAG)
			StallHelper.start(npc, true)
