# page_dev.gd — Dev tab (hidden unless GameState.dev_mode). Both pages.
#
# Uses the shared Header + List layout (scenes/ui/page_list_column.tscn) via
# PageListColumn, but does NOT use its two-column pagination — each column
# is independent and set by `column` before add_child():
#   "warps"     (PageLeft)  — DEV_WARP_TARGETS, room warps
#   "cutscenes" (PageRight) — DEV_MINIGAMES (open any minigame or quiz with
#                             every bank word), then DEV_CUTSCENES
# Each column pages ITEMS_PER_PAGE buttons at a time on its own arrow bar
# (BookUI paginates each side independently; single-page columns hide it).
#
# Tab visibility/lock is owned by BookUI (refresh_dev_tab()), driven by the
# Settings tab's DevModeToggle.
#
# DEV_WARP_TARGETS / DEV_CUTSCENES are hardcoded arrays, not folder scans —
# required by the Android PCK rule (DirAccess silently returns zero files in
# exported builds, TDD §9 item 1). Add new levels/cutscenes here by hand as
# they land.
extends PageListColumn

## Which list this column shows. Set by BookUI BEFORE add_child() so _ready()
## picks the right header.
@export_enum("warps", "cutscenes") var column: String = "warps"

## Every Chapter 1 story beat, forced true when skipping into Chapter 2.
const CH1_DONE_FLAGS := [
	"seen_chapter1_scene1_5", "seen_chapter1_scene2", "seen_chapter1_scene3", "seen_chapter1_scene4",
	"story_done_scene_3_reunion", "story_done_scene_4_rose", "chapter1_complete",
]
## Ch2 room warps also mark the arrival cutscene seen, so aklan_living.gd
## doesn't replay it (use the Ch2 S0 cutscene entry for that).
const CH2_START_FLAGS := [
	"seen_chapter1_scene1_5", "seen_chapter1_scene2", "seen_chapter1_scene3", "seen_chapter1_scene4",
	"story_done_scene_3_reunion", "story_done_scene_4_rose", "chapter1_complete",
	"seen_chapter2_scene0", "chapter2_slept", "seen_chapter2_scene0b",
]

## Chapter 2 finished (tour + mass + a night's sleep): the living room then plays
## Chapter 3's morning brief between 6:00 and 12:00.
const CH3_START_FLAGS := CH2_START_FLAGS + [
	"seen_chapter2_scene1", "seen_chapter2_scene2", "seen_chapter2_scene3", "seen_chapter2_scene4",
	"chapter2_tour_done", "map_open_market", "chapter2_mass_attended", "chapter2_complete",
]

## Chapter 3 finished: the living room then plays Chapter 4's morning brief
## between 6:00 and 12:00 (dev mode starts it before chapters.json marks it out).
const CH4_START_FLAGS := CH3_START_FLAGS + [
	"chapter_card_chapter3_seen", "seen_chapter3_scene0", "chapter3_started", "seen_chapter3_scene1",
	"map_open_habuean", "seen_chapter3_scene2", "wove_first_row", "seen_chapter3_scene3",
	"got_pina_bookmark", "story_done_ch3_loleng", "seen_chapter3_scene4", "seen_chapter3_scene5",
	"chapter3_complete", "note_story_so_far_seen",
]

## Chapter 1 story quests, in story order. q002 is handled by the onboarding
## skip in _dev_warp().
const CH1_QUESTS := ["q003", "q004"]

const ChapterGoals := preload("res://scripts/util/chapter_goals.gd")

## Buttons per column page; more entries page with the book's arrow bars.
const ITEMS_PER_PAGE := 5

