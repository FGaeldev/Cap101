# dialogue_action.gd — plays a chapter/scene sequence via the existing DialogueComponent.
# Owned by the cutscene, not by any single NPC — fixes the "wrong NPC triggers it" bug.
class_name DialogueCutsceneAction
extends RefCounted

func action_type() -> String:
	return "dialogue"

# step: { "type":"dialogue", "chapter":"chapter1", "scene":"scene_3_airport_parking_area" }
# Optional "said_by_npc_here": true -- the first scheduled NPC in the room
# (NpcSchedule.npcs_here) says the scene's lines. No one here, no dialogue.
func execute(step: Dictionary, mgr: Node) -> void:
	var lines: Array = ChapterLoader.get_scene_lines(step.get("chapter", ""), step.get("scene", ""))
	if lines.is_empty():
		push_error("DialogueCutsceneAction: empty lines for %s/%s" % [step.get("chapter",""), step.get("scene","")])
		return
	if step.get("said_by_npc_here", false):
		var here: Array[String] = NpcSchedule.npcs_here()
		if here.is_empty():
			return
		lines = lines.duplicate(true)
		for line: Dictionary in lines:
			line["speaker"] = here[0]
	var comp := DialogueComponent.new()
	comp.dialogue_lines = lines
	mgr.add_child(comp)
	comp.start_dialogue()
	await DialogueUI.dialogue_finished
	if is_instance_valid(comp):
		comp.queue_free()
