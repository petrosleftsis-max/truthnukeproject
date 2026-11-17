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

enum Kind { ARCH, ROOF, BALCONY, TREE, BACKDROP, EDGE, CRATE, PILLAR, STATUE, LAMP_POST, RAILING }
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
## In Front: how many pixels above the ground it is drawn. A wall's top is 192 up (Depth.WALL_LIFT) and raised ground's 96, so
## 192, as it is to begin with, rests it on the walls. A Tree: how tall its trunk is. A piece left at this is not written into
## its scene, so it follows the walls if their height is ever changed again; one given a height of its own keeps it.
@export var height: float = Depth.WALL_LIFT : set = _set_height
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
// The far away, hazier: mixed towards `haze`'s colour by its alpha, and a picture softened over `soft` of its own pixels.
uniform vec4 haze = vec4(0.0);
uniform float soft = 0.0;
varying vec2 world;
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	vec4 colour = COLOR;
	if (soft > 0.0) {
		vec2 step_by = TEXTURE_PIXEL_SIZE * soft;
		vec4 about = texture(TEXTURE, UV + vec2(step_by.x, 0.0)) + texture(TEXTURE, UV - vec2(step_by.x, 0.0))
			+ texture(TEXTURE, UV + vec2(0.0, step_by.y)) + texture(TEXTURE, UV - vec2(0.0, step_by.y));
		vec4 own = texture(TEXTURE, UV);
		colour *= (own + about) / 5.0 / max(own, vec4(0.0001));
	}
	colour.rgb = mix(colour.rgb, haze.rgb, haze.a);
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


## --- The next steps of depth (the proposals of 2026-11-16, section 4; the designer, 2026-11-17) ---
##
## - **Dappled shade under a tree** (`_Shade`): the crown's shadow on the ground and on whoever stands under it, with gaps of
##   light that drift with the wind. By day and under a clear sky; none at night. Where the sun's shadows lean, it leans.
## - **A crown that sways**: it leans and rocks the way the wind blows, harder in a wind, and in a gale leaves are shaken loose.
## - **The far away, hazier**: a piece Behind is mixed towards a pale haze, more in mist, and its Picture a little softened.
## - **Things at the screen's edge** (Kind Edge): drawn dark and soft at the very front, over the weather, sliding fastest as the
##   view moves (Depth.PIECE_MOVES_EDGE), and faded while one of the party is under it. A slot for the artist: until then, a
##   bough.
## - **More that stands** (Kinds Crate, Pillar, Statue, Lamp Post, Railing): a thing standing on its tile, among the figures -
##   whoever is in front of it is over it, whoever is behind it under it and seen through it. Drawn standing on the south edge of
##   its tile, as wide as its ground and Height tall (left at the walls' 192, its kind's own: STAND_HEIGHTS; a person is about 330). A slot each for the artist: until then, a drawing in
##   code. It stops nobody by itself: that is the tile's to say.
##
## All of it only to look at, and every number a PROPOSAL.

const SHADE_MOST := 0.34
const SHADE_GROWS := 1.25
const SWAY_STILL_TILES := 0.012
const SWAY_TILES := 0.085
const SWAY_TURN := 0.05
const LEAVES_FROM_WIND := 0.6
const LEAVES_EVERY := [0.9, 2.4]
const HAZE_PALE := Color(0.74, 0.8, 0.88)
const HAZE_ALWAYS := 0.14
const HAZE_IN_MIST := 0.5
const HAZE_SOFT := 1.5
const EDGE_DARK := 0.6
const EDGE_FADED := 0.22
const EDGE_SOFT := 2.5
## How tall each kind of thing that stands is drawn, in pixels, while its Height is left at the walls'.
const STAND_HEIGHTS := {Kind.CRATE: 210.0, Kind.PILLAR: 400.0, Kind.STATUE: 340.0, Kind.LAMP_POST: 400.0, Kind.RAILING: 110.0}
const IRON := Color(0.2, 0.2, 0.23)
const PALE_STONE := Color(0.62, 0.62, 0.6)