# {label, scene_path} — Player is a persistent Game.tscn sibling (not baked
# per-scene, see Game.gd), so every room scene is a valid standalone warp
# target on its own.
const DEV_WARP_TARGETS := [
	{"label": "Ch1 — US Home - Bedroom", "scene_path": "res://scenes/world/chapter1/us_bedroom.tscn"},
	{"label": "Ch1 — US Home - Living Room", "scene_path": "res://scenes/world/chapter1/us_living.tscn"},
	{"label": "Ch1 — Airport - Indoors", "scene_path": "res://scenes/world/chapter1/airport_arival.tscn"},
	{"label": "Ch1 — Airport - Outdoors", "scene_path": "res://scenes/world/chapter1/airport_ourdoors.tscn"},
	{"label": "Ch2 — Aklan - Living Room", "scene_path": "res://scenes/world/chapter2/aklan_living.tscn", "flags_on": CH2_START_FLAGS, "quests_done": CH1_QUESTS},
	{"label": "Ch2 — Aklan - Hallway", "scene_path": "res://scenes/world/chapter2/aklan_hallway.tscn", "flags_on": CH2_START_FLAGS, "quests_done": CH1_QUESTS},
	{"label": "Ch2 — Aklan - Player's Room", "scene_path": "res://scenes/world/chapter2/aklan_BR_Player.tscn", "flags_on": CH2_START_FLAGS, "quests_done": CH1_QUESTS},
	{"label": "Ch2 — Aklan - Rose's Room", "scene_path": "res://scenes/world/chapter2/aklan_BR_Rose.tscn", "flags_on": CH2_START_FLAGS, "quests_done": CH1_QUESTS},
	{"label": "Ch2 — Aklan - Susan's Room", "scene_path": "res://scenes/world/chapter2/aklan_BR_Susan.tscn", "flags_on": CH2_START_FLAGS, "quests_done": CH1_QUESTS},
	{"label": "Ch2 — Aklan - Jonabel's Room", "scene_path": "res://scenes/world/chapter2/aklan_BR_Jonabel.tscn", "flags_on": CH2_START_FLAGS, "quests_done": CH1_QUESTS},
	{"label": "Ch2 — Aklan - Jobert's Room", "scene_path": "res://scenes/world/chapter2/aklan_BR_Jobert.tscn", "flags_on": CH2_START_FLAGS, "quests_done": CH1_QUESTS},
	{"label": "Ch2 — Pastrana Park", "scene_path": "res://scenes/world/chapter2/pastrana_outdoors.tscn", "flags_on": CH2_START_FLAGS, "quests_done": CH1_QUESTS},
	{"label": "Ch2 — Market - Indoors", "scene_path": "res://scenes/world/market/market_indoors.tscn", "flags_on": CH2_START_FLAGS, "quests_done": CH1_QUESTS},
	{"label": "Ch2 — Cathedral - Indoors", "scene_path": "res://scenes/world/chapter2/cathedral_indoors.tscn", "flags_on": CH2_START_FLAGS, "quests_done": CH1_QUESTS},
	{"label": "Ch2 — Souvenir Shop", "scene_path": "res://scenes/world/chapter2/souvenir_shop.tscn", "flags_on": CH2_START_FLAGS, "quests_done": CH1_QUESTS},
	{"label": "Ch4 — Morning brief (Living Room)", "scene_path": "res://scenes/world/chapter2/aklan_living.tscn", "flags_on": CH4_START_FLAGS, "quests_done": CH1_QUESTS},
	{"label": "Ch4 — Bakhawan", "scene_path": "res://scenes/world/bakhawan/bakhawan_outdoors.tscn", "flags_on": CH2_START_FLAGS, "quests_done": CH1_QUESTS},
	{"label": "Ch4 — Bakhawan visitor centre", "scene_path": "res://scenes/world/bakhawan/bakhawan_indoors.tscn", "flags_on": CH2_START_FLAGS, "quests_done": CH1_QUESTS},
	{"label": "Ch4 — Bakhawan trail", "scene_path": "res://scenes/world/bakhawan/bakhawan_trail.tscn", "flags_on": CH2_START_FLAGS, "quests_done": CH1_QUESTS},
	{"label": "Ch3 — Morning brief (Living Room)", "scene_path": "res://scenes/world/chapter2/aklan_living.tscn", "flags_on": CH3_START_FLAGS, "quests_done": CH1_QUESTS},
	{"label": "Haboean — Outdoors", "scene_path": "res://scenes/world/haboean/habuean_outdoors.tscn", "flags_on": CH2_START_FLAGS, "quests_done": CH1_QUESTS},
	{"label": "Haboean — Café (L0)", "scene_path": "res://scenes/world/haboean/haboean_cafe.tscn", "flags_on": CH2_START_FLAGS, "quests_done": CH1_QUESTS},
	{"label": "Haboean — Gallery + Loft (L1)", "scene_path": "res://scenes/world/haboean/haboean_gallery.tscn", "flags_on": CH2_START_FLAGS, "quests_done": CH1_QUESTS},
	# {label, time}: jumps the day/night clock instead of warping.
	{"label": "Time — Morning (08:00)", "time": 8.0},
	{"label": "Time — Dusk (18:00)", "time": 18.0},
	{"label": "Time — Night (22:00)", "time": 22.0},
	{"label": "Time — Dawn (06:00)", "time": 6.0},
	# {label, days}: moves the in-game date (calendar / HUD weekday).
	{"label": "Date — Next day", "days": 1},
	{"label": "Date — Next week", "days": 7},
	# Economy testing (docs/ECONOMY_PLAN.md): adds pesos without closing the menu.
	{"label": "Money — +₱50", "pesos": 50},
	# Chapter cards and notes (ChapterCard). The switch shows them even in dev mode;
	# replays show one now, seen or not, without changing the save.
	{"label": "", "toggle_cards": true},
	{"label": "Cards — Replay Chapter 1 card", "card": "chapter1"},
	{"label": "Cards — Replay Chapter 2 card", "card": "chapter2"},
	{"label": "Cards — Replay Chapter 3 card", "card": "chapter3"},
	{"label": "Cards — Replay \"end of Part One\" note", "card": "story_so_far"},
]

