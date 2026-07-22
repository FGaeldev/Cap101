extends Control
## page_map.gd
## Map tab page for BookUI — fills PageMapHost, which spans the full spread
## (both PageLeft+PageRight width) instead of living inside one page, so the
## PNG map background isn't cut by the page seam.
##
## Replaces the old MapUI overlay (scenes/map/map_scene.tscn, now retired —
## delete after confirming nothing else references it). Region data model
## (regions.json), travel logic (MapManager.travel_to_region), and the
## Mag-adto/Balik confirm popup (region_popup.gd/tscn) are J. Gumban's
## original work, reused unchanged. What's new here: POI icon Buttons
## positioned by data instead of J. Gumban's color-mask polygon hit-testing
## (region_area.gd, now retired alongside map_scene.gd) — per design change,
## points of interest are tappable icons on a plain map image, not traced
## region shapes.

const MAP_TEXTURE := preload("res://assets/ui/book/aklan_map.png")
# Placeholder marker icon — star_icon.png was an unassigned general-purpose
# asset (UI STYLE GUIDE §6). Swap for a dedicated POI pin if art wants one.
const MARKER_ICON := preload("res://assets/ui/book/star_icon.png")
const RegionPopupScene := preload("res://scenes/map/region_popup.tscn")

# Placeholder — same "flag it, don't block on it" pattern as
# MARKER_SLICE_MARGIN/TEXTFIELD_SLICE_MARGIN elsewhere in the project.
# Remeasure once final map art + icon size are locked.
const MARKER_SIZE := Vector2(10, 10)

@onready var map_bg: TextureRect = $MapBG
@onready var markers_root: Control = $Markers

var _popup: CanvasLayer
var _marker_buttons: Dictionary = {}  # region_id -> Button

func _ready() -> void:
	map_bg.texture = MAP_TEXTURE
	_popup = RegionPopupScene.instantiate()
	add_child(_popup)
	_build_markers()

## Called by BookUI._show_page() right before the tab becomes visible —
## re-syncs unlock state the same way map_scene.gd::_refresh_unlocks() did,
## since unlocks can change after markers are built (quest/exposure gated).
func refresh() -> void:
	_refresh_unlocks()

func _build_markers() -> void:
	for region_id in MapManager.regions:
		var region: Dictionary = MapManager.regions[region_id]
		var btn := Button.new()
		btn.custom_minimum_size = MARKER_SIZE
		btn.icon = MARKER_ICON
		btn.expand_icon = true
		btn.flat = true
		btn.tooltip_text = region.get("display_name", region_id)
		markers_root.add_child(btn)
		btn.pressed.connect(_on_marker_pressed.bind(region_id))
		_marker_buttons[region_id] = btn
		# markers_root.size isn't final until this Control is laid out;
		# same "don't measure before visible" gotcha as BookUI._show_page
		# (TDD §9 item 2) — defer the position calc one frame.
		call_deferred("_position_marker", btn, region.get("map_pos", {"x": 0.5, "y": 0.5}))

func _position_marker(btn: Button, pos_norm: Dictionary) -> void:
	var area := markers_root.size
	var center := Vector2(pos_norm.get("x", 0.5) * area.x, pos_norm.get("y", 0.5) * area.y)
	btn.position = center - MARKER_SIZE * 0.5

func _refresh_unlocks() -> void:
	for region_id in _marker_buttons:
		var unlocked: bool = MapManager.is_unlocked(region_id)
		# Always-visible + dimmed-when-locked, not hover-revealed like
		# J. Gumban's original polygon regions — buttons are visible tap
		# targets by default, and hover doesn't exist on touch anyway.
		_marker_buttons[region_id].modulate = Color(1, 1, 1, 1.0 if unlocked else 0.4)

func _on_marker_pressed(region_id: String) -> void:
	AudioManager.play_sfx("menu_click")
	var region: Dictionary = MapManager.get_region(region_id)
	_popup.open_for_region(region_id, region.get("display_name", region_id), region.get("unlocked", false))
