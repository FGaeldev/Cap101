extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var dialogue := DialogueComponent.new()

	dialogue.dialogue_lines = ChapterLoader.get_scene_lines(
		"chapter1",
		"scene_0_on_game_start"
	)

	add_child(dialogue)
	dialogue.start_dialogue()
