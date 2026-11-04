# game_speed_action.gd -- speeds the whole game up for long walks, so they play
# in full without dragging. Clock, tweens and timers all run faster. Back to
# normal when the cutscene ends or aborts (CutsceneManager), or with "scale": 1.
#
# JSON usage:
#   {"type": "game_speed", "scale": 2.0}
class_name GameSpeedCutsceneAction
extends RefCounted

func action_type() -> String:
	return "game_speed"

func execute(step: Dictionary, _mgr: Node) -> void:
	Engine.time_scale = maxf(float(step.get("scale", 1.0)), 0.1)
