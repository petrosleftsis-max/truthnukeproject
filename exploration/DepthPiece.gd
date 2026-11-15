@tool
@icon("res://art/editor_icons/depth_piece.svg")
extends Node2D
class_name DepthPiece
## A layer over or under the ground (Depth "B. Layers and parallax"; docs/depth_on_maps.md; the designer and their artist,
## 2026-11-13). Placed on a tile; in a terrain scene it shows in the map and in its fights. Only to look at: nothing here says who
## can see, reach or walk where, and headless none of it is drawn (LightView.shown). Every number is a PROPOSAL.
##
## In Front, it is drawn over everybody, Height pixels above the ground it stands over: an arch over a way, a roof over a room, a
## balcony, a tree's crown. Whoever the player can see under it is seen through it, in a round patch about them - the cutaway, as
## for walls - and a Roof fades away whole while one of the party is under it or near it (Depth.ROOF_NEAR_TILES), so a room reads
## as indoors from outside and opens as they walk in (the designer: "roofs that fade when the player walks under and close to
## them... if it would be a good way to show what area is indoors").
##
## Behind, it is drawn under the ground and seen only where no tile is painted, and only through the ground it stands over (its
## Size Tiles are a window): roofs far below, a sky.
##
## Moves: what stands free slides against the ground as the view moves (Depth.piece_offset) - a tree's crown away from the view's
## middle, as the top of something tall does seen from above; what is behind lags after the view. Exactly in place when the view is
## centred on it.
##
## The Picture is the artist's slot. Empty, a placeholder is drawn in code by Kind.

enum Kind { ARCH, ROOF, BALCONY, TREE, BACKDROP }
enum Layer { IN_FRONT, BEHIND }

## The artist's picture, stretched over what the piece covers (a tree's over its crown). Empty: a placeholder, by Kind.
@export var picture: Texture2D = null : set = _set_picture
## What it is. It decides what the placeholder looks like, and two things more: a Roof fades away whole for the party, and a Tree
## stands on its own tile with its crown, Size Tiles big, over the top of its trunk.
@export var kind: Kind = Kind.ARCH : set = _set_kind
## How much ground it stands over, right and down from the tile it is on (a Tree: how big its crown is).
@export var size_tiles: Vector2i = Vector2i.ONE : set = _set_size
## In Front: over everybody. Behind: under the ground, seen where no tile is painted.
@export var layer: Layer = Layer.IN_FRONT : set = _set_layer
## In Front: how many pixels above the ground it is drawn. A wall's top is 160 up and raised ground's 80, so 160 rests it on the
## walls. A Tree: how tall its trunk is.
@export var height: float = 160.0 : set = _set_height
## How far it moves against the ground as the view moves, as a share of how far the view's middle is from it. Below 0: as its kind
## does (a Tree 0.12, anything Behind 0.5, the rest stay where they are, since they rest on walls).
@export_range(-1.0, 1.0, 0.01) var moves: float = -1.0
## In Front: whether it is seen through about whoever is under it, and a Roof whether it fades for the party. Off: always whole.
@export var fades: bool = true
## Behind: shown wherever no tile is painted, all round the map and as far as the view goes, with no end to it; Size Tiles are
## not used, and a Picture is repeated. Off: only through the ground it stands over.
@export var everywhere: bool = false : set = _set_everywhere

## See-through about whoever it covers, faded whole, and - behind the ground - seen only through its own window.
const PIECE_SHADER := """
shader_type canvas_item;
uniform vec3 cuts[24];
uniform vec2 cut_shapes[24];
uniform int cut_count = 0;
uniform float cut_alpha = 0.16;
uniform float cut_soft = 0.3;
uniform float fade = 1.0;
uniform vec4 window = vec4(0.0);
uniform float windowed = 0.0;
// Where the map has a tile, a pixel a tile: a piece behind the ground is kept off them.
uniform sampler2D painted : filter_nearest, repeat_disable;
uniform vec4 painted_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float masked = 0.0;
varying vec2 world;
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	vec4 colour = COLOR;
	float left = fade;
	for (int i = 0; i < cut_count; i++) {
		float far = length((world - cuts[i].xy + vec2(0.0, cut_shapes[i].x)) / vec2(max(cuts[i].z, 1.0), max(cut_shapes[i].y, 1.0)));
		left = min(left, mix(cut_alpha * fade, fade, smoothstep(1.0 - cut_soft, 1.0, far)));
	}
	if (windowed > 0.5 && (world.x < window.x || world.y < window.y || world.x > window.x + window.z || world.y > window.y + window.w)) {
		left = 0.0;
	}
	if (masked > 0.5) {
		vec2 on_map = (world - painted_rect.xy) / painted_rect.zw;
		if (on_map.x >= 0.0 && on_map.y >= 0.0 && on_map.x < 1.0 && on_map.y < 1.0 && texture(painted, on_map).r > 0.5) {
			left = 0.0;
		}
	}
	colour.a *= left;
	COLOR = colour;
}
"""

