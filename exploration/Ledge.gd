@tool
@icon("res://art/editor_icons/interactable.svg")
extends Node2D
class_name Ledge
## A sheer edge of raised ground (the proposals of 2026-11-19, "Climbing and shortcuts"; the designer: "Do all"). On a map the party
## climbs onto raised ground anywhere but onto the tiles a Ledge covers: those only from raised ground beside them, or by a Ladder.
## Dropped from anywhere. Placed on its top left tile; covers Size Tiles. A darker lip along its south edge marks it until it has a
## picture of its own. PROPOSAL.

@export var size_tiles: Vector2i = Vector2i(3, 1):
	set(value):
		size_tiles = value
		queue_redraw()


## The tiles it covers, on `tile_map`.
func tiles(tile_map: TileMap) -> Array:
	var corner := tile_map.local_to_map(tile_map.to_local(global_position))
	var found := []
	for y in size_tiles.y:
		for x in size_tiles.x:
			found.append(corner + Vector2i(x, y))
	return found


func _ready():
	if not Engine.is_editor_hint():
		z_as_relative = false
		z_index = ExplorationParty.PARTY_Z_BOTTOM - 1


func _draw():
	var tile := float(Grid.TILE_SIZE)
	var top_left := -Vector2.ONE * tile * 0.5
	var width := size_tiles.x * tile
	var south := top_left.y + size_tiles.y * tile
	# A sheer lip along its south edge, scored downwards: no foothold.
	draw_rect(Rect2(top_left.x, south - tile * 0.08, width, tile * 0.08), Color(0.05, 0.06, 0.12, 0.7))
	for i in int(size_tiles.x * 4):
		var x := top_left.x + (i + 0.5) * tile / 4.0
		draw_line(Vector2(x, south - tile * 0.02), Vector2(x, south + tile * 0.16), Color(0.05, 0.06, 0.12, 0.45), 3.0)
	if Engine.is_editor_hint():
		draw_rect(Rect2(top_left, Vector2(size_tiles) * tile), Color(1.0, 0.5, 0.2, 0.8), false, 3.0)
		draw_string(ThemeDB.fallback_font, top_left + Vector2(8, 28), "Ledge", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1.0, 0.5, 0.2))