const SHADE_SHADER := """
shader_type canvas_item;
render_mode blend_mul;
uniform sampler2D dapple : repeat_enable, filter_linear;
uniform vec2 drift = vec2(0.0);
uniform float strength = 0.3;
void fragment() {
	vec2 from_middle = UV * 2.0 - 1.0;
	float inside = 1.0 - smoothstep(0.55, 1.0, length(from_middle));
	float gaps = texture(dapple, UV * 1.7 + drift).r * 0.6 + texture(dapple, UV * 3.3 - drift * 1.6).r * 0.4;
	float light = smoothstep(0.5, 0.64, gaps);
	float dark = strength * inside * (1.0 - light * 0.85);
	COLOR = vec4(vec3(1.0 - dark), 1.0);
}
"""

static var _dapple: NoiseTexture2D = null

var _shade: ColorRect = null
var _shade_drift := Vector2.ZERO
var _sway := Vector2.ZERO
var _sway_turn := 0.0
var _sway_clock := 0.0
var _next_leaves := 1.5
## A fight's own layer holds what is drawn of a thing that stands, so it sorts with the fighters (`_stand_in_a_fight`).
var _stand_holder: Node2D = null


## Whether it is a thing that stands on its tile among the figures.
func stands() -> bool:
	return STAND_HEIGHTS.has(kind)


## How tall a thing that stands is drawn.
func stand_height() -> float:
	return float(STAND_HEIGHTS.get(kind, height)) if is_equal_approx(height, Depth.WALL_LIFT) else height


## The south edge of the ground a thing that stands is on, in the world: where it sorts from.
func foot_in_world() -> float:
	return global_position.y + ground_rect().end.y


static func _dapple_noise() -> NoiseTexture2D:
	if _dapple == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.02
		noise.seed = 4117
		_dapple = NoiseTexture2D.new()
		_dapple.width = 128
		_dapple.height = 128
		_dapple.seamless = true
		_dapple.noise = noise
	return _dapple


func _make_the_shade():
	_shade = ColorRect.new()
	_shade.name = "Shade"
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SHADE_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("dapple", _dapple_noise())
	_shade.material = material
	_shade.light_mask = 0
	# Before what is drawn of the piece: over the ground and everybody, under the crown.
	add_child(_shade, false, Node.INTERNAL_MODE_FRONT)
	move_child(_shade, 0)


## How dark the dappled shade is now (0: none): by the sun, as the figures' shadows are.
func shade_now() -> float:
	if kind != Kind.TREE or layer != Layer.IN_FRONT:
		return 0.0
	return SHADE_MOST * clampf(1.0 - LightView.night_now(), 0.0, 1.0) * clampf(CombatantSprite.shadow_strength / 0.35, 0.0, 1.0)


func _keep_the_shade(delta: float):
	if kind != Kind.TREE or layer != Layer.IN_FRONT:
		if _shade != null:
			_shade.visible = false
		return
	if _shade == null:
		_make_the_shade()
	var strength := shade_now()
	_shade.visible = strength > 0.01
	if not _shade.visible:
		return
	var wind := LightView.wind_over()
	_shade_drift += (wind * 0.09 + Vector2(0.004, 0.002)) * delta
	var ground := ground_rect().grow(float(Grid.TILE_SIZE) * 0.15)
	ground.size *= SHADE_GROWS
	ground.position -= ground.size * (1.0 - 1.0 / SHADE_GROWS) * 0.5
	# Where the sun throws it: the way the figures' shadows lean, as far as the crown is high.
	ground.position += Vector2(CombatantSprite.shadow_lean, 0.2) * height * 0.6 - Vector2(0.0, _raised)
	_shade.position = ground.position
	_shade.size = ground.size
	_shade.material.set_shader_parameter("strength", strength)
	_shade.material.set_shader_parameter("drift", _shade_drift + _sway / float(Grid.TILE_SIZE) * 0.2)


