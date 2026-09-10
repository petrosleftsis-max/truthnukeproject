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
@export var point_name: String = ""


## Case-insensitive, so dialogue can say "gate" for a node named "Gate".
func matches(wanted: String) -> bool:
	return _name().to_lower() == wanted.to_lower()


func _name() -> String:
	return point_name if point_name != "" else name


func _ready():
	# A marker is scenery for the author, never for the player.
	visible = false
