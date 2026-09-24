extends Node
## Every skill that says it heals actually heals.
##
## Light Heal had no HEAL effect at all: pressing it spent a Gate of World and
## restored nothing. It is in Alithia's list, and she is one of the four ways
## into the game.

var LOG_PATH := HarnessLog.path_for("heals")
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
	log_line("======== nothing a character carries does nothing ========")
	# A skill with no effects at all is spent for no result. Which is never what
	# anybody meant, so it is worth saying out loud.
	var hollow := []
	for key in CombatantDatabase.combatants:
		var definition: CombatantDefinition = CombatantDatabase.combatants[key]
		var carried: Array = definition.skills.duplicate()
		carried.append_array(definition.secondary_skills)
		for skill_key in carried:
			var skill: SkillDefinition = SkillDatabase.skills.get(skill_key)
			if skill == null:
				continue
			if skill.all_effects().is_empty() and not skill.teleports and not skill.suppresses_reactions:
				hollow.append("%s carries %s, which does nothing" % [key, skill_key])
	ok(hollow.is_empty(), "every carried skill does something", "%s" % [hollow])
	log_line("")

	log_line("======== the heals heal ========")
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

	var healer = null
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == "alithia":
			healer = comb
	ok(healer != null, "Alithia is in this fight")
	if healer == null:
		log_line("FAILURES: %d" % _fail)
		get_tree().quit(1)
		return
	ok("light_heal" in healer.skill_list, "and Light Heal is hers", "%s" % [healer.skill_list])

	for key in ["heal", "light_heal", "revitalizer"]:
		var skill: SkillDefinition = SkillDatabase.skills[key]
		var mends = false
		for effect in skill.all_effects():
			if effect.type == EffectDefinition.EffectType.HEAL:
				mends = true
		ok(mends, "%s carries a HEAL effect" % skill.name)
		# And really restores health when used, not only on paper.
		healer.hp = maxi(1, combat.get_effective_stat(healer, "max_hp") - 40)
		var hurt = healer.hp
		healer.spell_slots = healer.max_spell_slots.duplicate()
		await combat.use_skill(key, healer, healer.position, false, skill.is_secondary)
		ok(healer.hp > hurt, "  and using it restores health",
			"%d -> %d" % [hurt, healer.hp])
	log_line("")

	log_line("======== Light Heal is the lighter one ========")
	var light = combat.heal_amount(healer, SkillDatabase.skills["light_heal"])
	var full = combat.heal_amount(healer, SkillDatabase.skills["heal"])
	ok(light > 0, "it mends something", "%d" % light)
	ok(light < full, "and less than Heal does, as its modifier says",
		"%d vs %d" % [light, full])
	log_line("")

	log_line("======== a heal can be sized apart from the damage beside it ========")
	# ability_modifier was one dial for the lot - a hit, a heal and a tick all
	# read it - so a skill that both cut and mended did both at the same size.
	# An effect may now carry its own, and 0 still means "whatever the skill
	# is worth".
	var swing: SkillDefinition = SkillDatabase.skills["light_swing"]
	ok(swing != null and swing.name == "Light Swing", "Light Swing is in the database",
		swing.name if swing != null else "missing")
	var mend: EffectDefinition = null
	for effect in swing.all_effects():
		if effect.type == EffectDefinition.EffectType.HEAL:
			mend = effect
	ok(mend != null, "it mends whoever swung it")
	ok(mend != null and mend.applies_to_caster, "on themselves rather than the enemy")
	if mend != null:
		ok(mend.heal_modifier > 0.0, "and it sets a dial of its own",
			"x%s against the skill's x%s" % [mend.heal_modifier, swing.ability_modifier])
		var mended = combat.heal_amount(healer, swing, mend)
		var as_the_skill = combat.heal_amount(healer, swing)
		ok(mended > 0, "it mends something", "%d" % mended)
		ok(mended < as_the_skill,
			"less than the skill's own modifier would have mended",
			"%d with the dial, %d without" % [mended, as_the_skill])
		# The other half of the same swing is untouched by it.
		ok(swing.deals_damage, "and the swing still cuts")
		var cut = combat.base_skill_damage(healer, swing)
		ok(cut > mended, "for more than it gives back",
			"%d cut, %d mended" % [cut, mended])

	# A heal that sets no dial is still worth whatever its skill is.
	var plain: EffectDefinition = null
	for effect in SkillDatabase.skills["heal"].all_effects():
		if effect.type == EffectDefinition.EffectType.HEAL:
			plain = effect
	if plain != null:
		ok(plain.heal_modifier == 0.0, "Heal sets none")
		ok(combat.heal_amount(healer, SkillDatabase.skills["heal"], plain) == full,
			"and mends exactly what it did before", "%d" % full)
	log_line("")

	game.queue_free()
	await get_tree().process_frame
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
