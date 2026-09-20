extends RefCounted
class_name Grid
## The single place that knows how big a tile is in world units, and the only
## place that converts between grid coordinates and world positions.
##
## Everything else in the game thinks in tiles: spawns, ranges, movement costs,
## blocking data and the maps' own cell data are all tile coordinates and don't
## care what a tile measures. Only drawing and sprite placement need pixels,
## and they all come through here - so changing the tile size is changing this
## one number rather than hunting a literal 32 (and its half, 16) through a
## dozen files.


const TILE_SIZE := 192
## Offset from a tile's top-left corner to its centre. Sprites sit on tile
## centres, so this comes up constantly.
const HALF_TILE := Vector2(TILE_SIZE, TILE_SIZE) * 0.5
const TILE_VECTOR := Vector2i(TILE_SIZE, TILE_SIZE)


## The world position at the centre of `tile`. Where a combatant's sprite goes.
static func tile_to_world(tile: Vector2i) -> Vector2:
	return Vector2(tile) * TILE_SIZE + HALF_TILE


## Which tile contains `world_position`. Floors rather than rounds, so a point
## anywhere inside a tile maps to that tile rather than the nearest centre.
static func world_to_tile(world_position: Vector2) -> Vector2i:
	return Vector2i(floori(world_position.x / TILE_SIZE), floori(world_position.y / TILE_SIZE))


## The top-left corner of `tile`, for drawing a tile-sized texture over it -
## draw_texture places a texture by its corner, while everything else here
## works in centres.
static func tile_corner(tile: Vector2i) -> Vector2:
	return Vector2(tile) * TILE_SIZE


## A distance expressed in tiles, converted to world units. Speeds and radii
## are written this way so they stay meaningful in tiles when the size changes:
## a walk speed of "3 tiles a second" reads the same whatever a tile measures.
static func tiles(count: float) -> float:
	return count * TILE_SIZE
