# objective.gd -- "go there yourself" story beats (v1.1.6). Instead of a
# cutscene walking the player somewhere in the same map, a cutscene step
# ({"type": "objective", ...}, objective_action.gd) sets a goal: a label, the
# level it's in, and a target node (a door like "Warps/WarpArea8" or a marker).
# objective_arrow.gd points at it, Rose redirects the player from other doors
# (TourGuide), and the target door opens even if it's normally shut. It clears
# when the player reaches the target, or loads "until_level" (Game.load_level).
# Lives in GameState.objective, so a save made on the way keeps it.
extends RefCounted

const MarkerUtil := preload("res://scripts/util/marker_util.gd")
## Reaching within this many px of a non-door target completes it.
const REACH_PX: float = 20.0

## then: a cutscene to play on reaching a non-door target (sitting at the loom).
static func set_goal(label: String, level: String, target: String, until_level: String = "", then: String = "") -> void:
	GameState.objective = {"label": label, "level": level, "target": target, "until_level": until_level, "then": then}

static func clear() -> void:
	GameState.objective = {}

static func active() -> bool:
	return not GameState.objective.is_empty()

static func label() -> String:
	return str(GameState.objective.get("label", ""))

## True if the objective is in this level (by scene path).
static func is_here(level_path: String) -> bool:
	return active() and str(GameState.objective.get("level", "")) == level_path

## The target node in `level`, or null.
static func target_node(level: Node) -> Node2D:
	if level == null or not is_here(level.scene_file_path):
		return null
	var target: String = str(GameState.objective.get("target", ""))
	var node: Node = level.get_node_or_null(NodePath(target))
	if node == null:
		node = MarkerUtil.find(level, target)
	return node as Node2D

## Where the player has to stand for a non-door target: beside a seat (its
## approach spot), else on the target itself.
static func reach_point(target: Node2D) -> Vector2:
	return target.approach_position() if target.has_method("approach_position") else target.global_position

## Completes a non-door objective once the player stands at it, and plays its
## "then" cutscene. Polled by objective_arrow.gd while nothing else runs. True if reached.
static func check_reached(player: Node2D, target: Node2D) -> bool:
	if target.has_method("uses_button") or player.global_position.distance_to(reach_point(target)) > REACH_PX:
		return false
	var then: String = str(GameState.objective.get("then", ""))
	clear()
	if not then.is_empty():
		CutsceneManager.play(then)
	return true

## True if `warp` (a Comp_Warp) is where the objective leads.
static func is_target_warp(warp: Node) -> bool:
	var level: Node = warp
	while level != null and not (level is Node2D and str(level.scene_file_path).begins_with("res://scenes/world/")):
		level = level.get_parent()
	return level != null and target_node(level) == warp

## Game.load_level: arriving in until_level (or leaving for any other level once
## the target was a door into it) completes the objective.
static func on_level_loaded(path: String) -> void:
	if active() and str(GameState.objective.get("until_level", "")) == path:
		clear()
