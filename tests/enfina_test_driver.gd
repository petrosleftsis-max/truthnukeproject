extends "res://StealthHarness.gd"
## Enfina's depth, the designer's picks of 2026-11-07 (docs/proposals_2026-11-07.md section 15; Combat "Enfina"): the fire she pays for,
## the reactions Drills gives her, and a city guard's tricks.


func suite() -> String:
	return "enfina"


func time_limit() -> float:
	return 260.0


var game = null
var combat: Combat = null
var controller = null
var prompt = null
var _answering := false
var _saying_yes := true
var _asked := 0


func run_sections():
	await open_fight()
	the_kit()
	await open_fight()
	await flashover()
	await open_fight()
	await cauterise()
	await open_fight()
	await share_the_fire()
	await open_fight()
	await blazed_path()
	await open_fight()
	await through_the_fire()
	await open_fight()
	await burning_titanfall()
	await open_fight()
	await riposte_and_reads_the_form()
	await open_fight()
	await step_in()
	await open_fight()
	await throw_a_friend()
	await open_fight()
	await anything_is_a_weapon()
	await open_fight()
	await arrest()
	await close_fight()
	await carries_them()


func open_fight():
	await close_fight()
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
	prompt = combat.reaction_prompt
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
	var enfina := who("enfina")
	enfina["level"] = 64
	await settle()


func close_fight():
	if game != null and is_instance_valid(game):
		game.queue_free()
		await settle(3)
	game = null
	combat = null


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


func _keep_answering():
	while _answering and is_inside_tree():
		if prompt != null and is_instance_valid(prompt) and prompt._waiting:
			_asked += 1
			prompt._answer_with(_saying_yes)
		await get_tree().process_frame


func beside(comb: Dictionary, who_moves: Dictionary) -> Vector2i:
	for way in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var tile: Vector2i = comb.position + way
		if combat.can_land_on(who_moves, tile):
			return tile
	return comb.position


## A clear stretch of ground: nobody on it, walkable, somewhere open.
func open_ground(probe: Dictionary, room: int) -> Vector2i:
	var region: Rect2i = controller._astargrid.region
	for y in range(region.position.y + room, region.end.y - room):
		for x in range(region.position.x + room, region.end.x - room):
			var tile := Vector2i(x, y)
			var clear := true
			for near in Combat.get_diamond_tiles(tile, room):
				if not controller.is_on_map(near) or not combat.can_land_on(probe, near):
					clear = false
			if clear:
				return tile
	return Combat.NO_AREA


## Lights her, as Trailblaze does.
func light_her(enfina: Dictionary):
	await their_turn(enfina)
	await combat.use_skill("trailblaze", enfina, enfina.position, false, true)
	await settle()
	enfina.secondary_used_this_turn = false


func the_kit():
	log_line("======== the kit ========")
	var enfina := who("enfina")
	for key in ["flashover", "cauterise", "share_the_fire", "arrest"]:
		ok(enfina.skill_list.has(key), "she has %s" % key)
	var reactions: Array = combat._reactions_open_to(enfina)
	ok(reactions.has("riposte") and reactions.has("step_in"), "Drills gives her reactions")
	ok(not enfina.skill_list.has("riposte"), "that don't sit on her action bar")
	ok(not combat.main_skills_of(enfina).has("flashover") or SkillDatabase.skills.flashover.is_secondary, "Flashover is a secondary")
	var names: Array = enfina.passives.map(func(passive): return passive.name)
	for wanted in ["Blazed Path", "Through the Fire", "Burning Titanfall", "Reads the Form", "Drills I", "Drills II", "Drills III", "Throw a Friend", "Anything Is a Weapon", "Carries Them"]:
		ok(names.has(wanted), "and %s" % wanted)
	ok(SkillDatabase.skills.riposte.required_level == 8 and SkillDatabase.skills.step_in.required_level == 24, "Riposte at 8, Step In at 24")
	log_line("")