# Cutscenes are level-bound: their actors are spawned/registered by the host
# room's root script (scene_2.gd, airport_arival.gd, npc placement in .tscn),
# so a cutscene can't just be play()'d from wherever the player stands.
# Each entry warps to its host room with flags forced into the exact state
# that room expects right before that cutscene would normally fire.
#
#   cutscene_id  — data/cutscenes/<id>.json
#   scene_path   — host room the cutscene's actors/coords belong to
#   flags_on     — prerequisites (earlier story beats) forced true
#   flags_off    — this cutscene's own seen/story flags + every LATER beat's
#                  flags in the same room, forced false so spawns match
#   spawn        — optional marker the player is placed on (MarkerUtil ref,
#                  e.g. "S3/Player" -> SceneMarkers/S3/Player); omitted =
#                  DefaultSpawn. Matches where the player stands when that
#                  cutscene fires in normal play.
#   quests_done  — optional; quests completed silently (earlier beats, plus
#                  the quest whose interaction normally fires this cutscene)
#   quests_reset — optional; quests un-completed (this or later beats)
#   auto_play    — true if the host room plays it itself on _ready() once
#                  its seen flag is false; false = menu calls play() itself.
#                  Never both, or play() gets called twice.
const DEV_CUTSCENES := [
	{
		"label": "Ch1 S1 — Lola Jonabel intro",
		"cutscene_id": "chapter1_scene1",
		"scene_path": "res://scenes/world/chapter1/us_living.tscn",
		"flags_on": [],
		"flags_off": ["seen_chapter1_scene1"],
		"quests_reset": CH1_QUESTS,
		"auto_play": false,  # normally fired by interacting with Lola Jonabel
	},
	{
		"label": "Ch1 S1.5 — Airport arrival",
		"cutscene_id": "chapter1_scene1_5",
		"scene_path": "res://scenes/world/chapter1/airport_arival.tscn",
		"flags_on": [],
		"flags_off": ["seen_chapter1_scene1_5"],
		"spawn": "S1_5/Gate",
		"quests_reset": CH1_QUESTS,
		"auto_play": true,   # airport_arival.gd plays it when SEEN_FLAG is false
	},
	{
		"label": "Ch1 S2 — Airport outdoors",
		"cutscene_id": "chapter1_scene2",
		"scene_path": "res://scenes/world/chapter1/airport_ourdoors.tscn",
		"flags_on": ["seen_chapter1_scene1_5"],
		"flags_off": [
			"seen_chapter1_scene2", "seen_chapter1_scene3", "seen_chapter1_scene4",
			"story_done_scene_3_reunion", "story_done_scene_4_rose", "chapter1_complete",
		],
		"spawn": "S2/Arrival",
		"quests_reset": CH1_QUESTS,
		"auto_play": true,   # scene_2.gd plays it when SCENE2_SEEN_FLAG is false
	},
	{
		"label": "Ch1 S3 — Reunion",
		"cutscene_id": "chapter1_scene3",
		"scene_path": "res://scenes/world/chapter1/airport_ourdoors.tscn",
		"flags_on": ["seen_chapter1_scene1_5", "seen_chapter1_scene2"],
		"flags_off": [
			"seen_chapter1_scene3", "seen_chapter1_scene4",
			"story_done_scene_3_reunion", "story_done_scene_4_rose", "chapter1_complete",
		],
		"spawn": "S3/Player",
		"quests_done": ["q003"],     # interacting with Lola Susan completes it first
		"quests_reset": ["q004"],
		"auto_play": false,  # normally fired by interacting with Lola Susan
	},
	{
		"label": "Ch1 S4 — Rose vocab drill",
		"cutscene_id": "chapter1_scene4",
		"scene_path": "res://scenes/world/chapter1/airport_ourdoors.tscn",
		# scene3 seen -> scene_2.gd spawns Jonabel + Papa, whom scene4 moves.
		"flags_on": ["seen_chapter1_scene1_5", "seen_chapter1_scene2", "seen_chapter1_scene3", "story_done_scene_3_reunion"],
		"flags_off": ["seen_chapter1_scene4", "story_done_scene_4_rose", "chapter1_complete"],
		"spawn": "S4/Player",
		"quests_done": CH1_QUESTS,   # interacting with Rose completes q004 first
		"auto_play": false,  # normally fired by interacting with Rose
	},
	{
		"label": "Ch2 S0 — Home at last",
		"cutscene_id": "chapter2_scene0",
		"scene_path": "res://scenes/world/chapter2/aklan_living.tscn",
		"flags_on": CH1_DONE_FLAGS,
		"flags_off": ["seen_chapter2_scene0", "chapter2_slept", "seen_chapter2_scene0b"],
		"quests_done": CH1_QUESTS,
		"auto_play": true,   # aklan_living.gd plays it when SEEN_FLAG is false
	},
	{
		"label": "Ch2 S1 — Walk to the park",
		"cutscene_id": "chapter2_scene1",
		"scene_path": "res://scenes/world/chapter2/pastrana_outdoors.tscn",
		"flags_on": CH2_START_FLAGS + ["chapter2_with_rose", "chapter2_left_house", "chapter2_left_home"],
		"flags_off": ["seen_chapter2_scene1", "chapter2_arrived_park", "chapter2_at_park", "chapter2_walking_home"],
		"quests_done": CH1_QUESTS,
		"auto_play": true,   # pastrana_outdoors.gd plays it when SEEN_FLAG is false
	},
]

