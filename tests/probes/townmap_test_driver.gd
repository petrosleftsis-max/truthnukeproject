extends Node
## A probe: the Town Demo's ground as text - what blocks a walker (#), open floor (.), nothing painted ( ), and the tiles the designer
## named on 2026-11-27 (D doors, X the door to another map, W the cracked wall, P the path behind it) - for placing things on it.

var LOG_PATH := HarnessLog.path_for("townmap")
var _log: FileAccess


func log_line(t): _log.store_line(t); _log.flush()


func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	await get_tree().process_frame
	var map: Node = load("res://maps/TownDemo.tscn").instantiate()
	var tiles: TileMap = map.get_node("TileMap")
	var used := tiles.get_used_rect()
	log_line("used rect: %s" % used)
	var marks := {Vector2i(0, 6): "D", Vector2i(6, 6): "D", Vector2i(26, 10): "D", Vector2i(33, 5): "D", Vector2i(52, -11): "X",
		Vector2i(34, 15): "W"}
	for y in range(16, 24):
		marks[Vector2i(34, y)] = "P"
	var header := "      "
	for x in range(used.position.x, used.end.x):
		header += str(posmod(x, 10))
	log_line(header)
	for y in range(used.position.y, used.end.y):
		var row := "%5d " % y
		for x in range(used.position.x, used.end.x):
			var tile := Vector2i(x, y)
			var data = tiles.get_cell_tile_data(0, tile)
			var ch := " "
			if data != null:
				var blocks: Array = data.get_custom_data("Blocks")
				ch = "#" if 0 in blocks else "."
			if marks.has(tile):
				ch = marks[tile] if ch != "#" else marks[tile].to_lower()
			row += ch
		log_line(row)
	log_line("(a lower-case mark stands on a tile that blocks)")
	for tile in marks:
		var data = tiles.get_cell_tile_data(0, tile)
		log_line("%s %s: %s" % [marks[tile], tile, "nothing painted" if data == null else ("blocks %s, atlas %s" % [data.get_custom_data("Blocks"), tiles.get_cell_atlas_coords(0, tile)])])
	map.free()
	log_line("FAILURES: 0")
	get_tree().quit(0)
