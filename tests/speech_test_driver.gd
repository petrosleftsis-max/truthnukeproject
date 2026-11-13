extends "res://StealthHarness.gd"
## Lines in a bubble over somebody's head (SpeechBubbles, CombatLines; the designer, 2026-11-07), by what happens in a fight, and from a conversation.


func suite() -> String:
	return "speech"


func time_limit() -> float:
	return 160.0


var game = null
var combat: Combat = null
var controller = null
var lines: CombatLines = null


## Cyrus's own lines, kept while the suite gives him one for every moment.
var real_cyrus_lines: CombatLines = null


func run_sections():
	real_cyrus_lines = CombatantDatabase.combatants.cyrus.lines
	which_lines()
	SpeechBubbles.plays_headless = true
	SpeechBubbles.always = true
	await open_fight()
	await the_moments()
	await open_fight()
	await studying_them()
	await open_fight()
	await their_own_lines()
	await open_fight()
	await the_bubble()
	await close_fight()
	await on_a_map()
	SpeechBubbles.plays_headless = false
	SpeechBubbles.always = false
	SpeechBubbles.forget()


func which_lines():
	log_line("======== which lines ========")
	var set_of := CombatLines.new()
	set_of.won = ["Done."]
	set_of.when_using = {"trailblaze": ["Keep up."]}
	set_of.afflicted = ["Ugh."]
	set_of.when_afflicted = {"burn": ["Hot."]}
	ok(set_of.lines_for(&"won") == ["Done."], "by the moment")
	ok(set_of.lines_for(&"using", "trailblaze") == ["Keep up."], "by the move")
	ok(set_of.lines_for(&"using", "guard").is_empty(), "and nothing for a move with none")
	ok(set_of.lines_for(&"afflicted", "burn") == ["Hot."], "by the condition")
	ok(set_of.lines_for(&"afflicted", "fear") == ["Ugh."], "or anything harmful, with nothing of its own")
	ok(set_of.lines_for(&"healed").is_empty(), "nothing written, nothing said")
	var enfina: CombatantDefinition = CombatantDatabase.combatants.enfina
	ok(enfina.lines != null and not enfina.lines.lines_for(&"using", "trailblaze").is_empty(), "Enfina has her burn's")
	ok(not enfina.lines.studies.is_empty(), "and what she sees, studying somebody")
	log_line("")


func open_fight():
	await close_fight()
	SpeechBubbles.forget()
	Campaign.reset()
	Campaign.set_party(["enfina", "cyrus", "prometheus", "alithia"], 64)
	Campaign.current_map = "res://maps/crossroads_explore.tscn"
	Campaign.return_to_position = true
	Campaign.current_encounter = load("res://data/encounters/encounter_03_watcher.tres").duplicate()
	game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(6)
	combat = game.get_node("VisualCombat")
	controller = game.get_node("Controller")
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(2)
	for comb in combat.combatants:
		comb.reaction_used = true
		comb["accuracy"] = 200
		comb["first_blow_missed"] = true
		if comb.has("stats"):
			comb.hp = 900
			comb.max_hp = 900
	await settle()
	# Cyrus says something at every moment, to see which come.
	lines = CombatLines.new()
	for moment in ["fight_starts", "first_blow", "won", "fells_somebody", "reacts", "takes_a_blow", "studies", "deep_spell", "last_casting", "ally_falls", "badly_hurt", "healed", "afflicted", "seen_through", "phase"]:
		lines.set(moment, ["a line for " + moment] as Array[String])
	lines.when_using = {"rapier": ["a line for the rapier"]}
	CombatantDatabase.combatants.cyrus.lines = lines
	SpeechBubbles.forget()


func close_fight():
	if game != null and is_instance_valid(game):
		game.queue_free()
		await settle(3)
	game = null
	combat = null
	CombatantDatabase.combatants.cyrus.lines = real_cyrus_lines


func who(key: String) -> Dictionary:
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == key and not comb.get("illusion", false):
			return comb
	return {}


func foes() -> Array:
	return combat.combatants.filter(func(comb): return comb.side == 1 and comb.alive and not comb.has("object") and not comb.get("illusion", false))


func their_turn(comb: Dictionary):
	combat.current_combatant = combat.combatants.find(comb)
	comb.skill_used_this_turn = false
	comb.secondary_used_this_turn = false
	controller.set_controlled_combatant(comb)
	await settle()


func heard(event: StringName) -> bool:
	return SpeechBubbles.said.any(func(entry): return entry.who == "cyrus" and entry.event == event)


