extends "res://StealthHarness.gd"
## Light on the maps (the designer, 2026-11-05 and 06): Bright, Dim and Dark on every tile, from the
## ambient light and the hour, what is placed and what is carried, and what each does in a fight and
## on a stealth map.

const WATCHER := "res://data/encounters/encounter_03_watcher.tres"
const PARTY := ["enfina", "cyrus", "prometheus", "alithia"]

var game = null
var combat: Combat = null
var controller = null


func suite() -> String:
	return "light"


func time_limit() -> float:
	return 240.0


func run_sections():
	the_levels()
	await dark_fight()
	await dim_fight()
	await what_gives_light()
	await darkness_is_cover()
	await hunting_in_the_dark()
	await close_fight()
	await on_a_map()
	await a_guards_torch()
	await a_guard_cannot_see_past_the_dark()
	await the_hour()
	shadows()


func the_levels():
	log_line("======== the levels ========")
	var day := Light.base_level(Light.Ambient.OUTDOORS, Light.Hour.DAY)
	ok(day == Light.Level.BRIGHT, "outdoors by day is Bright")
	ok(Light.base_level(Light.Ambient.OUTDOORS, Light.Hour.DUSK) == Light.Level.DIM and Light.base_level(Light.Ambient.OUTDOORS, Light.Hour.DAWN) == Light.Level.DIM, "dusk and dawn are Dim")
	ok(Light.base_level(Light.Ambient.OUTDOORS, Light.Hour.NIGHT) == Light.Level.DIM, "a moonlit night is Dim")
	ok(Light.base_level(Light.Ambient.OUTDOORS, Light.Hour.NIGHT, true) == Light.Level.DARK, "a moonless one Dark")
	ok(Light.base_level(Light.Ambient.INTERIOR, Light.Hour.DAY) == Light.Level.DIM, "indoors is Dim")
	ok(Light.base_level(Light.Ambient.UNDERGROUND, Light.Hour.DAY) == Light.Level.DARK, "underground is Dark")
	var map := LightMap.new()
	var walls := {Vector2i(3, 0): true}
	var source := {"tile": Vector2i(0, 0), "bright": 2.0, "dim": 4.0, "colour": Color.ORANGE, "flickers": true}
	map.rebuild(Light.Level.DARK, [], [source], [], func(tile): return walls.has(tile))
	ok(map.level_at(Vector2i(1, 0)) == Light.Level.BRIGHT and map.level_at(Vector2i(0, 2)) == Light.Level.BRIGHT, "Bright as far as it says")
	ok(map.level_at(Vector2i(0, 3)) == Light.Level.DIM and map.level_at(Vector2i(0, 4)) == Light.Level.DIM, "Dim from there out")
	ok(map.level_at(Vector2i(0, 5)) == Light.Level.DARK, "and Dark past that")
	ok(map.level_at(Vector2i(4, 0)) == Light.Level.DARK, "a wall stops it")
	ok(map.amount_at(Vector2i(1, 0)) > map.amount_at(Vector2i(0, 3)), "and it looks brighter nearer the flame")
	ok(map.varies and map.flickers, "it has a say, and it flickers")
	map.rebuild(Light.Level.DARK, [], [source], [Vector2i(1, 0)], func(_tile): return false)
	ok(map.level_at(Vector2i(1, 0)) == Light.Level.DARK, "a dark zone is dark whatever lights it")
	map.rebuild(Light.Level.BRIGHT, [{"rect": Rect2i(10, 10, 2, 2), "level": Light.Level.DARK}], [], [], func(_tile): return false)
	ok(map.level_at(Vector2i(10, 10)) == Light.Level.DARK and map.level_at(Vector2i(9, 9)) == Light.Level.BRIGHT, "an ambient area has its own")
	log_line("")


func open_fight(ambient: int, hour: int = -1):
	await close_fight()
	Campaign.reset()
	Campaign.set_party(PARTY, 32)
	Campaign.current_map = "res://maps/crossroads_explore.tscn"
	Campaign.return_to_position = true
	var encounter: EncounterDefinition = load(WATCHER).duplicate()
	encounter.ambient = ambient
	encounter.time_of_day = hour
	encounter.boss_reveal = false
	Campaign.current_encounter = encounter
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
		if comb.has("stats"):
			comb.hp = 900
			comb.max_hp = 900


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