func flashover():
	log_line("======== Flashover ========")
	var enfina := who("enfina")
	var foe: Dictionary = foes()[0]
	var spell: SkillDefinition = SkillDatabase.skills.flashover
	await their_turn(enfina)
	ok(combat.refusal_for(enfina, spell, enfina.position) != "", "only while she burns")
	ok(combat.wasted_on(enfina, spell) != "", "and the bar says so")
	await light_her(enfina)
	var turns: int = Combat.burn_turns_of(enfina)
	ok(turns >= 5, "lit, for five turns or more", "%d" % turns)
	ok(is_equal_approx(Combat.modifier_of(enfina, spell), 0.6 + 0.15 * turns), "x0.6, and x0.15 a turn left", "%.2f" % Combat.modifier_of(enfina, spell))
	ok(combat.refusal_for(enfina, spell, enfina.position) == "", "now it can")
	combat.teleport_to(foe, beside(enfina, foe))
	var before: int = foe.hp
	await combat.use_skill("flashover", enfina, enfina.position, false, true)
	await settle(4)
	ok(foe.hp < before, "whoever is beside her is caught", "%d to %d" % [before, foe.hp])
	ok(Combat.burn_turns_of(enfina) == 0, "and the Burn is over")
	ok(enfina.secondary_used_this_turn and not enfina.skill_used_this_turn, "her secondary action")
	log_line("")


func cauterise():
	log_line("======== Cauterise ========")
	var enfina := who("enfina")
	var poisoned: ConditionDefinition = load("res://data/conditions/poisoned.tres")
	await light_her(enfina)
	var turns: int = Combat.burn_turns_of(enfina)
	combat.put_condition(enfina, poisoned, 3, "test", true)
	enfina.hp = 200
	var skill: SkillDefinition = SkillDatabase.skills.cauterise
	ok(combat.heal_amount(enfina, skill) >= 4 + 6 * turns, "4, and 6 for each turn of it", "%d, %d turns" % [combat.heal_amount(enfina, skill), turns])
	await combat.use_skill("cauterise", enfina, enfina.position, false, true)
	await settle(3)
	ok(enfina.hp > 200, "she mends", "%d" % enfina.hp)
	ok(Combat.burn_turns_of(enfina) == 0, "the Burn is over")
	ok(not combat.conditions_of(enfina).has(poisoned), "and the poison off")
	log_line("")


func share_the_fire():
	log_line("======== Share the Fire ========")
	var enfina := who("enfina")
	var cyrus := who("cyrus")
	combat.teleport_to(cyrus, beside(enfina, cyrus))
	await their_turn(enfina)
	var speed: int = combat.get_effective_stat(cyrus, "movement")
	await combat.use_skill("share_the_fire", enfina, cyrus.position, false, true)
	await settle(3)
	ok(combat.get_effective_stat(cyrus, "movement") == speed + 2, "he gets the speed", "%d to %d" % [speed, combat.get_effective_stat(cyrus, "movement")])
	var hers: int = enfina.hp
	var his: int = cyrus.hp
	combat.start_of_turn_effects(cyrus)
	await settle(2)
	ok(cyrus.hp == his, "the fire doesn't touch him", "%d" % cyrus.hp)
	ok(enfina.hp < hers, "it lands on her", "%d to %d" % [hers, enfina.hp])
	log_line("")