## The placeholders' colours.
const ROOF_TILE := Color(0.56, 0.29, 0.22)
const STONE := Color(0.27, 0.28, 0.27)
const WOOD := Color(0.45, 0.31, 0.2)
const BARK := Color(0.31, 0.22, 0.15)
const LEAF := Color(0.16, 0.36, 0.2)
const HAZE := Color(0.33, 0.39, 0.5)
## How big a far roof of the Backdrop's placeholder is, in pixels, and how thick the haze over them.
const FAR_ROOF := Vector2(176.0, 128.0)
const FAR_HAZE := 0.5
## How see-through a piece behind the ground is drawn in the editor, so the map under it can still be worked on.
const EDITOR_BEHIND_ALPHA := 0.5


## What is drawn of it: a child, so it can move against the ground.
class _Canvas extends Node2D:
	var piece: Node2D = null

	func _draw():
		if piece != null:
			piece._paint(self)


var _canvas: _Canvas = null
var _material: ShaderMaterial = null
## How solid it is now, 1 whole and 0 gone, and whether that has been settled once (the first time, at once).
var _fade := 1.0
var _settled := false
var _offset := Vector2.ZERO
var _cuts := PackedVector3Array()
var _shapes := PackedVector2Array()
var _raised := 0.0


func _set_picture(value: Texture2D):
	picture = value
	_again()


func _set_kind(value: Kind):
	kind = value
	_again()


func _set_size(value: Vector2i):
	size_tiles = Vector2i(maxi(value.x, 1), maxi(value.y, 1))
	_again()


func _set_layer(value: Layer):
	layer = value
	_again()


func _set_everywhere(value: bool):
	everywhere = value
	_again()


func _set_height(value: float):
	height = maxf(value, 0.0)
	_again()


func _again():
	queue_redraw()
	if _canvas != null:
		_canvas.modulate.a = EDITOR_BEHIND_ALPHA if Engine.is_editor_hint() and layer == Layer.BEHIND else 1.0
		_canvas.queue_redraw()


func _ready():
	_canvas = _Canvas.new()
	_canvas.name = "Drawn"
	_canvas.piece = self
	# The lamps under a roof do not light its top.
	_canvas.light_mask = 0
	_canvas.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var shader := Shader.new()
	shader.code = PIECE_SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("cut_alpha", Depth.CUT_ALPHA)
	_material.set_shader_parameter("cut_soft", Depth.CUT_SOFT)
	_canvas.material = _material
	add_child(_canvas, false, Node.INTERNAL_MODE_FRONT)
	_again()
	if Engine.is_editor_hint():
		return
	add_to_group(Depth.PIECES)
	if not LightView.shown():
		visible = false
		set_process(false)
		return
	z_as_relative = false
	z_index = Depth.PIECE_Z_BEHIND if layer == Layer.BEHIND else Depth.PIECE_Z_FRONT


## --- Where it is ---

## The north-west corner of the tile it is on, from where the node stands.
func _corner() -> Vector2:
	var tile := float(Grid.TILE_SIZE)
	return Vector2(floorf(position.x / tile), floorf(position.y / tile)) * tile - position


## The ground it stands over, from the node: right and down from its tile, or for a Tree round its trunk.
func ground_rect() -> Rect2:
	var tile := float(Grid.TILE_SIZE)
	var size := Vector2(size_tiles) * tile
	if kind == Kind.TREE:
		return Rect2(_corner() + Vector2(tile, tile) * 0.5 - size * 0.5, size)
	return Rect2(_corner(), size)