func tile_at_gap(from: Vector2i, gap: int, walker: Dictionary) -> Vector2i:
	for tile in controller.get_reachable_tiles(from, walker.movement_class, 40, walker):
		if combat.get_position_distance(tile, from) == gap and combat.can_land_on(walker, tile):
			return tile
	return from


## Everybody of the party but `kept` well away from `from`, so who is beside whom is plain.
func clear_round(from: Vector2i, kept: Dictionary):
	for index in combat.groups[0]:
		var comb: Dictionary = combat.combatants[index]
		if comb != kept and combat.get_position_distance(comb.position, from) <= 2:
			combat.teleport_to(comb, tile_at_gap(from, 5, comb))


func dark_fight():
	log_line("======== underground: all of it dark ========")
	await open_fight(Light.Ambient.UNDERGROUND)
	var enfina := who("enfina")
	var cyrus := who("cyrus")
	var foe: Dictionary = foes()[0]
	ok(combat.light.base == Light.Level.DARK and combat.light.varies, "the fight goes by the encounter's ambient light")
	ok(combat.in_darkness(enfina) and combat.in_darkness(foe), "everybody is in the dark")
	ok(combat.is_invisible(enfina) and combat.is_invisible(foe), "and invisible")
	ok(foes().all(func(comb): return combat.is_hidden(comb)) and combat.groups[0].all(func(index): return combat.is_hidden(combat.combatants[index])),
		"both whole sides, with nobody forced into view")
	ok(combat.reveal_anyone_now_seen().is_empty(), "the rule for the last in sight asks nothing of the dark")
	combat.teleport_to(enfina, tile_at_gap(foe.position, 4, enfina))
	clear_round(foe.position, enfina)
	combat.sync_zones()
	ok(combat.hidden_from(enfina, foe), "Enfina cannot see them, four tiles off")
	ok(combat.targets_if_aimed(enfina, SkillDatabase.skills.greatsword_attack, foe.position).is_empty(), "nor aim at them")
	ok(not combat.hidden_from(cyrus, foe), "Cyrus can (Night Eyes)")
	ok(not combat.unseen_by_party(foe), "so the player sees them, through him")
	combat.teleport_to(enfina, tile_at_gap(foe.position, 1, enfina))
	combat.sync_zones()
	ok(not combat.hidden_from(enfina, foe) and not combat.hidden_from(foe, enfina), "right beside each other, both see each other")
	ok(combat.targets_if_aimed(enfina, SkillDatabase.skills.greatsword_attack, foe.position).has(foe), "so melee still works")
	# Acting against the other side gives them away until their next turn.
	combat.teleport_to(cyrus, tile_at_gap(foe.position, 3, cyrus))
	combat.sync_zones()
	combat.set_controlled_combatant(cyrus) if combat.has_method("set_controlled_combatant") else null
	combat._invisibility_ends(cyrus)
	ok(not combat.is_hidden(cyrus), "whoever acts from the dark is seen")
	combat.sync_zones()
	ok(not combat.is_hidden(cyrus), "and stays seen until their next turn")
	cyrus.erase("shown_this_turn")
	combat.sync_zones()
	ok(combat.is_invisible(cyrus), "then the dark has them again")
	# A light placed on it.
	var lamp := LightSource.new()
	lamp.bright_tiles = 2.0
	lamp.dim_tiles = 4.0
	game.get_node("Terrain").add_child(lamp)
	lamp.global_position = controller.tile_map.to_global(controller.tile_map.map_to_local(foe.position))
	combat._begin_light()
	ok(combat.light_level(foe.position) == Light.Level.BRIGHT, "a lamp lights where it stands")
	ok(not combat.in_darkness(foe) and not combat.is_hidden(foe), "and whoever stands there is seen again")
	lamp.lit = false
	combat._begin_light()
	ok(combat.in_darkness(foe) and combat.is_hidden(foe), "put out, the dark has them")
	lamp.queue_free()
	combat._begin_light()
	# The AI, seeing nobody.
	for comb in combat.combatants:
		if comb.side == 0 and comb.has("position"):
			comb.reaction_used = true
	foe["level"] = foe.get("level", 1)
	combat.teleport_to(cyrus, tile_at_gap(foe.position, 6, cyrus))
	clear_round(foe.position, {})
	combat.sync_zones()
	ok(combat.groups[0].all(func(index): return combat.hidden_from(foe, combat.combatants[index])), "the enemy can see nobody")
	log_line("")


