# Game.gd — attached to Game.tscn root
extends Node

const CultureSpots := preload("res://scripts/util/culture_spots.gd")
const ChapterGoals := preload("res://scripts/util/chapter_goals.gd")

# Game.gd
## Player is now a persistent sibling of LevelContainer (not baked into each
## level scene) — see Game.tscn. load_level() must reposition it manually
## after every swap, since the old per-scene baked position no longer exists.
## spawn_id lets doors/warps target a specific Marker2D; default reuses the
## scene's "DefaultSpawn" marker (falls back to Vector2.ZERO if scene has none).
@onready var player: CharacterBody2D = $Player
## Lives under Player (see Player.tscn), so it survives every level swap.
@onready var camera: Camera2D = $Player/Camera2D

## World-space area of the current level's tiles. Empty when it has none.
var _map_bounds := Rect2()
## camera.zoom the current limits were worked out for.
var _limits_zoom := Vector2.ZERO

## quest_id -> tutorial started when that quest becomes active. Tutorial ids
## live in data/tutorials/tutorials.json.
const QUEST_TUTORIALS := {"q002": "ch1_quest_hud", "q010": "sleep"}
## Same, with the separated menus on. Chapter 1's chain there: full quest list
## (q002 starts) -> bedroom book opens the Dictionary (book.gd) -> sleep (q010)
## -> calendar + pause menu on waking (QUEST_DONE_TUTORIALS_SEPARATE_MENUS).
## Each quest completes on the action itself, never on its tutorial.
const QUEST_TUTORIALS_SEPARATE_MENUS := {"q002": "ch1_quests", "q010": "sleep"}
## quest_id -> tutorial started when that quest completes (separated menus).
const QUEST_DONE_TUTORIALS_SEPARATE_MENUS := {"q010": "ch1_morning"}
## Chapter 2: Rose hands over her map at the cathedral (chapter2.json sets the
## flag on her line); the HUD's Map button appears then (hud.gd) and this
## tutorial points at it once the cutscene is over.
const MAP_FLAG := "got_kalibo_map"
const MAP_TUTORIAL := "ch2_map"

const MarkerUtil := preload("res://scripts/util/marker_util.gd")
const ActorPath := preload("res://scripts/util/actor_path.gd")


## Closing the window, or Android backgrounding the app (the last event a swiped
## away app gets). APPLICATION_PAUSED never fires on desktop.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST and what != NOTIFICATION_APPLICATION_PAUSED:
		return
	if is_node_ready() and GameState.session_active:
		remember_exit_spot()
		GameState.save_game()


## Records the tile the player is on for the next Continue; the caller saves.
## Records nothing with no level loaded yet or during a warp, sleep or cutscene,
## since those positions are scripted and the level sets its own on reload.
func remember_exit_spot() -> void:
	GameState.exit_spot = {}
	if player.get_parent() == self or MapManager.is_transitioning or CutsceneManager.is_playing():
		return
	# Same rounding walk_state.gd uses, in case the player is exiting mid-step.
	var tile := float(player.tile_size)
	var at: Vector2 = player.global_position
	# Seated on a pew or seat (pew.gd, seat.gd): the seat is off the grid and inside
	# the bench, so come back standing in the row behind it.
	if player.has_meta("pew"):
		at = player.get_meta("pew").standing_spot(player)
	GameState.exit_spot = {
		"level": GameState.current_level_path,
		"position": (at / tile).round() * tile,
	}


