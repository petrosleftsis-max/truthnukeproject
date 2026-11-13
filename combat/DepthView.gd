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
varying vec2 world;
varying float north;
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	north = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).y;
}
void fragment() {
	// COLOR comes in as the picture's own colour already.
	vec4 colour = COLOR;
	if (shade_on > 0.5) {
		// The ground this row stands on, not the ground it is drawn over.
		vec2 on_shade = (vec2(world.x, north + half_tile) - shade_rect.xy) / shade_rect.zw;
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
	_material.set_shader_parameter("half_tile", float(Grid.TILE_SIZE) * 0.5)
	_material.set_shader_parameter("cut_alpha", Depth.CUT_ALPHA)
	_material.set_shader_parameter("cut_soft", Depth.CUT_SOFT)
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
		var row := _Row.new()
		row.name = "Row%d" % y
		row.material = _material
		var first: Vector2 = _tile_map.map_to_local(Vector2i(0, y))
		# Its north edge, in the tile map's own coordinates: where it sorts from.
		row.position = Vector2(0.0, first.y - tile * 0.5)
		var tiles: Array = by_row[y]
		tiles.sort_custom(func(one, other): return one.x < other.x)
		for at in tiles:
			row.tiles.append(_objects[at] if _objects.has(at) else _entry(at))
		if _layer != null:
			# With the figures, sorted by where each stands.
			row.z_index = 1
			_layer.add_child(row)
		else:
			add_child(row)
			row.z_as_relative = false
			row.z_index = Depth.z_at(_tile_map.to_global(row.position).y, _top)
		_rows.append(row)
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


## One row of lifted tiles: each one's picture drawn `lift` higher, and its face under it.
class _Row extends Node2D:
	var tiles: Array = []

	func _draw():
		var tile := float(Grid.TILE_SIZE)
		for entry in tiles:
			if entry.get("object", false):
				# A thing standing on the floor: its own picture, bigger, from where it stands.
				var stands: Rect2 = entry.dest
				if entry.get("flipped", false):
					stands.size.x = -stands.size.x
				draw_texture_rect_region(entry.texture, stands, entry.source)
				continue
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
			if entry.face <= 0.0:
				continue
			var face := Rect2(entry.x, tile - entry.lift, tile, entry.face)
			if entry.face_picture != null:
				draw_texture_rect(entry.face_picture, face, false)
				continue
			var colour: Color = entry.face_colour
			draw_rect(face, colour)
			# The lip's own shadow along the top of the face, and courses of stone or boards across it.
			draw_rect(Rect2(face.position, Vector2(tile, minf(10.0, entry.face * 0.2))), Color(0, 0, 0, 0.28))
			var courses := maxi(int(entry.face / 44.0), 1)
			for course in range(1, courses + 1):
				var y: float = face.position.y + entry.face * float(course) / float(courses + 1)
				draw_rect(Rect2(entry.x, y, tile, 3.0), Color(1, 1, 1, 0.07) if entry.wall else Color(0, 0, 0, 0.18))
			# The edge of the top, catching the light.
			draw_rect(Rect2(entry.x, face.position.y - 4.0, tile, 4.0), Color(1, 1, 1, 0.1))


func _process(_delta: float):
	if _tile_map == null:
		return
	_tell_the_shade()
	_keep_the_uprights()
	_sort_the_figures()
	_keep_the_shadows()


## The shade's own picture, for the rows to darken themselves by: what the figures read.
func _tell_the_shade():
	var on := CombatantSprite.shade_map != null
	_material.set_shader_parameter("shade_on", 1.0 if on else 0.0)
	if not on:
		return
	var rect: Rect2 = CombatantSprite.shade_rect
	_material.set_shader_parameter("shade_map", CombatantSprite.shade_map)
	_material.set_shader_parameter("shade_previous", CombatantSprite.shade_previous if CombatantSprite.shade_previous != null else CombatantSprite.shade_map)
	_material.set_shader_parameter("shade_blend", CombatantSprite.shade_blend if CombatantSprite.shade_previous != null else 1.0)
	_material.set_shader_parameter("shade_rect", Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
	_material.set_shader_parameter("drain", LightView.DRAIN)


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
		if cuts.size() >= Depth.MOST_CUTS or (_rise.is_empty() and _upright_rise.is_empty()):
			continue
		if not Depth.opens_a_cutaway(figure.is_visible_in_tree(), figure._shown_alpha):
			continue
		var reach: float = Depth.CUT_TILES * tile * maxf(absf(figure.global_scale.x), absf(figure.global_scale.y))
		if _covered(at, reach):
			cuts.append(Vector3(at.x, at.y, reach))
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
	_material.set_shader_parameter("cut_count", cuts.size())
	if not cuts.is_empty():
		cuts.resize(Depth.MOST_CUTS)
		_material.set_shader_parameter("cuts", cuts)


## Other places in the world to keep in view through what is lifted: the tile a fight's pointer is on (CController).
var more_cuts: Array = []
## The cutaways open now, each (x, y, reach) in the world (for a test).
var _cuts := PackedVector3Array()


func cuts_now() -> PackedVector3Array:
	return _cuts


## Whether anything lifted stands in front of somebody at `at` near enough to cover them: in the row to their south, within
## `reach` to either side.
func _covered(at: Vector2, reach: float) -> bool:
	var here := _tile_map.local_to_map(_tile_map.to_local(at))
	var across := maxi(ceili(reach / float(Grid.TILE_SIZE)), 1)
	for dx in range(-across, across + 1):
		for dy in [1, 2]:
			var lift: float = maxf(_rise.get(here + Vector2i(dx, dy), 0.0), _upright_rise.get(here + Vector2i(dx, dy), 0.0))
			# The second row down only reaches them if it is lifted more than a tile.
			if lift > 0.0 and (dy == 1 or lift > float(Grid.TILE_SIZE)):
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
		if face <= 0.0:
			return
		var front := Rect2(-half, tile - lift, tile, face)
		if painter.is_valid():
			painter.call(self, front)
		else:
			draw_rect(front, top.darkened(0.25))
		# The lip's own shadow along the top of the front.
		draw_rect(Rect2(front.position, Vector2(tile, minf(10.0, face * 0.2))), Color(0, 0, 0, 0.28))


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
		var on := _tile_map.local_to_map(_tile_map.to_local(node.global_position))
		var face: float = maxf(lift - float(_lifts.get(on + Vector2i.DOWN, 0.0)), 0.0) if lift > 0.0 else 0.0
		if not is_equal_approx(lift, upright.lift) or not is_equal_approx(face, upright.face):
			upright.lift = lift
			upright.face = face
			upright.queue_redraw()
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