## Where it is drawn with the view centred on it, from the node: over its ground, Height higher; behind the ground, its ground and
## as much round it as it can move.
func drawn_rect() -> Rect2:
	if layer == Layer.BEHIND:
		return ground_rect().grow(Depth.BEHIND_MARGIN_TILES * float(Grid.TILE_SIZE))
	var over := ground_rect()
	over.position.y -= height + _raised
	return over


## The ground it stands over, in the world.
func ground_in_world() -> Rect2:
	var ground := ground_rect()
	return Rect2(global_position + ground.position, ground.size)


## Where it is drawn now, in the world: moved as the view has it.
func drawn_in_world() -> Rect2:
	var drawn := drawn_rect()
	return Rect2(global_position + drawn.position + _offset, drawn.size)


## How far it moves against the ground (Depth.piece_moves).
func moves_now() -> float:
	return Depth.piece_moves(moves, layer == Layer.BEHIND, kind == Kind.TREE)


## How far it is drawn off its own place with the view's middle at `view`, in the world.
func offset_for(view: Vector2) -> Vector2:
	if layer == Layer.BEHIND and everywhere:
		# With no end to it, nothing holds it back.
		return (view - global_position) * moves_now()
	return Depth.piece_offset(moves_now(), layer == Layer.BEHIND, ground_in_world().get_center(), view)


## How far off its place it is drawn now, how solid (1 whole, 0 gone), and the cutaways open in it, each (x, y, reach) in the
## world (for a test).
func offset_now() -> Vector2:
	return _offset


func fade_now() -> float:
	return _fade


func cuts_now() -> PackedVector3Array:
	return _cuts


## --- Every frame, in the game ---

func _process(delta: float):
	if Engine.is_editor_hint() or _canvas == null:
		return
	_move_with_the_view()
	_darken_with_the_hour()
	_be_seen_through(delta)


func _move_with_the_view():
	var camera := get_viewport().get_camera_2d()
	var offset := offset_for(camera.get_screen_center_position()) if camera != null else Vector2.ZERO
	# A tree stands on ground that may itself be raised: its trunk starts on top of that.
	var raised := 0.0
	if kind == Kind.TREE and DepthView.showing != null and is_instance_valid(DepthView.showing):
		raised = DepthView.showing.height_at(Vector2i((global_position / float(Grid.TILE_SIZE)).floor()))
	if layer == Layer.BEHIND:
		_mask_by_the_map()
	var seen := ground_in_world()
	_material.set_shader_parameter("windowed", 1.0 if layer == Layer.BEHIND and not everywhere else 0.0)
	_material.set_shader_parameter("window", Vector4(seen.position.x, seen.position.y, seen.size.x, seen.size.y))
	if offset.distance_to(_offset) >= 0.25 or not is_equal_approx(raised, _raised):
		_offset = offset
		_raised = raised
		if kind == Kind.TREE:
			# Its trunk leans from where it stands to where its crown is drawn, so all of it is drawn again.
			_canvas.queue_redraw()
		else:
			_canvas.position = offset
	if layer == Layer.BEHIND and everywhere:
		# Drawn wherever the view is: again whenever the view comes to ground not drawn yet.
		var cells := _cells_in_view()
		if cells != _cells_drawn:
			_cells_drawn = cells
			_canvas.queue_redraw()
	if kind == Kind.ARCH and layer == Layer.IN_FRONT:
		var front := _front_shows()
		if front != _front_shown:
			_front_shown = front
			_canvas.queue_redraw()


## --- Behind the ground ---
##
## A piece behind is seen wherever no tile is painted (the designer, 2026-11-14: "the town below doesnt show all around the map and
## even from the top, if i go high enough on the map, i can still see the end of the background"). It is drawn over the ground's
## shade, not under the tiles, so that it darkens the same inside the map and far outside it, where there is no shade: `painted`,
## a pixel a tile of where the map has a tile, keeps it off them. So it wants to come after the TileMap in the scene, as a node
## added to a terrain does. Everywhere, it has no end: it is drawn over whatever the view shows (_cells_in_view), in cells that
## are the same wherever they are met.

## How many cells round the view an endless piece is drawn at a time, so that it is not drawn again at every step.
const VIEW_STEP_CELLS := 4

var _masked := false
var _cells_drawn := Rect2i()
var _front_shown := true


