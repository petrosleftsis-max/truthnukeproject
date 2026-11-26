@tool
@icon("res://art/editor_icons/interactable.svg")
extends Node2D
class_name Ladder
## A ladder up a Ledge (the proposals of 2026-11-19, "Climbing and shortcuts"; the designer: "Do all"): the party climbs the ledge
## where it stands. Placed on the ledge's tile it leans against, or the floor tile before it. A placeholder ladder until it has a
## Picture. PROPOSAL.

@export var picture: Texture2D:
	set(value):
		picture = value
		queue_redraw()


func _ready():
	if not Engine.is_editor_hint():
		z_as_relative = false
		z_index = ExplorationParty.PARTY_Z_BOTTOM + 1


func _draw():
	var tile := float(Grid.TILE_SIZE)
	if picture != null:
		draw_texture(picture, -picture.get_size() * 0.5)
		return
	var wood := Color("8a6038")
	var dark := Color("3e2a16")
	for side in [-1.0, 1.0]:
		var x: float = side * tile * 0.22
		draw_line(Vector2(x, -tile * 0.5), Vector2(x, tile * 0.45), dark, 9.0)
		draw_line(Vector2(x, -tile * 0.5), Vector2(x, tile * 0.45), wood, 5.0)
	for i in 5:
		var y := -tile * 0.42 + i * tile * 0.2
		draw_line(Vector2(-tile * 0.22, y), Vector2(tile * 0.22, y), wood, 6.0)
