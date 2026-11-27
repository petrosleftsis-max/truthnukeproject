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
	await open_fight()
	await things_that_break()
	await open_fight()
	await burn_through()
	await open_fight()
	await breakthrough()
	await open_fight()
	await intercept()
	await open_fight({"enfina": "vanguard"})
	await firebrand()
	await open_fight({"enfina": "warden_of_cover"})
	await interceptor()
	await open_fight()
	await grab_a_friend()
	await open_fight()
	await weak_points_and_the_kit()
	await close_fight()
	await carries_them()
	await smashing_on_a_map()


func open_fight(paths: Dictionary = {}):
	await close_fight()
	Campaign.reset()
	Campaign.set_party(["enfina", "cyrus", "prometheus", "alithia"], 64)
	for key in paths:
		Campaign.choose_subclass(key, paths[key])
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


## --- Through, not around (docs/proposals_2026-11-26_enfina.md, the designer's picks of 2026-11-26; Combat "Things that break") ---


## A barrel of the TileSet's (Health 12) put on `tile` for a check, read as the map reads it.
func put_barrel(tile: Vector2i):
	controller.tile_map.set_cell(0, tile, 0, Vector2i(5, 2))
	controller.retile(tile)
	combat._breakables_read = false
	controller.update_points_weight()


func has_condition(comb: Dictionary, path: String) -> bool:
	return comb.get("status_effects", []).any(func(entry): return entry.get("condition") != null and entry.condition.resource_path == path)


func add_keg(at: Vector2i) -> Dictionary:
	var keg: Dictionary = combat.create_combatant(load("res://data/objects/powder_keg.tres"), "powder_keg")
	combat.add_combatant(keg, 1, at)
	return keg


## A damaging blow of `comb`'s that reaches a tile away, by key, or "".
func a_blow_of(comb: Dictionary) -> String:
	for skill_key in comb.skill_list:
		var skill: SkillDefinition = SkillDatabase.skills.get(skill_key)
		if skill == null or not skill.deals_damage or skill.targets_ally or skill.reaction_only or skill.spell_slot_level > 0:
			continue
		if skill.min_range <= 1 and skill.max_range >= 1 and skill.aoe_radius == 0:
			return skill_key
	return ""


func things_that_break():
	log_line("======== Things that break ========")
	var enfina := who("enfina")
	var cyrus := who("cyrus")
	var there := open_ground(cyrus, 3)
	ok(there != Combat.NO_AREA, "room for it", "%s" % there)
	combat.teleport_to(cyrus, there)
	var barrel: Vector2i = there + Vector2i(2, 0)
	put_barrel(barrel)
	ok(combat.breakable_health(barrel) == 12 and combat.is_breakable_tile(barrel), "a barrel has the TileSet's Health, 12", "%d" % combat.breakable_health(barrel))
	ok(controller.is_tile_blocking(barrel, 0), "and stands in the way")
	combat.hurt_tile(barrel, 5, cyrus)
	ok(combat.tile_health_of(barrel) == 7 and controller.is_tile_blocking(barrel, 0), "anybody wears it down: 7 left, still standing")
	combat.hurt_tile(barrel, 7, cyrus)
	ok(combat.broken_tiles.has(barrel) and not combat.is_breakable_tile(barrel) and not controller.is_tile_blocking(barrel, 0),
		"at nothing it breaks, floor now")
	# A blow aimed at it.
	var foe: Dictionary = foes()[0]
	var key := a_blow_of(foe)
	var crate: Vector2i = there + Vector2i(0, 2)
	put_barrel(crate)
	ok(not combat._aim_blocked(crate, 0), "what breaks can be aimed at")
	if key != "" and combat.can_land_on(foe, crate + Vector2i.LEFT):
		combat.teleport_to(foe, crate + Vector2i.LEFT)
		await their_turn(foe)
		await combat.use_skill(key, foe, crate, false)
		await settle(4)
		ok(combat.tile_health_of(crate) < 12 or combat.broken_tiles.has(crate), "a blow aimed at it wears it down", "%s: %d" % [key, combat.tile_health_of(crate)])
	# Enfina breaks it outright, whatever its Health (Breaker).
	var third: Vector2i = there + Vector2i(-2, 0)
	put_barrel(third)
	combat.hurt_tile(third, 1, enfina)
	ok(combat.broken_tiles.has(third), "Enfina breaks it with any blow at all (Breaker)")
	var spot := open_ground(enfina, 2)
	combat.teleport_to(enfina, spot)
	var keg := add_keg(spot + Vector2i(0, 2))
	await settle()
	combat.do_damage(enfina, keg, Combat._splinter_effect(), SkillDatabase.skills.greatsword_attack, false, 0.01)
	await settle()
	ok(not keg.alive, "and a Powder Keg goes in one blow of hers, however light")
	log_line("")


