extends "res://StealthHarness.gd"
## What is on somebody, shown on them (ConditionLook), a tether's thread, how light falls on them and the shadows they throw
## (CombatantSprite). All of it is only to look at, so headless it is switched on by hand, and this checks what it decides
## to show: pictures cannot be checked from here.


func suite() -> String:
	return "figures"


func time_limit() -> float:
	return 200.0


var game = null
var combat: Combat = null
var controller = null


func run_sections():
	which_of_them_shows()
	MoveFeel.plays_headless = true
	LightView.plays_headless = true
	await open_fight()
	await on_the_figure()
	await open_fight()
	await poses()
	await open_fight()
	await threads()
	await open_fight()
	await light_on_them()
	await open_fight()
	await shadows()
	await close_fight()
	MoveFeel.plays_headless = false
	LightView.plays_headless = false
	CombatantSprite.forget_the_light()


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


func which_of_them_shows():
	log_line("======== one at a time ========")
	var strong := ConditionDefinition.new()
	strong.figure_priority = 5
	var also_strong := ConditionDefinition.new()
	also_strong.figure_priority = 5
	var weak := ConditionDefinition.new()
	weak.figure_priority = 1
	ok(ConditionLook.choose_from([], 0) == null, "nothing on them, nothing to show")
	var list := [{"condition": weak}, {"condition": strong}, {"condition": also_strong}]
	ok(ConditionLook.choose_from(list, 0) == strong, "the strongest shows")
	ok(ConditionLook.choose_from(list, 1) == also_strong, "those equal to it take turns")
	ok(ConditionLook.choose_from(list, 2) == strong, "and round again")
	var stunned: ConditionDefinition = load("res://data/conditions/stunned.tres")
	var burn: ConditionDefinition = load("res://data/conditions/burn.tres")
	ok(stunned.round_them == ConditionDefinition.RoundThem.STARS, "stunned has stars round them")
	ok(burn.off_them == ConditionDefinition.OffThem.EMBERS and burn.figure_tint.a > 0.0, "a burn has embers and a colour")
	# No icons over the head (the designer, 2026-11-07): a look is drawn on the figure.
	ok(not "icon_over_head" in burn, "and nothing floats a mark over the head")
	log_line("")


func on_the_figure():
	log_line("======== on the figure ========")
	var enfina := who("enfina")
	var sprite: CombatantSprite = enfina.sprite
	var burn: ConditionDefinition = load("res://data/conditions/burn.tres")
	combat.put_condition(enfina, burn, 3, "test", false)
	combat.update_combatants.emit(combat.combatants)
	await settle()
	ok(sprite.conditions_on_show.has(burn.resource_path), "what is on her is on show")
	var look: ConditionLook = sprite._condition_look
	ok(look != null, "her look is made")
	# The dark she may be standing in is on the list too: it only gives a look of its own.
	var burns: Array = look.entries.filter(func(entry): return entry.condition == burn)
	ok(burns.size() == 1, "the burn is on the list", "%d" % burns.size())
	ok(look._shown == burn, "the burn shows", "%s" % (look._shown.display_name if look._shown != null else "nothing"))
	ok(burns[0].helps == false, "and it hurts")
	ok(sprite.condition_tint != Color.WHITE, "her colour goes with it", "%s" % sprite.condition_tint)
	ok(look._particles != null and look._particles.emitting, "embers come off her")
	ok(look._ring != null and look._ring.get_parent() == sprite and sprite.get_child(0) == look._ring, "a ring under her, under everything of hers")
	# It takes turns with something as strong.
	var other: ConditionDefinition = burn.duplicate()
	other.resource_path = ""
	var poisoned: ConditionDefinition = load("res://data/conditions/poisoned.tres")
	poisoned.figure_priority = burn.figure_priority
	combat.put_condition(enfina, poisoned, 3, "test", false)
	combat.update_combatants.emit(combat.combatants)
	await settle()
	ok(look.entries.any(func(entry): return entry.condition == poisoned), "the poison is on the list too", "%d" % look.entries.size())
	var first: ConditionDefinition = look._shown
	look._since_turn = ConditionLook.TURN_SECONDS
	await settle()
	ok(look._shown != first and look._shown != null, "and they take turns", "%s" % look._shown.display_name)
	# It goes.
	enfina.status_effects.clear()
	combat.update_combatants.emit(combat.combatants)
	await settle()
	ok(sprite.conditions_on_show.is_empty(), "with nothing on her, nothing on show")
	ok(look._shown == null, "nothing shows", "%s" % (look._shown.display_name if look._shown != null else "nothing"))
	# Somebody the party cannot see has nothing to show.
	var foe: Dictionary = foes()[0]
	combat.put_condition(foe, burn, 3, "test", false)
	foe["invisible"] = true
	combat.set_hidden(foe, true)
	combat.update_combatants.emit(combat.combatants)
	await settle()
	ok(not foe.sprite.conditions_on_show.has(burn.resource_path) or not combat.unseen_by_party(foe), "nothing shows on somebody unseen")
	log_line("")


