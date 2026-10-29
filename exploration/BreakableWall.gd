@tool
@icon("res://art/editor_icons/breakable_wall.svg")
extends Node2D
class_name BreakableWall
## A wall on a map that a damaging move breaks (OutsideMoves, the designer
## 2026-10-26): place it on a floor tile. Standing, nobody walks or sees through
## it, as a shut door; any damaging move used beside it - within the move's reach,
## when no unaware guard is nearer to spring an ambush on - knocks it down, for
## good, and loudly. Kept broken in the flags ("broken:" and where it is), so it
## stays down through fights and saves.

## The flag it is kept broken in. Empty: one made from the map and the node's
## name, which is enough unless the node is renamed.
@export var flag: String = ""
## What it looks like - empty for a drawn stone wall.
@export var look: Texture2D : set = _set_look
## How big `look` is drawn, as a share of a tile.
@export var look_scale: float = 1.0 : set = _set_look_scale

const STONE := Color(0.46, 0.44, 0.42)
const MORTAR := Color(0.3, 0.28, 0.27)
const CRACK := Color(0.16, 0.14, 0.13)

## Whether it has been knocked down.
var broken := false : set = _set_broken


func _set_look(value: Texture2D):
	look = value
	queue_redraw()


func _set_look_scale(value: float):
	look_scale = value
	queue_redraw()


func _set_broken(value: bool):
	broken = value
	queue_redraw()


func _ready():
	z_as_relative = false
	z_index = ExplorationParty.PARTY_Z_TOP - 2


## The flag it is kept broken in, on the map at `map_path`.
func flag_for(map_path: String) -> String:
	return flag if flag != "" else "broken:%s::%s" % [map_path, name]


func _draw():
	var tile := float(Grid.TILE_SIZE)
	var half := tile / 2.0
	if broken:
		# Rubble where it stood.
		for at in [Vector2(-0.25, 0.2), Vector2(0.15, 0.3), Vector2(0.3, -0.1), Vector2(-0.1, -0.2)]:
			draw_circle(at * tile, tile * 0.08, MORTAR)
		return
	if look != null:
		var size := look.get_size() * look_scale * tile / maxf(look.get_size().x, 1.0)
		draw_texture_rect(look, Rect2(-size / 2.0, size), false)
	else:
		draw_rect(Rect2(-half, -half, tile, tile), STONE)
		for row in 4:
			var y := -half + tile * row / 4.0
			draw_line(Vector2(-half, y), Vector2(half, y), MORTAR, 4.0)
			var offset := tile / 4.0 if row % 2 == 1 else 0.0
			for column in 3:
				var x := -half + offset + tile * column / 2.0
				if x > -half and x < half:
					draw_line(Vector2(x, y), Vector2(x, y + tile / 4.0), MORTAR, 4.0)
		var crack := PackedVector2Array()
		for point in [Vector2(-0.1, -0.5), Vector2(0.05, -0.2), Vector2(-0.08, 0.05), Vector2(0.1, 0.35)]:
			crack.append(point * tile)
		draw_polyline(crack, CRACK, 5.0)
		draw_rect(Rect2(-half, -half, tile, tile), MORTAR, false, 6.0)
	if Engine.is_editor_hint():
		draw_string(ThemeDB.fallback_font, Vector2(-half + 8, -half + 28), "Breakable", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1.0, 0.85, 0.3, 0.9))
