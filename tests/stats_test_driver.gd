extends Node
## Covers the stat-driven damage formula, the stat contest, and spell slots.

var LOG_PATH := HarnessLog.path_for("stats")

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


## A spell that exists only for this test, registered so a combatant can name
## it in their skill list like any other.
func register_spell(key: String, level: int) -> SkillDefinition:
	var spell := SkillDefinition.new()
	spell.name = "Test Spell %d" % level
	spell.spell_slot_level = level
	SkillDatabase.skills[key] = spell
	return spell


func run_test():
	log_line("======== the formula ========")
	# BaseDamage = 6 + 0.7 x Stat; Final = Base x Modifier x 40/(40 + Defense)
	ok(is_equal_approx(Stats.base_damage(50), 41.0), "base damage at stat 50 is 41", "%s" % Stats.base_damage(50))
	ok(is_equal_approx(Stats.base_damage(0), 6.0), "a stat of 0 leaves just the weapon", "%s" % Stats.base_damage(0))
	ok(Stats.final_damage(41.0, 1.0, 0) == 41, "no defense means no reduction", "%d" % Stats.final_damage(41.0, 1.0, 0))
	ok(Stats.final_damage(41.0, 1.0, 40) == 21, "defense 40 roughly halves it", "%d" % Stats.final_damage(41.0, 1.0, 40))
	ok(Stats.final_damage(41.0, 1.0, 120) == 10, "defense 120 quarters it", "%d" % Stats.final_damage(41.0, 1.0, 120))
	ok(Stats.final_damage(41.0, 2.0, 0) == 82, "the modifier multiplies", "%d" % Stats.final_damage(41.0, 2.0, 0))
	ok(Stats.final_damage(1.0, 0.01, 100) >= 1, "a hit always costs at least 1")
	log_line("")

	log_line("======== the database says which two stats a character is built on ========")
	var definition: CombatantDefinition = CombatantDatabase.combatants["prometheus"]
	# The numbers themselves come from the level now (see level_test_driver),
	# so all the database carries is which pair they belong to.
	ok(definition.main_stat == Stats.Type.INTELLECT, "prometheus leads on Intellect",
		Stats.stat_name(definition.main_stat))
	var table = Stats.stats_for_level(1, definition.main_stat, definition.secondary_stat)
	ok(table.size() == 5, "five attributes come out of a level", "%d" % table.size())
	ok("physical" in table, "keyed as Stats.KEYS names them", "%s" % [table.keys()])
	log_line("")

	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_01_ambush.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	combat.finish_deployment()
	await get_tree().process_frame

	var hero = combat.combatants[0]
	var foe = null
	for comb in combat.combatants:
		if comb.side != hero.side:
			foe = comb
			break

	log_line("======== stats reach the combatant ========")
	ok(hero.has("stats"), "combatants carry stats")
	ok(combat.stat_of(hero, Stats.Type.PHYSICAL) > 0, "physical reads back", "%d" % combat.stat_of(hero, Stats.Type.PHYSICAL))
	ok(combat.stat_of(hero, Stats.Type.DEFENSE) > 0, "defense reads back", "%d" % combat.stat_of(hero, Stats.Type.DEFENSE))
	log_line("")

	log_line("======== damage follows the caster, not the skill ========")
	var melee: SkillDefinition = SkillDatabase.skills["greatsword_attack"]
	hero.stats["physical"] = 10
	foe.stats["defense"] = 10
	var weak = combat.skill_damage(hero, foe, melee)
	hero.stats["physical"] = 90
	var strong = combat.skill_damage(hero, foe, melee)
	ok(strong > weak, "a stronger caster hits harder with the same skill", "%d -> %d" % [weak, strong])
	foe.stats["defense"] = 90
	var defended = combat.skill_damage(hero, foe, melee)
	ok(defended < strong, "a tougher target takes less", "%d -> %d" % [strong, defended])
	var grazed = combat.skill_damage(hero, foe, melee, 0.5)
	ok(grazed < defended, "a graze is half power", "%d vs %d" % [grazed, defended])
	log_line("")

	log_line("======== the contest ignores dice ========")
	var fireball: SkillDefinition = SkillDatabase.skills["fireball"]
	ok(fireball.uses_stat_contest, "fireball contests a stat")
	hero.stats["intellect"] = 60
	foe.stats["physical"] = 30
	ok(combat.wins_contest(hero, foe, fireball), "beats a frailer target", "60 intellect vs 30 physical")
	foe.stats["physical"] = 60
	ok(not combat.wins_contest(hero, foe, fireball), "an equal target shrugs it off", "60 vs 60")
	foe.stats["physical"] = 90
	ok(not combat.wins_contest(hero, foe, fireball), "so does a tougher one", "60 vs 90")
	log_line("")

	log_line("======== spell slots ========")
	var caster = combat.combatants[0]
	caster.spell_slots = [0, 1, 1, 1]
	caster.max_spell_slots = [0, 1, 1, 1]
	# Built here rather than borrowed from the project: what a real spell costs
	# and what level unlocks it are balance, and balancing them should not turn
	# this into a failing test of the slot rules.
	var lvl1 := register_spell("test_spell_1", 1)
	var lvl2 := register_spell("test_spell_2", 2)
	var lvl3 := register_spell("test_spell_3", 3)
	ok(lvl1.spell_slot_level == 1 and lvl2.spell_slot_level == 2 and lvl3.spell_slot_level == 3,
		"the three example spells cost 1, 2 and 3")
	ok(combat.slot_available_for(caster, 1) == 1, "a level 1 spell takes the level 1 slot first",
		"%d" % combat.slot_available_for(caster, 1))
	caster.spell_slots = [0, 0, 1, 1]
	ok(combat.slot_available_for(caster, 1) == 2, "with no level 1 left it steps up to 2",
		"%d" % combat.slot_available_for(caster, 1))
	caster.spell_slots = [0, 1, 0, 0]
	ok(combat.slot_available_for(caster, 2) == 0, "a level 1 slot can never pay for a level 2 spell",
		"%d" % combat.slot_available_for(caster, 2))
	ok(not combat.can_afford_skill(caster, lvl2), "so it cannot be afforded")
	ok(combat.can_afford_skill(caster, lvl1), "the level 1 spell still can")
	ok(combat.can_afford_skill(caster, SkillDatabase.skills["greatsword_attack"]), "a free skill is always affordable")

	caster.spell_slots = [0, 1, 1, 1]
	var spent = combat.spend_slot_for(caster, lvl1)
	ok(spent == 1, "casting a level 1 spends the level 1 slot", "spent %d" % spent)
	ok(caster.spell_slots == [0, 0, 1, 1], "and only that one", "%s" % [caster.spell_slots])
	spent = combat.spend_slot_for(caster, lvl1)
	ok(spent == 2, "the next one steps up to the level 2 slot", "spent %d" % spent)
	ok(caster.spell_slots == [0, 0, 0, 1], "leaving the level 3 alone", "%s" % [caster.spell_slots])
	spent = combat.spend_slot_for(caster, lvl3)
	ok(spent == 3, "a level 3 spell takes the level 3 slot", "spent %d" % spent)
	ok(combat.spend_slot_for(caster, lvl1) == 0, "and now nothing is left to pay with")
	log_line("")

	log_line("======== which panel a skill appears on ========")
	caster.skill_list = ["greatsword_attack", "test_spell_3", "run", "cleanse"]
	caster.spell_slots = [0, 1, 1, 1]
	var main = combat.main_skills_of(caster)
	var spells = combat.spell_skills_of(caster)
	var secondary = combat.secondary_skills_of(caster)
	ok("greatsword_attack" in main, "a free main skill is on the main panel")
	ok(not ("test_spell_3" in main), "a spell is not")
	ok("test_spell_3" in spells, "it is on the spells panel", "%s" % [spells])
	var free_secondary = SkillDatabase.skills["cleanse"].spell_slot_level == 0
	ok(("cleanse" in secondary) == free_secondary,
		"a secondary skill sits on the secondary panel only while it is free",
		"%s" % [secondary])
	ok(("cleanse" in spells) == not free_secondary,
		"and on the spells panel exactly when it costs one", "%s" % [spells])
	log_line("")

	log_line("======== a spell with no slots left is not something left to do ========")
	caster.skill_list = ["test_spell_3"]
	caster.secondary_skills = []
	caster.skill_used_this_turn = false
	caster.secondary_used_this_turn = false
	caster.spell_slots = [0, 0, 0, 1]
	ok(combat.has_action_left(caster), "castable while a slot remains")
	caster.spell_slots = [0, 0, 0, 0]
	ok(not combat.has_action_left(caster), "but not once they are gone - the turn can end")
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
