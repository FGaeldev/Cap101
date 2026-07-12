class_name WaitCutsceneAction
extends RefCounted
func action_type() -> String: return "wait"
func execute(step: Dictionary, mgr: Node) -> void:
	await mgr.get_tree().create_timer(step.get("seconds", 1.0)).timeout
