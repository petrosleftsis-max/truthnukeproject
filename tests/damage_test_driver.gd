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
	Campaign.current_encounter = load("res://data/encounters/encounter_03_watcher.tres")
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
	var burn: ConditionDefinition = load("res://data/conditions/burn.tres")
	var poisoned: ConditionDefinition = load("res://data/conditions/poisoned.tres")
	ok(burn.dot_type == Damage.Type.FIRE, "Burn is fire", "%s" % Damage.type_name(burn.dot_type))
	ok(poisoned.dot_type == Damage.Type.POISON, "Poisoned is poison", "%s" % Damage.type_name(poisoned.dot_type))
	ok(load("res://data/conditions/windswept.tres").dot_type == Damage.Type.WIND, "Windswept is wind")
	ok(load("res://data/conditions/crystallised.tres").dot_type == Damage.Type.EARTH, "Crystallised is earth")
	ok(load("res://data/conditions/frozen.tres").dot_type == Damage.Type.WATER, "Frozen is water")

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
	# Her heals mend more for whatever of hers says so (Mercy I).
	var mercy := 1.0
	for passive in combat.active_passives(alithia):
		mercy += passive.heal_bonus
	# What it comes to is balance and yours to set; that it is worked out from
	# the healer rather than written on the effect is what this checks. Heal is on
	# the flat rule (APPROVED_TRIAL 2026-10-24): Heal Flat + Heal Per Stat x her
	# Mindfulness + Heal Per Weapon x her weapon base, Mercy I on all of it.
	var rule: EffectDefinition = combat.heal_effect_of(mender)
	ok(rule != null and rule.heals_flat(), "Heal is on the flat rule")
	ok(level_1_heal == roundi((rule.heal_flat + rule.heal_per_stat * combat.stat_of(alithia, mender.scaling_stat)
		+ rule.heal_per_weapon * alithia.get("weapon_base", Stats.WEAPON_BASE)) * mercy),
		"a level 1 heal is the formula off her Mindfulness and weapon", "%d from %d Mindfulness" % [
			level_1_heal, combat.stat_of(alithia, mender.scaling_stat)])

	var veteran_spawn = SpawnDefinition.new()
	veteran_spawn.combatant_key = "alithia"
	veteran_spawn.level = 20
	var veteran = combat.create_combatant(CombatantDatabase.combatants["alithia"], "alithia", "", veteran_spawn)
	var level_3_heal = combat.heal_amount(veteran, mender)
	var veteran_mercy := 1.0
	for passive in combat.active_passives(veteran):
		veteran_mercy += passive.heal_bonus
	# Mindfulness still counts, but modestly: the trial keeps the range narrow.
	ok(level_3_heal > level_1_heal,
		"and a level 20 healer mends more, from her Mindfulness",
		"%d -> %d" % [level_1_heal, level_3_heal])
	ok(level_3_heal == roundi((rule.heal_flat + rule.heal_per_stat * combat.stat_of(veteran, mender.scaling_stat)
		+ rule.heal_per_weapon * veteran.get("weapon_base", Stats.WEAPON_BASE)) * veteran_mercy),
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
	the_flat_heal_trial(combat)

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


## The revised healing, an APPROVED_TRIAL (2026-10-24, docs/healing_revision.md):
## the flat rule on Light Heal, Heal, Communion, Restoration and Mend the Bound;
## Mercy I on the whole amount and never on the share of health; the Mimic healing
## from its Self; the Gate Nades and Medicine left as they were.
func the_flat_heal_trial(combat):
	log_line("======== the flat heal trial ========")
	var trial := {"light_heal": [8.0, 0.15, 0.2], "heal": [12.0, 0.25, 0.3], "communion": [8.0, 0.15, 0.2],
		"restoration": [0.0, 0.25, 0.0], "mend_the_bound": [12.0, 0.25, 0.3]}
	for key in trial:
		var rule: EffectDefinition = combat.heal_effect_of(SkillDatabase.skills[key])
		ok(rule != null and is_equal_approx(rule.heal_flat, trial[key][0]) and is_equal_approx(rule.heal_per_stat, trial[key][1])
			and is_equal_approx(rule.heal_per_weapon, trial[key][2]), "%s: %s + %s x stat + %s x weapon base" % [key, trial[key][0], trial[key][1], trial[key][2]])
	ok(is_equal_approx(combat.heal_effect_of(SkillDatabase.skills["restoration"]).heal_share_of_health, 0.5), "  Restoration keeps half the target's health")
	ok(not combat.heal_effect_of(SkillDatabase.skills["grace"]).heals_flat(), "  Grace is left as it was")
	ok(is_equal_approx(SkillDatabase.skills["mend_the_bound"].ability_modifier, 1.0), "  Mend the Bound has lost its x0.9")

	var spawn := SpawnDefinition.new()
	spawn.combatant_key = "alithia"
	spawn.level = 54
	spawn.weapon_base = 10
	var alithia: Dictionary = combat.create_combatant(CombatantDatabase.combatants["alithia"], "alithia", "", spawn)
	var mind: int = combat.stat_of(alithia, Stats.Type.MINDFULNESS)
	var mercy := 1.0
	for passive in combat.active_passives(alithia):
		mercy += passive.heal_bonus
	ok(is_equal_approx(mercy, 1.1), "Mercy I is a tenth", str(mercy))
	ok(combat.heal_amount(alithia, SkillDatabase.skills["heal"]) == roundi((12.0 + 0.25 * mind + 0.3 * 10) * mercy),
		"her Heal at 54 with a weapon base of 10: Mercy I on all of it", "%d from %d Mindfulness" % [combat.heal_amount(alithia, SkillDatabase.skills["heal"]), mind])
	ok(combat.heal_amount(alithia, SkillDatabase.skills["communion"]) < combat.heal_amount(alithia, SkillDatabase.skills["heal"]),
		"  Communion mends less than Heal, per ally")
	var enfina: Dictionary = combat.create_combatant(CombatantDatabase.combatants["enfina"], "enfina")
	var most: int = combat.get_effective_stat(enfina, "max_hp")
	var restored: int = combat.predict_hit(alithia, enfina, SkillDatabase.skills["restoration"]).heal
	ok(restored == roundi(0.25 * mind * mercy) + roundi(0.5 * most), "  Restoration: Mercy I on the Mindfulness part, never on the half of her health",
		"%d on %d health" % [restored, most])
	var prometheus: Dictionary = combat.create_combatant(CombatantDatabase.combatants["prometheus"], "prometheus")
	ok(combat.predict_hit(alithia, prometheus, SkillDatabase.skills["heal"]).heal == combat.predict_hit(alithia, enfina, SkillDatabase.skills["heal"]).heal,
		"  the same Heal on Prometheus as on Enfina")

	var priest_spawn := SpawnDefinition.new()
	priest_spawn.combatant_key = "priest"
	priest_spawn.level = 18
	var priest: Dictionary = combat.create_combatant(CombatantDatabase.combatants["priest"], "priest", "", priest_spawn)
	var priest_mind: int = combat.stat_of(priest, Stats.Type.MINDFULNESS)
	ok(combat.heal_amount(priest, SkillDatabase.skills["heal"]) == roundi(12.0 + 0.25 * priest_mind + 0.3 * priest.get("weapon_base", Stats.WEAPON_BASE)),
		"a Priest's Heal is the same rule, no Mercy I", str(combat.heal_amount(priest, SkillDatabase.skills["heal"])))
	var summoner: Dictionary = combat.create_combatant(CombatantDatabase.combatants["summoner"], "summoner", "", priest_spawn)
	ok(combat.heal_amount(summoner, SkillDatabase.skills["mend_the_bound"]) == roundi(12.0 + 0.25 * combat.stat_of(summoner, Stats.Type.MINDFULNESS)
		+ 0.3 * summoner.get("weapon_base", Stats.WEAPON_BASE)), "the Summoner's Mend the Bound is Heal's rule", str(combat.heal_amount(summoner, SkillDatabase.skills["mend_the_bound"])))
	var mimic: Dictionary = combat.create_combatant(CombatantDatabase.combatants["mimic"], "mimic", "", priest_spawn)
	ok(combat.heal_amount(mimic, SkillDatabase.skills["heal"]) == roundi(12.0 + 0.25 * combat.stat_of(mimic, Stats.Type.SELF) + 0.3 * mimic.get("weapon_base", Stats.WEAPON_BASE)),
		"the Mimic's copied Heal works from its Self (Mimicry)", "%d from %d Self" % [combat.heal_amount(mimic, SkillDatabase.skills["heal"]), combat.stat_of(mimic, Stats.Type.SELF)])

	# The consumables stay as they were, for now: tested separately.
	var cyrus: Dictionary = combat.create_combatant(CombatantDatabase.combatants["cyrus"], "cyrus")
	ok(combat.predict_hit(cyrus, enfina, ItemDatabase.items["heal_gate_nade"]).heal == 21, "the Heal Gate Nade still mends 21",
		str(combat.predict_hit(cyrus, enfina, ItemDatabase.items["heal_gate_nade"]).heal))
	ok(combat.predict_hit(cyrus, enfina, ItemDatabase.items["communion_gate_nade"]).heal == 30, "  the Communion Gate Nade 30 each",
		str(combat.predict_hit(cyrus, enfina, ItemDatabase.items["communion_gate_nade"]).heal))
	ok(combat.predict_hit(cyrus, enfina, ItemDatabase.items["medicine"]).heal == 24, "  Medicine 24",
		str(combat.predict_hit(cyrus, enfina, ItemDatabase.items["medicine"]).heal))
	ok(combat.predict_hit(cyrus, enfina, ItemDatabase.items["cure_potion"]).heal == roundi(0.25 * most), "  a Cure Potion a quarter of her health",
		str(combat.predict_hit(cyrus, enfina, ItemDatabase.items["cure_potion"]).heal))
	log_line("")
