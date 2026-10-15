@tool
@icon("res://art/editor_icons/spawn_marker.svg")
extends Node2D
class_name EscapeMarker
## Editor-only. One way out of the fight placed on the map in the encounter
## editor (EncounterDefinition.escape_points) - a tile a broken enemy runs for,
## and is gone once it stands on. Drag it; duplicate it (Ctrl+D) for another;
## delete it to take it away. EncounterEditor writes them back when you save.


## Set by EncounterEditor from the map being previewed.
@export var tile_size := Grid.TILE_SIZE

const FILL := Color(0.95, 0.85, 0.3, 0.3)
const EDGE := Color(1.0, 0.85, 0.25, 0.95)


func _process(_delta):
	if not Engine.is_editor_hint():
		return
	# Snapped to the centre of whatever tile it has been dragged onto, like a
	# spawn marker, so it is always on exactly one tile.
	var target = Vector2(grid_position() * tile_size) + Vector2(tile_size, tile_size) * 0.5
	if position != target:
		position = target


## The tile this marker is on.
func grid_position() -> Vector2i:
	return Vector2i(floori(position.x / tile_size), floori(position.y / tile_size))


func _draw():
	if not Engine.is_editor_hint():
		return
	var half = tile_size * 0.5
	var box = Rect2(-half, -half, tile_size, tile_size)
	draw_rect(box, FILL)
	draw_rect(box, EDGE, false, 4.0)
	var font = ThemeDB.fallback_font
	var label = "Way out"
	var width = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(font, Vector2(-width * 0.5, 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
