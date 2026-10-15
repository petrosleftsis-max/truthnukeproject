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
	ok(Stats.MAX_LEVEL == 20, "there are twenty levels", "%d" % Stats.MAX_LEVEL)
	ok(Stats.main_stat_at(1) == 10, "level 1 main stat is 10", "%d" % Stats.main_stat_at(1))
	ok(Stats.main_stat_at(20) == 85, "level 20 main stat is 85", "%d" % Stats.main_stat_at(20))
	ok(Stats.secondary_stat_at(20) == 43, "level 20 secondary is half of 85", "%d" % Stats.secondary_stat_at(20))
	ok(Stats.main_stat_at(10) == 46 and Stats.secondary_stat_at(10) == 23,
		"level 10 is where level 2 was, near enough", "%d / %d" % [Stats.main_stat_at(10), Stats.secondary_stat_at(10)])
	var climbs := true
	for level in range(1, 20):
		climbs = climbs and Stats.main_stat_at(level + 1) > Stats.main_stat_at(level) \
			and Stats.secondary_stat_at(level + 1) >= Stats.secondary_stat_at(level)
	ok(climbs, "every level is a step up")
	ok(Stats.secondary_stat_at(2) == 10, "an early secondary never drops below 10", "%d" % Stats.secondary_stat_at(2))
	ok(Stats.main_stat_at(29) == Stats.main_stat_at(20), "beyond level 20 is clamped")
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
	var cyrus_ten = Stats.stats_for_level(10, Stats.Type.SELF, Stats.Type.PHYSICAL)
	ok(cyrus_ten["self_stat"] == 46, "main stat at 46", "%d" % cyrus_ten["self_stat"])
	ok(cyrus_ten["physical"] == 23, "secondary at 23", "%d" % cyrus_ten["physical"])
	ok(cyrus_ten["intellect"] == 10 and cyrus_ten["mindfulness"] == 10, "the rest stay at 10",
		"intellect %d, mindfulness %d" % [cyrus_ten["intellect"], cyrus_ten["mindfulness"]])
	var twenty = Stats.stats_for_level(20, Stats.Type.INTELLECT, Stats.Type.MINDFULNESS)
	ok(twenty["intellect"] == 85 and twenty["mindfulness"] == 43, "and level 20 does the same",
		"%d / %d" % [twenty["intellect"], twenty["mindfulness"]])
	log_line("")

	log_line("======== gates by level ========")
	ok(Stats.gates_for_level(1) == [0, 2, 0, 0], "level 1: two World")
	ok(Stats.gates_for_level(5) == [0, 3, 1, 0], "level 5: Hermes opens")
	ok(Stats.gates_for_level(9) == [0, 3, 2, 1], "level 9: Yaldabaoth opens")
	ok(Stats.gates_for_level(10) == [0, 3, 2, 1], "level 10: what level 2 was")
	ok(Stats.gates_for_level(20) == [0, 3, 3, 2], "level 20: what level 3 was")
	var never_fewer := true
	for level in range(1, 20):
		var now := Stats.gates_for_level(level)
		var next := Stats.gates_for_level(level + 1)
		for gate in range(1, 4):
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
	spawn.level = 20
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
	ok(built.level == 20, "the combatant is at the spawn's level", "%d" % built.level)
	ok(combat.stat_of(built, Stats.Type.SELF) == 85, "with the level's main stat",
		"%d" % combat.stat_of(built, Stats.Type.SELF))
	ok(combat.stat_of(built, Stats.Type.DEFENSE) == 70, "the spawn's defense, not the level's",
		"%d" % combat.stat_of(built, Stats.Type.DEFENSE))
	ok(built.weapon_base == 30, "and the spawn's weapon base", "%d" % built.weapon_base)

	var plain = combat.create_combatant(CombatantDatabase.combatants["cyrus"], "cyrus")
	ok(plain.level == 1, "no spawn means level 1", "%d" % plain.level)
	ok(combat.stat_of(plain, Stats.Type.DEFENSE) == 10, "and a default defense",
		"%d" % combat.stat_of(plain, Stats.Type.DEFENSE))
	log_line("")

	log_line("======== weapon base and level both reach the damage ========")
	var melee: SkillDefinition = SkillDatabase.skills["greatsword_attack"]
	var target = combat.create_combatant(CombatantDatabase.combatants["barbarian"], "barbarian")
	var weak = combat.skill_damage(plain, target, melee)
	var strong = combat.skill_damage(built, target, melee)
	ok(strong > weak, "a level 20 with a better weapon hits far harder", "%d -> %d" % [weak, strong])
	# Read off the skill rather than written in, so balancing Greatsword Attack
	# is not the same as breaking this test.
	var expected_weak = Stats.final_damage(6 + 0.7 * 10, melee.ability_modifier, 10)
	ok(weak == expected_weak, "the level 1 number is the formula's", "%d, wanted %d" % [weak, expected_weak])
	# Melee scales from Physical, which is Cyrus's secondary - 43 at level 20,
	# not the 85 his main stat is at.
	var expected_strong = Stats.final_damage(30 + 0.7 * 43, melee.ability_modifier, 10)
	ok(strong == expected_strong, "and so is the level 20 one", "%d, wanted %d" % [strong, expected_strong])
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
	ok(combat.meets_level_for(built, gated), "a level 20 has")
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