func poses():
	log_line("======== poses ========")
	var enfina := who("enfina")
	var sprite: CombatantSprite = enfina.sprite
	var drawn: AnimatedSprite2D = sprite._animated
	ok(drawn != null, "an animated figure")
	sprite.play_idle()
	sprite.set_pose(&"cowering")
	ok(drawn.animation == &"idle", "no such animation, and she stands in idle", "%s" % drawn.animation)
	sprite.set_pose(&"")
	var frames: SpriteFrames = drawn.sprite_frames.duplicate()
	frames.add_animation(&"cowering")
	frames.add_frame(&"cowering", frames.get_frame_texture(&"idle", 0))
	drawn.sprite_frames = frames
	sprite.set_pose(&"cowering")
	ok(drawn.animation == &"cowering", "with one, she stands in it", "%s" % drawn.animation)
	sprite.set_pose(&"")
	ok(drawn.animation == &"idle", "and back when it is over", "%s" % drawn.animation)
	log_line("")


func threads():
	log_line("======== a tether's thread ========")
	var alithia := who("alithia")
	ok(combat.what_a_tether_holds(alithia).is_empty(), "no tether, nothing held")
	var foe: Dictionary = foes()[0]
	combat.teleport_to(alithia, foe.position + Vector2i(3, 0))
	combat.current_combatant = combat.combatants.find(alithia)
	controller.set_controlled_combatant(alithia)
	await settle()
	await combat.use_skill("sleep", alithia, foe.position, false)
	await settle()
	ok(Combat.holds_tether(alithia), "she holds a tether")
	var held: Array = combat.what_a_tether_holds(alithia)
	ok(held.has(foe.position), "a thread to what it holds", "%s" % [held])
	combat.snap_tether(alithia, "test")
	await settle()
	ok(combat.what_a_tether_holds(alithia).is_empty(), "let go, and the thread goes")
	await open_fight()
	alithia = who("alithia")
	combat.current_combatant = combat.combatants.find(alithia)
	alithia.skill_used_this_turn = false
	alithia.secondary_used_this_turn = false
	controller.set_controlled_combatant(alithia)
	await settle()
	var ground := open_ground(alithia.position, 6)
	await combat.use_skill("daylight", alithia, ground, false)
	await settle()
	ok(Combat.holds_tether(alithia), "she holds Daylight on a tether", "at %s from %s, zones %d, %s" % [ground, alithia.position, combat.zones.size(), combat.refusal_for(alithia, SkillDatabase.skills.daylight, ground) if combat.has_method("refusal_for") else ""])
	ok(combat.what_a_tether_holds(alithia).has(ground), "a zone's thread goes to its middle", "%s" % [combat.what_a_tether_holds(alithia)])
	log_line("")


func light_on_them():
	log_line("======== light falling on them ========")
	ok(combat.light_view != null, "the look of light is on")
	var enfina := who("enfina")
	var sprite: CombatantSprite = enfina.sprite
	var tile: Vector2i = enfina.position
	var right := tile + Vector2i(2, 0)
	combat._placed_lights.append({"tile": right, "bright": 2.0, "dim": 5.0, "colour": Color(1.0, 0.3, 0.2), "flickers": false})
	combat.sync_zones()
	await settle(4)
	ok(CombatantSprite.figures_lit, "figures are lit")
	var point: Dictionary = {}
	for each in CombatantSprite.light_points:
		if each.colour == Color(1.0, 0.3, 0.2):
			point = each
	ok(not point.is_empty(), "told of the light, with its colour", "%d lights" % CombatantSprite.light_points.size())
	ok(point.get("node") != null and point.get("reach", 0.0) > 0.0, "where it is and how far it reaches")
	await settle(4)
	var material: ShaderMaterial = sprite._figure_material
	ok(material != null and sprite._drawn().material == material, "a shader of her own")
	var strength: float = material.get_shader_parameter("lit_strength") if material != null else 0.0
	ok(strength > 0.0, "a light near her colours her", "%.2f" % strength)
	var way: Vector2 = material.get_shader_parameter("light_way")
	var flipped: bool = sprite._animated.flip_h
	ok((way.x > 0.0) != flipped, "her lit edge faces it, whichever way she is drawn", "%s flipped %s" % [way, flipped])
	var colour: Vector3 = material.get_shader_parameter("lit_colour")
	ok(colour.x > colour.z, "in its colour", "%s" % colour)
	# Nobody shares a material, so one figure's light is not another's.
	var cyrus := who("cyrus")
	ok(cyrus.sprite._figure_material != material, "every figure has its own")
	# In the Dark, a rim; lit, none.
	await settle()
	var far: Vector2i = tile + Vector2i(-40, -40)
	sprite.set_in_the_dark(true, false)
	await settle(2)
	ok(material.get_shader_parameter("rim_on") == 1.0, "in the Dark, a rim so she can still be made out")
	sprite.set_in_the_dark(false, false)
	await settle(2)
	ok(material.get_shader_parameter("rim_on") == 0.0, "out of it, none")
	# Half in the dark: the shade's own picture is read, pixel by pixel.
	ok(CombatantSprite.shade_map != null and CombatantSprite.shade_rect.size.x > 0.0, "the shade is there to read", "%s" % CombatantSprite.shade_rect)
	ok(material.get_shader_parameter("shade_on") == 1.0, "and she reads it")
	# Whoever flies has their shadow further off.
	var enemy: Dictionary = foes()[0]
	enemy["movement_class"] = 1
	combat.sync_zones()
	await settle()
	ok(enemy.sprite.off_ground, "a flier is off the ground")
	# The next place forgets this one's light.
	CombatantSprite.forget_the_light()
	ok(not CombatantSprite.figures_lit and CombatantSprite.light_points.is_empty() and CombatantSprite.shade_map == null, "and a new place starts afresh")
	log_line("")


