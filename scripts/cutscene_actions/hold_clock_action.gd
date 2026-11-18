# hold_clock_action.gd -- stops the in-game clock for a scene that needs a fixed
# time of day (Chapter 4's sunset), so the light doesn't change mid-scene.
# The clock always starts again when the cutscene ends or aborts
# (CutsceneManager), or earlier with "value": false.
#
# JSON usage:
#   {"type": "hold_clock", "value": true}
class_name HoldClockCutsceneAction
extends RefCounted

func action_type() -> String:
	return "hold_clock"

func execute(step: Dictionary, mgr: Node) -> void:
	mgr.set_clock_held(bool(step.get("value", true)))
