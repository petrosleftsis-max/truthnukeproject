extends Node
## What each combatant actually reaches for when the AI falls back to hitting
## somebody standing next to them.
##
## The Priest was the reason melee_fallback_for exists: a healer with a kit of
## water and mending produced Enfina's greatsword. Giving them a melee of their
## own is the other half of that, and this says whether it took.

var LOG_PATH := HarnessLog.path_for("fallback")
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
	get_tree().create_timer(120.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


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

	log_line("======== what everybody swings when it comes to it ========")
	# Borrowing the greatsword is the documented last resort for somebody who
	# owns no melee at all - the Bomber carries only a suicide blast and Run,
	# and the Mimic carries nothing until it copies something. What would be
	# wrong is borrowing it while owning one, which is the bug this replaced.
	var ignored_their_own := []
	var had_nothing := []
	for comb in combat.combatants:
		if not comb.alive:
			continue
		var reached_for = combat.melee_fallback_for(comb)
		var owns = reached_for in comb.skill_list
		log_line("  %-12s reaches for %-20s %s"
			% [comb.name, reached_for, "their own" if owns else "nothing of their own"])
		if owns:
			continue
		# Did they have one to reach for?
		var could_have := []
		for key in comb.skill_list:
			var skill: SkillDefinition = SkillDatabase.skills.get(key)
			if skill == null or not skill.deals_damage or skill.targets_ally:
				continue
			if skill.min_range > 1 or combat.effective_max_range(comb, skill) < 1:
				continue
			could_have.append(key)
		if could_have.is_empty():
			had_nothing.append(comb.name)
		else:
			ignored_their_own.append("%s took %s over %s" % [comb.name, reached_for, could_have])
	ok(ignored_their_own.is_empty(),
		"nobody reaches past a melee of their own for somebody else's",
		"%s" % [ignored_their_own])
	log_line("  NOTE  carrying no melee at all, so the greatsword stands in: %s" % [had_nothing])

	# The one this was built for.
	var priest = {}
	for comb in combat.combatants:
		if comb.alive and comb.get("combatant_key", "") == "priest" and priest.is_empty():
			priest = comb
	ok(not priest.is_empty(), "there is a Priest in this fight")
	if not priest.is_empty():
		ok(combat.melee_fallback_for(priest) == "rapier",
			"and the Priest reaches for their own rapier",
			combat.melee_fallback_for(priest))

	game.queue_free()
	await get_tree().process_frame
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
