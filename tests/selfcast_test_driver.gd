extends Node
## A skill aimed at nobody but its own caster has to actually reach them.
##
## get_targets_in_tiles skips anybody on the caster's own side when
## targets_ally is false - the caster included, since they are their own ally.
## A skill that reaches zero tiles therefore finds nobody at all, and the
## caster's own effects are only applied once something connected. The audit
## found Guard in exactly that shape.

var LOG_PATH := HarnessLog.path_for("selfcast")
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
	get_tree().create_timer(180.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


func run_test():
	log_line("======== which skills can never reach anybody ========")
	# Worked out from the rule rather than from a list of names: aimed at
	# enemies, reaching no further than the tile the caster is standing on,
	# and with no area to catch anyone standing beside them.
	var unreachable := []
	for key in SkillDatabase.skills:
		var s: SkillDefinition = SkillDatabase.skills[key]
		if s == null or ItemDatabase.is_item(key):
			continue
		if not s.targets_ally and not s.affects_both_sides \
				and s.max_range <= 0 and s.aoe_radius <= 0:
			unreachable.append("%s (%s)" % [s.name, key])
	log_line("  NOTE  aimed at enemies, reaching zero tiles: %s" % [unreachable])
	log_line("")

	log_line("======== Guard in an actual fight ========")
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

	var guard: SkillDefinition = SkillDatabase.skills.get("guard")
	ok(guard != null, "Guard is in the database")
	if guard == null:
		finish(game)
		return
	log_line("  NOTE  Guard: targets_ally=%s range=%d-%d aoe=%d effects=%d"
		% [guard.targets_ally, guard.min_range, guard.max_range, guard.aoe_radius,
			guard.all_effects().size()])

	# Whoever carries it, put on their own feet and left alone.
	var keeper = null
	for comb in combat.combatants:
		if comb.alive and "guard" in comb.skill_list and keeper == null:
			keeper = comb
	if keeper == null:
		# Nobody in this fight has it, so hand it to a player for the check -
		# the question is whether the skill works, not who is carrying it.
		for comb in combat.combatants:
			if comb.alive and comb.side == 0 and keeper == null:
				keeper = comb
		if keeper != null and not "guard" in keeper.skill_list:
			keeper.skill_list.append("guard")
	ok(keeper != null, "somebody to try it with", keeper.name if keeper != null else "nobody")
	if keeper == null:
		finish(game)
		return

	combat.current_combatant = combat.combatants.find(keeper)
	# Guard needs level three and the party starts at one, so the refusal we
	# want to study is hidden behind one we do not. Raised rather than working
	# around it, so the cast that follows is the real one.
	keeper["level"] = maxi(keeper.get("level", 1), guard.required_level)
	log_line("  NOTE  %s raised to level %d, Guard needs %d"
		% [keeper.name, keeper.level, guard.required_level])
	keeper.skill_used_this_turn = false
	keeper.secondary_used_this_turn = false
	keeper.status_effects.clear()
	var before = combat.stat_of(keeper, Stats.Type.DEFENSE)

	# What the skill itself says it should do, read off its own effect.
	var buff: EffectDefinition = null
	for effect in guard.all_effects():
		if effect.type == EffectDefinition.EffectType.STAT_MULTIPLIER:
			buff = effect
	ok(buff != null, "it carries a multiplier")
	if buff != null:
		ok(buff.applies_to_caster, "meant for whoever used it")

	var heard: Array = []
	var listening = func(text): heard.append(text.strip_edges())
	combat.update_information.connect(listening)
	await combat.use_skill("guard", keeper, keeper.position, false)
	for i in 4:
		await get_tree().process_frame
	combat.update_information.disconnect(listening)
	for line in heard:
		if line != "":
			log_line("  NOTE  log: %s" % line)
	if heard.is_empty():
		log_line("  NOTE  log: (nothing at all - the cast never started)")

	var after = combat.stat_of(keeper, Stats.Type.DEFENSE)
	ok(after > before, "guarding actually raises the guard's defence",
		"%d before, %d after" % [before, after])
	ok(not keeper.status_effects.is_empty(),
		"and leaves something on them to say so", "%d effects" % keeper.status_effects.size())

	finish(game)


func finish(game):
	game.queue_free()
	await get_tree().process_frame
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
