extends "res://StealthHarness.gd"
## The designer's picks of 2026-11-07, all Alithia's: Sleep, Calm, Suggestion, Detect Magic and Arcane Eye; and
## Mesmerise for Prometheus as well.


func suite() -> String:
	return "newspells"


func time_limit() -> float:
	return 240.0


func run_sections():
	whose_they_are()
	await the_immunity_ladder()
	await sleep_and_calm()
	await suggestion_on_a_map()
	await detect_magic_on_a_map()
	await arcane_eye_on_a_map()


func whose_they_are():
	log_line("======== whose they are ========")
	var alithia: CombatantDefinition = CombatantDatabase.combatants.alithia
	for key in ["sleep", "calm", "suggestion", "detect_magic", "arcane_eye"]:
		ok(alithia.skills.has(key) and SkillDatabase.skills.has(key), "%s is Alithia's" % key)
	ok(SkillDatabase.skills.sleep.spell_slot_level == 2 and SkillDatabase.skills.calm.spell_slot_level == 2, "Sleep and Calm through Hermes")
	ok(SkillDatabase.skills.suggestion.outside_only() and OutsideMoves.iris_gate_for(SkillDatabase.skills.suggestion) == 1, "Suggestion through Iris, with nothing in a fight")
	ok(SkillDatabase.skills.detect_magic.spell_slot_level == 1 and OutsideMoves.iris_gate_for(SkillDatabase.skills.detect_magic) == 0, "Detect Magic through the Gates of the World")
	ok(SkillDatabase.skills.detect_magic.outside_seconds == 300, "for five minutes")
	ok(SkillDatabase.skills.suggestion.outside_seconds == 300, "and Suggestion for five minutes")
	ok(SkillDatabase.skills.arcane_eye.outside_only() and OutsideMoves.iris_gate_for(SkillDatabase.skills.arcane_eye) == 2, "Arcane Eye through Mnemosyne")
	ok(Combat.fighting_skills(["suggestion", "arcane_eye", "calm", "sleep", "detect_magic"]) == ["calm", "sleep", "detect_magic"], "and only those three are for a fight")
	var prometheus: CombatantDefinition = CombatantDatabase.combatants.prometheus
	ok(prometheus.skills.has("mesmerise"), "Mesmerise is Prometheus's to learn too")
	ok(ItemDatabase.item("mesmerise_spellbook") != null and ItemDatabase.item("mesmerise_spellbook").teaches == "mesmerise", "from a book")
	var store: StoreDefinition = load("res://data/stores/travelling_merchant.tres")
	ok(store.stock.has("mesmerise_spellbook"), "at the travelling merchant")
	# The designer's own marks on what they changed by hand, paying through what it says.
	ok(OutsideMoves.iris_gate_for(SkillDatabase.skills.seeming) == 1, "Seeming, marked Iris, is paid through Iris")
	log_line("")


