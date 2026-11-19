extends "res://StealthHarness.gd"
## What is on somebody, shown on them (ConditionLook), a tether's thread (TetherThreads), how light falls on them and the
## shadows they throw (CombatantSprite). All of it is only to look at, so headless it is switched on by hand, and this checks
## what it decides to show: pictures cannot be checked from here.

const TetherThreads := preload("res://control/TetherThreads.gd")


func suite() -> String:
	return "figures"


func time_limit() -> float:
	return 240.0


var game = null
var combat: Combat = null
var controller = null


func run_sections():
	which_of_them_shows()
	right_on_the_right()
	MoveFeel.plays_headless = true
	LightView.plays_headless = true
	TetherThreads.plays_headless = true
	await open_fight()
	await on_the_figure()
	await open_fight()
	await poses()
	await open_fight()
	await threads()
	await open_fight()
	await threads_to_what_touches()
	await open_fight(true)
	await how_a_thread_looks()
	await open_fight()
	await a_thread_in_the_dark()
	await open_fight()
	await light_on_them()
	await open_fight()
	await shadows()
	await close_fight()
	MoveFeel.plays_headless = false
	LightView.plays_headless = false
	TetherThreads.plays_headless = false
	CombatantSprite.forget_the_light()


## A shadow keeps their right on the right whichever way it falls (the designer, 2026-11-07: below a light, walking right,
## the shadow walked left).
func right_on_the_right():
	log_line("======== a shadow is never their mirror ========")
	var feet := Vector2(100, 100)
	for way in [Vector2.UP, Vector2.DOWN, Vector2(0.6, 0.8), Vector2(-0.6, 0.8), Vector2(0.6, -0.8)]:
		var corners: PackedVector2Array = CombatantSprite.cast_corners(feet, way, 80.0, 40.0)
		# The picture's bottom left is corner 0 and its bottom right corner 1: left of each other on the screen, at their feet.
		ok(corners[0].x < corners[1].x, "thrown %s, their left is on the left" % way, "%s %s" % [corners[0], corners[1]])
	var down: PackedVector2Array = CombatantSprite.cast_corners(feet, Vector2.DOWN, 80.0, 40.0)
	ok(down[2].y > feet.y and down[3].y > feet.y, "and thrown down the screen, the head end is below their feet")
	log_line("")


## Underground, unless `in_the_open` (outdoors, by day).
func open_fight(in_the_open := false):
	await close_fight()
	Campaign.reset()
	Campaign.set_party(["enfina", "cyrus", "prometheus", "alithia"], 64)
	Campaign.current_map = "res://maps/crossroads_explore.tscn"
	Campaign.return_to_position = true
	var encounter: EncounterDefinition = load("res://data/encounters/encounter_03_watcher.tres").duplicate()
	encounter.ambient = Light.Ambient.OUTDOORS if in_the_open else Light.Ambient.UNDERGROUND
	if in_the_open:
		encounter.time_of_day = Light.Hour.DAY
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
	ok(held.has(Vector2(foe.position)), "a thread to what it holds", "%s" % [held])
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
	ok(combat.what_a_tether_holds(alithia).has(Vector2(ground)), "a zone's thread goes to its middle", "%s" % [combat.what_a_tether_holds(alithia)])
	log_line("")


