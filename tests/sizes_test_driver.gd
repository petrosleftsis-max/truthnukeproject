extends Node
## Sizes: Tiny and Small sharing a tile with their own side, Large and up
## covering a square of tiles - fitting where they go, caught by any tile of
## theirs, reaching from every edge - Monstrous and up walking where a flier
## could, and bodies as cover to anybody not two sizes bigger.

var LOG_PATH := HarnessLog.path_for("sizes")
const MIXED := "res://data/encounters/sizes_big_and_small.tres"
const COLOSSUS := "res://data/encounters/sizes_colossus.tres"

var _log: FileAccess = null
var _fail = 0
var game: Node = null
var combat = null


func log_line(t: String):
	if _log:
		_log.store_line(t)
		_log.flush()


func ok(condition: bool, label: String, detail: String = ""):
	if condition:
		log_line("  PASS  %s %s" % [label, detail])
	else:
		_fail += 1
		log_line("  FAIL  %s %s" % [label, detail])


func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(240.0, true, false, true).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	var booted = get_tree().current_scene
	if booted != null:
		booted.queue_free()
		await settle()
	the_rule()
	await small_ones()
	await big_ones()
	await sight()
	await the_colossus()
	await close_fight()
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


func open_fight(path: String):
	await close_fight()
	Campaign.reset()
	Campaign.current_encounter = load(path)
	game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(6)
	combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(2)


func close_fight():
	if game != null and is_instance_valid(game):
		game.queue_free()
		await settle(3)
	game = null


func all_of(key: String) -> Array:
	return combat.combatants.filter(func(c): return c.get("combatant_key", "") == key and c.alive)


func who(key: String) -> Dictionary:
	var found := all_of(key)
	return found[0] if not found.is_empty() else {}


func the_rule():
	log_line("======== the sizes ========")
	ok(Sizes.NAMES == ["Tiny", "Small", "Human", "Large", "Enormous", "Monstrous", "Gigantic"], "seven, smallest to biggest")
	ok(Sizes.span(Sizes.Size.HUMAN) == 1 and Sizes.span(Sizes.Size.LARGE) == 2 and Sizes.span(Sizes.Size.ENORMOUS) == 4
		and Sizes.span(Sizes.Size.MONSTROUS) == 8, "Human one tile, and each step up twice as wide")
	ok(Sizes.span(Sizes.Size.GIGANTIC) == 16 and Sizes.span(Sizes.Size.GIGANTIC, 24) == 24 and Sizes.span(Sizes.Size.GIGANTIC, 4) == 16,
		"Gigantic sixteen or bigger")
	ok(is_equal_approx(Sizes.draw_scale(Sizes.Size.SMALL), 0.5) and is_equal_approx(Sizes.draw_scale(Sizes.Size.TINY), 0.25),
		"each step down half as wide: Small a half, Tiny a quarter")
	ok(Sizes.SPACE_IN_A_TILE / Sizes.share(Sizes.Size.TINY) == 16 and Sizes.SPACE_IN_A_TILE / Sizes.share(Sizes.Size.SMALL) == 4,
		"so a tile holds sixteen Tiny, or four Small")
	log_line("")


func small_ones():
	log_line("======== the small share a tile ========")
	await open_fight(MIXED)
	var rats := all_of("rat")
	var imps := all_of("imp")
	ok(rats.size() == 4 and rats.all(func(r): return r.position == rats[0].position), "four rats on the one tile")
	ok(combat.combatants_at(rats[0].position).size() == 4, "all four are there")
	ok(imps.size() == 2 and imps[0].position == imps[1].position, "two imps on another")
	var spare: Dictionary = combat.create_combatant(CombatantDatabase.combatants.rat, "rat")
	spare["side"] = 1
	ok(combat.room_for(spare, rats[0].position), "there is room for another rat")
	spare["side"] = 0
	ok(not combat.room_for(spare, rats[0].position), "but not for one of the other side")
	var person: Dictionary = combat.create_combatant(CombatantDatabase.combatants.cyrus, "cyrus")
	person["side"] = 1
	ok(not combat.room_for(person, rats[0].position), "nor for anybody a tile big")
	var imp: Dictionary = combat.create_combatant(CombatantDatabase.combatants.imp, "imp")
	imp["side"] = 1
	ok(combat.room_for(imp, imps[0].position), "two imps leave room for two more")
	for i in 2:
		var more: Dictionary = combat.create_combatant(CombatantDatabase.combatants.imp, "imp")
		combat.add_combatant(more, 1, imps[0].position)
	await settle(2)
	ok(not combat.room_for(imp, imps[0].position), "four fill it")
	var drawn := rats.map(func(r): return combat.drawing_offset(r))
	var distinct := {}
	for offset in drawn:
		distinct[offset] = true
	ok(distinct.size() == 4, "each rat drawn in its own corner of the tile", "%s" % [drawn])
	ok(is_equal_approx(rats[0].sprite.scale.x, 0.25) and is_equal_approx(imps[0].sprite.scale.x, 0.5), "drawn a quarter and a half as big")

	log_line("")
	log_line("======== hitting one of them, or all ========")
	var cyrus := who("cyrus")
	var beside := Vector2i(-1, -1)
	for way in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var tile: Vector2i = rats[0].position + way
		if combat.room_for(cyrus, tile):
			beside = tile
			break
	combat.teleport_to(cyrus, beside)
	await settle(1)
	for rat in rats:
		rat.hp = 50
		rat.max_hp = 50
	combat.current_combatant = combat.combatants.find(cyrus)
	cyrus.skill_used_this_turn = false
	combat.aim_choice = rats[2].id
	await combat.use_skill("rapier", cyrus, rats[0].position, false)
	await settle(3)
	var hurt := rats.filter(func(r): return r.hp < 50)
	ok(hurt.size() == 1 and hurt[0] == rats[2], "a single strike lands on the one picked, not all four",
		"%d hurt" % hurt.size())
	cyrus.skill_used_this_turn = false
	var blast: Array = combat.get_targets_in_tiles([rats[0].position], cyrus, false)
	ok(blast.size() == 4, "while an area catches every one of them")
	log_line("")