func shadow_of(sprite: CombatantSprite):
	for child in sprite.get_children():
		if child is CombatantSprite._Shadow:
			return child
	return null


func shadows():
	log_line("======== shadows ========")
	var enfina := who("enfina")
	var sprite: CombatantSprite = enfina.sprite
	var shadow = shadow_of(sprite)
	ok(shadow != null, "a shadow under her")
	ok(not sprite.current_frame().is_empty() and sprite.frame_stamp() != null, "of the frame she is showing")
	var feet: Vector2 = shadow.feet_at()
	var here: Vector2 = sprite.global_position + feet
	# Away from what lights her, the nearest strongest.
	var tile := float(Grid.TILE_SIZE)
	CombatantSprite.light_points = [{"at": here + Vector2(tile * 2.0, 0.0), "reach": tile * 5.0, "colour": Color.WHITE, "node": null, "energy": 1.0},
		{"at": here + Vector2(0.0, -tile), "reach": tile * 5.0, "colour": Color.WHITE, "node": null, "energy": 1.0}]
	var casts: Array = shadow.casts(feet)
	ok(casts.size() == 2, "a shadow for each light", "%d" % casts.size())
	ok(casts[0].way.y > 0.9, "the nearest strongest first, thrown away from it", "%s" % casts[0].way)
	ok(casts[1].way.x < -0.9, "and the other from the other", "%s" % casts[1].way)
	ok(casts[0].strength > casts[1].strength, "a nearer light throws a darker one", "%.2f, %.2f" % [casts[0].strength, casts[1].strength])
	ok(casts[0].length < casts[1].length, "and a shorter one", "%.2f, %.2f" % [casts[0].length, casts[1].length])
	# No more than three, or it is a mess.
	var many := []
	for i in 6:
		many.append({"at": here + Vector2(tile, 0.0).rotated(float(i)), "reach": tile * 5.0, "colour": Color.WHITE, "node": null, "energy": 1.0})
	CombatantSprite.light_points = many
	ok(shadow.casts(feet).size() == CombatantSprite.MOST_SHADOWS, "at most three", "%d" % shadow.casts(feet).size())
	# Out of reach of them all, or with none, the sun's.
	CombatantSprite.light_points = [{"at": here + Vector2(tile * 40.0, 0.0), "reach": tile * 5.0, "colour": Color.WHITE, "node": null, "energy": 1.0}]
	CombatantSprite.set_shadows({"lean": 0.6, "strength": 0.3, "colour": Color(0.1, 0.05, 0.02)})
	casts = shadow.casts(feet)
	ok(casts.size() == 1 and casts[0].way.x > 0.0, "the sun leans it its way", "%s" % [casts])
	ok(casts[0].colour == Color(0.1, 0.05, 0.02), "in the sky's colour")
	CombatantSprite.set_shadows({"lean": -0.6, "strength": 0.3})
	ok(shadow.casts(feet)[0].way.x < 0.0, "the other way later in the day")
	CombatantSprite.set_shadows({"lean": 0.0, "strength": 0.0})
	ok(shadow.casts(feet).is_empty(), "and underground, with no light at all, none")
	# The sky's colour is the hour's.
	var dusk: Dictionary = Light.shadow_at(Light.Ambient.OUTDOORS, 19 * 60)
	var night: Dictionary = Light.shadow_at(Light.Ambient.OUTDOORS, 23 * 60)
	ok(dusk.colour.r > dusk.colour.b, "warm at dusk", "%s" % dusk.colour)
	ok(night.colour.b > night.colour.r, "blue-black at night", "%s" % night.colour)
	# A wall stops it.
	var wall_at: float = sprite.global_position.x + feet.x + tile
	CombatantSprite.stops_shadow = func(at: Vector2): return at.x > wall_at
	ok(shadow.as_far_as_a_wall(feet, Vector2.RIGHT, tile * 4.0) <= tile * 1.5, "a wall stops it", "%.1f" % shadow.as_far_as_a_wall(feet, Vector2.RIGHT, tile * 4.0))
	ok(is_equal_approx(shadow.as_far_as_a_wall(feet, Vector2.LEFT, tile * 4.0), tile * 4.0), "and only that way")
	CombatantSprite.stops_shadow = Callable()
	ok(is_equal_approx(shadow.as_far_as_a_wall(feet, Vector2.RIGHT, tile * 4.0), tile * 4.0), "with nothing to ask, all of it")
	log_line("")