## One thread to all a tether holds that touch, side by side or corner to corner, and one to each part apart (the
## designer, 2026-11-17: "whenever a caster is tethered to one spell that occupies multiple but adjacent tiles, show
## only one tether").
func threads_to_what_touches():
	log_line("======== one thread to what touches ========")
	var caster := who("prometheus")
	var enfina := who("enfina")
	var skill: SkillDefinition = SkillDatabase.skills.wall_of_stone
	await turn_of(caster)
	var start := clear_row(caster.position, 6, skill)
	ok(start != Combat.NO_AREA, "a clear row in reach", "%s" % start)
	await combat.use_skill("wall_of_stone", caster, start, false, false, start + Vector2i(5, 0))
	await settle()
	var threads: Array = combat.what_a_tether_holds(caster)
	ok(threads == [Vector2(start) + Vector2(2.5, 0)], "a wall of six, one thread to its middle", "%s" % [threads])
	ok(TetherThreads.ground_of(threads[0] if not threads.is_empty() else Vector2.ZERO).is_equal_approx(
		(Grid.tile_to_world(start + Vector2i(2, 0)) + Grid.tile_to_world(start + Vector2i(3, 0))) / 2.0),
		"drawn to the line between its two middle pieces")
	combat.snap_tether(caster, "test")
	await settle()
	# Somebody in the way: the wall goes up in two parts, apart, and each has a thread.
	combat.teleport_to(enfina, start + Vector2i(2, 0))
	await turn_of(caster)
	await combat.use_skill("wall_of_stone", caster, start, false, false, start + Vector2i(5, 0))
	await settle()
	threads = combat.what_a_tether_holds(caster)
	ok(threads.size() == 2 and threads.has(Vector2(start) + Vector2(0.5, 0)) and threads.has(Vector2(start) + Vector2(4, 0)),
		"somebody in the way, two parts apart: a thread to each", "%s" % [threads])
	combat.snap_tether(caster, "test")
	await settle()
	# A zone, and whoever it holds in it: one thread, to the zone's middle.
	var alithia := who("alithia")
	var foe: Dictionary = foes()[0]
	var stand := open_ground(foe.position, 5)
	if stand != Combat.NO_AREA:
		combat.teleport_to(alithia, stand)
	await turn_of(alithia)
	# Beside them, so the zone's middle is not where they stand.
	var aimed: Vector2i = foe.position
	for way in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var there: Vector2i = foe.position + way
		if aimed == foe.position and controller.is_on_map(there) and not controller.is_tile_blocking(there, 0) and combat.get_combatant_at(there).is_empty():
			aimed = there
	await combat.use_skill("silence", alithia, aimed, false)
	await settle()
	ok(not combat.unseen_by_party(foe), "they are in sight, so a thread could go to them", "%s from %s" % [foe.position, alithia.position])
	var zone: Dictionary = {}
	for each in combat.zones:
		if Combat.holds_tether(alithia) and each.get("tether_of", -1) == alithia.tether.id:
			zone = each
	ok(not zone.is_empty() and foe.status_effects.any(func(entry): return entry.get("tether_of", -1) == alithia.tether.id),
		"Silence holds the ground and who stands in it", "%s" % [foe.status_effects.map(func(entry): return entry.get("tether_of", -1))])
	threads = combat.what_a_tether_holds(alithia)
	ok(not zone.is_empty() and threads == [Vector2(zone.centre)], "one thread, to the zone's middle", "%s" % [threads])
	log_line("")


func turn_of(comb: Dictionary):
	combat.current_combatant = combat.combatants.find(comb)
	comb.skill_used_this_turn = false
	comb.secondary_used_this_turn = false
	controller.set_controlled_combatant(comb)
	await settle()


## Where a wall `length` long can run right along a row from: in sight and reach of `from`, all of it clear.
func clear_row(from: Vector2i, length: int, skill: SkillDefinition) -> Vector2i:
	var probe: Dictionary = combat.summon_probe(skill, 0)
	var region: Rect2i = controller._astargrid.region
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var start := Vector2i(x, y)
			var gap: int = combat.get_position_distance(start, from)
			if gap < 2 or gap > 6 or not combat.has_line_of_sight(from, start, 0):
				continue
			var clear := true
			for step in length:
				var tile: Vector2i = start + Vector2i(step, 0)
				if not controller.is_on_map(tile) or not combat.can_land_on(probe, tile) or not combat.get_combatant_at(tile).is_empty():
					clear = false
			if clear:
				return start
	return Combat.NO_AREA