func blazed_path():
	log_line("======== Blazed Path ========")
	var enfina := who("enfina")
	var foe: Dictionary = foes()[0]
	var cyrus := who("cyrus")
	var there := open_ground(enfina, 2)
	ok(there != Combat.NO_AREA, "room for it", "%s" % there)
	combat.teleport_to(enfina, there)
	await their_turn(enfina)
	combat.blaze_where_they_walk(enfina, there + Vector2i.RIGHT)
	ok(not combat.zones.any(func(zone): return zone.has("blazed_by")), "not burning, it leaves nothing")
	await light_her(enfina)
	combat.blaze_where_they_walk(enfina, there + Vector2i.RIGHT)
	combat.blaze_where_they_walk(enfina, there + Vector2i(2, 0))
	var trail: Array = combat.zones.filter(func(zone): return zone.has("blazed_by"))
	ok(trail.size() == 1 and trail[0].tiles.size() >= 2, "burning, the tiles she walks stay lit, one trail", "%d" % (trail[0].tiles.size() if not trail.is_empty() else -1))
	ok(combat.light.level_at(there + Vector2i.RIGHT) == Light.Level.BRIGHT or combat.light.base == Light.Level.BRIGHT, "and they do light")
	var before: String = combat.board_fingerprint(enfina)
	combat.blaze_where_they_walk(enfina, there + Vector2i(3, 0))
	ok(combat.board_fingerprint(enfina) != before, "and a walk that leaves a trail can't be taken back")
	ok(combat.blazed_for(cyrus, there + Vector2i.RIGHT), "her side's to walk")
	ok(not combat.blazed_for(foe, there + Vector2i.RIGHT), "and nobody else's")
	ok(combat.hem_cost(cyrus, there + Vector2i.RIGHT) == 1, "with no hemming on them")
	combat.teleport_to(cyrus, there + Vector2i.RIGHT)
	ok(combat.blazed_path_bonus(cyrus) == 1, "a tile further, starting on one")
	await their_turn(cyrus)
	ok(controller.movement == combat.get_effective_stat(cyrus, "movement") + 1, "and it counts", "%d" % controller.movement)
	var burn_path := Combat.BURN_CONDITION
	ok(not combat.conditions_of(foe).any(func(condition): return condition.resource_path == burn_path), "the other side isn't burning yet")
	var foe_hp: int = foe.hp
	combat.zones_under_step(foe, there + Vector2i(2, 0))
	await settle()
	ok(combat.conditions_of(foe).any(func(condition): return condition.resource_path == burn_path), "stepping there, they catch it")
	ok(foe.hp == foe_hp, "and take nothing else for the step", "%d" % foe.hp)
	# Until her next turn.
	combat.current_combatant = combat.combatants.find(enfina)
	combat._zones_at_turn_start(enfina)
	await settle()
	ok(not combat.zones.any(func(zone): return zone.has("blazed_by")), "gone as her next turn starts")
	log_line("")


func through_the_fire():
	log_line("======== Through the Fire ========")
	var enfina := who("enfina")
	var foe: Dictionary = foes()[0]
	var fear: ConditionDefinition = load("res://data/conditions/fear.tres")
	var frozen: ConditionDefinition = load("res://data/conditions/frozen.tres")
	ok(not combat.walks_through_fire(enfina), "not burning, she doesn't")
	ok(not combat.immune_to_condition(enfina, fear), "and can be afraid")
	combat.put_condition(enfina, frozen, 3, "test", true)
	await light_her(enfina)
	ok(combat.walks_through_fire(enfina), "burning, she walks through fire")
	ok(combat.immune_to_condition(enfina, fear), "Fear can't take hold")
	ok(not combat.conditions_of(enfina).has(frozen), "and she thaws at once")
	# Fire on the ground, somebody else's.
	var burner: SkillDefinition = SkillDatabase.skills.burner
	var ground: EffectDefinition = null
	for effect in burner.effects:
		if effect.type == EffectDefinition.EffectType.ZONE:
			ground = effect
	combat.lay_zone(foe, ground, [enfina.position], burner)
	var hers: int = enfina.hp
	combat._zone_strikes(combat.zones.back(), enfina)
	ok(enfina.hp == hers, "fire on the ground does her no harm", "%d" % enfina.hp)
	log_line("")


func burning_titanfall():
	log_line("======== Burning Titanfall ========")
	var enfina := who("enfina")
	var foe: Dictionary = foes()[0]
	var blow: SkillDefinition = SkillDatabase.skills.greatsword_attack
	combat._burning_titanfall(enfina, foe, blow)
	ok(combat.zones.is_empty(), "not burning, nothing")
	await light_her(enfina)
	combat._burning_titanfall(enfina, foe, SkillDatabase.skills.guard)
	ok(combat.zones.is_empty(), "nor from a move that isn't it")
	combat._burning_titanfall(enfina, foe, blow)
	ok(combat.zones.size() == 1 and combat.zones[0].tiles.has(foe.position), "burning, the ground round it burns", "%d zones" % combat.zones.size())
	log_line("")


