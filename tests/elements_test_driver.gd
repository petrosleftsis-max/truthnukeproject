extends Node
## The three categories of damage, resistances that can be changed, a skill
## that does something to its own caster, and a ranger that stops waiting.

var LOG_PATH := HarnessLog.path_for("elements")
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


func run_test():
	log_line("======== the numbers already in resources have not moved ========")
	# Every skill stores its damage type as an integer. New types go on the end.
	# Pure Energy was removed, which pulled everything after it down a place.
	# Safe only because the types after it were days old and no resource had
	# stored one yet - lightning_bolt.tres, the only thing that dealt Pure
	# Energy, was retyped by hand in the same change.
	var frozen := {
		"PHYSICAL": 0, "FIRE": 1, "WATER": 2, "WIND": 3, "EARTH": 4,
		"POISON": 5, "PSYCHIC": 6,
	}
	ok(not "PURE_ENERGY" in Damage.Type.keys(), "Pure Energy is gone")
	var moved := []
	for name in frozen:
		if Damage.Type[name] != frozen[name]:
			moved.append("%s is now %d, was %d" % [name, Damage.Type[name], frozen[name]])
	ok(moved.is_empty(), "the eight that existed still mean what they meant", "%s" % [moved])
	ok(Damage.TYPE_NAMES.size() == Damage.Type.size(), "every type has a name",
		"%d names for %d types" % [Damage.TYPE_NAMES.size(), Damage.Type.size()])
	ok(Damage.TYPE_COLOURS.size() == Damage.Type.size(), "and a colour",
		"%d colours for %d types" % [Damage.TYPE_COLOURS.size(), Damage.Type.size()])
	log_line("")

	log_line("======== the upgraded elements ========")
	var wanted_upgrades := {
		Damage.Type.FIRE: Damage.Type.PLASMA,
		Damage.Type.WATER: Damage.Type.ICE,
		Damage.Type.WIND: Damage.Type.LIGHTNING,
		Damage.Type.EARTH: Damage.Type.METAL,
		Damage.Type.POISON: Damage.Type.ACID,
	}
	for base in wanted_upgrades:
		var up = wanted_upgrades[base]
		ok(Damage.upgraded_form(base) == up,
			"%s upgrades to %s" % [Damage.type_name(base), Damage.type_name(up)],
			Damage.type_name(Damage.upgraded_form(base)))
		ok(Damage.base_form(up) == base, "  and comes back down to it")
		ok(Damage.is_upgraded(up), "  which counts as an upgraded type")
		ok(Damage.category_of(base) == Damage.Category.BASE, "  off a base one")
	ok(Damage.types_in(Damage.Category.UPGRADED).size() == 5,
		"there are five upgraded types and no more",
		"%s" % [Damage.types_in(Damage.Category.UPGRADED).map(func(t): return Damage.type_name(t))])
	# An upgrade is a rung, not a ladder.
	ok(Damage.upgraded_form(Damage.Type.PLASMA) == Damage.Type.PLASMA,
		"an upgraded type does not upgrade again")
	ok(not Damage.can_upgrade(Damage.Type.PHYSICAL), "and a special type never upgrades")
	log_line("")

	log_line("======== the special ones ========")
	var special = Damage.types_in(Damage.Category.SPECIAL)
	for name in ["Physical", "Psychic", "Idol"]:
		var found := false
		for type in special:
			if Damage.type_name(type) == name:
				found = true
		ok(found, "%s is a special type" % name)
	ok(special.size() == 3, "and there are three of them",
		"%s" % [special.map(func(t): return Damage.type_name(t))])
	# Every type now belongs to exactly one of the three.
	var homeless := []
	for type in Damage.Type.values():
		if Damage.category_of(type) == Damage.Category.UNCATEGORISED:
			homeless.append(Damage.type_name(type))
	ok(homeless.is_empty(), "and every type in the game belongs to a category",
		"%s" % [homeless])
	var bolt: SkillDefinition = SkillDatabase.skills["lightning_bolt"]
	ok(bolt.damage_type == Damage.Type.LIGHTNING,
		"Lightning Bolt deals Lightning, now that there is such a thing",
		Damage.type_name(bolt.damage_type))
	log_line("")

	log_line("======== everything can be resisted ========")
	var definition := CombatantDefinition.new()
	var table = definition.resistance_table()
	var missing := []
	for type in Damage.Type.values():
		if not table.has(type):
			missing.append(Damage.type_name(type))
		elif not (Damage.resistance_key(type)) in definition:
			missing.append("%s has no field" % Damage.type_name(type))
	ok(missing.is_empty(), "every type has a resistance on the definition", "%s" % [missing])
	ok(Damage.resistance_key(Damage.Type.LIGHTNING) == "resist_lightning",
		"and the name of the field follows the name of the type",
		Damage.resistance_key(Damage.Type.LIGHTNING))
	log_line("")

	# The rest needs a battle.
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
		if comb.alive and comb.side == 0 and caster.is_empty():
			caster = comb
		elif comb.alive and comb.side == 1 and victim.is_empty():
			victim = comb

	log_line("======== a resistance can be changed for a while ========")
	var before = combat.resistance_of(victim, Damage.Type.FIRE)
	var harden := EffectDefinition.new()
	harden.type = EffectDefinition.EffectType.RESISTANCE
	harden.damage_type = Damage.Type.FIRE
	harden.modifier_amount = 40
	harden.duration = 2
	combat.apply_effect(caster, victim, harden, null, false)
	await get_tree().process_frame
	ok(combat.resistance_of(victim, Damage.Type.FIRE) == before + 40,
		"raising fire resistance raises it",
		"%d -> %d" % [before, combat.resistance_of(victim, Damage.Type.FIRE)])
	ok(combat.resistance_of(victim, Damage.Type.WATER) == combat.resistance_of(victim, Damage.Type.WATER),
		"  and leaves the other elements alone")
	ok(combat.resistance_of(victim, Damage.Type.PLASMA)
		== victim.get("resistances", {}).get(Damage.Type.PLASMA, 0),
		"  including the upgraded form, which is its own element")
	# It wears off like anything else.
	var turns = 0
	while combat.resistance_of(victim, Damage.Type.FIRE) != before and turns < 10:
		combat.process_status_effects(victim)
		turns += 1
	ok(combat.resistance_of(victim, Damage.Type.FIRE) == before,
		"and it wears off", "after %d turns" % turns)

	# Lowering it is the same thing the other way.
	var soften := EffectDefinition.new()
	soften.type = EffectDefinition.EffectType.RESISTANCE
	soften.damage_type = Damage.Type.FIRE
	soften.modifier_amount = -50
	soften.duration = 3
	combat.apply_effect(caster, victim, soften, null, false)
	await get_tree().process_frame
	ok(combat.resistance_of(victim, Damage.Type.FIRE) == before - 50,
		"lowering it lands too", "%d" % combat.resistance_of(victim, Damage.Type.FIRE))
	# And a cleanse lifts it, because it is stored like any other timed change.
	var strip := EffectDefinition.new()
	strip.type = EffectDefinition.EffectType.DISPEL
	strip.dispel_scope = EffectDefinition.DispelScope.BOTH
	combat.dispel_status_effects(caster, victim, strip)
	ok(combat.resistance_of(victim, Damage.Type.FIRE) == before,
		"and a cleanse lifts it like any other effect")
	log_line("")

	log_line("======== a skill that hurts them and helps you ========")
	var wound := EffectDefinition.new()
	wound.type = EffectDefinition.EffectType.DAMAGE
	wound.damage_type = Damage.Type.PHYSICAL
	wound.min_amount = 4
	wound.max_amount = 4
	var steady := EffectDefinition.new()
	steady.type = EffectDefinition.EffectType.STAT_MODIFIER
	steady.applies_to_caster = true
	steady.stat = "accuracy"
	steady.modifier_amount = 15
	steady.duration = 2
	var both: SkillDefinition = SkillDatabase.skills["greatsword_attack"].duplicate(true)
	both.deals_damage = false
	both.effects = [wound, steady]
	# It has to land every time, or the test is a coin toss about where the
	# effects went - which is how the first run of this passed and the second
	# one did not.
	both.accuracy = 100
	both.uses_stat_contest = false
	SkillDatabase.skills["_cut_and_steady"] = both

	var victim_hp = victim.hp
	var caster_accuracy = combat.get_effective_stat(caster, "accuracy")
	var victim_accuracy = combat.get_effective_stat(victim, "accuracy")
	caster.position = victim.position + Vector2i(1, 0)
	caster.skill_used_this_turn = false
	await combat.use_skill("_cut_and_steady", caster, victim.position, false)
	for i in 4:
		await get_tree().process_frame
	ok(victim.hp < victim_hp, "the enemy is hurt", "%d -> %d" % [victim_hp, victim.hp])
	ok(combat.get_effective_stat(caster, "accuracy") == caster_accuracy + 15,
		"and the caster is the one who got the buff",
		"%d -> %d" % [caster_accuracy, combat.get_effective_stat(caster, "accuracy")])
	ok(combat.get_effective_stat(victim, "accuracy") == victim_accuracy,
		"rather than whoever it was aimed at")
	var on_caster := 0
	for eff in caster.status_effects:
		if eff.get("stat", "") == "accuracy":
			on_caster += 1
	ok(on_caster == 1, "applied once, not once per person caught", "%d" % on_caster)
	var tip = combat.game_ui.build_skill_tooltip(both, caster)
	ok(tip.contains("(on yourself)"), "and the preview says which half lands on you")
	SkillDatabase.skills.erase("_cut_and_steady")
	log_line("")

	game.queue_free()
	await get_tree().process_frame
	await a_ranger_that_cannot_shoot(
)

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