## Minigames and quizzes, opened on the spot (no warp) for quick testing.
##   kind         quiz | minigame
##   line         the dialogue line to open; "word_pool": "ALL" (and "choices":
##                "ALL") is filled with every word in the bank, or every bank
##                word the letter-grid games can spell ("ALL_GRID", with
##                min_len/max_len)
##   from         optional {chapter, scene, minigame_type}: copy the authored
##                line from the dialogue JSON, then apply "line" on top
const DEV_MINIGAMES := [
	{"label": "Game — Quiz: meanings (all words)", "kind": "quiz", "line": {
		"type": "quiz", "quiz_type": "dynamic", "fixed_pool": true, "questions": [],
		"word_pool": "ALL", "choices": "ALL", "question_count": 5,
		"question_templates": ["What does \"[word]\" mean?", "What Akeanon word means \"[gloss]\"?"],
		"question_template_choice_displays": ["gloss", "word"], "choice_display": "gloss", "pass_ratio": 0.5}},
	{"label": "Game — Quiz: colours (Ch2)", "kind": "quiz",
		"from": {"chapter": "chapter2", "scene": "scene_4_vocabulary_practice_round_numbers_colors_market_goods", "has": "word_colors"}, "line": {}},
	{"label": "Game — Memory match (all words)", "kind": "minigame",
		"line": {"minigame_type": "memory_match", "word_pool": "ALL", "pair_count": 6}},
	{"label": "Game — Hangman (all words)", "kind": "minigame",
		"line": {"minigame_type": "hangman", "word_pool": "ALL_GRID", "min_len": 3, "max_len": 12}},
	{"label": "Game — Crossword (all words)", "kind": "minigame",
		"line": {"minigame_type": "crossword", "word_pool": "ALL_GRID", "min_len": 3, "max_len": 9, "word_count": 6}},
	{"label": "Game — Word search (all words)", "kind": "minigame",
		"line": {"minigame_type": "word_search", "word_pool": "ALL_GRID", "min_len": 3, "max_len": 8, "word_count": 6}},
	{"label": "Game — Habi-Habi: story loom (Ch3 colours)", "kind": "minigame",
		"from": {"chapter": "chapter3", "scene": "scene_2_trying_the_loom", "minigame_type": "habi_habi"}, "line": {}},
	{"label": "Game — Fishing (Ch4 pier)", "kind": "minigame",
		"from": {"chapter": "chapter4", "scene": "scene_3_fishing_lesson", "minigame_type": "fishing"}, "line": {}},
	{"label": "Game — Habi-Habi (all words)", "kind": "minigame",
		"from": {"chapter": "chapter3", "scene": "scene_loleng_habi_habi", "minigame_type": "habi_habi"},
		"line": {"word_pool": "ALL_GRID", "min_len": 3, "max_len": 8}},
]

