# advance_clock_action.gd -- moves the in-game clock forward to an hour, for time
# that passes in the story (sitting through mass). Never moves it backward.
#
# JSON usage:
#   {"type": "advance_clock", "to_hour": 11.0}
class_name AdvanceClockCutsceneAction
extends RefCounted

func action_type() -> String:
	return "advance_clock"

func execute(step: Dictionary, _mgr: Node) -> void:
	var minutes: float = (float(step.get("to_hour", 0.0)) - DayNightManager.get_hour()) * 60.0
	if minutes > 0.0:
		DayNightManager.advance_minutes(minutes)
