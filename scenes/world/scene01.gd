extends Node2D

func _ready() -> void:
	GameState.load_game()
	GameState.current_area = "village"
	if GameState.get_flag("seen_chapter1_scene1"):
		FadeManager.fade_in(0.6)
	else:
		CutsceneManager.play("chapter1_scene1")
