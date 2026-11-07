@tool
@icon("res://art/editor_icons/grid.svg")
extends Node2D
class_name GridOverlay
## The tile grid drawn over a map, worked out from the map itself.
##
## It used to be a second TileMap with the grid hand-painted onto it, which
## meant the grid was only ever right for the map it was painted against: it
## stayed a 21x17 patch in the top-left while the maps grew to 35x22 and 42x26,
## covered tiles that had nothing painted under them, and would have had to be
## repainted in every terrain scene each time a map changed size.
##
## Drawn instead, from the sibling TileMap's own painted cells, so it always
## covers exactly the map and nothing else - including the holes in a
## non-rectangular one, which stay holes. Nothing to repaint, and changing the
## tile size changes only Grid.TILE_SIZE.
##
## Hidden by default. The encounter editor turns it on while placing units,
## which is the one place a grid actually helps.
##
## In a fight `fades` is on (CController "The board without its squares"): the lines show as much as `whole` everywhere and `near`
## within `near_reach` of `pointer`, by a shader, and otherwise not at all.

## How thick the lines are, in world units. Scaled off the tile so it stays a
## hairline at any tile size rather than a fence at 192 and invisible at 32.
const LINE_WIDTH_RATIO := 0.012
## In a fight, thinner than that.
const FADING_WIDTH_RATIO := 0.006

const FADE_SHADER := """
shader_type canvas_item;
uniform vec2 pointer = vec2(0.0);
uniform float near_reach = 1000.0;
uniform float whole = 0.0;
uniform float near = 0.0;
varying vec2 world;
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	float close = 1.0 - smoothstep(near_reach * 0.45, near_reach, distance(world, pointer));
	COLOR.a *= max(whole, near * close);
}
"""

var fades := false:
	set(value):
		fades = value
		if fades and material == null:
			var shader := Shader.new()
			shader.code = FADE_SHADER
			var made := ShaderMaterial.new()
			made.shader = shader
			material = made
		apply()
		queue_redraw()
var whole := 0.0
var near := 0.0
var near_reach := 1000.0
var pointer := Vector2.ZERO


## Puts what is wanted on the shader.
func apply():
	if material is ShaderMaterial:
		material.set_shader_parameter("whole", whole)
		material.set_shader_parameter("near", near)
		material.set_shader_parameter("near_reach", near_reach)
		material.set_shader_parameter("pointer", pointer)


func _ready():
	# The map is a sibling, and a sibling's own _ready may not have run yet when
	# this one does. One frame is enough for the whole scene to exist.
	if not is_node_ready():
		await ready
	queue_redraw()


func _draw():
	var tile_map = _tile_map()
	if tile_map == null:
		return
	var width = maxf(Grid.TILE_SIZE * (FADING_WIDTH_RATIO if fades else LINE_WIDTH_RATIO), 1.0)
	var size = Vector2(Grid.TILE_VECTOR)
	for cell in tile_map.get_used_cells(0):
		draw_rect(Rect2(Vector2(cell) * Grid.TILE_SIZE, size), Color.WHITE, false, width)


## The map this grid belongs to: the TileMap beside it, by the name the rest of
## the game already addresses terrain by.
func _tile_map() -> TileMap:
	var parent = get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("TileMap")
