extends "res://StealthHarness.gd"
## The designer's answers to section 17 of docs/proposals_2026-11-07.md, 2026-11-07: Beckoning Light (on the Gates of Iris),
## Kindled Faith, and a dart that puts a guard's light out from afar, in place of Lifted Torch.


func suite() -> String:
	return "beckon"


func time_limit() -> float:
	return 240.0


const WATCHER := "res://data/encounters/encounter_03_watcher.tres"

var game = null
var combat: Combat = null
var controller = null


func run_sections():
	the_kit()
	await open_fight()
	await beckoning_in_a_fight()
	await open_fight()
	await not_taken_in()
	await open_fight()
	await kindled_faith()
	await close_fight()
	await beckoning_on_a_map()
	await the_dart()


func the_kit():
	log_line("======== whose, and what they cost ========")
	var light: SkillDefinition = SkillDatabase.skills.get("beckoning_light")
	ok(light != null and CombatantDatabase.combatants.alithia.skills.has("beckoning_light"), "Beckoning Light is Alithia's")
	ok(light.spell_slot_level == 2 and OutsideMoves.iris_gate_for(light) == 1, "Hermes in a fight, the Gates of Iris first on a map")
	ok(CController.aimed_twice(light), "aimed twice: at somebody, then where the light goes")
	ok(OutsideMoves.use_of(light) == OutsideMoves.Use.BECKON, "on a map it leads a guard off")
	ok(light.uses_stat_contest and light.contest_stat == Stats.Type.MINDFULNESS, "against their Mindfulness")
	var faith: PassiveDefinition = load("res://data/passives/kindled_faith.tres")
	ok(CombatantDatabase.combatants.alithia.passives.has(faith), "Kindled Faith is hers")
	ok(faith.required_level == 24 and faith.mends_in_bright == 3.0 and is_equal_approx(faith.mends_in_bright_per_stat, 0.05), "from 24: 3, and a twentieth of her Mindfulness")
	var dart: SkillDefinition = SkillDatabase.skills.poison_dart
	ok(dart.snuffs_carried_lights and dart.shoots_out_lights, "Cyrus's dart puts lights out, carried ones too")
	log_line("")


func open_fight():
	await close_fight()
	Campaign.reset()
	Campaign.set_party(["enfina", "cyrus", "prometheus", "alithia"], 64)
	Campaign.current_map = "res://maps/crossroads_explore.tscn"
	Campaign.return_to_position = true
	var encounter: EncounterDefinition = load(WATCHER).duplicate()
	encounter.ambient = Light.Ambient.UNDERGROUND
	Campaign.current_encounter = encounter
	game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(6)
	combat = game.get_node("VisualCombat")
	controller = game.get_node("Controller")
	combat.reaction_prompt = null
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(2)
	for comb in combat.combatants:
		comb.reaction_used = true
		comb["accuracy"] = 200
		if comb.has("stats"):
			comb.hp = 900
			comb.max_hp = 900
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


## Open ground `gap` tiles from `from` that `walker` could stand on.
func tile_away(from: Vector2i, gap: int, walker: Dictionary) -> Vector2i:
	for tile in controller.get_reachable_tiles(from, walker.movement_class, 40, walker):
		if combat.get_position_distance(tile, from) == gap and combat.can_land_on(walker, tile) and combat.get_combatant_at(tile).is_empty():
			return tile
	return from


func beckoning_in_a_fight():
	log_line("======== Beckoning Light, in a fight ========")
	var alithia := who("alithia")
	var foe: Dictionary = foes()[0]
	foe["stats"][Stats.stat_key(Stats.Type.MINDFULNESS)] = 0
	combat.teleport_to(foe, tile_away(alithia.position, 4, foe))
	var light: Vector2i = tile_away(foe.position, 4, foe)
	while combat.get_position_distance(alithia.position, light) > SkillDatabase.skills.beckoning_light.max_range:
		light = tile_away(foe.position, 3, foe)
	await their_turn(alithia)
	# Asked for where the light goes, as the board would: aimed at them first.
	controller.set_selected_skill("beckoning_light", false)
	controller.begin_target_selection()
	await settle()
	ok(controller.refusal_at(foe.position, foe) == "", "aimed at an enemy in reach", controller.refusal_at(foe.position, foe))
	controller.cancel_skill_selection()
	var before: int = combat.get_position_distance(foe.position, light)
	var paid: int = alithia.spell_slots[2]
	await combat.use_skill("beckoning_light", alithia, foe.position, false, false, light)
	await settle()
	ok(alithia.spell_slots[2] == paid - 1, "a casting through Hermes")
	ok(combat._noise_they_heard(foe) == light, "they will follow the light, not stay where they are", "%s for %s" % [combat._noise_they_heard(foe), light])
	ok(combat.zones.any(func(zone): return zone.tiles == [light]), "and a light is there, where she put it")
	await their_turn(foe)
	controller.movement = 3
	await combat._go_and_look(foe)
	await settle()
	ok(combat.get_position_distance(foe.position, light) < before, "they walk towards it", "%d from %d" % [combat.get_position_distance(foe.position, light), before])
	ok(combat.has_restriction(foe, "prevents_reactions"), "and arrive off their guard: no reactions")
	ok(foe.status_effects.any(func(entry): return entry.get("condition") != null and entry.condition.display_name == "Off Guard"), "Off Guard is on them")
	log_line("")


