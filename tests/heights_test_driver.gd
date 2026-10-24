extends Node
## Heights (Combat "Heights", CController "Heights"), on the "Two Floors" map: a
## ground floor with barrels to climb onto from a climb tile beside them, and a
## gallery over it reached by stairs. Up only from a climb tile, down from
## anywhere; up on high ground, low things are no cover either way; between
## floors, range is across plus a step a storey, and a line must pass the floor
## between through open air - nobody straight under the gallery, or under it
## beside whoever looks down, can be seen.

var LOG_PATH := HarnessLog.path_for("heights")
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
	combat.controller.reposition_combatant(from, tile)
	var sprite = comb.get("sprite")
	if sprite != null and is_instance_valid(sprite):
		sprite.position = combat.sprite_point(comb)


func steps_from(tile: Vector2i) -> Array:
	return combat.controller._height_steps(tile, 0, tile).map(func(step): return step[0])


## Gallery tile over ground tile `real`.
func up(real: Vector2i) -> Vector2i:
	return combat.tile_on(1, real)


func run_test():
	Campaign.reset()
	Campaign.current_encounter = load("res://data/encounters/two_floors.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(8)
	combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(1)
	combat.reaction_prompt = null
	combat.update_information.connect(func(line): said.append(line))
	var controller = combat.controller
	var enfina := who("enfina")
	var cyrus := who("cyrus")
	var alithia := who("alithia")
	var ranger := who("ranger")
	# Out of everybody's way, so the tiles below are free to stand on.
	for comb in combat.combatants:
		comb.max_hp = 999
		comb.hp = 999

	log_line("======== the map ========")
	ok(combat.heights_in_play() and combat.floors.size() == 2, "two floors, and climb tiles", "%d climb tiles" % combat.climb_tiles.size())
	ok(combat.floor_of(Vector2i(5, 13)) == 0 and combat.floor_of(Vector2i(36, 3)) == 1, "the ground, and the gallery")
	ok(combat.real_of(Vector2i(36, 3)) == Vector2i(8, 3) and up(Vector2i(8, 3)) == Vector2i(36, 3), "the gallery lies over the ground")
	ok(ranger.get("up", false) and controller.up_at(ranger.position) and Combat.terrain_class(ranger) == 1,
		"the Ranger stands up on the barrels")
	log_line("")

	log_line("======== up only from a climb tile ========")
	ok(not steps_from(Vector2i(7, 10)).has(Vector2i(7, 9)), "from beside the barrels, no way up onto them")
	ok(steps_from(Vector2i(5, 9)).has(Vector2i(6, 9)), "from the climb tile beside them, up")
	var along: Array = steps_from(Vector2i(6, 9))
	ok(along.has(Vector2i(7, 9)) and along.has(Vector2i(6, 10)) and along.has(Vector2i(5, 10)), "up there: along the barrels, and down anywhere")
	put(enfina, Vector2i(5, 12))
	var path: Array = controller._height_path(Vector2i(5, 12), Vector2i(7, 9), 0)
	ok(path.back() == Vector2i(7, 9) and path.has(Vector2i(5, 9)), "a walk onto the barrels goes by the climb tile", "%s" % [path])
	var reach: Dictionary = controller.get_reachable_tiles(Vector2i(5, 12), 0, 5, enfina)
	ok(reach.has(Vector2i(6, 9)) and not reach.has(Vector2i(8, 9)), "and costs its steps", "%s" % [reach.get(Vector2i(6, 9), "-")])
	log_line("")

	log_line("======== up the stairs, and down off the edge ========")
	ok(steps_from(Vector2i(19, 10)).has(up(Vector2i(19, 10))), "from the stairs under the walkway, up onto it")
	ok(steps_from(Vector2i(19, 9)).all(func(tile): return combat.floor_of(tile) == 0), "from anywhere else on the ground, no")
	var edge := up(Vector2i(5, 4))
	ok(steps_from(edge).has(Vector2i(5, 5)), "from the gallery's edge, down into the open below")
	ok(steps_from(up(Vector2i(5, 2))).all(func(tile): return combat.floor_of(tile) == 1), "from further back, no - there is floor all round")
	path = controller._height_path(Vector2i(3, 13), up(Vector2i(9, 2)), 0)
	ok(path.back() == up(Vector2i(9, 2)) and (path.has(Vector2i(2, 4)) or path.has(Vector2i(19, 10))),
		"a walk from the ground to the gallery goes up the stairs", "%s" % [path])
	log_line("")

	log_line("======== a walk up the stairs ========")
	put(enfina, Vector2i(2, 6))
	combat.current_combatant = combat.combatants.find(enfina)
	controller.set_controlled_combatant(enfina)
	controller.movement = 4
	controller.find_path(up(Vector2i(2, 3)))
	controller.move_player()
	var waited := 0
	var hopped := false
	while not controller._arrived and waited < 400:
		await get_tree().process_frame
		waited += 1
		if enfina.sprite._hop_tween != null and enfina.sprite._hop_tween.is_valid():
			hopped = true
	ok(enfina.position == up(Vector2i(2, 3)) and combat.floor_of(enfina.position) == 1,
		"Enfina walks up the stairs onto the gallery", "%s" % enfina.position)
	ok(hopped, "hopping up as she gets there")
	ok(said.any(func(line): return "climbs up to Gallery" in line), "and the log says so")
	ok(controller.shown_floor() == 1 or combat.camera == null or not is_instance_valid(combat.camera), "the view goes with her", "%d" % controller.shown_floor())
	log_line("")

	log_line("======== range and sight between floors ========")
	put(enfina, Vector2i(3, 13))
	var bow: Dictionary = {}
	for comb in combat.combatants:
		if comb.alive and comb.get("combatant_key", "") == "hired_bow" and comb.position == up(Vector2i(8, 3)):
			bow = comb
	ok(not bow.is_empty(), "an archer on the gallery over (8, 3)")
	ok(combat.get_position_distance(bow.position, Vector2i(8, 8)) == 6, "range across: the distance, and a step a storey",
		"%d" % combat.get_position_distance(bow.position, Vector2i(8, 8)))
	ok(not combat.has_line_of_sight(bow.position, Vector2i(8, 3), 0) and not combat.floors_open_between(bow.position, Vector2i(8, 3)),
		"straight underneath: the floor is in the way")
	ok(not combat.has_line_of_sight(bow.position, Vector2i(9, 3), 0), "under the gallery beside it: still the floor")
	ok(combat.has_line_of_sight(bow.position, Vector2i(8, 8), 0) and combat.has_line_of_sight(Vector2i(8, 8), bow.position, 0),
		"out in the open: seen through the air - both ways")
	var shot: SkillDefinition = SkillDatabase.skills["nail_projectile"]
	var tiles: Array = combat.get_range_tiles(shot, bow.position, 0, bow)
	ok(tiles.has(Vector2i(8, 8)) and not tiles.has(Vector2i(8, 3)), "its reach takes in the open ground below, not what is under it")
	ok(combat.refusal_for(bow, shot, Vector2i(8, 3)) == "The floor is in the way", "aimed under itself, refused", combat.refusal_for(bow, shot, Vector2i(8, 3)))
	log_line("")

	log_line("======== high ground is no cover ========")
	for comb in [enfina, cyrus, alithia]:
		put(comb, Vector2i(2 + [enfina, cyrus, alithia].find(comb), 14))
	ok(not combat.has_line_of_sight(Vector2i(5, 9), Vector2i(9, 9), 0), "across the barrels on the ground: no line")
	put(cyrus, Vector2i(8, 9))
	ok(cyrus.get("up", false), "Cyrus up on the end barrel")
	ok(combat.has_line_of_sight(Vector2i(5, 9), Vector2i(8, 9), 0), "up there, the barrels between are no cover to him")
	ok(combat.has_line_of_sight(Vector2i(8, 9), Vector2i(5, 9), 0), "nor to anybody he looks at")
	ok(not combat._aim_blocked(Vector2i(8, 9), 0), "and he can be aimed at, barrel and all")
	put(cyrus, Vector2i(9, 9))
	ok(not cyrus.get("up", false), "stepped down, he is not up any more")
	log_line("")

	log_line("======== big ones step over ========")
	put(enfina, Vector2i(6, 11))
	ok(combat.resize(enfina, Sizes.Size.LARGE), "Enfina grown to Large")
	ok(not combat.blocks_for(enfina, Vector2i(6, 9)) and combat.blocks_for(cyrus, Vector2i(6, 9)),
		"the barrels are no wall to her - they are to Cyrus")
	ok(controller._stance(enfina, Vector2i(6, 8), enfina.position, 0) == Vector2i(2, 2), "she can stand astride them, no climb tile needed")
	ok(controller.get_reachable_tiles(enfina.position, 0, 3, enfina).has(Vector2i(6, 9)), "and walks straight onto them")
	ok(Combat.elevation(enfina) == 1 and controller.raised_at(enfina.position) == 1, "a size bigger is a level higher")
	ok(combat.has_line_of_sight(Vector2i(4, 9), Vector2i(9, 9), 0, Sizes.Size.LARGE),
		"her eyes over the barrels: she sees past them")
	put(enfina, Vector2i(9, 9))
	ok(combat.has_line_of_sight(Vector2i(5, 9), Vector2i(9, 9), 0, Sizes.Size.HUMAN, enfina),
		"and behind them she is not hidden - they are no cover to her")
	log_line("")

	log_line("======== wide stairs ========")
	put(enfina, Vector2i(19, 10))
	var stairs_up := up(Vector2i(19, 10))
	var big_steps: Array = controller._height_steps(enfina.position, 0, enfina.position, enfina, {}).map(func(step): return step[0])
	ok(not big_steps.has(stairs_up), "stairs a tile wide are too narrow for her")
	var wider := [Vector2i(20, 10), Vector2i(19, 11), Vector2i(20, 11)]
	for tile in wider:
		combat.climb_tiles[tile] = true
	big_steps = controller._height_steps(enfina.position, 0, enfina.position, enfina, {}).map(func(step): return step[0])
	ok(big_steps.has(stairs_up), "stairs two wide take her up", "%s" % [big_steps])
	ok(steps_from(Vector2i(20, 11)).has(up(Vector2i(20, 11))), "and anybody smaller")
	for tile in wider:
		combat.climb_tiles.erase(tile)
	log_line("")

	log_line("======== small ones climb ========")
	ok(combat.resize(enfina, Sizes.Size.HUMAN), "Enfina back to her own size")
	put(enfina, Vector2i(3, 14))
	put(cyrus, Vector2i(5, 10))
	# Below Cat Burglar's level: the rule for anybody (see "Cat Burglar" below).
	cyrus.level = 1
	ok(combat.resize(cyrus, Sizes.Size.SMALL), "Cyrus shrunk to Small")
	ok(not controller.get_reachable_tiles(cyrus.position, 0, 1, cyrus).has(Vector2i(6, 9)), "beside the barrels, no straight way up")
	ok(controller.get_reachable_tiles(cyrus.position, 0, 3, cyrus).has(Vector2i(6, 9)), "by the climb tile, up he goes")
	put(cyrus, Vector2i(6, 9))
	ok(cyrus.get("up", false), "and stands up there")
	ok(combat.resize(cyrus, Sizes.Size.HUMAN), "Cyrus back to his own size")
	put(cyrus, Vector2i(9, 14))
	log_line("")

	log_line("======== a tall one between floors ========")
	put(enfina, Vector2i(8, 5))
	ok(not combat.has_line_of_sight(bow.position, Vector2i(8, 5), 0, Sizes.Size.HUMAN, enfina),
		"just past the gallery's edge, the floor hides her from the archer above")
	ok(combat.resize(enfina, Sizes.Size.LARGE), "grown to Large there")
	ok(combat.has_line_of_sight(bow.position, Vector2i(8, 5), 0, Sizes.Size.HUMAN, enfina)
			and combat.has_line_of_sight(Vector2i(8, 5), bow.position, 0, Sizes.Size.LARGE),
		"tall enough to see over its edge - and be seen")
	ok(combat.resize(enfina, Sizes.Size.HUMAN), "and back")
	put(enfina, Vector2i(3, 14))
	log_line("")

	log_line("======== no line through a floor ========")
	put(enfina, Vector2i(8, 6))
	ok(combat.resize(enfina, Sizes.Size.LARGE), "Enfina Large, out in the open beside the gallery")
	put(cyrus, Vector2i(8, 2))
	ok(not combat.has_line_of_sight(Vector2i(8, 6), Vector2i(8, 2), 0, Sizes.Size.LARGE)
			and not combat.has_line_of_sight(Vector2i(8, 2), Vector2i(8, 6), 0, Sizes.Size.HUMAN, enfina),
		"Cyrus deep under the gallery: her eyes are up past its floor, and the floor is in the way - both ways")
	put(cyrus, Vector2i(8, 4))
	ok(combat.has_line_of_sight(Vector2i(8, 6), Vector2i(8, 4), 0, Sizes.Size.LARGE),
		"just under its edge, the line comes down past the edge in the open")
	ok(combat.resize(enfina, Sizes.Size.HUMAN), "and back")
	put(cyrus, Vector2i(8, 2))
	ok(combat.has_line_of_sight(Vector2i(8, 6), Vector2i(8, 2), 0), "a Human's eyes are under the floor: he is seen")
	put(enfina, Vector2i(3, 14))
	put(cyrus, Vector2i(9, 14))
	log_line("")

	log_line("======== danger from another floor ========")
	var sellsword := who("sellsword")
	var bows: Array = combat.combatants.filter(func(comb): return comb.alive and comb.get("combatant_key", "") == "hired_bow")
	for comb in [ranger, sellsword]:
		comb.hidden = true
	for comb in bows:
		comb.movement = 0
	var map: Dictionary = combat.threat_map()
	ok(map.threat.has(Vector2i(8, 8)), "the archers on the gallery threaten the open ground below")
	ok(not map.threat.has(Vector2i(8, 2)), "not the ground under it")
	ok(map.get("across", {}).get(bow.id, {}).has(0), "and they are marked as threatening the ground")
	controller.set_danger_view(true)
	ok(controller.danger().get("across", {}).get(bow.id, {}).has(0), "which the danger view has, for their ghosts in red")
	controller.set_danger_view(false)
	for comb in [ranger, sellsword]:
		comb.hidden = false
	for comb in bows:
		comb.movement = 5
	log_line("")

	log_line("======== reactions across floors ========")
	var greatsword: SkillDefinition = SkillDatabase.skills["greatsword_attack"]
	ok(combat.reach_gap(bow, cyrus, shot, Vector2i(8, 8)) == 6, "a shot reaches down across the floors", "%d" % combat.reach_gap(bow, cyrus, shot, Vector2i(8, 8)))
	ok(combat.reach_gap(bow, cyrus, greatsword, Vector2i(8, 8)) == Combat.OUT_OF_REACH, "a melee blow keeps to its floor")
	put(cyrus, Vector2i(8, 8))
	ok(combat._reaction_target(bow, shot, cyrus, {}) == cyrus, "a ranged reaction finds him out in the open below")
	put(cyrus, Vector2i(8, 2))
	ok(combat._reaction_target(bow, shot, cyrus, {}).is_empty(), "not under the gallery")
	bow.skill_used_this_turn = false
	bow.reaction_used = false
	ok(combat.ready_refusal(bow, "nail_projectile", SkillDefinition.Trigger.ENTERS_AREA, Vector2i(8, 2)) == "The floor is in the way",
		"an area readied under its own floor: refused")
	ok(combat.ready_action(bow, "nail_projectile", SkillDefinition.Trigger.ENTERS_AREA, Vector2i(8, 8)),
		"an area readied on the ground below")
	ok(bow.readied.area.all(func(tile): return combat.floor_of(tile) == 0), "watching the ground floor only")
	put(cyrus, Vector2i(4, 8))
	await combat._react_to_step(cyrus, Vector2i(3, 8), Vector2i(4, 8))
	ok(bow.reaction_used and not bow.has("readied"), "Cyrus steps into it: the archer above shoots", "%s" % [said.slice(-3)])
	put(cyrus, Vector2i(9, 14))
	log_line("")

	log_line("======== Cat Burglar ========")
	var burglar_steps := func() -> Array:
		return controller._height_steps(cyrus.position, 0, cyrus.position, cyrus, {}).map(func(step): return step[0])
	cyrus.level = 1
	put(cyrus, Vector2i(5, 10))
	ok(not burglar_steps.call().has(Vector2i(6, 9)), "before level 24, Cyrus needs the climb tile like anybody")
	cyrus.level = 24
	ok(combat.climbs_anywhere(cyrus) and combat.get_effective_stat(cyrus, "movement") == 8,
		"at level 24, Cat Burglar II: two more tiles of movement, eight in all", "%d" % combat.get_effective_stat(cyrus, "movement"))
	ok(burglar_steps.call().has(Vector2i(6, 9)), "and straight up onto the barrels from beside them")
	ok(controller.hop_for(cyrus, Vector2i(5, 10), Vector2i(6, 9)) == CombatantSprite.Hop.UP
		and controller.hop_for(cyrus, Vector2i(6, 9), Vector2i(5, 10)) == CombatantSprite.Hop.DOWN,
		"jumping up onto them, and down off them")
	var level_ground := Vector2i(-99999, -99999)
	for way in [Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP, Vector2i.RIGHT]:
		var beside: Vector2i = Vector2i(5, 10) + way
		if level_ground.x == -99999 and controller.is_on_map(beside) and not controller.is_tile_blocking(beside, 0):
			level_ground = beside
	ok(controller.hop_for(cyrus, Vector2i(5, 10), level_ground) == CombatantSprite.Hop.NONE, "along the ground, no jump", "%s" % level_ground)
	# He walks by the rules of heights everywhere, where a diagonal step costs
	# what a straight one does: along open ground he still goes straight, not in
	# a zig-zag of steps that cost the same.
	var lane := Vector2i(-99999, -99999)
	var region: Rect2i = controller._astargrid.region
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x - 5):
			if lane.x != -99999:
				break
			var clear := true
			for i in 5:
				var tile := Vector2i(x + i, y)
				if not controller.is_on_map(tile) or combat.floor_of(tile) != 0 or controller.is_tile_blocking(tile, 0) \
						or combat.is_high(tile) or controller.get_tile_cost_for_class(tile, 0) != 1 \
						or not combat.get_combatant_at(tile).is_empty():
					clear = false
			if clear:
				lane = Vector2i(x, y)
	ok(lane.x != -99999, "five tiles of open ground in a row", "%s" % lane)
	if lane.x != -99999:
		put(cyrus, lane)
		var walk: Array = controller._height_path(lane, lane + Vector2i(4, 0), 0, cyrus)
		ok(walk == [lane, lane + Vector2i(1, 0), lane + Vector2i(2, 0), lane + Vector2i(3, 0), lane + Vector2i(4, 0)],
			"four tiles along, he walks the four tiles straight", "%s" % [walk])
	put(cyrus, Vector2i(16, 7))
	ok(burglar_steps.call().has(up(Vector2i(17, 7))), "beside the pillar under the walkway: up it, onto the gallery",
		"%s" % [burglar_steps.call()])
	put(cyrus, Vector2i(3, 2))
	ok(burglar_steps.call().all(func(tile): return combat.floor_of(tile) == 0), "not from under the gallery floor - nowhere to climb out")
	cyrus.level = 1
	put(cyrus, Vector2i(16, 7))
	ok(not burglar_steps.call().has(up(Vector2i(17, 7))), "nor up the pillar without it")
	put(cyrus, Vector2i(9, 14))
	log_line("")

	log_line("======== the screen ========")
	controller.show_floor(0)
	ok(controller.shown_floor() == 0 or combat.camera == null, "the ground on the screen")
	controller.cycle_floor(1)
	ok(controller.shown_floor() == 1 or combat.camera == null, "a floor up: the gallery")
	var bar = combat.game_ui._floor_bar
	ok(bar != null and bar.button_for(0) != null and bar.button_for(1) != null, "a button for each floor")
	game.queue_free()
	await settle()