func burn_through():
	log_line("======== Burn Through and Splinters ========")
	var enfina := who("enfina")
	var there := open_ground(enfina, 3)
	combat.teleport_to(enfina, there)
	var barrel: Vector2i = there + Vector2i(1, 0)
	put_barrel(barrel)
	await their_turn(enfina)
	ok(not combat.bursts_for(enfina).has(barrel), "not burning, a barrel stops her")
	await light_her(enfina)
	controller.update_points_weight()
	ok(combat.bursts_for(enfina).has(barrel), "burning, she goes straight through it")
	ok(controller.get_reachable_tiles(enfina.position, 0, 6, enfina).has(barrel), "  somewhere she can walk to")
	var foe: Dictionary = foes()[0]
	combat.teleport_to(foe, barrel + Vector2i(0, 1))
	var foe_hp: int = foe.hp
	enfina.position = barrel
	combat.burst_through(enfina, barrel, Vector2i.RIGHT)
	controller.refresh_occupancy()
	await settle()
	ok(combat.broken_tiles.has(barrel), "she bursts through it")
	ok(foe.hp < foe_hp and has_condition(foe, Combat.EXPOSED_CONDITION), "splinters: the one beside it hurt and Exposed", "%d to %d" % [foe_hp, foe.hp])
	# A keg in her way goes off, on her too.
	var keg := add_keg(enfina.position + Vector2i(1, 0))
	await settle()
	var hers: int = enfina.hp
	ok(combat.bursts_for(enfina).has(keg.position), "a keg she can burst through too")
	var at: Vector2i = keg.position
	enfina.position = at
	combat.burst_through(enfina, at, Vector2i.RIGHT)
	controller.refresh_occupancy()
	await settle(3)
	ok(not keg.alive and enfina.hp < hers, "it goes off as she comes to it, and catches her", "%d to %d" % [hers, enfina.hp])
	# Shoulder Through: a smaller foe of the other side, shoved aside, hurt once a turn.
	foe["size"] = Sizes.Size.SMALL
	if combat.can_land_on(foe, enfina.position + Vector2i(1, 0)):
		combat.teleport_to(foe, enfina.position + Vector2i(1, 0))
	await settle()
	ok(not combat.shouldered_at(enfina, foe.position).is_empty(), "burning, she walks through somebody smaller of the other side")
	var spot: Vector2i = foe.position
	var hp: int = foe.hp
	enfina.position = spot
	combat.burst_through(enfina, spot, Vector2i.RIGHT)
	controller.refresh_occupancy()
	await settle()
	ok(foe.position != spot and foe.hp < hp, "shouldered aside, with a bit of damage", "%d to %d" % [hp, foe.hp])
	var after: int = foe.hp
	enfina.position = foe.position
	combat.burst_through(enfina, foe.position, Vector2i.RIGHT)
	controller.refresh_occupancy()
	await settle()
	ok(foe.hp == after, "  hurt only once a turn")
	foe["size"] = Sizes.Size.HUMAN
	log_line("")


## A tile with `length` free tiles to its right, and free tiles above and below each of them, for a charge along a row.
func open_row(probe: Dictionary, length: int) -> Vector2i:
	var region: Rect2i = controller._astargrid.region
	for y in range(region.position.y + 1, region.end.y - 1):
		for x in range(region.position.x, region.end.x - length):
			var tile := Vector2i(x, y)
			var clear := true
			for step in range(0, length + 1):
				for side in [-1, 0, 1]:
					var near := tile + Vector2i(step, side)
					if not controller.is_on_map(near) or not combat.can_land_on(probe, near):
						clear = false
			if clear:
				return tile
	return Combat.NO_AREA


