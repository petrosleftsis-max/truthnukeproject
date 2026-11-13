extends Node2D
class_name DepthView
## 2.5D, drawn (Depth says what; docs/2_5d_plan.md; the designer and their artist, 2026-11-13). View only: nothing in it rolls or
## decides, and none of it is made headless unless LightView.plays_headless. Placeholders behind slots, every number a PROPOSAL.
##
## A. Raised ground, shown:
## - each lifted tile's own picture drawn again higher (Depth.lifts_of), row by row, with a face under it where what lies to its
##   south is lower (_Row). In a fight the rows go into the y-sorted Combatants layer at their north edge, so whoever stands on
##   one or in front of it is drawn over it and whoever stands behind it under it; on a map they and every figure take an absolute
##   z from where they are (Depth.z_at, _sort_the_figures);
## - they are over the shade, so RAISED_SHADER darkens and drains them from the shade's own picture, as the figures are
##   (CombatantSprite.shade_map), at the ground they stand on; the real lights fall on them as on the ground;
## - the cutaway: where somebody the player can see stands behind a lifted row, it goes see-through in a round patch about them
##   (_tell_the_cutaways, RAISED_SHADER's `cuts`);
## - a shadow off every edge onto the low side, leaning with the sun or the moon as the figures' shadows do
##   (_cast_the_shadows, a mask LEDGE_GRAIN to a tile under the shade), and a soft line at the foot of each face.
## Slots (Depth.slot): art/terrain/depth/face_<column>_<row>.png (256 x 80, a kind of raised ground's front, by its tile in the
## atlas), face.png (any other's), wall_face.png (256 x 160), top_<column>_<row>.png (256 x 256, in place of the tile's own picture).

## Darkened as the shade darkens the ground under them, and see-through about whoever they cover.
const RAISED_SHADER := """
shader_type canvas_item;
uniform sampler2D shade_map : filter_linear, repeat_disable;
uniform sampler2D shade_previous : filter_linear, repeat_disable;
uniform float shade_blend = 1.0;
uniform vec4 shade_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float shade_on = 0.0;
uniform float drain = 0.9;
uniform float most = 0.86;
uniform float half_tile = 128.0;
uniform vec3 cuts[24];
uniform int cut_count = 0;
uniform float cut_alpha = 0.16;
uniform float cut_soft = 0.3;
// What is drawn with it: 0 a top, 1 a face (it faces us, down the screen), 2 a thing standing (round, as a barrel is).
uniform float kind = 0.0;
uniform vec3 face_normal = vec3(0.0, 0.86, 0.5);
uniform float roundness = 0.85;
// The lamps: where each is, how far it reaches and how strong it is this moment; its colour; and where their light reaches at all.
uniform vec4 lamps[8];
uniform vec3 lamp_colours[8];
uniform int lamp_count = 0;
uniform sampler2D lit_gate : filter_linear, repeat_disable;
uniform vec4 gate_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float lamp_gain = 1.0;
uniform float lamp_height = 128.0;
varying vec2 world;
varying float north;
varying vec2 shape;
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	north = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).y;
	// A thing standing is drawn with where each corner is across it and down it in its vertex colour, not a tint.
	shape = COLOR.rg;
	if (kind > 1.5) {
		COLOR = vec4(1.0);
	}
}
void fragment() {
	// COLOR comes in as the picture's own colour already.
	vec4 colour = COLOR;
	// Which way this faces, the ground it stands on, and the ground whose light it takes: a top its own tile; a face the floor in
	// front of it, so it is as lit as the room it looks into and a lamp behind the wall never lights it; a thing standing its
	// own tile, round.
	vec3 facing = vec3(0.0, 0.0, 1.0);
	vec2 ground = vec2(world.x, north + half_tile);
	vec2 asked = ground;
	if (kind > 0.5 && kind < 1.5) {
		vec3 mapped = texture(NORMAL_TEXTURE, UV).rgb;
		if (length(mapped.xy - vec2(0.5)) < 0.02) {
			facing = normalize(face_normal);
		} else {
			facing = normalize(vec3(mapped.x * 2.0 - 1.0, 1.0 - mapped.y * 2.0, mapped.z));
		}
		ground = vec2(world.x, north + half_tile * 2.0);
		asked = vec2(world.x, north + half_tile * 3.0);
	} else if (kind > 1.5) {
		float across = clamp(shape.x * 2.0 - 1.0, -1.0, 1.0) * roundness;
		facing = normalize(vec3(across, 0.45, sqrt(max(1.0 - across * across, 0.04))));
		ground = vec2(world.x, north + half_tile * 1.6);
	}
	if (lamp_count > 0) {
		float reached = texture(lit_gate, (asked - gate_rect.xy) / gate_rect.zw).r;
		vec3 lit = vec3(0.0);
		for (int i = 0; i < lamp_count; i++) {
			vec2 to = lamps[i].xy - ground;
			float near = clamp(1.0 - length(to) / max(lamps[i].z, 1.0), 0.0, 1.0);
			vec3 from = normalize(vec3(to, lamp_height));
			lit += lamp_colours[i] * (near * sqrt(near) * lamps[i].w * max(dot(facing, from), 0.0));
		}
		colour.rgb += colour.rgb * lit * reached * lamp_gain;
	}
	if (shade_on > 0.5) {
		// The ground whose light it takes, not the ground it is drawn over.
		vec2 on_shade = (asked - shade_rect.xy) / shade_rect.zw;
		vec4 shade = mix(texture(shade_previous, on_shade), texture(shade_map, on_shade), shade_blend);
		float grey = dot(colour.rgb, vec3(0.299, 0.587, 0.114));
		vec3 drained = mix(colour.rgb, vec3(grey), clamp(shade.a / most, 0.0, 1.0) * drain);
		colour.rgb = mix(drained, shade.rgb, shade.a);
	}
	float left = 1.0;
	for (int i = 0; i < cut_count; i++) {
		// Only whoever stands behind this row: on it or in front of it, they are drawn over it anyway.
		if (cuts[i].y < north) {
			float far = distance(world, cuts[i].xy) / max(cuts[i].z, 1.0);
			left = min(left, mix(cut_alpha, 1.0, smoothstep(1.0 - cut_soft, 1.0, far)));
		}
	}
	colour.a *= left;
	COLOR = colour;
}
"""

