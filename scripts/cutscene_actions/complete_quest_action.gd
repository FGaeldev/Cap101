# complete_quest_action.gd -- completes a quest from a cutscene, with the usual
# quest-complete popup. Idempotent (QuestManager.complete_quest).
#
#   {"type": "complete_quest", "quest_id": "q006"}
class_name CompleteQuestCutsceneAction
extends RefCounted

func action_type() -> String:
	return "complete_quest"

func execute(step: Dictionary, _mgr: Node) -> void:
	QuestManager.complete_quest(str(step.get("quest_id", "")))
