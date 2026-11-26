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
const MAP_ICON_DIR := "res://assets/ui/map_icons/"
const FOG_SHADER := preload("res://assets/shaders/map_fog.gdshader")

## Roads drawn between markers, mirroring the warp zones in the world scenes:
## [from, side it leaves from, where along that side (0-1, left→right or
## top→bottom), to, side it enters]. Pastrana is the hub. Its WarpAreas sit on
## the west edge (home), top at ~62% (cathedral), top-right corner (bakhawan),
## east edge (airport), bottom at ~69% (market) and bottom-left corner
## (haboean), see pastrana_outdoors.tscn. Routes are computed from the marker
## rects, so moving a marker in the editor moves its road with it.
const ROADS := [
	["pastrana", "W", 0.5, "aklan_home", "E"],
	["pastrana", "N", 0.7, "cathedral", "S"],
	["pastrana", "N", 0.2, "souvenir", "S"],
	["pastrana", "E", 0.15, "bakhawan_ecopark", "W"],
	["pastrana", "E", 0.75, "airport", "W"],
	["pastrana", "S", 0.7, "market", "N"],
	["pastrana", "S", 0.1, "haboean", "E"],
]
const ROAD_COLOR := Color8(59, 36, 22, 170)
const ROAD_COLOR_LOCKED := Color8(59, 36, 22, 60)

@onready var map_bg: TextureRect = $MapBG
@onready var markers_root: Control = $Markers

var _popup: CanvasLayer
var _marker_buttons: Dictionary = {}  # region_id -> Button
var _roads: Control
var _icon_used: Dictionary = {}  # region_id -> Rect2 of the icon's opaque pixels (roads end there, not at the padded box)

## The map is drawn ZOOM times the page size inside a clipped page, and the
## player drags to pan it. Marker positions in the .tscn are authored at 1x
## (whole map fits the page); _wire_markers scales their centres by ZOOM, but
## the icons themselves stay their normal pixel size.
const ZOOM := 2.0
var _content: Control       # holds MapBG, Fog, Markers; moved to pan
var _dragging := false
var _user_panned := false   # reset each time the tab opens
## Page size the .tscn marker positions were placed at (the map page on a 16:9
## screen). Positions are kept as fractions of it, see _layout_markers.
const AUTHORED_SIZE := Vector2(616, 289)
var _marker_norm: Dictionary = {}  # region_id -> marker centre as a fraction of the map
var _fog_mat: ShaderMaterial

func _ready() -> void:
	map_bg.texture = MAP_TEXTURE
	_popup = RegionPopupScene.instantiate()
	_popup.layer = 101  # must render above BookUI's CanvasLayer (layer 100) or it opens invisibly behind the book
	add_child(_popup)
	_build_pan_layer()
	_wire_markers()
	_build_fog()
	_build_roads()
	_on_resized()
	HelpButton.pin(self, "map")

## Called by BookUI._show_page() right before the tab becomes visible —
## re-syncs unlock state, since unlocks can change after markers are built
## (quest/exposure gated), and re-centres the view on the places you can go.
func refresh() -> void:
	_refresh_unlocks()
	_user_panned = false
	_center_on_places.call_deferred()

# --- Panning -----------------------------------------------------------------

func _build_pan_layer() -> void:
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	_content = Control.new()
	_content.name = "PanContent"
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	move_child(_content, 0)
	for n: Control in [map_bg, markers_root]:
		n.reparent(_content, false)
		n.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_on_resized)
	visibility_changed.connect(func(): if is_visible_in_tree() and not _user_panned: _center_on_places.call_deferred())
	_on_resized()

## The page gets its real size only after BookUI lays it out (often after
## refresh()), so keep re-centring on every resize until the player drags.
func _on_resized() -> void:
	_content.size = size * ZOOM
	_layout_markers()
	if not _user_panned:
		_center_on_places()
	else:
		_set_pan(_content.position)