## How many samples of the ledge shadows' mask go to a tile, each way.
const LEDGE_GRAIN := 8
## How strong a ledge's shadow is, against a figure's (CombatantSprite.shadow_strength).
const LEDGE_SHADOW := 1.1
## How dark the soft line at the foot of a face is, in the mask (0 to 255), and one sample further out.
const FOOT_SHADOW := [150, 60]
## How far the sun has to lean differently for the shadows to be laid again.
const LEAN_STEP := 0.03
## A thing standing covers whoever is behind it only once it rises this far over its own tile; and how far round a thing lying
## on the map its cutaway reaches, in tiles.
const OBJECT_COVERS_FROM := 24.0
const THING_CUT_TILES := 0.45
## Where on its tile somebody's feet are, as a share of it down from its north edge (CombatantSprite's shadow stands there).
const FEET_AT := 0.92
## How a face is coloured from its tile, where no picture is in its slot: raised ground's darker, a wall's lighter.
const FACE_DARKER := 0.36
const WALL_FACE_LIGHTER := 0.14

## The view showing now.
static var showing: DepthView = null
static var _images := {}
static var _looks := {}

var _tile_map: TileMap = null
## The fight's y-sorted layer the rows are in, or null on a map.
var _layer: Node2D = null
var _lifts := {}
## What stands on the floor, {tile: what its row draws}, and how far everything rises over its own north edge, {tile: pixels}: what
## may cover whoever is behind it.
var _objects := {}
var _rise := {}
var _rows: Array = []
var _material: ShaderMaterial = null
## The same shader for the faces and for things standing, each told what it draws (RAISED_SHADER's `kind`).
var _face_material: ShaderMaterial = null
var _object_material: ShaderMaterial = null
## The shade at the foot of walls and raised edges ("Light that knows height").
var _feet: Sprite2D = null
var _shadows: Sprite2D = null
var _shadow_key := ""
var _shadow_lean := 99.0
var _region := Rect2i()
## The world y of the map's first row's north edge (Depth.z_at).
var _top := 0.0


## Starts drawing the depth of `tile_map`: in a fight `layer` is its y-sorted Combatants layer.
func start(tile_map: TileMap, layer: Node2D = null):
	name = "DepthView"
	_tile_map = tile_map
	_layer = layer
	showing = self
	var shader := Shader.new()
	shader.code = RAISED_SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_face_material = ShaderMaterial.new()
	_face_material.shader = shader
	_face_material.set_shader_parameter("kind", 1.0)
	_object_material = ShaderMaterial.new()
	_object_material.shader = shader
	_object_material.set_shader_parameter("kind", 2.0)
	for material in _materials():
		material.set_shader_parameter("half_tile", float(Grid.TILE_SIZE) * 0.5)
		material.set_shader_parameter("cut_alpha", Depth.CUT_ALPHA)
		material.set_shader_parameter("cut_soft", Depth.CUT_SOFT)
	_feet = Sprite2D.new()
	_feet.name = "WallFeet"
	_feet.centered = false
	_feet.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_feet.light_mask = 0
	var feet_shader := Shader.new()
	feet_shader.code = FOOT_SHADER
	_feet.material = ShaderMaterial.new()
	_feet.material.shader = feet_shader
	_feet.material.set_shader_parameter("strength", FOOT_SHADE)
	_feet.visible = false
	add_child(_feet)
	_shadows = Sprite2D.new()
	_shadows.name = "LedgeShadows"
	_shadows.centered = false
	_shadows.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_shadows.light_mask = 0
	_shadows.visible = false
	add_child(_shadows)
	build()


func _exit_tree():
	if showing == self:
		showing = null
	# The rows in a fight's layer are not this node's children: they go with it.
	for row in _rows:
		if is_instance_valid(row) and row.get_parent() != self:
			row.queue_free()
	_rows.clear()


## Every lifted tile, as {tile: lift}.
func lifts() -> Dictionary:
	return _lifts


## Every thing standing on the floor, as {tile: what its row draws}.
func objects() -> Dictionary:
	return _objects


## How much higher whoever stands up on `tile` is drawn: the ground's lift, or the top of the thing standing there. 0: not at all.
func height_at(tile: Vector2i) -> float:
	if _objects.has(tile):
		return _objects[tile].height
	return _lifts.get(tile, 0.0)


## The lifted rows, north to south (for a test).
func rows() -> Array:
	return _rows


## Reads the map again and draws it: at the start, and whenever its tiles have changed.
func build():
	for row in _rows:
		if is_instance_valid(row):
			row.queue_free()
	_rows.clear()
	if _tile_map == null:
		return
	_lifts = Depth.lifts_of(_tile_map)
	_objects = {}
	for at in Depth.standers_of(_tile_map):
		var thing := _object_entry(at)
		if not thing.is_empty():
			_objects[at] = thing
	_rise = _lifts.duplicate()
	for at in _objects:
		if _objects[at].rise > OBJECT_COVERS_FROM:
			_rise[at] = _objects[at].rise
	_region = _tile_map.get_used_rect()
	var tile := float(Grid.TILE_SIZE)
	_top = _tile_map.to_global(_tile_map.map_to_local(_region.position)).y - tile * 0.5
	var by_row := {}
	for at in _lifts.keys() + _objects.keys():
		if not by_row.has(at.y):
			by_row[at.y] = []
		by_row[at.y].append(at)
	var ys := by_row.keys()
	ys.sort()
	for y in ys:
		var tiles: Array = by_row[y]
		tiles.sort_custom(func(one, other): return one.x < other.x)
		var entries := []
		for at in tiles:
			entries.append(_objects[at] if _objects.has(at) else _entry(at))
		var first: Vector2 = _tile_map.map_to_local(Vector2i(0, y))
		# The tops, then the faces, then what stands: a node each, for how the light falls on each (RAISED_SHADER's `kind`).
		for what in [_Row.TOPS, _Row.FACES, _Row.THINGS]:
			var wanted: Array = entries.filter(func(entry):
				if entry.get("object", false):
					return what == _Row.THINGS
				return what == _Row.TOPS or (what == _Row.FACES and entry.face > 0.0))
			if wanted.is_empty():
				continue
			var row := _Row.new()
			row.name = "Row%d%s" % [y, ["Tops", "Faces", "Things"][what]]
			row.what = what
			row.material = [_material, _face_material, _object_material][what]
			# Its north edge, in the tile map's own coordinates: where it sorts from.
			row.position = Vector2(0.0, first.y - tile * 0.5)
			row.tiles = wanted
			if _layer != null:
				# With the figures, sorted by where each stands.
				row.z_index = 1
				_layer.add_child(row)
			else:
				add_child(row)
				row.z_as_relative = false
				row.z_index = Depth.z_at(_tile_map.to_global(row.position).y, _top)
			_rows.append(row)
	_shade_the_feet()
	_shadow_key = ""
	_shadow_lean = 99.0
	_keep_the_shadows()