func big_ones():
	log_line("======== the big cover a square ========")
	var ogre := who("ogre")
	var golem := who("golem")
	var behemoth := who("behemoth")
	ok(combat.tiles_of(ogre).size() == 4 and combat.tiles_of(golem).size() == 16 and combat.tiles_of(behemoth).size() == 64,
		"Large 2 x 2, Enormous 4 x 4, Monstrous 8 x 8")
	var corner: Vector2i = ogre.position + Vector2i(1, 1)
	ok(combat.get_combatant_at(corner) == ogre and combat.covers(ogre, corner), "the ogre is on every tile of its square")
	ok(is_equal_approx(ogre.sprite.scale.x, 2.0) and ogre.sprite.size_offset != Vector2.ZERO, "drawn twice the size, over its whole square")
	var caught: Array = combat.get_targets_in_tiles([corner, corner + Vector2i.LEFT], who("cyrus"), false)
	ok(caught.count(ogre) == 1, "an area over two of its tiles catches it once")
	var off_corner: Vector2i = ogre.position + Vector2i(2, 1)
	ok(combat.distance_to(ogre, off_corner) == 1, "a tile beside its far side is one step from it")
	var reach: Array = combat.get_range_tiles(SkillDatabase.skills.greatsword_attack, ogre.position, 0, ogre)
	ok(reach.has(ogre.position + Vector2i(2, 0)) and reach.has(ogre.position + Vector2i(-1, 1)) and reach.has(ogre.position + Vector2i(1, 2)),
		"it swings from every edge of its square", "%d tiles" % reach.size())
	var walked: Dictionary = combat.controller.get_reachable_tiles(ogre.position, ogre.movement_class, 3, ogre)
	ok(walked.size() > 1 and walked.keys().all(func(anchor): return combat.room_for(ogre, anchor)), "it walks only where its whole square fits",
		"%d places" % walked.size())
	combat.current_combatant = combat.combatants.find(ogre)
	combat.controller.update_points_weight()
	var astar = combat.controller._astargrid
	var open := 0
	var wrong := 0
	var region: Rect2i = astar.region
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var anchor := Vector2i(x, y)
			if astar.is_point_solid(anchor):
				continue
			open += 1
			if anchor != ogre.position and not combat.room_for(ogre, anchor):
				wrong += 1
	ok(open > 0 and wrong == 0, "and on its turn the pathfinder agrees", "%d open, %d wrong" % [open, wrong])
	ok(Combat.terrain_class(behemoth) == 1 and Combat.terrain_class(ogre) == 0, "the behemoth answers only to what stops a flier")
	var over_a_wall := false
	for y in range(region.position.y, region.end.y - 8):
		for x in range(region.position.x, region.end.x - 8):
			var anchor := Vector2i(x, y)
			var walls := false
			for tile in combat.tiles_of(behemoth, anchor):
				walls = walls or combat.controller.is_tile_blocking(tile, 0)
			if walls and combat.room_for(behemoth, anchor):
				over_a_wall = true
				break
		if over_a_wall:
			break
	ok(over_a_wall, "so it can stand over walls a walker could not cross")
	log_line("")


func sight():
	log_line("======== bodies as cover, by size ========")
	var cyrus := who("cyrus")
	var rats := all_of("rat")
	var ogre := who("ogre")
	ok(not combat.controller.blocks_sight(rats[0].position, Sizes.Size.HUMAN), "a Human sees over rats")
	ok(combat.controller.blocks_sight(rats[0].position, Sizes.Size.SMALL), "an imp does not")
	ok(combat.controller.blocks_sight(ogre.position, Sizes.Size.HUMAN), "nobody Human sees past an ogre")
	ok(not combat.controller.blocks_sight(ogre.position, Sizes.Size.MONSTROUS), "but a behemoth does")
	ok(combat.controller.blocks_sight(cyrus.position, Sizes.Size.HUMAN) and not combat.controller.blocks_sight(cyrus.position, Sizes.Size.ENORMOUS),
		"a person is cover to a person, and not to a golem")
	log_line("")


func the_colossus():
	log_line("======== the colossus ========")
	await open_fight(COLOSSUS)
	var colossus := who("colossus")
	ok(not colossus.is_empty() and colossus.span == 16 and combat.tiles_of(colossus).size() == 256, "sixteen tiles a side")
	var party: Array = combat.combatants.filter(func(c): return c.side == 0)
	ok(party.all(func(p): return not combat.covers(colossus, p.position)), "with the party standing clear of it")
	ok(is_equal_approx(colossus.sprite.scale.x, 16.0), "drawn sixteen times the size")
	log_line("")
