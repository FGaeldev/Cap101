extends Node
## MapManager.gd
## Autoload. Node-map travel system (Tier 0 deliverable — GDD §2, §9 item 3;
## Roadmap Phase A). Loads region -> destination-scene registry from
## data/map_data/regions.json and writes through to GameState.current_area /
## GameState.current_level_path on successful travel, per the
## register-on-ready / call-through-autoload pattern used by every other
## system (TDD §2).
##
## Region data model and travel logic are J. Gumban's original prototype,
## unchanged. Front-end changed: the Map is now a BookUI tab (page_map.gd)
## instead of a separate MapUI CanvasLayer overlay — see page_map.gd for the
## icon-button replacement of the old color-mask polygon regions
## (region_area.gd, now retired, see scenes/map/ + scripts/map/ deprecation
## note). -- J.Gumban --

const REGION_DATA_PATH := "res://data/map_data/regions.json"

## region_id (String, matches regions.json key and its own "id" field)
## -> Dictionary { display_name: String, scene_path: String, unlocked: bool }
var regions: Dictionary = {}

func _ready() -> void:
	_load_regions()

func _load_regions() -> void:
	var file := FileAccess.open(REGION_DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("MapManager: failed to open %s" % REGION_DATA_PATH)
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("MapManager: regions.json malformed, expected a top-level Dictionary")
		return

	regions = parsed

func get_region(region_id: String) -> Dictionary:
	return regions.get(region_id, {})

## region entry may optionally set "gate_challenge_id": String. If present,
## the node's lock state comes from ChallengeManager.is_passed(gate_id)
## instead of the static "unlocked" bool (TDD §9 item 10 — Ch2 node-map
## needs per-node challenge gating, not just static reveal). Regions with
## no gate_challenge_id keep the old static-unlock behavior unchanged.
func is_node_unlocked(region_id: String) -> bool:
	var region: Dictionary = regions.get(region_id, {})
	if region.is_empty():
		return false
	var gate_id: String = region.get("gate_challenge_id", "")
	if not gate_id.is_empty():
		return ChallengeManager.is_passed(gate_id)
	return region.get("unlocked", false)

func is_unlocked(region_id: String) -> bool:
	return is_node_unlocked(region_id)

## Called by RegionPopup's go_button. Fades out (if FadeManager is wired),
## switches scene, persists travel state to GameState, fades back in.
##
## Routes through Game.gd::load_level() (swaps LevelContainer's child), NOT
## get_tree().change_scene_to_file() — the latter would replace the whole
## running scene tree (Game.tscn itself, the current_scene once past
## MainMenu), destroying HUD/ScreenFade/DialogueRoot/WordReveal/
## QuestCompletePopup/PuzzlePanel, all of which live in Game.tscn's UILayer
## and are meant to persist across area travel.
func travel_to_region(region_id: String) -> void:
	var region := get_region(region_id)
	if region.is_empty():
		push_error("MapManager: unknown region_id '%s'" % region_id)
		return
	if not is_node_unlocked(region_id):
		push_warning("MapManager: refused travel to locked region '%s'" % region_id)
		return

	var scene_path: String = region.get("scene_path", "")
	if scene_path.is_empty():
		push_error("MapManager: region '%s' is unlocked but has no scene_path set" % region_id)
		return

	var game := get_tree().current_scene
	if game == null or not game.has_method("load_level"):
		push_error("MapManager: current_scene has no load_level() — not running inside Game.tscn")
		return

	CutsceneManager.abort()
	BookUI.close()
	await FadeManager.fade_out()

	GameState.current_area = region.get("id", region_id)
	GameState.current_level_path = scene_path
	GameState.save_game()

	game.load_level(scene_path)

	await FadeManager.fade_in()

## Opens the Map tab. Kept as the stable call site for gameplay code
## (stub_area.gd etc.) so nothing outside BookUI needs to know the map lives
## in a tab now instead of its own overlay.
func open_map() -> void:
	BookUI.open("map")