func riposte_and_reads_the_form():
	log_line("======== Riposte, and Reads the Form ========")
	var enfina := who("enfina")
	var foe: Dictionary = foes()[0]
	combat.teleport_to(foe, beside(enfina, foe))
	enfina.reaction_used = false
	_answering = true
	_saying_yes = true
	_asked = 0
	_keep_answering()
	var foe_hp: int = foe.hp
	await their_turn(foe)
	await combat._react(SkillDefinition.Trigger.STRUCK, foe, "a blow lands", Callable(), func(reactor, _skill, _readied): return is_same(reactor, enfina))
	await settle(4)
	ok(_asked >= 1, "she is asked", "%d" % _asked)
	ok(foe.hp < foe_hp, "and strikes back", "%d to %d" % [foe_hp, foe.hp])
	ok(enfina.reaction_used, "for her reaction")
	# Against somebody she has studied, the first is free.
	foe["studied"] = true
	enfina.reaction_used = false
	enfina.erase("free_reaction_spent")
	foe_hp = foe.hp
	await combat._react(SkillDefinition.Trigger.STRUCK, foe, "a blow lands", Callable(), func(reactor, _skill, _readied): return is_same(reactor, enfina))
	await settle(4)
	ok(foe.hp < foe_hp, "she strikes back at one she has read", "%d" % foe.hp)
	ok(not enfina.reaction_used, "and it costs her nothing")
	foe_hp = foe.hp
	await combat._react(SkillDefinition.Trigger.STRUCK, foe, "a blow lands", Callable(), func(reactor, _skill, _readied): return is_same(reactor, enfina))
	await settle(4)
	ok(enfina.reaction_used and foe.hp < foe_hp, "the second one does")
	_answering = false
	await settle()
	# Drills III.
	var plain: float = combat.progression_damage_bonus(enfina, foe, SkillDatabase.skills.riposte)
	enfina["reacting"] = true
	ok(is_equal_approx(combat.progression_damage_bonus(enfina, foe, SkillDatabase.skills.riposte) - plain, 0.25), "her reactions land a quarter harder")
	enfina.erase("reacting")
	log_line("")


func step_in():
	log_line("======== Step In ========")
	var enfina := who("enfina")
	var cyrus := who("cyrus")
	var foe: Dictionary = foes()[0]
	combat.teleport_to(cyrus, beside(enfina, cyrus))
	combat.teleport_to(foe, beside(cyrus, foe))
	enfina.reaction_used = false
	var reaction: SkillDefinition = SkillDatabase.skills.step_in
	ok(not combat._answers_this_blow(reaction, foe, SkillDatabase.skills.guard), "not for what deals no damage")
	ok(combat._answers_this_blow(reaction, foe, SkillDatabase.skills.greatsword_attack), "for one blow")
	ok(not combat._answers_this_blow(reaction, foe, SkillDatabase.skills.wildfire), "and not for an area")
	_answering = true
	_saying_yes = true
	_asked = 0
	_keep_answering()
	var his: int = cyrus.hp
	var hers: int = enfina.hp
	await their_turn(foe)
	await combat.use_skill("greatsword_attack", foe, cyrus.position, false)
	await settle(5)
	_answering = false
	await settle()
	ok(_asked >= 1, "she is asked", "%d" % _asked)
	ok(cyrus.hp == his, "the blow doesn't reach him", "%d" % cyrus.hp)
	ok(enfina.hp < hers, "it lands on her", "%d to %d" % [hers, enfina.hp])
	ok(enfina.reaction_used, "for her reaction")
	log_line("")


func throw_a_friend():
	log_line("======== Throw a Friend ========")
	var enfina := who("enfina")
	var cyrus := who("cyrus")
	var hurl: SkillDefinition = SkillDatabase.skills.hurl
	var there := open_ground(enfina, 3)
	ok(there != Combat.NO_AREA, "room for it", "%s" % there)
	combat.teleport_to(enfina, there)
	combat.teleport_to(cyrus, beside(enfina, cyrus))
	await their_turn(enfina)
	ok(combat._grip_refusal(enfina, hurl, cyrus) == "", "an ally can be taken hold of")
	controller.set_selected_skill("hurl")
	ok(controller.is_valid_skill_target(cyrus), "and aimed at")
	var places: Array = combat.throw_destinations(enfina, hurl, cyrus)
	ok(not places.is_empty() and places.all(func(tile): return combat.get_position_distance(tile, enfina.position) <= 3), "up to three tiles", "%d" % places.size())
	var far: Vector2i = places[0]
	for tile in places:
		if combat.get_position_distance(tile, enfina.position) > combat.get_position_distance(far, enfina.position):
			far = tile
	var his: int = cyrus.hp
	var his_action: bool = cyrus.get("skill_used_this_turn", false)
	await combat.use_skill("hurl", enfina, cyrus.position, false, false, far)
	await settle(4)
	ok(cyrus.position == far, "he lands where she threw him", "%s" % cyrus.position)
	ok(cyrus.hp == his, "unhurt", "%d" % cyrus.hp)
	ok(cyrus.get("skill_used_this_turn", false) == his_action, "ready to act")
	# Somebody without it can't.
	var prometheus := who("prometheus")
	ok(combat._grip_refusal(prometheus, hurl, cyrus) != "", "nobody else can")
	log_line("")