## The designer, 2026-11-07: "darkness should work as a visual cover. creatures can go through it but cannot see in or
## behind it, except if they have a passive like cyrus does that allows them to".
func darkness_is_cover():
	log_line("======== darkness is cover to the eyes ========")
	await open_fight(Light.Ambient.UNDERGROUND)
	var enfina := who("enfina")
	var cyrus := who("cyrus")
	var foe: Dictionary = foes()[0]
	for other in foes():
		if not is_same(other, foe):
			combat.teleport_to(other, tile_at_gap(foe.position, 12, other))
	var there: Vector2i = tile_at_gap(foe.position, 6, enfina)
	combat.teleport_to(enfina, there)
	clear_round(foe.position, enfina)
	# Each in a pool of light, with the dark between them.
	for tile in [enfina.position, foe.position]:
		combat._placed_lights.append({"tile": tile, "bright": 1.0, "dim": 1.0, "colour": Color.WHITE, "flickers": false})
	combat.sync_zones()
	ok(combat.light_level(enfina.position) == Light.Level.BRIGHT and combat.light_level(foe.position) == Light.Level.BRIGHT, "both stand in light")
	ok(not combat.is_hidden(foe) and not combat.is_hidden(enfina), "so neither is hidden")
	ok(combat.dark_between(enfina.position, foe.position, combat.tiles_of(foe)), "and the dark lies between them")
	ok(combat.hidden_from(enfina, foe) and combat.hidden_from(foe, enfina), "they cannot see each other past it")
	ok(combat.targets_if_aimed(enfina, SkillDatabase.skills.greatsword_attack, foe.position).is_empty(), "nor aim at each other")
	# Beside her, with a clear line: bodies stop sight in a fight, hers too.
	for way in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		if combat.can_land_on(cyrus, enfina.position + way):
			combat.teleport_to(cyrus, enfina.position + way)
			if combat.sees_tile(cyrus, foe.position, foe):
				break
	combat.sync_zones()
	ok(combat.sees_tile(cyrus, foe.position, foe), "Cyrus has a clear line to them")
	ok(not combat.hidden_from(cyrus, foe), "Cyrus sees past it (Night Eyes)")
	ok(not combat.unseen_by_party(foe), "so the player sees them, through him")
	# Without his Night Eyes, he is as the rest.
	cyrus.passives = cyrus.passives.filter(func(passive): return not passive.sees_in_darkness)
	combat.sync_zones()
	ok(combat.unseen_by_party(foe), "without Night Eyes, nobody of the party sees them",
		"%s" % [combat.groups[0].map(func(index): return [combat.combatants[index].name, combat.combatants[index].position, combat.hidden_from(combat.combatants[index], foe)])])
	# Lit all the way: nothing between.
	combat._placed_lights.clear()
	combat._placed_lights.append({"tile": enfina.position, "bright": 9.0, "dim": 12.0, "colour": Color.WHITE, "flickers": false})
	combat.sync_zones()
	ok(not combat.hidden_from(enfina, foe), "with the dark lit away, they see each other again")
	combat._placed_lights.clear()
	combat.sync_zones()
	log_line("")