## Frames to wait after load_level() before calling play() on a manual
## (auto_play = false) cutscene — lets host-room _ready() spawns and NPC
## register_actor() calls settle (scene_2.gd defers its own play by 1 frame).
const DEV_CUTSCENE_SETTLE_FRAMES := 2

func _get_header_text() -> String:
	return "DEV: Skip to Scene" if column == "warps" else "DEV: Games & Cutscenes"

## Overrides the base two-column refresh — each dev column builds itself.
## Buttons never change at runtime, so build once and reuse on later opens.
func refresh() -> void:
	if list.get_child_count() > 0:
		return
	_render_page()

## Per-column paging (overrides the base's two-column spread paging). BookUI
## queries each side independently, so each column gets its own arrow bar.
func next_page() -> void:
	if has_next_page():
		_offset += ITEMS_PER_PAGE
		_render_page()

func prev_page() -> void:
	if has_prev_page():
		_offset = maxi(0, _offset - ITEMS_PER_PAGE)
		_render_page()

func has_next_page() -> bool:
	return _offset + ITEMS_PER_PAGE < _entries().size()

func has_prev_page() -> bool:
	return _offset > 0

func _entries() -> Array:
	return DEV_WARP_TARGETS if column == "warps" else DEV_MINIGAMES + DEV_CUTSCENES

func _render_page() -> void:
	clear_list()
	for entry in _entries().slice(_offset, _offset + ITEMS_PER_PAGE):
		if entry.has("toggle_cards"):
			add_button(cards_label(), func():
				GameState.set_dev_show_cards(not GameState.dev_show_cards)
				_render_page())
		elif column == "warps":
			add_button(entry["label"], _on_dev_warp_pressed.bind(entry))
		elif entry.has("kind"):
			add_button(entry["label"], _on_dev_minigame_pressed.bind(entry))
		else:
			add_button(entry["label"], _on_dev_cutscene_pressed.bind(entry))

func _on_dev_warp_pressed(target: Dictionary) -> void:
	if target.has("card"):
		BookUI.close()
		await ChapterCard.replay(str(target["card"]))
		return
	if target.has("pesos"):
		RewardManager.award_pesos(int(target["pesos"]), "Dev")
		GameState.save_game()
		return
	if target.has("time"):
		DayNightManager.set_hour(target["time"])
		BookUI.close()
		return
	if target.has("days"):
		GameState.date_unix += int(target["days"]) * DayNightManager.SECONDS_PER_DAY
		DayNightManager.day_changed.emit()
		BookUI.close()
		return
	_dev_warp(target["scene_path"], target.get("flags_on", []), [], "DefaultSpawn", target.get("quests_done", []))

## Opens one DEV_MINIGAMES entry right where the player is. Needs a loaded level
## (DialogueUI's root lives in Game.tscn). The result shows as a short line.
func _on_dev_minigame_pressed(entry: Dictionary) -> void:
	var line: Dictionary = dev_minigame_line(entry)
	if line.is_empty():
		return
	BookUI.close()
	CutsceneManager.abort()
	DialogueUI.hide()
	await get_tree().process_frame
	var report := func(passed: bool):
		DialogueUI.hide()
		print("DEV minigame %s -> %s" % [entry["label"], "pass" if passed else "fail"])
		_say_result(entry["label"], passed)
	if entry["kind"] == "quiz":
		DialogueUI.show_standalone_quiz(line, report)
	else:
		DialogueUI.show_standalone_minigame(line, report)

