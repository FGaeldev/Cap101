extends Node2D

func _ready() -> void:
	GameState.load_game()
	GameState.current_area = "village"
	AudioManager.play_bgm("village")
	FadeManager.fade_in(0.6)
