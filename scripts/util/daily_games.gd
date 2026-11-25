# daily_games.gd -- word games people offer once a day from their talk menu
# (v1.1.9 tester report: no minigame in the market on Thursday or after mass,
# none in the Haboean cafe, Chapter 3 is only weaving). Data:
# data/daily_games.json. Static helper, preload it like stall_helper.gd.
#
# npc_generic.gd adds one menu entry per game this NPC hosts here today
# ("daily:<id>") and shows the marker while one is still open. A game: the
# host's intro line, the minigame, then the win or lose line. A win pays the
# game's pesos and counts towards GameState.activity_wins (chapter goals).
# Losing costs nothing (no-punishment rule); either way it's done for the day.
extends RefCounted

const DATA_PATH: String = "res://data/daily_games.json"
const MENU_PREFIX: String = "daily:"

static var _games: Dictionary = {}

static func _load() -> void:
	if _games.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_games = parsed.get("games", {}) if parsed is Dictionary else {}

static func game(game_id: String) -> Dictionary:
	_load()
	return _games.get(game_id, {})

## Ids of the games this NPC offers in the current map, open or played today.
static func hosted_by(npc_id: String) -> Array[String]:
	_load()
	var out: Array[String] = []
	for game_id: String in _games:
		var g: Dictionary = _games[game_id]
		if str(g.get("host", "")) != npc_id:
			continue
		if not str(g.get("level", "")).is_empty() and str(g["level"]) != GameState.current_level_path:
			continue
		if not str(g.get("requires_flag", "")).is_empty() and not GameState.get_flag(str(g["requires_flag"])):
			continue
		if not str(g.get("unless_flag", "")).is_empty() and GameState.get_flag(str(g["unless_flag"])):
			continue
		out.append(game_id)
	return out

static func done_today(game_id: String) -> bool:
	return int(GameState.activity_dates.get(game_id, -1)) == GameState.daily_date()

## True while this NPC still has a game to play today (the marker).
static func has_open(npc_id: String) -> bool:
	for game_id: String in hosted_by(npc_id):
		if not done_today(game_id):
			return true
	return false

## Menu entries for npc_generic's talk menu: [{id, label}].
static func menu_entries(npc_id: String) -> Array:
	var out: Array = []
	for game_id: String in hosted_by(npc_id):
		if not done_today(game_id):
			out.append({"id": MENU_PREFIX + game_id, "label": str(game(game_id).get("label", "Play"))})
	return out

## Plays a game from the host's menu. host = the NPC (its dialogue lives under it).
static func start(host: Node, game_id: String) -> void:
	var g: Dictionary = game(game_id)
	if g.is_empty() or done_today(game_id):
		return
	var speaker: String = str(host.get("npc_id"))
	if not await _say(host, speaker, str(g.get("intro", ""))):
		return
	var line: Dictionary = (g.get("minigame", {}) as Dictionary).duplicate(true)
	if int(line.get("pair_count", 0)) < 0:
		line["pair_count"] = GameState.get_minigame_word_count()
	var result := [false, false]  # [done, passed]
	DialogueUI.show_standalone_minigame(line, func(passed: bool):
		result[0] = true
		result[1] = passed)
	while not result[0]:
		await host.get_tree().process_frame
		if not is_instance_valid(host):
			return
	DialogueUI.hide()
	GameState.activity_dates[game_id] = GameState.daily_date()
	if result[1]:
		GameState.activity_wins += 1
		var pay: int = int(g.get("pay", 0))
		if pay > 0:
			RewardManager.award_pesos(pay, str(g.get("label", "Word game")))
	GameState.save_game()
	await _say(host, speaker, str(g.get("win" if result[1] else "lose", "")))
	# Markers and the HUD re-check on flag changes.
	GameState.flag_changed.emit("daily_game_played", true)

## Says one line as the host and waits for it. False if the host is gone.
static func _say(host: Node, speaker: String, text: String) -> bool:
	if text.is_empty():
		return is_instance_valid(host)
	var dialogue := DialogueComponent.new()
	dialogue.npc_id = speaker
	dialogue.dialogue_lines = [{"speaker": speaker, "text": text, "next": null}]
	host.add_child(dialogue)
	dialogue.start_dialogue()
	await dialogue.dialogue_ended
	dialogue.queue_free()
	return is_instance_valid(host)
