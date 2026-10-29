@tool
@icon("res://art/editor_icons/small_gap.svg")
extends Node2D
class_name SmallGap
## A gap in a wall only something Small or smaller fits through - a grate, a
## drain, a hole under a fence (ExplorationScene "Small gaps"). Place it on a
## wall tile, between floor on either side: nobody in the party gets through,
## a familiar does (Find Familiar). Still a wall to everybody's eyes.
##
## The same as a tile whose Blocks has 4, for a map whose tileset has none.

const BARS := Color(0.22, 0.22, 0.25)
const DARK := Color(0.05, 0.05, 0.07)


func _ready():
	z_as_relative = false
	z_index = ExplorationParty.PARTY_Z_TOP - 3


func _draw():
	var tile := float(Grid.TILE_SIZE)
	var half := tile * 0.32
	draw_rect(Rect2(-half, -half, half * 2.0, half * 2.0), DARK)
	for i in range(1, 5):
		var x := -half + half * 2.0 * i / 5.0
		draw_line(Vector2(x, -half), Vector2(x, half), BARS, 7.0)
	draw_rect(Rect2(-half, -half, half * 2.0, half * 2.0), BARS, false, 8.0)
	if Engine.is_editor_hint():
		draw_string(ThemeDB.fallback_font, Vector2(-tile / 2.0 + 8, -tile / 2.0 + 28), "Small gap", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1.0, 0.85, 0.3, 0.9))
