@tool
@icon("res://art/editor_icons/interactable.svg")
extends Node2D
class_name LoopingCorridor
## A corridor of the archive that goes on until you notice what is wrong (the proposals of 2026-11-19, "The archive that
## rearranges"; the designer: "Do all"). Placed where the loop begins, Loop Tiles long the way it runs (Way): walking past its far end
## the party is back at its start, the view with them, as if nothing had happened - until Breaks On Flag is set (by reading the one
## note in it that is out of place, say), and from then on it is a corridor. PROPOSAL.

@export var way: Vector2i = Vector2i(1, 0):
	set(value):
		way = value
		queue_redraw()
@export var loop_tiles: int = 8:
	set(value):
		loop_tiles = maxi(value, 2)
		queue_redraw()
## How wide the corridor is, across its way, in tiles.
@export var width_tiles: int = 1
@export var breaks_on_flag: String = ""

## For a suite: how many times it has looped the party.
var loops := 0


func _scene() -> Node:
	var up := get_parent()
	while up != null:
		if up.has_method("party_position") and up.get("party") != null:
			return up
		up = up.get_parent()
	return null


func is_broken() -> bool:
	return breaks_on_flag != "" and Campaign.flag(breaks_on_flag)


func _process(_delta: float):
	if Engine.is_editor_hint() or is_broken():
		return
	var scene := _scene()
	if scene == null:
		return
	var at: Vector2 = scene.party_position() - global_position
	var along := at.dot(Vector2(way))
	var across := absf(at.dot(Vector2(-way.y, way.x)))
	if across > Grid.tiles(width_tiles * 0.5 + 0.5) or along < Grid.tiles(loop_tiles):
		return
	loop_back(scene)


## Back to the start, the view with them, so nothing seems to have changed.
func loop_back(scene: Node):
	var back := -Vector2(way) * Grid.tiles(loop_tiles)
	var party = scene.party
	party.teleport(scene.party_position() + back)
	var camera = scene.get("camera")
	if camera != null:
		camera.position += back
	for key in ["_view_want", "_view_was"]:
		var value = scene.get(key)
		if value is Vector2:
			scene.set(key, value + back)
	loops += 1


func _draw():
	if not Engine.is_editor_hint():
		return
	var tile := float(Grid.TILE_SIZE)
	var end := Vector2(way) * tile * loop_tiles
	draw_line(Vector2.ZERO, end, Color(0.95, 0.5, 0.9, 0.8), 6.0)
	draw_circle(end, 12.0, Color(0.95, 0.5, 0.9, 0.8))
	draw_string(ThemeDB.fallback_font, Vector2(8, -12), "Loops back (%d)" % loop_tiles, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1.0, 0.7, 0.95))
