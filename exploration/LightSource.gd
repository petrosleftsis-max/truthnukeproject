@tool
@icon("res://art/editor_icons/light_source.svg")
extends Node2D
class_name LightSource
## A light on a map or a fight's terrain (Light): everything within Bright Tiles that it has a clear
## line to is Bright, and on out to Dim Tiles it is Dim. Walls stop it. Tick Opening for a cave mouth,
## a hole in the roof or a window, which lets in only what the sun gives: all of it by day, only
## the Dim at dusk and dawn, nothing at night.

@export var bright_tiles: float = 3.0 : set = _set_bright
@export var dim_tiles: float = 6.0 : set = _set_dim
## The colour of the light on the ground. A placeholder look, like the rest.
@export var colour: Color = Color(1.0, 0.74, 0.42)
## Whether it is giving light to begin with.
@export var lit: bool = true
## A way in for the sun, not a flame of its own.
@export var opening: bool = false
## Whether it breathes, as a flame does.
@export var flickers: bool = true
## Whether a small flame is drawn where it stands, for one with no art of its own to stand on.
@export var shows_flame: bool = true


func _set_bright(value: float):
	bright_tiles = maxf(value, 0.0)
	queue_redraw()


func _set_dim(value: float):
	dim_tiles = maxf(value, 0.0)
	queue_redraw()


## What it gives now, as LightMap wants it, or nothing.
func source_now(tile_map: TileMap, time: int) -> Dictionary:
	if not lit:
		return {}
	var bright := bright_tiles
	var dim := dim_tiles
	if opening:
		var shares: Array = Light.opening_shares(time)
		bright *= shares[0]
		dim *= shares[1]
	if dim <= 0.0 and bright <= 0.0:
		return {}
	return {"tile": tile_map.local_to_map(tile_map.to_local(global_position)), "bright": bright, "dim": dim,
		"colour": colour, "flickers": flickers and not opening}


func _draw():
	if Engine.is_editor_hint():
		var tile := float(Grid.TILE_SIZE)
		draw_arc(Vector2.ZERO, tile * bright_tiles, 0.0, TAU, 48, Color(colour, 0.9), 4.0)
		draw_arc(Vector2.ZERO, tile * dim_tiles, 0.0, TAU, 48, Color(colour, 0.45), 3.0)
	if shows_flame and not opening and lit:
		var size := float(Grid.TILE_SIZE) * 0.16
		draw_circle(Vector2.ZERO, size, Color(colour, 0.95))
		draw_circle(Vector2.ZERO, size * 0.5, Color(1.0, 0.95, 0.8))
