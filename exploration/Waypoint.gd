@tool
extends Node2D
class_name Waypoint
## A named spot on a map, for dialogue to send someone to.
##
## Drop one into a map scene, give it a name, and a conversation can say
##
##     do Actors.walk("cyrus", "gate")
##
## rather than naming tile coordinates. Names rather than numbers because a
## conversation should still read correctly after the map is repainted and the
## gate is two tiles further along - and because "gate" says what the scene is
## doing and (12, 7) does not.
##
## Tile coordinates still work anywhere a waypoint name does, for a one-off
## that does not deserve a marker.

## What dialogue calls this spot. Falls back to the node's own name, so a node
## called "Gate" is already reachable as "gate" without filling anything in.
@export var point_name: String = "" : set = _set_point_name


## Case-insensitive, so dialogue can say "gate" for a node named "Gate".
func matches(wanted: String) -> bool:
	return _name().to_lower() == wanted.to_lower()


func _name() -> String:
	return point_name if point_name != "" else name


## Visible while you are placing it and invisible in the game, with no need to
## hide it: a Node2D draws nothing by itself, so this is the whole of its
## appearance and it only happens in the editor.
func _draw():
	if not Engine.is_editor_hint():
		return
	var reach = Grid.TILE_SIZE * 0.4
	draw_circle(Vector2.ZERO, reach * 0.35, Color(0.35, 0.75, 1.0, 0.5))
	draw_line(Vector2(-reach, 0), Vector2(reach, 0), Color(0.35, 0.75, 1.0), 3.0)
	draw_line(Vector2(0, -reach), Vector2(0, reach), Color(0.35, 0.75, 1.0), 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(-reach, -reach * 0.6), _name(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)


func _ready():
	queue_redraw()


func _set_point_name(value: String):
	point_name = value
	queue_redraw()