## What a row has to know to draw the tile at `at`.
func _entry(at: Vector2i) -> Dictionary:
	var tile := float(Grid.TILE_SIZE)
	var lift: float = _lifts[at]
	var source_id := _tile_map.get_cell_source_id(0, at)
	var atlas := _tile_map.get_cell_atlas_coords(0, at)
	var entry := {"x": _tile_map.map_to_local(at).x - tile * 0.5, "lift": lift, "face": Depth.face_under(_lifts, at),
		"alternative": _tile_map.get_cell_alternative_tile(0, at), "wall": lift >= Depth.WALL_LIFT, "texture": null, "region": Rect2(),
		"face_colour": Color(0.3, 0.3, 0.34), "face_picture": null, "top_picture": Depth.slot("top_%d_%d" % [atlas.x, atlas.y])}
	var source = _tile_map.tile_set.get_source(source_id) if _tile_map.tile_set != null and _tile_map.tile_set.has_source(source_id) else null
	if source is TileSetAtlasSource:
		# A wall piece that is half floor is drawn, lifted, as the whole block (Depth.TOP_STAND_INS).
		var drawn_as: Vector2i = Depth.TOP_STAND_INS.get(atlas, atlas)
		if drawn_as != atlas:
			entry.alternative = 0
		entry.texture = source.texture
		entry.region = Rect2(source.get_tile_texture_region(drawn_as))
		var look := _look_of(source, drawn_as)
		entry.face_colour = look.lightened(WALL_FACE_LIGHTER) if entry.wall else look.darkened(FACE_DARKER)
	entry.face_picture = Depth.slot("face_%d_%d" % [atlas.x, atlas.y])
	if entry.face_picture == null:
		entry.face_picture = Depth.slot("wall_face" if entry.wall else "face")
	return entry


## What a row has to know to draw the thing standing on `at` (Depth.stands_at): the picture in its slot
## (art/terrain/depth/object_<column>_<row>.png, standing with the middle of its foot on the tile's foot), or until then the thing
## cut out of its tile (_cut_out) and drawn Depth.OBJECT_SCALE bigger from where it stands.
func _object_entry(at: Vector2i) -> Dictionary:
	var tile := float(Grid.TILE_SIZE)
	var source_id := _tile_map.get_cell_source_id(0, at)
	var atlas := _tile_map.get_cell_atlas_coords(0, at)
	var source = _tile_map.tile_set.get_source(source_id) if _tile_map.tile_set != null and _tile_map.tile_set.has_source(source_id) else null
	var x: float = _tile_map.map_to_local(at).x - tile * 0.5
	var entry := {"object": true, "x": x, "texture": null, "source": Rect2(), "dest": Rect2(), "height": 0.0, "rise": 0.0, "foot": Rect2(), "tall": 0.0}
	var picture := Depth.slot("object_%d_%d" % [atlas.x, atlas.y])
	if picture != null:
		var size: Vector2 = picture.get_size()
		entry.texture = picture
		entry.source = Rect2(Vector2.ZERO, size)
		entry.dest = Rect2(x + tile * 0.5 - size.x * 0.5, tile * FEET_AT - size.y, size.x, size.y)
	elif source is TileSetAtlasSource:
		var cut := _cut_out(source, atlas)
		if cut.texture == null:
			return {}
		var box: Rect2 = cut.box
		var flipped: bool = (_tile_map.get_cell_alternative_tile(0, at) & TileSetAtlasSource.TRANSFORM_FLIP_H) != 0
		if flipped:
			box.position.x = tile - box.end.x
		var size: Vector2 = box.size * Depth.OBJECT_SCALE
		entry.texture = cut.texture
		entry.source = cut.box
		entry.dest = Rect2(x + box.get_center().x - size.x * 0.5, box.end.y - size.y, size.x, size.y)
		entry["flipped"] = flipped
	else:
		return {}
	var width: float = entry.dest.size.x
	entry.tall = entry.dest.size.y
	entry.rise = maxf(-entry.dest.position.y, 0.0)
	# Whoever climbs it stands a little under its top.
	entry.height = maxf(tile * FEET_AT - (entry.dest.position.y + entry.tall * Depth.STAND_ON_SHARE), 0.0)
	# What throws its shadow: about where it meets the floor.
	entry.foot = Rect2(entry.dest.position.x + width * 0.15, entry.dest.end.y - width * 0.55, width * 0.7, width * 0.5)
	return entry


