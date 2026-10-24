extends Node
## Changing size in the middle of a fight (Combat "Growing"): Prometheus's
## Growth making an ally a size bigger for a while, the room it needs, wearing
## off, body parts stretching with whoever grows, and a boss phase that grows it.

var LOG_PATH := HarnessLog.path_for("growth")
var _log: FileAccess
var _fail = 0
var combat = null


func log_line(t): _log.store_line(t); _log.flush()

func ok(condition: bool, label: String, detail: String = ""):
	if condition:
		log_line("  PASS  %s %s" % [label, detail])
	else:
		_fail += 1
		log_line("  FAIL  %s %s" % [label, detail])


func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(200.0, true, false, true).timeout.connect(func():
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


func put(comb: Dictionary, tile: Vector2i):
	var from: Vector2i = comb.position
	comb.position = tile
	if comb.get("sprite") != null:
		comb.sprite.position = combat.sprite_point(comb)
	combat.controller.reposition_combatant(from, tile)


## Where `comb`'s picture is drawn, in the space their sprite node sits in.
func drawn_rect(comb: Dictionary) -> Rect2:
	var sprite = comb.sprite
	var drawn: Node2D = sprite._drawn()
	var size := Vector2.ZERO
	var offset := Vector2.ZERO
	if drawn is AnimatedSprite2D:
		size = drawn.sprite_frames.get_frame_texture(drawn.animation, drawn.frame).get_size()
		offset = drawn.offset
	else:
		size = drawn.texture.get_size() / Vector2(drawn.hframes, drawn.vframes)
		offset = drawn.offset
	return sprite.transform * drawn.transform * Rect2(offset - size / 2.0, size)


## The square `comb` covers, in the same space.
func square_rect(comb: Dictionary) -> Rect2:
	var square: Rect2i = combat.rect_of(comb)
	var top_left: Vector2 = combat.sprite_point(comb, square.position) - Vector2(Grid.HALF_TILE)
	return Rect2(top_left, Vector2(square.size) * Grid.TILE_SIZE)


## Whether `comb` is drawn standing in their square: feet on its bottom edge,
## across its middle.
func drawn_in_square(comb: Dictionary) -> bool:
	var picture := drawn_rect(comb)
	var square := square_rect(comb)
	return absf(picture.end.y - square.end.y) < 2.0 and absf(picture.get_center().x - square.get_center().x) < 2.0


## A tile `comb` could grow into from: room for a 2 x 2 square with it as the corner.
func open_corner(comb: Dictionary) -> Vector2i:
	var region: Rect2i = combat.controller._astargrid.region
	for y in range(region.position.y, region.end.y - 1):
		for x in range(region.position.x, region.end.x - 1):
			var tile := Vector2i(x, y)
			var free := true
			for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				var t: Vector2i = tile + d
				if combat.controller.is_tile_blocking(t, 0) or not combat.get_combatant_at(t).is_empty():
					free = false
			if free:
				return tile
	return Vector2i(-99999, -99999)


func run_test():
	Campaign.reset()
	var at_fourteen: EncounterDefinition = load("res://data/encounters/encounter_02_sappers.tres").duplicate(true)
	for spawn in at_fourteen.spawns:
		spawn.level = 14
	Campaign.current_encounter = at_fourteen
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(8)
	combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(1)
	combat.reaction_prompt = null
	var prometheus := who("prometheus")
	var enfina := who("enfina")

	log_line("======== Growth ========")
	var growth: SkillDefinition = SkillDatabase.skills.get("growth")
	ok(growth != null and prometheus.skill_list.has("growth") and growth.spell_slot_level == 2 and growth.targets_ally,
		"Prometheus knows Growth, through the Gates of Hermes, for an ally")
	var corner := open_corner(enfina)
	put(enfina, corner)
	combat.apply_effect(prometheus, enfina, growth.effects[0], growth, true)
	ok(enfina.size == Sizes.Size.LARGE and enfina.span == 2 and combat.tiles_of(enfina).size() == 4,
		"Enfina grows a size: Large, four tiles", "%s" % [combat.tiles_of(enfina)])
	ok(enfina.position == corner, "from her own tile, as the corner of the square")
	ok(is_equal_approx(enfina.sprite.scale.x, Sizes.draw_scale(Sizes.Size.LARGE, 2)), "and drawn bigger", "%s" % enfina.sprite.scale)
	ok(drawn_in_square(enfina), "on the square she covers - her feet on its bottom edge, across its middle",
		"%s in %s" % [drawn_rect(enfina), square_rect(enfina)])
	ok(combat.size_wanted(enfina) == Sizes.Size.LARGE and enfina.base_size == Sizes.Size.HUMAN, "for a while: underneath, still Human")
	var turns := 0
	while enfina.size != Sizes.Size.HUMAN and turns < 10:
		combat.end_of_turn_effects(enfina)
		combat.start_of_turn_effects(enfina)
		turns += 1
	ok(enfina.size == Sizes.Size.HUMAN and enfina.span == 1 and enfina.position == corner,
		"it wears off: back to one tile, in the corner she grew from", "after %d turns" % turns)
	ok(drawn_in_square(enfina), "drawn on her own tile again", "%s in %s" % [drawn_rect(enfina), square_rect(enfina)])
	log_line("")

	log_line("======== grown upward, drawn upward ========")
	# Somebody below and beside her: the square from her own tile has no room,
	# so it goes up a tile - and her drawing has to go with it.
	var room := open_corner(enfina)
	var prometheus_was: Vector2i = prometheus.position
	put(enfina, room + Vector2i(0, 1))
	put(prometheus, room + Vector2i(1, 2))
	combat.apply_effect(prometheus, enfina, growth.effects[0], growth, true)
	ok(enfina.size == Sizes.Size.LARGE and enfina.position == room, "she grows up a tile, from the square above",
		"%s, wanted %s" % [enfina.position, room])
	ok(drawn_in_square(enfina), "and is drawn there, not over the square below it",
		"%s in %s" % [drawn_rect(enfina), square_rect(enfina)])
	turns = 0
	while enfina.size != Sizes.Size.HUMAN and turns < 10:
		combat.end_of_turn_effects(enfina)
		combat.start_of_turn_effects(enfina)
		turns += 1
	ok(enfina.size == Sizes.Size.HUMAN and drawn_in_square(enfina), "back to her size, drawn on her tile",
		"%s in %s" % [drawn_rect(enfina), square_rect(enfina)])
	put(prometheus, prometheus_was)
	log_line("")

	log_line("======== no room ========")
	# Hemmed in on all four sides: every square holding her tile holds one of them.
	var region: Rect2i = combat.controller._astargrid.region
	var hemmers: Array = combat.combatants.filter(func(comb): return comb.alive and comb != enfina \
		and not comb.has("object") and comb.get("span", 1) == 1 and not Sizes.shares(comb.size))
	var sides := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var cramped := Vector2i(-99999, -99999)
	for y in range(region.position.y + 1, region.end.y - 1):
		for x in range(region.position.x + 1, region.end.x - 1):
			var tile := Vector2i(x, y)
			if cramped.x != -99999:
				break
			var clear: bool = not combat.controller.is_tile_blocking(tile, 0) and combat.get_combatant_at(tile).is_empty()
			for d in sides:
				var t: Vector2i = tile + d
				if combat.controller.is_tile_blocking(t, 0) or not combat.get_combatant_at(t).is_empty():
					clear = false
			if clear:
				cramped = tile
	ok(cramped.x != -99999 and hemmers.size() >= 4, "four others to hem her in with", "%d" % hemmers.size())
	if cramped.x != -99999 and hemmers.size() >= 4:
		put(enfina, cramped)
		for i in 4:
			put(hemmers[i], cramped + sides[i])
		ok(combat._room_to_grow(enfina, Sizes.Size.LARGE).x == -99999, "hemmed in, there is no square for her", "%s" % cramped)
		combat.apply_effect(prometheus, enfina, growth.effects[0], growth, true)
		ok(enfina.size == Sizes.Size.HUMAN and not enfina.status_effects.any(func(e): return e.get("stat", "") == "size"),
			"so Growth does not take - and nothing is left on her")
	log_line("")

	log_line("======== a bigger swing ========")
	var swing: SkillDefinition = SkillDatabase.skills["greatsword_attack"]
	var sweep: SkillDefinition = SkillDatabase.skills["sweep_strike"]
	var hurl: SkillDefinition = SkillDatabase.skills["hurl"]
	ok(combat.aoe_radius_of(enfina, swing) == 0, "at her own size, a greatsword swing is one tile")
	var foes: Array = combat.combatants.filter(func(comb): return comb.alive and comb.side == 1 \
		and not comb.has("object") and comb.get("span", 1) == 1 and not Sizes.shares(comb.size))
	var block := open_block(4, 2)
	ok(block.x != -99999 and foes.size() >= 2, "room for her and two enemies", "%s" % block)
	if block.x != -99999 and foes.size() >= 2:
		put(enfina, block + Vector2i(1, 0))
		var target: Dictionary = foes[0]
		put(target, block + Vector2i(2, 0))
		# Behind the one she swings at, a step off to the side.
		put(foes[1], block + Vector2i(3, 1))
		ok(combat.targets_if_aimed(enfina, swing, target.position).size() == 1, "her swing at one catches just the one")
		put(enfina, block)
		ok(combat.resize(enfina, Sizes.Size.LARGE) and enfina.position == block, "Enfina a size bigger, beside them")
		ok(combat.aoe_shape_of(enfina, swing) == SkillDefinition.AoEShape.CONE and combat.aoe_radius_of(enfina, swing) == 2,
			"her swing is a cone now, two long", "%d" % combat.aoe_radius_of(enfina, swing))
		var swept: Array = combat.get_impact_tiles(swing, combat.nearest_tile_of(enfina, target.position), target.position, 0, enfina.size, enfina)
		ok(swept.size() <= 4 and swept.has(target.position) and swept.has(block + Vector2i(3, 0)) and swept.has(block + Vector2i(3, 1)),
			"the tile she aims at and the three behind it (a wall may take one)", "%s" % [swept])
		var caught: Array = combat.targets_if_aimed(enfina, swing, target.position)
		ok(caught.size() == 2 and caught.has(foes[1]), "and catches the one behind as well")
		# Aimed anywhere round her, the cone goes out of the side of her facing
		# it - the aiming marks too (CController), which once drew it from her
		# top-left tile whichever way she swung.
		var own: Array = combat.tiles_of(enfina)
		var odd := []
		for dy in range(-1, 3):
			for dx in range(-1, 3):
				var aim: Vector2i = block + Vector2i(dx, dy)
				if aim in own or combat.controller.is_tile_blocking(aim, 0):
					continue
				var cone: Array = combat.get_impact_tiles(swing, combat.nearest_tile_of(enfina, aim), aim, 0, enfina.size, enfina)
				if not cone.has(aim) or cone.any(func(tile): return tile in own):
					odd.append(aim)
		ok(odd.is_empty(), "aimed at any tile round her, it lands there and never on herself", "%s" % [odd])
		ok(Combat.nearest_from(enfina, enfina.position, block + Vector2i(3, 1)) == combat.nearest_tile_of(enfina, block + Vector2i(3, 1)),
			"and the AI weighs it from the same tile")
		ok(combat.aoe_radius_of(enfina, sweep) == sweep.aoe_radius + 1, "a swing with an area of its own reaches a tile further")
		ok(combat.aoe_radius_of(enfina, hurl) == hurl.aoe_radius, "a throw is no swing: unchanged")
		ok(combat.aoe_radius_of(enfina, SkillDatabase.skills["chain_hook"]) == 0, "nor a hook that reaches five tiles")
		var bigger := {"size": Sizes.Size.ENORMOUS, "original_size": Sizes.Size.HUMAN}
		ok(combat.aoe_radius_of(bigger, swing) == 3, "two sizes bigger, a tile longer: three")
		ok(combat.resize(enfina, Sizes.Size.HUMAN), "back to her own size")
		ok(combat.resize(enfina, Sizes.Size.SMALL), "and shrunk to Small")
		ok(combat.aoe_radius_of(enfina, swing) == 0 and combat.aoe_shape_of(enfina, swing) == swing.aoe_shape,
			"a swing at one tile is still the one tile")
		ok(combat.aoe_radius_of(enfina, sweep) == sweep.aoe_radius - 1, "one with an area reaches a tile less")
		combat.resize(enfina, Sizes.Size.HUMAN)
	log_line("")

	log_line("======== parts stretch ========")
	var glutton: Dictionary = combat.create_combatant(load("res://data/enemies/glutton.tres"), "glutton", "", null, 14)
	var spot := Vector2i(-99999, -99999)
	for y in range(region.position.y, region.end.y - 3):
		for x in range(region.position.x, region.end.x - 3):
			var tile := Vector2i(x, y)
			var free := true
			for dy in 4:
				for dx in 4:
					var t: Vector2i = tile + Vector2i(dx, dy)
					if combat.controller.is_tile_blocking(t, 0) or not combat.get_combatant_at(t).is_empty():
						free = false
			if free and spot.x == -99999:
				spot = tile
	ok(spot.x != -99999, "somewhere a 4 x 4 fits", "%s" % spot)
	if spot.x != -99999:
		combat.add_combatant(glutton, 1, spot)
		var jaws: BodyPartDefinition = glutton.parts[0]
		ok(glutton.span == 4 and jaws.tiles.size() == 8, "the glutton is Enormous, its Jaws eight tiles")
		ok(combat.resize(glutton, Sizes.Size.LARGE) and glutton.span == 2, "the glutton shrunk to Large")
		ok(glutton.parts[0].tiles.size() == 2 and jaws.tiles.size() == 8, "its Jaws shrink to two tiles - its own copy, the rest of its kind untouched",
			"%s" % [glutton.parts[0].tiles])
		ok(combat.part_index_at(glutton, glutton.position + Vector2i(1, 0)) == 0, "the far corner of its head is still its Jaws")
		ok(combat.resize(glutton, Sizes.Size.ENORMOUS) and glutton.parts[0].tiles.size() == 8
				and combat.part_index_at(glutton, glutton.position + Vector2i(3, 1)) == 0, "grown back, they stretch again")
		combat.resize(glutton, Sizes.Size.LARGE)
		# Grown for good by a phase, as if Large were its own size.
		glutton.base_size = Sizes.Size.LARGE
		var phase := BossPhase.new()
		phase.name = "Bloat"
		phase.grows = 1
		combat._begin_phase(glutton, phase)
		ok(glutton.base_size == Sizes.Size.ENORMOUS and glutton.size == Sizes.Size.ENORMOUS and glutton.span == 4,
			"a phase that grows it: Enormous now, for good", "%d / %d" % [glutton.base_size, glutton.size])
		ok(glutton.parts[0].tiles.size() == 8, "its parts stretching with it")
	game.queue_free()
	await settle()


## The top-left of a `w` x `h` block of open ground with nobody on it.
func open_block(w: int, h: int) -> Vector2i:
	var region: Rect2i = combat.controller._astargrid.region
	for y in range(region.position.y, region.end.y - h + 1):
		for x in range(region.position.x, region.end.x - w + 1):
			var free := true
			for dy in h:
				for dx in w:
					var t := Vector2i(x + dx, y + dy)
					if not combat.controller.is_on_map(t) or combat.controller.is_tile_blocking(t, 0) or not combat.get_combatant_at(t).is_empty():
						free = false
			if free:
				return Vector2i(x, y)
	return Vector2i(-99999, -99999)
