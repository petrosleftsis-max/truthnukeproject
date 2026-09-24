extends Node
## Where a blast is seen from.
##
## Range is the caster's question - what they can see is what they may aim at.
## What the blast then touches is the landing tile's question: a bomb going off
## round a corner catches what is around it, not what the thrower could see.

var LOG_PATH := HarnessLog.path_for("blast")
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
	get_tree().create_timer(180.0, true, false, true).timeout.connect(func():
		log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


func run_test():
	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_02_sappers.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	for i in 8:
		await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await get_tree().process_frame

	log_line("======== which skills this even applies to ========")
	var blasts := []
	for key in SkillDatabase.skills:
		var skill: SkillDefinition = SkillDatabase.skills[key]
		if skill.aoe_radius > 0 and skill.respects_blocking \
			and skill.aoe_shape == SkillDefinition.AoEShape.DIAMOND:
			blasts.append("%s (radius %d)" % [skill.name, skill.aoe_radius])
	log_line("  NOTE  blasts that respect cover: %s" % [blasts])
	# Fireball is deliberately not one of them - it says so in its own
	# description, "even behind cover" - so nothing here changes what it does.
	var fireball: SkillDefinition = SkillDatabase.skills["fireball"]
	ok(not fireball.respects_blocking,
		"Fireball still ignores cover, as its description says")
	log_line("")

	log_line("======== a blast is measured from where it lands ========")
	var subject: SkillDefinition = null
	for key in SkillDatabase.skills:
		var skill: SkillDefinition = SkillDatabase.skills[key]
		if skill.aoe_radius >= 2 and skill.respects_blocking \
			and skill.aoe_shape == SkillDefinition.AoEShape.DIAMOND:
			subject = skill
			break
	ok(subject != null, "there is one to try", subject.name if subject else "none")
	if subject == null:
		log_line("FAILURES: %d" % maxi(_fail, 1))
		get_tree().quit(1)
		return

	# Somewhere on this map where the two views genuinely differ, found rather
	# than assumed - a hand-picked pair of tiles would rot the first time the
	# map is redrawn.
	var found_a_difference := false
	var report := ""
	var origin = Vector2i.ZERO
	for comb in combat.combatants:
		if comb.alive:
			origin = comb.position
			break
	for dx in range(-12, 13):
		for dy in range(-12, 13):
			var aim = origin + Vector2i(dx, dy)
			if combat.get_position_distance(origin, aim) > subject.max_range:
				continue
			var from_landing = combat.get_impact_tiles(subject, origin, aim, 0)
			var from_caster := []
			for tile in combat.get_diamond_tiles(aim, subject.aoe_radius):
				if combat.controller.is_tile_blocking(tile, 0):
					continue
				if combat.has_line_of_sight(origin, tile, 0):
					from_caster.append(tile)
			if from_landing.size() != from_caster.size():
				var only_now := []
				for tile in from_landing:
					if not tile in from_caster:
						only_now.append(tile)
				if not only_now.is_empty():
					found_a_difference = true
					report = "aiming at %s from %s: %d tiles in the blast now, %d under the old rule; %s is in it because the blast can see it, though the caster cannot" % [
						aim, origin, from_landing.size(), from_caster.size(), only_now[0]]
					# And prove the claim rather than asserting it.
					ok(combat.has_line_of_sight(aim, only_now[0], 0),
						"  the landing tile can see it")
					ok(not combat.has_line_of_sight(origin, only_now[0], 0),
						"  the caster cannot")
					break
		if found_a_difference:
			break
	ok(found_a_difference, "the two rules genuinely differ on this map", report)
	log_line("")

	log_line("======== and nothing outside the blast is ever in it ========")
	var strays := []
	for dx in range(-6, 7):
		for dy in range(-6, 7):
			var aim = origin + Vector2i(dx, dy)
			for tile in combat.get_impact_tiles(subject, origin, aim, 0):
				if combat.get_position_distance(aim, tile) > subject.aoe_radius:
					strays.append("%s is %d from %s" % [tile, combat.get_position_distance(aim, tile), aim])
	ok(strays.is_empty(), "every tile caught is inside the blast's own radius",
		"%s" % [strays.slice(0, 3)])
	log_line("")

	log_line("======== a beam is still thrown by the caster ========")
	# A LINE or a CONE comes out of the caster, so it is still the caster's view
	# that decides how far it gets - the change is about blasts only.
	var beam: SkillDefinition = null
	for key in SkillDatabase.skills:
		var skill: SkillDefinition = SkillDatabase.skills[key]
		if skill.respects_blocking and skill.aoe_shape != SkillDefinition.AoEShape.DIAMOND:
			beam = skill
			break
	if beam == null:
		log_line("  NOTE  no skill in the game is a line or a cone that respects cover, so there is nothing to check here")
	else:
		var aim = origin + Vector2i(mini(beam.max_range, 4), 0)
		var thrown = combat.get_impact_tiles(beam, origin, aim, 0)
		var blocked := []
		for tile in thrown:
			if not combat.has_line_of_sight(origin, tile, 0):
				blocked.append(tile)
		ok(blocked.is_empty(), "%s still only reaches what its caster can see" % beam.name,
			"%s" % [blocked.slice(0, 3)])
	log_line("")

	log_line("======== the tiles named in the report ========")
	# Reported as: a caster on (28,15) throwing at (30,17) should catch (30,19)
	# and not (27,12) or (28,12). Printed rather than asserted, because two of
	# those three are a long way outside any blast in the game and the answer is
	# worth seeing rather than arguing about.
	var caster_tile = Vector2i(28, 15)
	var landing = Vector2i(30, 17)
	for named in [Vector2i(30, 19), Vector2i(27, 12), Vector2i(28, 12)]:
		log_line("  %s is %d tiles from where it lands" % [named, combat.get_position_distance(landing, named)])
	for key in ["burner", "wind_swoon", "fireball"]:
		var skill: SkillDefinition = SkillDatabase.skills[key]
		var caught = combat.get_impact_tiles(skill, caster_tile, landing, 0)
		var says := []
		for named in [Vector2i(30, 19), Vector2i(27, 12), Vector2i(28, 12)]:
			says.append("%s %s" % [named, "hit" if named in caught else "not hit"])
		log_line("  %s (radius %d, cover %s): %s"
			% [skill.name, skill.aoe_radius, skill.respects_blocking, ", ".join(says)])
	log_line("")

	log_line("======== a wall can stop a step without stopping a look ========")
	# A tile's Blocks data carries the movement classes it stops; a 3 alongside
	# them says the wall has a gap at eye height. Nothing on the maps is
	# painted that way yet, so the rule is checked by marking a real wall and
	# putting it back.
	var ctrl = combat.controller
	ok(ctrl.SEE_THROUGH == 3, "the marker is the 3 painted in Blocks",
		"%d" % ctrl.SEE_THROUGH)
	var wall_tile = Vector2i.ZERO
	var found_wall := false
	for candidate in ctrl._all_blocking_spaces:
		if not found_wall and ctrl.is_tile_blocking(candidate, 0):
			wall_tile = candidate
			found_wall = true
	ok(found_wall, "there is a wall on this map to try it on", "%s" % wall_tile)
	if found_wall:
		ok(ctrl.blocks_line_of_sight(wall_tile, 0), "an ordinary wall stops a shot")
		ok(ctrl.is_tile_blocking(wall_tile, 0), "and stops a step")
		ctrl._see_through[wall_tile] = true
		ok(not ctrl.blocks_line_of_sight(wall_tile, 0),
			"painted see-through, the shot goes past", "%s" % wall_tile)
		ok(ctrl.is_tile_blocking(wall_tile, 0),
			"while the step is still refused - it is a wall, not a doorway")
		# And a body standing in the gap is cover again, see-through or not.
		var somebody = {}
		for comb in combat.combatants:
			if comb.alive and somebody.is_empty():
				somebody = comb
		if not somebody.is_empty():
			var was = somebody.position
			somebody.position = wall_tile
			ctrl._occupied_spaces[wall_tile] = true
			ok(ctrl.blocks_line_of_sight(wall_tile, 0),
				"somebody standing in the gap fills it")
			ctrl._occupied_spaces.erase(wall_tile)
			somebody.position = was
		# In range, and drawn so. A flier can be standing on a see-through
		# railing, and the shot reaches them - so the tile has to appear in the
		# overlay that says what can be hit rather than being dropped for being
		# somewhere the caster could not walk.
		var shooter = {}
		for comb in combat.combatants:
			if comb.alive and shooter.is_empty():
				shooter = comb
		var aimed: SkillDefinition = null
		for key in SkillDatabase.skills:
			var candidate: SkillDefinition = SkillDatabase.skills[key]
			if aimed == null and candidate != null and candidate.respects_blocking \
					and candidate.max_range >= 3:
				aimed = candidate
		ok(aimed != null, "a skill that respects cover to aim with",
			aimed.name if aimed != null else "none")
		if aimed != null and not shooter.is_empty():
			# Standing close enough that only the wall is in question.
			var eye = wall_tile + Vector2i(1, 0)
			if not ctrl.is_tile_blocking(eye, 0):
				shooter.position = eye
				# Solid again first: the checks above left it painted, and a
				# wall that is still see-through proves nothing here.
				ctrl._see_through.erase(wall_tile)
				var solid = combat.get_range_tiles(aimed, eye, 0, shooter)
				ok(not (wall_tile in solid), "a solid wall is not offered as a target")
				ctrl._see_through[wall_tile] = true
				var gapped = combat.get_range_tiles(aimed, eye, 0, shooter)
				ok(wall_tile in gapped,
					"but a see-through one is, since somebody can be standing on it",
					"%s in reach of %s" % [wall_tile, aimed.name])
				ctrl._see_through.erase(wall_tile)
		ctrl._see_through.erase(wall_tile)
		ok(ctrl.blocks_line_of_sight(wall_tile, 0), "and unpainted it is a wall once more")
	log_line("")

	log_line("======== a body is cover ========")
	# Standing in front of somebody shields them: a line of sight has to get
	# past everybody in the way, not only past the walls.
	var shooter = {}
	var mark = {}
	for comb in combat.combatants:
		if not comb.alive:
			continue
		if shooter.is_empty():
			shooter = comb
		elif mark.is_empty():
			mark = comb
	ok(not shooter.is_empty() and not mark.is_empty(), "somebody to shoot and somebody to shoot at")

	# A stretch of clear ground, found rather than assumed.
	var lane_start = Vector2i.ZERO
	var found_lane := false
	var region: Rect2i = combat.controller._astargrid.region
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x - 4):
			var here = Vector2i(x, y)
			var there = here + Vector2i(4, 0)
			var clear := true
			for step in range(0, 5):
				if combat.controller.is_tile_blocking(here + Vector2i(step, 0), 0):
					clear = false
			if clear and not found_lane:
				lane_start = here
				found_lane = true
	ok(found_lane, "there is a clear five-tile lane to try it in", "%s" % lane_start)
	if found_lane:
		var eye = lane_start
		var aim = lane_start + Vector2i(4, 0)
		var shield = lane_start + Vector2i(2, 0)
		# Nobody in the lane to begin with.
		combat.teleport_to(shooter, eye)
		combat.teleport_to(mark, aim)
		await get_tree().process_frame
		ok(combat.has_line_of_sight(eye, aim, 0), "a clear lane is clear", "%s to %s" % [eye, aim])

		# Now put somebody in the middle of it.
		var wall = {}
		for comb in combat.combatants:
			if comb.alive and comb != shooter and comb != mark and wall.is_empty():
				wall = comb
		ok(not wall.is_empty(), "there is a third body to stand in the way")
		if not wall.is_empty():
			combat.teleport_to(wall, shield)
			await get_tree().process_frame
			ok(not combat.has_line_of_sight(eye, aim, 0), "somebody standing between breaks it",
				"%s stood on %s" % [wall.name, shield])
			# For everybody, not only for walkers: a body is a body.
			var sees_anyway := []
			for movement_class in 3:
				if combat.has_line_of_sight(eye, aim, movement_class):
					sees_anyway.append(Stats.movement_class_name(movement_class))
			ok(sees_anyway.is_empty(), "and for every movement class alike",
				"%s can still see through" % [sees_anyway])
			# The two at the ends do not block themselves.
			ok(combat.has_line_of_sight(eye, shield, 0),
				"you can still see the one doing the shielding")
			ok(combat.has_line_of_sight(shield, aim, 0),
				"and they can still see whoever they are shielding")

			# Somebody hidden is not cover. If they stopped a line, a shot that
			# refused to connect over empty-looking floor would say exactly
			# where they were standing - a worse tell than being seen.
			wall["hidden"] = true
			await get_tree().process_frame
			ok(combat.has_line_of_sight(eye, aim, 0),
				"but somebody hidden is seen through rather than shot around",
				"%s is hiding on %s" % [wall.name, shield])
			wall["hidden"] = false
			await get_tree().process_frame
			ok(not combat.has_line_of_sight(eye, aim, 0),
				"and they are cover again the moment they are not hiding")

			# Step aside and the lane opens again.
			combat.teleport_to(wall, shield + Vector2i(0, 1))
			await get_tree().process_frame
			ok(combat.has_line_of_sight(eye, aim, 0), "stepping out of the way opens it again")

			# What the AI calls cover is how many players cannot see a tile, and
			# every archetype's safety score is built on it. A see-through wall
			# must not read as a hiding place, or they walk behind a railing and
			# stand there being shot.
			var watcher = {}
			for comb in combat.combatants:
				if comb.alive and comb.side == 0 and watcher.is_empty():
					watcher = comb
			# The eye end of the lane is taken by the shooter from the checks
			# above, and teleport_to will not stack two people on one tile - so
			# whoever is standing there steps off before the watcher moves in.
			if not watcher.is_empty() and not is_same(watcher, shooter):
				combat.teleport_to(shooter, eye + Vector2i(0, 1))
				await get_tree().process_frame
			if not watcher.is_empty():
				combat.teleport_to(watcher, eye)
				await get_tree().process_frame
				ok(watcher.position == eye and combat.has_line_of_sight(eye, aim, watcher.movement_class),
					"a player stands at one end of the clear lane",
					"%s at %s, looking at %s" % [watcher.name, watcher.position, aim])
				var seen = combat.count_players_without_los(aim)
				for movement_class in 3:
					combat.controller._blocking_lookup[movement_class][shield] = true
				var walled = combat.count_players_without_los(aim)
				ok(walled > seen, "a wall in the lane is cover to the AI",
					"%d hidden from, up from %d" % [walled, seen])
				combat.controller._see_through[shield] = true
				var gapped = combat.count_players_without_los(aim)
				ok(gapped == seen, "and a see-through one is cover to nobody",
					"%d hidden from, the same as with no wall at all" % gapped)
				combat.controller._see_through.erase(shield)
				for movement_class in 3:
					combat.controller._blocking_lookup[movement_class].erase(shield)
	log_line("")

	game.queue_free()
	await get_tree().process_frame
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
