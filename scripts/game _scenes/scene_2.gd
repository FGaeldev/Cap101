extends Node2D
 
func _ready() -> void:
	GameState.current_area = "village"  # TODO: update once scene2 has its own area id
	AudioManager.play_bgm("village")     # TODO: swap if scene2 needs its own track
	FadeManager.fade_in(0.6)
	if not GameState.get_flag("seen_chapter1_scene2"):
		CutsceneManager.play("chapter1_scene2")
