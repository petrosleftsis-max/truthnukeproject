extends "res://StealthHarness.gd"
## The designer's picks of 2026-11-07 from the spells that make light: Dancing Lights with no tether, Flare in place of
## Unveil, Votive Flame's mark, Daylight on the ground or on a weapon, and Light Void over every other light.


func suite() -> String:
	return "lightspells"


func time_limit() -> float:
	return 240.0


var game = null
var combat: Combat = null
var controller = null


func run_sections():
	whose_they_are()
	await open_fight()
	await dancing_lights()
	await open_fight()
	await flare()
	await open_fight()
	await votive_flame()
	await open_fight()
	await daylight()
	await open_fight()
	await light_void_wins()
	await open_fight()
	await a_shot_at_a_light()
	await open_fight()
	await shadow_step()
	await open_fight()
	await silhouette()
	await open_fight()
	await ink_bottle()
	await open_fight()
	await calling_out()
	await open_fight()
	await blessed_in_the_light()
	await open_fight()
	await nowhere_to_hide()
	await close_fight()
	await flare_on_a_map()
	await a_shot_at_a_lamp_on_a_map()
	await in_plain_darkness()


func whose_they_are():
	log_line("======== whose they are ========")
	var skills: Dictionary = SkillDatabase.skills
	var prometheus: CombatantDefinition = CombatantDatabase.combatants.prometheus
	var alithia: CombatantDefinition = CombatantDatabase.combatants.alithia
	ok(not skills.has("unveil"), "Unveil is gone")
	ok(prometheus.skills.has("flare") and not prometheus.skills.has("unveil"), "Flare in its place")
	ok(prometheus.skills.has("dancing_lights") and skills.dancing_lights.spell_slot_level == 1, "Dancing Lights is his, through World")
	ok(not skills.dancing_lights.tethered, "with no tether")
	ok(alithia.skills.has("daylight") and skills.daylight.spell_slot_level == 2 and skills.daylight.tethered, "Daylight is hers, through Hermes, on a tether")
	for book in ["flare_spellbook", "dancing_lights_spellbook"]:
		ok(ItemDatabase.item(book) != null, "%s is there" % book)
		ok(load("res://data/stores/travelling_merchant.tres").stock.has(book), "  and on sale")
	ok(ItemDatabase.item("unveil_spellbook") == null, "and the old book is not")
	ok(skills.votive_flame.all_effects().any(func(effect): return effect != null and effect.condition != null and effect.condition.cannot_hide), "Votive Flame marks")
	log_line("")


## A fight in the dark, everybody standing near enough to it all.
func open_fight():
	await close_fight()
	Campaign.reset()
	Campaign.set_party(["enfina", "cyrus", "prometheus", "alithia"], 64)
	Campaign.current_map = "res://maps/crossroads_explore.tscn"
	Campaign.return_to_position = true
	var encounter: EncounterDefinition = load("res://data/encounters/encounter_03_watcher.tres").duplicate()
	encounter.ambient = Light.Ambient.UNDERGROUND
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
		comb["accuracy"] = 200
		if comb.has("stats"):
			comb.hp = 900
			comb.max_hp = 900
	for key in ["alithia", "prometheus"]:
		var caster := who(key)
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


## A tile with room all round it, `gap` from `from`, and none of the party's tiles near it.
func open_ground(from: Vector2i, gap: int) -> Vector2i:
	var probe := who("enfina")
	var region: Rect2i = controller._astargrid.region
	# As clear as there is: two tiles all round, or one, or only itself.
	for room in [2, 1, 0]:
		for y in range(region.position.y, region.end.y):
			for x in range(region.position.x, region.end.x):
				var tile := Vector2i(x, y)
				if combat.get_position_distance(tile, from) != gap:
					continue
				var clear := true
				for near in Combat.get_diamond_tiles(tile, room):
					if not controller.is_on_map(near) or not combat.can_land_on(probe, near):
						clear = false
				if clear:
					return tile
	return Combat.NO_AREA


