extends Node
## MapManager.gd
## Autoload. Node-map travel system (Tier 0 deliverable — GDD §2, §9 item 3;
## Roadmap Phase A). Loads region -> destination-scene registry from
## data/map_data/regions.json, drives RegionPopup's "Mag-adto" (go) action,
## and writes through to GameState.current_area / GameState.current_level_path
## on successful travel, per the register-on-ready / call-through-autoload
## pattern used by every other system (TDD §2).
##
## Built on top of J. Gumban's color-region-mask map prototype
## (map_scene.gd / region_area.gd / region_popup.gd, adapted — see those files).
## -- J.Gumban --

const REGION_DATA_PATH := "res://data/map_data/regions.json"
const MAP_SCENE_PATH := "res://scenes/map/map_scene.tscn"

## region_id (String, hex color, matches region_map.png mask + regions.json key)
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

func is_unlocked(region_id: String) -> bool:
	return regions.get(region_id, {}).get("unlocked", false)

## Called by RegionPopup's go_button. Fades out (if FadeManager is wired),
## switches scene, persists travel state to GameState, fades back in.
func travel_to_region(region_id: String) -> void:
	var region := get_region(region_id)
	if region.is_empty():
		push_error("MapManager: unknown region_id '%s'" % region_id)
		return
	if not region.get("unlocked", false):
		push_warning("MapManager: refused travel to locked region '%s'" % region_id)
		return

	var scene_path: String = region.get("scene_path", "")
	if scene_path.is_empty():
		push_error("MapManager: region '%s' is unlocked but has no scene_path set" % region_id)
		return

	# TODO: confirm FadeManager.fade_out/fade_in signatures against the live
	# FadeManager.gd (TDD §2 lists them but exact args/coroutine shape unconfirmed here).
	if Engine.has_singleton("FadeManager") or has_node("/root/FadeManager"):
		var fade_manager := get_node("/root/FadeManager")
		if fade_manager.has_method("fade_out"):
			await fade_manager.fade_out()

	GameState.current_area = region_id
	GameState.current_level_path = scene_path
	if GameState.has_method("save_game"):
		GameState.save_game()

	get_tree().change_scene_to_file(scene_path)

	if has_node("/root/FadeManager"):
		var fade_manager2 := get_node("/root/FadeManager")
		if fade_manager2.has_method("fade_in"):
			await fade_manager2.fade_in()

## Opens the node-map scene itself. TODO: no in-village trigger calls this yet —
## wire a signpost Comp_Interactable or a BookUI menu entry (open item, not built).
func open_map() -> void:
	get_tree().change_scene_to_file(MAP_SCENE_PATH)