## The line a DEV_MINIGAMES entry opens, with ALL / ALL_GRID pools filled in.
## Static so tests and dev_panel.gd can use it. {} if the entry can't be built.
static func dev_minigame_line(entry: Dictionary) -> Dictionary:
	var line: Dictionary = {}
	var from: Dictionary = entry.get("from", {})
	if not from.is_empty():
		for l in ChapterLoader.get_scene_lines(from["chapter"], from["scene"]):
			if (from.has("minigame_type") and l.get("minigame_type", "") == from["minigame_type"]) \
					or (from.has("has") and l.has(from["has"])):
				line = l.duplicate(true)
				break
		if line.is_empty():
			push_error("DevMinigame: no matching line in %s/%s" % [from["chapter"], from["scene"]])
			return {}
	line.merge(entry["line"].duplicate(true), true)
	if not line.has("type"):
		line["type"] = "minigame_trigger" if entry["kind"] == "minigame" else "quiz"
	for key in ["word_pool", "choices"]:
		match line.get(key, null):
			"ALL":
				line[key] = WordBank.words.keys()
			"ALL_GRID":
				line[key] = _grid_words(int(line.get("min_len", 3)), int(line.get("max_len", 8)))
	return line

## Every bank word a letter-grid game can spell, one id per spelling.
static func _grid_words(min_len: int, max_len: int) -> Array:
	var seen: Dictionary = {}
	var out: Array = []
	for id: String in WordBank.words:
		var letters: String = WordBank.puzzle_letters(id)
		if letters.length() < min_len or letters.length() > max_len or seen.has(letters):
			continue
		seen[letters] = true
		out.append(id)
	out.shuffle()
	return out

func _say_result(label: String, passed: bool) -> void:
	var host: Node = get_tree().current_scene
	if host == null:
		return
	var dialogue := DialogueComponent.new()
	dialogue.dialogue_lines = [{"speaker": "", "text": "DEV: %s → %s" % [label.get_slice("— ", 1), "pass" if passed else "fail"], "next": null}]
	host.add_child(dialogue)
	dialogue.dialogue_ended.connect(dialogue.queue_free)
	dialogue.start_dialogue()

## Replays one DEV_CUTSCENES entry: onboarding skip (same as a warp) -> force
## the entry's flag state -> warp to host room -> play unless the room
## auto-plays it from its own _ready().
##
## Flags are written BEFORE load_level() on purpose: host-room _ready()
## (scene_2.gd etc.) reads them synchronously during add_child() to decide
## what to spawn and whether to auto-play.
func _on_dev_cutscene_pressed(entry: Dictionary) -> void:
	var cutscene_path := "res://data/cutscenes/%s.json" % entry["cutscene_id"]
	if not FileAccess.file_exists(cutscene_path):
		push_error("DevSkip: cutscene data not found: %s" % cutscene_path)
		return

	if not _dev_warp(entry["scene_path"], entry["flags_on"], entry["flags_off"], entry.get("spawn", "DefaultSpawn"),
			entry.get("quests_done", []), entry.get("quests_reset", [])):
		return
	if entry["auto_play"]:
		return

	# This column lives under the BookUI autoload, so it survives the level
	# swap and can keep awaiting here.
	for i in DEV_CUTSCENE_SETTLE_FRAMES:
		await get_tree().process_frame
	if CutsceneManager.is_playing():
		push_warning("DevSkip: another cutscene started first; skipped %s" % entry["cutscene_id"])
		return
	CutsceneManager.play(entry["cutscene_id"])