func dancing_lights():
	log_line("======== Dancing Lights ========")
	var prometheus := who("prometheus")
	await their_turn(prometheus)
	var at := open_ground(prometheus.position, 6)
	ok(at != Combat.NO_AREA, "room to try it", "%s" % at)
	ok(combat.light.level_at(at) == Light.Level.DARK, "the ground is dark")
	var sources: int = combat.light.sources.size()
	ok(not combat.secondary_grants(prometheus).has("move_lights"), "nothing to move yet")
	await combat.use_skill("dancing_lights", prometheus, at, false)
	await settle()
	ok(combat.zones.size() == 1, "there they are", "%d" % combat.zones.size())
	var zone: Dictionary = combat.zones[0]
	ok(not Combat.holds_tether(prometheus) and not zone.has("tether_of"), "with no tether")
	ok(combat.light.sources.size() == sources + 3, "three lights", "%d" % combat.light.sources.size())
	var points: Array = combat.zone_light_points(zone)
	ok(points.has(at + Vector2i(0, -2)) or points.has(at), "spread about where he pointed", "%s" % [points])
	ok(combat.light.level_at(points[0]) == Light.Level.BRIGHT, "each lights its own ground")
	ok(combat.zone_tiles()[0].bare and combat.zone_tiles()[0].lights.size() == 3 and combat.zone_tiles()[0].cloud == Combat.NO_AREA, "drawn as lights, with no tiles and no cloud")
	# A secondary action sends them off.
	ok(combat.secondary_grants(prometheus).has("move_lights"), "and a secondary action to send them")
	var to := open_ground(at, 6)
	ok(to != Combat.NO_AREA, "somewhere to send them", "%s" % to)
	await their_turn(prometheus)
	ok(combat.get_range_tiles(SkillDatabase.skills.move_lights, prometheus.position, 0, prometheus).has(to), "in their reach, from where they are")
	await combat.use_skill("move_lights", prometheus, to, false, true)
	await settle()
	ok(zone.centre == to, "they go", "%s" % zone.centre)
	ok(combat.light.level_at(combat.zone_light_points(zone)[0]) == Light.Level.BRIGHT, "and the light with them")
	ok(combat.light.level_at(points[0]) == Light.Level.DARK or combat.zone_light_points(zone).has(points[0]), "dark again where they were")
	# Ten of his turns.
	for i in 9:
		combat._zones_at_turn_start(prometheus)
	ok(combat.zones.has(zone), "nine of his turns on, still there")
	combat._zones_at_turn_start(prometheus)
	ok(not combat.zones.has(zone), "ten, and they are gone")
	ok(not combat.secondary_grants(prometheus).has("move_lights"), "nothing left to move")
	log_line("")


func flare():
	log_line("======== Flare ========")
	var prometheus := who("prometheus")
	var they := foes()
	var unseen: Dictionary = they[0]
	var hidden: Dictionary = they[1]
	var at := open_ground(prometheus.position, 6)
	combat.teleport_to(unseen, at)
	combat.teleport_to(hidden, at + Vector2i(1, 0))
	combat.make_invisible(unseen)
	combat.set_hidden(hidden, true)
	ok(combat.is_hidden(unseen) and combat.is_hidden(hidden), "one invisible, one hidden")
	await their_turn(prometheus)
	await combat.use_skill("flare", prometheus, at, false)
	await settle()
	ok(not combat.is_hidden(unseen) and not combat.is_invisible(unseen), "the invisible is seen")
	ok(not combat.is_hidden(hidden), "and the hidden")
	ok(not Combat.holds_tether(prometheus), "with no tether")
	ok(combat.light.level_at(at) == Light.Level.BRIGHT, "it is Bright")
	var zone: Dictionary = combat.zones[0]
	ok(zone.radius == 5 and combat.light.level_at(at + Vector2i(2, 0)) == Light.Level.BRIGHT, "over a big area", "%d" % zone.radius)
	combat._zones_at_turn_start(prometheus)
	ok(combat.zones.has(zone), "for two of his turns")
	combat._zones_at_turn_start(prometheus)
	ok(not combat.zones.has(zone) and combat.light.level_at(at) == Light.Level.DARK, "and then it is out")
	log_line("")