func _ready() -> void:
	QuestManager.quest_started.connect(_on_quest_started)
	QuestManager.quest_completed.connect(_on_quest_completed)
	GameState.flag_changed.connect(_on_flag_changed)
	# UI scale must not change how much of the world is on screen.
	camera.zoom /= UIScale.factor
	UIScale.changed.connect(_on_ui_scale_changed)
	# Day/night tint. A CanvasModulate tints only its own canvas layer (the
	# world); UILayer and the other CanvasLayer UIs stay untouched.
	var day_night := CanvasModulate.new()
	day_night.name = "DayNightModulate"
	add_child(day_night)
	DayNightManager.register_canvas_modulate(day_night)
	# Save is loaded by now: baseline achievements so only new ones get a toast.
	AchievementManager.prime()
	# Between-chapter goals (chapter_goals.gd): re-check on any story flag, a frame
	# later so a quest the flag just unlocked is already active.
	GameState.flag_changed.connect(func(_flag: String, _value: bool): ChapterGoals.check.call_deferred())
	ChapterGoals.check.call_deferred()
	# First errand and first chapter goals each get a short tutorial (tutorials.json).
	QuestManager.quest_started.connect(func(quest_id: String):
		var quest: Dictionary = QuestManager.quests.get(quest_id, {})
		if quest.get("category", "") == "side":
			TutorialManager.start("errands")
		elif ChapterGoals.is_goal_quest(quest_id):
			TutorialManager.start("chapter_goals"))
	# Before the level loads, so the bedroom's opening dialogue waits for it.
	# Saves already past the opening never get this card.
	if not GameState.get_flag("seen_chapter1_scene1"):
		await ChapterCard.show_if_new("chapter1")
	var level_path := GameState.current_level_path if GameState.current_level_path != "" else "res://scenes/world/chapter1/us_bedroom.tscn"
	if not ResourceLoader.exists(level_path):
		push_warning("Game: saved level '%s' is missing, starting at home" % level_path)
		level_path = MapManager.home_level()
		GameState.current_level_path = level_path
	load_level(level_path)
	# Tutorial start moved here (was after fade_in+timer) — fixes race where
	# player could act mid-fade before tutorial hooks were armed.
	TutorialManager.start("ch1_basics")
	# Absorbed from scene01.gd (deprecated — scene01.tscn removed, see
	# Team_Changes/roadmap notes; game now boots straight into us_bedroom).
	# Runs once per app launch here instead of once per scene01 (re)load,
	# which also fixes the old latent re-trigger-on-revisit behavior.
	# current_area is NOT set here: load_level() above already derived it
	# from the loaded level, and overwriting it broke area-gated quests
	# after Continue.
	AudioManager.play_bgm("village")
	await FadeManager.fade_in(3)
	await get_tree().create_timer(1.5).timeout


## Cutscenes can tween the zoom, which changes how much of the map fits on screen.
func _process(_delta: float) -> void:
	if camera.zoom != _limits_zoom:
		_update_camera_limits()


func _on_ui_scale_changed(previous: float, current: float) -> void:
	camera.zoom *= previous / current

## Starts the tutorial mapped to a newly-active quest (QUEST_TUTORIALS). If
## another is running, TutorialManager queues it. Step timing lives in
## tutorials.json ("auto_advance").
func _on_quest_started(quest_id: String) -> void:
	var map: Dictionary = QUEST_TUTORIALS_SEPARATE_MENUS if BookUI.separate_menus else QUEST_TUTORIALS
	var tutorial_id: String = map.get(quest_id, "")
	if not tutorial_id.is_empty():
		TutorialManager.start(tutorial_id)


func _on_quest_completed(quest_id: String) -> void:
	if not BookUI.separate_menus:
		return
	var tutorial_id: String = QUEST_DONE_TUTORIALS_SEPARATE_MENUS.get(quest_id, "")
	if not tutorial_id.is_empty():
		TutorialManager.start(tutorial_id)


## The map tutorial waits for the cutscene that hands the map over to end, so
## "Tap the Map button" never shows while the HUD is hidden.
func _on_flag_changed(flag_name: String, value: bool) -> void:
	if flag_name != MAP_FLAG or not value or not BookUI.separate_menus:
		return
	while CutsceneManager.is_playing():
		await CutsceneManager.cutscene_finished
	if is_inside_tree():
		TutorialManager.start(MAP_TUTORIAL)


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
	_resume_exit_spot(path)
	# Per-level night strength (metadata on the level root, see DayNightManager).
	DayNightManager.set_level_strength(float(level.get_meta("day_night_strength", 1.0)))
	_map_bounds = _get_map_bounds(level)
	_update_camera_limits()
	# Settle the view on the spawn now, while the screen is still black,
	# instead of letting the smoothed camera glide in during the fade-in.
	CutsceneManager.snap_camera()
	_update_current_area(path)
	NpcSchedule.on_level_loaded(level, path)
	CultureSpots.place(level, path)
	ChapterCard.show_area_if_new(path)

## Union of every visible TileMapLayer except "Edge" (the border ring around the
## map, which the camera shouldn't show), so a new map is covered without
## per-scene setup. Levels with no tiles return an empty Rect2.
func _get_map_bounds(level: Node) -> Rect2:
	var bounds := Rect2()
	for layer: TileMapLayer in level.find_children("*", "TileMapLayer", true, false):
		var used := layer.get_used_rect()
		if layer.name == &"Edge" or not layer.visible or used.size == Vector2i.ZERO:
			continue
		var tile := Vector2(layer.tile_set.tile_size)
		var rect: Rect2 = layer.get_global_transform() * Rect2(Vector2(used.position) * tile, Vector2(used.size) * tile)
		bounds = bounds.merge(rect) if bounds.has_area() else rect
	return bounds