## Shared warp core. Dev warp skips Chapter 1 onboarding as well as changing
## levels: marks its story gates/tutorials complete so their triggers do not
## replay after a warp. Keeps normal quest progression intact except for q002,
## whose objective is the opening-room/book onboarding this shortcut bypasses.
##
## flags_on/flags_off are applied AFTER the onboarding skip so a cutscene
## entry can re-clear an onboarding flag (e.g. replaying chapter1_scene1
## needs seen_chapter1_scene1 false). quests_reset / quests_done then
## un-complete / complete quests silently. spawn_id places the player (any marker
## ref Game.load_level() accepts). Returns false (state untouched) if the
## warp can't happen.
func _dev_warp(scene_path: String, flags_on: Array = [], flags_off: Array = [], spawn_id: String = "DefaultSpawn",
		quests_done: Array = [], quests_reset: Array = []) -> bool:
	if not ResourceLoader.exists(scene_path, "PackedScene"):
		push_error("DevSkip: scene resource not found: %s" % scene_path)
		return false

	var game := get_tree().current_scene
	if game == null or not game.has_method("load_level"):
		push_error("DevSkip: current scene does not provide load_level()")
		return false

	CutsceneManager.abort()
	TutorialManager.abort()
	# Close dialogue already on screen before replacing the current level.
	DialogueUI.hide()
	for tutorial_id in ["ch1_basics", "ch1_quest_hud", "ch1_quests", "ch1_dictionary"]:
		GameState.set_flag("tutorial_" + tutorial_id + "_done")
	GameState.set_flag("seen_chapter1_scene1")
	GameState.set_flag("story_done_papa_jobert_scene1")
	GameState.set_flag("story_done_lola_jonabel_scene1")
	if not GameState.get_flag("quest_002_done"):
		QuestManager.complete_quest_silently("q002")

	# v1.1.7: a save carries story-in-progress state the skip doesn't know about
	# (a trip with Rose, a walk-to goal, lessons waiting for a retake). Clear it
	# so the skipped-to scene starts the way the story would reach it.
	for flag: String in MapManager.DEV_SKIP_CLEARED_FLAGS:
		GameState.set_flag(flag, false)
	GameState.objective = {}
	GameState.missed_lessons = {}
	GameState.set_flag("lessons_missed", false)
	for flag in flags_on:
		GameState.set_flag(flag, true)
	for flag in flags_off:
		GameState.set_flag(flag, false)
	# Skipping past Chapter 2: meet the between-chapter goals (chapter_goals.gd),
	# so the Chapter 3/4 briefs play. Dev mode no longer waives them (v1.1.8).
	if "chapter2_complete" in flags_on:
		_meet_chapter_goals()
	# After flags: quest gates (requires_flag) read them. Reset first so a
	# re-cleared quest only reappears when its gate is met.
	for quest_id in quests_reset:
		QuestManager.reset_quest_silently(quest_id)
	for quest_id in quests_done:
		QuestManager.complete_quest_silently(quest_id)

	BookUI.close()
	# Same as doors and cutscene loads: load_level() doesn't record the level.
	GameState.current_level_path = scene_path
	game.load_level(scene_path, spawn_id)
	_save_after_load(game)
	return true

## Two family errands and six passed Reviews: enough for both the Chapter 3 and
## Chapter 4 goals. Same errands the playtest uses (Susan's list, Papa's pasalubong).
func _meet_chapter_goals() -> void:
	for quest_id: String in ["qs001", "qs003"]:
		var quest: Dictionary = QuestManager.quests.get(quest_id, {})
		GameState.set_flag(str(quest.get("requires_flag", "")))
		QuestManager.complete_quest_silently(quest_id)
	GameState.reviews_done = maxi(GameState.reviews_done, 6)
	GameState.reviews_passed = maxi(GameState.reviews_passed, 6)
	GameState.activity_wins = maxi(GameState.activity_wins, 3)  # v1.1.9 "Daily games won"
	ChapterGoals.check()

## Saves once the skipped-to level has loaded, so Continue comes back here with
## the skip's flags and quests. Waits a frame first so the level's own _ready()
## code (spawning the cast, setting flags, moving the player) is in the save.
## Not awaited by _dev_warp(): a cutscene entry carries on meanwhile.
func _save_after_load(game: Node) -> void:
	await get_tree().process_frame
	if not is_instance_valid(game):
		return
	game.remember_exit_spot()
	GameState.save_game()

## Label of the Dev switch for chapter cards in dev mode.
static func cards_label() -> String:
	return "Chapter cards in dev mode: %s (tap to switch)" % ("on" if GameState.dev_show_cards else "off")