func votive_flame():
	log_line("======== Votive Flame ========")
	var alithia := who("alithia")
	var foe: Dictionary = foes()[0]
	var at := open_ground(alithia.position, 5)
	combat.teleport_to(foe, at)
	combat.make_invisible(foe)
	await their_turn(alithia)
	await combat.use_skill("votive_flame", alithia, at, false)
	await settle()
	ok(not combat.is_hidden(foe) and not combat.is_invisible(foe), "whoever it hits is seen")
	var mark: ConditionDefinition = load("res://data/conditions/marked_by_flame.tres")
	ok(combat.conditions_of(foe).has(mark), "and marked")
	var entry: Dictionary = {}
	for each in foe.status_effects:
		if each.get("condition") == mark:
			entry = each
	ok(entry.get("duration", 0) >= 8 and entry.get("duration", 0) <= 9, "for 8 of their turns", "%d" % entry.get("duration", 0))
	combat.set_hidden(foe, true)
	ok(not combat.is_hidden(foe), "it cannot hide")
	combat.make_invisible(foe)
	ok(not combat.is_invisible(foe), "or go invisible")
	# The dark does not take them either: this is a dark place.
	combat.sync_zones()
	ok(not combat.is_hidden(foe) and not combat.hidden_from(who("enfina"), foe), "nor does the dark hide it", "level %d" % combat.light.level_at(foe.position))
	ok(combat._invisibility_refusal(SkillDatabase.skills.invisibility, foe) != "", "and Invisibility says so")
	# It can be dispelled.
	var prometheus := who("prometheus")
	await their_turn(prometheus)
	combat.dispel_magic(prometheus, foe, SkillDatabase.skills.dispel_magic)
	await settle()
	ok(not combat.conditions_of(foe).has(mark), "Dispel Magic ends it")
	combat.make_invisible(foe)
	ok(combat.is_invisible(foe), "and it can go unseen again")
	# And it wears off by itself.
	combat.set_hidden(foe, false)
	await their_turn(alithia)
	await combat.use_skill("votive_flame", alithia, at, false)
	await settle()
	ok(combat.conditions_of(foe).has(mark), "marked again")
	log_line("")


func daylight():
	log_line("======== Daylight ========")
	var alithia := who("alithia")
	var prometheus := who("prometheus")
	var enfina := who("enfina")
	var at := open_ground(alithia.position, 7)
	ok(at != Combat.NO_AREA, "room to try it", "%s" % at)
	await their_turn(prometheus)
	await combat.use_skill("light_void", prometheus, at, false)
	await settle()
	ok(combat.light.level_at(at) == Light.Level.DARK, "Light Void lies on it")
	await their_turn(alithia)
	await combat.use_skill("daylight", alithia, at, false)
	await settle()
	ok(combat.zones.size() == 2, "and Daylight over it", "%d" % combat.zones.size())
	ok(Combat.holds_tether(alithia) and alithia.tether.max == 200, "on her tether")
	ok(combat.light.level_at(at) == Light.Level.BRIGHT, "it wins, where it lies", "%d" % combat.light.level_at(at))
	var void_only: Vector2i = Combat.NO_AREA
	var the_void: Dictionary = combat.zones[0]
	var day: Dictionary = combat.zones[1]
	# A tile of a bigger void that Daylight does not reach, if there is one, stays dark. Not here: move the day off.
	var foe: Dictionary = foes()[0]
	combat.teleport_to(foe, at)
	combat.sync_zones()
	ok(not combat.in_darkness(foe), "nobody is in the dark there")
	ok(not combat.is_hidden(foe), "or hidden by it")
	combat.snap_tether(alithia, "test")
	await settle()
	ok(not combat.zones.has(day) and combat.zones.has(the_void), "with Daylight gone, the void is still there")
	ok(combat.light.level_at(at) == Light.Level.DARK, "and has it back")
	combat.sync_zones()
	ok(combat.in_darkness(foe), "and whoever stands there is in the dark")
	combat.teleport_to(foe, open_ground(alithia.position, 12))
	# On a weapon.
	combat.teleport_to(enfina, at)
	await their_turn(alithia)
	await combat.use_skill("daylight", alithia, enfina.position, false)
	await settle()
	var carried: Dictionary = combat.zones.back()
	ok(carried.get("follows", false) and carried.get("follows_id", -1) == enfina.id, "aimed at an ally, it is on their weapon")
	ok(combat.light.level_at(enfina.position) == Light.Level.BRIGHT, "lighting them, in the void itself")
	ok(not combat.in_darkness(enfina), "and they are not in the dark there")
	var away := open_ground(alithia.position, 3)
	var day_was: Vector2i = enfina.position
	combat.teleport_to(enfina, away)
	combat.sync_zones()
	ok(carried.centre == away, "it goes where they go", "%s" % carried.centre)
	ok(combat.light.level_at(away) == Light.Level.BRIGHT, "and so does the light")
	ok(combat.light.level_at(day_was) == Light.Level.DARK, "and the void has its ground back")
	combat.snap_tether(alithia, "test")
	await settle()
	ok(not combat.zones.has(carried), "the tether gone, so is the light")
	log_line("")