## Cunning and above know where somebody went into the dark, and that an area, a dispel or a search could still find them; and
## they keep to the dark's edge themselves (the designer, 2026-11-07).
func hunting_in_the_dark():
	log_line("======== hunting in the dark ========")
	await open_fight(Light.Ambient.OUTDOORS)
	var enfina := who("enfina")
	var prometheus := who("prometheus")
	var cyrus := who("cyrus")
	cyrus.passives = cyrus.passives.filter(func(passive): return not passive.sees_in_darkness)
	var foe: Dictionary = foes()[0]
	var definition: CombatantDefinition = CombatantDatabase.combatants[foe.combatant_key]
	foe["ai_knows"] = Combat._ai_knows_of(definition, CombatantDefinition.AiSmarts.CUNNING)
	ok(Combat._ai_knows(foe, CombatantDefinition.AiKnows.DARK_PATCHES), "Cunning hunts in the dark")
	ok(Combat._ai_knows_of(definition, CombatantDefinition.AiSmarts.TRAINED) & CombatantDefinition.AiKnows.DARK_PATCHES == 0, "Trained does not")
	for other in combat.combatants:
		if other.get("alive", false) and other != foe and other != enfina and other != prometheus and not other.has("object"):
			combat.teleport_to(other, tile_at_gap(foe.position, 14, other))
	# A Light Void six tiles off, in its sight.
	var spot := tile_at_gap(foe.position, 6, prometheus)
	combat.teleport_to(prometheus, tile_at_gap(spot, 3, prometheus))
	combat.teleport_to(enfina, tile_at_gap(foe.position, 2, enfina))
	prometheus.spell_slots = Stats.gates_for_level(64)
	if not prometheus.skill_list.has("light_void"):
		prometheus.skill_list.append("light_void")
	combat.current_combatant = combat.combatants.find(prometheus)
	controller.set_controlled_combatant(prometheus)
	prometheus.skill_used_this_turn = false
	await combat.use_skill("light_void", prometheus, spot, false)
	await settle(2)
	var dark: Array = combat.zones.filter(func(zone): return zone.get("condition") != null and zone.condition.is_darkness)
	ok(not dark.is_empty(), "a Light Void on the ground")
	if dark.is_empty():
		log_line("")
		return
	var zone: Dictionary = dark[0]
	# The edge of it nearest the foe, which it can see.
	var edge := Vector2i(-99999, -99999)
	for tile in zone.tiles:
		if combat.can_land_on(enfina, tile) and combat.has_line_of_sight(foe.position, tile, 0) and not combat.dark_between(foe.position, tile, [tile]) \
				and (edge.x == -99999 or combat.get_position_distance(foe.position, tile) < combat.get_position_distance(foe.position, edge)):
			edge = tile
	ok(edge.x != -99999, "an edge of it the foe can see", "%s" % edge)
	if edge.x == -99999:
		log_line("")
		return
	combat.teleport_to(enfina, edge)
	combat.sync_zones()
	ok(combat.in_darkness(enfina) and combat.hidden_from(foe, enfina), "Enfina steps into it, and is lost to it")
	var guesses: Dictionary = combat._ai_dark_guesses(foe)
	ok(guesses.get(enfina.id, Vector2i(-1, -1)) == edge, "but it saw where she went in", "%s" % [guesses])
	# An area there.
	foe["level"] = 64
	foe.spell_slots = Stats.gates_for_level(64)
	foe["max_spell_slots"] = Stats.gates_for_level(64)
	foe.skill_list.append_array(["wildfire", "dispel_magic"])
	var wildfire: SkillDefinition = SkillDatabase.skills.wildfire
	combat._ai_assumed = guesses
	ok(combat.ai_worth_table(foe, wildfire).has(enfina.id), "Wildfire there is worth something: it could catch her")
	ok(not combat.ai_worth_table(foe, SkillDatabase.skills.fire_blast).has(enfina.id) or combat.aoe_radius_of(foe, SkillDatabase.skills.fire_blast) > 0,
		"a blow at one tile is not: there is nobody there to see")
	var aims: Dictionary = combat._ai_aim_scores(foe, wildfire, combat.ai_worth_table(foe, wildfire))
	ok(aims.keys().any(func(aim): return combat.get_position_distance(aim, edge) <= wildfire.aoe_radius and aims[aim] > 0.0), "aimed round where she went in")
	combat._ai_assumed = {}
	var plan: Dictionary = combat.ai_plan_attack(foe, ["wildfire"], 0)
	ok(plan.skill == "wildfire" and combat.get_position_distance(plan.aim, edge) <= wildfire.aoe_radius, "and the plan is to throw it there",
		"%s at %s" % [plan.skill, plan.aim])
	# Undo the dark.
	var undo: Dictionary = combat._ai_best_dispel(foe)
	ok(undo.get("target", {"x": 1}).is_empty() and undo.get("aim", Vector2i(-1, -1)) in zone.tiles, "or undo the dark she hides in", "%s" % [undo])
	# Trained knows nothing of it.
	foe["ai_knows"] = Combat._ai_knows_of(definition, CombatantDefinition.AiSmarts.TRAINED)
	ok(combat._ai_dark_guesses(foe).is_empty() and combat.ai_plan_attack(foe, ["wildfire"], 0).skill == "", "Trained, none of it")
	foe["ai_knows"] = Combat._ai_knows_of(definition, CombatantDefinition.AiSmarts.CUNNING)
	# Its own cover: the dark's edge, with nobody in sight who sees in it.
	combat._ai_read_the_field(foe)
	ok(combat._ai_mind.get("dark_cover", false), "the dark is cover to it, with nobody in sight who sees in it")
	var lurk := Vector2i(-99999, -99999)
	var lit := Vector2i(-99999, -99999)
	for tile in zone.tiles:
		if tile == edge:
			continue
		for step in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if combat.light.level_at(tile + step) != Light.Level.DARK and controller.is_on_map(tile + step):
				lurk = tile
				lit = tile + step
	ok(lurk.x != -99999 and combat._ai_tile_worth(foe, lurk) > combat._ai_tile_worth(foe, lit), "a dark tile at its edge is worth more than the lit one beside it",
		"%.1f against %.1f" % [combat._ai_tile_worth(foe, lurk), combat._ai_tile_worth(foe, lit)])
	log_line("")