## How a thread looks (the designer, 2026-11-17: "Do all" of the ways offered, and "if the spell effect is connected to
## something invisible or hidden, have it also hide if it is an opponent's, or keep it without light if its an ally"). What
## TetherThreads decides to draw, not the pictures.
func how_a_thread_looks():
	log_line("======== how a thread looks ========")
	var alithia := who("alithia")
	var foe: Dictionary = foes()[0]
	combat.set_hidden(foe, false)
	await settle(3)
	var lit = controller._threads_lit
	var unlit = controller._threads_unlit
	ok(lit != null and is_instance_valid(lit) and lit.get_parent() == combat.combatant_layer() and not lit.z_as_relative \
		and lit.z_index == TetherThreads.LIT_Z, "the lit threads over the figures")
	ok(unlit != null and is_instance_valid(unlit) and unlit.get_parent() == controller and unlit.z_index == 0 and unlit.material == null,
		"the unlit ones plain, with the board's marks under the figures")
	if lit == null or unlit == null:
		log_line("")
		return
	combat.teleport_to(alithia, foe.position + Vector2i(3, 0))
	await turn_of(alithia)
	await combat.use_skill("sleep", alithia, foe.position, false)
	await settle(3)
	ok(Combat.holds_tether(alithia), "her Sleep on a tether")
	if not Combat.holds_tether(alithia):
		log_line("")
		return
	var id: int = alithia.tether.id
	var drawn: Array = lit.threads_now.filter(func(thread): return thread.id == id)
	ok(drawn.size() == 1 and unlit.threads_now.is_empty(), "one thread, lit", "%d" % drawn.size())
	if drawn.is_empty():
		log_line("")
		return
	var points: PackedVector2Array = drawn[0].points
	var layer: Node2D = combat.combatant_layer()
	# Their feet are at the bottom of their tile (CombatantSprite._fit_feet); their middle is their picture's.
	var her_feet: Vector2 = lit.to_local(layer.to_global(MoveFeel.middle_of(combat, alithia))) + Vector2(0.0, Grid.HALF_TILE.y)
	var their_feet: Vector2 = lit.to_local(layer.to_global(MoveFeel.middle_of(combat, foe))) + Vector2(0.0, Grid.HALF_TILE.y)
	var her_middle: Vector2 = lit.to_local(alithia.sprite._drawn().to_global(alithia.sprite._drawn().offset))
	ok(points[0].is_equal_approx(her_middle) and points[0].y < her_feet.y - 40.0, "it leaves the middle of her picture, up off the floor",
		"%s, her picture's middle %s, her feet %s" % [points[0], her_middle, her_feet])
	ok(points[points.size() - 1].y < their_feet.y - 40.0, "and reaches theirs", "%s, their feet %s" % [points[points.size() - 1], their_feet])
	var straight: Vector2 = points[0].lerp(points[points.size() - 1], 0.5)
	ok(points[points.size() / 2].y > straight.y + 2.0, "hanging a little in the middle", "%s below %s" % [points[points.size() / 2], straight])
	var phase: float = drawn[0].phase
	await settle(6)
	drawn = lit.threads_now.filter(func(thread): return thread.id == id)
	ok(not drawn.is_empty() and drawn[0].phase > phase, "its motes drift along it")
	# The pointer on her lights it up.
	var width: float = drawn[0].width if not drawn.is_empty() else 0.0
	controller._hover_tile = alithia.position
	await settle(2)
	drawn = lit.threads_now.filter(func(thread): return thread.id == id)
	ok(not drawn.is_empty() and drawn[0].pointed and drawn[0].width > width, "pointed at, it lights up")
	controller._hover_tile = Vector2i(-99999, -99999)
	# Frayed: a shiver along it.
	combat.fray_tether(alithia, 10.0, "test")
	await settle(1)
	ok(lit._seen.has(id) and lit._seen[id].shiver > 0.0, "frayed, it shivers")
	# Worn nearly through: gaps, loose pixels, a flicker.
	alithia.tether.bar = alithia.tether.max * 0.08
	await settle(60)
	drawn = lit.threads_now.filter(func(thread): return thread.id == id)
	ok(not drawn.is_empty() and drawn[0].gaps > 0.0, "worn, gaps open in it", "%s" % [drawn[0].gaps if not drawn.is_empty() else "-"])
	ok(not lit.loose.is_empty(), "and pixels come loose from it", "%d" % lit.loose.size())
	var flickered := false
	for each in 20:
		await settle(1)
		drawn = lit.threads_now.filter(func(thread): return thread.id == id)
		flickered = flickered or (not drawn.is_empty() and drawn[0].flicker < 0.99)
	ok(flickered, "and it flickers")
	ok(lit.threads_now.all(func(thread): return lit.pieces_of(thread).size() >= 1), "still drawn, in pieces")
	alithia.tether.bar = alithia.tether.max
	# Unseen, hers stays, without its light.
	alithia["invisible"] = true
	await settle(2)
	var hers: Array = combat.tether_threads(alithia)
	ok(hers.size() == 1 and hers[0].light == Combat.ThreadLight.UNLIT, "invisible, hers is kept, without its light")
	ok(not lit.threads_now.any(func(thread): return thread.id == id) and unlit.threads_now.any(func(thread): return thread.id == id),
		"drawn plain now, not lit")
	ok(lit.snaps.is_empty() and unlit.snaps.is_empty(), "and nothing snapped")
	alithia.erase("invisible")
	foe["hidden"] = true
	await settle(2)
	hers = combat.tether_threads(alithia)
	ok(combat.unseen_by_party(foe) or (hers.size() == 1 and hers[0].light == Combat.ThreadLight.UNLIT),
		"to somebody of theirs hidden but in sight, without its light too; out of sight, none at all", "%s" % [hers.map(func(thread): return thread.light)])
	foe.erase("hidden")
	await settle(2)
	ok(lit.threads_now.any(func(thread): return thread.id == id), "seen again, lit again")
	# It ends: it snaps, and is gone.
	combat.snap_tether(alithia, "test")
	await settle(1)
	ok(not lit.snaps.is_empty(), "let go, it snaps")
	await get_tree().create_timer(TetherThreads.SNAP_SECONDS + 0.2).timeout
	ok(lit.snaps.is_empty() and not lit.threads_now.any(func(thread): return thread.id == id), "and is gone")
	# The other side's, from somebody hidden or invisible: not there at all. Theirs held by hand (none of them here has a
	# gate open to cast one): something of it on Enfina.
	var enfina := who("enfina")
	combat.teleport_to(enfina, open_ground(foe.position, 3))
	var theirs: int = combat.tie_tether(foe, "sleep", SkillDatabase.skills.sleep)
	combat.put_condition(enfina, combat.EXPOSED, 5, foe.name, true, foe.get("id", -1))
	if not enfina.status_effects.is_empty():
		enfina.status_effects.back()["tether_of"] = theirs
	await settle(3)
	ok(combat.tether_threads(foe).size() == 1 and lit.threads_now.any(func(thread): return thread.id == theirs),
		"theirs, in sight, has its thread, lit", "%s, %s" % [combat.tether_threads(foe).size(), enfina.status_effects.map(func(entry): return entry.get("tether_of", -1))])
	foe["invisible"] = true
	await settle(2)
	ok(combat.tether_threads(foe).is_empty() and not lit.threads_now.any(func(thread): return thread.id == theirs) \
		and not unlit.threads_now.any(func(thread): return thread.id == theirs), "invisible, theirs hides")
	ok(lit.snaps.is_empty() and unlit.snaps.is_empty(), "with no snap to give them away")
	foe.erase("invisible")
	await settle(2)
	ok(lit.threads_now.any(func(thread): return thread.id == theirs), "and comes back with them")
	log_line("")


