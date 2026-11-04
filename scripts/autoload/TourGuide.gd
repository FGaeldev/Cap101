# TourGuide.gd -- keeps the player with Rose while she's showing them around
# (flag chapter2_with_rose). If the player tries a warp in a map where Rose is,
# the warp doesn't fire: Rose walks over and asks where they want to go instead.
# After dark she walks over and takes them home. Comp_Warp asks intercept()
# before doing anything else. Dev mode skips the warp check.
extends Node

const WITH_ROSE_FLAG := "chapter2_with_rose"
const ROSE_ID := "Rose"
## Pace of Rose's walk over to the player. Same game speed as the long walks.
const APPROACH_SPEED: float = 48.0
const APPROACH_GAME_SPEED: float = 2.0
## Rose takes the player home from this hour until morning.
const HOME_BY_HOUR: int = 18
const MORNING_HOUR: int = 6
## Per map (by scene file): cutscene home, and the places offered under "Somewhere
## else" once their flag is set (no flag = always).
const STOPS: Dictionary = {
	"pastrana_outdoors.tscn": {
		"home": "chapter2_walk_home_park",
		"places": [{"label": "The market", "flag": "map_open_market", "cutscene": "chapter2_park_to_market"}],
	},
	"market_outdoors.tscn": {
		"home": "chapter2_walk_home_market",
		"places": [{"label": "The park", "flag": "", "cutscene": "chapter2_market_to_park"}],
	},
}

const ActorPath := preload("res://scripts/util/actor_path.gd")

func _ready() -> void:
	DayNightManager.hour_changed.connect(_on_hour_changed)

## True if Rose took over this warp attempt.
func intercept(warp: Node, player: Node2D) -> bool:
	if GameState.dev_mode or _rose_nearby(player) == null:
		return false
	_approach_then(_rose_nearby(player), player, _ask, warp)
	return true

## Rose in the same map as the player, while out with her and nothing's running.
func _rose_nearby(player: Node2D) -> Node2D:
	if not GameState.get_flag(WITH_ROSE_FLAG) or CutsceneManager.is_playing():
		return null
	if player == null or not CutsceneManager.has_actor(ROSE_ID):
		return null
	var rose: Node2D = CutsceneManager.get_actor(ROSE_ID)
	return rose if rose.get_parent() == player.get_parent() else null

func _on_hour_changed(hour: int) -> void:
	if hour >= MORNING_HOUR and hour < HOME_BY_HOUR:
		return
	if DialogueUI.is_active() or MapManager.is_transitioning or not CutsceneManager.has_actor("player"):
		return
	var player: Node2D = CutsceneManager.get_actor("player")
	var rose: Node2D = _rose_nearby(player)
	if rose != null:
		_approach_then(rose, player, _say_getting_late)

func _approach_then(rose: Node2D, player: Node2D, next: Callable, warp: Node = null) -> void:
	# Same lock warps use: freezes player input while she walks over.
	MapManager.is_transitioning = true
	if warp != null:
		warp._walk_player_back(player)
		await get_tree().create_timer(player.step_time).timeout
	await _walk_rose_over(rose, player)
	MapManager.is_transitioning = false
	if is_instance_valid(rose):
		next.call(rose)

## Walks Rose to the clear tile beside the player that's nearest her.
func _walk_rose_over(rose: Node2D, player: Node2D) -> void:
	var player_tile: Vector2 = _snap(player.global_position)
	var from: Vector2 = _snap(rose.global_position)
	var spots: Array[Vector2] = []
	for dir: Vector2 in ActorPath.DIRECTIONS:
		var spot: Vector2 = player_tile + dir * ActorPath.TILE_SIZE
		if not ActorPath._is_solid(rose, spot):
			spots.append(spot)
	spots.sort_custom(func(a: Vector2, b: Vector2): return a.distance_to(from) < b.distance_to(from))
	if spots.is_empty() or spots.has(from):
		_set_anim(rose, "idle", player_tile - from)
		return
	Engine.time_scale = APPROACH_GAME_SPEED
	var prev: Vector2 = from
	for leg_end: Vector2 in ActorPath.around_actors(CutsceneManager, rose, from, spots[0]):
		_set_anim(rose, "walk", (leg_end - prev).normalized())
		var tween := rose.create_tween()
		tween.tween_property(rose, "global_position", leg_end, prev.distance_to(leg_end) / APPROACH_SPEED)
		await tween.finished
		prev = leg_end
	Engine.time_scale = 1.0
	_set_anim(rose, "idle", player_tile - prev)

func _stop_for(rose: Node2D) -> Dictionary:
	return STOPS.get(rose.get_parent().scene_file_path.get_file(), {})

func _say_getting_late(rose: Node2D) -> void:
	var dialogue := DialogueComponent.new()
	dialogue.dialogue_lines = [{"speaker": "Rose", "text": "It's getting late, balikbayan. Let's head home.", "next": null}]
	rose.add_child(dialogue)
	dialogue.dialogue_ended.connect(func():
		dialogue.queue_free()
		_play_home(rose))
	dialogue.start_dialogue()

func _play_home(rose: Node2D) -> void:
	var home: String = _stop_for(rose).get("home", "")
	if not home.is_empty():
		CutsceneManager.play(home)

## Choices jump past the last line to report the answer (same trick as
## sleep_bed.gd): dialogue_lines.size() + choice index. -1 stays where they are.
func _ask(rose: Node2D) -> void:
	var places: Array[Dictionary] = []
	for place: Dictionary in _stop_for(rose).get("places", []):
		if place["flag"].is_empty() or GameState.get_flag(place["flag"]):
			places.append(place)
	var home_choice: int = 2
	var lines: Array = [
		{"speaker": "Rose", "text": "Leaving already? Where do you want to go?", "choices": [
			{"label": "Somewhere else", "next": 1},
			{"label": "Home", "next": home_choice},
			{"label": "Stay here a bit", "next": -1},
		]},
	]
	if places.is_empty():
		lines.append({"speaker": "Rose", "text": "Nowhere else is ready for us yet, balikbayan. Look around here a little more.", "next": null})
	else:
		var choices: Array = []
		for i in places.size():
			choices.append({"label": places[i]["label"], "next": home_choice + 1 + i})
		choices.append({"label": "Never mind", "next": -1})
		lines.append({"speaker": "Rose", "text": "Where to, then?", "choices": choices})
	var dialogue := DialogueComponent.new()
	dialogue.dialogue_lines = lines
	rose.add_child(dialogue)
	dialogue.dialogue_ended.connect(func():
		var answer: int = dialogue._current_line
		dialogue.queue_free()
		if answer == home_choice:
			_play_home(rose)
		elif answer > home_choice:
			CutsceneManager.play(places[answer - home_choice - 1]["cutscene"]))
	dialogue.start_dialogue()

func _set_anim(rose: Node2D, state: String, dir: Vector2) -> void:
	var anim: Node = rose.get_node_or_null("CutsceneAnimComponent")
	if anim:
		anim.set_cutscene_anim_state(state, dir)

func _snap(pos: Vector2) -> Vector2:
	return (pos / ActorPath.TILE_SIZE).round() * ActorPath.TILE_SIZE