## The thing painted on the tile at `atlas`, apart from the floor it is painted on: {"texture", "box"} (the box in the tile's own
## pixels), or no texture where nothing is found. A stand-in until the artist draws the thing alone: whatever is wood-coloured
## there (a barrel, a crate), filled in across its hoops and grown by its outline.
static func _cut_out(source: TileSetAtlasSource, atlas: Vector2i) -> Dictionary:
	var key := "cut:%d:%d:%d" % [source.get_instance_id(), atlas.x, atlas.y]
	if _looks.has(key):
		return _looks[key]
	var found := {"texture": null, "box": Rect2()}
	_looks[key] = found
	var texture: Texture2D = source.texture
	if texture == null:
		return found
	if not _images.has(texture):
		var whole: Image = texture.get_image()
		if whole != null and whole.is_compressed():
			whole.decompress()
		_images[texture] = whole
	var sheet: Image = _images[texture]
	if sheet == null or sheet.is_empty():
		return found
	var region: Rect2i = source.get_tile_texture_region(atlas)
	var piece: Image = sheet.get_region(region)
	piece.convert(Image.FORMAT_RGBA8)
	var w := piece.get_width()
	var h := piece.get_height()
	var far := 99999
	var row_from := PackedInt32Array()
	var row_to := PackedInt32Array()
	var column_from := PackedInt32Array()
	var column_to := PackedInt32Array()
	row_from.resize(h)
	row_to.resize(h)
	column_from.resize(w)
	column_to.resize(w)
	row_from.fill(far)
	row_to.fill(-1)
	column_from.fill(far)
	column_to.fill(-1)
	var count := 0
	for y in range(0, h, 2):
		for x in range(0, w, 2):
			var pixel := piece.get_pixel(x, y)
			if pixel.a < 0.5 or pixel.s < 0.3 or pixel.v < 0.25 or (pixel.h > 0.14 and pixel.h < 0.97):
				continue
			count += 1
			row_from[y] = mini(row_from[y], x)
			row_to[y] = maxi(row_to[y], x + 1)
			column_from[x] = mini(column_from[x], y)
			column_to[x] = maxi(column_to[x], y + 1)
	if count < (w * h) / 200:
		return found
	# Filled in down every column too, so a hoop across it is not a gap.
	for x in range(0, w, 2):
		if column_to[x] < 0:
			continue
		for y in range(column_from[x], mini(column_to[x] + 1, h)):
			row_from[y] = mini(row_from[y], x)
			row_to[y] = maxi(row_to[y], x + 1)
	# Grown by its outline, which is no colour at all.
	var grown := 5
	var box := Rect2i()
	var clear := Color(0, 0, 0, 0)
	for y in h:
		var first := far
		var last := -1
		for near in range(maxi(y - grown, 0), mini(y + grown + 1, h)):
			if row_to[near] >= 0:
				first = mini(first, row_from[near])
				last = maxi(last, row_to[near])
		if last < 0:
			piece.fill_rect(Rect2i(0, y, w, 1), clear)
			continue
		first = maxi(first - grown, 0)
		last = mini(last + grown, w - 1)
		if first > 0:
			piece.fill_rect(Rect2i(0, y, first, 1), clear)
		if last < w - 1:
			piece.fill_rect(Rect2i(last + 1, y, w - 1 - last, 1), clear)
		var span := Rect2i(first, y, last - first + 1, 1)
		box = span if box.size == Vector2i.ZERO else box.merge(span)
	found.texture = ImageTexture.create_from_image(piece)
	found.box = Rect2(box)
	return found


## The colour along the foot of the tile at `atlas`, for a face with no picture: its lower third, averaged.
static func _look_of(source: TileSetAtlasSource, atlas: Vector2i) -> Color:
	var key := "%d:%d:%d" % [source.get_instance_id(), atlas.x, atlas.y]
	if _looks.has(key):
		return _looks[key]
	var colour := Color(0.3, 0.3, 0.34)
	var texture: Texture2D = source.texture
	if texture != null:
		if not _images.has(texture):
			var image: Image = texture.get_image()
			if image != null and image.is_compressed():
				image.decompress()
			_images[texture] = image
		var picture: Image = _images[texture]
		if picture != null and not picture.is_empty():
			var region: Rect2i = source.get_tile_texture_region(atlas)
			var sum := Vector3.ZERO
			var weight := 0.0
			for i in 8:
				for j in 4:
					var at := Vector2i(region.position.x + int((i + 0.5) * region.size.x / 8.0), region.position.y + int(region.size.y * (0.68 + j * 0.08)))
					if at.x >= picture.get_width() or at.y >= picture.get_height():
						continue
					var pixel := picture.get_pixelv(at)
					sum += Vector3(pixel.r, pixel.g, pixel.b) * pixel.a
					weight += pixel.a
			if weight > 0.5:
				colour = Color(sum.x / weight, sum.y / weight, sum.z / weight)
	_looks[key] = colour
	return colour


