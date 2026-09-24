extends Node
## A walk interrupted by the turn changing has to put the walker down.
##
## Movement slides a sprite between tile centres while comb.position holds the
## last tile actually reached. Targeting compares a click against position, so
## a body left stranded mid-stride is drawn on one tile and found on another -
## alive, plainly visible, and impossible to click. The controller also has one
## _next_position for everybody, so a walk left running past its own turn drags
## whoever is controlled next along the dead walker's path.

var LOG_PATH := HarnessLog.path_for("midwalk")
var _log: FileAccess
var _fail = 0

func log_line(t): _log.store_line(t); _log.flush()

func ok(condition: bool, label: String, detail: String = ""):
	if condition:
		log_line("  PASS  %s %s" % [label, detail])
	else:
		_fail += 1
		log_line("  FAIL  %s %s" % [label, detail])

func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(200.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


func act_as(combat, controller, comb: Dictionary):
	for i in combat.combatants.size():
		if is_same(combat.combatants[i], comb):
			combat.current_combatant = i
	controller.set_controlled_combatant(comb)


func free_tile_near(combat, comb, from: Vector2i, reach: int) -> Vector2i:
	for radius in range(1, reach + 1):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				var tile = from + Vector2i(dx, dy)
				if combat.get_position_distance(from, tile) > reach:
					continue
				if tile == comb.position:
					continue
				if combat.can_land_on(comb, tile):
					return tile
	return Vector2i(-99999, -99999)


func run_test():
	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_02_sappers.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	for i in 6:
		await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	var controller = combat.controller
	if combat.deployment_active:
		combat.finish_deployment()
		await get_tree().process_frame

	var walker = null
	var next_up = null
	for comb in combat.combatants:
		if comb.alive and walker == null:
			walker = comb
		elif comb.alive and next_up == null:
			next_up = comb
	ok(walker != null and next_up != null, "somebody to walk, somebody to follow")

	log_line("======== a walk cut short by the turn changing ========")
	act_as(combat, controller, walker)
	var started_on = walker.position
	var destination = free_tile_near(combat, walker, walker.position, 3)
	ok(destination != Vector2i(-99999, -99999), "somewhere to walk to", "%s" % destination)
	controller.find_path(destination)
	controller.move_player()
	# Let them get properly under way, but nowhere near arriving.
	await get_tree().process_frame
	await get_tree().process_frame
	var mid_stride = walker.sprite.position
	ok(not controller._arrived, "they are mid-stride", "sprite at %s" % mid_stride)
	ok(mid_stride != Grid.tile_to_world(walker.position),
		"and genuinely between two tiles", "%s vs tile %s" % [mid_stride, walker.position])

	# The turn changes out from under them - an AI walk that ran past its own
	# timeout, or a fight that moved on while a step was still in the air.
	var was_next_position = next_up.position
	act_as(combat, controller, next_up)
	for i in 5:
		await get_tree().process_frame

	ok(walker.sprite.position == Grid.tile_to_world(walker.position),
		"the walker is put down on the tile the game says they are on",
		"sprite %s, tile %s -> %s" % [walker.sprite.position, walker.position,
			Grid.tile_to_world(walker.position)])
	var found = controller.get_combatant_at_position(walker.position)
	ok(found != null and found.name == walker.name,
		"and clicking them finds them", "found %s" % ["nobody" if found == null else found.name])
	ok(next_up.position == was_next_position,
		"whoever is up next was not dragged along the dead walk",
		"%s -> %s" % [was_next_position, next_up.position])
	ok(next_up.sprite.position == Grid.tile_to_world(next_up.position),
		"and is still standing on their own tile",
		"sprite %s, tile %s" % [next_up.sprite.position, next_up.position])
	log_line("")

	log_line("======== nothing else was disturbed ========")
	var problems := []
	for comb in combat.combatants:
		if not comb.alive:
			continue
		if comb.sprite.position != Grid.tile_to_world(comb.position):
			problems.append("%s drawn at %s, tile %s" % [comb.name, comb.sprite.position, comb.position])
		var at = controller.get_combatant_at_position(comb.position)
		if at == null or at.name != comb.name:
			problems.append("clicking %s finds %s" % [comb.position, "nobody" if at == null else at.name])
	ok(problems.is_empty(), "everybody is where they are drawn", "%s" % [problems])
	log_line("")

	log_line("======== an ordinary walk still finishes ========")
	act_as(combat, controller, walker)
	var from = walker.position
	var step = free_tile_near(combat, walker, walker.position, 1)
	if step != Vector2i(-99999, -99999):
		controller.find_path(step)
		controller.move_player()
		var waited = 0
		while not controller._arrived and waited < 240:
			await get_tree().process_frame
			waited += 1
		ok(walker.position == step, "they walk a tile normally", "%s -> %s" % [from, walker.position])
		ok(walker.sprite.position == Grid.tile_to_world(walker.position),
			"and land on it squarely")
	log_line("")

	game.queue_free()
	await get_tree().process_frame
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