## Alithia's (the designer, 2026-11-07: "Do the ladder of immunities to Alithia according to your new recommendation,
## reduce all the required levels by 8 (fear will be at level 1)").
func the_immunity_ladder():
	log_line("======== Unbowed ========")
	Campaign.reset()
	Campaign.set_party(["enfina", "cyrus", "prometheus", "alithia"], 1)
	Campaign.current_map = "res://maps/crossroads_explore.tscn"
	Campaign.return_to_position = true
	Campaign.current_encounter = load("res://data/encounters/encounter_03_watcher.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(6)
	var combat: Combat = game.get_node("VisualCombat")
	var definition: CombatantDefinition = CombatantDatabase.combatants.alithia
	var ladder := {"fear": 1, "confused": 8, "compelled": 16, "blind": 24, "deafened": 24, "dazed": 33, "choking_ash": 46, "stunned": 56}
	for key in ladder:
		var condition: ConditionDefinition = load("res://data/conditions/%s.tres" % key)
		var at: int = ladder[key]
		var then: Dictionary = combat.create_combatant(definition, "alithia", "", null, at)
		ok(combat.immune_to_condition(then, condition), "%s: immune at level %d" % [key, at])
		if at > 1:
			var before: Dictionary = combat.create_combatant(definition, "alithia", "", null, at - 1)
			ok(not combat.immune_to_condition(before, condition), "  but not at %d" % (at - 1))
		var other: Dictionary = combat.create_combatant(CombatantDatabase.combatants.prometheus, "prometheus", "", null, 64)
		ok(not combat.immune_to_condition(other, condition), "  and nobody else has it")
	var ranks: Array = CharacterSheet.passive_families(definition.passives).filter(func(family): return Combat.passive_family(family[0]) == "Unbowed")
	ok(ranks.size() == 1 and ranks[0].size() == 7, "one passive in seven ranks", "%d" % ranks.size())
	ok(CharacterSheet.shown_rank(ranks[0], 40).name == "Unbowed V", "the sheet shows the highest she has")
	game.queue_free()
	await settle(3)
	log_line("")


func sleep_and_calm():
	log_line("======== Sleep and Calm, in a fight ========")
	Campaign.reset()
	Campaign.set_party(["enfina", "cyrus", "prometheus", "alithia"], 32)
	Campaign.current_map = "res://maps/crossroads_explore.tscn"
	Campaign.return_to_position = true
	Campaign.current_encounter = load("res://data/encounters/encounter_03_watcher.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(6)
	var combat: Combat = game.get_node("VisualCombat")
	var controller = game.get_node("Controller")
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(2)
	var alithia: Dictionary = {}
	for comb in combat.combatants:
		comb.reaction_used = true
		if comb.has("stats"):
			comb.hp = 900
			comb.max_hp = 900
		if comb.get("combatant_key", "") == "alithia":
			alithia = comb
	for gate in alithia.spell_slots.size():
		alithia.spell_slots[gate] = 5
	alithia.stats["mindfulness"] = 10
	var foes: Array = combat.combatants.filter(func(comb): return comb.side == 1 and comb.alive and not comb.has("object"))
	var sleep: SkillDefinition = SkillDatabase.skills.sleep
	# Lowest first, up to a total.
	foes[0].stats["mindfulness"] = 15
	foes[1].stats["mindfulness"] = 3
	foes[2].stats["mindfulness"] = 7
	foes[3].stats["mindfulness"] = 11
	var reached: Array = combat._up_to_a_total(alithia, sleep, foes.slice(0, 4))
	ok(reached == [foes[1], foes[2]], "up to twice her Mindfulness: 3 and 7 of 20, and not the 11 past it", "%s" % [reached.map(func(comb): return comb.stats.mindfulness)])
	foes[3].stats["mindfulness"] = 10
	ok(combat._up_to_a_total(alithia, sleep, foes.slice(0, 4)) == [foes[1], foes[2], foes[3]], "a 10 still fits, in what is left")
	var stunned: ConditionDefinition = load("res://data/conditions/stunned.tres")
	ok(sleep.effects[0].condition == stunned and sleep.effects[0].comes_off_when_hurt and sleep.effects[0].held_by_tether, "they sleep until hurt, or until the tether goes")
	# Calm.
	var fear: ConditionDefinition = load("res://data/conditions/fear.tres")
	var confused: ConditionDefinition = load("res://data/conditions/confused.tres")
	var enfina: Dictionary = {}
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == "enfina":
			enfina = comb
	combat.put_condition(enfina, fear, 5, "test", true, -1)
	combat.put_condition(enfina, confused, 5, "test", true, -1)
	var foe: Dictionary = foes[0]
	foe.status_effects.append({"stat": "strength", "amount": 5, "op": "add", "duration": 5, "source_name": "Rage"})
	combat.current_combatant = combat.combatants.find(alithia)
	alithia.skill_used_this_turn = false
	controller.set_controlled_combatant(alithia)
	await settle()
	# Everybody in reach of the area.
	var at: Vector2i = alithia.position
	for tile in controller.get_reachable_tiles(at, alithia.movement_class, 20, alithia):
		if combat.get_position_distance(tile, at) == 4 and combat.get_combatant_at(tile).is_empty():
			at = tile
			break
	for tile in controller.get_reachable_tiles(at, 0, 3, enfina):
		if combat.get_position_distance(tile, at) == 1 and combat.get_combatant_at(tile).is_empty():
			combat.teleport_to(enfina, tile)
			break
	for tile in controller.get_reachable_tiles(at, 0, 3, foe):
		if combat.get_position_distance(tile, at) == 1 and combat.get_combatant_at(tile).is_empty():
			combat.teleport_to(foe, tile)
			break
	await settle()
	await combat.use_skill("calm", alithia, at, false)
	await settle()
	ok(not combat.has_restriction(enfina, "prevents_approach") and not combat.has_restriction(enfina, "confuses"), "fear and confusion come off her side")
	ok(combat.immune_to_condition(enfina, fear) and combat.immune_to_condition(enfina, confused), "and cannot come back while it holds")
	ok(not foe.status_effects.any(func(entry): return entry.get("source_name", "") == "Rage"), "the other side's boosts come off")
	ok(not combat.immune_to_condition(foe, fear), "and they are not calmed")
	combat.snap_tether(alithia, "test")
	await settle()
	ok(not combat.immune_to_condition(enfina, fear), "the tether gone, nor is she")
	# Detect Magic in a fight.
	combat.zones.append({"id": 77, "name": "hidden", "side": 1, "unseen": true, "tiles": [at], "centre": at, "radius": 0, "colour": Color.WHITE, "turns": 3, "owner_id": -1, "caught": []})
	combat.traps.append({"tile": at + Vector2i.RIGHT, "owner_id": -1, "side": 1, "holds": null, "burst": 0.0, "burst_radius": 0, "skill": null})
	ok(combat.zone_tiles().size() == 0 or not combat.zone_tiles().any(func(zone): return zone.tiles.has(at)), "their unseen ground is unseen")
	ok(not combat.trap_tiles().has(at + Vector2i.RIGHT), "and their traps")
	alithia.skill_used_this_turn = false
	await combat.use_skill("detect_magic", alithia, alithia.position, false)
	await settle()
	ok(combat.party_sees_magic(), "Detect Magic")
	ok(combat.trap_tiles().has(at + Vector2i.RIGHT), "shows their traps")
	combat.zones.clear()
	combat.traps.clear()
	game.queue_free()
	await settle()
	log_line("")


func suggestion_on_a_map():
	log_line("======== Suggestion ========")
	var m = await open_map()
	Campaign.set_party(["alithia"], 14)
	await settle()
	var guard := add_guard(m, "Guard", m.post + Vector2i.RIGHT * 5, 180.0)
	var watch = await watch_it(m, m.post)
	var scene = m.scene
	var iris: int = Campaign.outside_gates_left("alithia")[1]
	ok(OutsideMoves.use_of(SkillDatabase.skills.suggestion) == OutsideMoves.Use.SUGGEST, "a thing of its own out here")
	ok(OutsideMoves.refusal(scene, "alithia", "suggestion") == "", "she can cast it", OutsideMoves.refusal(scene, "alithia", "suggestion"))
	ok(OutsideMoves.use(scene, "alithia", "suggestion"), "she does")
	ok(guard.mood == Guard.Mood.REPORTING, "he goes off", "%d" % guard.mood)
	ok(Campaign.outside_gates_left("alithia")[1] == iris - 1, "through Iris")
	ok(watch.spotted_by == null, "and nobody the wiser")
	await close_map(m)
	log_line("")


func detect_magic_on_a_map():
	log_line("======== Detect Magic ========")
	var m = await open_map()
	Campaign.set_party(["alithia"], 14)
	await settle()
	var sensor := add_guard(m, "Sensor", m.post + Vector2i.RIGHT * 9, 180.0)
	sensor.kind = Guard.Kind.SENSOR
	var watch = await watch_it(m, m.post)
	watch.setup.guards_seen_only_in_sight = true
	var scene = m.scene
	sensor.global_position = at(m, m.post + Vector2i.RIGHT * 40)
	ok(not watch.guard_shown(sensor), "a sensor out of sight is not on show")
	ok(OutsideMoves.use(scene, "alithia", "detect_magic"), "she casts it", OutsideMoves.refusal(scene, "alithia", "detect_magic"))
	ok(is_equal_approx(watch.detect_magic_left, 300.0), "for five minutes", "%.0f" % watch.detect_magic_left)
	ok(watch.guard_shown(sensor), "now it is")
	var state: Dictionary = watch.net_state()
	ok(state.has("detect"), "and the other machine is told")
	watch.detect_magic_left = 0.0
	ok(not watch.guard_shown(sensor), "and when it is over it is not")
	await close_map(m)
	log_line("")


func arcane_eye_on_a_map():
	log_line("======== Arcane Eye ========")
	var m = await open_map()
	Campaign.set_party(["alithia"], 28)
	await settle()
	# Well off from the party, who a nose would catch for itself.
	var there := find_tile(m, func(tile): return gap(tile, m.post) >= 10.0 and standable(m, tile) and standable(m, tile + Vector2i.RIGHT))
	var dog := add_guard(m, "Nose", there, 180.0)
	dog.kind = Guard.Kind.DOG
	var sensor := add_guard(m, "Sensor", there + Vector2i.RIGHT, 180.0)
	sensor.kind = Guard.Kind.SENSOR
	var watch = await watch_it(m, m.post)
	var scene = m.scene
	var mnemosyne: int = Campaign.outside_gates_left("alithia")[2]
	ok(mnemosyne > 0, "she has the Gates of Mnemosyne", "%d" % mnemosyne)
	ok(OutsideMoves.use(scene, "alithia", "arcane_eye"), "she casts it", OutsideMoves.refusal(scene, "alithia", "arcane_eye"))
	var keeper = scene.familiar_keeper
	ok(keeper.familiar != null and keeper.familiar.form.nothing_notices, "out it goes")
	ok(Campaign.outside_gates_left("alithia")[2] == mnemosyne - 1, "through Mnemosyne")
	ok(OutsideMoves.refusal(scene, "alithia", "arcane_eye") == "A familiar is out already", "one at a time")
	keeper.familiar.global_position = dog.global_position
	await settle(6)
	await wait(1.0)
	ok(keeper.familiar != null, "right under a nose, and beside a sensor, it is still there")
	ok(watch.familiar_doubt.is_empty(), "and nothing notices it", "%s" % [watch.familiar_doubt.size()])
	# The spell that calls a familiar is not this one, whoever casts it.
	ok(FamiliarKeeper.spell_among(["alithia"]).get("skill", "") == "find_familiar", "Find Familiar is still what calls a familiar")
	scene.dismiss_familiar()
	await close_map(m)
	log_line("")
