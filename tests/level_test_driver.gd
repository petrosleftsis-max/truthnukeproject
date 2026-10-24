extends Node
## Levels: the stats they hand out, the skills they gate, and the per-spawn
## weapon base and defense.

var LOG_PATH := HarnessLog.path_for("level")

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
	get_tree().create_timer(120.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


func run_test():
	log_line("======== the numbers a level hands out ========")
	ok(Stats.MAX_LEVEL == 64, "there are sixty-four levels", "%d" % Stats.MAX_LEVEL)
	ok(Stats.main_stat_at(1) == 10, "level 1 main stat is 10", "%d" % Stats.main_stat_at(1))
	ok(Stats.main_stat_at(64) == 85, "level 64 main stat is 85", "%d" % Stats.main_stat_at(64))
	ok(Stats.secondary_stat_at(64) == 43, "level 64 secondary is half of 85", "%d" % Stats.secondary_stat_at(64))
	ok(Stats.main_stat_at(8) == 18 and Stats.main_stat_at(14) == 25,
		"the lab's level 8 and the city's 14 on the way", "%d / %d" % [Stats.main_stat_at(8), Stats.main_stat_at(14)])
	var climbs := true
	for level in range(1, Stats.MAX_LEVEL):
		climbs = climbs and Stats.main_stat_at(level + 1) > Stats.main_stat_at(level) \
			and Stats.secondary_stat_at(level + 1) >= Stats.secondary_stat_at(level)
	ok(climbs, "every level is a step up")
	ok(Stats.secondary_stat_at(2) == 10, "an early secondary never drops below 10", "%d" % Stats.secondary_stat_at(2))
	ok(Stats.main_stat_at(99) == Stats.main_stat_at(64), "beyond level 64 is clamped")
	log_line("")

	log_line("======== a level 1 combatant is flat 10s ========")
	var flat = Stats.stats_for_level(1, Stats.Type.SELF, Stats.Type.PHYSICAL)
	var all_ten = true
	for key in flat:
		if flat[key] != 10:
			all_ten = false
	ok(all_ten, "every attribute is 10 whoever they are", "%s" % flat)
	log_line("")

	log_line("======== higher levels raise only the two ========")
	var cyrus_city = Stats.stats_for_level(14, Stats.Type.SELF, Stats.Type.PHYSICAL)
	ok(cyrus_city["self_stat"] == 25, "main stat at 25", "%d" % cyrus_city["self_stat"])
	ok(cyrus_city["physical"] == 13, "secondary at 13", "%d" % cyrus_city["physical"])
	ok(cyrus_city["intellect"] == 10 and cyrus_city["mindfulness"] == 10, "the rest stay at 10",
		"intellect %d, mindfulness %d" % [cyrus_city["intellect"], cyrus_city["mindfulness"]])
	var top = Stats.stats_for_level(64, Stats.Type.INTELLECT, Stats.Type.MINDFULNESS)
	ok(top["intellect"] == 85 and top["mindfulness"] == 43, "and level 64 does the same",
		"%d / %d" % [top["intellect"], top["mindfulness"]])
	log_line("")

	log_line("======== gates by level ========")
	# D&D's full casters stretched to 64 (Stats.GATE_STEPS), World first.
	var counts := func(level: int) -> Array: return Stats.gates_for_level(level).slice(1)
	ok(Stats.gates_for_level(1).size() == Stats.GATE_NAMES.size(), "a count for every gate there is")
	ok(counts.call(1).slice(0, 3) == [2, 0, 0], "level 1: two World", "%s" % [counts.call(1)])
	ok(counts.call(7).slice(0, 3) == [3, 0, 0] and counts.call(8).slice(0, 3) == [4, 2, 0], "level 8: Hermes opens, twice",
		"%s" % [counts.call(8)])
	ok(counts.call(13)[2] == 0 and counts.call(14).slice(0, 4) == [4, 3, 2, 0], "level 14: Pandora opens, twice",
		"%s" % [counts.call(14)])
	ok(counts.call(60)[9] == 0 and counts.call(61)[9] == 1, "level 61: Yaldabaoth, the tenth, opens", "%s" % [counts.call(61)])
	ok(counts.call(64) == [4, 3, 3, 3, 3, 2, 2, 1, 1, 1], "level 64: everything", "%s" % [counts.call(64)])
	var opens := []
	for gate in range(1, Stats.GATE_NAMES.size()):
		for level in range(1, Stats.MAX_LEVEL + 1):
			if Stats.gates_for_level(level)[gate] > 0:
				opens.append(level)
				break
	ok(opens == [1, 8, 14, 21, 28, 34, 41, 47, 54, 61], "a new gate every six or seven levels", "%s" % [opens])
	var never_fewer := true
	for level in range(1, Stats.MAX_LEVEL):
		var now := Stats.gates_for_level(level)
		var next := Stats.gates_for_level(level + 1)
		for gate in range(1, now.size()):
			never_fewer = never_fewer and next[gate] >= now[gate]
	ok(never_fewer, "and no level takes a gate away")
	log_line("")

	log_line("======== each character is built around the right pair ========")
	var expected = {
		"cyrus": [Stats.Type.SELF, Stats.Type.PHYSICAL],
		"prometheus": [Stats.Type.INTELLECT, Stats.Type.MINDFULNESS],
		"enfina": [Stats.Type.PHYSICAL, Stats.Type.INTELLECT],
		"alithia": [Stats.Type.MINDFULNESS, Stats.Type.SELF],
		"mimic": [Stats.Type.SELF, Stats.Type.MINDFULNESS],
		"sorcerer": [Stats.Type.INTELLECT, Stats.Type.MINDFULNESS],
		"priest": [Stats.Type.MINDFULNESS, Stats.Type.SELF],
		"ranger": [Stats.Type.PHYSICAL, Stats.Type.MINDFULNESS],
		"barbarian": [Stats.Type.PHYSICAL, Stats.Type.SELF],
		"bomber": [Stats.Type.MINDFULNESS, Stats.Type.PHYSICAL],
	}
	for key in expected:
		if not CombatantDatabase.combatants.has(key):
			ok(false, "%s is in the database" % key)
			continue
		var definition: CombatantDefinition = CombatantDatabase.combatants[key]
		ok(definition.main_stat == expected[key][0] and definition.secondary_stat == expected[key][1],
			"%s" % key, "%s / %s" % [Stats.stat_name(definition.main_stat), Stats.stat_name(definition.secondary_stat)])
	ok(not CombatantDatabase.combatants.has("eye"), "the Eye is gone")
	log_line("")

	log_line("======== a spawn decides level, weapon and defense ========")
	var spawn := SpawnDefinition.new()
	spawn.combatant_key = "cyrus"
	spawn.level = 64
	spawn.weapon_base = 30
	spawn.defense = 70

	Campaign.reset()
	Campaign.current_encounter = load("res://data/encounters/encounter_01_ambush.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	combat.finish_deployment()
	await get_tree().process_frame

	var built = combat.create_combatant(CombatantDatabase.combatants["cyrus"], "cyrus", "", spawn)
	ok(built.level == 64, "the combatant is at the spawn's level", "%d" % built.level)
	ok(combat.stat_of(built, Stats.Type.SELF) == 85, "with the level's main stat",
		"%d" % combat.stat_of(built, Stats.Type.SELF))
	ok(combat.stat_of(built, Stats.Type.DEFENSE) == 70, "the spawn's defense, not the level's",
		"%d" % combat.stat_of(built, Stats.Type.DEFENSE))
	ok(built.weapon_base == 30, "and the spawn's weapon base", "%d" % built.weapon_base)

	var plain = combat.create_combatant(CombatantDatabase.combatants["cyrus"], "cyrus")
	ok(plain.level == 1, "no spawn means level 1", "%d" % plain.level)
	# With no spawn to say, their own at that level (the party's sheet: 12 at 1).
	ok(combat.stat_of(plain, Stats.Type.DEFENSE) == CombatantDatabase.combatants["cyrus"].defense_at(1), "and their own defense",
		"%d" % combat.stat_of(plain, Stats.Type.DEFENSE))
	log_line("")

	log_line("======== weapon base and level both reach the damage ========")
	var melee: SkillDefinition = SkillDatabase.skills["greatsword_attack"]
	var target = combat.create_combatant(CombatantDatabase.combatants["barbarian"], "barbarian")
	var weak = combat.skill_damage(plain, target, melee)
	var strong = combat.skill_damage(built, target, melee)
	ok(strong > weak, "a level 64 with a better weapon hits far harder", "%d -> %d" % [weak, strong])
	# Read off the skill rather than written in, so balancing Greatsword Attack
	# is not the same as breaking this test.
	# The barbarian's own defence at its level, as no spawn says otherwise.
	var soak: int = combat.stat_of(target, Stats.Type.DEFENSE)
	var expected_weak = Stats.final_damage(6 + 0.7 * 10, melee.ability_modifier, soak)
	ok(weak == expected_weak, "the level 1 number is the formula's", "%d, wanted %d" % [weak, expected_weak])
	# Melee scales from Physical, which is Cyrus's secondary - 43 at level 64,
	# not the 85 his main stat is at.
	var expected_strong = Stats.final_damage(30 + 0.7 * 43, Combat.modifier_of(built, melee), soak)
	ok(strong == expected_strong, "and so is the level 64 one", "%d, wanted %d" % [strong, expected_strong])
	log_line("")

	log_line("======== skills are gated by level ========")
	# Whichever skill this character actually carries, since which skills belong
	# to whom is content: a gate can only be seen on a skill they have.
	var gated_key = ""
	for key in combat.create_combatant(CombatantDatabase.combatants["cyrus"], "cyrus").skill_list:
		var candidate: SkillDefinition = SkillDatabase.skills[key]
		# A main-panel skill: a secondary or a spell lives on another panel, and
		# would be missing from main_skills_of for a reason that is not the gate.
		if not candidate.is_secondary and candidate.spell_slot_level == 0:
			gated_key = key
			break
	var gated: SkillDefinition = SkillDatabase.skills[gated_key]
	var original = gated.required_level
	gated.required_level = 3
	var one = combat.create_combatant(CombatantDatabase.combatants["cyrus"], "cyrus")
	ok(not combat.meets_level_for(one, gated), "a level 1 has not learned a level 3 skill")
	ok(not (gated_key in combat.main_skills_of(one)), "so it is not on their panel",
		"%s" % [combat.main_skills_of(one)])
	ok(combat.meets_level_for(built, gated), "a level 64 has")
	ok(gated_key in combat.main_skills_of(built), "and it is on theirs",
		"%s" % [combat.main_skills_of(built)])
	gated.required_level = 2
	var two_spawn := SpawnDefinition.new()
	two_spawn.level = 2
	var two = combat.create_combatant(CombatantDatabase.combatants["cyrus"], "cyrus", "", two_spawn)
	ok(combat.meets_level_for(two, gated), "a level 2 meets a level 2 requirement")
	gated.required_level = original
	ok(gated_key in combat.main_skills_of(one), "and putting it back restores it")
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