## A tree's crown, leaning and rocking with the wind; and in a gale, leaves shaken loose.
func _sway_the_crown(delta: float):
	if kind != Kind.TREE:
		return
	var wind := LightView.wind_over()
	var strong := wind.length()
	_sway_clock += delta * (0.9 + strong * 2.2)
	var tile := float(Grid.TILE_SIZE)
	var rock := sin(_sway_clock + position.x * 0.01) * 0.6 + sin(_sway_clock * 2.3 + position.y * 0.013) * 0.4
	var way := wind.normalized() if strong > 0.01 else Vector2.RIGHT
	_sway = way * tile * (SWAY_STILL_TILES * rock + SWAY_TILES * strong * (0.55 + 0.45 * rock))
	_sway_turn = SWAY_TURN * (0.25 + strong) * rock
	# Shaken by a blast beside it, dying away.
	var shake := shaken_now()
	_sway += _shaken_way * tile * SHAKEN_TILES * shake
	_sway_turn += SHAKEN_TURN * shake * (1.0 if _shaken_way.x >= 0.0 else -1.0)
	_canvas.queue_redraw()
	if strong >= LEAVES_FROM_WIND:
		_next_leaves -= delta
		if _next_leaves <= 0.0:
			_next_leaves = randf_range(LEAVES_EVERY[0], LEAVES_EVERY[1])
			var crown := drawn_rect().get_center() + _offset
			MapFeel.spawn(self, &"leaf", crown, {"toward": way, "colour": LEAF.lightened(0.15), "z": Depth.PIECE_Z_FRONT + 1})


## How hazy something behind the ground is now, 0 to 1.
func haze_now() -> float:
	if layer != Layer.BEHIND:
		return 0.0
	return clampf(HAZE_ALWAYS + HAZE_IN_MIST * LightView.mist_now(), 0.0, 0.8)


func _keep_the_haze():
	if layer != Layer.BEHIND:
		return
	var lit := LightView.open_sky_colour()
	var haze := haze_now()
	_material.set_shader_parameter("haze", Color(HAZE_PALE.r * lit.r, HAZE_PALE.g * lit.g, HAZE_PALE.b * lit.b, haze))
	_material.set_shader_parameter("soft", HAZE_SOFT if picture != null else 0.0)


## Where a thing that stands is in the draw order: on a map, by its foot; in a fight, what is drawn of it is handed to the
## fighters' own layer, which sorts by where each stands.
func _stand_among_the_figures():
	if not stands():
		return
	var view: DepthView = DepthView.showing
	if view == null or not is_instance_valid(view) or not Depth.same_scene(view, self):
		return
	if view._layer != null:
		_stand_in_a_fight(view._layer)
		return
	z_index = Depth.z_at(foot_in_world() - 1.0, view._top)


func _stand_in_a_fight(among: Node2D):
	if _stand_holder == null or not is_instance_valid(_stand_holder):
		_stand_holder = Node2D.new()
		_stand_holder.name = "Stands_%s" % name
		among.add_child(_stand_holder)
		_canvas.reparent(_stand_holder, false)
	var foot := Vector2(global_position.x, foot_in_world() - 1.0)
	_stand_holder.global_position = foot
	_canvas.position = global_position - foot


func _exit_tree():
	if _stand_holder != null and is_instance_valid(_stand_holder):
		_stand_holder.queue_free()
		_stand_holder = null


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
	if kind == Kind.EDGE:
		# The very front: over the weather too.
		z_index = LightView.SKY_Z + 1
		_material.set_shader_parameter("soft", EDGE_SOFT if picture != null else 0.0)


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
	if stands():
		# Standing on the south edge of its ground, as wide as that and as tall as it is.
		var on := ground_rect()
		return Rect2(on.position.x, on.end.y - stand_height(), on.size.x, stand_height())
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
	if stands():
		return 0.0
	if kind == Kind.EDGE and moves < 0.0:
		return Depth.PIECE_MOVES_EDGE
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
	_keep_the_shade(delta)
	_keep_shaking(delta)
	_sway_the_crown(delta)
	_keep_the_haze()
	_stand_among_the_figures()


## --- Shaken by a blast ---
##
## The proposals of 2026-11-17, section 6 ("Trees and things that stand, shaken"): a blast beside it (MapLife.blast_at) shakes a
## tree's crown and knocks a few leaves loose, and rocks a thing that stands about its foot; both settle as the shaking dies away.
## Only to look at. PROPOSAL.
const SHAKEN_SECONDS := 0.9
const SHAKEN_TILES := 0.12
const SHAKEN_TURN := 0.09
const ROCK_TURN := 0.06
const SHAKEN_LEAVES := 3
var _shaken_way := Vector2.ZERO
var _shaken_left := 0.0
## How many times it has been shaken, for a suite.
var shaken := 0


