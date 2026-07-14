# scripts/cutscene_actions/set_visible_action.gd
class_name SetVisibleCutsceneAction
extends RefCounted
func action_type() -> String: return "set_visible"
func execute(step: Dictionary, mgr: Node) -> void:
	var actor: Node2D = mgr.get_actor(step.get("actor", ""))
	if actor:
		actor.visible = step.get("value", true)
