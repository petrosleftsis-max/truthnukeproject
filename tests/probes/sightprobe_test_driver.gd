extends Node
## Why one of two people can see the other and not the other way round.
##
## Asks the question from both ends, for every movement class, and prints the
## tiles each walk actually crosses and which of them stops it.

var LOG_PATH := HarnessLog.path_for("sightprobe")
const HERE := Vector2i(41, 25)
const THERE := Vector2i(45, 22)

var _log: FileAccess

func log_line(t): _log.store_line(t); _log.flush()


func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(120.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_probe()


func describe(combat, controller, from: Vector2i, to: Vector2i, movement_class: int) -> String:
	var crossed := []
	var stopper := "nothing"
	for tile in combat.get_tiles_between(from, to):
		var terrain = controller.terrain_blocks_sight(tile, movement_class)
		var body = controller.blocks_sight(tile)
		var mark = ""
		if terrain:
			mark = "#"
		elif body:
			mark = "@"
		crossed.append("%s%s" % [tile, mark])
		if stopper == "nothing" and (terrain or body):
			stopper = "%s (%s)" % [tile, "terrain" if terrain else "a body"]
	return "%s -> %s: %s, stopped by %s. crossed %s" % [
		from, to, combat.has_line_of_sight(from, to, movement_class), stopper, crossed]


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

	log_line("======== the two tiles themselves ========")
	for tile in [HERE, THERE]:
		var blocks := []
		for movement_class in 3:
			if controller.is_tile_blocking(tile, movement_class):
				blocks.append(Stats.movement_class_name(movement_class))
		log_line("  %s: blocks movement for %s, somebody standing there: %s"
			% [tile, blocks if not blocks.is_empty() else "nobody", controller.blocks_sight(tile)])
	log_line("")

	log_line("======== both directions, every movement class ========")
	for movement_class in 3:
		log_line("  --- %s ---" % Stats.movement_class_name(movement_class))
		log_line("  " + describe(combat, controller, HERE, THERE, movement_class))
		log_line("  " + describe(combat, controller, THERE, HERE, movement_class))
	log_line("")

	log_line("======== is the walk itself symmetric? ========")
	# Bresenham breaks a tie by stepping one way rather than the other, and
	# which way depends on which end it started from. If the two lists differ,
	# the two people are not looking along the same line at all.
	for movement_class in 1:
		var out = combat.get_tiles_between(HERE, THERE)
		var back = combat.get_tiles_between(THERE, HERE)
		back.reverse()
		log_line("  out:  %s" % [out])
		log_line("  back: %s" % [back])
		log_line("  same tiles both ways: %s" % [out == back])
	log_line("")

	log_line("======== how many pairs on this map disagree ========")
	var region: Rect2i = controller._astargrid.region
	var checked := 0
	var disagreed := 0
	var examples := []
	for y in range(region.position.y, mini(region.end.y, region.position.y + 40)):
		for x in range(region.position.x, mini(region.end.x, region.position.x + 40)):
			var a := Vector2i(x, y)
			if controller.is_tile_blocking(a, 0):
				continue
			for step in [Vector2i(4, -3), Vector2i(3, -4), Vector2i(5, -2), Vector2i(2, 5)]:
				var b = a + step
				if not controller.is_in_bounds(b) or controller.is_tile_blocking(b, 0):
					continue
				checked += 1
				var there = combat.has_line_of_sight(a, b, 0)
				var back = combat.has_line_of_sight(b, a, 0)
				if there != back:
					disagreed += 1
					if examples.size() < 5:
						examples.append("%s/%s %s vs %s" % [a, b, there, back])
	log_line("  %d pairs checked, %d disagree" % [checked, disagreed])
	log_line("  %s" % [examples])
	log_line("")

	log_line("======== who is actually standing where ========")
	for comb in combat.combatants:
		if comb.alive:
			log_line("  %-12s %s side %d class %d hidden %s"
				% [comb.name, comb.position, comb.side, comb.movement_class,
					combat.is_hidden(comb)])

	game.queue_free()
	await get_tree().process_frame
	log_line("FAILURES: 0")
	get_tree().quit(0)
