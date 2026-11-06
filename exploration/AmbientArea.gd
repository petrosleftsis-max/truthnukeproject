@tool
@icon("res://art/editor_icons/ambient_area.svg")
extends Node2D
class_name AmbientArea
## Part of a map whose ambient light is its own (Light): a roofed building on an outdoor map, a cave
## on a hillside. Everything in it starts from this instead of the map's ambient light. Its corner is
## where the node stands, and it reaches Size Tiles right and down.

@export var size_tiles: Vector2i = Vector2i(8, 8) : set = _set_size
## Interior or Underground, most often. Stored as Light.Ambient.
@export_enum("Outdoors:1", "Interior:2", "Underground:3") var ambient: int = 2


func _set_size(value: Vector2i):
	size_tiles = value
	queue_redraw()


## The tiles it covers.
func tile_rect(tile_map: TileMap) -> Rect2i:
	return Rect2i(tile_map.local_to_map(tile_map.to_local(global_position)), size_tiles)


func _draw():
	if Engine.is_editor_hint():
		var tile := float(Grid.TILE_SIZE)
		draw_rect(Rect2(Vector2.ZERO, Vector2(size_tiles) * tile), Color(0.55, 0.65, 1.0, 0.8), false, 4.0)
