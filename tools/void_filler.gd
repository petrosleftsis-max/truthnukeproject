@tool
extends Node
class_name VoidFiller
## Editor-only. Paints a chosen tile into every unpainted cell of a map, so the
## gaps in a non-rectangular map read as deliberate void rather than as holes
## where the artist stopped.
##
## How to use it:
##   1. Add the void tile to the map's TileSet, and give it Blocks = [0, 1, 2]
##      in the tile's custom data so nothing can walk, fly or ride onto it.
##   2. In the terrain scene, add a child Node to the root and attach this
##      script (or add a VoidFiller node).
##   3. Point Tile Map at the map's TileMap, set Source Id and Atlas Coords to
##      the void tile, and press "Fill holes with the void tile".
##   4. Save the terrain scene.
##
## Purely cosmetic. The game already treats an unpainted cell exactly as it
## treats a tile that blocks every movement class, so filling changes nothing
## about where anyone can stand or walk - it only changes what is drawn there.
## The one thing to know is that a filled cell stops being "an unpainted hole"
## and starts being "terrain nothing can enter", so that is how the encounter
## editor will describe a spawn dropped on one.


## The map to fill. Its TileSet must already contain the void tile.
@export var tile_map: TileMap
## Which tile to paint. Source Id is the atlas's id in the TileSet (the number
## beside it in the TileSet editor); Atlas Coords is the tile's position within
## that atlas, in tiles.
@export var source_id: int = 0
@export var atlas_coords: Vector2i = Vector2i.ZERO
## How far past the edge of the painted area to carry the void, in tiles. Zero
## fills only the holes inside the map. A few tiles of border makes the map sit
## on a deliberate field rather than ending abruptly.
@export_range(0, 20) var border_tiles: int = 0
## Which layer to paint into. 0 unless the map has been given extra layers.
@export var layer: int = 0

@export_tool_button("Fill holes with the void tile") var fill_action = fill
@export_tool_button("Remove the void tiles again") var clear_action = clear_void

## What the last press did. Read-only.
@export_multiline var status: String = ""


func fill():
	if not _ready_to_run():
		return
	# Captured before painting: filling changes what counts as used, and the
	# border would then walk outwards a ring at a time on every pass.
	var area = tile_map.get_used_rect().grow(border_tiles)
	var painted = 0
	for x in range(area.position.x, area.position.x + area.size.x):
		for y in range(area.position.y, area.position.y + area.size.y):
			var cell = Vector2i(x, y)
			if tile_map.get_cell_source_id(layer, cell) != -1:
				continue
			tile_map.set_cell(layer, cell, source_id, atlas_coords)
			painted += 1
	_report("Filled %d cells across %s. Save the scene to keep it." % [painted, area])
	_warn_if_walkable()


## Takes the void back out, leaving the map as it was. Only removes cells that
## are actually the void tile, so hand-painted terrain is never touched.
func clear_void():
	if not _ready_to_run():
		return
	var removed = 0
	for cell in tile_map.get_used_cells(layer):
		if tile_map.get_cell_source_id(layer, cell) != source_id:
			continue
		if tile_map.get_cell_atlas_coords(layer, cell) != atlas_coords:
			continue
		tile_map.erase_cell(layer, cell)
		removed += 1
	_report("Removed %d void cells. Save the scene to keep it." % removed)


func _ready_to_run() -> bool:
	if tile_map == null:
		_report("No TileMap assigned - point Tile Map at the map to fill.")
		return false
	if tile_map.tile_set == null:
		_report("That TileMap has no TileSet, so there is no tile to paint with.")
		return false
	if not tile_map.tile_set.has_source(source_id):
		_report("This TileSet has no source %d. Check the number beside the atlas in the TileSet editor." % source_id)
		return false
	return true


## The void is meant to be impassable. If the tile chosen doesn't block, the
## fill has quietly opened up every hole in the map to walk through, which is a
## much worse outcome than the cosmetic problem it was meant to solve.
func _warn_if_walkable():
	var source = tile_map.tile_set.get_source(source_id)
	if not source is TileSetAtlasSource:
		return
	var data = source.get_tile_data(atlas_coords, 0)
	if data == null:
		return
	var blocks = data.get_custom_data("Blocks")
	var missing = []
	for movement_class in [0, 1, 2]:
		if not (blocks is Array and movement_class in blocks):
			missing.append(movement_class)
	if missing.is_empty():
		return
	var complaint = "The void tile does not block movement classes %s - units can now walk into the holes. Set Blocks = [0, 1, 2] on it in the TileSet editor." % [missing]
	status += "\n" + complaint
	push_warning(complaint)


func _report(message: String):
	status = message
	notify_property_list_changed()
	print(message)