## Shaken by a blast from beside it, `away` the way it was pushed and `strength` 0 to 1 of how hard.
func shake(away: Vector2, strength: float):
	if kind != Kind.TREE and not stands():
		return
	shaken += 1
	_shaken_way = (away.normalized() if away != Vector2.ZERO else Vector2.RIGHT) * clampf(strength, 0.2, 1.0)
	_shaken_left = SHAKEN_SECONDS
	if kind == Kind.TREE and _canvas != null:
		var crown := drawn_rect().get_center() + _offset
		for i in SHAKEN_LEAVES:
			MapFeel.spawn(self, &"leaf", crown + Vector2(randf_range(-1.0, 1.0), randf_range(-0.5, 0.5)) * Grid.tiles(0.45),
				{"toward": _shaken_way, "colour": LEAF.lightened(0.15), "z": Depth.PIECE_Z_FRONT + 1})


## How far through its shaking it is now: a wobble dying away, -1 to 1; 0 at rest.
func shaken_now() -> float:
	if _shaken_left <= 0.0:
		return 0.0
	var t := 1.0 - _shaken_left / SHAKEN_SECONDS
	return sin(t * PI * 6.0) * (1.0 - t) * (1.0 - t) * _shaken_way.length()


func _keep_shaking(delta: float):
	if _shaken_left <= 0.0:
		return
	_shaken_left = maxf(_shaken_left - delta, 0.0)
	_canvas.queue_redraw()


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
	if kind == Kind.EDGE:
		# Nearest of all, against the light: all but a shape.
		lit = LightView.open_sky_colour() * EDGE_DARK
	if stands():
		lit = LightView.lit_colour_at(Vector2(global_position.x, foot_in_world() - float(Grid.TILE_SIZE) * 0.5))
	_canvas.modulate = Color(lit.r, lit.g, lit.b, 1.0)


## The cutaways, and a roof's fading for the party.
func _be_seen_through(delta: float):
	var wanted := 1.0
	var cuts := PackedVector3Array()
	if fades and layer == Layer.IN_FRONT:
		if kind == Kind.ROOF and _the_party_is_near():
			wanted = 0.0
		if kind == Kind.EDGE:
			# Never in the party's way: faded while one of them is under where it is drawn.
			wanted = EDGE_FADED if _the_party_is_under() else 1.0
		elif wanted > 0.0 or _fade > 0.01:
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


func _the_party_is_under() -> bool:
	var drawn := drawn_in_world().grow(float(Grid.TILE_SIZE) * 0.5)
	for one in get_tree().get_nodes_in_group(Depth.PARTY):
		if is_instance_valid(one) and one is Node2D and one.is_inside_tree() and Depth.same_scene(one, self) and drawn.has_point(one.global_position):
			return true
	return false


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
		if stands() and figure.global_position.y >= foot_in_world() - tile * 0.5:
			# On its own tile's row or in front of it: drawn over it, nothing to see through.
			continue
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
	# Rocked about its foot by a blast beside it (Shaken by a blast).
	var rock := ROCK_TURN * shaken_now() * (1.0 if _shaken_way.x >= 0.0 else -1.0) if stands() else 0.0
	if rock != 0.0:
		var foot := Vector2(over.get_center().x, over.end.y)
		canvas.draw_set_transform(foot - foot.rotated(rock), rock, Vector2.ONE)
	_paint_body(canvas, over)
	if rock != 0.0:
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## What it is, drawn over `over`: the artist's picture, or the drawing in code for its kind.
func _paint_body(canvas: CanvasItem, over: Rect2):
	if picture != null:
		canvas.draw_texture_rect(picture, over, false)
		return
	match kind:
		Kind.EDGE:
			_paint_edge(canvas, over)
		Kind.CRATE:
			_paint_crate(canvas, over)
		Kind.PILLAR:
			_paint_pillar(canvas, over)
		Kind.STATUE:
			_paint_statue(canvas, over)
		Kind.LAMP_POST:
			_paint_lamp_post(canvas, over)
		Kind.RAILING:
			_paint_railing(canvas, over)
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
	var crown := over.get_center() + _offset + _sway
	var wide := tile * 0.11
	var across := (crown - foot).orthogonal().normalized()
	if across == Vector2.ZERO:
		across = Vector2.RIGHT
	canvas.draw_colored_polygon(PackedVector2Array([foot - across * wide, foot + across * wide, crown + across * wide * 0.6, crown - across * wide * 0.6]), BARK)
	canvas.draw_circle(foot, wide * 1.25, BARK.darkened(0.25))
	# The crown turns a little about its own middle as it rocks.
	canvas.draw_set_transform(crown, _sway_turn, Vector2.ONE)
	crown = Vector2.ZERO
	if picture != null:
		canvas.draw_texture_rect(picture, Rect2(-over.size * 0.5, over.size), false)
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
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
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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


