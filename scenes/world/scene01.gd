extends Node2D

func _ready() -> void:
	GameState.load_game()
	GameState.current_area = "village"
	CutsceneManager.play("chapter1_scene1")
	# Connect word reveal
	var elder = $NpcElder
	var word_reveal = $WordReveal
	elder.get_node("DialogueComponent").word_revealed.connect(
		func(_id, word): word_reveal.show_word(word)
	)
	
