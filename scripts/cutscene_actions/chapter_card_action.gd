# chapter_card_action.gd -- a chapter start: queues the "Chapter N / title /
# Started" banner once per save (banner_card.gd). The banner plays over the game
# and waits out any black screen by itself, so the cutscene carries straight on;
# "fade_in_after" no longer fires for chapters (ChapterCard.show_if_new returns
# false). Notes still use the full card, which closes onto a black screen, so
# for those "fade_in_after": true fades back in.
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
