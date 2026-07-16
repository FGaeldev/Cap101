# dialogue_action.gd — plays a chapter/scene sequence via the existing DialogueComponent.
# Owned by the cutscene, not by any single NPC — fixes the "wrong NPC triggers it" bug.
class_name DialogueCutsceneAction
extends RefCounted

func action_type() -> String:
	return "dialogue"

# step: { "type":"dialogue", "chapter":"chapter1", "scene":"scene_3_airport_parking_area" }
func execute(step: Dictionary, mgr: Node) -> void:
	var lines: Array = ChapterLoader.get_scene_lines(step.get("chapter", ""), step.get("scene", ""))
	if lines.is_empty():
		push_error("DialogueCutsceneAction: empty lines for %s/%s" % [step.get("chapter",""), step.get("scene","")])
		return
	var comp := DialogueComponent.new()
	comp.dialogue_lines = lines
	mgr.add_child(comp)
	comp.start_dialogue()
	await DialogueUI.dialogue_finished
	if is_instance_valid(comp):
		comp.queue_free()
