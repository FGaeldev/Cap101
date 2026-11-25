# objective_action.gd -- sets a "go there yourself" goal (scripts/util/objective.gd).
# { "type": "objective", "label": "Go into the souvenir shop",
#   "target": "Warps/WarpArea8",            # node path or marker name in this level
#   "until_level": "res://.../souvenir_shop.tscn",   # optional: arriving there completes it
#   "then": "chapter3_scene2" }   # optional: cutscene played on reaching a non-door target
# Returns at once: the cutscene ends and the player walks there on their own.
class_name ObjectiveCutsceneAction
extends RefCounted

const Objective := preload("res://scripts/util/objective.gd")

func action_type() -> String:
	return "objective"

func execute(step: Dictionary, _mgr: Node) -> void:
	# {"type": "objective", "clear": true}: the beat happened another way (talking
	# to Loleng starts the loom too), so drop the goal.
	if step.get("clear", false):
		Objective.clear()
		return
	Objective.set_goal(str(step.get("label", "")), GameState.current_level_path,
			str(step.get("target", "")), str(step.get("until_level", "")), str(step.get("then", "")))
	GameState.save_game()
