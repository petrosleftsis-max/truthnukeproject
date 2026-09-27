@tool
extends Node
class_name LayoutPainter
## A quick way to rough out a map in the editor: add one of these beside a
## TileMap, type the layout into Layout - one character a tile, see
## StagePainter for what each means - and tick Paint Now. The TileMap is
## painted in the laboratory's style, walls worked out for you. Paint again
## after any change to the text; touch up by hand with the TileMap editor
## afterwards as usual.
##
## For designing only: it does nothing while the game runs, and can be deleted
## once the map is painted.

## The TileMap to paint. Empty: a sibling called TileMap.
@export var tile_map: TileMap
## Where the layout's top-left corner goes, in tiles.
@export var origin: Vector2i = Vector2i.ZERO
@export_multiline var layout: String = ""
## Tick to paint. It unticks itself.
@export var paint_now: bool = false : set = _paint


func _paint(value: bool):
	paint_now = false
	if not value:
		return
	var target = tile_map
	if target == null and get_parent() != null:
		target = get_parent().get_node_or_null("TileMap")
	if target == null:
		push_warning("LayoutPainter: no TileMap to paint - set Tile Map, or put this beside one called TileMap.")
		return
	var rows := PackedStringArray()
	for line in layout.split("\n"):
		rows.append(line.rstrip("\r"))
	StagePainter.paint(target, rows, origin)
