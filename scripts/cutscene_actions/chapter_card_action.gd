# chapter_card_action.gd -- shows a chapter's description card once per save.
class_name ChapterCardCutsceneAction
extends RefCounted
func action_type() -> String: return "chapter_card"
func execute(step: Dictionary, _mgr: Node) -> void:
	await ChapterCard.show_if_new(step.get("chapter", ""))
