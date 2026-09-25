extends Node
## What a caster's turn actually costs to think about.
##
## Two playtesters, one symptom: the game pauses when the caster plays, and on
## the web build it stops responding altogether. ai_caster scores every tile it
## could stand on against every tile it could aim at, and with line of sight
## switched on that is a Bresenham walk per aim. This counts the work rather
## than guessing at it.

var LOG_PATH := HarnessLog.path_for("castcost")
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
	get_tree().create_timer(600.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


func tiles_in_diamond(reach: int) -> int:
	return 2 * reach * reach + 2 * reach + 1


## The way find_best_aim_and_count used to do it: build the whole blast for
## every tile in reach, line of sight and all, then look for players in it.
## Kept here as the thing the fast version has to agree with, so "faster" can
## be shown to also mean "the same".
func the_long_way(combat, skill: SkillDefinition, from: Vector2i, movement_class: int, caster: Dictionary) -> Dictionary:
	var best_aim = from
	var best_count = 0
	var reach = combat.effective_max_range(caster, skill)
	for dx in range(-reach, reach + 1):
		var remaining = reach - absi(dx)
		for dy in range(-remaining, remaining + 1):
			if absi(dx) + absi(dy) < skill.min_range:
				continue
			var aim = from + Vector2i(dx, dy)
			var tiles = combat.get_impact_tiles(skill, from, aim, movement_class)
			var count = 0
			for index in combat.groups[Combat.Group.PLAYERS]:
				var p = combat.combatants[index]
				if p.alive and p.position in tiles:
					count += 1
			if count > best_count:
				best_count = count
				best_aim = aim
	return {"position": best_aim, "count": best_count}


func measure(encounter_path: String, label: String):
	log_line("======== %s ========" % label)
	Campaign.reset()
	Campaign.current_encounter = load(encounter_path)
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	for i in 8:
		await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await get_tree().process_frame

	var casters := []
	for comb in combat.combatants:
		if comb.alive and comb.get("ai_function", "") == "ai_caster":
			casters.append(comb)
	log_line("  casters in this fight: %d" % casters.size())

	for comb in casters:
		var budget = combat.movement_budget_of(comb)
		var reachable = combat.controller.get_reachable_tiles(comb.position, comb.movement_class, budget)
		log_line("  %s at %s: movement %d, %d tiles it could stand on"
			% [comb.name, comb.position, budget, reachable.size()])

		var total_aims := 0
		var considered := []
		for skill_key in comb.skill_list:
			var skill: SkillDefinition = SkillDatabase.skills[skill_key]
			if skill.targets_ally or skill.aoe_radius <= 0:
				continue
			if not combat.can_afford_skill(comb, skill) or not combat.meets_level_for(comb, skill):
				continue
			var reach = combat.effective_max_range(comb, skill)
			var aims = tiles_in_diamond(reach)
			# One score for each tile it could stand on, plus the one it is on.
			total_aims += aims * (reachable.size() + 1)
			considered.append("%s (reach %d, %d aims each, blocking %s)"
				% [skill_key, reach, aims, skill.respects_blocking])
		for line in considered:
			log_line("    %s" % line)
		log_line("    -> %d aim evaluations for one turn" % total_aims)

		# The fast answer and the slow answer, tile for tile.
		var checked := 0
		var disagreements := []
		var sample := [comb.position]
		for tile in reachable:
			sample.append(tile)
		for skill_key in comb.skill_list:
			var skill: SkillDefinition = SkillDatabase.skills[skill_key]
			if skill.targets_ally or skill.aoe_radius <= 0:
				continue
			if not combat.can_afford_skill(comb, skill) or not combat.meets_level_for(comb, skill):
				continue
			for tile in sample:
				var fast = combat.find_best_aim_and_count(skill, tile, comb.movement_class, comb)
				var slow = the_long_way(combat, skill, tile, comb.movement_class, comb)
				checked += 1
				if fast.count != slow.count or fast.position != slow.position:
					disagreements.append("%s from %s: fast %s/%d vs slow %s/%d"
						% [skill_key, tile, fast.position, fast.count, slow.position, slow.count])
		ok(disagreements.is_empty(),
			"    the quick way agrees with the long way everywhere (%d checks)" % checked,
			"%s" % [disagreements.slice(0, 3)])

		# And what that actually costs, timed the way ai_caster does it: every
		# spell and skill in its kit weighed from every tile it could stand on.
		var started = Time.get_ticks_msec()
		combat.ai_plan_attack(comb, combat._ai_main_keys(comb), budget,
			func(t): return float(combat.count_players_without_los(t)) * combat.CASTER_COVER)
		var spent = Time.get_ticks_msec() - started
		log_line("    -> %d ms to decide, on this machine, headless" % spent)
		ok(spent < 1000, "%s decides inside a second" % comb.name, "%d ms" % spent)

	game.queue_free()
	await get_tree().process_frame
	log_line("")


func run_test():
	await measure("res://encounters/encounter_02_sappers.tres", "the Lab Fight")
	await measure("res://encounters/encounter_03_watcher.tres", "the City Fight")
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
