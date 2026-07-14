# Game.gd — attached to Game.tscn root
extends Node

func _ready() -> void:
	load_level("res://scenes/world/scene01.tscn")

func load_level(path: String) -> void:
	for c in $LevelContainer.get_children():
		c.queue_free()
	var level = load(path).instantiate()
	$LevelContainer.add_child(level)