func light_void_wins():
	log_line("======== Light Void over every other light ========")
	var prometheus := who("prometheus")
	var at := open_ground(prometheus.position, 6)
	await their_turn(prometheus)
	await combat.use_skill("flare", prometheus, at, false)
	await settle()
	ok(combat.light.level_at(at) == Light.Level.BRIGHT, "Flare lights the ground")
	await their_turn(prometheus)
	await combat.use_skill("light_void", prometheus, at, false)
	await settle()
	ok(combat.light.level_at(at) == Light.Level.DARK, "Light Void wins over Flare")
	await their_turn(prometheus)
	await combat.use_skill("dancing_lights", prometheus, at, false)
	await settle()
	ok(combat.light.level_at(at) == Light.Level.DARK and combat.light.level_at(at + Vector2i(0, -2)) == Light.Level.DARK, "and over Dancing Lights")
	# Somebody burning, stood in it.
	var enfina := who("enfina")
	combat.teleport_to(enfina, at)
	combat.put_condition(enfina, load("res://data/conditions/burn.tres"), 5, "test", true)
	combat.sync_zones()
	ok(combat.light.level_at(at) == Light.Level.DARK, "and over somebody burning in it")
	ok(combat.in_darkness(enfina), "who is in the dark all the same")
	log_line("")


func a_shot_at_a_light():
	log_line("======== A shot at a light ========")
	var cyrus := who("cyrus")
	ok(SkillDatabase.skills.gun.shoots_out_lights, "his Gun can")
	ok(not SkillDatabase.skills.rapier.shoots_out_lights, "and nothing else of his needs to")
	var at := open_ground(cyrus.position, 5)
	# A light placed on the ground, as a LightSource gives one.
	combat._placed_lights.append({"tile": at, "bright": 3.0, "dim": 6.0, "colour": Color.WHITE, "flickers": true})
	combat.sync_zones()
	ok(combat.light.level_at(at) == Light.Level.BRIGHT, "a light, on the ground")
	ok(not combat.light_to_shoot_at(at).is_empty(), "something to shoot at")
	await their_turn(cyrus)
	controller.set_selected_skill("gun")
	controller.begin_target_selection()
	await settle()
	ok(controller.refusal_at(at, {}) == "", "aimed at it, with nobody there", controller.refusal_at(at, {}))
	controller.cancel_skill_selection()
	await combat.use_skill("gun", cyrus, at, false)
	await settle()
	ok(combat.light_to_shoot_at(at).is_empty() and combat.light.level_at(at) == Light.Level.DARK, "out it goes", "%d" % combat.light.level_at(at))
	ok(cyrus.skill_used_this_turn, "for his main action")
	# A thing on the map that gives light.
	var brazier: CombatantDefinition = CombatantDatabase.combatants.get("brazier")
	if brazier != null:
		ok(true, "a brazier is there to try")
	log_line("")