## One row of lifted tiles: their tops (each one's picture drawn `lift` higher), or their faces, or the things standing in the row.
## A node for each, since the light falls on each differently (RAISED_SHADER's `kind`).
class _Row extends Node2D:
	enum { TOPS, FACES, THINGS }
	var what := TOPS
	var tiles: Array = []

	func _draw():
		for entry in tiles:
			match what:
				TOPS:
					_draw_top(entry)
				FACES:
					_draw_face(entry)
				THINGS:
					_draw_thing(entry)

	func _draw_top(entry: Dictionary):
		var tile := float(Grid.TILE_SIZE)
		var top := Rect2(entry.x, -entry.lift, tile, tile)
		if entry.top_picture != null:
			draw_texture_rect(entry.top_picture, top, false)
		elif entry.texture != null:
			var alternative: int = entry.alternative
			var dest := top
			if alternative & TileSetAtlasSource.TRANSFORM_FLIP_H:
				dest.size.x = -dest.size.x
			if alternative & TileSetAtlasSource.TRANSFORM_FLIP_V:
				dest.size.y = -dest.size.y
			draw_texture_rect_region(entry.texture, dest, entry.region, Color.WHITE, (alternative & TileSetAtlasSource.TRANSFORM_TRANSPOSE) != 0)
		if entry.face > 0.0:
			# The edge of the top, catching the light.
			draw_rect(Rect2(entry.x, tile - entry.lift - 4.0, tile, 4.0), Color(1, 1, 1, 0.1))

	func _draw_face(entry: Dictionary):
		var tile := float(Grid.TILE_SIZE)
		var face := Rect2(entry.x, tile - entry.lift, tile, entry.face)
		if entry.face_picture != null:
			draw_texture_rect(entry.face_picture, face, false)
			return
		var colour: Color = entry.face_colour
		draw_rect(face, colour)
		# The lip's own shadow along the top of the face, and courses of stone or boards across it.
		draw_rect(Rect2(face.position, Vector2(tile, minf(10.0, entry.face * 0.2))), Color(0, 0, 0, 0.28))
		var courses := maxi(int(entry.face / 44.0), 1)
		for course in range(1, courses + 1):
			var y: float = face.position.y + entry.face * float(course) / float(courses + 1)
			draw_rect(Rect2(entry.x, y, tile, 3.0), Color(1, 1, 1, 0.07) if entry.wall else Color(0, 0, 0, 0.18))

	## A thing standing on the floor: its own picture, bigger, from where it stands. Each corner's colour says where it is across
	## the thing and down it, for the shader to round it by.
	func _draw_thing(entry: Dictionary):
		var stands: Rect2 = entry.dest
		var source: Rect2 = entry.source
		var size: Vector2 = entry.texture.get_size()
		var left: float = source.position.x / size.x
		var right: float = source.end.x / size.x
		if entry.get("flipped", false):
			var swap := left
			left = right
			right = swap
		var up: float = source.position.y / size.y
		var down: float = source.end.y / size.y
		draw_polygon(
			PackedVector2Array([stands.position, Vector2(stands.end.x, stands.position.y), stands.end, Vector2(stands.position.x, stands.end.y)]),
			PackedColorArray([Color(0, 0, 0), Color(1, 0, 0), Color(1, 1, 0), Color(0, 1, 0)]),
			PackedVector2Array([Vector2(left, up), Vector2(right, up), Vector2(right, down), Vector2(left, down)]),
			entry.texture)


## The three materials of the one shader: for the tops, the faces, and things standing.
func _materials() -> Array:
	return [_material, _face_material, _object_material]


## --- Light that knows height ---
##
## C of the three (the designer and their artist, 2026-11-13). The real lights never reach what stands inside a wall's or a
## barrel's own square (it is their occluder), so RAISED_SHADER lights what is lifted itself, from the lamps LightView tells the
## figures of (_tell_the_lamps: where each is and how strong this moment, so they move and breathe): by which way each piece faces -
## a top up, a face towards us, so a lamp in front of it lights it and one behind it does not, a thing standing round, lit on the
## side the lamp is - and only where the light's own rule says a lamp reaches (_gate_the_light, from LightMap.glow: a face asks of
## the floor in front of it), so nothing is lit through a wall. A picture in a slot with a normal map beside it (`_n` before
## `.png`, Depth.slot) faces as that says. The lamps' own shadows already fall off every wall and barrel (LightView's occluders). And the foot of every wall and raised edge is shaded on the floor: FOOT_SHADER over a mask a pixel a tile of how
## high each tile stands, which the filter fades across the floor beside it; under the shade, as the ledges' shadows are.

## How strong a lamp's light is on what is lifted, against what the real light gives the floor beside it; how high over the floor a
## lamp is taken to hang, for which way its light comes; and how lit by a lamp the floor has to be (LightMap.glow's strength)
## for what stands on it or over it to be lit at all.
const LAMP_GAIN := 1.6
const LAMP_HEIGHT_TILES := 0.5
const GATE_FROM := 0.04
## The most lamps told to the shader at once: the nearest to the middle of the view.
const MOST_LAMPS := 8

## Which tiles a lamp's light reaches, by the light's own rule: a pixel a tile, for the shader to ask.
var _gate: ImageTexture = null
var _gate_map: LightMap = null
var _gate_version := -1


## The lamps, told to the rows every frame: where each is and how strong this moment (they move and breathe), from what LightView
## tells the figures; and where their light reaches at all, from the light's own map, again whenever that has been worked out anew.
func _tell_the_lamps():
	var view: LightView = LightView.showing
	var map: LightMap = view.light if view != null and is_instance_valid(view) else null
	var points: Array = CombatantSprite.light_points
	if map == null or points.is_empty() or not view.visible:
		for material in _materials():
			material.set_shader_parameter("lamp_count", 0)
		return
	if map != _gate_map or map.version != _gate_version:
		_gate_map = map
		_gate_version = map.version
		_gate_the_light(map)
	var middle: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * (Vector2(get_viewport().get_visible_rect().size) * 0.5)
	var nearest := points.duplicate()
	if nearest.size() > MOST_LAMPS:
		nearest.sort_custom(func(one, other): return _lamp_at(one).distance_squared_to(middle) < _lamp_at(other).distance_squared_to(middle))
		nearest.resize(MOST_LAMPS)
	var lamps := PackedVector4Array()
	var colours := PackedVector3Array()
	for point in nearest:
		var at := _lamp_at(point)
		var node = point.get("node")
		var energy: float = node.energy if node != null and is_instance_valid(node) else float(point.get("energy", 1.0))
		# As a share of a lamp's full strength: a torch is little by day, and one coming on or going out is on its way.
		lamps.append(Vector4(at.x, at.y, point.reach, energy / LightView.ENERGY))
		var colour: Color = node.color if node != null and is_instance_valid(node) else point.get("colour", Color.WHITE)
		colours.append(Vector3(colour.r, colour.g, colour.b))
	var count := lamps.size()
	lamps.resize(MOST_LAMPS)
	colours.resize(MOST_LAMPS)
	var tile := float(Grid.TILE_SIZE)
	var region := _region.grow(1)
	var origin: Vector2 = _tile_map.to_global(_tile_map.map_to_local(region.position)) - Vector2(tile, tile) * 0.5
	for material in _materials():
		material.set_shader_parameter("lamp_count", count)
		material.set_shader_parameter("lamps", lamps)
		material.set_shader_parameter("lamp_colours", colours)
		material.set_shader_parameter("lit_gate", _gate)
		material.set_shader_parameter("gate_rect", Vector4(origin.x, origin.y, region.size.x * tile, region.size.y * tile))
		material.set_shader_parameter("lamp_gain", LAMP_GAIN)
		material.set_shader_parameter("lamp_height", tile * LAMP_HEIGHT_TILES)