## World pixels the camera may show past each map edge, so the HUD never covers
## a player standing at the edge (playtest v0.1.19: hidden behind the quest box).
const HUD_EDGE_MARGIN: float = 32.0

## Stops the camera from showing anything past the map edges. On an axis where
## the map is smaller than the view (most indoor rooms), the map stays centered.
func _update_camera_limits() -> void:
	_limits_zoom = camera.zoom
	if not _map_bounds.has_area():
		# No tiles to measure: back to Camera2D's default, effectively unlimited.
		camera.limit_left = -10000000
		camera.limit_top = -10000000
		camera.limit_right = 10000000
		camera.limit_bottom = 10000000
		return
	var view: Vector2 = get_viewport().get_visible_rect().size / camera.zoom
	# Camera2D pins the view to the top-left when its limits are narrower than
	# the view, so widen them to the view's size around the map's center.
	var pad: Vector2 = (view - _map_bounds.size).max(Vector2.ZERO) / 2.0
	var limits: Rect2 = _map_bounds.grow_individual(pad.x, pad.y, pad.x, pad.y)
	# Let the view run a little past the edges so a player on the edge of the
	# map stays clear of the HUD corners (quest box, menu, joystick). Only on axes
	# that scroll: a room smaller than the view stays fixed and centred.
	var mx: float = HUD_EDGE_MARGIN if pad.x == 0.0 else 0.0
	var my: float = HUD_EDGE_MARGIN if pad.y == 0.0 else 0.0
	limits = limits.grow_individual(mx, my, mx, my)
	# Camera2D applies its offset after the limits, so cancel it out here or the
	# view would still go past the map by that amount.
	limits.position -= camera.offset
	camera.limit_left = floori(limits.position.x)
	camera.limit_top = floori(limits.position.y)
	camera.limit_right = ceili(limits.end.x)
	camera.limit_bottom = ceili(limits.end.y)

## Every level swap (boot, door, map travel, cutscene load_scene, dev skip)
## passes through load_level(), so the area is derived here from the level
## itself instead of being hard-coded by whichever caller loaded it.
func _update_current_area(path: String) -> void:
	var area := MapManager.area_for_scene(path)
	if area.is_empty():
		push_warning("Game: no area for '%s' (add it to data/map_data/level_areas.json); keeping '%s'" % [path, GameState.current_area])
		return
	GameState.current_area = area

func _place_player_at_spawn(level: Node, spawn_id: String) -> void:
	var spawn := _find_spawn(level, spawn_id)
	if spawn == null and spawn_id != "DefaultSpawn":
		push_warning("Game: spawn_id '%s' not found in '%s', falling back to DefaultSpawn" % [spawn_id, level.name])
		spawn = _find_spawn(level, "DefaultSpawn")
	if spawn == null:
		push_warning("Game: no spawn marker found in '%s', leaving Player at (0,0)" % level.name)
		return
	player.global_position = spawn.global_position

## Puts the player back where they exited, if that was in this level. Falls back
## to the spawn they were just placed at if the level opens with a cutscene (those
## are authored to start there) or the tile is no longer free. Both are only known
## once the level has settled, which is still behind the opening fade.
func _resume_exit_spot(path: String) -> void:
	var spot: Dictionary = GameState.exit_spot
	GameState.exit_spot = {}
	if spot.get("level", "") != path or CutsceneManager.is_playing():
		return
	var spawn_position := player.global_position
	var return_to_spawn := func() -> void:
		player.global_position = spawn_position
		CutsceneManager.snap_camera()
	player.global_position = spot["position"]
	# Signal, not a check after the wait: the cutscene's first step must see the spawn.
	var on_cutscene := return_to_spawn.unbind(1)
	CutsceneManager.cutscene_started.connect(on_cutscene)
	await ActorPath.settle(get_tree())
	await get_tree().process_frame  # level scripts wait out settle() too, let them go first
	CutsceneManager.cutscene_started.disconnect(on_cutscene)
	if CutsceneManager.is_playing() or GameState.current_level_path != path:
		return
	var cell := NpcSchedule.cell_of(spot["position"])
	if NpcSchedule.is_blocked(cell) or NpcSchedule.is_occupied(cell, player):
		return_to_spawn.call()

## Spawn markers may sit directly under the level root or be grouped under
## an organizing node (e.g. "Spawns/Stairs"); MarkerUtil finds either.
func _find_spawn(level: Node, spawn_id: String) -> Node2D:
	return MarkerUtil.find(level, spawn_id)