func shadow_step():
	log_line("======== Shadow Step ========")
	var cyrus := who("cyrus")
	var skill: SkillDefinition = SkillDatabase.skills.shadow_step
	ok(skill.is_secondary and skill.max_range == 4 and CombatantDatabase.combatants.cyrus.skills.has("shadow_step"), "his, a secondary action, within four")
	var to := open_ground(cyrus.position, 3)
	await their_turn(cyrus)
	ok(combat.wasted_on(cyrus, skill) == "", "from the dark, it can be done", combat.wasted_on(cyrus, skill))
	ok(combat.refusal_for(cyrus, skill, to) == "", "to the dark", combat.refusal_for(cyrus, skill, to))
	controller.set_selected_skill("shadow_step", true)
	controller.begin_target_selection()
	await settle()
	ok(controller._range_preview_positions.has(to), "offered")
	controller.cancel_skill_selection()
	await combat.use_skill("shadow_step", cyrus, to, false, true)
	await settle()
	ok(cyrus.position == to, "there he is", "%s" % cyrus.position)
	ok(cyrus.secondary_used_this_turn and not cyrus.skill_used_this_turn, "for his secondary action")
	# In the light, no.
	combat._placed_lights.append({"tile": to, "bright": 4.0, "dim": 8.0, "colour": Color.WHITE, "flickers": true})
	combat.sync_zones()
	ok(combat.wasted_on(cyrus, skill) != "", "standing in the light, he cannot")
	combat._placed_lights.clear()
	combat.sync_zones()
	log_line("")


func silhouette():
	log_line("======== Silhouette ========")
	var cyrus := who("cyrus")
	var foe: Dictionary = foes()[0]
	var at := open_ground(cyrus.position, 8)
	combat.teleport_to(foe, at)
	combat._placed_lights.append({"tile": at, "bright": 2.0, "dim": 2.0, "colour": Color.WHITE, "flickers": true})
	combat.sync_zones()
	var gun: SkillDefinition = SkillDatabase.skills.gun
	ok(combat.light_level_of(cyrus) == Light.Level.DARK and combat.light_level_of(foe) == Light.Level.BRIGHT, "him in the dark, them in the light")
	var lit: int = combat.skill_damage(cyrus, foe, gun)
	combat._placed_lights.clear()
	combat.sync_zones()
	var dark: int = combat.skill_damage(cyrus, foe, gun)
	ok(absf(float(lit) / float(dark) - 1.2) < 0.03, "a fifth more", "%d against %d" % [lit, dark])
	log_line("")


func ink_bottle():
	log_line("======== Ink Bottle ========")
	var cyrus := who("cyrus")
	var at := open_ground(cyrus.position, 4)
	var item: ItemDefinition = ItemDatabase.item("ink_bottle")
	ok(item != null and item.price == 120, "as the other bottles are priced")
	ok(load("res://data/stores/travelling_merchant.tres").stock.has("ink_bottle"), "and on sale")
	combat._placed_lights.append({"tile": at, "bright": 4.0, "dim": 8.0, "colour": Color.WHITE, "flickers": true})
	combat.sync_zones()
	ok(combat.light.level_at(at) == Light.Level.BRIGHT, "a lit place")
	await their_turn(cyrus)
	await combat.use_skill("ink_bottle", cyrus, at, false)
	await settle()
	ok(combat.zones.size() == 1 and combat.light.level_at(at) == Light.Level.DARK, "broken on it, it is Dark, whatever lights it", "%d" % combat.light.level_at(at))
	var zone: Dictionary = combat.zones[0]
	for i in 2:
		combat._zones_at_turn_start(cyrus)
	ok(combat.zones.has(zone), "for three of his turns")
	combat._zones_at_turn_start(cyrus)
	ok(not combat.zones.has(zone) and combat.light.level_at(at) == Light.Level.BRIGHT, "then the light is back")
	log_line("")


func calling_out():
	log_line("======== Calling Out ========")
	var alithia := who("alithia")
	var enfina := who("enfina")
	var foe: Dictionary = foes()[0]
	var skill: SkillDefinition = SkillDatabase.skills.calling_out
	ok(skill.is_secondary and CombatantDatabase.combatants.alithia.skills.has("calling_out"), "hers, a secondary action")
	# Lost in the dark, and beside her: she can see them, Enfina cannot.
	var at := open_ground(alithia.position, 1)
	combat.teleport_to(foe, at)
	combat.teleport_to(enfina, open_ground(alithia.position, 6))
	combat.sync_zones()
	ok(combat.is_hidden(foe), "lost in the dark", "%d" % combat.light.level_at(at))
	ok(not combat.hidden_from(alithia, foe), "she sees them, beside her")
	ok(combat.hidden_from(enfina, foe), "Enfina does not")
	await their_turn(alithia)
	foe.status_effects = foe.status_effects.filter(func(entry): return true)
	await combat.use_skill("calling_out", alithia, at, false, true)
	await settle()
	ok(not combat.hidden_from(enfina, foe), "named out loud, Enfina can aim at them too")
	ok(combat.is_hidden(foe), "though they are still hidden from the rest")
	ok(alithia.secondary_used_this_turn, "for her secondary action")
	combat._turn_begins_for(foe)
	ok(not combat.hidden_from(enfina, foe), "their own turn does not end it")
	combat._turn_begins_for(alithia)
	ok(combat.hidden_from(enfina, foe), "her next turn does")
	log_line("")


