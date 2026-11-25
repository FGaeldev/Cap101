# plaza_game.gd -- "Help with directions" in Pastrana Park (docs/MINIGAMES_PLAN.md).
# Static helper, preload it like stall_helper.gd.
#
# The visitor NPC (data/culture_spots.json, "activity": "plaza_directions")
# offers it in their menu once a day. A round is up to ROUNDS visitors, each
# asking for a different place that has a "plaza" name in places.json and an
# open warp in this map. Pay: PAY_PER_VISITOR each, plus ALL_BONUS when every
# visitor arrives (rule change 2026-11-22: a lost visitor costs that bonus).
extends RefCounted

const Directions := preload("res://scripts/util/directions.gd")

const ROUNDS: int = 3
const PAY_PER_VISITOR: int = 3
const ALL_BONUS: int = 3

static func done_today() -> bool:
	return GameState.plaza_helped_date == GameState.daily_date()

## Places a visitor can ask for from `level`: [{"place", "warp"}], open warps only.
static func places(level: Node, from: Vector2) -> Array:
	return Directions.places_here(level, from).filter(func(e: Dictionary) -> bool:
		return (e["place"] as Dictionary).has("plaza"))

static func start(visitor: Node2D) -> void:
	var level: Node2D = visitor.get_parent() as Node2D
	while level != null and level.get_parent() != null and not level.scene_file_path.begins_with("res://scenes/world/"):
		level = level.get_parent() as Node2D
	var options: Array = places(level, visitor.global_position)
	options.shuffle()
	var game: Dictionary = {
		"minigame_type": "plaza_directions",
		"level": level,
		"start": visitor.global_position,
		"rounds": options.slice(0, ROUNDS),
	}
	var done := [false]
	DialogueUI.show_standalone_minigame(game, func(_passed: bool): done[0] = true)
	while not done[0]:
		await visitor.get_tree().process_frame
		if not is_instance_valid(visitor):
			return
	DialogueUI.hide()
	GameState.plaza_helped_date = GameState.daily_date()
	var helped: int = int(game.get("helped", 0))
	GameState.plaza_visitors_helped += helped
	if helped > 0:
		GameState.activity_wins += 1  # a daily game won (kalibo_goals.gd "games")
	var pay: int = helped * PAY_PER_VISITOR
	if helped > 0 and helped == Array(game["rounds"]).size():
		pay += ALL_BONUS
	if pay > 0:
		RewardManager.award_pesos(pay, "Helping visitors")
	GameState.save_game()
