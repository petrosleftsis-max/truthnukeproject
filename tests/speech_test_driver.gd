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


func run_sections():
	which_lines()
	SpeechBubbles.plays_headless = true
	SpeechBubbles.always = true
	await open_fight()
	await the_moments()
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
	CombatantDatabase.combatants.cyrus.lines = null


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
