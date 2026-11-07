extends "res://StealthHarness.gd"
## Prometheus's other magic, the designer's picks of 2026-11-07 (docs/proposals_2026-11-07.md section 16; Combat "Prometheus's other magic"):
## Shrink, Transposition, Grease, Wall of Stone, False Life, Withering Touch and Blight, with a book for each.


func suite() -> String:
	return "prometheus"


func time_limit() -> float:
	return 240.0


const NEW := ["shrink", "transposition", "grease", "wall_of_stone", "false_life", "withering_touch", "blight"]

var game = null
var combat: Combat = null
var controller = null


func run_sections():
	whose_they_are()
	await open_fight()
	await shrink()
	await open_fight()
	await transposition()
	await open_fight()
	await grease()
	await open_fight()
	await wall_of_stone()
	await open_fight()
	await false_life()
	await open_fight()
	await withering_touch()
	await open_fight()
	await blight()
	await close_fight()
	await shrink_on_a_map()


func whose_they_are():
	log_line("======== whose they are ========")
	var definition: CombatantDefinition = CombatantDatabase.combatants.prometheus
	var wanted := {"shrink": 2, "transposition": 3, "grease": 1, "wall_of_stone": 3, "false_life": 1, "withering_touch": 1, "blight": 3}
	var prices := {1: 150, 2: 150, 3: 375}
	var stock: Array = load("res://data/stores/travelling_merchant.tres").stock
	for key in NEW:
		var skill: SkillDefinition = SkillDatabase.skills.get(key)
		ok(skill != null and skill.spell_slot_level == wanted[key], "%s through the right gate" % key, "%d" % (skill.spell_slot_level if skill != null else -1))
		ok(definition.skills.has(key), "and it is his")
		ok(not definition.starting_spells.has(key), "to be learned")
		var book = ItemDatabase.items.get(key + "_spellbook")
		ok(book != null and book.teaches == key and book.price == prices[wanted[key]], "from a book at the usual price", "%d" % (book.price if book != null else -1))
		ok(stock.has(key + "_spellbook"), "which the merchant has")
	ok(SkillDatabase.skills.shrink.tether_strength == 100 and SkillDatabase.skills.shrink.outside_gate == 1, "Shrink: a tether of 100, and the Gates of Iris on a map")
	ok(SkillDatabase.skills.blight.tether_strength == 200, "Blight: a tether of 200")
	ok(SkillDatabase.skills.wall_of_stone.tether_strength == 200, "Wall of Stone: a tether of 200")
	ok(not SkillDatabase.skills.transposition.tethered and not SkillDatabase.skills.grease.tethered and not SkillDatabase.skills.false_life.tethered and not SkillDatabase.skills.withering_touch.tethered, "and the rest with none")
	log_line("")


func open_fight():
	await close_fight()
	Campaign.reset()
	Campaign.set_party(["enfina", "cyrus", "prometheus", "alithia"], 64)
	Campaign.learned_spells["prometheus"] = NEW + ["burner", "wildfire", "fire_blast"]
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
	var caster := who("prometheus")
	for gate in caster.spell_slots.size():
		caster.spell_slots[gate] = 5
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


## Open ground with `room` clear all round, a little way from anybody.
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


