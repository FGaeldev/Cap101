extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Scene 0 is first-run onboarding. Never replay it after a dev warp; dev
	# warps can enter the bedroom without completing the original intro chain.
	if GameState.dev_mode or GameState.get_flag("seen_chapter1_scene1"):
		return

	var dialogue := DialogueComponent.new()
	dialogue.dialogue_lines = ChapterLoader.get_scene_lines(
		"chapter1",
		"scene_0_on_game_start"
	)
	add_child(dialogue)

	# Level may be replaced while the delay is pending. Do not start dialogue
	# from a stale room node after a warp.
	await get_tree().create_timer(3.0).timeout
	if not is_inside_tree() or GameState.dev_mode or GameState.get_flag("seen_chapter1_scene1"):
		if is_instance_valid(dialogue):
			dialogue.queue_free()
		return
	dialogue.start_dialogue()
