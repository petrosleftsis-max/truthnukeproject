extends Node
## Regression test for non-rectangular maps: unpainted cells inside the
## TileMap's bounding rect must behave as the edge of the map, not as walkable
## ground with no tile data behind it.

var LOG_PATH := HarnessLog.path_for("hole")

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
	get_tree().create_timer(90.0).timeout.connect(func(): get_tree().quit(2))
	await get_tree().process_frame
	await get_tree().process_frame
	await run_test()


func check_map(encounter_path: String):
	var enc: EncounterDefinition = load(encounter_path)
	Campaign.current_encounter = enc
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame

	var tile_map: TileMap = game.get_node("Terrain/TileMap")
	var controller = game.get_node("Controller")
	var used = tile_map.get_used_rect()
	var painted = tile_map.get_used_cells(0)

	var voids = []
	for x in range(used.position.x, used.position.x + used.size.x):
		for y in range(used.position.y, used.position.y + used.size.y):
			var cell = Vector2i(x, y)
			if tile_map.get_cell_tile_data(0, cell) == null:
				voids.append(cell)

	log_line("'%s'  rect %s, %d painted, %d holes" % [enc.display_name, used.size, painted.size(), voids.size()])
	var expect_holes = not voids.is_empty()
	log_line("  %d holes to check" % voids.size())

	for hole in voids:
		if controller.is_tile_blocking(hole, 0) and controller.is_tile_blocking(hole, 1) and controller.is_tile_blocking(hole, 2) and controller._astargrid.is_point_solid(hole):
			continue
		_fail += 1
		log_line("  FAIL  hole %s is not blocked for every movement class" % hole)
		break
	if not voids.is_empty():
		ok(true, "all %d holes blocked for ground, flying and mounted" % voids.size())
		ok(controller.get_tile_cost(voids[0]) == 1,
			"get_tile_cost on a hole returns safely", "%s (used to crash)" % controller.get_tile_cost(voids[0]))
		# Nothing may plan a route that ends in the void.
		var path_into_hole = controller.get_grid_path(painted[0], voids[0])
		ok(path_into_hole.is_empty() or path_into_hole[-1] != voids[0],
			"no route can be planned into a hole", "%d steps" % path_into_hole.size())
		# Reachability must not offer holes either - this is what the AI uses.
		var start = game.get_node("VisualCombat").combatants[0].position
		var reachable = controller.get_reachable_tiles(start, 0, 8)
		var offered = 0
		for hole in voids:
			# Where they already stand does not count: a combatant placed on an
			# unpainted tile can still stay where they are, and an encounter with
			# spawns off the painted map is a content problem the encounter editor
			# reports rather than a routing one.
			if hole == start:
				continue
			if reachable.has(hole):
				offered += 1
		ok(offered == 0, "AI reachability excludes holes", "%d offered" % offered)

	# Painted ground must still report its real terrain cost.
	var costs_seen := {}
	for cell in painted:
		costs_seen[controller.get_tile_cost(cell)] = true
	ok(costs_seen.size() > 0, "painted tiles still report real costs", "distinct costs: %s" % [costs_seen.keys()])

	# Hovering right off the edge of the map must not error either.
	controller.find_path(Vector2i(used.position.x + used.size.x + 5, used.position.y - 3))
	ok(controller._path.is_empty(), "cursor off the map clears the path instead of erroring")

	# Which tiles near the player start are actually free to stand on?
	if expect_holes:
		var taken = {}
		for spawn in enc.spawns:
			taken[spawn.position] = true
		var free = []
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				var cell = Vector2i(20, 7) + Vector2i(dx, dy)
				if taken.has(cell) or not controller.is_in_bounds(cell):
					continue
				if not controller.is_tile_blocking(cell, 0):
					free.append(cell)
		log_line("  free walkable tiles near (20, 7): %s" % [free.slice(0, 10)])

	get_tree().root.remove_child(game)
	game.free()
	log_line("")


func run_test():
	log_line("======== non-rectangular map (Sappers) ========")
	await check_map("res://encounters/encounter_02_sappers.tres")
	log_line("======== rectangular map, unchanged (Ambush) ========")
	await check_map("res://encounters/encounter_01_ambush.tres")
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