func shrink():
	log_line("======== Shrink ========")
	var caster := who("prometheus")
	var foe: Dictionary = foes()[0]
	var size_was: int = foe.size
	combat.teleport_to(foe, open_ground(foe, 1))
	combat.teleport_to(caster, foe.position + Vector2i(2, 0)) if combat.can_land_on(caster, foe.position + Vector2i(2, 0)) else combat.teleport_to(caster, foe.position + Vector2i(0, 2))
	await their_turn(caster)
	await combat.use_skill("shrink", caster, foe.position, false)
	await settle(3)
	ok(foe.size == size_was - 1, "a size smaller", "%d to %d" % [size_was, foe.size])
	ok(Combat.holds_tether(caster) and caster.tether.max == 100, "on a tether of 100")
	combat.snap_tether(caster, "test")
	await settle(2)
	ok(foe.size == size_was, "and back when it goes", "%d" % foe.size)
	# An ally too.
	var cyrus := who("cyrus")
	var cyrus_was: int = cyrus.size
	combat.teleport_to(cyrus, caster.position + Vector2i(1, 0)) if combat.can_land_on(cyrus, caster.position + Vector2i(1, 0)) else combat.teleport_to(cyrus, caster.position + Vector2i(-1, 0))
	await their_turn(caster)
	await combat.use_skill("shrink", caster, cyrus.position, false)
	await settle(3)
	ok(cyrus.size == cyrus_was - 1, "on an ally too")
	log_line("")


func transposition():
	log_line("======== Transposition ========")
	var caster := who("prometheus")
	var enfina := who("enfina")
	var cyrus := who("cyrus")
	var there := open_ground(caster, 2)
	combat.teleport_to(caster, there)
	combat.teleport_to(enfina, there + Vector2i(1, 0))
	combat.teleport_to(cyrus, there + Vector2i(-1, 0))
	var hers: Vector2i = enfina.position
	var his: Vector2i = cyrus.position
	await their_turn(caster)
	controller.set_selected_skill("transposition")
	ok(controller.aimed_twice(SkillDatabase.skills.transposition), "aimed twice")
	ok(combat.can_transpose(enfina, cyrus), "two of a size can")
	ok(not combat.can_transpose(enfina, enfina), "not with themselves")
	await combat.use_skill("transposition", caster, hers, false, false, his)
	await settle(3)
	ok(enfina.position == his and cyrus.position == hers, "they change places", "%s, %s" % [enfina.position, cyrus.position])
	ok(caster.skill_used_this_turn, "for his main action")
	ok(combat.get_combatant_at(his) == enfina and combat.get_combatant_at(hers) == cyrus, "and the board knows it")
	# A foe gets a say.
	var foe: Dictionary = foes()[0]
	foe.stats[Stats.stat_key(Stats.Type.SELF)] = 900
	combat.teleport_to(foe, there + Vector2i(0, 1)) if combat.can_land_on(foe, there + Vector2i(0, 1)) else combat.teleport_to(foe, there + Vector2i(0, -1))
	var at: Vector2i = foe.position
	var her_now: Vector2i = enfina.position
	await their_turn(caster)
	await combat.use_skill("transposition", caster, foe.position, false, false, enfina.position)
	await settle(3)
	ok(foe.position == at and enfina.position == her_now, "a foe stronger of self holds on to where they are", "%s" % foe.position)
	foe.stats[Stats.stat_key(Stats.Type.SELF)] = 0
	await their_turn(caster)
	await combat.use_skill("transposition", caster, foe.position, false, false, enfina.position)
	await settle(3)
	ok(foe.position == her_now and enfina.position == at, "a weaker one goes", "%s" % foe.position)
	log_line("")


