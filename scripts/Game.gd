# Game.gd — attached to Game.tscn root
extends Node

# Game.gd
## Player is now a persistent sibling of LevelContainer (not baked into each
## level scene) — see Game.tscn. load_level() must reposition it manually
## after every swap, since the old per-scene baked position no longer exists.
## spawn_id lets doors/warps target a specific Marker2D; default reuses the
## scene's "DefaultSpawn" marker (falls back to Vector2.ZERO if scene has none).
@onready var player: CharacterBody2D = $Player

## quest_id -> tutorial started when that quest becomes active. Tutorial ids
## live in data/tutorials/tutorials.json.
const QUEST_TUTORIALS := {"q002": "ch1_quest_hud"}


func _ready() -> void:
	QuestManager.quest_started.connect(_on_quest_started)
	var level_path := GameState.current_level_path if GameState.current_level_path != "" else "res://scenes/world/chapter1/us_bedroom.tscn"
	load_level(level_path)
	# Absorbed from scene01.gd (deprecated — scene01.tscn removed, see
	# Team_Changes/roadmap notes; game now boots straight into us_bedroom).
	# Runs once per app launch here instead of once per scene01 (re)load,
	# which also fixes the old latent re-trigger-on-revisit behavior.
	GameState.current_area = "village"
	AudioManager.play_bgm("village")
	await FadeManager.fade_in(3)
	await get_tree().create_timer(1.5).timeout
	TutorialManager.start("ch1_basics")


## Starts the tutorial mapped to a newly-active quest (QUEST_TUTORIALS).
## Waits out any tutorial still running (start() is a no-op while one is
## active). Step timing lives in tutorials.json ("auto_advance").
func _on_quest_started(quest_id: String) -> void:
	var tutorial_id: String = QUEST_TUTORIALS.get(quest_id, "")
	if tutorial_id.is_empty():
		return
	if TutorialManager.is_running():
		await TutorialManager.tutorial_completed
	TutorialManager.start(tutorial_id)


func load_level(path: String, spawn_id: String = "DefaultSpawn") -> void:
	# Rescue Player before freeing old level, else queue_free() deletes it too.
	if player.get_parent() != self:
		player.reparent(self, false)
	for c in $LevelContainer.get_children():
		c.queue_free()
	var level = load(path).instantiate()
	$LevelContainer.add_child(level)
	# Level roots are y_sort_enabled; Player must be a child to sort with furniture/NPCs.
	player.reparent(level, false)
	player = player.get_parent().get_node("Player")
	_place_player_at_spawn(level, spawn_id)

func _place_player_at_spawn(level: Node, spawn_id: String) -> void:
	var spawn := level.get_node_or_null(spawn_id)
	if spawn == null and spawn_id != "DefaultSpawn":
		push_warning("Game: spawn_id '%s' not found in '%s', falling back to DefaultSpawn" % [spawn_id, level.name])
		spawn = level.get_node_or_null("DefaultSpawn")
	if spawn == null:
		push_warning("Game: no spawn marker found in '%s', leaving Player at (0,0)" % level.name)
		return
	player.global_position = spawn.global_position
