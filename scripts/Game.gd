# Game.gd — attached to Game.tscn root
extends Node

# Game.gd
func _ready() -> void:
	var level_path := GameState.current_level_path if GameState.current_level_path != "" else "res://scenes/world/scene01.tscn"
	load_level(level_path)

func load_level(path: String) -> void:
	for c in $LevelContainer.get_children():
		c.queue_free()
	var level = load(path).instantiate()
	$LevelContainer.add_child(level)