func breakthrough():
	log_line("======== Breakthrough ========")
	var enfina := who("enfina")
	var there := open_row(enfina, 5)
	ok(there != Combat.NO_AREA, "room for it", "%s" % there)
	combat.teleport_to(enfina, there)
	var foe: Dictionary = foes()[0]
	combat.teleport_to(foe, there + Vector2i(2, 0))
	put_barrel(there + Vector2i(3, 0))
	await light_her(enfina)
	await their_turn(enfina)
	var charge: SkillDefinition = SkillDatabase.skills.breakthrough
	ok(combat.refusal_for(enfina, charge, there + Vector2i(2, 1)) != "", "only in a straight line")
	ok(combat.get_range_tiles(charge, enfina.position, 0, enfina).has(there + Vector2i(4, 0)), "as far as she walks, through what she can smash")
	var hp: int = foe.hp
	await combat.use_skill("breakthrough", enfina, there + Vector2i(4, 0), false)
	await settle(5)
	ok(enfina.position == there + Vector2i(4, 0), "the charge carries her the whole way", "%s" % enfina.position)
	ok(foe.position.y != there.y and foe.hp < hp, "the one in the way driven aside and hurt", "%s, %d to %d" % [foe.position, hp, foe.hp])
	ok(combat.broken_tiles.has(there + Vector2i(3, 0)), "the barrel in the way smashed")
	var lit: Array = []
	for zone in combat.zones:
		if zone.has("blazed_by"):
			lit.append_array(zone.tiles)
	ok(lit.has(there + Vector2i(1, 1)) and lit.has(there + Vector2i(1, -1)) and lit.has(there + Vector2i(1, 0)), "burning, the way stays alight a tile wider each side")
	# Somebody bigger stops her.
	var start: Vector2i = enfina.position
	var big: Dictionary = foes()[0]
	big["size"] = Sizes.Size.LARGE
	if combat.can_land_on(big, start + Vector2i(-2, 0)):
		combat.teleport_to(big, start + Vector2i(-2, 0))
		enfina.skill_used_this_turn = false
		var big_hp: int = big.hp
		await combat.use_skill("breakthrough", enfina, start + Vector2i(-4, 0), false)
		await settle(5)
		ok(enfina.position == start + Vector2i(-1, 0) and big.hp < big_hp, "somebody bigger stops her beside them, and takes the blow", "%s" % enfina.position)
	big["size"] = Sizes.Size.HUMAN
	log_line("")


func intercept():
	log_line("======== Intercept ========")
	var enfina := who("enfina")
	var cyrus := who("cyrus")
	var foe: Dictionary = foes()[0]
	var there := open_ground(enfina, 3)
	combat.teleport_to(enfina, there)
	combat.teleport_to(cyrus, there + Vector2i(2, 0))
	combat.teleport_to(foe, there + Vector2i(3, 0))
	var step_in: SkillDefinition = SkillDatabase.skills.step_in
	ok(combat.intercept_reach(enfina) == 0 and combat._reaction_target(enfina, step_in, foe, cyrus).is_empty(), "not burning, two tiles is too far")
	await light_her(enfina)
	ok(combat.intercept_reach(enfina) == 2 and not combat._reaction_target(enfina, step_in, foe, cyrus).is_empty(), "burning, Step In reaches him")
	enfina.reaction_used = false
	_answering = true
	_saying_yes = true
	_keep_answering()
	var his: int = cyrus.hp
	var hers: int = enfina.hp
	await their_turn(foe)
	await combat.use_skill("greatsword_attack", foe, cyrus.position, false)
	await settle(5)
	_answering = false
	await settle()
	ok(cyrus.hp == his and enfina.hp < hers, "she runs to him and takes it", "%d, %d to %d" % [cyrus.hp, hers, enfina.hp])
	ok(combat.rect_gap(combat.rect_of(enfina), combat.rect_of(cyrus)) <= 1, "  beside him now")
	ok(int(enfina.get("walk_owed", 0)) == 1, "  a tile of her next walk owed")
	var full := int(combat.get_effective_stat(enfina, "movement")) + combat.blazed_path_bonus(enfina)
	await their_turn(enfina)
	ok(controller.movement == full - 1, "  paid as her turn begins", "%d of %d" % [controller.movement, full])
	log_line("")


