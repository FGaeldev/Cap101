# scripts/cutscene_actions/fade_action.gd
class_name FadeCutsceneAction
extends RefCounted
func action_type() -> String: return "fade"
func execute(step: Dictionary, _mgr: Node) -> void:
	if step.get("direction","in") == "in":
		await FadeManager.fade_in(step.get("duration", 0.6))
	else:
		await FadeManager.fade_out(step.get("duration", 0.6))
	
