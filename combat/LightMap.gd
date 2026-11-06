extends RefCounted
class_name LightMap
## Which tile is how lit: worked out afresh from the ambient light, the ambient areas, the sources
## and whatever darkness lies over them (Light). The same for a fight and a map; StealthWatch and
## Combat say what is lighting what, and LightView draws it.

## The level of every tile nothing else has a say on.
var base: int = Light.Level.BRIGHT
## tile -> Light.Level, where that is not `base`.
var levels := {}
## tile -> how lit it looks, 0 to 1, for drawing: it fades, where the level steps.
var amounts := {}
## tile -> the colour of the light on it, for drawing.
var glow := {}
## Whether anywhere is anything but Bright, so whether light has any say at all.
var varies := false
## Whether any source here flickers, for drawing.
var flickers := false

var _blocked := {}


func level_at(tile: Vector2i) -> int:
	return levels.get(tile, base)


func amount_at(tile: Vector2i) -> float:
	return amounts.get(tile, Light.AMOUNTS[base])


func clear():
	base = Light.Level.BRIGHT
	levels = {}
	amounts = {}
	glow = {}
	varies = false
	flickers = false


## Lights it all: `base_level`; `areas`, each {"rect", "level"}; `sources`, each {"tile", "bright", "dim",
## "colour", "flickers"} in tiles; `dark_tiles`, forced dark whatever lights them (Light Void);
## `blocks` says whether a tile stops light.
func rebuild(base_level: int, areas: Array, sources: Array, dark_tiles: Array, blocks: Callable):
	clear()
	base = base_level
	_blocked = {}
	for area in areas:
		var rect: Rect2i = area.rect
		for x in range(rect.position.x, rect.end.x):
			for y in range(rect.position.y, rect.end.y):
				var tile := Vector2i(x, y)
				levels[tile] = area.level
				amounts[tile] = Light.AMOUNTS[area.level]
	for source in sources:
		_shine(source, blocks)
	for tile in dark_tiles:
		levels[tile] = Light.Level.DARK
		amounts[tile] = 0.0
		glow.erase(tile)
	varies = base != Light.Level.BRIGHT or levels.values().any(func(level): return level != Light.Level.BRIGHT)
	_blocked = {}


func _shine(source: Dictionary, blocks: Callable):
	var from: Vector2i = source.tile
	var bright: float = source.bright
	var dim: float = maxf(source.dim, bright)
	var colour: Color = source.get("colour", Color.WHITE)
	if source.get("flickers", false):
		flickers = true
	var reach := ceili(dim)
	for dx in range(-reach, reach + 1):
		for dy in range(-reach, reach + 1):
			var d := Vector2(dx, dy).length()
			if d > dim:
				continue
			var tile := from + Vector2i(dx, dy)
			if tile != from and not _clear(from, tile, blocks):
				continue
			var level: int = Light.Level.BRIGHT if bright > 0.0 and d <= bright else Light.Level.DIM
			if level > level_at(tile):
				levels[tile] = level
			var amount := _falloff(d, bright, dim)
			if amount > amount_at(tile):
				amounts[tile] = amount
			# The colour of the nearest flame, as strong as it is here.
			var strength := amount * 0.55
			if strength > glow.get(tile, Color(0, 0, 0, 0)).a:
				glow[tile] = Color(colour, strength)


## Bright full at the flame, easing off to the edge of Bright, then away through Dim to nothing.
static func _falloff(d: float, bright: float, dim: float) -> float:
	if d <= bright:
		return 1.0 - 0.3 * pow(d / maxf(bright, 0.01), 2.0)
	var t: float = (d - bright) / maxf(dim - bright, 0.01)
	return 0.7 * pow(1.0 - t, 1.5) if bright > 0.0 else 0.55 * pow(1.0 - t, 1.5)


## Whether nothing that stops light stands between the two, walked tile by tile.
func _clear(from: Vector2i, to: Vector2i, blocks: Callable) -> bool:
	var delta := to - from
	var steps := maxi(absi(delta.x), absi(delta.y))
	for step in range(1, steps):
		var at := Vector2(from) + Vector2(delta) * (float(step) / float(steps))
		var tile := Vector2i(roundi(at.x), roundi(at.y))
		if not _blocked.has(tile):
			_blocked[tile] = blocks.call(tile)
		if _blocked[tile]:
			return false
	return true
