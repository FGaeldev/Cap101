extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Opening monologue is for the first visit only -- the bedroom is revisited
	# for the book quest and must not replay it (or talk over the Book tutorial).
	if GameState.get_flag("seen_chapter1_scene1"):
		return
	var dialogue := DialogueComponent.new()

	dialogue.dialogue_lines = ChapterLoader.get_scene_lines(
		"chapter1",
		"scene_0_on_game_start"
	)

	add_child(dialogue)
	await get_tree().create_timer(3.0).timeout
	dialogue.start_dialogue()