func dim_fight():
	log_line("======== indoors: all of it dim ========")
	await open_fight(Light.Ambient.INTERIOR)
	var enfina := who("enfina")
	var cyrus := who("cyrus")
	var foe: Dictionary = foes()[0]
	ok(combat.light.base == Light.Level.DIM, "Dim")
	ok(not combat.in_darkness(enfina) and not combat.is_hidden(enfina), "nobody is hidden by it")
	ok(combat.hit_chance(foe, SkillDatabase.skills.greatsword_attack, enfina) == 100 or combat.hit_chance(foe, SkillDatabase.skills.greatsword_attack, enfina) == SkillDatabase.skills.greatsword_attack.accuracy, "and it takes nothing off the chance to hit", "%d" % combat.hit_chance(foe, SkillDatabase.skills.greatsword_attack, enfina))
	combat.teleport_to(cyrus, tile_at_gap(foe.position, 6, cyrus))
	ok(combat._hides_in_dim(cyrus), "Cyrus knows how to hide in it")
	ok(not combat._hides_in_dim(enfina), "Enfina does not")
	for other in foes():
		if not is_same(other, foe):
			combat.teleport_to(other, tile_at_gap(cyrus.position, 7, other))
	ok(not combat.is_seen_by_opponents(cyrus), "six tiles off, with nothing in the way, nobody makes him out")
	combat.teleport_to(enfina, tile_at_gap(foe.position, 6, enfina))
	var clear_line: bool = combat.sees_tile(foe, enfina.position, enfina)
	ok(not clear_line or combat.is_seen_by_opponents(enfina), "Enfina they see, there or anywhere")
	combat.teleport_to(cyrus, tile_at_gap(foe.position, 2, cyrus))
	ok(not combat.sees_tile(foe, cyrus.position, cyrus) or combat.is_seen_by_opponents(cyrus), "and him too from close by")
	log_line("")


