@tool
@icon("res://art/editor_icons/spawn_marker.svg")
extends EscapeMarker
class_name ClimbMarker
## Editor-only. One climb tile placed on the map in the encounter editor
## (EncounterDefinition.climb_points) - where a walker can climb up onto the high
## ground beside it, or up the stairs to a floor above (Combat "Heights"). Drag
## it; duplicate it (Ctrl+D) for another; delete it to take it away.
## EncounterEditor writes them back when you save.

const CLIMB_FILL := Color(0.85, 0.65, 0.4, 0.3)
const CLIMB_EDGE := Color(0.95, 0.75, 0.45, 0.95)


func _draw():
	if not Engine.is_editor_hint():
		return
	var half = tile_size * 0.5
	var box = Rect2(-half, -half, tile_size, tile_size)
	draw_rect(box, CLIMB_FILL)
	draw_rect(box, CLIMB_EDGE, false, 4.0)
	var font = ThemeDB.fallback_font
	var label = "Climb"
	var width = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(font, Vector2(-width * 0.5, 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
