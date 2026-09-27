extends RefCounted
class_name StagePainter
## Paints a map in the laboratory's style from a text layout, one character a
## tile:
##
##     #  wall, or solid rock where nothing is
##     T  wall with a torch on it - on a wall facing east or west
##     b  a barrel standing on the floor (blocks walking and sight)
##     o  a barrel lying on its side (the same, the other way round)
##     anything else is floor - letters and digits can mark where things go
##
## The walls are worked out the way the lab was painted by hand: a wall tile
## facing whichever way the floor beside it is, a solid block where two or more
## sides meet floor or only a corner does, and nothing at all further in,
## which reads as darkness and blocks like a wall. The floor alternates between
## the two stone tiles by column.
##
## Used by tools/build_stealth_stages.gd, and by the LayoutPainter node for
## painting a layout typed straight into the inspector.

const FLOOR_ODD := Vector2i(3, 2)
const FLOOR_EVEN := Vector2i(4, 2)
const BARREL := Vector2i(5, 2)
const BARREL_LYING := Vector2i(6, 2)
const WALL := Vector2i(2, 3)
const WALL_TORCH := Vector2i(2, 4)
const BLOCK := Vector2i(0, 2)

## The wall piece turned to face the floor beside it: which way round each of
## the lab's walls is drawn. The flags are TileSetAtlasSource's own.
const FACES_EAST := 0
const FACES_WEST := TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_FLIP_V
const FACES_SOUTH := TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_H
const FACES_NORTH := TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_V


static func is_floor(ch: String) -> bool:
	return ch != "#" and ch != "T" and ch != " " and ch != ""


static func _at(rows: PackedStringArray, x: int, y: int) -> String:
	if y < 0 or y >= rows.size() or x < 0 or x >= rows[y].length():
		return "#"
	return rows[y][x]


## Paints `rows` onto layer 0 of `tile_map`, its top-left corner at `origin`.
## Everything already there under the layout is replaced.
static func paint(tile_map: TileMap, rows: PackedStringArray, origin := Vector2i.ZERO):
	for y in rows.size():
		for x in rows[y].length():
			var cell = origin + Vector2i(x, y)
			var ch = rows[y][x]
			if is_floor(ch):
				var tile = FLOOR_ODD if posmod(cell.x, 2) == 1 else FLOOR_EVEN
				if ch == "b":
					tile = BARREL
				elif ch == "o":
					tile = BARREL_LYING
				tile_map.set_cell(0, cell, 0, tile, 0)
				continue
			_paint_wall(tile_map, rows, x, y, cell, ch == "T")


static func _paint_wall(tile_map: TileMap, rows: PackedStringArray, x: int, y: int, cell: Vector2i, torch: bool):
	var east = is_floor(_at(rows, x + 1, y))
	var west = is_floor(_at(rows, x - 1, y))
	var south = is_floor(_at(rows, x, y + 1))
	var north = is_floor(_at(rows, x, y - 1))
	var sides = int(east) + int(west) + int(south) + int(north)
	if sides == 1:
		var piece = WALL
		var turn = FACES_EAST
		if west:
			turn = FACES_WEST
		elif south:
			turn = FACES_SOUTH
		elif north:
			turn = FACES_NORTH
		# A torch only reads the right way up on a wall facing east or west, and
		# the west-facing one is mirrored rather than turned for it.
		if torch and (east or west):
			piece = WALL_TORCH
			turn = 0 if east else TileSetAtlasSource.TRANSFORM_FLIP_H
		tile_map.set_cell(0, cell, 0, piece, turn)
		return
	if sides > 1:
		tile_map.set_cell(0, cell, 0, BLOCK, 0)
		return
	# Nothing beside it but maybe a corner: a block there, darkness further in.
	for d in [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
		if is_floor(_at(rows, x + d.x, y + d.y)):
			tile_map.set_cell(0, cell, 0, BLOCK, 0)
			return
	tile_map.erase_cell(0, cell)


## Every tile in `rows` marked with `mark`, in reading order.
static func find(rows: PackedStringArray, mark: String) -> Array:
	var found := []
	for y in rows.size():
		for x in rows[y].length():
			if rows[y][x] == mark:
				found.append(Vector2i(x, y))
	return found
