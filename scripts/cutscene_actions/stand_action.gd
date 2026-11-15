# stand_action.gd -- gets an actor up from the pew they're sitting on.
#
#   {"type": "stand", "actor": "Rose"}
#
# They step back into the row behind their seat, with their sprite and
# collision restored. Does nothing if the actor isn't seated.
class_name StandCutsceneAction
extends RefCounted

func action_type() -> String:
	return "stand"

func execute(step: Dictionary, mgr: Node) -> void:
	var actor: Node2D = mgr.get_actor(step.get("actor", ""))
	if actor == null:
		return
	if not actor.has_meta("pew"):
		return
	var pew: Variant = actor.get_meta("pew")
	if is_instance_valid(pew):
		pew.stand(actor)