static func _lamp_at(point: Dictionary) -> Vector2:
	var node = point.get("node")
	return node.global_position if node != null and is_instance_valid(node) else point.at


## Whether a lamp's light reaches `tile` of `map` at all, by the light's own rule and what stops it.
static func lamp_reaches(map: LightMap, tile: Vector2i) -> bool:
	return map != null and map.glow.has(tile) and map.glow[tile].a > GATE_FROM


func _gate_the_light(map: LightMap):
	var region := _region.grow(1)
	var mask := Image.create(region.size.x, region.size.y, false, Image.FORMAT_L8)
	for tile in map.glow:
		var at: Vector2i = tile - region.position
		if at.x >= 0 and at.y >= 0 and at.x < region.size.x and at.y < region.size.y and map.glow[tile].a > GATE_FROM:
			mask.set_pixelv(at, Color.WHITE)
	_gate = ImageTexture.create_from_image(mask)


## How dark the floor is right at the foot of a wall, 0 to 1. Raised ground shades it by its height.
const FOOT_SHADE := 0.42
const FOOT_SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform float strength = 0.42;
void fragment() {
	// How high what stands here is, a pixel a tile: half of it at its edge, fading to nothing at the middle of the floor beside it.
	float high = texture(TEXTURE, UV).r;
	COLOR = vec4(0.03, 0.03, 0.07, strength * smoothstep(0.07, 0.5, high));
}
"""


## How dark the foot of something `rise` high is in the mask, 0 to 1: a wall wholly, raised ground and things by their height.
static func foot_of(rise: float) -> float:
	return clampf(rise / Depth.WALL_LIFT, 0.0, 1.0)


func _shade_the_feet():
	if _feet == null:
		return
	# Not under a thing standing: its floor shows all round it, and a shaded square there reads as a darker tile.
	if _lifts.is_empty():
		_feet.visible = false
		return
	var region := _region.grow(1)
	var mask := Image.create(region.size.x, region.size.y, false, Image.FORMAT_L8)
	for at in _lifts:
		mask.set_pixelv(at - region.position, Color(foot_of(_lifts[at]), 0.0, 0.0))
	var tile := float(Grid.TILE_SIZE)
	_feet.texture = ImageTexture.create_from_image(mask)
	_feet.scale = Vector2(tile, tile)
	_feet.position = to_local(_tile_map.to_global(_tile_map.map_to_local(region.position))) - Vector2(tile, tile) * 0.5
	_feet.visible = true


func _process(_delta: float):
	if _tile_map == null:
		return
	_tell_the_shade()
	_tell_the_lamps()
	_keep_the_uprights()
	_sort_the_figures()
	_keep_the_shadows()


## The shade's own picture, for the rows to darken themselves by: what the figures read.
func _tell_the_shade():
	var on := CombatantSprite.shade_map != null
	for material in _materials():
		material.set_shader_parameter("shade_on", 1.0 if on else 0.0)
	if not on:
		return
	var rect: Rect2 = CombatantSprite.shade_rect
	for material in _materials():
		material.set_shader_parameter("shade_map", CombatantSprite.shade_map)
		material.set_shader_parameter("shade_previous", CombatantSprite.shade_previous if CombatantSprite.shade_previous != null else CombatantSprite.shade_map)
		material.set_shader_parameter("shade_blend", CombatantSprite.shade_blend if CombatantSprite.shade_previous != null else 1.0)
		material.set_shader_parameter("shade_rect", Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
		material.set_shader_parameter("drain", LightView.DRAIN)


## On a map, every figure takes its z from where it stands, so the nearer is drawn over the further and a lifted row over whoever
## is behind it; and, on a map or in a fight, whoever stands behind a lifted row opens a cutaway in it.
func _sort_the_figures():
	var cuts := PackedVector3Array()
	var tile := float(Grid.TILE_SIZE)
	for figure in get_tree().get_nodes_in_group(Depth.FIGURES):
		if not is_instance_valid(figure) or not figure.is_inside_tree() or not figure is CombatantSprite:
			continue
		var at: Vector2 = figure.global_position
		if _layer == null and not figure.z_as_relative and figure.z_index >= ExplorationParty.PARTY_Z_BOTTOM and figure.z_index <= ExplorationParty.PARTY_Z_TOP:
			figure.z_index = Depth.z_at(at.y, _top)
		if _layer != null and figure.get_parent() == _layer:
			_keep_the_big_over(figure)
		if cuts.size() >= Depth.MOST_CUTS or (_rise.is_empty() and _upright_rise.is_empty()):
			continue
		if not Depth.opens_a_cutaway(figure.is_visible_in_tree(), figure._shown_alpha):
			continue
		var reach: float = Depth.CUT_TILES * tile * maxf(absf(figure.global_scale.x), absf(figure.global_scale.y))
		# About the middle of what is drawn, not the node: somebody bigger than a tile is drawn off their own tile, over the middle
		# of the square they cover (the designer, 2026-11-13: "Does the cutaway work for creatures that are bigger than human").
		var middle := body_middle(figure)
		if _covered(middle, reach):
			cuts.append(Vector3(middle.x, middle.y, reach))
	if _layer == null and not (_rise.is_empty() and _upright_rise.is_empty()):
		for thing in get_tree().get_nodes_in_group(Depth.THINGS):
			if not is_instance_valid(thing) or not thing is Node2D or not thing.is_inside_tree() or not thing.is_visible_in_tree():
				continue
			var where: Vector2 = thing.global_position
			var on := _tile_map.local_to_map(_tile_map.to_local(where))
			if _upright_rise.has(on) and thing.is_in_group(Depth.UPRIGHTS):
				# Standing, it is its own wall: nothing to be seen through to.
				continue
			if _lifts.has(on):
				# Lying on raised ground: drawn over it.
				var over := Depth.z_at(_tile_map.to_global(_tile_map.map_to_local(on)).y, _top)
				if thing.z_as_relative or thing.z_index < over:
					thing.z_as_relative = false
					thing.z_index = over
			elif cuts.size() < Depth.MOST_CUTS and _covered(where, THING_CUT_TILES * tile):
				cuts.append(Vector3(where.x, where.y, THING_CUT_TILES * tile))
	for point in more_cuts:
		if cuts.size() < Depth.MOST_CUTS and _covered(point, Depth.CUT_TILES * tile):
			cuts.append(Vector3(point.x, point.y, Depth.CUT_TILES * tile))
	_cuts = cuts
	var count := cuts.size()
	if count > 0:
		cuts.resize(Depth.MOST_CUTS)
	for material in _materials():
		material.set_shader_parameter("cut_count", count)
		if count > 0:
			material.set_shader_parameter("cuts", cuts)


## Other places in the world to keep in view through what is lifted: the tile a fight's pointer is on (CController).
var more_cuts: Array = []
## The cutaways open now, each (x, y, reach) in the world (for a test).
var _cuts := PackedVector3Array()


func cuts_now() -> PackedVector3Array:
	return _cuts


## Somebody bigger than a tile sorts from their top-left tile, as ever, so a barrel or raised ground among their feet - the big step
## over high ground (Combat.steps_over_size) - would be drawn over their legs. While any lies in the rows they cover below their
## first, they are drawn over everything in the figures' layer instead; and back as they were once none does.
func _keep_the_big_over(figure: CombatantSprite):
	var wide := roundi(absf(figure.scale.x))
	var deep := roundi(absf(figure.scale.y))
	var over := false
	if deep >= 2 and not (_objects.is_empty() and _lifts.is_empty()):
		var first := _tile_map.local_to_map(_tile_map.to_local(figure.global_position))
		for dy in range(1, deep):
			for dx in wide:
				var tile := first + Vector2i(dx, dy)
				if _objects.has(tile) or (_lifts.has(tile) and _lifts[tile] < Depth.WALL_LIFT):
					over = true
	if over and figure.z_index == 1:
		figure.z_index = 2
		figure.set_meta("depth_over", true)
	elif not over and figure.has_meta("depth_over"):
		figure.remove_meta("depth_over")
		if figure.z_index == 2:
			figure.z_index = 1


## The middle of what is drawn of `figure`, in the world: its node, and for somebody bigger or smaller than a tile where their
## drawing sits off it (CombatantSprite.set_size_offset), as high as they stand up.
static func body_middle(figure: CombatantSprite) -> Vector2:
	return figure.global_position + figure._placed - Vector2(0.0, figure.ground_lift)


## Whether anything lifted stands in front of somebody whose middle is at `at`, near enough to cover them: in the rows to their
## south, within `reach` to either side, and reaching up into the round patch `reach` about them.
func _covered(at: Vector2, reach: float) -> bool:
	var tile := float(Grid.TILE_SIZE)
	var here := _tile_map.local_to_map(_tile_map.to_local(at))
	var across := maxi(ceili(reach / tile), 1)
	for dy in range(1, across + 2):
		# The north edge of that row, in the world.
		var north: float = _tile_map.to_global(_tile_map.map_to_local(here + Vector2i(0, dy))).y - tile * 0.5
		for dx in range(-across, across + 1):
			var lift: float = maxf(_rise.get(here + Vector2i(dx, dy), 0.0), _upright_rise.get(here + Vector2i(dx, dy), 0.0))
			# Its top edge, drawn `lift` over that: it has to come up into the patch.
			if lift > 0.0 and north - lift - at.y < reach:
				return true
	return false


## --- What a map's own nodes stand up ---
##
## A shut door and a wall that can be broken are nodes on a floor tile, not tiles (the designer, 2026-11-13: "A door is just a
## placeholder of a single colour right? It should be easy to lift when appropriate"). Each is in Depth.UPRIGHTS and says how high
## it stands now (depth_lift: a wall's lift shut or standing, 0 open or broken), the colour of its top (depth_top) and how its front
## is drawn (depth_paint). Here each gets a child that draws it lifted, as a wall tile is: sorted from its north edge, darkened by
## the shade, seen through about whoever is behind it. Asked every frame, so a door opening drops at once. Only on a map: neither
## is in a fight.

## How high each stands now, {tile: lift}, for the cutaway.
var _upright_rise := {}


class _Upright extends Node2D:
	var lift := 0.0
	var face := 0.0
	var top := Color(0.4, 0.4, 0.42)
	var painter := Callable()

	func _draw():
		if lift <= 0.0:
			return
		var tile := float(Grid.TILE_SIZE)
		var half := tile * 0.5
		var above := Rect2(-half, -lift, tile, tile)
		draw_rect(above, top)
		draw_rect(above.grow(-3.0), top.darkened(0.3), false, 6.0)


## An upright's front: a node of its own, lit as a face is.
class _Front extends Node2D:
	func _draw():
		var upright: _Upright = get_parent()
		if upright.lift <= 0.0 or upright.face <= 0.0:
			return
		var tile := float(Grid.TILE_SIZE)
		var front := Rect2(-tile * 0.5, tile - upright.lift, tile, upright.face)
		if upright.painter.is_valid():
			upright.painter.call(self, front)
		else:
			draw_rect(front, upright.top.darkened(0.25))
		# The lip's own shadow along the top of the front.
		draw_rect(Rect2(front.position, Vector2(tile, minf(10.0, upright.face * 0.2))), Color(0, 0, 0, 0.28))


func _keep_the_uprights():
	if _layer != null:
		return
	var rise := {}
	var tile := float(Grid.TILE_SIZE)
	for node in get_tree().get_nodes_in_group(Depth.UPRIGHTS):
		if not is_instance_valid(node) or not node is Node2D or not node.is_inside_tree() or not node.has_method("depth_lift"):
			continue
		var lift: float = node.depth_lift() if node.is_visible_in_tree() else 0.0
		var upright: _Upright = node.get_node_or_null("DepthUpright")
		if upright == null:
			if lift <= 0.0:
				continue
			upright = _Upright.new()
			upright.name = "DepthUpright"
			# Its north edge: where it sorts from, and where the shader takes its ground from.
			upright.position = Vector2(0.0, -tile * 0.5)
			upright.material = _material
			upright.z_as_relative = false
			if node.has_method("depth_top"):
				upright.top = node.depth_top()
			if node.has_method("depth_paint"):
				upright.painter = node.depth_paint
			node.add_child(upright)
			var front := _Front.new()
			front.name = "Front"
			front.material = _face_material
			upright.add_child(front)
		var on := _tile_map.local_to_map(_tile_map.to_local(node.global_position))
		var face: float = maxf(lift - float(_lifts.get(on + Vector2i.DOWN, 0.0)), 0.0) if lift > 0.0 else 0.0
		if not is_equal_approx(lift, upright.lift) or not is_equal_approx(face, upright.face):
			upright.lift = lift
			upright.face = face
			upright.queue_redraw()
			for part in upright.get_children():
				part.queue_redraw()
		upright.visible = lift > 0.0
		upright.z_index = Depth.z_at(upright.global_position.y, _top)
		if lift > 0.0:
			rise[on] = lift
	_upright_rise = rise


## --- The shadow off every edge ---


## The shadows as the sun or the moon stands now: laid again only when it leans differently enough.
func _keep_the_shadows():
	if _shadows == null:
		return
	var strength: float = CombatantSprite.shadow_strength
	if (_lifts.is_empty() and _objects.is_empty()) or strength <= 0.01:
		_shadows.visible = false
		return
	var lean: float = CombatantSprite.shadow_lean
	if absf(lean - _shadow_lean) >= LEAN_STEP or _shadows.texture == null:
		_shadow_lean = lean
		_cast_the_shadows(lean)
	_shadows.visible = true
	_shadows.modulate = Color(CombatantSprite.shadow_colour, clampf(strength * LEDGE_SHADOW, 0.0, 0.8))


## How far a ledge `lift` high throws its shadow with the sun leaning `lean`, on the map: the way a figure's goes, as long as the
## ledge is high.
static func shadow_reach(lean: float, lift: float) -> Vector2:
	var way := Vector2(lean, CombatantSprite.SUN_SLANT).normalized()
	return way * minf(absf(lean) * 1.4 + 0.25, CombatantSprite.SUN_SHADOW_MOST) * lift


## The mask of where the ground is in a ledge's shadow, LEDGE_GRAIN samples to a tile: every lifted tile's square swept along its
## shadow, and a soft line at the foot of each face. What falls under something lifted is covered by it.
func _cast_the_shadows(lean: float):
	var grain := LEDGE_GRAIN
	var region := _region.grow(2)
	var width := region.size.x * grain
	var height := region.size.y * grain
	if width <= 0 or height <= 0:
		return
	var bytes := PackedByteArray()
	bytes.resize(width * height)
	var tile := float(Grid.TILE_SIZE)
	var cell := tile / float(grain)
	for at in _lifts:
		var lift: float = _lifts[at]
		var reach := shadow_reach(lean, lift) / cell
		var steps := maxi(ceili(maxf(absf(reach.x), absf(reach.y))), 1)
		var x0: int = (at.x - region.position.x) * grain
		var y0: int = (at.y - region.position.y) * grain
		var done := {}
		for step in range(0, steps + 1):
			var shift := Vector2i(roundi(reach.x * step / steps), roundi(reach.y * step / steps))
			if done.has(shift):
				continue
			done[shift] = true
			for gy in range(maxi(y0 + shift.y, 0), mini(y0 + shift.y + grain, height)):
				var line := gy * width
				for gx in range(maxi(x0 + shift.x, 0), mini(x0 + shift.x + grain, width)):
					bytes[line + gx] = 255
		if Depth.face_under(_lifts, at) > 0.0:
			for out in FOOT_SHADOW.size():
				var gy: int = y0 + grain + out
				if gy < 0 or gy >= height:
					continue
				for gx in range(maxi(x0, 0), mini(x0 + grain, width)):
					bytes[gy * width + gx] = maxi(bytes[gy * width + gx], FOOT_SHADOW[out])
	# What stands on the floor throws its own, from about where it meets the floor.
	for at in _objects:
		var thing: Dictionary = _objects[at]
		var reach := shadow_reach(lean, thing.tall * 0.8) / cell
		var steps := maxi(ceili(maxf(absf(reach.x), absf(reach.y))), 1)
		var north: float = (at.y - region.position.y) * tile
		var west: float = -float(region.position.x) * tile - (_tile_map.map_to_local(Vector2i.ZERO).x - tile * 0.5)
		var foot: Rect2 = thing.foot
		var x0 := floori((foot.position.x + west) / cell)
		var y0 := floori((foot.position.y + north) / cell)
		var x1 := ceili((foot.end.x + west) / cell)
		var y1 := ceili((foot.end.y + north) / cell)
		for step in range(0, steps + 1):
			var shift := Vector2i(roundi(reach.x * step / steps), roundi(reach.y * step / steps))
			for gy in range(maxi(y0 + shift.y, 0), mini(y1 + shift.y, height)):
				for gx in range(maxi(x0 + shift.x, 0), mini(x1 + shift.x, width)):
					bytes[gy * width + gx] = 255
	var picture := Image.create_from_data(width, height, false, Image.FORMAT_L8, bytes)
	picture.convert(Image.FORMAT_LA8)
	# White, with the shadow in its alpha.
	var data := picture.get_data()
	for i in range(0, data.size(), 2):
		data[i + 1] = data[i]
		data[i] = 255
	_shadows.texture = ImageTexture.create_from_image(Image.create_from_data(width, height, false, Image.FORMAT_LA8, data))
	_shadows.scale = Vector2(cell, cell)
	_shadows.position = to_local(_tile_map.to_global(_tile_map.map_to_local(region.position))) - Vector2(tile, tile) * 0.5