## --- Placeholders for the new kinds ---

## A bough reaching in from the nearest corner of what it covers, thick with leaves: dark, its edges soft.
func _paint_edge(canvas: CanvasItem, over: Rect2):
	var from := over.position + Vector2(0.0, over.size.y)
	var to := over.position + over.size * Vector2(0.9, 0.15)
	var across := (to - from).orthogonal().normalized()
	var thick := minf(over.size.x, over.size.y) * 0.035
	canvas.draw_colored_polygon(PackedVector2Array([from - across * thick, from + across * thick, to + across * thick * 0.25, to - across * thick * 0.25]), BARK.darkened(0.2))
	for i in 16:
		# Clusters of leaves along its outer half, to either side of it.
		var along := 0.35 + 0.65 * _chance(i + 300)
		var at := from.lerp(to, along) + across * (over.size.y * 0.16) * (_chance(i + 320) - 0.5) * 2.0
		var reach := minf(over.size.x, over.size.y) * (0.045 + 0.04 * _chance(i + 340))
		# Soft: a few rings, fainter outwards.
		for ring in 3:
			canvas.draw_circle(at, reach * (1.0 + 0.3 * float(ring)), Color(LEAF.darkened(0.1 + 0.25 * _chance(i + 360)), 0.6 - 0.18 * float(ring)))


## The top of a block `deep` pixels from front to back, and its front under it, in `over`: [top, front].
func _block(over: Rect2) -> Array:
	var deep := minf(ground_rect().size.y, over.size.y * 0.5)
	return [Rect2(over.position, Vector2(over.size.x, deep)), Rect2(over.position + Vector2(0.0, deep), Vector2(over.size.x, over.size.y - deep))]


func _paint_crate(canvas: CanvasItem, over: Rect2):
	var box := over.grow_individual(-over.size.x * 0.1, 0.0, -over.size.x * 0.1, -over.size.y * 0.04)
	var parts := _block(box)
	var top: Rect2 = parts[0]
	var front: Rect2 = parts[1]
	canvas.draw_rect(top, WOOD.lightened(0.14))
	canvas.draw_rect(front, WOOD)
	var plank := front.size.x / 4.0
	for i in range(1, 4):
		canvas.draw_line(Vector2(front.position.x + plank * i, front.position.y), Vector2(front.position.x + plank * i, front.end.y), WOOD.darkened(0.4), 4.0)
		canvas.draw_line(Vector2(top.position.x + plank * i, top.position.y), Vector2(top.position.x + plank * i, top.end.y), WOOD.darkened(0.25), 3.0)
	canvas.draw_line(front.position, front.end, WOOD.darkened(0.3), 10.0)
	canvas.draw_rect(front.grow(-5.0), WOOD.darkened(0.45), false, 10.0)
	canvas.draw_rect(top.grow(-4.0), WOOD.darkened(0.3), false, 6.0)


