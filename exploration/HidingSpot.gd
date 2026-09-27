@tool
extends Node2D
class_name HidingSpot
## Somewhere to hide on a stealth map: behind barrels, in a locker, in a dark
## alcove. Place it on a floor tile. Whoever stands on its tile cannot be seen
## by a guard unless the guard is right beside it - though a dog's nose still
## finds them, and a guard who saw them step in walks over to look.
##
## One spot hides one person: a party of two needs two spots side by side, or
## the one following behind is left standing in the open. A knocked-out guard
## stuffed into it fills it for good - hidden from every guard, and nowhere to
## hide any more.

## What it looks like - barrels, a crate. Empty: a patch of shadow only.
@export var look: Texture2D : set = _set_look
## How big `look` is drawn, as a share of a tile.
@export var look_scale: float = 1.0 : set = _set_look_scale

const SHADOW := Color(0.0, 0.0, 0.0, 0.45)
const EDITOR_EDGE := Color(0.45, 0.85, 1.0, 0.9)
## How a spot with a body in it is drawn: darker, so it reads as taken.
const FULL_TINT := Color(0.5, 0.45, 0.45)

## The guard stuffed in here, if any. Set by the StealthWatch.
var holds_body: Node2D = null : set = _set_holds_body


func _set_holds_body(value: Node2D):
	holds_body = value
	queue_redraw()


## Whether somebody could still hide here.
func is_free() -> bool:
	return holds_body == null


func _set_look(value: Texture2D):
	look = value
	queue_redraw()


func _set_look_scale(value: float):
	look_scale = value
	queue_redraw()


func _ready():
	# Under the party, so whoever hides is drawn in front of the spot rather
	# than vanishing behind it.
	z_as_relative = false
	z_index = ExplorationParty.PARTY_Z_TOP - 1
	queue_redraw()


func _draw():
	var tile := Vector2(Grid.TILE_SIZE, Grid.TILE_SIZE)
	draw_circle(Vector2(0, Grid.tiles(0.18)), Grid.tiles(0.42), SHADOW)
	if look != null:
		var size = tile * look_scale
		draw_texture_rect(look, Rect2(-size / 2.0, size), false, Color.WHITE if is_free() else FULL_TINT)
	elif not is_free():
		draw_circle(Vector2(0, Grid.tiles(0.18)), Grid.tiles(0.3), SHADOW)
	if Engine.is_editor_hint():
		draw_rect(Rect2(-tile / 2.0, tile), EDITOR_EDGE, false, 4.0)
		draw_string(ThemeDB.fallback_font, Vector2(-tile.x / 2.0 + 8, -tile.y / 2.0 + 28), "Hide",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 26, EDITOR_EDGE)