## The map this piece is on: the TileMap beside it in its scene, or the one the depth is drawn for.
func _map_under() -> TileMap:
	var beside = get_parent().get_node_or_null("TileMap") if get_parent() != null else null
	if beside is TileMap:
		return beside
	if DepthView.showing != null and is_instance_valid(DepthView.showing):
		return DepthView.showing._tile_map
	return null


func _mask_by_the_map():
	if _masked:
		return
	var tile_map := _map_under()
	if tile_map == null:
		return
	var region := tile_map.get_used_rect()
	if region.size.x <= 0 or region.size.y <= 0:
		return
	var image := Image.create(region.size.x, region.size.y, false, Image.FORMAT_R8)
	image.fill(Color.BLACK)
	for cell in tile_map.get_used_cells(0):
		image.set_pixelv(cell - region.position, Color.WHITE)
	var tile := float(Grid.TILE_SIZE)
	var corner: Vector2 = tile_map.to_global(tile_map.map_to_local(region.position)) - Vector2(tile, tile) * 0.5
	_material.set_shader_parameter("painted", ImageTexture.create_from_image(image))
	_material.set_shader_parameter("painted_rect", Vector4(corner.x, corner.y, region.size.x * tile, region.size.y * tile))
	_material.set_shader_parameter("masked", 1.0)
	_masked = true
	z_index = Depth.PIECE_Z_BEHIND_MASKED


## Whether it is kept off the map's tiles and drawn over the shade (for a test).
func masked() -> bool:
	return _masked


## How big one cell of an endless piece is: its picture, repeated, or one far roof of the placeholder.
func _cell_size() -> Vector2:
	return picture.get_size() if picture != null else FAR_ROOF


## The cells of an endless piece that the view shows now, and a few round them, from where the piece is drawn.
func _cells_in_view() -> Rect2i:
	var inverse := get_canvas_transform().affine_inverse()
	var view := Rect2(inverse * Vector2.ZERO - global_position - _offset, inverse.basis_xform(get_viewport_rect().size)).abs()
	var cell := _cell_size()
	var step := float(VIEW_STEP_CELLS)
	var first := Vector2i(floori(view.position.x / cell.x / step) - 1, floori(view.position.y / cell.y / step) - 1) * VIEW_STEP_CELLS
	var last := Vector2i(ceili(view.end.x / cell.x / step) + 1, ceili(view.end.y / cell.y / step) + 1) * VIEW_STEP_CELLS
	return Rect2i(first, last - first)


## Whether an arch's front shows: whether what stands to its south is lower than it. Over a way through a wall that runs north
## to south it does not, and only its top is drawn.
func _front_shows() -> bool:
	if Engine.is_editor_hint() or DepthView.showing == null or not is_instance_valid(DepthView.showing):
		return true
	var lifts: Dictionary = DepthView.showing.lifts()
	var first := Vector2i((ground_in_world().position / float(Grid.TILE_SIZE)).round())
	for dx in size_tiles.x:
		if float(lifts.get(first + Vector2i(dx, size_tiles.y), 0.0)) < height:
			return true
	return false


## Darker after dark, as everything is: a roof by the open sky over it, whatever is under it; the rest by the ground they stand
## on. What is behind the ground is far off under the same sky (and, with no map to keep it off, under the ground's own shade).
func _darken_with_the_hour():
	var lit := Color.WHITE
	if layer == Layer.IN_FRONT:
		lit = LightView.open_sky_colour() if kind == Kind.ROOF else LightView.lit_colour_at(global_position)
	elif _masked:
		lit = LightView.open_sky_colour()
	_canvas.modulate = Color(lit.r, lit.g, lit.b, 1.0)


## The cutaways, and a roof's fading for the party.
func _be_seen_through(delta: float):
	var wanted := 1.0
	var cuts := PackedVector3Array()
	if fades and layer == Layer.IN_FRONT:
		if kind == Kind.ROOF and _the_party_is_near():
			wanted = 0.0
		if wanted > 0.0 or _fade > 0.01:
			cuts = _who_it_covers()
	_fade = wanted if not _settled else move_toward(_fade, wanted, delta / Depth.PIECE_FADE_SECONDS)
	_settled = true
	# A copy: what is told to the shader below is padded out to its whole length.
	_cuts = cuts.duplicate()
	var count := cuts.size()
	_material.set_shader_parameter("fade", _fade)
	_material.set_shader_parameter("cut_count", count)
	if count > 0:
		var shapes := _shapes.duplicate()
		shapes.resize(Depth.MOST_CUTS)
		cuts.resize(Depth.MOST_CUTS)
		_material.set_shader_parameter("cuts", cuts)
		_material.set_shader_parameter("cut_shapes", shapes)


