@tool
extends Node2D
class_name NoisyFloor
## Ground that gives somebody away on a stealth map: gravel that crunches,
## puddles that splash, broken glass that crackles. Place it on the top-left
## tile of the patch and say how big the patch is. Walked across at an
## ordinary pace, every step is heard; creeping (hold Ctrl) crosses it
## without a sound, at a crawl.

## What it is. Stored by number, so a new one goes on the end.
enum Kind {
	GRAVEL,        ## Heard 3 tiles off. Guards turn to it.
	PUDDLE,        ## Heard 2.5 tiles off. Guards turn to it.
	BROKEN_GLASS,  ## Heard 4 tiles off - and nobody treads on glass by accident: guards come to look.
}
@export var kind: Kind = Kind.GRAVEL : set = _set_kind
## How big the patch is, in tiles, reaching right and down from the tile it
## is placed on.
@export var size_tiles: Vector2i = Vector2i.ONE : set = _set_size_tiles
## How far a step on it is heard, in tiles. Zero: the kind's own.
@export var heard_tiles: float = 0.0

const HEARD := [3.0, 2.5, 4.0]
const COMES_TO_LOOK := [false, false, true]


func _set_kind(value: Kind):
	kind = value
	queue_redraw()


func _set_size_tiles(value: Vector2i):
	size_tiles = Vector2i(maxi(value.x, 1), maxi(value.y, 1))
	queue_redraw()


## How far a step on it is heard, in tiles.
func noise_tiles() -> float:
	return heard_tiles if heard_tiles > 0.0 else HEARD[kind]


## Whether guards who hear a step on it come to see who it was, rather than
## only turning to it.
func brings_them() -> bool:
	return COMES_TO_LOOK[kind]


## Every tile it covers, given the map tile it is placed on.
func covers(first: Vector2i) -> Array:
	var tiles := []
	for x in size_tiles.x:
		for y in size_tiles.y:
			tiles.append(first + Vector2i(x, y))
	return tiles


func _ready():
	queue_redraw()


## Drawn tile by tile, the same scatter on the same tile every time, so it
## reads as ground rather than as a pattern.
func _draw():
	var tile := float(Grid.TILE_SIZE)
	for x in size_tiles.x:
		for y in size_tiles.y:
			var corner = Vector2(x, y) * tile - Vector2.ONE * tile / 2.0
			var noise := RandomNumberGenerator.new()
			noise.seed = hash(Vector2i(x, y) + Vector2i(int(position.x), int(position.y)))
			match kind:
				Kind.GRAVEL:
					# Warmer and darker than the stone under it, so it reads as
					# something else to walk on.
					draw_rect(Rect2(corner, Vector2.ONE * tile), Color(0.36, 0.3, 0.22, 0.45))
					for i in 40:
						var at = corner + Vector2(noise.randf(), noise.randf()) * tile
						var shade = noise.randf_range(0.28, 0.62)
						draw_circle(at, noise.randf_range(5.0, 12.0), Color(shade, shade * 0.88, shade * 0.7, 0.9))
				Kind.PUDDLE:
					for i in 3:
						var at = corner + Vector2(noise.randf_range(0.2, 0.8), noise.randf_range(0.2, 0.8)) * tile
						var r = noise.randf_range(0.18, 0.3) * tile
						draw_set_transform(at, 0.0, Vector2(1.0, 0.55))
						draw_circle(Vector2.ZERO, r, Color(0.25, 0.4, 0.55, 0.55))
						draw_arc(Vector2.ZERO, r * 0.7, -2.4, -1.2, 12, Color(0.8, 0.9, 1.0, 0.5), 5.0)
						draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				Kind.BROKEN_GLASS:
					for i in 14:
						var at = corner + Vector2(noise.randf(), noise.randf()) * tile
						var turn = noise.randf() * TAU
						var shard = PackedVector2Array([
							at + Vector2(0, -13).rotated(turn), at + Vector2(7, 7).rotated(turn), at + Vector2(-6, 5).rotated(turn)])
						draw_colored_polygon(shard, Color(0.75, 0.9, 1.0, 0.7))
	if Engine.is_editor_hint():
		var outline = Rect2(-Vector2.ONE * tile / 2.0, Vector2(size_tiles) * tile)
		draw_rect(outline, Color(1.0, 0.8, 0.35, 0.9), false, 4.0)
		draw_string(ThemeDB.fallback_font, outline.position + Vector2(8, 28), Kind.keys()[kind].capitalize(),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1.0, 0.8, 0.35, 0.9))