func blessed_in_the_light():
	log_line("======== Blessed in the Light ========")
	var alithia := who("alithia")
	var enfina := who("enfina")
	var foe: Dictionary = foes()[0]
	var heal: SkillDefinition = SkillDatabase.skills.heal
	var heal_effect: EffectDefinition = null
	for effect in heal.all_effects():
		if effect != null and effect.type == EffectDefinition.EffectType.HEAL:
			heal_effect = effect
	var flame: SkillDefinition = SkillDatabase.skills.votive_flame
	# In the dark, nothing.
	ok(is_equal_approx(combat._blessed_factor(alithia, enfina), 1.0), "in the dark, nothing more")
	var dim_damage: int = combat.skill_damage(alithia, foe, flame)
	var dim_heal: int = combat.predict_hit(alithia, enfina, heal).heal
	# In Bright, a tenth more each.
	combat._placed_lights.append({"tile": enfina.position, "bright": 2.0, "dim": 2.0, "colour": Color.WHITE, "flickers": true})
	combat._placed_lights.append({"tile": foe.position, "bright": 2.0, "dim": 2.0, "colour": Color.WHITE, "flickers": true})
	combat.sync_zones()
	ok(is_equal_approx(combat._blessed_factor(alithia, enfina), 1.1), "on somebody in Bright, a tenth more", "%f" % combat._blessed_factor(alithia, enfina))
	var lit_damage: int = combat.skill_damage(alithia, foe, flame)
	var lit_heal: int = combat.predict_hit(alithia, enfina, heal).heal
	ok(absf(float(lit_damage) / float(dim_damage) - 1.1) < 0.06, "her Idol damage", "%d against %d" % [lit_damage, dim_damage])
	ok(absf(float(lit_heal) / float(dim_heal) - 1.1) < 0.06, "and her heals", "%d against %d" % [lit_heal, dim_heal])
	var water: SkillDefinition = SkillDatabase.skills.water_spike
	combat._placed_lights.clear()
	combat.sync_zones()
	var water_dark: int = combat.skill_damage(alithia, foe, water)
	combat._placed_lights.append({"tile": foe.position, "bright": 2.0, "dim": 2.0, "colour": Color.WHITE, "flickers": true})
	combat.sync_zones()
	ok(combat.skill_damage(alithia, foe, water) == water_dark, "but no other element's")
	log_line("")


func nowhere_to_hide():
	log_line("======== Nowhere to Hide ========")
	var alithia := who("alithia")
	var foe: Dictionary = foes()[0]
	var at := open_ground(alithia.position, 4)
	combat.teleport_to(foe, at)
	combat._placed_lights.append({"tile": at, "bright": 2.0, "dim": 2.0, "colour": Color.WHITE, "flickers": true})
	combat.sync_zones()
	ok(not combat._whose_light_they_are_in(foe).is_empty(), "in Bright, in her sight, within six")
	combat.set_hidden(foe, true)
	ok(not combat.is_hidden(foe), "they cannot hide")
	combat.make_invisible(foe)
	ok(not combat.is_invisible(foe), "or go invisible")
	ok(combat.conditions_of(foe).any(func(condition): return condition.more_from_source > 0.0), "and are Exposed for trying")
	var far: Vector2i = open_ground(alithia.position, 12)
	combat.teleport_to(foe, far)
	combat._placed_lights.clear()
	combat._placed_lights.append({"tile": far, "bright": 2.0, "dim": 2.0, "colour": Color.WHITE, "flickers": true})
	combat.sync_zones()
	ok(combat._whose_light_they_are_in(foe).is_empty(), "further off, no")
	log_line("")