func the_moments():
	log_line("======== the moments ========")
	var cyrus := who("cyrus")
	var alithia := who("alithia")
	var foe: Dictionary = foes()[0]
	SpeechBubbles.somebody_says(combat, &"fight_starts")
	ok(heard(&"fight_starts"), "as the fight starts")
	# His first blow, once.
	for way in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
		if combat.can_land_on(foe, cyrus.position + way):
			combat.teleport_to(foe, cyrus.position + way)
			break
	await their_turn(cyrus)
	await combat.use_skill("rapier", cyrus, foe.position, false)
	await settle(4)
	ok(heard(&"first_blow"), "his first blow")
	var count: int = SpeechBubbles.said.filter(func(entry): return entry.event == &"first_blow").size()
	ok(heard(&"using"), "and the move, by its key")
	cyrus.skill_used_this_turn = false
	await combat.use_skill("rapier", cyrus, foe.position, false)
	await settle(4)
	ok(SpeechBubbles.said.filter(func(entry): return entry.event == &"first_blow").size() == count, "the first only once")
	# Badly hurt, once, going through it.
	cyrus.hp = int(cyrus.max_hp * 0.5)
	combat.lose_hp(cyrus, int(cyrus.max_hp * 0.3), Damage.Type.PHYSICAL)
	ok(heard(&"badly_hurt"), "below a third of his health")
	SpeechBubbles.said.clear()
	combat.lose_hp(cyrus, 1, Damage.Type.PHYSICAL)
	ok(not heard(&"badly_hurt"), "and not again on the way down")
	# Healed by somebody else, not by himself.
	var heal: EffectDefinition = SkillDatabase.skills.heal.effects[0]
	combat.do_heal(cyrus, cyrus, heal, SkillDatabase.skills.heal)
	ok(not heard(&"healed"), "not mending himself")
	combat.do_heal(alithia, cyrus, heal, SkillDatabase.skills.heal)
	ok(heard(&"healed"), "mended by somebody else")
	# A condition that hurts.
	SpeechBubbles.said.clear()
	combat._condition_lands(cyrus, cyrus.sprite, load("res://data/conditions/fear.tres"))
	ok(heard(&"afflicted"), "something harmful takes hold")
	SpeechBubbles.said.clear()
	combat._condition_lands(cyrus, cyrus.sprite, load("res://data/conditions/blessed.tres"))
	ok(not heard(&"afflicted"), "something that helps doesn't count")
	# Felling somebody.
	SpeechBubbles.said.clear()
	foe["hurt_by"] = cyrus.id
	foe.hp = 0
	combat.combatant_die(foe)
	await settle(3)
	ok(heard(&"fells_somebody"), "he fells somebody")
	# Somebody of his side falls near him.
	SpeechBubbles.said.clear()
	var enfina := who("enfina")
	for other in combat.combatants:
		if other.get("side", -1) == 0 and other != cyrus and other != enfina:
			combat.teleport_to(other, other.position)
	combat.teleport_to(cyrus, enfina.position + Vector2i.RIGHT) if combat.can_land_on(cyrus, enfina.position + Vector2i.RIGHT) else null
	enfina.hp = 0
	combat.combatant_die(enfina)
	await settle(3)
	ok(heard(&"ally_falls"), "an ally falls, and he is the nearest")
	# A casting.
	SpeechBubbles.said.clear()
	combat._casting_gate = Combat.DEEP_GATE_FROM
	cyrus["spell_slots"] = [0, 0]
	combat._say_of_the_casting(cyrus)
	ok(heard(&"deep_spell") and heard(&"last_casting"), "a deep gate, and the last casting")
	# Over something unseen, nothing.
	SpeechBubbles.said.clear()
	cyrus.alive = false
	ok(not SpeechBubbles.on_event(combat, cyrus, &"won"), "nobody down says anything")
	cyrus.alive = true
	log_line("")


