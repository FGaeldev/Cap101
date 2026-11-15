# sit_action.gd -- seats an actor on a pew (pew.tscn) or a seat (seat.tscn).
#
#   {"type": "sit", "actor": "Rose", "pew": "Pews/LeftB5", "seat": 0}
#   {"type": "sit", "actor": "player", "pew": "Pews/LeftB5", "walk": true, "speed": 48}
#
# "pew" is a node path from the level root, or just the pew's or seat's node name.
# "seat" is 0-based from the left; leave it out for the first free seat. Seats have one seat.
# "walk": true walks the actor around obstacles to the row behind the seat and
# steps them in; otherwise they're placed instantly. Seated actors face the
# pew's "face" (up by default) with their sprite lifted 1px.
class_name SitCutsceneAction
extends RefCounted

func action_type() -> String:
	return "sit"

func execute(step: Dictionary, mgr: Node) -> void:
	var actor: Node2D = mgr.get_actor(step.get("actor", ""))
	if actor == null:
		push_error("sit: actor '%s' not found" % step.get("actor", ""))
		return
	var pew := find_pew(actor.get_parent(), String(step.get("pew", "")))
	if pew == null:
		push_error("sit: pew '%s' not found" % step.get("pew", ""))
		return
	var seat: int = int(step.get("seat", -1))
	var ok: bool
	if step.get("walk", false):
		ok = await pew.walk_to_seat(actor, seat, mgr, float(step.get("speed", 40.0)))
	else:
		ok = pew.sit(actor, seat)
	if not ok and is_instance_valid(actor) and not actor.has_meta("pew"):
		push_warning("sit: '%s' couldn't sit on '%s' seat %d" % [step.get("actor", ""), step.get("pew", ""), seat])

static func find_pew(level: Node, ref: String) -> Node:
	if level == null or ref.is_empty():
		return null
	var pew: Node = level.get_node_or_null(ref)
	if pew == null:
		pew = level.find_child(ref.get_file(), true, false)
	return pew if pew != null and pew.has_method("walk_to_seat") else null