## On a battle of its own, because the sections above move combatants by writing
## their positions straight onto the dictionaries - which leaves the controller's
## idea of who is standing where behind, and pathfinding reads that.
func a_ranger_that_cannot_shoot():
	log_line("======== a ranger with nothing in reach closes the distance ========")
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

	var ranger = {}
	for comb in combat.combatants:
		if comb.alive and comb.get("ai_function", "") == "ai_ranger":
			ranger = comb
			break
	ok(not ranger.is_empty(), "there is a ranger in this fight",
		"" if ranger.is_empty() else ranger.name)
	ok(combat.has_method("approach_with_remaining_movement"),
		"and something for it to close the distance with")
	if ranger.is_empty():
		game.queue_free()
		return

	var prey = combat.find_nearest_enemy_of(ranger)
	ok(not prey.is_empty(), "and somebody to close on")
	if prey.is_empty():
		game.queue_free()
		return

	var was = combat.get_position_distance(ranger.position, prey.position)
	var skill_key = combat.find_best_single_target_skill(ranger)
	var reach = combat.effective_max_range(ranger, SkillDatabase.skills[skill_key])
	var budget = combat.movement_budget_of(ranger)
	log_line("  (%s is %d tiles from %s, reaches %d, moves %d)"
		% [ranger.name, was, prey.name, reach, budget])
	log_line("  (whether it can shoot from here is beside the point - what is being"
		+ " asked is whether being told to close the distance closes it)")

	# It has to actually be its turn: update_points_weight frees the tile of
	# whoever combat says is acting, and pathfinding from a tile still marked
	# solid finds no route at all.
	for i in combat.combatants.size():
		if is_same(combat.combatants[i], ranger):
			combat.current_combatant = i
	combat.controller.set_controlled_combatant(ranger)
	await combat.approach_with_remaining_movement(ranger, prey)
	for i in 6:
		await get_tree().process_frame
	var now = combat.get_position_distance(ranger.position, prey.position)
	ok(now < was, "so it closes the distance instead of standing there",
		"%d tiles -> %d tiles" % [was, now])
	ok(was - now > 0, "  moving %d tiles of its %d" % [was - now, budget])

	# And it is still picking cover among the tiles that get it equally close.
	var chosen_safety = combat.score_tile_safety(ranger.position)
	var worst := 999.0
	for tile in combat.controller.get_reachable_tiles(ranger.position, ranger.movement_class, budget):
		if combat.get_position_distance(tile, prey.position) == now:
			worst = minf(worst, combat.score_tile_safety(tile))
	ok(chosen_safety >= worst, "and took cover among the tiles that get it equally close",
		"scored %.1f, worst equally-close tile scores %.1f" % [chosen_safety, worst])

	game.queue_free()
	await get_tree().process_frame
	log_line("")
