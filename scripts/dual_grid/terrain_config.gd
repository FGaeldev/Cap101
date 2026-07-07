## TerrainConfig - defines one terrain type for dual-grid system.
## New terrain = new .tres instance of this resource. No code changes needed.
extends Resource
class_name TerrainConfig

## Terrain identifier, e.g. "grass", "dirt". Used as dictionary key in DualGridSystem.
@export var terrain_id: StringName

## Texture atlas source ID in the shared TileSet resource (set in TileSet editor).
@export var atlas_source_id: int = 0

## Maps 4-bit corner bitmask (0-15) -> atlas coordinate in the tileset.
## Bit order (fixed convention, do not change without updating _dual_bitmask()):
##   bit 0 (1)  = NW corner filled
##   bit 1 (2)  = NE corner filled
##   bit 2 (4)  = SW corner filled
##   bit 3 (8)  = SE corner filled
## Populate all 16 entries (0-15) once tileset sliced.
@export var bitmask_to_atlas = {
	0:  Vector2i(0, 3), # empty
	1:  Vector2i(1, 1), # NW OC
	2:  Vector2i(2, 0), # NE OC
	3:  Vector2i(3, 0), # N side (NW+NE)
	4:  Vector2i(2, 2), # SW OC
	5:  Vector2i(1, 0), # W side (NW+SW)
	6:  Vector2i(2, 3), # NE+SW diagonal
	7:  Vector2i(1, 3), # SE IC (missing SE)
	8:  Vector2i(3, 1), # SE OC
	9:  Vector2i(0, 1), # NW+SE diagonal
	10: Vector2i(3, 2), # E side (NE+SE)
	11: Vector2i(0, 0), # SW IC (missing SW)
	12: Vector2i(1, 2), # S side (SW+SE)
	13: Vector2i(0, 2), # NE IC (missing NE)
	14: Vector2i(3, 3), # NW IC (missing NW)
	15: Vector2i(2, 1), # full
}
