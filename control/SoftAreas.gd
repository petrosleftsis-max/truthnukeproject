extends Node2D
class_name SoftAreas
## Areas on the board as soft patches, not fields of squares (the designer, 2026-11-07, docs/proposals_2026-11-07.md section 13
## A: keep the rules on tiles, stop showing the tiles). View only. CController hands over every area it would mark, and this draws
## them from a mask with one pixel a tile, read with a linear filter: halfway between a tile that is in and a tile that is not is
## exactly the tile's edge, so what shows covers just the tiles the rules go by, with its corners rounded. A little wobble keeps
## the edge from looking ruled.
##
## Two of these sit under the controller's own drawing, one for the fills and one for the edges, as each has its own shader.
## What is told apart by colour is told apart by a pattern as well (Pattern, section 11's "Colour alone").

enum Pattern { PLAIN, STRIPES, DOTS, CROSSES }

const FILL_SHADER := """
shader_type canvas_item;
varying vec4 tint;
varying vec2 world;
void vertex() {
	tint = COLOR;
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
float wobble(vec2 at) {
	return (sin(at.x * 0.021 + sin(at.y * 0.017) * 2.0) + sin(at.y * 0.027 + sin(at.x * 0.013) * 2.0)) * 0.01;
}
void fragment() {
	vec4 mask = texture(TEXTURE, UV);
	vec2 d = TEXTURE_PIXEL_SIZE * 0.3;
	vec2 e = TEXTURE_PIXEL_SIZE * 0.42;
	float a = mask.a * 2.0 + texture(TEXTURE, UV + d).a + texture(TEXTURE, UV - d).a + texture(TEXTURE, UV + vec2(d.x, -d.y)).a + texture(TEXTURE, UV + vec2(-d.x, d.y)).a
		+ texture(TEXTURE, UV + vec2(e.x, 0.0)).a + texture(TEXTURE, UV - vec2(e.x, 0.0)).a + texture(TEXTURE, UV + vec2(0.0, e.y)).a + texture(TEXTURE, UV - vec2(0.0, e.y)).a;
	a /= 10.0;
	float inside = smoothstep(0.43, 0.53, a + wobble(world));
	float pattern = mask.r * 4.0;
	float shape = 1.0;
	if (pattern > 0.5 && pattern < 1.5) {
		shape = mix(0.35, 1.0, smoothstep(0.4, 0.5, abs(fract((world.x + world.y) / 72.0) - 0.5)));
	} else if (pattern > 1.5 && pattern < 2.5) {
		vec2 cell = fract(world / 64.0) - 0.5;
		shape = mix(0.45, 1.0, 1.0 - smoothstep(0.2, 0.26, length(cell)));
	} else if (pattern > 2.5) {
		vec2 cell = abs(fract(world / 64.0) - 0.5);
		shape = mix(0.45, 1.0, 1.0 - smoothstep(0.05, 0.08, min(cell.x, cell.y)));
	}
	COLOR = vec4(tint.rgb, tint.a * inside * shape);
}
"""

## The edge's width is on the screen: how far a pixel is from the outline, by how fast the mask changes there, so it is one thin line
## whatever the zoom, and doesn't swell where two corners touch.
const EDGE_SHADER := """
shader_type canvas_item;
varying vec4 tint;
varying vec2 world;
void vertex() {
	tint = COLOR;
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
float wobble(vec2 at) {
	return (sin(at.x * 0.021 + sin(at.y * 0.017) * 2.0) + sin(at.y * 0.027 + sin(at.x * 0.013) * 2.0)) * 0.01;
}
void fragment() {
	vec4 mask = texture(TEXTURE, UV);
	vec2 d = TEXTURE_PIXEL_SIZE * 0.3;
	vec2 e = TEXTURE_PIXEL_SIZE * 0.42;
	float a = mask.a * 2.0 + texture(TEXTURE, UV + d).a + texture(TEXTURE, UV - d).a + texture(TEXTURE, UV + vec2(d.x, -d.y)).a + texture(TEXTURE, UV + vec2(-d.x, d.y)).a
		+ texture(TEXTURE, UV + vec2(e.x, 0.0)).a + texture(TEXTURE, UV - vec2(e.x, 0.0)).a + texture(TEXTURE, UV + vec2(0.0, e.y)).a + texture(TEXTURE, UV - vec2(0.0, e.y)).a;
	a = a / 10.0 + wobble(world);
	float half_width = mask.g * 32.0 * 0.2;
	float slope = max(length(vec2(dFdx(a), dFdy(a))), 0.00005);
	float away = abs(a - 0.48) / slope;
	COLOR = vec4(tint.rgb, tint.a * (1.0 - smoothstep(half_width - 0.6, half_width + 0.8, away)));
}
"""

const MOST_KEPT := 128
## One size a tile, as the masks are drawn.
static var _masks := {}
static var _fill_shader: Shader = null
static var _edge_shader: Shader = null

var edges := false
var _list: Array = []


func _init(for_edges: bool = false):
	edges = for_edges
	show_behind_parent = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var material_made := ShaderMaterial.new()
	if _fill_shader == null:
		_fill_shader = Shader.new()
		_fill_shader.code = FILL_SHADER
		_edge_shader = Shader.new()
		_edge_shader.code = EDGE_SHADER
	material_made.shader = _edge_shader if edges else _fill_shader
	material = material_made


## What is to be drawn, as CController's `_draw` found it: {"tiles", "fill", "edge", "width", "pattern", "at"}. `at` turns a tile
## into its top-left corner on the map.
func show_list(list: Array):
	_list = list
	queue_redraw()


func _draw():
	for area in _list:
		var colour: Color = area.edge if edges else area.fill
		if colour.a <= 0.0:
			continue
		var made: Dictionary = mask_of(area.tiles, area.pattern, area.width)
		var rect := Rect2(area.at.call(made.corner), Vector2(made.size) * float(Grid.TILE_SIZE))
		draw_texture_rect(made.texture, rect, false, colour)


## The mask for `tiles`: a pixel a tile, a tile's margin all round, with the pattern and the edge's width in its colour since
## a shader has no other way to be told per area. Kept, since the same areas are drawn over and over as the pointer moves.
static func mask_of(tiles: Array, pattern: int, width: float) -> Dictionary:
	var key := [tiles, pattern, width].hash()
	if _masks.has(key):
		return _masks[key]
	var least := Vector2i(tiles[0])
	var most := Vector2i(tiles[0])
	for tile in tiles:
		least = Vector2i(mini(least.x, tile.x), mini(least.y, tile.y))
		most = Vector2i(maxi(most.x, tile.x), maxi(most.y, tile.y))
	var corner: Vector2i = least - Vector2i.ONE
	var size: Vector2i = most - least + Vector2i(3, 3)
	var image := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	var base := Color(float(pattern) / 4.0, clampf(width / 32.0, 0.0, 1.0), 0.0, 0.0)
	image.fill(base)
	for tile in tiles:
		image.set_pixelv(Vector2i(tile) - corner, Color(base.r, base.g, base.b, 1.0))
	if _masks.size() >= MOST_KEPT:
		_masks.clear()
	var made := {"texture": ImageTexture.create_from_image(image), "corner": corner, "size": size}
	_masks[key] = made
	return made
