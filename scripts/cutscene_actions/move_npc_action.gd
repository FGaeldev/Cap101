# move_npc_action.gd — moves a registered actor to a point via tween. No physics needed:
# cutscene movement is deterministic, doesn't need collision resolution.
class_name MoveNpcCutsceneAction
extends RefCounted

func action_type() -> String:
	return "move_npc"

# step: { "type":"move_npc", "actor":"father", "to":[120,84], "speed":40 }
# speed px/sec; duration derived from distance so the author never hand-times a move
func execute(step: Dictionary, mgr: Node) -> void:
	var actor: Node2D = mgr.get_actor(step.get("actor", ""))
	if actor == null:
		return
	var to: Array = step.get("to", [0, 0])
	var target := Vector2(to[0], to[1])
	var speed: float = step.get("speed", 40.0)
	var dir: Vector2 = target - actor.global_position
	var duration: float = actor.global_position.distance_to(target) / max(speed, 1.0)

	_set_anim(actor, "walk", dir)
	var tween := actor.create_tween()
	tween.tween_property(actor, "global_position", target, duration)
	await tween.finished
	_set_anim(actor, "idle", dir)

func _set_anim(actor: Node, state_name: String, dir: Vector2 = Vector2.ZERO) -> void:
	var anim = actor.get_node_or_null("CutsceneAnimComponent")
	if anim:
		anim.set_cutscene_anim_state(state_name, dir)
