# chapter_card_action.gd -- shows a chapter's description card once per save.
# The card closes onto a black screen. Steps that set the scene up first fade in
# themselves (chapter2_scene0); otherwise pass "fade_in_after": true, which fades
# in only when the card actually showed (no black flash on a repeat).
#   {"type": "chapter_card", "chapter": "chapter3", "fade_in_after": true}
# With "note" instead of "chapter", shows one of ChapterCard.NOTES (same fade rule):
#   {"type": "chapter_card", "note": "story_so_far", "fade_in_after": true}
class_name ChapterCardCutsceneAction
extends RefCounted

func action_type() -> String: return "chapter_card"

func execute(step: Dictionary, _mgr: Node) -> void:
	var shown: bool
	if step.has("note"):
		shown = await ChapterCard.show_note_if_new(str(step["note"]))
	else:
		shown = await ChapterCard.show_if_new(step.get("chapter", ""))
	if shown and step.get("fade_in_after", false):
		await FadeManager.fade_in(float(step.get("fade_duration", 0.6)))