func grease():
	log_line("======== Grease ========")
	var caster := who("prometheus")
	var foe: Dictionary = foes()[0]
	var there := open_ground(foe, 2)
	ok(there != Combat.NO_AREA, "room for it")
	combat.teleport_to(caster, there + Vector2i(-2, -1) if combat.can_land_on(caster, there + Vector2i(-2, -1)) else there + Vector2i(0, -3))
	await their_turn(caster)
	await combat.use_skill("grease", caster, there, false)
	await settle(3)
	var zone = combat.zones.filter(func(each): return each.name == "Grease")
	ok(zone.size() == 1 and zone[0].tiles.has(there), "ground that lies there", "%d" % zone.size())
	# Whoever walks it, and loses.
	foe.stats[Stats.stat_key(Stats.Type.PHYSICAL)] = 0
	var prone: ConditionDefinition = load("res://data/conditions/prone.tres")
	combat.teleport_to(foe, there)
	foe.status_effects = foe.status_effects.filter(func(entry): return entry.get("condition") != prone)
	var hp: int = foe.hp
	combat.zones_under_step(foe, there)
	await settle()
	ok(combat.conditions_of(foe).has(prone), "knocks down whoever walks it")
	ok(foe.hp == hp, "and hurts nobody", "%d" % foe.hp)
	# Whoever wins, no.
	foe.status_effects = foe.status_effects.filter(func(entry): return entry.get("condition") != prone)
	foe.stats[Stats.stat_key(Stats.Type.PHYSICAL)] = 900
	combat.zones_under_step(foe, there)
	await settle()
	ok(not combat.conditions_of(foe).has(prone), "strong enough, they keep their feet")
	# Fire.
	await their_turn(caster)
	await combat.use_skill("fire_blast", caster, there, false)
	await settle(4)
	ok(not combat.zones.any(func(each): return each.name == "Grease"), "fire touches it, and it goes up", "%d" % combat.zones.size())
	ok(combat.zones.any(func(each): return each.get("effect") != null and each.effect.damage_type == Damage.Type.FIRE), "and burns")
	log_line("")


func wall_of_stone():
	log_line("======== Wall of Stone ========")
	var caster := who("prometheus")
	var foe: Dictionary = foes()[0]
	var there := open_ground(caster, 3)
	combat.teleport_to(caster, there + Vector2i(-3, 0))
	await their_turn(caster)
	var skill: SkillDefinition = SkillDatabase.skills.wall_of_stone
	ok(Combat.places_a_wall(skill), "placed by two points")
	await combat.use_skill("wall_of_stone", caster, there + Vector2i(0, -2), false, false, there + Vector2i(0, 2))
	await settle(3)
	var pieces: Array = combat.combatants.filter(func(comb): return comb.get("alive", false) and comb.has("object") and comb.object.resource_path.ends_with("wall_of_stone.tres"))
	ok(pieces.size() == 5, "five tiles of it", "%d" % pieces.size())
	ok(not pieces.is_empty() and combat.is_wall(pieces[0]) and not pieces[0].get("illusion", false), "really there")
	ok(Combat.holds_tether(caster) and caster.tether.max == 200, "on a tether of 200")
	ok(not combat.has_line_of_sight(there + Vector2i(-1, 0), there + Vector2i(1, 0), 0), "nobody sees past it")
	ok(not combat.can_land_on(foe, there), "nor stands on it")
	ok(combat.illusions_to_pass(foe).is_empty() and combat.illusions_to_pass(caster).is_empty(), "and nobody of either side walks through")
	# It can be broken, by what breaks walls.
	var enfina := who("enfina")
	ok(combat.breaks_wall(enfina, SkillDatabase.skills.greatsword_attack), "Enfina can break it")
	combat.snap_tether(caster, "test")
	await settle(3)
	ok(combat.can_land_on(foe, there), "and it goes with the tether")
	log_line("")


func false_life():
	log_line("======== False Life ========")
	var caster := who("prometheus")
	await their_turn(caster)
	ok(caster.get("temp_hp", 0) == 0, "nothing on top of his health")
	await combat.use_skill("false_life", caster, caster.position, false)
	await settle(3)
	ok(caster.get("temp_hp", 0) >= 10, "health on top of his own", "%d" % caster.get("temp_hp", 0))
	var shield: int = caster.temp_hp
	var hp: int = caster.hp
	combat.lose_hp(caster, 5, Damage.Type.PHYSICAL)
	ok(caster.temp_hp == shield - 5 and caster.hp == hp, "taken first")
	log_line("")


