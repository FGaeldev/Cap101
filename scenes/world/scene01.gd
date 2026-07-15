extends Node2D

func _ready() -> void:
	GameState.load_game()
	GameState.current_area = "village"
	CutsceneManager.play("chapter1_scene1")	