## In the dark, whoever has faded into it is hidden (Combat "Darkness is cover"), so a thread of the party's to or from them
## is kept without its light, under the shade: a glowing one would light them up.
func a_thread_in_the_dark():
	log_line("======== a thread in the dark ========")
	var alithia := who("alithia")
	var foe: Dictionary = foes()[0]
	combat.teleport_to(alithia, foe.position + Vector2i(3, 0))
	await turn_of(alithia)
	await combat.use_skill("sleep", alithia, foe.position, false)
	await settle(3)
	ok(combat.out_of_sight(alithia) or combat.out_of_sight(foe), "down here, faded into the dark",
		"%s, %s" % [alithia.get("lost_in_the_dark", false), foe.get("lost_in_the_dark", false)])
	var hers: Array = combat.tether_threads(alithia)
	ok(hers.size() == 1 and hers[0].light == Combat.ThreadLight.UNLIT, "so her thread is kept without its light", "%s" % [hers.map(func(thread): return thread.light)])
	var unlit = controller._threads_unlit
	var lit = controller._threads_lit
	var id: int = alithia.tether.id if Combat.holds_tether(alithia) else -1
	ok(unlit != null and unlit.threads_now.any(func(thread): return thread.id == id) and not lit.threads_now.any(func(thread): return thread.id == id),
		"and drawn plain, not lit: still there to see")
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
	sprite.set_in_the_dark(true)
	# It comes on over a moment, as darkness does (the designer, 2026-11-12).
	await get_tree().create_timer(CombatantSprite.FADE_SECONDS + 0.15).timeout
	ok(material.get_shader_parameter("rim_on") == 1.0, "in the Dark, a rim so she can still be made out")
	sprite.set_in_the_dark(false)
	await get_tree().create_timer(CombatantSprite.FADE_SECONDS + 0.15).timeout
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