func _the_party_is_near() -> bool:
	var covered := ground_in_world()
	for one in get_tree().get_nodes_in_group(Depth.PARTY):
		if is_instance_valid(one) and one is Node2D and one.is_inside_tree() and Depth.same_scene(one, self) and Depth.roof_opens(covered, one.global_position):
			return true
	return false


## A cutaway about everybody drawn under it whom the player can see, about a thing to be found under it (not under a roof, which
## is there to hide the indoors until somebody comes near), and about the tile a fight's pointer is on.
func _who_it_covers() -> PackedVector3Array:
	var cuts := PackedVector3Array()
	_shapes = PackedVector2Array()
	var tile := float(Grid.TILE_SIZE)
	var drawn := drawn_in_world()
	for figure in get_tree().get_nodes_in_group(Depth.FIGURES):
		if cuts.size() >= Depth.MOST_CUTS:
			return cuts
		if not is_instance_valid(figure) or not figure.is_inside_tree() or not figure is CombatantSprite or not Depth.same_scene(figure, self):
			continue
		if not Depth.opens_a_cutaway(figure.is_visible_in_tree(), figure._shown_alpha):
			continue
		var reach: float = Depth.CUT_TILES * tile * maxf(absf(figure.global_scale.x), absf(figure.global_scale.y))
		var middle := DepthView.body_middle(figure)
		if drawn.grow(reach).has_point(middle):
			cuts.append(Vector3(middle.x, middle.y, reach))
			_shapes.append(DepthView.cut_shape_of(figure, reach))
	if kind != Kind.ROOF:
		for thing in get_tree().get_nodes_in_group(Depth.THINGS):
			if cuts.size() >= Depth.MOST_CUTS:
				return cuts
			if not is_instance_valid(thing) or not thing is Node2D or not thing.is_inside_tree() or not thing.is_visible_in_tree() or thing.is_in_group(Depth.UPRIGHTS) \
					or not Depth.same_scene(thing, self):
				continue
			if drawn.has_point(thing.global_position):
				cuts.append(Vector3(thing.global_position.x, thing.global_position.y, DepthView.THING_CUT_TILES * tile))
				_shapes.append(Vector2(0.0, DepthView.THING_CUT_TILES * tile))
	if DepthView.showing != null and is_instance_valid(DepthView.showing):
		for point in DepthView.showing.more_cuts:
			if cuts.size() < Depth.MOST_CUTS and drawn.has_point(point):
				cuts.append(Vector3(point.x, point.y, Depth.CUT_TILES * tile))
				_shapes.append(Vector2(0.0, Depth.CUT_TILES * tile))
	return cuts


## --- What it looks like ---

## In the editor, the ground it stands over, and a line up to where it is drawn.
func _draw():
	if not Engine.is_editor_hint():
		return
	var ground := ground_rect()
	draw_rect(ground, Color(0.55, 0.65, 1.0, 0.8), false, 4.0)
	if layer == Layer.IN_FRONT and height > 0.0:
		draw_line(ground.get_center(), drawn_rect().get_center(), Color(0.55, 0.65, 1.0, 0.8), 3.0)


## A number from 0 to 1 that is always the same for the same `i` in the same place.
func _chance(i: int) -> float:
	return fposmod(sin(float(i) * 12.9898 + position.x * 0.0131 + position.y * 0.0717) * 43758.5453, 1.0)


func _paint(canvas: CanvasItem):
	var over := drawn_rect()
	if layer == Layer.BEHIND and everywhere and not Engine.is_editor_hint() and _cells_drawn.size != Vector2i.ZERO:
		# With no end: whatever the view shows, in whole cells.
		var cell := _cell_size()
		var shown := Rect2(Vector2(_cells_drawn.position) * cell, Vector2(_cells_drawn.size) * cell)
		if picture != null:
			canvas.draw_texture_rect(picture, shown, true)
		else:
			_paint_backdrop(canvas, shown)
		return
	if kind == Kind.TREE:
		_paint_tree(canvas, over)
		return
	if picture != null:
		canvas.draw_texture_rect(picture, over, false)
		return
	match kind:
		Kind.ROOF:
			_paint_roof(canvas, over)
		Kind.BALCONY:
			_paint_balcony(canvas, over)
		Kind.BACKDROP:
			_paint_backdrop(canvas, over)
		_:
			_paint_arch(canvas, over)


