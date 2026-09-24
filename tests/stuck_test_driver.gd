extends Node
## Two ways an enemy can spend a fight doing nothing.
##
## A ranger out of everybody's reach used to walk to whichever nearby tile hid
## it best, arrive unable to shoot, and have no movement left to close with -
## then do the same again next turn, stepping between two equally safe tiles
## while the players walked around it. A healer whose allies were all within
## reach from anywhere took the best cover on the map and sat in it, because
## coverage tied everywhere and hiding was the only tiebreak left.

var LOG_PATH := HarnessLog.path_for("stuck")

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
	get_tree().create_timer(240.0, true, false, true).timeout.connect(func():
		log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


## Where the old rule would have parked a healer: the best cover it can reach
## among the tiles that keep as many allies in reach as any other. Coverage ties
## almost everywhere, so in practice this is simply the best hiding place - the
## corner one of them sat in for a whole fight.
func old_healer_choice(combat, comb: Dictionary, reach: int) -> Vector2i:
	return combat.find_best_reachable_tile(comb, combat.controller.movement, func(t):
		return float(combat.count_allies_within_heal_reach(comb, t, reach)) * 100.0 			+ combat.score_tile_safety(t)
	)


func run_test():
	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_02_sappers.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	for i in 8:
		await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	var controller = game.get_node("Controller")
	if combat.deployment_active:
		combat.finish_deployment()
		await get_tree().process_frame

	var ranger = {}
	var healer = {}
	for comb in combat.combatants:
		if not comb.alive or comb.side == 0:
			continue
		if comb.get("ai_function", "") == "ai_ranger" and ranger.is_empty():
			ranger = comb
		elif comb.get("ai_function", "") == "ai_healer" and healer.is_empty():
			healer = comb
	log_line("  NOTE  this fight fields a ranger: %s, and a healer: %s" % [
		ranger.get("name", "none"), healer.get("name", "none")])

	if not ranger.is_empty():
		log_line("======== what a ranger actually does, turn after turn ========")
		# Its gun reaches twenty tiles and respects cover, so what stops it
		# shooting is never distance - it is line of sight. And the tiles that
		# score best for safety are exactly the ones nobody can see it from,
		# which are the ones it cannot shoot from either.
		var gun_key = combat.find_best_single_target_skill(ranger)
		var gun: SkillDefinition = SkillDatabase.skills[gun_key]
		log_line("  NOTE  it fights with %s: reach %d, respects cover %s" % [
			gun.name, gun.max_range, gun.respects_blocking])
		var shots = 0
		var moves = 0
		var report := []
		for turn in 6:
			if not ranger.alive:
				break
			combat.current_combatant = combat.combatants.find(ranger)
			controller.set_controlled_combatant(ranger)
			var mark: Dictionary = combat.find_lowest_hp_enemy_of(ranger)
			if mark.is_empty():
				break
			var before = ranger.position
			var hp_before = mark.hp
			var in_reach = await combat.move_into_range_of(ranger, mark.position, gun,
				controller.movement, true, mark)
			if in_reach:
				await combat.use_skill(gun_key, ranger, mark.position, false)
				await combat.retreat_with_remaining_movement(ranger, mark,
					gun.max_range + combat.movement_budget_of(ranger))
			else:
				await combat.approach_with_remaining_movement(ranger, mark)
			for i in 3:
				await get_tree().process_frame
			if in_reach:
				shots += 1
			if ranger.position != before:
				moves += 1
			report.append("%s -> %s, %s, %s saw %d hp go to %d" % [before, ranger.position,
				"shot" if in_reach else "no shot", mark.name, hp_before, mark.hp])
		for line in report:
			log_line("  NOTE  " + line)
		ok(shots > 0, "it takes a shot at some point across six turns",
			"%d shots, %d moves" % [shots, moves])
		# The reported symptom: moving and then coming back, over and over,
		# achieving nothing. A turn that neither shoots nor ends up somewhere
		# new is a wasted one, and a whole fight of them is the bug.
		var wasted = 0
		for line in report:
			if line.contains("no shot"):
				var halves = line.split(" -> ")
				if halves.size() > 1 and halves[1].begins_with(halves[0]):
					wasted += 1
		ok(wasted == 0, "and never stands still for a turn without shooting",
			"%d such turns of %d" % [wasted, report.size()])
		log_line("")

		log_line("======== and closes in when there is genuinely no shot ========")
		# The Gun reaches twenty tiles, so to reproduce being out of reach the
		# test gives it something short-ranged. What matters is the shape: no
		# reachable tile can shoot, so the turn must be spent closing rather
		# than on cover it cannot shoot from.
		var stubby: SkillDefinition = gun.duplicate(true)
		stubby.max_range = 2
		SkillDatabase.skills["_stubby_gun"] = stubby
		var mark = combat.find_lowest_hp_enemy_of(ranger)
		var walk := []
		var stood_still = 0
		for turn in 5:
			if mark.is_empty() or not ranger.alive:
				break
			combat.current_combatant = combat.combatants.find(ranger)
			controller.set_controlled_combatant(ranger)
			var before = ranger.position
			var gap_before = combat.get_position_distance(before, mark.position)
			if not await combat.move_into_range_of(ranger, mark.position, stubby,
				controller.movement, true, mark):
				await combat.approach_with_remaining_movement(ranger, mark)
			for i in 3:
				await get_tree().process_frame
			var gap_after = combat.get_position_distance(ranger.position, mark.position)
			walk.append(gap_after)
			if ranger.position == before and gap_after > stubby.max_range:
				stood_still += 1
		log_line("  NOTE  distance to its mark, turn by turn: %s" % [walk])
		ok(stood_still == 0, "it never spends a turn standing still while out of reach",
			"%d such turns of %d" % [stood_still, walk.size()])
		ok(walk.size() > 1 and walk[walk.size() - 1] < walk[0],
			"and is closer at the end of the run than at the start",
			"%s" % [walk])
		SkillDatabase.skills.erase("_stubby_gun")
		log_line("")

	if not healer.is_empty():
		log_line("======== a healer does not sit out the fight in a corner ========")
		combat.current_combatant = combat.combatants.find(healer)
		controller.set_controlled_combatant(healer)
		var reach = combat.movement_budget_of(healer)
		var heal_key = combat.find_skill_of_type(healer, EffectDefinition.EffectType.HEAL)
		if heal_key != "":
			reach += SkillDatabase.skills[heal_key].max_range
		# Put it where the old scoring would have: its best hiding place.
		var hide = old_healer_choice(combat, healer, reach)
		combat.teleport_to(healer, hide)
		await get_tree().process_frame
		combat.current_combatant = combat.combatants.find(healer)
		controller.set_controlled_combatant(healer)
		var hid_at = healer.position
		var front = combat.ally_nearest_the_enemy(healer)
		ok(not front.is_empty(), "somebody of its own is nearest the fighting",
			front.get("name", "nobody"))
		var was = combat.get_position_distance(hid_at, front.position)
		log_line("  NOTE  the old rule would park it on %s, %d tiles from the front" % [hid_at, was])
		await combat.reposition_healer(healer, reach)
		for i in 4:
			await get_tree().process_frame
		var now = combat.get_position_distance(healer.position, front.position)
		ok(healer.position != hid_at, "it leaves the corner",
			"%s -> %s" % [hid_at, healer.position])
		ok(now < was, "and ends up nearer whoever is about to need mending",
			"%d tiles from %s, was %d" % [now, front.get("name", "them"), was])
		# The thing it must never trade away is still not traded away.
		var covered_before = combat.count_allies_within_heal_reach(healer, hid_at, reach)
		var covered_after = combat.count_allies_within_heal_reach(healer, healer.position, reach)
		ok(covered_after >= covered_before,
			"without covering fewer of them than it did from cover",
			"%d covered, was %d" % [covered_after, covered_before])
		log_line("")

	game.queue_free()
	await get_tree().process_frame
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
