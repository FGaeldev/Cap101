extends Node2D
## map_scene.gd
## Node-map travel screen. Renders map_art.png as backdrop, traces clickable
## region polygons from the region_map.png color mask, and opens RegionPopup
## on tap/click so the player can travel to an unlocked region.
##
## Color-mask polygon tracing (get_fit_scale / get_region_color_dict /
## get_polygons) is J. Gumban's original map prototype, unchanged in logic.
## Adapted to read region metadata from MapManager.regions (regions.json)
## instead of a flat name list, and to route selection through a signal
## instead of a hardcoded "Main/RegionPopup" node path.
## -- J.Gumban --

@onready var mapArt: Sprite2D = $MapArt
@onready var mapImage: Sprite2D = $MapDisplay
@onready var regionsNode: Node2D = $Regions
@onready var regionPopup: CanvasLayer = $RegionPopup

func _ready() -> void:
	# -- J.Gumban --
	mapArt.centered = false
	mapImage.centered = false
	var fit_scale := get_fit_scale()
	mapImage.scale = Vector2(fit_scale, fit_scale)
	mapArt.scale = Vector2(fit_scale, fit_scale)
	regionsNode.scale = Vector2(fit_scale, fit_scale)
	load_regions()

# -- J.Gumban --
func get_fit_scale() -> float:
	var viewport_size := get_viewport_rect().size
	var texture_size := mapImage.get_texture().get_size()
	return min(viewport_size.x / texture_size.x, viewport_size.y / texture_size.y)

## Builds one RegionArea per entry in MapManager.regions, using polygon
## geometry traced from the region_map.png color mask.
func load_regions() -> void:
	var image := mapImage.get_texture().get_image()
	var pixel_color_dict := get_region_color_dict(image)

	for region_id in MapManager.regions:
		var region_data: Dictionary = MapManager.regions[region_id]

		if region_id not in pixel_color_dict:
			push_warning("map_scene: no pixels found for region '%s' (%s)" % [region_id, region_data.get("display_name", "?")])
			continue

		var region: Area2D = load("res://scenes/map/region_area.tscn").instantiate()
		region.region_id = region_id
		region.region_name = region_data.get("display_name", region_id)
		region.unlocked = region_data.get("unlocked", false)
		region.set_name(region_id)  # -- J.Gumban -- (color string is a valid Node name)
		regionsNode.add_child(region)
		region.region_selected.connect(_on_region_selected)

		var polygons := get_polygons(image, region_id, pixel_color_dict)
		for polygon in polygons:
			var region_collision := CollisionPolygon2D.new()
			var region_polygon := Polygon2D.new()
			region_collision.polygon = polygon
			region_polygon.polygon = polygon
			region.add_child(region_collision)
			region.add_child(region_polygon)

	mapImage.queue_free()  # -- J.Gumban --

func _on_region_selected(region_id: String, region_name: String, unlocked: bool) -> void:
	regionPopup.open_for_region(region_id, region_name, unlocked)

# -- J.Gumban --
func get_region_color_dict(image: Image) -> Dictionary:
	var pixel_color_dict := {}
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel_color := "#" + str(image.get_pixel(int(x), int(y)).to_html(false))
			if pixel_color not in pixel_color_dict:
				pixel_color_dict[pixel_color] = []
			pixel_color_dict[pixel_color].append(Vector2(x, y))
	return pixel_color_dict

# -- J.Gumban --
func get_polygons(image: Image, region_color: String, pixel_color_dict: Dictionary) -> Array:
	var targetImage := Image.create_empty(image.get_size().x, image.get_size().y, false, Image.FORMAT_RGBA8)
	for value in pixel_color_dict[region_color]:
		targetImage.set_pixel(value.x, value.y, Color("#ffffff"))

	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(targetImage)
	return bitmap.opaque_to_polygons(Rect2(Vector2(0, 0), bitmap.get_size()), 0.1)
