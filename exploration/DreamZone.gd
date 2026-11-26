@tool
@icon("res://art/editor_icons/interactable.svg")
extends Node2D
class_name DreamZone
## A stretch of the dream where its rules bend (DreamPlace; the proposals of 2026-11-19, "A dream-place"). Placed on its top left
## tile, Size Tiles across: inside it the party is drawn Figure Scale big, and carried along by Drift (tiles a second, the way it
## goes) as if the ground were tilted. Only to look at and walk in; nothing in a fight. PROPOSAL.

@export var size_tiles: Vector2i = Vector2i(4, 4):
	set(value):
		size_tiles = Vector2i(maxi(value.x, 1), maxi(value.y, 1))
		queue_redraw()
@export_range(0.3, 3.0, 0.05) var figure_scale: float = 1.0
@export var drift: Vector2 = Vector2.ZERO


func covers_rect() -> Rect2:
	var tile := float(Grid.TILE_SIZE)
	return Rect2(global_position - Vector2.ONE * tile / 2.0, Vector2(size_tiles) * tile)


func _draw():
	var tile := float(Grid.TILE_SIZE)
	var rect := Rect2(-Vector2.ONE * tile / 2.0, Vector2(size_tiles) * tile)
	if Engine.is_editor_hint():
		draw_rect(rect, Color(0.8, 0.5, 1.0, 0.12))
		draw_rect(rect, Color(0.85, 0.6, 1.0, 0.8), false, 4.0)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(8, 28), "Dream zone x%.2f" % figure_scale, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.9, 0.75, 1.0))
		return
	# The ground breathing: faint rings, and the drift's way in arrows.
	draw_rect(rect, Color(0.75, 0.55, 1.0, 0.08))
	if drift != Vector2.ZERO:
		var way := drift.normalized()
		for y in size_tiles.y:
			for x in size_tiles.x:
				var at := rect.position + (Vector2(x, y) + Vector2(0.5, 0.5)) * tile
				draw_line(at - way * tile * 0.2, at + way * tile * 0.2, Color(0.85, 0.7, 1.0, 0.35), 4.0)