## Puts every marker at its fraction of the (stretched, zoomed) map, so markers
## stay on their spot of the map on any screen shape. Icons keep their pixel size.
func _layout_markers() -> void:
	if _marker_buttons.is_empty() or _content.size.x <= 0.0:
		return
	for region_id in _marker_buttons:
		var b: Button = _marker_buttons[region_id]
		var bsize := Vector2(b.offset_right - b.offset_left, b.offset_bottom - b.offset_top)
		var norm: Vector2 = _marker_norm[region_id]
		var tl: Vector2 = (norm * _content.size - bsize * 0.5).round()
		b.offset_left = tl.x; b.offset_top = tl.y
		b.offset_right = tl.x + bsize.x; b.offset_bottom = tl.y + bsize.y
	if _fog_mat:
		var centers := PackedVector2Array()
		for region_id in _marker_buttons:
			centers.append(_marker_rect(region_id).get_center())
		_fog_mat.set_shader_parameter("clear_count", mini(centers.size(), 16))
		centers.resize(16)
		_fog_mat.set_shader_parameter("clear_pos", centers)
	if _roads:
		_roads.queue_redraw()

## Clamp so the map always covers the page (no empty edge showing).
func _set_pan(p: Vector2) -> void:
	var min_p := size - _content.size
	_content.position = Vector2(clampf(p.x, min_p.x, 0.0), clampf(p.y, min_p.y, 0.0)).round()

## Centre the view on the bounding box of every marker (the playable area).
func _center_on_places() -> void:
	if _marker_buttons.is_empty() or size.x <= 0.0:
		return
	var box := Rect2()
	var first := true
	for region_id in _marker_buttons:
		var r := _marker_rect(region_id)
		box = r if first else box.merge(r)
		first = false
	_set_pan(size * 0.5 - box.get_center())

func _gui_input(event: InputEvent) -> void:
	# Touch is emulated as mouse (project default), so this covers both.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_user_panned = true
		_set_pan(_content.position + event.relative)
		accept_event()

## Markers already exist as hand-placed children of $Markers (editor-authored
## position, placed with the whole map filling an AUTHORED_SIZE page). This wires
## each one to its regions.json entry by name and remembers where it sits as a
## fraction of the map; _layout_markers places it on the map at any size.
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
		var half := Vector2(btn.offset_right - btn.offset_left, btn.offset_bottom - btn.offset_top) * 0.5
		_marker_norm[region_id] = (Vector2(btn.offset_left, btn.offset_top) + half) / AUTHORED_SIZE
		_apply_icon(btn, region_id)
		btn.tooltip_text = region.get("display_name", region_id)
		btn.pressed.connect(_on_marker_pressed.bind(region_id))
		_marker_buttons[region_id] = btn

## Swaps the plain dot for a landmark icon from assets/ui/map_icons/<region_id>.png
## (drawn by art_requests/tools/build_map_icons.gd.txt). The button is regrown
## around its editor-placed centre to the icon's size, so the hand-placed
## position is kept and the tap target gets a little bigger. No icon file → the
## marker stays a plain dot.
func _apply_icon(btn: Button, region_id: String) -> void:
	var path := MAP_ICON_DIR + region_id + ".png"
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	var size := tex.get_size()
	var img := tex.get_image()
	if img:
		_icon_used[region_id] = Rect2(img.get_used_rect())
	var center := Vector2(btn.offset_left + btn.offset_right, btn.offset_top + btn.offset_bottom) * 0.5
	btn.offset_left = round(center.x - size.x * 0.5)
	btn.offset_top = round(center.y - size.y * 0.5)
	btn.offset_right = btn.offset_left + size.x
	btn.offset_bottom = btn.offset_top + size.y
	btn.flat = true
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		btn.add_theme_stylebox_override(state, empty)
	var icon := TextureRect.new()
	icon.texture = tex
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.pivot_offset = size * 0.5
	btn.add_child(icon)
	# Small pop on hover/press so the icon reads as tappable.
	btn.mouse_entered.connect(func(): icon.scale = Vector2(1.15, 1.15))
	btn.mouse_exited.connect(func(): icon.scale = Vector2.ONE)
	btn.button_down.connect(func(): icon.scale = Vector2(0.9, 0.9))
	btn.button_up.connect(func(): icon.scale = Vector2.ONE)

## Fog of war over the parts of Aklan the game doesn't have yet. Sits between
## MapBG and Markers and clears a ragged circle around every marker, so adding
## a marker for a new municipality uncovers it with no other change.
func _build_fog() -> void:
	var fog := ColorRect.new()
	fog.name = "Fog"
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = FOG_SHADER
	mat.set_shader_parameter("map_tex", MAP_TEXTURE)
	mat.set_shader_parameter("map_px", MAP_TEXTURE.get_size())
	fog.material = mat
	_content.add_child(fog)
	_content.move_child(fog, markers_root.get_index())
	mat.set_shader_parameter("clear_radius", 30.0 * ZOOM)
	mat.set_shader_parameter("edge", 10.0 * ZOOM)
	_fog_mat = mat  # clearings are set in _layout_markers
	var sync_size := func(): mat.set_shader_parameter("host_size", fog.size)
	fog.resized.connect(sync_size)
	sync_size.call()

