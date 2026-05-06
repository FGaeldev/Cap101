# VillageArea.gd
extends Node2D

func _ready() -> void:
	GameState.load_game()
	GameState.current_area = "village"
