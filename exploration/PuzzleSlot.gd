@tool
extends Control
class_name PuzzleSlot
## Where a PuzzlePiece goes, under a Puzzle: a piece dropped near enough snaps
## into it. Size it to the piece meant for it - a torn strip's place in the
## letter, a jar's place on the shelf.

## A faint outline in the game, so the player can see where things go. Off for
## a puzzle that should not say.
@export var show_outline: bool = true

const EDGE := Color(0.92, 0.86, 0.7, 0.35)


func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func centre() -> Vector2:
	return position + size / 2.0


func _draw():
	if not show_outline and not Engine.is_editor_hint():
		return
	var edge = Color(0.4, 0.8, 1.0, 0.8) if Engine.is_editor_hint() else EDGE
	# Dashed, so it reads as a place rather than a thing.
	var corners := [Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y), Vector2.ZERO]
	for side in 4:
		var from: Vector2 = corners[side]
		var to: Vector2 = corners[side + 1]
		var length := from.distance_to(to)
		var at := 0.0
		while at < length:
			draw_line(from.lerp(to, at / length), from.lerp(to, minf(at + 10.0, length) / length), edge, 2.0)
			at += 18.0
	if Engine.is_editor_hint():
		draw_string(ThemeDB.fallback_font, Vector2(6, 20), String(name), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, edge)
