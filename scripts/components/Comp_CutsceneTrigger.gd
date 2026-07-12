# cutscene_trigger.gd — attach to an Area2D, or call .trigger() from a quest-stage check
extends Node
@export var cutscene_id: String = ""
func trigger() -> void:
	CutsceneManager.play(cutscene_id)