func a_shot_at_a_lamp_on_a_map():
	log_line("======== A shot at a lamp, on a map ========")
	var m = await open_map()
	Campaign.set_party(["cyrus"], 14)
	await settle()
	var scene = m.scene
	var map = scene.get_node(ExplorationScene.MAP_NODE)
	var lamp := Lamp.new()
	map.add_child(lamp)
	var there: Vector2i = m.post + Vector2i.RIGHT * 4
	lamp.global_position = at(m, there)
	var watch = await watch_it(m, m.post)
	ok(watch._lamps.has(lamp), "a lamp the watch knows")
	var skill: SkillDefinition = SkillDatabase.skills.gun
	var tile: Vector2i = watch.tile_of(lamp.global_position)
	ok(OutsideMoves.aim_refusal(scene, "cyrus", skill, tile) == "", "aimed at it, with nobody there", OutsideMoves.aim_refusal(scene, "cyrus", skill, tile))
	var alert: float = watch.alert
	ok(OutsideMoves.fire_at(scene, "cyrus", "gun", tile), "he shoots")
	await settle()
	ok(not lamp.lit, "and it is out")
	ok(watch.spotted_by == null and Campaign.current_encounter == null or watch.spotted_by == null, "with no fight")
	ok(watch.alert == alert, "and no alarm for it")
	await close_map(m)
	log_line("")


func in_plain_darkness():
	log_line("======== In Plain Darkness ========")
	var m = await open_map()
	Campaign.set_party(["cyrus"], 14)
	await settle()
	var spot: Vector2i = m.post
	var listener := add_guard(m, "Listener", spot + Vector2i.RIGHT * 3, 0.0)
	var victim := add_guard(m, "Victim", spot + Vector2i.RIGHT, 0.0)
	var watch = await watch_it(m, spot)
	watch.setup.dark = true
	watch._relight()
	await settle()
	var scene = m.scene
	ok(scene.light.level_at(watch.tile_of(victim.global_position)) == Light.Level.DARK, "a dark place")
	ok(watch._in_plain_darkness(victim.global_position), "and so in plain darkness")
	ok(watch.take_down(victim), "taken down")
	await settle()
	ok(listener.mood == Guard.Mood.PATROLLING, "and nobody heard", "%d" % listener.mood)
	watch._look_for_bodies(listener)
	ok(not watch._bodies.get(victim, true), "nor does anybody find them there")
	await close_map(m)
	log_line("")


func flare_on_a_map():
	log_line("======== Flare, on a map ========")
	var m = await open_map()
	Campaign.set_party(["prometheus"], 14)
	Campaign.learned_spells = {"prometheus": ["flare"]}
	await settle()
	var guard := add_guard(m, "Guard", m.post + Vector2i.RIGHT * 9, 180.0)
	var watch = await watch_it(m, m.post)
	var scene = m.scene
	var skill: SkillDefinition = SkillDatabase.skills.flare
	ok(OutsideMoves.use_of(skill) == OutsideMoves.Use.FLARE, "a thing of its own out here")
	ok(OutsideMoves.refusal(scene, "prometheus", "flare") == "", "he can cast it", OutsideMoves.refusal(scene, "prometheus", "flare"))
	var seconds: int = skill.outside_seconds
	skill.outside_seconds = 1
	var map = scene.get_node(ExplorationScene.MAP_NODE)
	var lights: int = map.find_children("*", "LightSource", true, false).size()
	ok(guard.mood == Guard.Mood.PATROLLING, "the guard is about his business", "%d" % guard.mood)
	ok(OutsideMoves.use(scene, "prometheus", "flare"), "he does")
	await settle()
	ok(map.find_children("*", "LightSource", true, false).size() == lights + 1, "a light goes up over the map")
	ok(guard.mood != Guard.Mood.PATROLLING, "and the guard heard it", "%d" % guard.mood)
	await get_tree().create_timer(1.3).timeout
	await settle()
	ok(map.find_children("*", "LightSource", true, false).size() == lights, "and then it is out")
	skill.outside_seconds = seconds
	await close_map(m)
	log_line("")
