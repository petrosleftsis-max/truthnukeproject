@tool
@icon("res://art/editor_icons/interactable.svg")
extends Node2D
class_name ShiftingRoom
## A room of the archive that will not stay put (the proposals of 2026-11-19, "The archive that rearranges"; the designer: "Do all").
## Placed on its top left tile, Size Tiles across, with its layouts as hidden TileMap children (named anything): while the whole of
## it is out of the view and nobody of the party is in it, it takes the next layout - its tiles copied from that child onto the
## map's own, walls, doors and all - and the map is read again (walking, light, depth). Not more often than Every Seconds. Heard
## faintly, if near (SoundBank "shift"). PROPOSAL.

@export var size_tiles: Vector2i = Vector2i(6, 5):
	set(value):
		size_tiles = Vector2i(maxi(value.x, 1), maxi(value.y, 1))
		queue_redraw()
@export var every_seconds: float = 4.0

var layout := 0
var _wait := 0.0
## For a suite: how many times it has changed.
var shifts := 0


func _ready():
	if Engine.is_editor_hint():
		return
	for child in layouts():
		child.visible = false
	_wait = every_seconds


func layouts() -> Array:
	return get_children().filter(func(child): return child is TileMap)


## The world rectangle it covers.
func covers_rect() -> Rect2:
	var tile := float(Grid.TILE_SIZE)
	return Rect2(global_position - Vector2.ONE * tile / 2.0, Vector2(size_tiles) * tile)


func _scene() -> Node:
	var up := get_parent()
	while up != null:
		if up.has_method("party_position") and up.get("_tile_map") != null:
			return up
		up = up.get_parent()
	return null


## Whether any of it is in the view, or the party in it.
func is_watched(scene: Node) -> bool:
	var view := scene.get_viewport()
	var shown := view.get_canvas_transform().affine_inverse() * Rect2(Vector2.ZERO, view.get_visible_rect().size)
	return shown.grow(Grid.tiles(1.0)).intersects(covers_rect()) or covers_rect().has_point(scene.party_position())


func _process(delta: float):
	if Engine.is_editor_hint() or layouts().size() < 2:
		return
	_wait -= delta
	if _wait > 0.0:
		return
	var scene := _scene()
	if scene == null or is_watched(scene):
		return
	_wait = every_seconds
	shift(scene)


## Takes the next layout: its tiles onto the map, and the map read again.
func shift(scene: Node):
	var all := layouts()
	layout = (layout + 1) % all.size()
	var source: TileMap = all[layout]
	var tile_map: TileMap = scene._tile_map
	var corner := tile_map.local_to_map(tile_map.to_local(global_position))
	var from := source.local_to_map(source.to_local(global_position))
	for y in size_tiles.y:
		for x in size_tiles.x:
			var cell := from + Vector2i(x, y)
			var at := corner + Vector2i(x, y)
			var source_id := source.get_cell_source_id(0, cell)
			if source_id < 0:
				tile_map.erase_cell(0, at)
			else:
				tile_map.set_cell(0, at, source_id, source.get_cell_atlas_coords(0, cell), source.get_cell_alternative_tile(0, cell))
	scene._build_blocking()
	scene._gather_climbing()
	if scene.has_method("relight_map"):
		scene.relight_map()
	var depth = scene.get("depth_view")
	if depth != null and is_instance_valid(depth) and depth.has_method("build"):
		depth.build()
	shifts += 1
	if scene.party_position().distance_to(covers_rect().get_center()) < Grid.tiles(12.0):
		MapFeel.sound(&"shift", -10.0, 1.0, covers_rect().get_center())


func _draw():
	if not Engine.is_editor_hint():
		return
	var tile := float(Grid.TILE_SIZE)
	var rect := Rect2(-Vector2.ONE * tile / 2.0, Vector2(size_tiles) * tile)
	draw_rect(rect, Color(0.4, 0.9, 0.7, 0.12))
	draw_rect(rect, Color(0.4, 0.9, 0.7, 0.8), false, 4.0)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(8, 28), "Shifting room (%d layouts)" % layouts().size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.6, 1.0, 0.85))
