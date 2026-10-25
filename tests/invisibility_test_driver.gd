extends "res://StealthHarness.gd"
## Invisibility: hiding that sight does not end. In a fight it is cast through
## Hermes, on yourself or an ally, while being watched, and lasts until they do
## something to an enemy - or nobody on their side is left in sight. On a
## stealth map it is cast through the Gates of Iris, whose castings are their
## own: the whole party unseen for a while, a casting each.


func suite() -> String:
	return "invisibility"


func run_sections():
	await the_spell()
	await in_a_fight()
	await nobody_left_in_sight()
	await on_a_stealth_map()
	await iris_in_a_dungeon()


func the_spell():
	log_line("======== the spell, and the gate it opens outside a fight ========")
	var spell: SkillDefinition = SkillDatabase.skills.get("invisibility")
	ok(spell != null, "Invisibility is in the database")
	if spell == null:
		return
	ok(spell.spell_slot_level == 2 and spell.outside_gate == 1, "Hermes in a fight, Iris outside one",
		"%d / %d" % [spell.spell_slot_level, spell.outside_gate])
	ok(spell.targets_ally and spell.outside_seconds > 0, "on an ally, and for a while outside a fight", "%ds" % spell.outside_seconds)
	ok("invisibility" in CombatantDatabase.combatants["prometheus"].skills, "Prometheus knows it")
	ok(EffectDefinition.EffectType.BREAK_FREE == 23 and EffectDefinition.EffectType.INVISIBLE == 24,
		"its effect type went on the end, so the ones before it mean what they did")
	ok(Stats.outside_gate_name(1) == "Gates of Iris" and Stats.OUTSIDE_GATES[1].matches == 2,
		"Iris is as strong as Hermes", Stats.outside_gate_name(1))
	ok(Stats.outside_gates_for_level(8)[1] == Stats.gates_for_level(8)[2] and Stats.outside_gates_for_level(14)[1] == Stats.gates_for_level(14)[2] \
		and Stats.outside_gates_for_level(1)[1] == 0, "with as many castings as Hermes has", "%s" % [Stats.outside_gates_for_level(8)])
	Campaign.reset()
	Campaign.set_party(["cyrus", "prometheus"], 7)
	ok(Campaign.outside_spells("prometheus").is_empty() and Campaign.outside_gates_most("prometheus")[1] == 0,
		"before level 8 Iris isn't open, so Invisibility isn't offered outside a fight", "%s" % [Campaign.outside_spells("prometheus")])
	Campaign.reset()
	Campaign.set_party(["cyrus", "prometheus"], 8)
	ok(Campaign.outside_spells("prometheus") == ["invisibility"] and Campaign.outside_spells("cyrus").is_empty(),
		"only somebody who knows an Iris spell opens it", "%s" % [Campaign.outside_spells("prometheus")])
	ok(Campaign.outside_gates_most("prometheus")[1] == 2 and Campaign.outside_gates_most("cyrus")[1] == 0,
		"two castings at level 8, and none for Cyrus", "%s / %s" % [Campaign.outside_gates_most("prometheus"), Campaign.outside_gates_most("cyrus")])
	ok(not Campaign.spend_outside_gate("prometheus", 1, 3) and Campaign.outside_gates_left("prometheus")[1] == 2,
		"three can't be spent from two, and nothing is")
	ok(Campaign.spend_outside_gate("prometheus", 1, 2) and Campaign.outside_gates_left("prometheus")[1] == 0,
		"two can")
	ok(Campaign.gates_spent_outside.is_empty(), "and the next fight's own gates are untouched")
	ok("outside_spent" in Campaign.SAVED, "what is spent is saved with the run")
	log_line("")


