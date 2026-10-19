# page_dev.gd — Dev tab (hidden unless GameState.dev_mode). Both pages.
#
# Uses the shared Header + List layout (scenes/ui/page_list_column.tscn) via
# PageListColumn, but does NOT use its two-column pagination — each column
# is independent and set by `column` before add_child():
#   "warps"     (PageLeft)  — DEV_WARP_TARGETS, room warps
#   "cutscenes" (PageRight) — DEV_CUTSCENES, replay any cutscene
# Both lists fit one page each (<=5 buttons), so no pagination methods are
# exposed and BookUI hides the arrow bars for this tab.
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

# {label, scene_path} — Player is a persistent Game.tscn sibling (not baked
# per-scene, see Game.gd), so every room scene is a valid standalone warp
# target on its own.
const DEV_WARP_TARGETS := [
	{"label": "Ch1 — US Home - Bedroom", "scene_path": "res://scenes/world/chapter1/us_bedroom.tscn"},
	{"label": "Ch1 — US Home - Living Room", "scene_path": "res://scenes/world/chapter1/us_living.tscn"},
	{"label": "Ch1 — Airport - Indoors", "scene_path": "res://scenes/world/chapter1/airport_arival.tscn"},
	{"label": "Ch1 — Airport - Outdoors", "scene_path": "res://scenes/world/chapter1/airport_ourdoors.tscn"},
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
		"auto_play": false,  # normally fired by interacting with Lola Jonabel
	},
	{
		"label": "Ch1 S1.5 — Airport arrival",
		"cutscene_id": "chapter1_scene1_5",
		"scene_path": "res://scenes/world/chapter1/airport_arival.tscn",
		"flags_on": [],
		"flags_off": ["seen_chapter1_scene1_5"],
		"spawn": "S1_5/Gate",
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
		"auto_play": false,  # normally fired by interacting with Rose
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
	if column == "warps":
		for target in DEV_WARP_TARGETS:
			add_button(target["label"], _on_dev_warp_pressed.bind(target["scene_path"]))
	else:
		for entry in DEV_CUTSCENES:
			add_button(entry["label"], _on_dev_cutscene_pressed.bind(entry))

func _on_dev_warp_pressed(scene_path: String) -> void:
	_dev_warp(scene_path)

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

	if not _dev_warp(entry["scene_path"], entry["flags_on"], entry["flags_off"], entry.get("spawn", "DefaultSpawn")):
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
## needs seen_chapter1_scene1 false). spawn_id places the player (any marker
## ref Game.load_level() accepts). Returns false (state untouched) if the
## warp can't happen.
func _dev_warp(scene_path: String, flags_on: Array = [], flags_off: Array = [], spawn_id: String = "DefaultSpawn") -> bool:
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

	BookUI.close()
	game.load_level(scene_path, spawn_id)
	return true
