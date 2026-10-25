# page_dev.gd — Dev tab (hidden unless GameState.dev_mode). Both pages.
#
# Uses the shared Header + List layout (scenes/ui/page_list_column.tscn) via
# PageListColumn, but does NOT use its two-column pagination — each column
# is independent and set by `column` before add_child():
#   "warps"     (PageLeft)  — DEV_WARP_TARGETS, room warps
#   "cutscenes" (PageRight) — DEV_CUTSCENES, replay any cutscene
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
	"seen_chapter2_scene0",
]

## Chapter 1 story quests, in story order. q002 is handled by the onboarding
## skip in _dev_warp().
const CH1_QUESTS := ["q003", "q004"]

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
		"flags_off": ["seen_chapter2_scene0"],
		"quests_done": CH1_QUESTS,
		"auto_play": true,   # aklan_living.gd plays it when SEEN_FLAG is false
	},
]

## Frames to wait after load_level() before calling play() on a manual
## (auto_play = false) cutscene — lets host-room _ready() spawns and NPC
## register_actor() calls settle (scene_2.gd defers its own play by 1 frame).
const DEV_CUTSCENE_SETTLE_FRAMES := 2

func _get_header_text() -> String:
	return "DEV: Skip to Scene" if column == "warps" else "DEV: Play Cutscene"

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
	return DEV_WARP_TARGETS if column == "warps" else DEV_CUTSCENES

func _render_page() -> void:
	clear_list()
	for entry in _entries().slice(_offset, _offset + ITEMS_PER_PAGE):
		if column == "warps":
			add_button(entry["label"], _on_dev_warp_pressed.bind(entry))
		else:
			add_button(entry["label"], _on_dev_cutscene_pressed.bind(entry))

func _on_dev_warp_pressed(target: Dictionary) -> void:
	_dev_warp(target["scene_path"], target.get("flags_on", []), [], "DefaultSpawn", target.get("quests_done", []))

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
	for tutorial_id in ["ch1_basics", "ch1_quest_hud"]:
		GameState.set_flag("tutorial_" + tutorial_id + "_done")
	GameState.set_flag("seen_chapter1_scene1")
	GameState.set_flag("story_done_papa_jobert_scene1")
	GameState.set_flag("story_done_lola_jonabel_scene1")
	if not GameState.get_flag("quest_002_done"):
		QuestManager.complete_quest_silently("q002")

	for flag in flags_on:
		GameState.set_flag(flag, true)
	for flag in flags_off:
		GameState.set_flag(flag, false)
	# After flags: quest gates (requires_flag) read them. Reset first so a
	# re-cleared quest only reappears when its gate is met.
	for quest_id in quests_reset:
		QuestManager.reset_quest_silently(quest_id)
	for quest_id in quests_done:
		QuestManager.complete_quest_silently(quest_id)

	BookUI.close()
	game.load_level(scene_path, spawn_id)
	return true