## The full party against the sappers, with an enemy beside whoever is tested.
func open_fight() -> Node:
	Campaign.reset()
	# Spent before the fight: a fight brings Iris back, as it does its own gates.
	Campaign.outside_spent = {"prometheus": [0, 2]}
	Campaign.current_encounter = load("res://data/encounters/encounter_02_sappers.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(8)
	var combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(1)
	return game


func who(combat, key: String) -> Dictionary:
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == key and comb.alive:
			return comb
	return {}


## A free tile beside `comb` anybody could stand on.
func beside(combat, comb: Dictionary) -> Vector2i:
	for step in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP, Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
		var tile: Vector2i = comb.position + step
		if not combat.controller.is_tile_blocking(tile, 0) and combat.get_combatant_at(tile).is_empty():
			return tile
	return comb.position


func put(combat, comb: Dictionary, tile: Vector2i):
	var from: Vector2i = comb.position
	comb.position = tile
	combat.controller.reposition_combatant(from, tile)


func in_a_fight():
	var game = await open_fight()
	var combat = game.get_node("VisualCombat")
	log_line("======== a fight brings Iris back ========")
	ok(Campaign.outside_spent.is_empty(), "what was spent outside is all there again", "%s" % [Campaign.outside_spent])
	log_line("")

	var prometheus = who(combat, "prometheus")
	var alithia = who(combat, "alithia")
	var cyrus = who(combat, "cyrus")
	var foe := {}
	for comb in combat.combatants:
		if comb.alive and comb.side == 1 and not comb.has("object") and foe.is_empty():
			foe = comb
	ok(not prometheus.is_empty() and not alithia.is_empty() and not foe.is_empty(), "a caster, an ally and an enemy")
	prometheus.spell_slots = [0, 3, 2, 1]
	put(combat, alithia, beside(combat, prometheus))
	put(combat, foe, beside(combat, alithia))
	ok(combat.is_seen_by_opponents(alithia), "Alithia is in plain view of %s" % foe.name)

	log_line("======== cast on an ally, while she is watched ========")
	ok(combat.refusal_for(prometheus, SkillDatabase.skills["invisibility"], alithia.position) == "", "nothing refuses it",
		combat.refusal_for(prometheus, SkillDatabase.skills["invisibility"], alithia.position))
	prometheus.skill_used_this_turn = false
	await combat.use_skill("invisibility", prometheus, alithia.position, false)
	await settle()
	ok(combat.is_invisible(alithia) and combat.is_hidden(alithia), "she fades from sight")
	ok(prometheus.spell_slots[2] == 1, "through Hermes", "%s" % [prometheus.spell_slots])
	ok(combat.reveal_anyone_now_seen().is_empty() and combat.is_invisible(alithia),
		"%s looks right at her, and finds nothing" % foe.name)
	if alithia.get("sprite") != null and is_instance_valid(alithia.sprite):
		ok(is_equal_approx(alithia.sprite.hidden_alpha, combat.HIDDEN_ALLY_ALPHA), "drawn faintly, as a hidden ally is")
	var attack: SkillDefinition = null
	for key in foe.skill_list:
		var skill: SkillDefinition = SkillDatabase.skills.get(key)
		if skill != null and skill.deals_damage and skill.max_range >= 1:
			attack = skill
			break
	if attack != null:
		ok(not combat.targets_if_aimed(foe, attack, alithia.position).has(alithia),
			"%s can't aim %s at her" % [foe.name, attack.name])
	var sought = combat.find_nearest_enemy_of(foe)
	ok(sought.is_empty() or not is_same(sought, alithia), "and nobody goes looking for her")
	log_line("")

	log_line("======== what does not end it ========")
	var hit := EffectDefinition.new()
	hit.type = EffectDefinition.EffectType.DAMAGE
	hit.min_amount = 1
	hit.max_amount = 1
	var hp_was: int = alithia.hp
	combat.apply_effect(foe, alithia, hit)
	ok(alithia.hp < hp_was and combat.is_invisible(alithia), "caught in a blow, she is hurt but still unseen")
	var mend := EffectDefinition.new()
	mend.type = EffectDefinition.EffectType.HEAL
	mend.min_amount = 1
	mend.max_amount = 1
	combat.apply_effect(alithia, cyrus, mend)
	ok(combat.is_invisible(alithia), "mending a friend")
	var look := EffectDefinition.new()
	look.type = EffectDefinition.EffectType.REVEAL
	combat.apply_effect(alithia, foe, look)
	ok(combat.is_invisible(alithia), "looking an enemy over (Study)")
	# Study opens the character sheet, which holds the game: let it go.
	MenuPause.clear(get_tree())
	ok(combat.refusal_for(prometheus, SkillDatabase.skills["invisibility"], alithia.position) != "",
		"and casting it on her again is refused, since she is already",
		combat.refusal_for(prometheus, SkillDatabase.skills["invisibility"], alithia.position))
	log_line("")

	log_line("======== doing something to an enemy ends it ========")
	combat.apply_effect(alithia, foe, hit)
	ok(not combat.is_invisible(alithia) and not combat.is_hidden(alithia), "she strikes, and can be seen again")
	ok(not alithia.has("invisible"), "nothing left of it on her")
	log_line("")
	game.queue_free()
	await settle()


func nobody_left_in_sight():
	var game = await open_fight()
	var combat = game.get_node("VisualCombat")
	var prometheus = who(combat, "prometheus")
	prometheus.spell_slots = [0, 3, 3, 1]
	var party := []
	for comb in combat.combatants:
		if comb.alive and comb.side == 0:
			party.append(comb)
	var others: Array = party.filter(func(comb): return comb != prometheus)
	log_line("======== the last of a side in sight can't go ========")
	for comb in others:
		combat.make_invisible(comb)
	ok(others.all(func(comb): return combat.is_invisible(comb)), "everybody but Prometheus is invisible", "%d of them" % others.size())
	var refusal: String = combat.refusal_for(prometheus, SkillDatabase.skills["invisibility"], prometheus.position)
	ok(refusal.contains("last of their side in sight"), "so he can't make himself invisible too", refusal)
	prometheus.skill_used_this_turn = false
	await combat.use_skill("invisibility", prometheus, prometheus.position, false)
	await settle()
	ok(not combat.is_invisible(prometheus) and prometheus.spell_slots[2] == 3, "refused, and nothing spent", "%s" % [prometheus.spell_slots])
	log_line("")

	log_line("======== nobody left in sight: everybody is revealed ========")
	# Out of sight some other way - Stealth, say - he leaves nobody in it.
	combat.set_hidden(prometheus, true)
	var revealed: Array = combat.reveal_anyone_now_seen()
	ok(party.all(func(comb): return not combat.is_hidden(comb)), "every one of them can be seen again",
		"%d revealed" % revealed.size())
	ok(revealed.size() == party.size(), "all at once", "%d of %d" % [revealed.size(), party.size()])
	log_line("")

	log_line("======== one invisible, the rest in sight: it holds ========")
	var alithia = who(combat, "alithia")
	combat.make_invisible(alithia)
	ok(combat.reveal_anyone_now_seen().is_empty() and combat.is_invisible(alithia), "she stays invisible")
	for comb in party:
		if comb != alithia:
			combat.combatant_die(comb)
	ok(not combat.is_invisible(alithia) and not combat.is_hidden(alithia),
		"and the last of the party standing is invisible no longer")
	log_line("")
	game.queue_free()
	await settle()


func on_a_stealth_map():
	var m = await open_map()
	var post: Vector2i = m.post
	var sentry = add_guard(m, "Sentry", post, 0.0)
	var in_view: Vector2i = post + Vector2i.RIGHT * 2
	var watch = await watch_it(m, out_of_sight_of(m, row(post)))
	var bar: StealthBar = watch._bar
	log_line("======== nobody here knows how ========")
	ok(watch.invisibility_spell().is_empty() and not bar._invisible.visible, "Cyrus alone: no spell, no button")
	ok(not watch.go_invisible() and not watch.anyone_unseen(), "and nothing happens")
	log_line("")

	log_line("======== Prometheus with him, at level 8, one casting left ========")
	Campaign.add_member("prometheus")
	Campaign.reach_level(8, true)
	# Hermes opens at 8 with two; one already spent leaves one.
	Campaign.spend_outside_gate("prometheus", 1, 1)
	await settle(4)
	watch = m.scene.stealth
	bar = watch._bar
	ok(watch.invisibility_spell().get("caster", "") == "prometheus", "Prometheus would cast it")
	ok(watch.invisibility_cost() == 2, "the two of them would cost a casting each", "%d" % watch.invisibility_cost())
	ok(watch.invisibility_refusal().contains("needs 2"), "and with one, he can't hide both", watch.invisibility_refusal())
	ok(watch.invisibility_refusal(["cyrus"]) == "", "but he can hide one of them")
	await settle(2)
	ok(bar._invisible.visible and not bar._invisible.disabled, "the bar offers it", bar._invisible.text)
	log_line("")

	log_line("======== G: choosing who ========")
	press(bar, KEY_G)
	await settle(2)
	var picker = bar._picker
	ok(is_instance_valid(picker) and get_tree().paused, "G opens the choice, and the game holds while it is open")
	if not is_instance_valid(picker):
		await close_map(m)
		return
	ok(picker.toggles.has("cyrus") and picker.toggles.has("prometheus") and picker.chosen().size() == 2,
		"both of them, lit to begin with", "%s" % [picker.chosen()])
	ok(picker._cast.disabled and picker._cost.text.contains("needs 2"), "too dear for one casting", picker._cost.text)
	picker.toggles["prometheus"].button_pressed = false
	ok(picker.chosen() == ["cyrus"] and not picker._cast.disabled, "Cyrus alone is affordable", picker._cost.text)
	ok(picker.cast(), "cast")
	await settle(2)
	ok(not is_instance_valid(bar._picker) or bar._picker.is_queued_for_deletion(), "the choice goes away")
	ok(not get_tree().paused, "and the game carries on")
	ok(watch.unseen("cyrus") and not watch.unseen("prometheus"), "Cyrus is invisible, Prometheus is not")
	var ten_minutes := float(SkillDatabase.skills["invisibility"].outside_seconds)
	ok(ten_minutes == 600.0 and watch.unseen_left("cyrus") > 599.0, "for ten minutes", StealthBar.clock(watch.unseen_left("cyrus")))
	ok(Campaign.outside_gates_left("prometheus")[1] == 0, "the one casting of Iris spent")
	ok(Campaign.gates_spent_outside.is_empty(), "and none of the next fight's gates")
	await settle(2)
	ok(bar._status.text.begins_with("Invisible 10:00") or bar._status.text.begins_with("Invisible 9:"),
		"the bar says so, counting down", bar._status.text)
	log_line("")

	log_line("======== in plain view: only Prometheus is seen ========")
	settle_guard(watch, sentry)
	m.party.teleport(at(m, in_view))
	await settle(2)
	var standing: Array = watch._party_standing()
	var cyrus_there = standing.filter(func(someone): return someone.key == "cyrus")
	var prometheus_there = standing.filter(func(someone): return someone.key == "prometheus")
	ok(not cyrus_there.is_empty() and not watch.can_perceive(sentry, cyrus_there[0]), "%s can't see Cyrus" % sentry.name)
	ok(not prometheus_there.is_empty() and watch.can_perceive(sentry, prometheus_there[0]), "but sees Prometheus beside him")
	m.party.teleport(at(m, m.away))
	settle_guard(watch, sentry)
	log_line("")

	log_line("======== both castings back: both, and nobody sees anything ========")
	Campaign.outside_spent.clear()
	watch._unseen.clear()
	await settle(2)
	ok(watch.go_invisible(["cyrus", "prometheus"]), "both hidden, two castings")
	settle_guard(watch, sentry)
	m.party.teleport(at(m, in_view))
	await wait(0.4)
	ok(watch.suspicion[sentry] == 0.0, "standing right in front of %s, he notices nothing" % sentry.name, "%.2f" % watch.suspicion[sentry])
	# The same post with a nose instead of eyes.
	sentry.kind = Guard.Kind.DOG
	await wait(0.3)
	ok(watch.suspicion[sentry] > 0.0, "but a hound's nose finds them anyway", "%.2f" % watch.suspicion[sentry])
	sentry.kind = Guard.Kind.WATCHMAN
	m.party.teleport(at(m, m.away))
	settle_guard(watch, sentry)
	log_line("")

	log_line("======== it wears off ========")
	watch._unseen["cyrus"] = 0.2
	watch._unseen["prometheus"] = 0.2
	await wait(0.4)
	ok(not watch.anyone_unseen(), "after its time")
	m.party.teleport(at(m, in_view))
	await wait(0.2)
	ok(watch.suspicion[sentry] > 0.0, "and the same spot in front of %s is seen again" % sentry.name, "%.2f" % watch.suspicion[sentry])
	m.party.teleport(at(m, m.away))
	settle_guard(watch, sentry)
	await settle(2)
	settle_guard(watch, sentry)
	log_line("")

	log_line("======== whoever does something to a guard is seen again ========")
	Campaign.outside_spent.clear()
	ok(watch.go_invisible(["cyrus", "prometheus"]), "both invisible again")
	var back_of_him = behind(m, post)
	m.party.teleport(at(m, back_of_him))
	await settle(2)
	settle_guard(watch, sentry)
	ok(watch.take_down(sentry), "a guard taken down, by Cyrus, who leads")
	ok(not watch.unseen("cyrus") and watch.unseen("prometheus"), "Cyrus can be seen again; Prometheus is still invisible")
	log_line("")

	log_line("======== caught like that, the fight starts that way ========")
	var fight: EncounterDefinition = watch.build_fight()
	var by_key := {}
	for spawn in fight.spawns:
		if spawn.side == 0:
			by_key[spawn.combatant_key] = spawn
	ok(by_key.has("prometheus") and by_key.prometheus.invisible and by_key.has("cyrus") and not by_key.cyrus.invisible,
		"Prometheus's place in the fight starts him invisible, Cyrus's doesn't")
	await close_map(m)
	var game = await fight_from(fight)
	var combat = game.get_node("VisualCombat")
	ok(combat.is_invisible(who(combat, "prometheus")) and not combat.is_hidden(who(combat, "cyrus")),
		"and in the fight, so he is")
	game.queue_free()
	await settle()
	for spawn in fight.spawns:
		if spawn.side == 0:
			spawn.invisible = true
	game = await fight_from(fight)
	combat = game.get_node("VisualCombat")
	ok(combat.is_invisible(who(combat, "prometheus")) and not combat.is_hidden(who(combat, "cyrus")),
		"both of them asking: Cyrus, who led, is the one left in sight")
	game.queue_free()
	await settle()
	log_line("")


func fight_from(fight: EncounterDefinition) -> Node:
	Campaign.current_encounter = fight
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(8)
	return game


## In a dungeon, Iris is like its other gates: spent stays spent from fight to
## fight, and a rest's recovery brings it back, at Hermes's price. The demo has
## no recovery of its own since its short rests (2026-10-25), so it is given the
## one it had; Meditate leaves Iris to the long rest (the restcycle suite).
func iris_in_a_dungeon():
	log_line("======== in a dungeon, Iris waits for a rest ========")
	var dungeon: DungeonDefinition = load("res://data/dungeons/dungeon_demo.tres").duplicate()
	dungeon.gate_recovery_for = ["prometheus"]
	dungeon.gate_recoveries = 1
	dungeon.gate_recovery_points = 3
	dungeon.gate_costs = [0, 1, 2, 3]
	Campaign.reset()
	Campaign.dungeon = dungeon
	Campaign.gate_recoveries_left = dungeon.gate_recoveries
	Campaign.set_party(dungeon.party, dungeon.level)
	var most: int = Campaign.outside_gates_most("prometheus")[1]
	ok(most >= 2 and Campaign.spend_outside_gate("prometheus", 1, 2), "two castings of Iris spent", "of %d" % most)
	Campaign.current_encounter = dungeon.stages[0].encounter
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(8)
	ok(Campaign.outside_gates_left("prometheus")[1] == most - 2, "the next fight does not bring them back",
		"%s" % [Campaign.outside_gates_left("prometheus")])
	game.queue_free()
	await settle()
	ok(dungeon.gate_recovery_for.has("prometheus") and Campaign.can_recover_gates("prometheus"), "a rest offers them")
	ok(Campaign.outside_gate_cost(1) == dungeon.gate_cost(2), "at Hermes's price", "%d" % dungeon.gate_cost(2))
	var panel := RestPanel.new()
	add_child(panel)
	await settle(2)
	ok(panel._row_for(1, true) != null, "the rest has a row for Iris")
	panel.change(1, 1, true)
	ok(panel.chosen_outside[1] == 1, "one chosen", "%s" % [panel.chosen_outside])
	ok(panel.recover(), "and recovered")
	ok(Campaign.outside_gates_left("prometheus")[1] == most - 1, "one casting of Iris back",
		"%s" % [Campaign.outside_gates_left("prometheus")])
	panel.queue_free()
	Campaign.reset()
	await settle()
	log_line("")