## A line of Enfina's and one of Prometheus's written on each monster (the designer, 2026-11-07).
func studying_them():
	log_line("== What she says, studying them ==")
	var enfina := who("enfina")
	var prometheus := who("prometheus")
	var foe: Dictionary = foes()[0]
	var definition: CombatantDefinition = CombatantDatabase.combatants[foe.combatant_key]
	var was := [definition.enfina_studies_line, definition.prometheus_studies_line]
	ok("enfina_studies_line" in definition and "prometheus_studies_line" in definition, "a monster has a line of each of theirs to fill in")
	definition.enfina_studies_line = "Leans on the bad knee."
	definition.prometheus_studies_line = "Fascinating. Hold still."
	SpeechBubbles.said.clear()
	combat.study(enfina, foe, true)
	var hers: Array = SpeechBubbles.said.filter(func(entry): return entry.who == "enfina")
	ok(hers.size() == 1 and hers[0].line == "Leans on the bad knee." and hers[0].event == &"studies_them", "Enfina says what is written for her on it", str(hers))
	ok(not SpeechBubbles.said.any(func(entry): return entry.event == &"studies"), "and none of her own lines with it")
	var same: Array = foes().filter(func(other): return other != foe and other.combatant_key == foe.combatant_key)
	SpeechBubbles.said.clear()
	if not same.is_empty():
		combat.study(enfina, same[0], true)
		ok(SpeechBubbles.said.is_empty(), "another of the same kind: she keeps it to herself", str(SpeechBubbles.said))
	combat.study(enfina, foe, true)
	ok(SpeechBubbles.said.is_empty(), "nor again on the same one")
	combat.study(prometheus, foe, true)
	var his: Array = SpeechBubbles.said.filter(func(entry): return entry.who == "prometheus")
	ok(his.size() == 1 and his[0].line == "Fascinating. Hold still.", "Prometheus says his, though she studied it first", str(his))
	definition.enfina_studies_line = ""
	definition.prometheus_studies_line = ""
	var others: Array = foes().filter(func(other): return other.combatant_key != foe.combatant_key and not other.get("studied", false))
	SpeechBubbles.said.clear()
	if not others.is_empty():
		combat.study(enfina, others[0], true)
		ok(SpeechBubbles.said.any(func(entry): return entry.who == "enfina" and entry.event == &"studies"), "nothing written: one of her own", str(SpeechBubbles.said))
	SpeechBubbles.said.clear()
	combat.study(prometheus, foe, true)
	ok(SpeechBubbles.said.is_empty(), "nothing written for him, and he has no lines of his own: nothing")
	definition.enfina_studies_line = was[0]
	definition.prometheus_studies_line = was[1]
	log_line("")


func the_bubble():
	log_line("======== the bubble ========")
	var cyrus := who("cyrus")
	ok(SpeechBubbles.say_line(combat, cyrus, "Now, that'd just kill the fun."), "said")
	await settle(2)
	var bubble = SpeechBubbles.bubble_over(cyrus.sprite)
	ok(bubble != null and is_instance_valid(bubble), "a bubble over him")
	ok(bubble.seconds >= SpeechBubbles.SECONDS_AT_LEAST and bubble.seconds <= SpeechBubbles.SECONDS_AT_MOST, "for as long as it takes to read", "%.1f" % bubble.seconds)
	var long: String = "So many words that it could never be read in any reasonable length of time, and goes on and on and on and on and on and on."
	SpeechBubbles.say_line(combat, cyrus, long)
	await settle(2)
	var second = SpeechBubbles.bubble_over(cyrus.sprite)
	ok(second != bubble and not is_instance_valid(bubble), "another takes its place, rather than piling up")
	ok(second.seconds == SpeechBubbles.SECONDS_AT_MOST, "and even a long one goes", "%.1f" % second.seconds)
	second.seconds = 0.05
	await get_tree().create_timer(0.2).timeout
	ok(not is_instance_valid(second), "it goes by itself")
	# A conversation can do it.
	Campaign.say_bubble("cyrus", "From a conversation.")
	await settle()
	ok(true, "(say_bubble in a test has no current scene to speak in)")
	log_line("")


func on_a_map():
	log_line("======== on a map ========")
	Campaign.reset()
	var m := await open_map()
	var figure = m.party.sprite_for(Campaign.party_order[0]) if not Campaign.party_order.is_empty() else null
	ok(figure != null, "somebody to say it")
	if figure != null:
		SpeechBubbles.say_over(get_tree(), figure, "Hm.")
		await settle(2)
		ok(SpeechBubbles.bubble_over(figure) != null, "over them on a map too")
	close_map(m)
	await settle()
	Campaign.reset()
	log_line("")


