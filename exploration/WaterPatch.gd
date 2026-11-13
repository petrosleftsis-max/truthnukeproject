@tool
@icon("res://art/editor_icons/water_patch.svg")
extends Node2D
class_name WaterPatch
## Water on a map: a pool, a pond, a ditch, a stretch of river. Place it on the top-left tile of the water and say how big it is,
## as with a Noisy Floor. In the game it moves (LightView "More to look at", the designer, 2026-11-13): it ripples the way the wind
## blows, foams where it meets the land, takes rings when it rains, and the sun glints on it on the side where the sun stands at
## that hour, the moon faintly at night. Lights are mirrored in it, and the low mist of a night lies thicker beside it.
##
## Only to look at: whether anybody can walk into it is the tiles' Blocks, as ever. It is drawn by the light's view, under the
## dark of the night like the ground, so nothing of it is drawn here but in the editor. A picture at art/fx/water.png is laid over
## the water in place of its plain colour (a slot; a placeholder look, like the rest).

## How big the water is, in tiles, reaching right and down from the tile it is placed on.
@export var size_tiles: Vector2i = Vector2i(3, 2) : set = _set_size_tiles
## The water's colour.
@export var colour: Color = Color(0.17, 0.35, 0.47, 0.92) : set = _set_colour
## Foam along its edges, where it meets the land. Off for water against a wall or a quay.
@export var foam: bool = true

const PICTURE := "res://art/fx/water.png"


func _set_size_tiles(value: Vector2i):
	size_tiles = Vector2i(maxi(value.x, 1), maxi(value.y, 1))
	queue_redraw()


func _set_colour(value: Color):
	colour = value
	queue_redraw()


## Every tile it covers, given the map tile it is placed on.
func covers(first: Vector2i) -> Array:
	var tiles := []
	for x in size_tiles.x:
		for y in size_tiles.y:
			tiles.append(first + Vector2i(x, y))
	return tiles


## The tile it is placed on, on `tile_map`.
func first_tile(tile_map: TileMap) -> Vector2i:
	return tile_map.local_to_map(tile_map.to_local(global_position))


func _draw():
	if not Engine.is_editor_hint():
		return
	var tile := float(Grid.TILE_SIZE)
	var outline := Rect2(-Vector2.ONE * tile / 2.0, Vector2(size_tiles) * tile)
	draw_rect(outline, Color(colour, 0.55))
	draw_rect(outline, Color(0.55, 0.85, 1.0, 0.9), false, 4.0)
	draw_string(ThemeDB.fallback_font, outline.position + Vector2(8, 28), "Water", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.75, 0.92, 1.0, 0.95))