func _paint_pillar(canvas: CanvasItem, over: Rect2):
	var middle := over.get_center().x
	var wide := over.size.x * 0.34
	var cap := over.size.x * 0.48
	var tile := float(Grid.TILE_SIZE)
	# Its base on the ground, its shaft, and its capital seen a little from above.
	canvas.draw_rect(Rect2(middle - cap * 0.5, over.end.y - tile * 0.24, cap, tile * 0.2), PALE_STONE.darkened(0.25))
	canvas.draw_rect(Rect2(middle - wide * 0.5, over.position.y + tile * 0.18, wide, over.size.y - tile * 0.4), PALE_STONE)
	for i in range(1, 4):
		var x := middle - wide * 0.5 + wide * float(i) / 4.0
		canvas.draw_line(Vector2(x, over.position.y + tile * 0.2), Vector2(x, over.end.y - tile * 0.24), PALE_STONE.darkened(0.2), 4.0)
	canvas.draw_rect(Rect2(middle - wide * 0.5, over.position.y + tile * 0.18, wide * 0.22, over.size.y - tile * 0.4), PALE_STONE.lightened(0.18))
	canvas.draw_rect(Rect2(middle - cap * 0.5, over.position.y, cap, tile * 0.22), PALE_STONE.lightened(0.1))
	canvas.draw_rect(Rect2(middle - cap * 0.5, over.position.y + tile * 0.16, cap, tile * 0.06), PALE_STONE.darkened(0.3))


func _paint_statue(canvas: CanvasItem, over: Rect2):
	var middle := over.get_center().x
	var tile := float(Grid.TILE_SIZE)
	var plinth := Rect2(middle - over.size.x * 0.3, over.end.y - tile * 0.34, over.size.x * 0.6, tile * 0.3)
	canvas.draw_rect(plinth, PALE_STONE.darkened(0.2))
	canvas.draw_rect(Rect2(plinth.position, Vector2(plinth.size.x, tile * 0.07)), PALE_STONE.lightened(0.1))
	# A robed figure: a body widening to its hem, shoulders, a head.
	var hem := plinth.position.y
	var shoulders := over.position.y + (hem - over.position.y) * 0.3
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(middle - over.size.x * 0.2, hem), Vector2(middle + over.size.x * 0.2, hem),
		Vector2(middle + over.size.x * 0.13, shoulders), Vector2(middle - over.size.x * 0.13, shoulders)]), PALE_STONE)
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(middle - over.size.x * 0.2, hem), Vector2(middle - over.size.x * 0.06, hem),
		Vector2(middle - over.size.x * 0.05, shoulders), Vector2(middle - over.size.x * 0.13, shoulders)]), PALE_STONE.lightened(0.16))
	canvas.draw_circle(Vector2(middle, shoulders - over.size.x * 0.1), over.size.x * 0.1, PALE_STONE.lightened(0.05))


func _paint_lamp_post(canvas: CanvasItem, over: Rect2):
	var middle := over.get_center().x
	var tile := float(Grid.TILE_SIZE)
	canvas.draw_rect(Rect2(middle - tile * 0.09, over.end.y - tile * 0.2, tile * 0.18, tile * 0.16), IRON.darkened(0.2))
	canvas.draw_rect(Rect2(middle - tile * 0.03, over.position.y + tile * 0.3, tile * 0.06, over.size.y - tile * 0.46), IRON)
	var head := Rect2(middle - tile * 0.11, over.position.y + tile * 0.04, tile * 0.22, tile * 0.26)
	canvas.draw_rect(head, IRON)
	canvas.draw_rect(head.grow(-tile * 0.035), Color(1.0, 0.8, 0.42))
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(head.position.x - tile * 0.03, head.position.y), Vector2(head.end.x + tile * 0.03, head.position.y),
		Vector2(middle, over.position.y - tile * 0.04)]), IRON)


func _paint_railing(canvas: CanvasItem, over: Rect2):
	var tile := float(Grid.TILE_SIZE)
	var top := over.position.y + tile * 0.04
	var post := over.position.x
	while post <= over.end.x + 0.5:
		canvas.draw_line(Vector2(post, over.end.y - tile * 0.04), Vector2(post, top), IRON, 8.0)
		post += tile * 0.25
	canvas.draw_line(Vector2(over.position.x, top), Vector2(over.end.x, top), IRON.lightened(0.15), 12.0)
	canvas.draw_line(Vector2(over.position.x, over.end.y - tile * 0.08), Vector2(over.end.x, over.end.y - tile * 0.08), IRON, 8.0)