## The Vanguard's Firebrand (2026-11-27): whoever Breakthrough drives aside catches fire, and so does anybody of the other side
## her splinters hit. Not burning herself, so Adrenaline (which sets alight only while she burns) cannot be what lit them.
func firebrand():
	log_line("======== Firebrand (Vanguard) ========")
	const BURN := "res://data/conditions/burn.tres"
	var enfina := who("enfina")
	ok(combat._has_passive_switch(enfina, &"firebrand") and not enfina.skill_list.has("daunting_roar"), "a Vanguard has Firebrand, and no Daunting Roar")
	var there := open_row(enfina, 5)
	ok(there != Combat.NO_AREA, "room for it", "%s" % there)
	combat.teleport_to(enfina, there)
	var the_foes := foes()
	var driven: Dictionary = the_foes[0]
	var beside_it: Dictionary = the_foes[1]
	combat.teleport_to(driven, there + Vector2i(1, 0))
	put_barrel(there + Vector2i(3, 0))
	combat.teleport_to(beside_it, there + Vector2i(3, 1))
	for foe in [driven, beside_it]:
		foe.status_effects = foe.status_effects.filter(func(entry): return entry.get("condition") == null or entry.condition.resource_path != BURN)
		foe.hp = 9999
		foe.max_hp = 9999
	await their_turn(enfina)
	ok(combat.burn_turns_of(enfina) <= 0, "  she is not burning")
	await combat.use_skill("breakthrough", enfina, there + Vector2i(4, 0), false)
	await settle(5)
	ok(driven.position.y != there.y and has_condition(driven, BURN), "the one she drove aside is burning", "%s" % driven.position)
	ok(combat.broken_tiles.has(there + Vector2i(3, 0)) and has_condition(beside_it, BURN), "and so is the one her splinters hit beside the barrel")
	log_line("")


## The Warden of Cover's Interceptor, reworked (2026-11-27): Step In reaches 3 tiles, burning or not, and costs her no walk.
func interceptor():
	log_line("======== Interceptor (Warden of Cover) ========")
	var enfina := who("enfina")
	var cyrus := who("cyrus")
	var foe: Dictionary = foes()[0]
	var there := open_row(enfina, 5)
	ok(there != Combat.NO_AREA, "room for it", "%s" % there)
	combat.teleport_to(enfina, there)
	combat.teleport_to(cyrus, there + Vector2i(3, 0))
	combat.teleport_to(foe, there + Vector2i(4, 0))
	var step_in: SkillDefinition = SkillDatabase.skills.step_in
	ok(combat.burn_turns_of(enfina) <= 0 and combat.intercept_reach(enfina) == 3 and not combat._reaction_target(enfina, step_in, foe, cyrus).is_empty(),
		"not burning, Step In reaches him 3 tiles off", "%d" % combat.intercept_reach(enfina))
	ok(enfina.skill_list.has("daunting_roar"), "and Daunting Roar is hers")
	enfina.reaction_used = false
	_answering = true
	_saying_yes = true
	_keep_answering()
	var his: int = cyrus.hp
	var hers: int = enfina.hp
	await their_turn(foe)
	await combat.use_skill("greatsword_attack", foe, cyrus.position, false)
	await settle(5)
	_answering = false
	await settle()
	ok(cyrus.hp == his and enfina.hp < hers, "she runs to him and takes it", "%d, %d to %d" % [cyrus.hp, hers, enfina.hp])
	ok(int(enfina.get("walk_owed", 0)) == 0, "  and owes none of her next walk")
	log_line("")


func grab_a_friend():
	log_line("======== Grab, on a friend ========")
	var enfina := who("enfina")
	var cyrus := who("cyrus")
	var grab: SkillDefinition = SkillDatabase.skills.grab
	var there := open_ground(enfina, 2)
	combat.teleport_to(enfina, there)
	combat.teleport_to(cyrus, there + Vector2i.RIGHT)
	await their_turn(enfina)
	ok(grab.is_secondary, "Grab is a secondary action")
	ok(combat.wins_contest(enfina, cyrus, grab), "a friend is always taken hold of")
	controller.set_selected_skill("grab")
	ok(controller.is_valid_skill_target(cyrus), "and can be aimed at")
	await combat.use_skill("grab", enfina, cyrus.position, false, true)
	await settle()
	ok(combat.is_held(cyrus) and combat.holder_of(cyrus).get("id", -1) == enfina.id, "she has hold of him")
	ok(combat.drag_cost(enfina) == 1, "on his feet, he costs her nothing to carry")
	var stun: ConditionDefinition = load("res://data/conditions/stunned.tres")
	combat.put_condition(cyrus, stun, 2, "test", false)
	ok(combat.drag_cost(enfina) == 2, "stunned, he is dead weight", "%d" % combat.drag_cost(enfina))
	cyrus.status_effects = cyrus.status_effects.filter(func(entry): return entry.get("condition") != stun)
	combat._turn_begins_for(cyrus)
	ok(not combat.is_held(cyrus), "set down as his own turn begins")
	log_line("")