## Road layer sits under the markers (first child of $Markers, same coords).
func _build_roads() -> void:
	_roads = Control.new()
	_roads.name = "Roads"
	_roads.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_roads.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_roads.draw.connect(_draw_roads)
	markers_root.add_child(_roads)
	markers_root.move_child(_roads, 0)

func _marker_rect(region_id: String) -> Rect2:
	var b: Button = _marker_buttons[region_id]
	if _icon_used.has(region_id):
		var u: Rect2 = _icon_used[region_id]
		return Rect2(Vector2(b.offset_left, b.offset_top) + u.position, u.size)
	return Rect2(b.offset_left, b.offset_top, b.offset_right - b.offset_left, b.offset_bottom - b.offset_top)

## Point on a rect's side, pushed 1px outward so the road stops just short of the icon.
func _side_point(r: Rect2, side: String, t: float) -> Vector2:
	match side:
		"N": return Vector2(r.position.x + r.size.x * t, r.position.y - 1)
		"S": return Vector2(r.position.x + r.size.x * t, r.end.y)
		"W": return Vector2(r.position.x - 1, r.position.y + r.size.y * t)
		_:   return Vector2(r.end.x, r.position.y + r.size.y * t)

## Axis-aligned route: leave along the exit side's normal, bend once (or twice
## when both ends face the same axis), arrive along the entry side's normal.
func _road_points(a: Vector2, exit_side: String, b: Vector2, enter_side: String) -> PackedVector2Array:
	var exit_h := exit_side in ["E", "W"]
	var enter_h := enter_side in ["E", "W"]
	a = a.round(); b = b.round()
	if exit_h and enter_h:
		if absf(a.y - b.y) < 4: b.y = a.y
		var mx := roundf((a.x + b.x) * 0.5)
		return PackedVector2Array([a, Vector2(mx, a.y), Vector2(mx, b.y), b])
	if not exit_h and not enter_h:
		if absf(a.x - b.x) < 4: b.x = a.x
		var my := roundf((a.y + b.y) * 0.5)
		return PackedVector2Array([a, Vector2(a.x, my), Vector2(b.x, my), b])
	if exit_h:
		return PackedVector2Array([a, Vector2(b.x, a.y), b])
	return PackedVector2Array([a, Vector2(a.x, b.y), b])

func _draw_roads() -> void:
	for road in ROADS:
		var from: String = road[0]
		var to: String = road[3]
		if not (_marker_buttons.has(from) and _marker_buttons.has(to)):
			continue
		var open: bool = MapManager.is_unlocked(from) and MapManager.is_unlocked(to)
		var col: Color = ROAD_COLOR if open else ROAD_COLOR_LOCKED
		var pts := _road_points(_side_point(_marker_rect(from), road[1], road[2]), road[1],
				_side_point(_marker_rect(to), road[4], 0.5), road[4])
		# 1px dashes (2 on, 2 off), stepped pixel by pixel so it stays crisp.
		var step := 0
		for i in pts.size() - 1:
			var p := pts[i]
			var q := pts[i + 1]
			var n := int(maxf(absf(q.x - p.x), absf(q.y - p.y)))
			var dir := (q - p) / maxf(n, 1)
			for s in n:
				if step % 4 < 2:
					_roads.draw_rect(Rect2((p + dir * s).floor(), Vector2.ONE), col)
				step += 1

func _refresh_unlocks() -> void:
	if _roads:
		_roads.queue_redraw()
	for region_id in _marker_buttons:
		var unlocked: bool = MapManager.is_unlocked(region_id)
		# Always-visible + dimmed-when-locked — buttons are visible tap
		# targets by default, and hover doesn't exist on touch anyway.
		_marker_buttons[region_id].modulate = Color(1, 1, 1, 1.0 if unlocked else 0.4)

func _on_marker_pressed(region_id: String) -> void:
	AudioManager.play_sfx("menu_click")
	var region: Dictionary = MapManager.get_region(region_id)
	_popup.open_for_region(region_id, region.get("display_name", region_id), MapManager.is_unlocked(region_id))
