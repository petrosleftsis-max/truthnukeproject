extends Node
## Every route by which a spell gets cast, walked with a blinded caster.
##
## Blind caps reach at one tile. A playtester thinks they saw a blinded caster
## cast from range anyway, so rather than argue about which check covers it,
## this walks each way a skill can actually go off and asks the same question
## of all of them.

var LOG_PATH := HarnessLog.path_for("blindcast")
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


func blind(combat, comb: Dictionary):
	comb.status_effects.append({
		"stat": "condition",
		"condition": load("res://conditions/blind.tres"),
		"dot_base": 0.0,
		"duration": 5,
		"source_name": "the test",
	})


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

	var caster = {}
	var victim = {}
	for comb in combat.combatants:
		if comb.alive and caster.is_empty():
			caster = comb
		elif comb.alive and comb.side != caster.side and victim.is_empty():
			victim = comb
	ok(not caster.is_empty() and not victim.is_empty(), "somebody to blind and somebody to shoot at")

	log_line("======== the rule itself ========")
	var far: SkillDefinition = null
	for key in SkillDatabase.skills:
		var skill: SkillDefinition = SkillDatabase.skills[key]
		if skill is ItemDefinition:
			continue
		if skill.max_range >= 5 and skill.min_range <= 1 and not skill.targets_ally:
			far = skill
			break
	ok(far != null, "there is a long-ranged spell to try", far.name if far else "none")
	blind(combat, caster)
	ok(combat.effective_max_range(caster, far) == 1,
		"a blinded caster reaches one tile", "%d" % combat.effective_max_range(caster, far))
	log_line("")

	log_line("======== every skill they own, at every distance ========")
	# Not one skill at one distance: every skill in their kit, at every distance
	# out to its own range, asked the one question that gates a cast.
	var leaks := []
	for key in caster.skill_list:
		var skill: SkillDefinition = SkillDatabase.skills.get(key)
		if skill == null:
			continue
		for d in range(2, maxi(skill.max_range, 2) + 1):
			var there = caster.position + Vector2i(d, 0)
			if combat.is_effectively_in_range(skill, caster.position, there, caster.movement_class, caster):
				leaks.append("%s at %d tiles" % [key, d])
	ok(leaks.is_empty(), "nothing in their kit reaches past one tile", "%s" % [leaks.slice(0, 4)])
	log_line("")

	log_line("======== the player's own preview ========")
	# What the range overlay offers is what a player believes they may do.
	var offered = combat.get_range_tiles(far, caster.position, caster.movement_class, caster)
	var too_far := []
	for tile in offered:
		if combat.get_position_distance(caster.position, tile) > 1:
			too_far.append(tile)
	ok(too_far.is_empty(), "the overlay offers nothing out of reach",
		"%d of %d tiles too far" % [too_far.size(), offered.size()])
	log_line("")

	log_line("======== actually pressing the button ========")
	var before = victim.hp
	var distance = combat.get_position_distance(caster.position, victim.position)
	if distance <= 1:
		ok(true, "  (the target is already adjacent - nothing to prove here)")
	else:
		await combat.use_skill(far.resource_path.get_file().get_basename(), caster, victim.position, false)
		for i in 4:
			await get_tree().process_frame
		ok(victim.hp == before,
			"a cast aimed %d tiles away does nothing" % distance,
			"%d -> %d" % [before, victim.hp])
	log_line("")

	log_line("======== and a reaction, which checks range nowhere else ========")
	# use_reactive_skill checks line of sight and never range, so the trigger is
	# the only gate. It used to read the skill's own reach rather than the
	# reactor's, which let a blinded reactor fire across the map - invisible
	# today only because every reactive skill in the game happens to reach one
	# tile anyway.
	var reactive: SkillDefinition = null
	for key in SkillDatabase.skills:
		if SkillDatabase.skills[key].is_reactive:
			reactive = SkillDatabase.skills[key]
			break
	ok(reactive != null, "there is a reactive skill", reactive.name if reactive else "none")
	if reactive != null:
		var stretched: SkillDefinition = reactive.duplicate(true)
		stretched.max_range = 8
		SkillDatabase.skills["_stretched_reaction"] = stretched
		var reactor = victim
		reactor.skill_list = ["_stretched_reaction"]
		reactor.reaction_used = false
		blind(combat, reactor)
		var from_tile = reactor.position + Vector2i(5, 0)
		var to_tile = reactor.position + Vector2i(9, 0)
		var provoked = combat.find_triggering_reactions_along_path(caster, [from_tile, to_tile])
		ok(provoked.is_empty(),
			"a blinded reactor does not fire at somebody leaving five tiles away",
			"%d reactions" % provoked.size())
		# And the same reactor, unblinded, still does its job.
		reactor.status_effects.clear()
		var seeing = combat.find_triggering_reactions_along_path(caster, [from_tile, to_tile])
		ok(not seeing.is_empty(),
			"while one that can see still reacts", "%d reactions" % seeing.size())
		SkillDatabase.skills.erase("_stretched_reaction")
	log_line("")

	log_line("======== what a blast still reaches ========")
	# Worth stating plainly, because it is the one thing that genuinely looks
	# like a blinded caster hitting somebody far away: the CAST is capped, the
	# blast around where it lands is not.
	var widest := 0
	var widest_name := ""
	for key in caster.skill_list:
		var skill: SkillDefinition = SkillDatabase.skills.get(key)
		if skill != null and skill.aoe_radius > widest:
			widest = skill.aoe_radius
			widest_name = skill.name
	if widest > 0:
		log_line("  NOTE  blinded, this caster can still catch somebody %d tiles off - %s lands one tile away and bursts %d"
			% [1 + widest, widest_name, widest])
	else:
		log_line("  NOTE  this caster has no area skills, so nothing reaches past one tile at all")
	log_line("")

	game.queue_free()
	await get_tree().process_frame
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