func weak_points_and_the_kit():
	log_line("======== Weak Points, and her kit ========")
	var enfina := who("enfina")
	var cyrus := who("cyrus")
	var there := open_ground(enfina, 3)
	combat.teleport_to(enfina, there)
	put_barrel(there + Vector2i(2, 0))
	var keg := add_keg(there + Vector2i(0, 2))
	await settle()
	await their_turn(enfina)
	ok(combat.weak_points_shown(), "on her turn she sees weak points")
	ok(combat.weak_point_tiles().has(there + Vector2i(2, 0)) and combat.goes_off_tiles().has(keg.position), "what breaks, and what goes off")
	await their_turn(cyrus)
	ok(not combat.weak_points_shown(), "  not on anybody else's")
	ok(not combat.active_passives(enfina).any(func(passive): return passive.still_damage_bonus > 0.0), "Momentum (Planted) is out of her kit")
	var caught: EffectDefinition = SkillDatabase.skills.blazed_path.effects[0]
	ok(caught.condition_duration == 5 and is_equal_approx(caught.condition_dot_modifier, 0.4), "Blazed Path burns the other side longer and harder: 5 turns at 0.4")
	ok(enfina.skill_list.has("breakthrough"), "Breakthrough is hers")
	log_line("")


func smashing_on_a_map():
	log_line("======== Smashing things on a map ========")
	var m := await open_map()
	Campaign.set_party(["enfina", "cyrus"], 64)
	var scene: ExplorationScene = m.scene
	var tile_map: TileMap = m.tile_map
	var near: Vector2i = tile_map.local_to_map(tile_map.to_local(scene.party_position()))
	var spot := Vector2i(-99999, -99999)
	for reach in range(2, 6):
		for way in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
			var tile: Vector2i = near + way * reach
			if spot.x == -99999 and scene.is_walkable(tile_map.map_to_local(tile)):
				spot = tile
	ok(spot.x != -99999, "a spot of floor near the party", "%s" % spot)
	if spot.x == -99999:
		close_map(m)
		return
	tile_map.set_cell(0, spot, 0, Vector2i(5, 2))
	scene._build_blocking()
	scene.map_sight().retile(spot)
	ok(not scene.is_walkable(tile_map.map_to_local(spot)) and scene.things_on([spot]) == [spot], "a barrel on the map stands in the way, and breaks")
	ok(OutsideMoves.smashes_things("enfina") and not OutsideMoves.smashes_things("cyrus"), "out here it is hers to smash")
	scene.break_thing(spot)
	await settle()
	ok(scene.is_walkable(tile_map.map_to_local(spot)) and Campaign.flag(ExplorationScene.BROKEN_THING_FLAG % [scene.map_path(), spot.x, spot.y]),
		"smashed: floor now, and kept in the flags")
	ok(not scene.map_sight().stops_sight(spot), "  and seen across")
	# Kept broken as the map loads again.
	var other: Vector2i = spot + Vector2i(1, 0) if scene.is_walkable(tile_map.map_to_local(spot + Vector2i(1, 0))) else spot + Vector2i(0, 1)
	tile_map.set_cell(0, other, 0, Vector2i(5, 2))
	Campaign.set_flag(ExplorationScene.BROKEN_THING_FLAG % [scene.map_path(), other.x, other.y])
	scene._apply_broken_things()
	ok(Combat.health_on(tile_map, other) == 0, "what was smashed before is smashed again as the map loads")
	ok(scene.party_sees_weak_points(), "with her in the party, what breaks near them is marked")
	Campaign.set_party(["cyrus", "alithia"], 64)
	ok(not scene.party_sees_weak_points(), "  and without her, not")
	close_map(m)
	await settle()
	Campaign.reset()
	log_line("")
