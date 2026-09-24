extends Node
## Measures what per-step Fear checking would actually cost, against the two
## places it could live: walking the already-computed path, and marking closer
## tiles unwalkable once per turn.

var LOG_PATH := HarnessLog.path_for("perf")

var _log: FileAccess = null


func log_line(t: String):
	if _log:
		_log.store_line(t)
		_log.flush()


func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(90.0).timeout.connect(func(): get_tree().quit(2))
	await get_tree().process_frame
	await get_tree().process_frame
	await run_test()


func run_test():
	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_01_ambush.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	var controller = game.get_node("Controller")
	combat.finish_deployment()
	await get_tree().process_frame

	var hero = null
	var foe = null
	for comb in combat.combatants:
		if comb.side == 0 and hero == null:
			hero = comb
		elif comb.side == 1 and foe == null:
			foe = comb
	combat.current_combatant = combat.combatants.find(hero)

	controller.set_controlled_combatant(hero)
	# A synthetic 20-tile route. What Option A costs is the per-step distance
	# loop over a path that has ALREADY been computed - no pathfinding is
	# repeated - so the path's contents don't matter, only its length. 20 steps
	# is longer than anything a combatant can actually walk in one turn.
	var path: Array = []
	for i in 20:
		path.append(hero.position + Vector2i(i, i / 2))
	log_line("Synthetic route of %d steps (longer than any real single turn)" % path.size())
	log_line("")

	# Option A: walk the path that has already been computed, comparing each
	# step's distance to the nearest enemy.
	const ITERATIONS = 100000
	var start = Time.get_ticks_usec()
	var rejected = 0
	for i in ITERATIONS:
		var limit = combat.get_position_distance(hero.position, foe.position)
		for step in path:
			if combat.get_position_distance(step, foe.position) < limit:
				rejected += 1
				break
	var elapsed = Time.get_ticks_usec() - start
	log_line("Option A - check every step of the existing path")
	log_line("  %d runs in %.1f ms => %.4f ms per move" % [ITERATIONS, elapsed / 1000.0, float(elapsed) / ITERATIONS / 1000.0])
	log_line("  (a frame at 60fps has 16.67 ms)")
	log_line("")

	# Option B: once per turn, mark every tile closer to the nearest enemy as
	# unwalkable, so pathfinding routes around and the preview is correct.
	var region = controller._astargrid.region
	const TURN_ITERATIONS = 2000
	start = Time.get_ticks_usec()
	var marked = 0
	for i in TURN_ITERATIONS:
		var limit = combat.get_position_distance(hero.position, foe.position)
		for x in range(region.position.x, region.position.x + region.size.x):
			for y in range(region.position.y, region.position.y + region.size.y):
				if combat.get_position_distance(Vector2i(x, y), foe.position) < limit:
					marked += 1
	elapsed = Time.get_ticks_usec() - start
	log_line("Option B - sweep the whole grid once per turn (%d tiles)" % [region.size.x * region.size.y])
	log_line("  %d runs in %.1f ms => %.4f ms per turn" % [TURN_ITERATIONS, elapsed / 1000.0, float(elapsed) / TURN_ITERATIONS / 1000.0])
	log_line("  tiles it would mark unwalkable: %d" % (marked / TURN_ITERATIONS))
	log_line("")

	# For scale: what the game already does every single mouse move.
	start = Time.get_ticks_usec()
	for i in 2000:
		controller.find_path(Vector2i(24, 16))
	elapsed = Time.get_ticks_usec() - start
	log_line("For scale - find_path(), which already runs on every mouse motion")
	log_line("  2000 runs in %.1f ms => %.4f ms per call" % [elapsed / 1000.0, float(elapsed) / 2000 / 1000.0])

	# Nothing here judges anything - it is a stopwatch. The line is for the
	# runner, which reads it to tell "finished" from "died halfway".
	log_line("FAILURES: 0")
	get_tree().quit(0)