func withering_touch():
	log_line("======== Withering Touch ========")
	var caster := who("prometheus")
	var foe: Dictionary = foes()[0]
	var there := open_ground(foe, 1)
	combat.teleport_to(foe, there)
	combat.teleport_to(caster, there + Vector2i.RIGHT)
	var hp: int = foe.hp
	await their_turn(caster)
	await combat.use_skill("withering_touch", caster, foe.position, false)
	await settle(3)
	ok(foe.hp < hp, "a weak blow", "%d to %d" % [hp, foe.hp])
	var withered: ConditionDefinition = load("res://data/conditions/withered.tres")
	ok(combat.conditions_of(foe).has(withered), "and they are withered")
	ok(combat.healing_taken_share(foe) == 0.0, "nothing mends them")
	foe.hp = 100
	var alithia := who("alithia")
	var heal: SkillDefinition = SkillDatabase.skills.heal
	combat.do_heal(alithia, foe, heal.effects[0], heal)
	ok(foe.hp == 100, "not even a heal", "%d" % foe.hp)
	log_line("")


func blight():
	log_line("======== Blight ========")
	var caster := who("prometheus")
	var foe: Dictionary = foes()[0]
	var cyrus := who("cyrus")
	var there := open_ground(foe, 2)
	combat.teleport_to(foe, there)
	combat.teleport_to(cyrus, there + Vector2i(1, 0))
	combat.teleport_to(caster, there + Vector2i(-3, 0)) if combat.can_land_on(caster, there + Vector2i(-3, 0)) else combat.teleport_to(caster, there + Vector2i(3, 0))
	await their_turn(caster)
	await combat.use_skill("blight", caster, there, false)
	await settle(3)
	var blighted: ConditionDefinition = load("res://data/conditions/blighted.tres")
	ok(combat.conditions_of(foe).has(blighted), "everything standing there rots")
	ok(combat.conditions_of(cyrus).has(blighted), "whoever's side they are on")
	ok(is_equal_approx(combat.healing_taken_share(foe), 0.5), "and is mended only half", "%.2f" % combat.healing_taken_share(foe))
	ok(Combat.holds_tether(caster) and caster.tether.max == 200, "on a tether of 200")
	combat.snap_tether(caster, "test")
	await settle(2)
	ok(not combat.conditions_of(foe).has(blighted), "and it goes with it")
	log_line("")


func shrink_on_a_map():
	log_line("======== Shrink on a map ========")
	Campaign.reset()
	Campaign.set_party(["prometheus", "cyrus"], 64)
	Campaign.learned_spells["prometheus"] = ["shrink"]
	var m := await open_map()
	var scene: ExplorationScene = m.scene
	ok(OutsideMoves.use_of(SkillDatabase.skills.shrink) == OutsideMoves.Use.SHRINK, "out of a fight it is Shrink's own")
	ok(Stats.OUTSIDE_GATES.size() > 0 and SkillDatabase.skills.shrink.outside_gate == 1, "through the Gates of Iris")
	var tile := Vector2i(-1, -1)
	var region: Rect2i = scene._tile_map.get_used_rect()
	for x in range(region.position.x, region.end.x):
		for y in range(region.position.y, region.end.y):
			if tile == Vector2i(-1, -1) and scene.is_walkable(scene._tile_map.map_to_local(Vector2i(x, y))):
				tile = Vector2i(x, y)
	ok(tile != Vector2i(-1, -1), "ground to try it on", "%s" % tile)
	scene.set_small_gap(tile, true)
	var was: bool = scene.is_walkable(scene._tile_map.map_to_local(tile))
	ok(not was, "a small gap stops them")
	scene.shrink_party(5.0)
	ok(scene.shrunk(), "shrunk")
	ok(scene.is_walkable(scene._tile_map.map_to_local(tile)), "and through it they go")
	var figure = scene.party.sprite_for("prometheus")
	ok(figure == null or figure.has_meta("scale_when_full"), "drawn smaller")
	scene.shrink_party(0.0)
	ok(not scene.shrunk() and not scene.is_walkable(scene._tile_map.map_to_local(tile)), "and back")
	ok(figure == null or not figure.has_meta("scale_when_full"), "and back to their size")
	close_map(m)
	await settle()
	Campaign.reset()
	log_line("")