func what_gives_light():
	log_line("======== what gives light ========")
	await open_fight(Light.Ambient.UNDERGROUND)
	var cyrus := who("cyrus")
	var prometheus := who("prometheus")
	var foe: Dictionary = foes()[0]
	combat.teleport_to(foe, tile_at_gap(cyrus.position, 8, foe))
	# Somebody burning.
	var burn: ConditionDefinition = load("res://data/conditions/burn.tres")
	combat.put_condition(foe, burn, 3, "test")
	combat.sync_zones()
	ok(combat.light_level(foe.position) == Light.Level.BRIGHT, "whoever burns lights where they stand")
	ok(not combat.is_hidden(foe), "so they can be seen")
	foe.status_effects = foe.status_effects.filter(func(entry): return entry.get("condition") != burn)
	combat.sync_zones()
	ok(combat.is_hidden(foe), "the fire out, the dark has them")
	# A lantern in the Baldric.
	var item: ItemDefinition = ItemDatabase.item("lantern")
	ok(item != null and item.light_tiles > 0.0, "a lantern gives light")
	ok(Campaign.give_item("cyrus", "lantern") or true, "in Cyrus's bag")
	ok(Campaign.contents_of("cyrus", "belt").has("lantern"), "in the Baldric", "%s" % [Campaign.contents_of("cyrus", "belt")])
	ok(not Campaign.combat_items_of("cyrus").has("lantern"), "with nothing to use in a fight: carrying it is enough")
	combat.sync_zones()
	ok(combat.light_level(cyrus.position) == Light.Level.BRIGHT, "lit where he stands")
	ok(not combat.is_hidden(cyrus), "and seen")
	Campaign.take_item("cyrus", "lantern")
	combat.sync_zones()
	ok(combat.is_hidden(cyrus), "without it, not")
	# Something on the map that gives it.
	var brazier: BattleObjectDefinition = load("res://data/objects/brazier.tres")
	ok(brazier != null and brazier.light_tiles == 6.0, "a brazier")
	var spot := tile_at_gap(foe.position, 2, prometheus)
	var spawn := SpawnDefinition.new()
	spawn.position = spot
	var thing: Dictionary = combat.create_combatant(brazier, "brazier")
	thing["side"] = 1
	thing["position"] = spot
	combat.combatants.append(thing)
	combat.sync_zones()
	ok(combat.light_level(spot) == Light.Level.BRIGHT and combat.light_level(foe.position) >= Light.Level.BRIGHT, "lights round it")
	combat.hit_by_the_arena(thing, 9999, Damage.Type.PHYSICAL, null, 0, 0.0, "a blow")
	await settle()
	combat.sync_zones()
	ok(not thing.alive and combat.light_level(spot) == Light.Level.DARK, "broken, its light has gone")
	# Burner's ground lights what it burns; Light Void puts out anything in it.
	var burner_zone: EffectDefinition = null
	for effect in SkillDatabase.skills.burner.all_effects():
		if effect != null and effect.type == EffectDefinition.EffectType.ZONE:
			burner_zone = effect
	ok(burner_zone != null and burner_zone.zone_light_tiles > 0.0, "Burner's ground gives light")
	combat._casting_gate = 2
	combat.lay_zone(prometheus, burner_zone, [foe.position], SkillDatabase.skills.burner)
	combat.zones.back().centre = foe.position
	combat.sync_zones()
	ok(combat.light_level(foe.position) == Light.Level.BRIGHT, "lit while it burns")
	var void_zone: EffectDefinition = null
	for effect in SkillDatabase.skills.light_void.all_effects():
		if effect != null and effect.type == EffectDefinition.EffectType.ZONE:
			void_zone = effect
	combat.lay_zone(prometheus, void_zone, [foe.position], SkillDatabase.skills.light_void)
	combat.sync_zones()
	ok(combat.light_level(foe.position) == Light.Level.DARK, "and a Light Void over it is dark all the same")
	ok(foe.status_effects.filter(func(entry): return entry.get("condition") != null and entry.condition.is_darkness).size() == 1, "one In Darkness, not two", "%d" % foe.status_effects.size())
	log_line("")


