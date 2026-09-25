extends Node
## Holding Shift: every tile an enemy the player can see could reach and hit
## next turn, and every tile a player would set off a reaction by leaving.
## Checked against the arithmetic it claims to do rather than against itself -
## what an enemy can strike without moving must all be there, and nothing out of
## reach of a walk and a strike may be.

var LOG_PATH := HarnessLog.path_for("danger")

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
	get_tree().create_timer(150.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


func shift(down: bool):
	var key := InputEventKey.new()
	key.keycode = KEY_SHIFT
	key.physical_keycode = KEY_SHIFT
	key.pressed = down
	Input.parse_input_event(key)
	await get_tree().process_frame
	await get_tree().process_frame


func enemies(combat: Combat) -> Array:
	var found := []
	for comb in combat.combatants:
		if comb.side == 1 and comb.alive:
			found.append(comb)
	return found


func run_test():
	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_02_sappers.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	for i in 4:
		await get_tree().process_frame
	var combat: Combat = game.get_node("VisualCombat")
	var controller = game.get_node("Controller")
	var ui = game.get_node("CanvasLayer/UI")

	log_line("======== while the party is being placed ========")
	await shift(true)
	ok(controller.is_showing_danger(), "Shift shows it before the fight starts, when placing is decided")
	await shift(false)
	ok(not controller.is_showing_danger(), "and letting go puts it away")
	combat.finish_deployment()
	await get_tree().process_frame
	log_line("")

	log_line("======== the quick sight lines agree with the real ones ========")
	var foes = enemies(combat)
	ok(not foes.is_empty(), "there is somebody to be afraid of", "%d" % foes.size())
	var region: Rect2i = controller._astargrid.region
	var sight = Combat._SightGrid.new(controller, combat.combatants)
	var asked = 0
	var disagree := []
	for foe in foes:
		for y in range(region.position.y, region.end.y):
			for x in range(region.position.x, region.end.x):
				var tile = Vector2i(x, y)
				asked += 1
				if sight.clear(foe.position, tile, foe.movement_class) != combat.has_line_of_sight(foe.position, tile, foe.movement_class):
					disagree.append([foe.position, tile])
	ok(disagree.is_empty(), "every line from every enemy to every tile judged the same", "%d asked, %s" % [asked, disagree.slice(0, 3)])
	log_line("")

	log_line("======== where they could strike ========")
	var started = Time.get_ticks_usec()
	var map: Dictionary = combat.threat_map()
	var took = (Time.get_ticks_usec() - started) / 1000.0
	var threat: Dictionary = map.threat
	log_line("  NOTE  worked out in %.0f ms" % took)
	ok(took < 1500.0, "quickly enough to hold a key for", "%.0f ms" % took)
	ok(not threat.is_empty(), "some of the map is in danger", "%d tiles" % threat.size())
	var open_floor = 0
	var open_marked = 0
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			if not controller.is_tile_blocking(Vector2i(x, y), 0):
				open_floor += 1
				if threat.has(Vector2i(x, y)):
					open_marked += 1
	log_line("  NOTE  %d of %d open tiles marked" % [open_marked, open_floor])
	# A walk takes diagonal steps as well as straight ones, so a walk of M
	# tiles can end 2M steps away counted the way a skill's reach is.
	for foe in foes:
		log_line("  NOTE  %s: walks %d, strikes %d" % [foe.name, combat.movement_budget_of(foe), combat.threat_reach(foe)])
	var missing := []
	var too_far := []
	var walled_off := []
	for foe in foes:
		for skill in combat.threat_skills(foe):
			var far = maxi(combat.effective_max_range(foe, skill), 0)
			var near = skill.min_range if skill.respects_blocking else 0
			# Everything they could hit without taking a step.
			for x in range(foe.position.x - far, foe.position.x + far + 1):
				for y in range(foe.position.y - far, foe.position.y + far + 1):
					var tile = Vector2i(x, y)
					if not controller.is_in_bounds(tile):
						continue
					var gap = combat.get_position_distance(foe.position, tile)
					if gap > far or gap < near:
						continue
					if skill.respects_blocking:
						if controller.terrain_blocks_sight(tile, foe.movement_class):
							continue
						if not combat.has_line_of_sight(foe.position, tile, foe.movement_class):
							if not threat.has(tile):
								walled_off.append(tile)
							continue
					if not threat.has(tile):
						missing.append(tile)
	for tile in threat:
		var somebody_could = false
		for foe in foes:
			var reach = combat.threat_reach(foe)
			if reach >= 0 and combat.get_position_distance(foe.position, tile) <= 2 * combat.movement_budget_of(foe) + reach:
				somebody_could = true
		if not somebody_could:
			too_far.append(tile)
	ok(missing.is_empty(), "every tile an enemy could hit from where they stand is marked", "%s" % [missing.slice(0, 5)])
	ok(too_far.is_empty(), "and nothing beyond a walk and a strike is", "%s" % [too_far.slice(0, 5)])
	ok(not walled_off.is_empty(), "while tiles in range but behind a wall from everywhere they could stand are left clear",
		"%d such tiles" % walled_off.size())
	ok(open_marked < open_floor, "so the map is not simply all red", "%d of %d" % [open_marked, open_floor])
	log_line("")

	log_line("======== the walls, tile by tile ========")
	# One enemy on their own, worked out the slow way: every tile they could
	# stand on, the game's own line of sight, and the blasts spread by hand.
	var archer = {}
	for foe in foes:
		if archer.is_empty():
			for skill in combat.threat_skills(foe):
				if skill.respects_blocking and combat.effective_max_range(foe, skill) >= 6:
					archer = foe
	ok(not archer.is_empty(), "somebody shoots from range", archer.get("name", "nobody"))
	if not archer.is_empty():
		var others := []
		for foe in foes:
			if foe != archer:
				others.append(foe)
				foe.hidden = true
		var theirs: Dictionary = combat.threat_map().threat
		var standing: Array = controller.get_reachable_tiles(archer.position, archer.movement_class, combat.movement_budget_of(archer)).keys()
		if not standing.has(archer.position):
			standing.append(archer.position)
		var bound = 2 * combat.movement_budget_of(archer) + combat.threat_reach(archer)
		var every := []
		for y in range(region.position.y, region.end.y):
			for x in range(region.position.x, region.end.x):
				var spot = Vector2i(x, y)
				if combat.get_position_distance(archer.position, spot) <= bound:
					every.append(spot)
		var truth := {}
		var by_reach := {}
		for skill in combat.threat_skills(archer):
			var far = maxi(combat.effective_max_range(archer, skill), 0)
			var near = skill.min_range if skill.respects_blocking else 0
			var key = "%d/%d/%s" % [far, near, skill.respects_blocking]
			if not by_reach.has(key):
				var aims := {}
				for tile in every:
					for from in standing:
						var gap = combat.get_position_distance(from, tile)
						if gap > far or gap < near:
							continue
						if not skill.respects_blocking or (not controller.terrain_blocks_sight(tile, archer.movement_class)
								and _clear_without(combat, controller, archer, from, tile)):
							aims[tile] = true
							break
				by_reach[key] = aims
			var landing: Dictionary = by_reach[key]
			if skill.aoe_radius > 0:
				var spread := {}
				var from_where: Array = landing.keys() if skill.aoe_shape == SkillDefinition.AoEShape.DIAMOND else standing
				for tile in every:
					for centre in from_where:
						if combat.get_position_distance(centre, tile) <= skill.aoe_radius:
							spread[tile] = true
							break
				if skill.aoe_shape == SkillDefinition.AoEShape.DIAMOND:
					landing = spread
				else:
					landing = landing.merged(spread)
			truth.merge(landing)
		var wrong := []
		for tile in every:
			if truth.has(tile) != theirs.has(tile):
				wrong.append(tile)
		for foe in others:
			foe.hidden = false
		ok(wrong.is_empty(), "%s's danger matches the slow way on every tile in reach" % archer.name,
			"%d checked, %d marked, wrong: %s" % [every.size(), truth.size(), wrong.slice(0, 5)])
	log_line("")

	log_line("======== nobody hidden gives themselves away ========")
	for foe in foes:
		combat.set_hidden(foe, true)
	ok(combat.threat_map().threat.is_empty(), "with every enemy hidden, nothing is shown",
		"%d tiles" % combat.threat_map().threat.size())
	combat.set_hidden(foes[0], false)
	var one_seen = combat.threat_map().threat
	var only_theirs = true
	var reach0 = combat.threat_reach(foes[0])
	for tile in one_seen:
		if combat.get_position_distance(foes[0].position, tile) > 2 * combat.movement_budget_of(foes[0]) + reach0:
			only_theirs = false
	ok(not one_seen.is_empty() and only_theirs, "one back in sight shows only what they could reach",
		"%d tiles" % one_seen.size())
	for foe in foes:
		combat.set_hidden(foe, false)
	log_line("")

	log_line("======== reactions ========")
	for foe in foes:
		foe.reaction_used = true
	ok(combat.threat_map().reaction.is_empty(), "with every reaction spent, no tile warns of one")
	var guard = foes[0]
	guard.reaction_used = false
	if not guard.skill_list.has("rapier"):
		guard.skill_list.append("rapier")
	guard.stats["physical"] = maxi(guard.stats.get("physical", 0), 5)
	var rapier: SkillDefinition = SkillDatabase.skills["rapier"]
	var reaction: Dictionary = combat.threat_map().reaction
	ok(not reaction.is_empty(), "one ready to react marks the tiles round them", "%d" % reaction.size())
	var beside = guard.position + Vector2i.RIGHT
	if not controller.is_in_bounds(beside):
		beside = guard.position + Vector2i.LEFT
	ok(reaction.has(beside), "including the tile beside them", "%s" % beside)
	var outside := []
	for tile in reaction:
		var gap = combat.get_position_distance(guard.position, tile)
		if gap > combat.effective_max_range(guard, rapier) or gap < rapier.min_range:
			outside.append(tile)
	ok(outside.is_empty(), "and nothing past the reach of what they would react with", "%s" % [outside])
	guard.reaction_used = true
	ok(combat.threat_map().reaction.is_empty(), "once they have reacted this round, the warning goes")
	guard.reaction_used = false
	log_line("")

	log_line("======== holding the key ========")
	await shift(true)
	ok(controller.is_showing_danger(), "Shift down shows it")
	ok(controller.danger().get("threat", {}).size() == combat.threat_map().threat.size(),
		"showing what the threat map says")
	ok(ui._danger_legend.visible, "with the legend saying what the colours mean")
	var screen = ui.get_viewport_rect().size
	var box = Rect2(ui._danger_legend.global_position, ui._danger_legend.size)
	ok(Rect2(Vector2.ZERO, screen).encloses(box), "on the screen", "%s" % box)
	await shift(false)
	ok(not controller.is_showing_danger(), "Shift up hides it")
	ok(not ui._danger_legend.visible, "legend and all")
	await shift(true)
	controller._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	ok(not controller.is_showing_danger(), "and switching window away lets go of it too, since the key-up never arrives")
	await shift(false)
	log_line("")

	game.queue_free()
	await get_tree().process_frame
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


## The game's own line of sight from `from` to `to`, with `walker` taken off
## the tile they stand on now - they would have walked to `from` to take it.
func _clear_without(combat: Combat, controller, walker: Dictionary, from: Vector2i, to: Vector2i) -> bool:
	var was = controller._occupied_spaces.has(walker.position)
	controller._occupied_spaces.erase(walker.position)
	var clear = combat.has_line_of_sight(from, to, walker.movement_class)
	if was:
		controller._occupied_spaces[walker.position] = true
	return clear
