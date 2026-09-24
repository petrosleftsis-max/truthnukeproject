extends Node
## Tests damage types and per-combatant resistances.

var LOG_PATH := HarnessLog.path_for("damage")

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
	get_tree().create_timer(90.0).timeout.connect(func(): get_tree().quit(2))
	await get_tree().process_frame
	await get_tree().process_frame
	await run_test()


func run_test():
	log_line("======== the eight types exist and are named ========")
	var expected = ["Physical", "Fire", "Water", "Wind", "Earth", "Poison", "Psychic",
		"Plasma", "Ice", "Lightning", "Metal", "Acid", "Idol"]
	# Not a count: types get added, and that is allowed. What must hold is that
	# every one of them is named and coloured, and that the original eight still
	# carry the numbers every existing .tres stores them by - which the elements
	# suite checks name by name.
	ok(Damage.TYPE_NAMES.size() == Damage.Type.size(), "every damage type is named",
		"%d names for %d types" % [Damage.TYPE_NAMES.size(), Damage.Type.size()])
	ok(Damage.TYPE_COLOURS.size() == Damage.Type.size(), "and coloured",
		"%d colours for %d types" % [Damage.TYPE_COLOURS.size(), Damage.Type.size()])
	for i in expected.size():
		ok(Damage.type_name(i) == expected[i], "type %d is %s" % [i, expected[i]], "'%s'" % Damage.type_name(i))
	log_line("")

	log_line("======== the resistance maths ========")
	ok(Damage.after_resistance(10, 0) == 10, "no resistance leaves damage alone", "%d" % Damage.after_resistance(10, 0))
	ok(Damage.after_resistance(10, 20) == 8, "20% resistance takes a fifth off", "%d" % Damage.after_resistance(10, 20))
	ok(Damage.after_resistance(10, -20) == 12, "-20% lets a fifth extra through", "%d" % Damage.after_resistance(10, -20))
	ok(Damage.after_resistance(10, 100) == 0, "100% is immunity", "%d" % Damage.after_resistance(10, 100))
	ok(Damage.after_resistance(10, 150) == 0, "beyond immune still stops at zero, never heals", "%d" % Damage.after_resistance(10, 150))
	log_line("")

	log_line("======== the two set in the database ========")
	var sorcerer: CombatantDefinition = CombatantDatabase.combatants["sorcerer"]
	var priest: CombatantDefinition = CombatantDatabase.combatants["priest"]
	ok(sorcerer.resist_fire > 0, "the Sorcerer resists fire", "%d%%" % sorcerer.resist_fire)
	ok(priest.resist_earth < 0, "and the Priest is vulnerable to earth", "%d%%" % priest.resist_earth)
	ok(sorcerer.resistance_table()[Damage.Type.FIRE] == sorcerer.resist_fire,
		"the lookup table agrees with the field it was built from",
		"%s" % sorcerer.resistance_table()[Damage.Type.FIRE])
	log_line("")

	log_line("======== resistance changes what actually lands ========")
	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_03_watcher.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	combat.finish_deployment()
	await get_tree().process_frame

	# Built from the database rather than picked out of the encounter: which
	# combatants an encounter fields is level design and changes often, and this
	# is testing resistances, not who happens to be in that fight today.
	var acolyte = combat.create_combatant(CombatantDatabase.combatants["sorcerer"], "sorcerer")   # fire-resistant
	var attendant = combat.create_combatant(CombatantDatabase.combatants["priest"], "priest")     # earth-vulnerable
	ok(acolyte != null and attendant != null, "both were built from the database")
	ok(acolyte.resistances[Damage.Type.FIRE] == CombatantDatabase.combatants["sorcerer"].resist_fire,
		"resistances copied onto the combatant", "%s" % acolyte.resistances[Damage.Type.FIRE])

	# A fixed 10-point hit of each type, so the roll can't muddy the result.
	var fire := EffectDefinition.new()
	fire.type = EffectDefinition.EffectType.DAMAGE
	fire.damage_type = Damage.Type.FIRE
	fire.min_amount = 10
	fire.max_amount = 10
	var earth := EffectDefinition.new()
	earth.type = EffectDefinition.EffectType.DAMAGE
	earth.damage_type = Damage.Type.EARTH
	earth.min_amount = 10
	earth.max_amount = 10

	var messages: Array = []
	combat.update_information.connect(func(text): messages.append(text))

	# Worked out from whatever the database now says rather than from the numbers
	# it said the day this was written - the arithmetic is what is being checked,
	# and the percentages are balance somebody is entitled to move.
	var fire_resist = acolyte.resistances[Damage.Type.FIRE]
	var earth_weak = attendant.resistances[Damage.Type.EARTH]
	acolyte.hp = 50
	combat.do_damage(attendant, acolyte, fire, null, false)
	ok(50 - acolyte.hp == Damage.after_resistance(10, fire_resist),
		"10 fire on the fire-resistant one lands as its resistance says",
		"%d taken at %d%% resistance" % [50 - acolyte.hp, fire_resist])
	ok(50 - acolyte.hp < 10, "which is less than it would take neutral",
		"%d" % (50 - acolyte.hp))
	acolyte.hp = 50
	combat.do_damage(attendant, acolyte, earth, null, false)
	ok(50 - acolyte.hp == Damage.after_resistance(10, acolyte.resistances[Damage.Type.EARTH]),
		"10 earth on them lands as theirs says too", "%d" % (50 - acolyte.hp))

	attendant.hp = 50
	combat.do_damage(acolyte, attendant, earth, null, false)
	ok(50 - attendant.hp == Damage.after_resistance(10, earth_weak),
		"10 earth on the earth-vulnerable one lands as its vulnerability says",
		"%d taken at %d%%" % [50 - attendant.hp, earth_weak])
	ok(50 - attendant.hp > 10, "which is more than it would take neutral",
		"%d" % (50 - attendant.hp))
	attendant.hp = 50
	combat.do_damage(acolyte, attendant, fire, null, false)
	ok(50 - attendant.hp == 10, "10 fire on them is unchanged", "%d" % (50 - attendant.hp))
	log_line("")

	log_line("======== the log says what kind, and whether it was resisted ========")
	var joined = "".join(messages)
	ok(joined.contains("fire damage (resisted)"), "resisted fire is called out", "%s" % messages[0].strip_edges())
	ok(joined.contains("earth damage (vulnerable)"), "vulnerable earth is called out", "%s" % messages[2].strip_edges())
	ok(joined.contains("earth damage") and not messages[1].contains("("), "a neutral hit gets no note", "%s" % messages[1].strip_edges())
	log_line("")

	log_line("======== conditions burn with their own element ========")
	var burn: ConditionDefinition = load("res://conditions/burn.tres")
	var poisoned: ConditionDefinition = load("res://conditions/poisoned.tres")
	ok(burn.dot_type == Damage.Type.FIRE, "Burn is fire", "%s" % Damage.type_name(burn.dot_type))
	ok(poisoned.dot_type == Damage.Type.POISON, "Poisoned is poison", "%s" % Damage.type_name(poisoned.dot_type))
	ok(load("res://conditions/windswept.tres").dot_type == Damage.Type.WIND, "Windswept is wind")
	ok(load("res://conditions/crystallised.tres").dot_type == Damage.Type.EARTH, "Crystallised is earth")
	ok(load("res://conditions/frozen.tres").dot_type == Damage.Type.WATER, "Frozen is water")

	# Burning the fire-resistant sorcerer should hurt less than burning someone neutral.
	# Enough to survive forty of the worst rolls Burn has in it, worked out from
	# the condition rather than written down: a flat 200 quietly became too
	# little the day its range went up, and the pair died partway through.
	var burn_room = 40 * maxi(burn.dot_max, 1) + 1
	acolyte.hp = burn_room
	attendant.hp = burn_room
	for i in 40:
		combat.tick_condition_damage(acolyte, burn)
		combat.tick_condition_damage(attendant, burn)
	ok(acolyte.alive and attendant.alive,
		"both live through forty ticks, so every one of them landed",
		"%d and %d left of %d" % [acolyte.hp, attendant.hp, burn_room])
	var resistant_took = burn_room - acolyte.hp
	var neutral_took = burn_room - attendant.hp
	ok(resistant_took < neutral_took,
		"40 burn ticks hurt the fire-resistant one less", "%d vs %d" % [resistant_took, neutral_took])
	log_line("")

	log_line("======== skills carry the right element ========")
	# Only the two skills whose names still name their element. Everything else
	# is checked against what the skill itself says, just below, so repurposing
	# one is not something a test should object to.
	for pair in [["fireball", Damage.Type.FIRE], ["greatsword_attack", Damage.Type.PHYSICAL]]:
		var skill: SkillDefinition = SkillDatabase.skills[pair[0]]
		var found = -1
		for effect in skill.all_effects():
			if effect.type == EffectDefinition.EffectType.DAMAGE:
				found = effect.damage_type
				break
		ok(found == skill.damage_type, "%s resolves the type set on the skill" % skill.name,
			"%s vs %s" % [Damage.type_name(found), Damage.type_name(skill.damage_type)])
		ok(found == pair[1], "%s deals %s" % [skill.name, Damage.type_name(pair[1])], "got %s" % Damage.type_name(found))
	log_line("")

	log_line("======== every damaging skill resolves the type it names ========")
	for key in SkillDatabase.skills:
		var each: SkillDefinition = SkillDatabase.skills[key]
		if not each.deals_damage:
			continue
		var resolved = -1
		for effect in each.all_effects():
			if effect.type == EffectDefinition.EffectType.DAMAGE:
				resolved = effect.damage_type
				break
		ok(resolved == each.damage_type, "%s hits as %s" % [each.name, Damage.type_name(each.damage_type)],
			"resolved %s" % Damage.type_name(resolved))
	log_line("")

	log_line("======== damage is set on the skill, not buried in an effect ========")
	var melee: SkillDefinition = SkillDatabase.skills["greatsword_attack"]
	ok(melee.deals_damage, "an attack says so on the skill itself")
	ok(melee.effects.is_empty(), "and carries no effect just to hold a damage type",
		"%d effects" % melee.effects.size())
	ok(melee.all_effects().size() == 1, "yet still resolves one damage effect",
		"%d" % melee.all_effects().size())
	ok(melee.all_effects()[0].type == EffectDefinition.EffectType.DAMAGE, "which is the damage")
	ok(melee.all_effects()[0].damage_type == melee.damage_type,
		"of the type the skill names")
	var dummy_a = combat.create_combatant(CombatantDatabase.combatants["cyrus"], "cyrus")
	var dummy_b = combat.create_combatant(CombatantDatabase.combatants["barbarian"], "barbarian")
	var hp_before = dummy_b.hp
	for effect in melee.all_effects():
		combat.apply_effect(dummy_a, dummy_b, effect, melee)
	ok(dummy_b.hp < hp_before, "and a skill with no effects at all still hurts",
		"%d -> %d" % [hp_before, dummy_b.hp])

	var mender: SkillDefinition = SkillDatabase.skills["heal"]
	ok(not mender.deals_damage, "a heal says it deals none")
	var untouched = combat.create_combatant(CombatantDatabase.combatants["barbarian"], "barbarian")
	untouched.hp = 3
	for effect in mender.all_effects():
		combat.apply_effect(dummy_a, untouched, effect, mender)
	ok(untouched.hp > 3, "and heals rather than hitting what it lands on", "%d" % untouched.hp)
	log_line("")

	log_line("======== healing scales off the healer, like damage does ========")
	var alithia = combat.create_combatant(CombatantDatabase.combatants["alithia"], "alithia")
	var level_1_heal = combat.heal_amount(alithia, mender)
	# What it comes to is balance and yours to set; that it is worked out from
	# the healer rather than written on the effect is what this checks.
	ok(level_1_heal == roundi((Stats.WEAPON_BASE + 0.7 * combat.stat_of(alithia, mender.scaling_stat)) * mender.ability_modifier),
		"a level 1 heal is the formula off her Mindfulness", "%d from %d Mindfulness at x%s" % [
			level_1_heal, combat.stat_of(alithia, mender.scaling_stat), mender.ability_modifier])

	var veteran_spawn = SpawnDefinition.new()
	veteran_spawn.combatant_key = "alithia"
	veteran_spawn.level = 3
	var veteran = combat.create_combatant(CombatantDatabase.combatants["alithia"], "alithia", "", veteran_spawn)
	var level_3_heal = combat.heal_amount(veteran, mender)
	ok(level_3_heal > level_1_heal * 2,
		"and a level 3 healer mends far more, rather than the same flat number",
		"%d -> %d" % [level_1_heal, level_3_heal])
	ok(level_3_heal == roundi((Stats.WEAPON_BASE + 0.7 * combat.stat_of(veteran, mender.scaling_stat)) * mender.ability_modifier),
		"which is the formula, off her Mindfulness", "%d from %d Mindfulness" % [
			level_3_heal, combat.stat_of(veteran, mender.scaling_stat)])

	var patient = combat.create_combatant(CombatantDatabase.combatants["alithia"], "alithia")
	patient.hp = 1
	for effect in mender.all_effects():
		combat.apply_effect(veteran, patient, effect, mender)
	ok(patient.hp > 1, "and casting it actually restores that much", "%d" % patient.hp)
	ok(patient.hp <= combat.get_effective_stat(patient, "max_hp"),
		"never past full", "%d/%d" % [patient.hp, combat.get_effective_stat(patient, "max_hp")])

	# Nothing casting it - a heal applied by hand still has its flat range.
	var heal_effect = mender.all_effects()[0]
	patient.hp = 1
	combat.apply_effect(veteran, patient, heal_effect, null)
	ok(patient.hp >= 1 + heal_effect.min_amount and patient.hp <= 1 + heal_effect.max_amount,
		"with no skill behind it, the flat range still stands in",
		"%d, from %d-%d" % [patient.hp, heal_effect.min_amount, heal_effect.max_amount])
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
