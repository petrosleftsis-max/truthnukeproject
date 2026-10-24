extends Node
## The first boss, Erysichthon (data/enemies/glutton.tres, boss_glutton.tres), and
## what it is built from: enemies arriving late on a cue or once so many have
## fallen (Combat "Arriving late"), eating (Combat "Gluttony") - food on the map,
## a carcass tainted by a Use, a keg in meat, its own dead, itself - parts that
## grow back, and swallowing whoever it holds (Combat "Swallowing"), with every
## way out of it and the one way that ends it.

var LOG_PATH := HarnessLog.path_for("glutton")
var _log: FileAccess
var _fail = 0
var combat = null
var said: Array = []


func log_line(t): _log.store_line(t); _log.flush()

func ok(condition: bool, label: String, detail: String = ""):
	if condition:
		log_line("  PASS  %s %s" % [label, detail])
	else:
		_fail += 1
		log_line("  FAIL  %s %s" % [label, detail])


func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(240.0, true, false, true).timeout.connect(func():
		log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


func who(key: String) -> Dictionary:
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == key and comb.alive:
			return comb
	return {}


func all_of(key: String) -> Array:
	return combat.combatants.filter(func(comb): return comb.get("combatant_key", "") == key and comb.alive)


func put(comb: Dictionary, tile: Vector2i):
	var from: Vector2i = comb.position
	comb.position = tile
	combat.controller.reposition_combatant(from, tile)
	var sprite = comb.get("sprite")
	if sprite != null and is_instance_valid(sprite):
		sprite.position = combat.sprite_point(comb)


## A free tile right beside `boss` that `comb` has room on.
func beside(boss: Dictionary, comb: Dictionary) -> Vector2i:
	var rect: Rect2i = combat.rect_of(boss)
	for y in range(rect.position.y - 1, rect.end.y + 1):
		for x in range(rect.position.x - 1, rect.end.x + 1):
			var tile := Vector2i(x, y)
			if rect.has_point(tile):
				continue
			if combat.room_for(comb, tile) and combat.get_combatant_at(tile).is_empty():
				return tile
	return Vector2i(-99999, -99999)


func part_index(boss: Dictionary, name: String) -> int:
	for i in range(boss.parts.size() - 1, -1, -1):
		if boss.parts[i].name == name:
			return i
	return -1


func heard(words: String) -> bool:
	return said.any(func(line): return words in line)


## `glutton` takes hold of `prey` the way its Grab does, without the contest.
func grab(glutton: Dictionary, prey: Dictionary):
	var skill: SkillDefinition = SkillDatabase.skills["grab"]
	combat.apply_effect(glutton, prey, skill.effects[0], skill)


## `glutton` swallows `prey`: grabbed, Devour announced, and landed.
func swallow(glutton: Dictionary, prey: Dictionary):
	put(prey, beside(glutton, prey))
	grab(glutton, prey)
	glutton.erase("declared")
	await combat._ai_announce_devour(glutton, [prey])
	await combat.land_declared(glutton)
	await settle()


func run_test():
	Campaign.reset()
	Campaign.current_encounter = load("res://data/encounters/boss_glutton.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(8)
	combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(1)
	combat.reaction_prompt = null
	combat.update_information.connect(func(line): said.append(line))
	var glutton := who("glutton")
	var cyrus := who("cyrus")
	var alithia := who("alithia")
	var enfina := who("enfina")
	ok(not glutton.is_empty() and glutton.name == "Erysichthon" and combat.is_boss(glutton), "Erysichthon is here, a boss")
	ok(glutton.get("size", 0) == Sizes.Size.ENORMOUS and glutton.span == 4 and glutton.level == 22 and cyrus.level == 22,
		"Enormous, four tiles a side, and the fight is at level 22", "%d" % glutton.level)
	ok(glutton.parts.size() == 3 and glutton.eats == 3 and glutton.ai_function == "ai_glutton",
		"its Jaws, Belly Hole and Hind Legs; it eats food and its own dead; it fights as a glutton")
	ok(not who("carrion_heap").is_empty() and not who("bait_keg").is_empty(), "a carcass and a keg in meat on the map")
	for comb in combat.combatants:
		comb.max_hp = maxi(comb.max_hp, 900)
		comb.hp = comb.max_hp
	log_line("")

	log_line("======== arriving late ========")
	ok(combat.arriving().size() == 6 and all_of("gnawer").is_empty(), "six Gnawers waiting, none here yet", "%d" % combat.arriving().size())
	combat._bring_in_arrivals(true)
	ok(all_of("gnawer").is_empty(), "nothing has happened yet that brings them")
	combat.cue("broke:Jaws")
	combat._bring_in_arrivals(true)
	var wave := all_of("gnawer")
	ok(wave.size() == 2, "its Jaws broken (the cue), two come", "%d" % wave.size())
	ok(wave.all(func(gnawer): return combat.turn_queue.has(combat.combatants.find(gnawer))), "and take their place in the order")
	for gnawer in wave:
		combat.combatant_die(gnawer)
	ok(combat.fallen_of(1) == 2, "two of its side fallen", "%d" % combat.fallen_of(1))
	combat._bring_in_arrivals(true)
	ok(all_of("gnawer").is_empty(), "the wave waiting on three fallen does not come at two")
	combat.round_number = 3
	combat._bring_in_arrivals(false)
	ok(all_of("gnawer").size() == 2, "round 3: the next wave", "%d" % all_of("gnawer").size())
	combat.combatant_die(all_of("gnawer")[0])
	combat._bring_in_arrivals(true)
	ok(all_of("gnawer").size() == 3 and combat.arriving().is_empty(), "a third fallen: the last wave, and nobody left to come",
		"%d here, %d to come" % [all_of("gnawer").size(), combat.arriving().size()])
	for gnawer in all_of("gnawer"):
		combat.combatant_die(gnawer)
	combat.round_number = 1
	log_line("")

	log_line("======== it eats ========")
	var carrion := who("carrion_heap")
	put(glutton, Vector2i(55, -19))
	glutton.hp = 500
	var jaws := part_index(glutton, "Jaws")
	combat._break_part(glutton, jaws)
	ok(combat.part_broken(glutton, jaws) and not glutton.skill_list.has("devour"), "its Jaws broken: no Devour, no Bite")
	ok(combat.food_within(glutton).has(carrion), "the carcass is in reach")
	combat._glutton_turn_begins(glutton)
	ok(not carrion.alive and heard("devours the [color=orange]Carrion Heap"), "as its turn begins it eats it, free")
	ok(glutton.hp > 500, "fed, it heals", "%d" % glutton.hp)
	ok(not combat.part_broken(glutton, jaws) and glutton.skill_list.has("devour"), "and its Jaws grow back - Devour too")
	ok(combat.conditions_of(glutton).is_empty() and glutton.status_effects.any(func(e): return e.get("stat", "") == "physical"),
		"and it is Gorged - stronger for a while")
	glutton.status_effects.clear()
	log_line("")

	log_line("======== a carcass tainted ========")
	var heap: Dictionary = combat.create_combatant(load("res://data/objects/carrion_heap.tres"), "carrion_heap")
	combat.add_combatant(heap, 1, beside(glutton, heap))
	combat.use_object(cyrus, heap)
	ok(heap.name == "Tainted Carrion" and heap.object.edible and not heap.object.nourishing,
		"Used, the heap turns into Tainted Carrion", heap.name)
	combat._break_part(glutton, part_index(glutton, "Hind Legs"))
	var before: int = glutton.hp
	var stagger_before: float = glutton.stagger
	combat._glutton_turn_begins(glutton)
	ok(not heap.alive and glutton.hp < before, "it eats it anyway - and is hurt by it", "%d -> %d" % [before, glutton.hp])
	ok(combat.conditions_of(glutton).has(load("res://data/conditions/poisoned.tres")), "poisoned")
	ok(glutton.stagger > stagger_before, "and reels", "%.1f" % glutton.stagger)
	ok(combat.part_broken(glutton, part_index(glutton, "Hind Legs")), "but fed nothing: its legs stay broken")
	glutton.status_effects.clear()
	glutton.stagger = 0.0
	log_line("")

	log_line("======== parts grow back on their own ========")
	var legs := part_index(glutton, "Hind Legs")
	combat._regrow_part(glutton, legs)
	combat._break_part(glutton, legs)
	ok(combat.has_restriction(glutton, "prevents_movement"), "legs broken, it cannot move")
	for turn in glutton.parts[legs].regrows_after:
		combat._regrow_clock(glutton)
	ok(not combat.part_broken(glutton, legs) and not combat.has_restriction(glutton, "prevents_movement"),
		"%d of its turns later they are back, and so is its walk" % glutton.parts[legs].regrows_after)
	log_line("")

	log_line("======== its own dead ========")
	var gnawer: Dictionary = combat.create_combatant(load("res://data/enemies/gnawer.tres"), "gnawer")
	combat.add_combatant(gnawer, 1, beside(glutton, gnawer))
	var lies: Vector2i = gnawer.position
	combat.combatant_die(gnawer)
	ok(combat.food_within(glutton).has(gnawer), "a Gnawer falls beside it: food")
	combat.feed(glutton)
	ok(gnawer.get("eaten", false) and combat.fallen_at(lies, 1).is_empty(), "eaten - and gone, nothing left to stand back up")
	ok(not combat.food_within(glutton).has(cyrus), "the party's fallen are not on its menu")
	log_line("")

	log_line("======== the keg in meat ========")
	var keg := who("bait_keg")
	put(keg, beside(glutton, keg))
	var belly := part_index(glutton, "Belly Hole")
	before = glutton.hp
	combat.feed(glutton)
	ok(not keg.alive and glutton.hp < before - 40, "it swallows the keg - and it goes off inside", "%d -> %d" % [before, glutton.hp])
	ok(combat.part_broken(glutton, belly), "tearing its Belly Hole open")
	combat._regrow_part(glutton, belly)
	glutton.status_effects.clear()
	glutton.stagger = 0.0
	log_line("")

	log_line("======== swallowed ========")
	put(glutton, Vector2i(54, -16))
	ok(combat.refusal_for(glutton, SkillDatabase.skills["devour"], cyrus.position) != "", "nobody can be devoured who is not held first")
	await swallow(glutton, cyrus)
	ok(combat.is_inside(cyrus) and combat.swallower_of(cyrus).get("id", -1) == glutton.id, "held, and Devour landing: Cyrus is inside it")
	ok(not cyrus.sprite.visible and combat.get_combatant_at(cyrus.position).get("id", -1) != cyrus.id, "off the board: not drawn, on no tile")
	ok(combat.conditions_of(cyrus).has(load("res://data/conditions/swallowed.tres")) and cyrus.digest_left == 2, "Swallowed, two of its turns to get out")
	ok(combat.refusal_for(cyrus, SkillDatabase.skills["devour"], cyrus.position) != "" \
		and combat.refusal_for(cyrus, SkillDatabase.skills["heal"], alithia.position) != "", "from inside, nothing but it")
	var stab := ""
	for key in cyrus.skill_list:
		var skill: SkillDefinition = SkillDatabase.skills.get(key)
		if skill != null and skill.deals_damage and not skill.targets_ally and skill.aoe_radius == 0 and skill.spell_slot_level == 0:
			stab = key
			break
	ok(stab != "" and combat.refusal_for(cyrus, SkillDatabase.skills[stab], glutton.position) == "", "a blow at it, though, he can", stab)
	ok(combat.get_range_tiles(SkillDatabase.skills[stab], cyrus.position, 0, cyrus) == combat.tiles_of(glutton), "all of it in reach")
	ok(combat.part_index_at(glutton, combat._aim_from_inside(cyrus, glutton, glutton.position)) == belly, "and what he hits is the belly")
	ok(not combat._can_react(cyrus), "no reactions from in there")
	combat._digest(glutton)
	ok(cyrus.alive and cyrus.digest_left == 1, "a turn digested, still alive")
	combat._digest(glutton)
	ok(not cyrus.alive and not combat.is_inside(cyrus) and cyrus.sprite.visible, "a second: digested - dead, and out")
	ok(not combat.rect_of(glutton).has_point(cyrus.position) and not combat.fallen_at(cyrus.position, 0).is_empty(),
		"falling out of the hole behind it, a body that can still be stood back up")
	ok(heard("is digested"), "and the log says so")
	log_line("")

	log_line("======== out alive ========")
	await swallow(glutton, alithia)
	ok(combat.is_inside(alithia), "Alithia swallowed")
	combat._break_part(glutton, belly)
	ok(alithia.alive and not combat.is_inside(alithia) and alithia.sprite.visible, "its Belly Hole torn open: she falls out alive")
	ok(combat.conditions_of(alithia).has(load("res://data/conditions/bile_soaked.tres")), "covered in bile")
	combat._regrow_part(glutton, belly)
	alithia.status_effects.clear()
	await swallow(glutton, alithia)
	combat.stagger(glutton)
	ok(alithia.alive and not combat.is_inside(alithia), "staggered, it heaves her back up")
	glutton.status_effects.clear()
	glutton.erase("declared")
	await swallow(glutton, alithia)
	ok(combat.is_inside(alithia), "swallowed again")
	glutton.hp = 1
	combat.combatant_die(glutton)
	ok(alithia.alive and not combat.is_inside(alithia), "it falls: she climbs out")
	log_line("")

	game.queue_free()
	await settle()
	await phases()
	await the_ai()
	await squeezing()


## The fight again, fresh, for what changes as it goes down.
func open_fresh() -> Node:
	Campaign.reset()
	Campaign.current_encounter = load("res://data/encounters/boss_glutton.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(8)
	combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(1)
	combat.reaction_prompt = null
	said.clear()
	combat.update_information.connect(func(line): said.append(line))
	for comb in combat.combatants:
		comb.max_hp = maxi(comb.max_hp, 900)
		comb.hp = comb.max_hp
	return game


func phases():
	log_line("======== Gorge: a second head ========")
	var game = await open_fresh()
	var glutton := who("glutton")
	var most: int = combat.get_effective_stat(glutton, "max_hp")
	glutton.hp = roundi(most * 0.7)
	combat.lose_hp(glutton, roundi(most * 0.05))
	ok(glutton.phase_name == "Gorge" and glutton.parts.size() == 4 and glutton.holds_at_once == 2,
		"below two thirds: a fourth part, and it holds two", glutton.phase_name)
	var head := part_index(glutton, "Second Head")
	ok(combat.part_index_at(glutton, glutton.position + Vector2i(2, 0)) == head and combat.part_index_at(glutton, glutton.position + Vector2i(1, 0)) != head, "the head grows over half its Jaws")
	var jaw_marks: Array = combat.part_marks().filter(func(mark): return mark.name == "Jaws")
	ok(jaw_marks.size() == 1 and jaw_marks[0].tiles.size() == 4, "and only the half left is drawn as Jaws")
	var cyrus := who("cyrus")
	var alithia := who("alithia")
	put(cyrus, beside(glutton, cyrus))
	grab(glutton, cyrus)
	put(alithia, beside(glutton, alithia))
	grab(glutton, alithia)
	ok(combat.held_by(glutton).size() == 2, "two held at once")
	log_line("")

	log_line("======== The Hollow: it eats itself ========")
	combat._let_go(cyrus)
	combat._let_go(alithia)
	glutton.hp = roundi(most * 0.35)
	combat.lose_hp(glutton, roundi(most * 0.05))
	ok(glutton.phase_name == "The Hollow" and glutton.skill_list.has("rib_maws"), "below a third: Rib Maws", glutton.phase_name)
	put(glutton, Vector2i(54, -16))
	var food: Array = combat.food_within(glutton)
	ok(food.is_empty(), "nothing in reach to eat", "%s" % [food.map(func(f): return f.name)])
	var before: int = glutton.hp
	combat._glutton_turn_begins(glutton)
	ok(glutton.hp == before - roundi(most * 0.04), "so it tears into itself", "%d -> %d" % [before, glutton.hp])
	ok(glutton.status_effects.any(func(e): return e.get("stat", "") == "physical"), "and is Gorged on itself")
	game.queue_free()
	await settle()
	log_line("")


func the_ai():
	log_line("======== how it fights ========")
	var game = await open_fresh()
	var glutton := who("glutton")
	var cyrus := who("cyrus")
	combat.current_combatant = combat.combatants.find(glutton)
	combat.controller.set_controlled_combatant(glutton)
	await combat._ai_catch_scent(glutton)
	var scented: Array = combat.combatants.filter(func(comb): return comb.alive and combat.conditions_of(comb).has(combat.SCENTED))
	ok(scented.size() == 1 and scented[0].side == 0, "with its secondary it catches somebody's scent",
		"%s" % [scented.map(func(c): return c.name)])
	for comb in combat.combatants:
		comb.status_effects.clear()
	combat.put_condition(cyrus, combat.SCENTED, 2, glutton.name)
	ok(combat._ai_scented_prey(glutton).get("id", -1) == cyrus.id, "whoever has its scent on them is its prey")
	put(cyrus, beside(glutton, cyrus))
	glutton.skill_used_this_turn = false
	glutton.secondary_used_this_turn = false
	await combat.ai_glutton(glutton)
	await settle(4)
	ok(combat.holder_of(cyrus).get("id", -1) == glutton.id or combat.is_inside(cyrus) or heard("twists out"),
		"its turn: it goes for its prey, and gets hold of him", "%s" % [said.slice(-6)])
	ok(glutton.has("declared") or combat.is_inside(cyrus) or not combat.is_held(cyrus), "and means to swallow him")
	game.queue_free()
	await settle()
	log_line("")


## The top-left of a `w` x `h` block of open ground with nobody on it.
func open_block(w: int, h: int, avoid := Rect2i()) -> Vector2i:
	var region: Rect2i = combat.controller._astargrid.region
	for y in range(region.position.y, region.end.y - h + 1):
		for x in range(region.position.x, region.end.x - w + 1):
			var free := true
			for dy in h:
				for dx in w:
					var t := Vector2i(x + dx, y + dy)
					if not combat.controller.is_on_map(t) or combat.controller.is_tile_blocking(t, 0) or not combat.get_combatant_at(t).is_empty() \
							or avoid.has_point(t):
						free = false
			if free:
				return Vector2i(x, y)
	return Vector2i(-99999, -99999)


func squeezing():
	log_line("======== Hollow Frame: it folds to fit ========")
	var game = await open_fresh()
	var glutton := who("glutton")
	var cyrus := who("cyrus")
	var alithia := who("alithia")
	var controller = combat.controller
	ok(combat.can_squeeze(glutton) and not combat.can_squeeze(cyrus), "Erysichthon has Hollow Frame, and can squeeze; nobody else can")
	var spot := open_block(5, 4)
	ok(spot.x != -99999, "open ground to try it on", "%s" % spot)
	if spot.x == -99999:
		game.queue_free()
		await settle()
		return
	var aside := open_block(2, 1, Rect2i(spot, Vector2i(5, 4)))
	put(cyrus, aside)
	put(alithia, aside + Vector2i(1, 0))
	# How it would stand there, asked from where it is - out of the way, so its
	# own body is in none of them.
	var gap: Vector2i = spot + Vector2i(1, 0)
	ok(controller._stance(glutton, gap, glutton.position, 0) == Vector2i(4, 4), "with nobody about, it fits as it is")
	put(cyrus, gap + Vector2i(3, 3))
	ok(controller._stance(glutton, gap, glutton.position, 0) == Vector2i(4, 2), "the bottom of that square taken: it folds four by two")
	put(cyrus, gap + Vector2i(3, 0))
	ok(controller._stance(glutton, gap, glutton.position, 0) == Vector2i(2, 4), "the far side taken: two by four")
	put(alithia, gap + Vector2i(0, 3))
	ok(controller._stance(glutton, gap, glutton.position, 0) == Vector2i(2, 2), "both: two by two")
	put(alithia, aside + Vector2i(1, 0))
	# A step along from right beside it.
	put(glutton, spot)
	combat.fit_to_room(glutton)
	var steps: Array = controller._height_steps(spot, 0, spot, glutton, {})
	var into: Array = steps.filter(func(step): return step[0] == gap)
	ok(not into.is_empty() and into[0][1] == 2 * controller.get_tile_cost_for_class(gap, 0), "the step in costs twice over",
		"%s" % [into])
	var reach: Dictionary = controller.get_reachable_tiles(spot, 0, 8, glutton)
	ok(reach.has(gap), "so it can get there", "%s" % [reach.get(gap, "-")])
	var kept: Array = glutton.passives
	glutton.passives = []
	ok(controller._stance(glutton, gap, glutton.position, 0) == Vector2i.ZERO and not combat.can_squeeze(glutton),
		"without Hollow Frame it could not")
	glutton.passives = kept
	put(glutton, gap)
	ok(combat.fit_to_room(glutton) and Combat.footprint(glutton) == Vector2i(2, 4) and glutton.size == Sizes.Size.ENORMOUS,
		"standing there, it is folded two by four - and still Enormous", "%s" % Combat.footprint(glutton))
	ok(combat.tiles_of(glutton).size() == 8 and not combat.covers(glutton, gap + Vector2i(2, 0)) and combat.covers(glutton, gap + Vector2i(1, 3)),
		"it covers just those eight tiles")
	ok(heard("folds itself 2 by 4") and glutton.get("squeezed", false), "and the log says it folds itself")
	ok(glutton.sprite.scale.x < glutton.sprite.scale.y, "drawn squashed thin", "%s" % glutton.sprite.scale)
	ok(combat.part_index_at(glutton, gap) >= 0 and combat.part_index_at(glutton, gap + Vector2i(0, 3)) >= 0,
		"its parts fold with it")
	ok(combat.part_marks().filter(func(mark): return mark.id == glutton.id).all(func(mark): return mark.tiles.all(func(tile): return combat.covers(glutton, tile))),
		"and are marked only on the tiles it covers")
	combat.resync_size(glutton)
	ok(Combat.footprint(glutton) == Vector2i(2, 4), "its turn's ticks leave it folded while there is no room")
	put(cyrus, aside)
	ok(not combat.fit_to_room(glutton) and Combat.footprint(glutton) == Vector2i(4, 4) and glutton.position == gap,
		"room again: it opens out where it stands")
	ok(heard("opens out again") and not glutton.get("squeezed", false), "and the log says so")
	log_line("")

	log_line("======== a walk into the gap ========")
	put(glutton, spot)
	combat.fit_to_room(glutton)
	put(cyrus, gap + Vector2i(3, 3))
	combat.current_combatant = combat.combatants.find(glutton)
	controller.set_controlled_combatant(glutton)
	controller.movement = 8
	await controller.ai_move(gap)
	await settle(4)
	ok(glutton.position == gap and Combat.footprint(glutton) == Vector2i(4, 2), "it walks in, folding as it goes",
		"%s, %s" % [glutton.position, Combat.footprint(glutton)])
	ok(controller.movement == 8 - 2, "a step in, at twice the cost", "%d left" % controller.movement)
	game.queue_free()
	await settle()
	log_line("")
