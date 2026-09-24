extends Node
## What each way of making line of sight symmetric actually costs, on the map
## it is asked about most.
##
## One walk each way is not the same price in both directions: permissive walks
## twice whenever a line is blocked, strict walks twice whenever it is clear, and
## which of those is the common case is a property of the map rather than of the
## rule.

var LOG_PATH := HarnessLog.path_for("sightcost")
var _log: FileAccess

func log_line(t): _log.store_line(t); _log.flush()


func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(300.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_probe()


func run_probe():
	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_02_sappers.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	for i in 6:
		await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await get_tree().process_frame
	var controller = combat.controller

	# The shape of the question the field of view actually asks: from where
	# each enemy stands, to every tile on the map.
	var region: Rect2i = controller._astargrid.region
	var eyes := []
	for comb in combat.combatants:
		if comb.alive and comb.side != 0:
			eyes.append(comb.position)
	var targets := []
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			targets.append(Vector2i(x, y))
	log_line("  %d watchers, %d tiles, %d questions per sweep"
		% [eyes.size(), targets.size(), eyes.size() * targets.size()])

	# How many of those are clear, which is what decides the cost of each rule.
	var clear := 0
	for eye in eyes:
		for tile in targets:
			if combat._walk_is_clear(eye, tile, 0):
				clear += 1
	var total = eyes.size() * targets.size()
	log_line("  %d of %d lines are clear one way (%.0f%%)"
		% [clear, total, 100.0 * clear / maxi(total, 1)])
	log_line("")

	log_line("======== one sweep, each rule ========")
	var started = Time.get_ticks_msec()
	for eye in eyes:
		for tile in targets:
			var _unused = combat._walk_is_clear(eye, tile, 0)
	var one_way = Time.get_ticks_msec() - started

	started = Time.get_ticks_msec()
	for eye in eyes:
		for tile in targets:
			var _unused = combat._walk_is_clear(eye, tile, 0) \
				or combat._walk_is_clear(tile, eye, 0)
	var permissive = Time.get_ticks_msec() - started

	started = Time.get_ticks_msec()
	for eye in eyes:
		for tile in targets:
			var _unused = combat._walk_is_clear(eye, tile, 0) \
				and combat._walk_is_clear(tile, eye, 0)
	var strict = Time.get_ticks_msec() - started

	# Always walked from the same end of the pair, whichever end asked.
	started = Time.get_ticks_msec()
	for eye in eyes:
		for tile in targets:
			var a = eye
			var b = tile
			if b.x < a.x or (b.x == a.x and b.y < a.y):
				a = tile
				b = eye
			var _unused = combat._walk_is_clear(a, b, 0)
	var canonical = Time.get_ticks_msec() - started

	log_line("  one way only (what it was, and not symmetric)  %5d ms" % one_way)
	log_line("  permissive - clear either way is clear         %5d ms" % permissive)
	log_line("  strict - must be clear both ways               %5d ms" % strict)
	log_line("  canonical - always walk the pair the same way  %5d ms" % canonical)

	game.queue_free()
	await get_tree().process_frame
	log_line("FAILURES: 0")
	get_tree().quit(0)
