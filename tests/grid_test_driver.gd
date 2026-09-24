extends Node
## The tile grid drawn over a map: does it cover the map, and only the map?

var LOG_PATH := HarnessLog.path_for("grid")

var _log: FileAccess = null
var _fail = 0


func log_line(t: String):
	if _log:
		_log.store_line(t)
		_log.flush()


func ok(condition: bool, label: String, detail: String = ""):
	if condition:
		log_line("  PASS  %s %s" % [label, detail])
	else:
		_fail += 1
		log_line("  FAIL  %s %s" % [label, detail])


func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(120.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


func run_test():
	for path in ["res://scenes/terrain.tscn", "res://scenes/sapperTerrain.tscn", "res://scenes/explore_crossroads.tscn"]:
		log_line("======== %s ========" % path)
		var scene = load(path).instantiate()
		get_tree().root.add_child(scene)
		await get_tree().process_frame
		var tile_map: TileMap = scene.get_node_or_null("TileMap")
		var grid = scene.get_node_or_null("Grid")
		ok(tile_map != null, "the map is there")
		ok(grid != null, "and a grid with it")
		if tile_map == null or grid == null:
			scene.queue_free()
			continue
		ok(grid is GridOverlay, "the grid works itself out from the map rather than being painted",
			grid.get_class())
		ok(not grid.visible, "off until something turns it on")

		# The grid is drawn, so what it covers is what it would draw: one cell
		# per painted tile, at the tile size the rest of the game uses.
		var painted = tile_map.get_used_cells(0)
		ok(grid._tile_map() == tile_map, "it reads the map beside it")
		var rect = tile_map.get_used_rect()
		ok(painted.size() > 0, "the map has tiles", "%d" % painted.size())
		# The old painted grid was a fixed 21x17 patch at the origin. Anything
		# that size again means it stopped following the map.
		ok(rect.size != Vector2i(21, 17), "the map is not the old 21x17 patch", "%s" % rect.size)

		# Not the corner of the bounding box: a map with a ragged edge has nothing
		# painted there. What matters is that the grid runs the full width and
		# height of what IS painted, rather than stopping partway as it used to.
		var covers_unpainted = false
		var widest = 0
		var tallest = 0
		for cell in painted:
			widest = maxi(widest, cell.x - rect.position.x + 1)
			tallest = maxi(tallest, cell.y - rect.position.y + 1)
			if tile_map.get_cell_tile_data(0, cell) == null:
				covers_unpainted = true
		ok(widest == rect.size.x and tallest == rect.size.y,
			"the grid runs the full extent of the map", "%dx%d of %s" % [widest, tallest, rect.size])
		ok(not covers_unpainted, "and never draws over a hole in it")
		ok(Grid.TILE_SIZE == tile_map.tile_set.tile_size.x,
			"drawn at the same tile size the map uses, so it lines up",
			"%d vs %d" % [Grid.TILE_SIZE, tile_map.tile_set.tile_size.x])
		scene.queue_free()
		await get_tree().process_frame
		log_line("")

	log_line("======== which mode it is decides whether it shows ========")
	# The scenes above save it switched off; two others save it on. That was a
	# coin toss rather than a decision, and crossroads_terrain is the same scene
	# used for walking about AND for the ambush fought on it, so no setting in
	# a scene file could tell the two apart. The mode settles it at load.
	var ambush: EncounterDefinition = load("res://encounters/encounter_01_ambush.tres")
	var fight_terrain = ambush.terrain_scene.resource_path
	log_line("  NOTE  the ambush is fought on %s" % fight_terrain)

	Campaign.reset()
	Campaign.current_map = "res://scenes/explore_crossroads.tscn"
	var walking = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(walking)
	for i in 6:
		await get_tree().process_frame
	var walked_grid = _find_grid(walking)
	ok(walked_grid != null, "the exploration map has a grid to hide", "%s" % walked_grid)
	ok(walked_grid != null and not walked_grid.visible,
		"and walking about shows no grid")
	walking.queue_free()
	await get_tree().process_frame

	Campaign.reset()
	Campaign.current_encounter = ambush
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	for i in 8:
		await get_tree().process_frame
	var fight_grid = _find_grid(game.get_node_or_null("Terrain"))
	ok(fight_grid != null, "the battle has one too", "%s" % fight_grid)
	ok(fight_grid != null and fight_grid.visible, "and a battle is played on it")
	# The whole point: one scene on disk, two answers, decided by the mode.
	ok(fight_terrain == "res://scenes/crossroads_terrain.tscn",
		"and both were the same terrain scene, so only the mode could have decided",
		fight_terrain)
	game.queue_free()
	await get_tree().process_frame
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


## The grid anywhere under `node` - a map may wrap a terrain scene, so it is
## not always a direct child.
func _find_grid(node: Node):
	if node == null:
		return null
	for child in node.get_children():
		if child is GridOverlay:
			return child
		var deeper = _find_grid(child)
		if deeper != null:
			return deeper
	return null