func anything_is_a_weapon():
	log_line("======== Anything Is a Weapon ========")
	var enfina := who("enfina")
	var foe: Dictionary = foes()[0]
	var hurl: SkillDefinition = SkillDatabase.skills.hurl
	var there := open_ground(enfina, 3)
	combat.teleport_to(enfina, there)
	var definition: CombatantDefinition = load("res://data/objects/powder_keg.tres")
	var keg: Dictionary = combat.create_combatant(definition, "powder_keg")
	combat.add_combatant(keg, 1, there + Vector2i.RIGHT)
	await settle()
	var bell: Dictionary = combat.create_combatant(load("res://data/objects/bell.tres"), "bell")
	combat.add_combatant(bell, 1, there + Vector2i.LEFT)
	await settle()
	await their_turn(enfina)
	ok(combat._grip_refusal(enfina, hurl, keg) == "", "a keg can be picked up")
	ok(combat._grip_refusal(enfina, hurl, bell) != "", "a bell can't")
	ok(combat._grip_refusal(who("cyrus"), hurl, keg) != "", "and nobody else picks up anything")
	combat.teleport_to(foe, there + Vector2i(0, 3))
	var foe_hp: int = foe.hp
	var land: Vector2i = there + Vector2i(0, 2)
	ok(combat.throw_destinations(enfina, hurl, keg).has(land), "somewhere to throw it")
	await combat.use_skill("hurl", enfina, keg.position, false, false, land)
	await settle(6)
	ok(not keg.alive, "it goes off where it lands")
	ok(foe.hp < foe_hp, "catching whoever is there", "%d to %d" % [foe_hp, foe.hp])
	log_line("")


func arrest():
	log_line("======== Arrest ========")
	var enfina := who("enfina")
	var foe: Dictionary = foes()[0]
	var skill: SkillDefinition = SkillDatabase.skills.arrest
	combat.teleport_to(foe, beside(enfina, foe))
	await their_turn(enfina)
	foe["nerve"] = 100
	foe["shaken"] = 0
	ok(combat.refusal_for(enfina, skill, foe.position) != "", "their nerve still holds", combat.refusal_for(enfina, skill, foe.position))
	foe["shaken"] = 60
	ok(combat.refusal_for(enfina, skill, foe.position) == "", "more than half gone, she can try")
	enfina.stats[Stats.stat_key(Stats.Type.PHYSICAL)] = 900
	foe.stats[Stats.stat_key(Stats.Type.SELF)] = 0
	await combat.use_skill("arrest", enfina, foe.position, false)
	await settle(4)
	ok(foe.get("taken", "") == "surrendered", "they give up", foe.get("taken", ""))
	ok(combat.prisoners().has(foe), "and can be questioned after")
	log_line("")


func carries_them():
	log_line("======== Carries Them ========")
	Campaign.reset()
	Campaign.set_party(["enfina", "cyrus"], 64)
	var m := await open_map()
	m.scene.begin_stealth()
	await settle()
	var watch = m.scene.stealth
	Campaign.party_order = ["enfina", "cyrus"]
	ok(watch._carries_at_full_pace(), "she leads: at her full pace", Campaign.leader())
	Campaign.party_order = ["cyrus", "enfina"]
	ok(not watch._carries_at_full_pace(), "he leads: not", Campaign.leader())
	close_map(m)
	await settle()
	Campaign.reset()
	log_line("")