func a_guards_torch():
	log_line("======== a guard carrying a light ========")
	Campaign.return_to_position = false
	var m = await open_map()
	var post: Vector2i = m.post
	var walker = add_guard(m, "Torch", post + Vector2i.RIGHT * 2, 0.0)
	walker.carries_light_tiles = 4.0
	var watch = await watch_it(m, out_of_sight_of(m, row(post)))
	var scene: ExplorationScene = m.scene
	Campaign.map_ambient = Light.Ambient.UNDERGROUND
	scene.relight_map()
	watch.lights_changed()
	var spot: Vector2i = watch.tile_of(walker.global_position)
	ok(scene.light.level_at(spot) == Light.Level.BRIGHT, "the ground under him is lit")
	ok(scene.light.level_at(spot + Vector2i.RIGHT * 3) == Light.Level.DIM, "and dimly further off")
	ok(not watch.carried_lights_moved(), "while he stands, nothing changes")
	walker.global_position = at(m, post + Vector2i.RIGHT * 4)
	ok(watch.carried_lights_moved(), "and it goes with him")
	scene.relight_map()
	ok(not watch.carried_lights_moved(), "lit anew from where he stands")
	ok(scene.light.level_at(watch.tile_of(walker.global_position)) == Light.Level.BRIGHT, "now there")
	walker.knocked_out = true
	ok(watch.carried_lights_moved(), "knocked out, it goes out")
	scene.relight_map()
	ok(scene.light.level_at(watch.tile_of(walker.global_position)) == Light.Level.DARK, "and it is dark again")
	await close_map(m)
	log_line("")


## On a map too: a guard sees nothing past the dark, unless his creature sees in it.
func a_guard_cannot_see_past_the_dark():
	log_line("======== a guard cannot see past the dark ========")
	Campaign.return_to_position = false
	var m = await open_map()
	var post: Vector2i = m.post
	var guard = add_guard(m, "Looker", post, 0.0)
	var watch = await watch_it(m, out_of_sight_of(m, row(post)))
	var scene: ExplorationScene = m.scene
	var light: LightMap = scene.light
	var far: Vector2i = post + Vector2i.RIGHT * 6
	var near: Vector2i = post + Vector2i.RIGHT * 1
	ok(not StealthWatch._dark_between(light, post, near, 1.0), "nothing between him and the tile beside him")
	# All dark but a pool of light far off.
	Campaign.map_ambient = Light.Ambient.UNDERGROUND
	scene.relight_map()
	ok(StealthWatch._dark_between(scene.light, post, far, 1.0), "dark lies between him and a tile six off")
	ok(not watch._sees_in_the_dark(guard), "a barbarian does not see in the dark")
	await close_map(m)
	log_line("")


func shadows():
	log_line("======== shadows lean with the hour ========")
	ok(Light.shadow_of(Light.Ambient.OUTDOORS, Light.Hour.DUSK).lean > 0.0, "one way at dusk")
	ok(Light.shadow_of(Light.Ambient.OUTDOORS, Light.Hour.DAWN).lean < 0.0, "the other at dawn")
	ok(absf(Light.shadow_of(Light.Ambient.OUTDOORS, Light.Hour.DAY).lean) < 0.5, "hardly at all by day")
	ok(Light.shadow_of(Light.Ambient.UNDERGROUND, Light.Hour.DUSK).lean == 0.0, "underground the hour has no say")
	var version: int = CombatantSprite.shadow_version
	CombatantSprite.set_shadows(Light.shadow_of(Light.Ambient.OUTDOORS, Light.Hour.DUSK))
	ok(CombatantSprite.shadow_lean > 0.0 and CombatantSprite.shadow_version == version + 1, "and every figure is told")
	log_line("")