## Tiles in courses down two slopes, a ridge along the longer way, and a dark eave.
func _paint_roof(canvas: CanvasItem, over: Rect2):
	var course := float(Grid.TILE_SIZE) * 0.25
	var line := Color(ROOF_TILE.darkened(0.45), 0.5)
	if over.size.x >= over.size.y:
		canvas.draw_rect(Rect2(over.position, Vector2(over.size.x, over.size.y * 0.5)), ROOF_TILE.darkened(0.2))
		canvas.draw_rect(Rect2(over.position + Vector2(0.0, over.size.y * 0.5), Vector2(over.size.x, over.size.y * 0.5)), ROOF_TILE)
		var y := over.position.y + course
		while y < over.end.y:
			canvas.draw_line(Vector2(over.position.x, y), Vector2(over.end.x, y), line, 3.0)
			y += course
		canvas.draw_line(Vector2(over.position.x, over.get_center().y), Vector2(over.end.x, over.get_center().y), ROOF_TILE.lightened(0.3), 12.0)
	else:
		canvas.draw_rect(Rect2(over.position, Vector2(over.size.x * 0.5, over.size.y)), ROOF_TILE.darkened(0.2))
		canvas.draw_rect(Rect2(over.position + Vector2(over.size.x * 0.5, 0.0), Vector2(over.size.x * 0.5, over.size.y)), ROOF_TILE)
		var x := over.position.x + course
		while x < over.end.x:
			canvas.draw_line(Vector2(x, over.position.y), Vector2(x, over.end.y), line, 3.0)
			x += course
		canvas.draw_line(Vector2(over.get_center().x, over.position.y), Vector2(over.get_center().x, over.end.y), ROOF_TILE.lightened(0.3), 12.0)
	canvas.draw_rect(over.grow(-6.0), ROOF_TILE.darkened(0.5), false, 12.0)


## A slab of dressed stone, its stones marked across it, and its front over the way where that faces us.
func _paint_arch(canvas: CanvasItem, over: Rect2):
	canvas.draw_rect(over, STONE)
	var step := float(Grid.TILE_SIZE) * 0.25
	var joint := Color(STONE.darkened(0.4), 0.6)
	if over.size.x >= over.size.y:
		var x := over.position.x + step
		while x < over.end.x - 1.0:
			canvas.draw_line(Vector2(x, over.position.y), Vector2(x, over.end.y), joint, 3.0)
			x += step
	else:
		var y := over.position.y + step
		while y < over.end.y - 1.0:
			canvas.draw_line(Vector2(over.position.x, y), Vector2(over.end.x, y), joint, 3.0)
			y += step
	canvas.draw_rect(over.grow(-4.0), STONE.darkened(0.45), false, 8.0)
	if _front_shown:
		# Its front, over the way under it: a band of stone, and the dark under that.
		var band := Rect2(over.position.x, over.end.y, over.size.x, minf(height * 0.35, float(Grid.TILE_SIZE) * 0.25))
		canvas.draw_rect(band, STONE.lightened(0.12))
		var joint_x := band.position.x + step
		while joint_x < band.end.x - 1.0:
			canvas.draw_line(Vector2(joint_x, band.position.y), Vector2(joint_x, band.end.y), joint, 3.0)
			joint_x += step
		canvas.draw_rect(Rect2(band.position.x, band.end.y, band.size.x, 10.0), Color(0, 0, 0, 0.3))


## Planks, and a rail along its south edge and its sides.
func _paint_balcony(canvas: CanvasItem, over: Rect2):
	canvas.draw_rect(over, WOOD)
	var plank := float(Grid.TILE_SIZE) * 0.2
	var x := over.position.x + plank
	while x < over.end.x - 1.0:
		canvas.draw_line(Vector2(x, over.position.y), Vector2(x, over.end.y), Color(WOOD.darkened(0.4), 0.7), 3.0)
		x += plank
	var rail := WOOD.darkened(0.35)
	var up := float(Grid.TILE_SIZE) * 0.28
	var post := over.position.x
	while post <= over.end.x + 0.5:
		canvas.draw_line(Vector2(post, over.end.y), Vector2(post, over.end.y - up), rail, 6.0)
		post += plank * 1.5
	canvas.draw_line(Vector2(over.position.x, over.end.y - up), Vector2(over.end.x, over.end.y - up), rail.lightened(0.15), 9.0)
	canvas.draw_rect(over.grow(-4.0), rail, false, 8.0)


