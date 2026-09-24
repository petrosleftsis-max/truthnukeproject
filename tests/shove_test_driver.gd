extends Node
## The tile somebody was moved off has to be walkable again.
##
## A shove, a pull, a wind drift and a teleport all move a body without them
## walking. Each one used to leave the tile they came from marked solid on the
## pathfinding grid forever, so nobody could ever walk back onto it - while a
## blink, which does not consult that grid at all, still could.

var LOG_PATH := HarnessLog.path_for("shove")
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


## Hands the turn to `comb`, the way the turn loop would, so the pathfinding
## grid is rebuilt from their point of view.
func act_as(combat, controller, comb: Dictionary):
	for i in combat.combatants.size():
		if is_same(combat.combatants[i], comb):
			combat.current_combatant = i
	controller.set_controlled_combatant(comb)


## A free tile `comb` could stand on within `reach` of `from`.
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
	if combat.deployment_active:
		combat.finish_deployment()
		await get_tree().process_frame
	var controller = combat.controller

	var target = null
	var shover = null
	for comb in combat.combatants:
		if comb.alive and comb.side == 0 and target == null:
			target = comb
		elif comb.alive and comb.side == 1 and shover == null:
			shover = comb
	ok(target != null and shover != null, "somebody to shove, and somebody to shove them")
	if target == null or shover == null:
		log_line("FAILURES: %d" % _fail)
		get_tree().quit(1)
		return

	log_line("======== a shove leaves the tile behind it walkable ========")
	# Stand the shover next to them, facing along a line with room to give.
	var beside = free_tile_near(combat, shover, target.position, 1)
	ok(beside != Vector2i(-99999, -99999), "there is room beside them", "%s" % beside)
	combat.teleport_to(shover, beside)
	var vacated = target.position
	await combat.use_skill("shoving_strike", shover, target.position, false, false)
	ok(target.position != vacated, "the shove moved them",
		"%s -> %s" % [vacated, target.position])

	if target.position != vacated and target.alive:
		act_as(combat, controller, target)
		ok(not controller._astargrid.is_point_solid(vacated),
			"the tile they were shoved off is free again", "%s" % vacated)
		ok(not controller.get_grid_path(target.position, vacated).is_empty(),
			"and they can walk back to it", "%s -> %s" % [target.position, vacated])
		ok(combat.can_land_on(target, vacated),
			"a blink could always reach it - that was the giveaway")
	log_line("")

	log_line("======== the same for a teleport ========")
	var mover = null
	for comb in combat.combatants:
		if comb.alive and comb.side == 0 and not is_same(comb, target):
			mover = comb
			break
	if mover != null:
		var left_behind = mover.position
		var landing = free_tile_near(combat, mover, mover.position, 3)
		if landing != Vector2i(-99999, -99999):
			combat.teleport_to(mover, landing)
			act_as(combat, controller, mover)
			ok(not controller._astargrid.is_point_solid(left_behind),
				"the tile a teleport left is free again", "%s" % left_behind)
			ok(not controller.get_grid_path(mover.position, left_behind).is_empty(),
				"and walkable back to")
	log_line("")

	log_line("======== and nobody can walk onto an occupied tile ========")
	# The release must not go so far that bodies stop blocking each other.
	var standing = null
	for comb in combat.combatants:
		if comb.alive and not is_same(comb, mover):
			standing = comb
			break
	if mover != null and standing != null:
		act_as(combat, controller, mover)
		ok(controller._astargrid.is_point_solid(standing.position),
			"somebody standing there still blocks the way", "%s on %s" % [standing.name, standing.position])
	log_line("")

	log_line("======== a walk still frees the tiles it crosses ========")
	if mover != null:
		act_as(combat, controller, mover)
		var start = mover.position
		var step = free_tile_near(combat, mover, mover.position, 1)
		if step != Vector2i(-99999, -99999):
			controller.find_path(step)
			controller.move_player()
			var waited = 0
			while not controller._arrived and waited < 240:
				await get_tree().process_frame
				waited += 1
			ok(mover.position == step, "they walked a tile", "%s -> %s" % [start, mover.position])
			ok(not controller._astargrid.is_point_solid(start),
				"and the tile they walked off is free", "%s" % start)
	log_line("")

	log_line("======== a collision is worth what the shover is worth ========")
	# It used to be a flat min-max roll that nothing touched, so a strong
	# character put people into walls exactly as hard as a weak one, and armour
	# made no difference to landing on your back.
	var shove: SkillDefinition = SkillDatabase.skills["shoving_strike"]
	var slam: EffectDefinition = null
	for effect in shove.all_effects():
		if effect.type == EffectDefinition.EffectType.PUSH:
			slam = effect
	ok(slam != null, "Shoving Strike shoves", shove.name)
	if slam != null:
		shover.stats[Stats.stat_key(shove.scaling_stat)] = 10
		var weak_slam = combat.collision_impact(shover, slam, shove)
		shover.stats[Stats.stat_key(shove.scaling_stat)] = 90
		var strong_slam = combat.collision_impact(shover, slam, shove)
		ok(strong_slam > weak_slam, "a stronger shover slams harder",
			"%d against %d" % [strong_slam, weak_slam])
		# By the same arithmetic the panel quotes for a swing, times whatever
		# the effect says a shove is worth next to one.
		ok(strong_slam == maxi(roundi(float(combat.base_skill_damage(shover, shove))
			* slam.damage_modifier), 0),
			"and by the same formula a swing is worked out with",
			"%d, base %d at x%s" % [strong_slam,
				combat.base_skill_damage(shover, shove), slam.damage_modifier])
		# Nothing behind the shove leaves the flat pair standing in, the way a
		# plain hit falls back to its own min-max.
		var loose = combat.collision_impact(shover, slam, null)
		ok(loose >= slam.min_amount and loose <= slam.max_amount,
			"with no skill behind it, the written range stands in",
			"%d, range %d-%d" % [loose, slam.min_amount, slam.max_amount])

		# And armour is now worth something on the way into the wall.
		var soft = combat.create_combatant(CombatantDatabase.combatants["cyrus"], "cyrus")
		var armoured = combat.create_combatant(CombatantDatabase.combatants["cyrus"], "cyrus")
		soft.resistances = {}
		armoured.resistances = {}
		soft.stats["defense"] = 0
		armoured.stats["defense"] = 60
		# Enough to survive the slam. These are bare combatants with no sprite
		# and no tile, so killing one is the harness falling over rather than
		# anything the game would do.
		soft.hp = strong_slam * 4
		armoured.hp = strong_slam * 4
		var soft_hp = soft.hp
		var armoured_hp = armoured.hp
		combat._take_collision_damage(shover, soft, slam, strong_slam, "hit a wall")
		combat._take_collision_damage(shover, armoured, slam, strong_slam, "hit a wall")
		ok(soft_hp - soft.hp > armoured_hp - armoured.hp,
			"and being armoured softens the landing",
			"%d taken unarmoured, %d armoured" % [soft_hp - soft.hp, armoured_hp - armoured.hp])

		log_line("======== and the panel quotes that figure, not the fallback ========")
		var ui = game.get_node("CanvasLayer/UI")
		shover.stats[Stats.stat_key(shove.scaling_stat)] = 40
		var said = ui.build_skill_tooltip(shove, shover)
		var expected = combat.collision_impact(shover, slam, shove)
		var slam_line = ""
		for line in said.split("
"):
			if line.contains("collision"):
				slam_line = line
		ok(slam_line.contains("base %d" % expected),
			"it names what the collision is actually worth", slam_line)
		ok(not slam_line.contains("%d-%d" % [slam.min_amount, slam.max_amount]),
			"rather than the written range, which only stands in when nothing is behind the shove",
			slam_line)
		# A stronger shover reads a bigger number, the way the damage line does.
		shover.stats[Stats.stat_key(shove.scaling_stat)] = 10
		ok(ui.build_skill_tooltip(shove, shover) != said,
			"and it is the shover's number, not the skill's")
	log_line("")

	game.queue_free()
	await get_tree().process_frame
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
