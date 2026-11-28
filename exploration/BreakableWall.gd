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


## Light shows through its crack while it stands (the proposals of 2026-11-19, "Secrets worth finding"): a hint there is something
## behind it. A secret is counted on the map screen and found once broken.
@export var light_through: bool = true
@export var secret: bool = false

## Drawn as the wall tiles beside it are - their picture, their face standing up - with cracks across it (the designer,
## 2026-11-27: "Make the breakable wall look like a normal wall, except with cracks"). Off: courses of stone, or Look.
@export var like_the_walls: bool = false : set = _set_like_the_walls

@export_group("What it hides")
## Tiles kept out of the party's sight while it stands, however they might be seen (HiddenPlaces), from one corner to the other;
## broken, they are seen at once (the designer, 2026-11-27: "When it breaks, it should be revealed to them the path").
@export var hides: bool = false
@export var hides_from: Vector2i = Vector2i.ZERO
@export var hides_to: Vector2i = Vector2i.ZERO
@export_group("")


func _set_like_the_walls(value: bool):
	like_the_walls = value
	_beside = {}
	queue_redraw()


## The tiles it hides (What it hides), or none.
func hidden_tiles() -> Array:
	if not hides:
		return []
	var tiles := []
	for x in range(mini(hides_from.x, hides_to.x), maxi(hides_from.x, hides_to.x) + 1):
		for y in range(mini(hides_from.y, hides_to.y), maxi(hides_from.y, hides_to.y) + 1):
			tiles.append(Vector2i(x, y))
	return tiles


## The wall tile beside it, as the map draws it: {texture, region, face (its colour standing up)} - or {} with none beside it.
var _beside := {}


func _wall_beside() -> Dictionary:
	if not _beside.is_empty() or not like_the_walls:
		return _beside
	var tile_map: TileMap = null
	if get_parent() != null:
		for child in get_parent().get_children():
			if child is TileMap:
				tile_map = child
				break
	if tile_map == null or tile_map.tile_set == null:
		return {}
	var at := tile_map.local_to_map(tile_map.to_local(global_position))
	for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var data = tile_map.get_cell_tile_data(0, at + step)
		if data == null or not 0 in data.get_custom_data("Blocks"):
			continue
		var source = tile_map.tile_set.get_source(tile_map.get_cell_source_id(0, at + step))
		if not source is TileSetAtlasSource:
			continue
		var atlas := tile_map.get_cell_atlas_coords(0, at + step)
		var face := STONE
		if not Engine.is_editor_hint():
			atlas = Depth.TOP_STAND_INS.get(atlas, atlas)
			face = DepthView._look_of(source, atlas).lightened(DepthView.WALL_FACE_LIGHTER)
		_beside = {"texture": source.texture, "region": Rect2(source.get_tile_texture_region(atlas)), "face": face}
		return _beside
	return {}


## Cracks across `rect`, scaled to it: dark lines, and light along the main one while something lies behind.
func _draw_cracks(canvas: CanvasItem, rect: Rect2):
	var lines := [
		[Vector2(0.42, 0.0), Vector2(0.55, 0.28), Vector2(0.44, 0.52), Vector2(0.58, 0.78), Vector2(0.5, 1.0)],
		[Vector2(0.55, 0.28), Vector2(0.78, 0.36), Vector2(0.9, 0.3)],
		[Vector2(0.44, 0.52), Vector2(0.24, 0.6), Vector2(0.12, 0.74)],
		[Vector2(0.58, 0.78), Vector2(0.74, 0.88)],
	]
	for i in lines.size():
		var points := PackedVector2Array()
		for point in lines[i]:
			points.append(rect.position + point * rect.size)
		canvas.draw_polyline(points, CRACK, 6.0 if i == 0 else 4.0)
		if i == 0 and light_through:
			canvas.draw_polyline(points, Color(1.0, 0.86, 0.55, 0.7), 2.0)


func _ready():
	z_as_relative = false
	z_index = ExplorationParty.PARTY_Z_BOTTOM - 2
	if not Engine.is_editor_hint():
		add_to_group(Depth.UPRIGHTS)
		if secret:
			add_to_group(&"secrets")


## A secret found: broken through.
func is_found() -> bool:
	return broken


## Standing, it is as tall as the walls beside it (DepthView "What a map's own nodes stand up"); broken, it is the rubble drawn
## below.
func depth_lift() -> float:
	return 0.0 if broken else Depth.lift_of(Depth.Kind.WALL)


func depth_top() -> Color:
	return STONE.darkened(0.25)


## Its top, standing up (DepthView), drawn like the walls beside it: their picture, cracked.
func depth_paint_top(canvas: CanvasItem, above: Rect2, _whole: Rect2 = Rect2()):
	var beside := _wall_beside()
	if beside.is_empty():
		canvas.draw_rect(above, depth_top())
		return
	canvas.draw_texture_rect_region(beside.texture, above, beside.region)
	_draw_cracks(canvas, above)


## Its front, drawn on `canvas` in `front`: like the walls beside it with cracks, its own picture, or courses of stone with a crack
## down them.
func depth_paint(canvas: CanvasItem, front: Rect2, _whole: Rect2 = Rect2()):
	var beside := _wall_beside()
	if not beside.is_empty():
		canvas.draw_rect(front, beside.face)
		var picture := Depth.slot("wall_face") if not Engine.is_editor_hint() else null
		if picture != null:
			canvas.draw_texture_rect(picture, front, false)
		_draw_cracks(canvas, front)
		return
	if look != null:
		canvas.draw_texture_rect(look, front, false)
		return
	canvas.draw_rect(front, STONE)
	for row in range(1, 3):
		var y: float = front.position.y + front.size.y * row / 3.0
		canvas.draw_line(Vector2(front.position.x, y), Vector2(front.end.x, y), MORTAR, 4.0)
	var crack := PackedVector2Array()
	for point in [Vector2(0.4, 0.0), Vector2(0.55, 0.35), Vector2(0.42, 0.6), Vector2(0.6, 1.0)]:
		crack.append(front.position + point * front.size)
	canvas.draw_polyline(crack, CRACK, 5.0)
	# Light from whatever is behind it, along the crack.
	if light_through:
		canvas.draw_polyline(crack, Color(1.0, 0.86, 0.55, 0.85), 2.0)
	canvas.draw_rect(front, MORTAR, false, 6.0)


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
	var beside := _wall_beside()
	if not beside.is_empty():
		# The wall tile beside it, cracked.
		draw_texture_rect_region(beside.texture, Rect2(-half, -half, tile, tile), beside.region)
		_draw_cracks(self, Rect2(-half, -half, tile, tile))
	elif look != null:
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
