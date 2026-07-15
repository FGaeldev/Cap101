class_name SetFlagCutsceneAction
extends RefCounted
func action_type() -> String: return "set_flag"
func execute(step: Dictionary, _mgr: Node) -> void:
	GameState.set_flag(step.get("flag", ""), step.get("value", true))