func not_taken_in():
	log_line("======== whoever beats her Mindfulness stays ========")
	var alithia := who("alithia")
	var foe: Dictionary = foes()[0]
	foe["stats"][Stats.stat_key(Stats.Type.MINDFULNESS)] = 999
	alithia["stats"][Stats.stat_key(Stats.Type.MINDFULNESS)] = 0
	combat.teleport_to(foe, tile_away(alithia.position, 4, foe))
	var light: Vector2i = tile_away(foe.position, 3, foe)
	await their_turn(alithia)
	await combat.use_skill("beckoning_light", alithia, foe.position, false, false, light)
	await settle()
	ok(combat._noise_they_heard(foe) == Combat.NO_AREA, "not drawn")
	log_line("")


func kindled_faith():
	log_line("======== Kindled Faith ========")
	var alithia := who("alithia")
	alithia.hp = 50
	alithia.max_hp = 900
	# Underground and unlit: Dark, and no mend.
	combat._placed_lights.clear()
	combat.sync_zones()
	ok(combat.light_level_of(alithia) != Light.Level.BRIGHT, "in the dark to begin with")
	combat._kindled_at_turn_start(alithia)
	ok(alithia.hp == 50, "out of Bright, nothing", "%d" % alithia.hp)
	combat._placed_lights.append({"tile": alithia.position, "bright": 3.0, "dim": 6.0, "colour": Color.WHITE, "flickers": false})
	combat.sync_zones()
	ok(combat.light_level_of(alithia) == Light.Level.BRIGHT, "then a light on her")
	var mind: int = combat.stat_of(alithia, Stats.Type.MINDFULNESS)
	var wanted: int = roundi(3.0 + 0.05 * float(mind))
	combat._kindled_at_turn_start(alithia)
	ok(alithia.hp == 50 + wanted, "in Bright as her turn starts, she mends 3 and a twentieth of her Mindfulness", "%d, Mindfulness %d" % [alithia.hp, mind])
	# Withered: nothing mends them (Prometheus's Withering Touch), this either.
	combat.put_condition(alithia, load("res://data/conditions/withered.tres"), 1, "test")
	var was: int = alithia.hp
	combat._kindled_at_turn_start(alithia)
	ok(alithia.hp == was, "not while nothing can mend her")
	log_line("")


func beckoning_on_a_map():
	log_line("======== Beckoning Light, on a map ========")
	var m = await open_map()
	Campaign.set_party(["alithia"], 14)
	await settle()
	var post := open_row(m)
	var guard := add_guard(m, "Near", post + Vector2i.RIGHT * 3, 180.0)
	var watch = await watch_it(m, post)
	var scene = m.scene
	var her: Vector2 = at(m, post)
	var was: float = guard.global_position.distance_to(her)
	ok(OutsideMoves.refusal(scene, "alithia", "beckoning_light") == "", "there is a guard in reach to beckon", OutsideMoves.refusal(scene, "alithia", "beckoning_light"))
	ok(OutsideMoves.use(scene, "alithia", "beckoning_light"), "cast on him")
	ok(guard.mood == Guard.Mood.BEWILDERED and guard.on_errand(), "he follows the light, his eyes on nothing else", Guard.Mood.keys()[guard.mood])
	ok(guard.errand_at().distance_to(her) > was, "away from her", "%d against %d" % [guard.errand_at().distance_to(her), was])
	ok(Campaign.outside_gates_left("alithia")[1] < Campaign.outside_gates_most("alithia")[1], "through the Gates of Iris", "%s of %s" % [Campaign.outside_gates_left("alithia"), Campaign.outside_gates_most("alithia")])
	await close_map(m)


## A tile with ten open ones in a row to its right, in sight of each other.
func open_row(m: Dictionary) -> Vector2i:
	return find_tile(m, func(tile):
		for step in range(1, 11):
			if not standable(m, tile + Vector2i.RIGHT * step):
				return false
		return m.sight.clear(tile, tile + Vector2i.RIGHT * 5))


func the_dart():
	log_line("======== a dart at a guard's light ========")
	var m = await open_map()
	Campaign.set_party(["cyrus"], 14)
	await settle()
	var post := open_row(m)
	var guard := add_guard(m, "Torch", post + Vector2i.RIGHT * 4, 180.0)
	guard.carries_light_tiles = 4.0
	var lamp := Lamp.new()
	place(m, lamp, post + Vector2i.RIGHT * 8, "Lamp")
	var watch = await watch_it(m, post)
	var scene = m.scene
	ok(watch.lights_for_the_map().size() >= 2, "his light and the lamp light the map")
	var tile: Vector2i = tile_at(m, guard.global_position)
	ok(OutsideMoves.aim_refusal(scene, "cyrus", SkillDatabase.skills.poison_dart, tile) == "", "the dart can be aimed at him", OutsideMoves.aim_refusal(scene, "cyrus", SkillDatabase.skills.poison_dart, tile))
	var encounter_was = Campaign.current_encounter
	ok(OutsideMoves.fire_at(scene, "cyrus", "poison_dart", tile), "let go")
	ok(guard.torch_out, "his light is out")
	ok(not watch.lights_for_the_map().any(func(source): return source.tile == tile_at(m, guard.global_position)), "and lights nothing")
	ok(Campaign.current_encounter == encounter_was and is_instance_valid(scene) and not guard.knocked_out, "no fight, nobody hurt")
	ok(guard.mood == Guard.Mood.RELIGHTING and guard.errand_at().distance_to(lamp.global_position) < 2.0, "off to the lamp to light it again", Guard.Mood.keys()[guard.mood])
	watch._torch_lit_again(guard)
	ok(not guard.torch_out, "and lit again once there")
	# Nothing to light it from: on he goes, dark.
	guard.end_errand()
	lamp.set_lit(false)
	watch._relight()
	ok(watch.snuff_torch(guard), "put out again")
	ok(guard.mood != Guard.Mood.RELIGHTING, "with no lamp lit anywhere, he carries on dark")
	await close_map(m)