## A trunk from where it stands, leaning to where its crown is drawn, and a crown of leaves in clumps. The Picture is its crown's.
func _paint_tree(canvas: CanvasItem, over: Rect2):
	var tile := float(Grid.TILE_SIZE)
	var foot := _corner() + Vector2(tile, tile) * 0.5 + Vector2(0.0, tile * 0.2 - _raised)
	var crown := over.get_center() + _offset
	var wide := tile * 0.11
	var across := (crown - foot).orthogonal().normalized()
	if across == Vector2.ZERO:
		across = Vector2.RIGHT
	canvas.draw_colored_polygon(PackedVector2Array([foot - across * wide, foot + across * wide, crown + across * wide * 0.6, crown - across * wide * 0.6]), BARK)
	canvas.draw_circle(foot, wide * 1.25, BARK.darkened(0.25))
	if picture != null:
		canvas.draw_texture_rect(picture, Rect2(over.position + _offset, over.size), false)
		return
	var reach := minf(over.size.x, over.size.y) * 0.5
	canvas.draw_circle(crown, reach * 0.8, LEAF.darkened(0.3))
	for i in 9:
		var turn := TAU * float(i) / 9.0 + _chance(i) * 0.6
		var at := crown + Vector2(cos(turn), sin(turn) * 0.85) * reach * (0.42 + _chance(i + 20) * 0.14)
		canvas.draw_circle(at, reach * (0.36 + _chance(i + 40) * 0.12), LEAF.darkened(_chance(i + 60) * 0.22))
	# The side the light comes from.
	for i in 6:
		var turn := TAU * float(i) / 6.0 + _chance(i + 80)
		var at := crown + Vector2(-0.16, -0.22) * reach + Vector2(cos(turn), sin(turn)) * reach * 0.3
		canvas.draw_circle(at, reach * (0.2 + _chance(i + 100) * 0.1), LEAF.lightened(0.12 + _chance(i + 120) * 0.14))


## Roofs far below, in rows with streets between, pale under a haze. Each is the same wherever it is met, so the town has no end.
func _paint_backdrop(canvas: CanvasItem, over: Rect2):
	canvas.draw_rect(over, HAZE.darkened(0.25))
	var colours := [Color(0.5, 0.36, 0.33), Color(0.4, 0.43, 0.5), Color(0.44, 0.45, 0.4), Color(0.52, 0.42, 0.34)]
	for row in range(floori(over.position.y / FAR_ROOF.y), ceili(over.end.y / FAR_ROOF.y)):
		for column in range(floori(over.position.x / FAR_ROOF.x), ceili(over.end.x / FAR_ROOF.x) + 1):
			var i := row * 131 + column * 17
			# A street, or a yard.
			if _chance(i) < 0.14:
				continue
			# Each street's houses stand a little off the next street's.
			var cell := Rect2(Vector2(float(column) - _chance(row + 900), row) * FAR_ROOF, FAR_ROOF)
			var roof := cell.grow_individual(-8.0 - _chance(i + 1) * 14.0, -8.0 - _chance(i + 2) * 12.0, -8.0 - _chance(i + 3) * 14.0, -8.0 - _chance(i + 4) * 12.0)
			var colour: Color = colours[int(_chance(i + 5) * colours.size()) % colours.size()]
			canvas.draw_rect(Rect2(roof.position, Vector2(roof.size.x, roof.size.y * 0.5)), colour.darkened(0.18))
			canvas.draw_rect(Rect2(roof.position + Vector2(0.0, roof.size.y * 0.5), Vector2(roof.size.x, roof.size.y * 0.5)), colour)
			canvas.draw_line(Vector2(roof.position.x, roof.get_center().y), Vector2(roof.end.x, roof.get_center().y), colour.lightened(0.2), 4.0)
	canvas.draw_rect(over, Color(HAZE, FAR_HAZE))
