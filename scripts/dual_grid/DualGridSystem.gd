## DualGridSystem.gd
## Core engine for dual-grid autotiling. Pure config-driven — no terrain-specific
## logic lives here. Add new terrain by adding a TerrainConfig resource, not by
## editing this script.
extends Node
class_name DualGridSystem

## Reference to the visual TileMapLayer that renders the dual (offset) grid.
@export var render_layer: TileMapLayer

## Registry of available terrains, keyed by terrain_id (StringName).
## Populate in editor with TerrainConfig resources (grass_terrain.tres, etc).
@export var terrain_configs: Array[TerrainConfig] = []

## Logical grid: coarse grid, 1 cell = 1 terrain assignment.
## Key: Vector2i logic cell coord. Value: StringName terrain_id.
var logic_grid: Dictionary = {}

## Lookup built from terrain_configs at _ready(), keyed by terrain_id.
var _terrain_lookup: Dictionary = {}

func _ready() -> void:
	_build_terrain_lookup()
	# temp test, remove after verify
	set_cell(Vector2i(0,0), &"grass")
	set_cell(Vector2i(1,0), &"grass")
	set_cell(Vector2i(0,1), &"grass")

## Builds StringName -> TerrainConfig lookup from the exported array.
## Called once at startup; call again manually if terrain_configs changes at runtime.
func _build_terrain_lookup() -> void:
	_terrain_lookup.clear()
	for config in terrain_configs:
		if config == null:
			push_warning("DualGridSystem: null TerrainConfig in terrain_configs array")
			continue
		_terrain_lookup[config.terrain_id] = config

## Sets a logic cell to a terrain type and repaints affected dual cells.
## terrain_id = "" or invalid clears the cell (treated as empty/no terrain).
func set_cell(logic_pos: Vector2i, terrain_id: StringName) -> void:
	if terrain_id == StringName():
		logic_grid.erase(logic_pos)
	else:
		logic_grid[logic_pos] = terrain_id
	_mark_dirty_neighbors(logic_pos)

## A logic cell touches 4 dual cells (its own coord + 3 neighbors, since dual
## cell (x,y) samples logic cells (x,y),(x+1,y),(x,y+1),(x+1,y+1)).
## Changing logic cell (x,y) can affect dual cells (x,y), (x-1,y), (x,y-1), (x-1,y-1).
func _mark_dirty_neighbors(logic_pos: Vector2i) -> void:
	for offset in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]:
		_repaint_dual(logic_pos + offset)

## Samples the 4 logic-grid corners for a given dual cell coordinate and
## packs them into a 4-bit mask (bit order fixed, must match TerrainConfig comment):
##   bit 0 (1) = NW filled, bit 1 (2) = NE filled,
##   bit 2 (4) = SW filled, bit 3 (8) = SE filled.
## Only samples cells matching a single terrain per dual cell (no blending yet).
func _dual_bitmask(dual_pos: Vector2i, terrain_id: StringName) -> int:
	var nw: bool = logic_grid.get(dual_pos, StringName()) == terrain_id
	var ne: bool = logic_grid.get(dual_pos + Vector2i(1, 0), StringName()) == terrain_id
	var sw: bool = logic_grid.get(dual_pos + Vector2i(0, 1), StringName()) == terrain_id
	var se: bool = logic_grid.get(dual_pos + Vector2i(1, 1), StringName()) == terrain_id
	var mask: int = 0
	if nw: mask |= 1
	if ne: mask |= 2
	if sw: mask |= 4
	if se: mask |= 8
	return mask

## Repaints one dual cell. Determines dominant terrain among the 4 sampled
## logic corners, computes bitmask for that terrain, looks up atlas coord,
## writes to render_layer. Cell with no terrain present clears the render tile.
func _repaint_dual(dual_pos: Vector2i) -> void:
	var dominant_terrain: StringName = _get_dominant_terrain(dual_pos)
	if dominant_terrain == StringName():
		render_layer.erase_cell(dual_pos)
		return

	var config: TerrainConfig = _terrain_lookup.get(dominant_terrain)
	if config == null:
		push_warning("DualGridSystem: no TerrainConfig registered for terrain_id '%s'" % dominant_terrain)
		return

	var mask: int = _dual_bitmask(dual_pos, dominant_terrain)
	var atlas_coord: Vector2i = config.bitmask_to_atlas.get(mask, Vector2i(-1, -1))
	if atlas_coord == Vector2i(-1, -1):
		push_warning("DualGridSystem: missing bitmask %d in TerrainConfig '%s'" % [mask, dominant_terrain])
		return
	
	print(dual_pos, config.atlas_source_id, atlas_coord)
	render_layer.set_cell(dual_pos, config.atlas_source_id, atlas_coord)

## Picks which terrain "owns" a dual cell when its 4 logic corners may contain
## mixed terrains. Current rule: first non-empty terrain found (NW->NE->SW->SE
## priority). Sufficient for single/non-overlapping terrains; revisit if
## multi-terrain blending (mask-per-pair) gets added later.
func _get_dominant_terrain(dual_pos: Vector2i) -> StringName:
	for offset in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var t: StringName = logic_grid.get(dual_pos + offset, StringName())
		if t != StringName():
			return t
	return StringName()
