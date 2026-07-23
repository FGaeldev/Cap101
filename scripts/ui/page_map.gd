extends Control
## page_map.gd
## Map tab page for BookUI — fills PageMapHost, which spans the full spread
## (both PageLeft+PageRight width) instead of living inside one page, so the
## PNG map background isn't cut by the page seam.
##
## POI markers are hand-placed Button nodes under $Markers in the editor
## (anchor-pinned to a point so they stay put on resize), NOT generated at
## runtime from data. Each marker's node name must exactly match its
## regions.json key — that's the only link between scene position and
## MapManager data (display_name/scene_path/unlocked).
##
## Region data model (regions.json), travel logic (MapManager.travel_to_region),
## and the Mag-adto/Balik confirm popup (region_popup.gd/tscn) are J. Gumban's
## original work, reused unchanged.

const MAP_TEXTURE := preload("res://assets/ui/book/aklan_map.png")
const RegionPopupScene := preload("res://scenes/map/region_popup.tscn")

@onready var map_bg: TextureRect = $MapBG
@onready var markers_root: Control = $Markers

var _popup: CanvasLayer
var _marker_buttons: Dictionary = {}  # region_id -> Button

func _ready() -> void:
	map_bg.texture = MAP_TEXTURE
	_popup = RegionPopupScene.instantiate()
	_popup.layer = 101  # must render above BookUI's CanvasLayer (layer 100) or it opens invisibly behind the book
	add_child(_popup)
	_wire_markers()

## Called by BookUI._show_page() right before the tab becomes visible —
## re-syncs unlock state, since unlocks can change after markers are built
## (quest/exposure gated).
func refresh() -> void:
	_refresh_unlocks()

## Markers already exist as hand-placed children of $Markers (editor-authored
## position). This just wires each one to its regions.json entry by name —
## no creation, no position math.
func _wire_markers() -> void:
	for child in markers_root.get_children():
		if not child is Button:
			continue
		var region_id := child.name
		var region: Dictionary = MapManager.get_region(region_id)
		if region.is_empty():
			push_warning("page_map: marker node '%s' has no matching regions.json entry" % region_id)
			continue
		var btn := child as Button
		btn.tooltip_text = region.get("display_name", region_id)
		btn.pressed.connect(_on_marker_pressed.bind(region_id))
		_marker_buttons[region_id] = btn

func _refresh_unlocks() -> void:
	for region_id in _marker_buttons:
		var unlocked: bool = MapManager.is_unlocked(region_id)
		# Always-visible + dimmed-when-locked — buttons are visible tap
		# targets by default, and hover doesn't exist on touch anyway.
		_marker_buttons[region_id].modulate = Color(1, 1, 1, 1.0 if unlocked else 0.4)

func _on_marker_pressed(region_id: String) -> void:
	AudioManager.play_sfx("menu_click")
	var region: Dictionary = MapManager.get_region(region_id)
	_popup.open_for_region(region_id, region.get("display_name", region_id), region.get("unlocked", false))
