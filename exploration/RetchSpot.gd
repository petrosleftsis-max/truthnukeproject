@tool
extends Node2D
class_name RetchSpot
## Where a guard given an emetic goes to be sick: a latrine, a bucket, an open
## window. Place it on a floor tile; a guard goes to the nearest one, and with
## none on the map, is sick where he stands.

const WOOD := Color(0.4, 0.3, 0.2)
const DARK := Color(0.14, 0.11, 0.09)


func _ready():
	z_as_relative = false
	z_index = ExplorationParty.PARTY_Z_TOP - 2
	queue_redraw()


func _draw():
	var tile := float(Grid.TILE_SIZE)
	# A bucket.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-tile * 0.2, -tile * 0.15), Vector2(tile * 0.2, -tile * 0.15),
		Vector2(tile * 0.15, tile * 0.25), Vector2(-tile * 0.15, tile * 0.25)]), WOOD)
	draw_rect(Rect2(-tile * 0.2, -tile * 0.18, tile * 0.4, tile * 0.07), DARK)
	draw_arc(Vector2(0, -tile * 0.15), tile * 0.2, PI, TAU, 16, DARK, 4.0)
	if Engine.is_editor_hint():
		draw_string(ThemeDB.fallback_font, Vector2(-tile / 2.0 + 8, -tile / 2.0 + 28), "Retch here",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.55, 0.85, 0.35))
