# despawn_npc_action.gd -- removes a cutscene-spawned NPC for good.
# Unregisters the actor id first so CutsceneManager never holds a dangling
# reference, then frees the node (set_visible(false) would leave it in the
# tree, still interactable once the cutscene ends).
#
# JSON usage:
#   {"type":"despawn_npc", "actor":"Lola Jonabel"}
class_name DespawnNpcCutsceneAction
extends RefCounted

func action_type() -> String:
	return "despawn_npc"

func execute(step: Dictionary, mgr: Node) -> void:
	var actor_id: String = step.get("actor", "")
	var actor: Node = mgr.get_actor(actor_id)
	if actor == null:
		return
	mgr.unregister_actor(actor_id)
	actor.queue_free()
