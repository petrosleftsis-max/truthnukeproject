extends Node
## What an item is worth beside a skill, now that both are worked out the same
## way from a base of their own.
##
## A skill's base is the caster's arm and attribute and moves with them; an
## item's is one number written on it. So the question is where that number
## lands against the range a real character spans.

var LOG_PATH := HarnessLog.path_for("scale")
var _log: FileAccess

func log_line(t): _log.store_line(t); _log.flush()


func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(120.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_probe()


func run_probe():
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

	var party := []
	for comb in combat.combatants:
		if comb.alive and comb.side == 0:
			party.append(comb)
	var mark = {}
	for comb in combat.combatants:
		if comb.alive and comb.side != 0:
			mark = comb
			break

	log_line("======== the base each thing is built on ========")
	log_line("  a skill's base is WeaponBase + 0.7 x its scaling stat, so it")
	log_line("  moves with whoever is holding it. An item's is its own number.")
	for comb in party:
		var line = "  %-12s" % comb.name
		for key in ["rapier", "burner", "water_spike"]:
			var skill: SkillDefinition = SkillDatabase.skills.get(key)
			if skill != null:
				line += "  %s %.0f" % [skill.name, combat.power_behind(comb, skill)]
		log_line(line)
	# Every item used to answer with the same number, so one line covered them
	# all. They are a ladder now and each one has to speak for itself.
	for key in ItemDatabase.items:
		log_line("  %-12s  %-20s %.0f" % ["(item)", key,
			combat.power_behind(party[0], ItemDatabase.items[key])])
	log_line("")

	log_line("======== what lands on the same target ========")
	log_line("  against %s, defence %d" % [mark.name, combat.stat_of(mark, Stats.Type.DEFENSE)])
	log_line("  %-18s %-9s %-7s %s" % ["", "power", "damage", "one tick"])
	for key in SkillDatabase.skills:
		var skill: SkillDefinition = SkillDatabase.skills[key]
		if skill == null or not skill.deals_damage:
			continue
		if not ItemDatabase.is_item(key) and skill.spell_slot_level == 0 and skill.max_range > 1:
			continue
		describe(combat, party[0], mark, key, skill)
	log_line("")

	log_line("======== and what the conditions tick for ========")
	log_line("  %-18s %-9s %-7s %s" % ["", "power", "dial", "one tick"])
	for key in SkillDatabase.skills:
		var skill: SkillDefinition = SkillDatabase.skills[key]
		if skill == null:
			continue
		for effect in skill.all_effects():
			if effect == null or effect.type != EffectDefinition.EffectType.CONDITION:
				continue
			if effect.condition == null or effect.condition.dot_modifier <= 0.0:
				continue
			var caster = party[0]
			# In the hands of whoever the skill actually suits, for a skill.
			for comb in party:
				if combat.stat_of(comb, skill.scaling_stat) > combat.stat_of(caster, skill.scaling_stat):
					caster = comb
			var dial = effect.condition_dot_strength()
			var base = combat.dot_base_damage(caster, skill, dial)
			var tick = combat.dot_tick(mark, base, effect.condition.dot_min, effect.condition.dot_max)
			var after = combat.resisted_damage(mark, effect.condition.dot_type, tick)
			log_line("  %-18s %-9.0f %-7s %d%s" % [
				"%s%s" % [skill.name, " (item)" if ItemDatabase.is_item(key) else ""],
				combat.power_behind(caster, skill), "x%.2f" % dial, after,
				"  was %d-%d" % [effect.condition.dot_min, effect.condition.dot_max]
					if ItemDatabase.is_item(key) else ""])

	game.queue_free()
	await get_tree().process_frame
	log_line("FAILURES: 0")
	get_tree().quit(0)


func describe(combat, caster, mark, key, skill):
	log_line("  %-18s %-9.0f %-7d %s" % [
		"%s%s" % [skill.name, " (item)" if ItemDatabase.is_item(key) else ""],
		combat.power_behind(caster, skill),
		combat.skill_damage(caster, mark, skill), "-"])
