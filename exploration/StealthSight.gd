extends RefCounted
class_name StealthSight
## What a guard on a stealth map can see: the same walls, and the same rule for
## what stops a look, that combat's line of sight uses - built from the same
## "Blocks" tile data, see-through tiles included.
##
## Its own copy of the walk rather than a call into Combat, which needs a
## battle's controller to ask. The same arithmetic in the same order, though,
## so a wall that hides somebody in a fight hides them here too - the `sneak`
## suite checks the two agree line for line, the way `danger` checks
## Combat._SightGrid. Change the rule in one and the others have to follow.
##
## Bodies are not cover here. In a fight a person in the way stops a shot; out
## here the only people are the guards, and a guard is not going to hide
## Cyrus from another guard.

## How a guard's view is shaped: half of 160 degrees either side of where they
## face, and as far as the walls allow.
const HALF_CONE_DEGREES := 80.0

## The Blocks entry meaning "stops the feet, not the eyes". The same number
## CController reads it as.
const SEE_THROUGH := 3

var _stops_sight := {}
var _region := Rect2i()
var _tile_map: TileMap = null


func _init(tile_map: TileMap):
	_tile_map = tile_map
	if tile_map == null:
		return
	_region = tile_map.get_used_rect()
	for x in range(_region.position.x, _region.end.x):
		for y in range(_region.position.y, _region.end.y):
			var tile := Vector2i(x, y)
			var data = tile_map.get_cell_tile_data(0, tile)
			if data == null:
				# No ground there: the edge of the map, which nothing sees across -
				# the same as combat's unpainted cells.
				_stops_sight[tile] = true
				continue
			var blocks = data.get_custom_data("Blocks")
			# Ground-level eyes: stopped by whatever stops somebody walking,
			# unless it is painted see-through.
			if 0 in blocks and not SEE_THROUGH in blocks:
				_stops_sight[tile] = true


## Every tile of the map, for drawing what a guard can see.
func region() -> Rect2i:
	return _region


func stops_sight(tile: Vector2i) -> bool:
	return _stops_sight.has(tile) or not _region.has_point(tile)


## Whether a look from `from` reaches `to`. Walked from the lesser end of the
## pair, as Combat.has_line_of_sight does, so two people always agree about
## whether they can see each other.
func clear(from: Vector2i, to: Vector2i) -> bool:
	if to.x < from.x or (to.x == from.x and to.y < from.y):
		var swap = from
		from = to
		to = swap
	var dx = absi(to.x - from.x)
	var dy = -absi(to.y - from.y)
	var sx = 1 if from.x < to.x else -1
	var sy = 1 if from.y < to.y else -1
	var err = dx + dy
	var x = from.x
	var y = from.y
	while x != to.x or y != to.y:
		var e2 = 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
		if x == to.x and y == to.y:
			continue
		if stops_sight(Vector2i(x, y)):
			return false
	return true


## Whether somebody on `from`, looking along `facing`, sees `to`: inside the
## cone, and with nothing in the way. Their own tile always counts - nobody
## stands on a guard unseen.
func sees(from: Vector2i, facing: Vector2, to: Vector2i, half_cone: float = HALF_CONE_DEGREES) -> bool:
	if from == to:
		return true
	if stops_sight(to):
		return false
	var towards := Vector2(to - from)
	if facing != Vector2.ZERO and absf(rad_to_deg(facing.angle_to(towards))) > half_cone:
		return false
	return clear(from, to)


## Every tile `from` sees looking along `facing` - what is drawn on the map, and
## what spotting is judged by, so the two cannot disagree.
func seen_from(from: Vector2i, facing: Vector2, half_cone: float = HALF_CONE_DEGREES) -> Dictionary:
	var seen := {}
	for x in range(_region.position.x, _region.end.x):
		for y in range(_region.position.y, _region.end.y):
			var tile := Vector2i(x, y)
			if sees(from, facing, tile, half_cone):
				seen[tile] = true
	return seen