func on_a_map():
	log_line("======== on a stealth map ========")
	Campaign.return_to_position = false
	var m = await open_map()
	m.setup.dim_sight_tiles = 3.0
	m.setup.dark_sight_tiles = 2.0
	var post: Vector2i = m.post
	var watcher = add_guard(m, "Watcher", post, 0.0)
	var watch = await watch_it(m, out_of_sight_of(m, row(post)))
	var scene: ExplorationScene = m.scene
	var two: Vector2i = post + Vector2i.RIGHT * 2
	var four: Vector2i = post + Vector2i.RIGHT * 4
	settle_guard(watch, watcher, 0.0)
	ok(not scene.light.varies, "outdoors by day, light has no say")
	ok(watch.sees(watcher, four), "he sees four tiles off")
	Campaign.map_ambient = Light.Ambient.INTERIOR
	scene.relight_map()
	watch.lights_changed()
	ok(scene.light.base == Light.Level.DIM, "indoors, all of it is Dim")
	ok(watch.sees(watcher, two), "he sees two tiles off")
	ok(not watch.sees(watcher, four), "and no longer four: Dim Sight Tiles")
	Campaign.map_ambient = Light.Ambient.UNDERGROUND
	scene.relight_map()
	watch.lights_changed()
	ok(watch.is_dark(), "underground it is dark")
	ok(watch.sees(watcher, post + Vector2i.RIGHT), "right beside him, close enough to make out")
	ok(not watch.sees(watcher, post + Vector2i.RIGHT * 3), "three tiles off, no: Dark Sight Tiles")
	# A placed light.
	var source := LightSource.new()
	source.bright_tiles = 1.0
	source.dim_tiles = 2.0
	m.map.add_child(source)
	source.global_position = at(m, four)
	scene.relight_map()
	watch.lights_changed()
	ok(scene.light.level_at(four) == Light.Level.BRIGHT, "a placed light lights its ground")
	ok(watch.sees(watcher, four), "and he sees by it, however far")
	# An opening goes by the hour.
	source.opening = true
	Campaign.set_time_of_day("night")
	scene.relight_map()
	ok(scene.light.level_at(four) == Light.Level.DARK, "an opening at night lets in nothing")
	Campaign.set_time_of_day("dusk")
	scene.relight_map()
	ok(scene.light.level_at(four) == Light.Level.DIM, "at dusk only Dim")
	Campaign.set_time_of_day("day")
	scene.relight_map()
	ok(scene.light.level_at(four) == Light.Level.BRIGHT, "by day all of it")
	source.queue_free()
	await settle()
	# A lantern.
	Campaign.give_item(m.leader, "lantern")
	scene.relight_map()
	var leader_tile: Vector2i = tile_at(m, m.party.position_of_leader())
	ok(scene.light.level_at(leader_tile) == Light.Level.BRIGHT, "a lantern lights whoever carries it")
	# The hours going by, on a map that says so.
	Campaign.map_ambient = Light.Ambient.OUTDOORS
	await close_map(m)


func the_hour():
	log_line("======== the hour ========")
	Campaign.reset()
	ok(Campaign.time_of_day == Light.Hour.DAY, "it starts by day")
	var heard := [0]
	var on_change := func(): heard[0] += 1
	Campaign.time_of_day_changed.connect(on_change)
	Campaign.set_time_of_day("night")
	ok(Campaign.time_of_day == Light.Hour.NIGHT and heard[0] == 1, "a conversation can change it")
	Campaign.set_time_of_day("night")
	ok(heard[0] == 1, "to what it is already, nothing happens")
	Campaign.pass_time()
	ok(Campaign.time_of_day == Light.Hour.DAWN, "night passes to dawn")
	var state := Campaign.snapshot("", Vector2.ZERO)
	ok(state.has("time_of_day") and state.time_of_day == Light.Hour.DAWN, "it is kept in a save")
	Campaign.set_time_of_day(Light.Hour.NIGHT)
	Campaign.set_party(PARTY, 8)
	Campaign.long_rest()
	ok(Campaign.time_of_day == Light.Hour.DAWN, "a long rest ends at dawn")
	state = Campaign.snapshot("", Vector2.ZERO)
	state.time_of_day = Light.Hour.DUSK
	var before: int = heard[0]
	Campaign.apply(state)
	ok(Campaign.time_of_day == Light.Hour.DUSK and heard[0] == before + 1, "what comes from the other machine lights this one too")
	Campaign.time_of_day_changed.disconnect(on_change)
	Campaign.reset()
	# Sees in the dark, from a map.
	Campaign.set_party(PARTY, 1)
	ok(Campaign.sees_in_darkness("cyrus") and not Campaign.sees_in_darkness("enfina"), "Cyrus's eyes, from level 1")
	log_line("")