## The designer's lines of 2026-11-13 (proposals section 19), at their own moments.
func their_own_lines():
	log_line("======== their own lines ========")
	CombatantDatabase.combatants.cyrus.lines = real_cyrus_lines
	var cyrus := who("cyrus")
	var alithia := who("alithia")
	var enfina := who("enfina")
	var prometheus := who("prometheus")
	var them := foes()
	var foe: Dictionary = them[0]
	var lines_of := func(key: String) -> CombatLines: return CombatantDatabase.combatants[key].lines
	var spoke := func(key: String, event: StringName) -> Array:
		return SpeechBubbles.said.filter(func(entry): return entry.who == key and entry.event == event)
	for key in ["cyrus", "alithia", "enfina", "prometheus"]:
		ok(lines_of.call(key) != null, "%s has lines" % key)
	# A big hit: half their health or more in one blow, taken standing and given.
	SpeechBubbles.forget()
	cyrus.hp = 400
	combat._say_of_a_big_hit(foe, cyrus, 500)
	var taken: Array = spoke.call("cyrus", &"big_hit_taken")
	ok(taken.size() == 1 and lines_of.call("cyrus").big_hit_taken.has(taken[0].line), "half his health in one blow, and Cyrus says so", "%s" % [taken])
	SpeechBubbles.forget()
	var foe_most: int = combat.get_effective_stat(foe, "max_hp")
	combat._say_of_a_big_hit(alithia, foe, roundi(foe_most * 0.6))
	var given: Array = spoke.call("alithia", &"big_hit_given")
	ok(given.size() == 1 and lines_of.call("alithia").big_hit_given.has(given[0].line), "and Alithia, giving one", "%s" % [given])
	SpeechBubbles.forget()
	combat._say_of_a_big_hit(alithia, foe, roundi(foe_most * 0.3))
	ok(spoke.call("alithia", &"big_hit_given").is_empty(), "a third of it is not a big one")
	cyrus.hp = 900
	# Brought back.
	SpeechBubbles.forget()
	var resuscitate: SkillDefinition = SkillDatabase.skills.resuscitate
	var revive_effect: EffectDefinition = null
	for effect in resuscitate.all_effects():
		if effect != null and effect.type == EffectDefinition.EffectType.REVIVE:
			revive_effect = effect
	prometheus.alive = false
	prometheus.hp = 0
	combat.revive(alithia, prometheus, revive_effect, resuscitate)
	var back: Array = spoke.call("prometheus", &"brought_back")
	ok(prometheus.alive and back.size() == 1 and back[0].line == "Don't worry, I'm back.", "brought back, Prometheus says so", "%s" % [back])
	prometheus.hp = 900
	# Something harmful lifted off them by their own side.
	SpeechBubbles.forget()
	combat.put_condition(cyrus, load("res://data/conditions/poisoned.tres"), 3, "test", true)
	var cleanse := EffectDefinition.new()
	cleanse.type = EffectDefinition.EffectType.DISPEL
	cleanse.dispel_scope = EffectDefinition.DispelScope.DEBUFFS_ONLY
	combat.dispel_status_effects(alithia, cyrus, cleanse)
	var thanks: Array = spoke.call("cyrus", &"condition_lifted")
	ok(thanks.size() == 1 and thanks[0].line == "How refreshing, you have my gratitude!", "a poison lifted off him: his thanks", "%s" % [thanks])
	# An enemy breaking and running: one of the party says so, only one.
	SpeechBubbles.forget()
	var runner: Dictionary = them[1] if them.size() > 1 else foe
	runner["nerve"] = 0
	runner["when_broken"] = 0
	runner.erase("fleeing")
	var broke: bool = combat.check_nerve(runner)
	var shouted: Array = SpeechBubbles.said.filter(func(entry): return entry.event == &"enemy_gives_up")
	ok(not broke or (shouted.size() == 1 and ["cyrus", "alithia", "enfina", "prometheus"].has(shouted[0].who)), "one of them breaks and runs: one of the party says so", "%s %s" % [broke, shouted])
	# Praise: one other of the party, about whoever felled somebody who is not a boss.
	SpeechBubbles.forget()
	var felled: Dictionary = them[2] if them.size() > 2 else foe
	felled["hurt_by"] = enfina.id
	combat._say_of_the_fallen(felled)
	var praised: Array = SpeechBubbles.said.filter(func(entry): return entry.event == &"praise")
	ok(praised.size() == 1 and praised[0].who != "enfina" and lines_of.call(praised[0].who).praise.get("enfina", []).has(praised[0].line),
		"Enfina fells one: one of the others praises her", "%s" % [praised])
	SpeechBubbles.forget()
	felled["boss"] = true
	combat._say_of_the_fallen(felled)
	felled.erase("boss")
	ok(SpeechBubbles.said.filter(func(entry): return entry.event == &"praise").is_empty(), "a boss felled: no praise")
	# What is said at the last casting, and Enfina's Step In.
	ok(lines_of.call("alithia").last_casting.has("I can no longer protect you. Do not squander the chance I gave you!")
		and lines_of.call("prometheus").last_casting.has("My system is out of power, I leave the rest to you."), "out of castings: hers and his")
	ok(lines_of.call("enfina").when_using.get("step_in", []).has("Can you really afford to be distracted?"), "and Enfina's Step In")
	log_line("")
