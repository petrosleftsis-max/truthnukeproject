extends Node
## The illusions the designer chose on 2026-11-06, each played out in a fight, and Cyrus putting on a
## disguise he carries while hidden. On a map they are in `outsidespells`.

const LOG_NAME := "illusions"
const WATCHER := "res://data/encounters/encounter_03_watcher.tres"
const PARTY := ["enfina", "cyrus", "prometheus", "alithia"]

var LOG_PATH := HarnessLog.path_for(LOG_NAME)
var _log: FileAccess = null
var _fail := 0
var game = null
var combat: Combat = null
var controller = null
var ui = null
var prompt = null


func log_line(text: String):
	if _log:
		_log.store_line(text)
		_log.flush()


func ok(condition: bool, label: String, detail: String = ""):
	if condition:
		log_line("  PASS  %s %s" % [label, detail])
	else:
		_fail += 1
		log_line("  FAIL  %s %s" % [label, detail])


func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(300.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await settle()
	var booted = get_tree().current_scene
	if booted != null:
		booted.queue_free()
		await settle()
	await where_they_are()
	await open_fight()
	await phantom_noise()
	await open_fight()
	await phantom_wall()
	await open_fight()
	await a_wall_by_two_clicks()
	await open_fight()
	await seen_through_one_by_one()
	await open_fight()
	await seeming()
	await open_fight()
	await false_ground()
	await open_fight()
	await false_ground_seen_through()
	await open_fight()
	await phantom_killer()
	await open_fight()
	await fallen_friend()
	await open_fight()
	await phantom_company()
	await open_fight()
	await mislead()
	await open_fight()
	await weird()
	await open_fight()
	await a_disguise()
	await close_fight()
	log_line("FAILURES: %d" % _fail)
	_log.close()
	get_tree().quit(0 if _fail == 0 else 1)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


func open_fight():
	await close_fight()
	Campaign.reset()
	Campaign.set_party(PARTY, 64)
	Campaign.choose_subclass("alithia", "illusory_shepherd")
	Campaign.current_map = "res://maps/crossroads_explore.tscn"
	Campaign.return_to_position = true
	Campaign.current_encounter = load(WATCHER)
	game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(6)
	combat = game.get_node("VisualCombat")
	controller = game.get_node("Controller")
	ui = game.get_node("CanvasLayer/UI")
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(2)
	prompt = combat.reaction_prompt
	for comb in combat.combatants:
		comb.reaction_used = true
		# Nobody falls by accident: a turn handed to a fallen one goes round and round.
		if comb.has("stats"):
			comb.hp = 900
			comb.max_hp = 900
		if comb.side == 1 and comb.has("stats"):
			comb.stats["mindfulness"] = 1
	var alithia := who("alithia")
	for gate in alithia.spell_slots.size():
		alithia.spell_slots[gate] = 5
	# Everybody near enough for what is tried here.
	var foe: Dictionary = foes()[0]
	combat.teleport_to(foe, tile_away(alithia.position, 4, foe))
	var enfina := who("enfina")
	combat.teleport_to(enfina, tile_away(alithia.position, 2, enfina))
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


var _answering := false


## Nobody at the keyboard: anything asked while a turn plays out is answered no.
func _keep_answering():
	while _answering and is_inside_tree():
		if prompt != null and is_instance_valid(prompt) and prompt._waiting:
			prompt._answer_with(false)
		await get_tree().process_frame


func real_turn(before: Dictionary, comb: Dictionary):
	_answering = true
	_keep_answering()
	for each in combat.combatants:
		each.reaction_used = true
	var b: int = combat.combatants.find(before)
	var c: int = combat.combatants.find(comb)
	combat.turn_queue = [b, c, b]
	combat.turn = 0
	combat.current_combatant = b
	await combat.advance_turn()
	await settle(4)
	_answering = false


func tile_away(from: Vector2i, gap: int, walker: Dictionary) -> Vector2i:
	for tile in controller.get_reachable_tiles(from, walker.movement_class, 40, walker):
		if combat.get_position_distance(tile, from) == gap and combat.can_land_on(walker, tile) and combat.get_combatant_at(tile).is_empty():
			return tile
	return from


func where_they_are():
	log_line("======== where they are ========")
	var path: SubclassDefinition = load("res://data/subclasses/illusory_shepherd.tres")
	var wanted := {"phantom_noise": 2, "phantom_wall": 2, "seeming": 2, "false_ground": 3, "phantom_killer": 3, "fallen_friend": 4, "phantom_company": 4, "mislead": 5, "weird": 10}
	for key in wanted:
		var skill: SkillDefinition = SkillDatabase.skills.get(key)
		ok(skill != null and path.skills.has(key), "%s is on the Illusory Shepherd's path" % key)
		ok(skill != null and skill.spell_slot_level == wanted[key], "through its gate", "%d" % skill.spell_slot_level)
		ok(skill != null and skill.required_level <= 1, "and no level of its own", "%d" % skill.required_level)
	ok(OutsideMoves.iris_gate_for(SkillDatabase.skills.phantom_noise) == 1, "Phantom Noise pays Iris first, on a map")
	ok(OutsideMoves.iris_gate_for(SkillDatabase.skills.mislead) == 2, "Mislead pays Mnemosyne first, on a map")
	ok(Stats.OUTSIDE_GATES[2].matches < 6, "Mnemosyne is below Nemesis", "%d" % Stats.OUTSIDE_GATES[2].matches)
	ok(not SkillDatabase.skills.mislead.tethered, "Mislead holds no tether: its double stays until hit or dispelled")
	ok(SkillDatabase.skills.phantom_wall.tether_strength == 100 and SkillDatabase.skills.weird.tether_strength == 400, "the tethers on the table")
	log_line("")


func phantom_noise():
	log_line("======== Phantom Noise ========")
	var alithia := who("alithia")
	var foe: Dictionary = foes()[0]
	var spell: SkillDefinition = SkillDatabase.skills.phantom_noise
	await their_turn(alithia)
	# Somewhere behind them, a few tiles off.
	var noise: Vector2i = tile_away(foe.position, 4, foe)
	var before: int = combat.get_position_distance(foe.position, noise)
	var paid: int = alithia.spell_slots[2]
	await combat.use_skill("phantom_noise", alithia, noise, false)
	await settle()
	ok(alithia.spell_slots[2] == paid - 1, "a casting through Hermes, in a fight")
	ok(combat._noise_they_heard(foe) == noise, "they heard it", "%s" % combat._noise_they_heard(foe))
	await their_turn(foe)
	controller.movement = 3
	await combat._go_and_look(foe)
	await settle()
	ok(combat.get_position_distance(foe.position, noise) < before, "and go to look", "%d tiles off from %d" % [combat.get_position_distance(foe.position, noise), before])
	ok(combat._noise_they_heard(foe) == Combat.NO_AREA, "once")
	ok(foe.get("ran_this_turn", false) and combat.movement_budget_of(foe) == controller.movement, "and the rest of their movement is what they carry on with", "%d" % controller.movement)
	# Whoever beats her Mindfulness is not taken in.
	await open_fight()
	alithia = who("alithia")
	foe = foes()[0]
	foe.stats["mindfulness"] = 900
	await their_turn(alithia)
	await combat.use_skill("phantom_noise", alithia, foe.position, false)
	await settle()
	ok(combat._noise_they_heard(foe) == Combat.NO_AREA, "they beat her Mindfulness, and hear nothing")
	ok(spell.aoe_radius == 4, "an area of four tiles")
	log_line("")


func phantom_wall():
	log_line("======== Phantom Wall ========")
	var alithia := who("alithia")
	var foe: Dictionary = foes()[0]
	await their_turn(alithia)
	# Well clear of anybody, straight along a row.
	var at: Vector2i = alithia.position
	for gap in range(2, 7):
		var there: Vector2i = alithia.position + Vector2i.RIGHT * gap
		var clear := true
		for step in range(-2, 3):
			var tile: Vector2i = there + Vector2i(0, step)
			if not combat.get_combatant_at(tile).is_empty() or not controller.is_on_map(tile) or controller.is_tile_blocking(tile, 0):
				clear = false
		if clear:
			at = there
			break
	ok(at != alithia.position, "there is room to try it", "%s" % at)
	await combat.use_skill("phantom_wall", alithia, at, false)
	await settle()
	var pieces: Array = combat.combatants.filter(func(comb): return comb.get("alive", false) and comb.has("object") and comb.object.name == "Phantom Wall")
	ok(pieces.size() == 5, "five tiles of it", "%d" % pieces.size())
	ok(pieces.all(func(piece): return piece.position.x == at.x), "across the line from her")
	ok(pieces.all(func(piece): return piece.get("tether_of", -1) == alithia.tether.id), "held on her tether", "%d" % alithia.tether.max)
	ok(alithia.tether.max == 100, "a tether of 100")
	# To the enemy's mind a wall; to hers nothing.
	ok(not controller.blocks_sight(at), "it stops nothing that happens")
	combat.ai_believes = true
	combat._believer_side = 1
	ok(controller.blocks_sight(at), "and sight, to the side it fools")
	combat.ai_believes = false
	ok(combat.get_targets_in_tiles([at], alithia, false, false).is_empty(), "nothing hits it")
	ok(combat.refusal_for(alithia, SkillDatabase.skills.holy_lance, at) != combat.WALL_HOLDS, "and it is no wall to her own aim")
	# Nobody walks through.
	ok(controller._occupied_spaces.has(at), "and it stands in the way of a walk")
	combat.snap_tether(alithia, "test")
	await settle()
	ok(pieces.all(func(piece): return not piece.alive), "the tether gone, so is the wall")
	log_line("")


## Where it starts, then where it ends (the designer, 2026-11-07).
func a_wall_by_two_clicks():
	log_line("======== Phantom Wall, by two clicks ========")
	var skill: SkillDefinition = SkillDatabase.skills.phantom_wall
	var effect: EffectDefinition = Combat.wall_effect_of(skill)
	var o := Vector2i(10, 10)
	ok(Combat.places_a_wall(skill) and CController.aimed_twice(skill), "aimed twice")
	ok(Combat.wall_line(effect, o, o + Vector2i(3, 0)) == [o, o + Vector2i(1, 0), o + Vector2i(2, 0), o + Vector2i(3, 0)], "along a row")
	ok(Combat.wall_line(effect, o, o + Vector2i(0, -2)) == [o, o + Vector2i(0, -1), o + Vector2i(0, -2)], "or a column")
	ok(Combat.wall_line(effect, o, o) == [o], "one tile, if that is all it is asked for")
	ok(Combat.wall_line(effect, o, o + Vector2i(40, 0)).size() == Combat.wall_length(effect), "no longer than it ever was", "%d" % Combat.wall_length(effect))
	ok(Combat.wall_end_for(effect, o, o + Vector2i(3, 1)) == o + Vector2i(3, 0), "pointing just off the row, along the row")
	ok(Combat.wall_end_for(effect, o, o + Vector2i(2, 3)) == o + Vector2i(3, 3), "or nearer the diagonal, along the diagonal")
	var slant: Array = Combat.wall_line(effect, o, o + Vector2i(2, 2))
	ok(slant == [o, o + Vector2i(1, 0), o + Vector2i(1, 1), o + Vector2i(2, 1), o + Vector2i(2, 2)], "a diagonal fills its corners, so nobody slips through", "%s" % [slant])
	var alithia := who("alithia")
	await their_turn(alithia)
	# Clear ground in a row, in reach.
	var start: Vector2i = alithia.position
	for gap in range(2, 7):
		for way in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var there: Vector2i = alithia.position + way * gap
			var along: Vector2i = Vector2i(way.y, way.x)
			var clear := true
			for step in range(0, 4):
				var tile: Vector2i = there + along * step
				if not combat.get_combatant_at(tile).is_empty() or not controller.is_on_map(tile) or controller.is_tile_blocking(tile, 0):
					clear = false
			if clear and start == alithia.position:
				start = there
				_wall_along = along
	ok(start != alithia.position, "there is room to try it", "%s" % start)
	var gates: Array = alithia.spell_slots.duplicate()
	controller.set_selected_skill("phantom_wall")
	controller.begin_target_selection()
	await settle()
	ok(controller.aim_click(start), "the first click says where it starts")
	await settle()
	ok(controller.waiting_for_destination() and controller.aiming_a_walls_end(), "and it waits for the second")
	ok(controller._range_preview_positions.all(func(tile): return controller.is_on_map(tile)), "nothing off the map is offered")
	var region: Rect2i = controller._astargrid.region
	var far_left := Vector2i(region.position.x - 40, start.y)
	ok(controller.wall_end_at(far_left) == Vector2i(maxi(start.x - 4, region.position.x), start.y), "pointing past the edge, it stops at the edge", "%s" % controller.wall_end_at(far_left))
	ok(alithia.spell_slots == gates and not combat.holds_tether(alithia), "with nothing spent yet")
	ok(controller.refusal_at(start + _wall_along * 2 + Vector2i(_wall_along.y, _wall_along.x), {}) != "", "off the straight lines is no end for it")
	ok(controller.wall_end_at(start + _wall_along * 3 + Vector2i(_wall_along.y, _wall_along.x)) == start + _wall_along * 3, "and a click there is pulled onto the nearest")
	ok(controller.aim_click(start + _wall_along * 3), "the second says where it ends")
	# It plays out at its own pace.
	await get_tree().create_timer(5.0).timeout
	var pieces: Array = combat.combatants.filter(func(comb): return comb.get("alive", false) and comb.has("object") and comb.object.name == "Phantom Wall")
	ok(pieces.size() == 4, "four tiles, as chosen", "%d" % pieces.size())
	ok(pieces.any(func(piece): return piece.position == start) and pieces.any(func(piece): return piece.position == start + _wall_along * 3), "from one to the other")
	ok(combat.holds_tether(alithia) and pieces.all(func(piece): return piece.get("tether_of", -1) == alithia.tether.id), "on her tether")
	var straight: float = Vector2(_wall_along).angle() - PI / 2.0
	ok(pieces.all(func(piece): return absf(angle_difference(piece.sprite._drawn().rotation, straight)) < 0.01 and is_equal_approx(piece.sprite._drawn().scale.y, 1.0)), "each drawn along the wall, tile to tile")
	# On a diagonal, the wall is drawn on the diagonal, and what fills its corners only blocks.
	combat.snap_tether(alithia, "test")
	await their_turn(alithia)
	var probe: Dictionary = combat.summon_probe(skill, 0)
	var reach: Array = combat.get_range_tiles(skill, alithia.position, alithia.movement_class, alithia)
	var slope := Vector2i.ZERO
	var from_tile := Vector2i.ZERO
	for tile in reach:
		for way in [Vector2i(1, 1), Vector2i(1, -1)]:
			if slope == Vector2i.ZERO and Combat.wall_line(effect, tile, tile + way * 2).all(func(there): return combat.can_land_on(probe, there)):
				slope = way
				from_tile = tile
	ok(slope != Vector2i.ZERO, "there is room for a diagonal too", "%s" % from_tile)
	await combat.use_skill("phantom_wall", alithia, from_tile, false, false, from_tile + slope * 2)
	await settle()
	var slanted: Array = combat.combatants.filter(func(comb): return comb.get("alive", false) and comb.has("object") and comb.object.name == "Phantom Wall")
	var on_it: Array = slanted.filter(func(piece): return absi(piece.position.x - from_tile.x) == absi(piece.position.y - from_tile.y))
	var corners: Array = slanted.filter(func(piece): return not on_it.has(piece))
	ok(on_it.size() == 3 and corners.size() == 2, "three on the diagonal, two filling its corners", "%d, %d" % [on_it.size(), corners.size()])
	var diagonal: float = Vector2(slope).angle() - PI / 2.0
	ok(on_it.all(func(piece): return piece.sprite._drawn().visible and absf(angle_difference(piece.sprite._drawn().rotation, diagonal)) < 0.01), "those on it lie along it")
	ok(on_it.all(func(piece): return is_equal_approx(piece.sprite._drawn().scale.y * piece.sprite._drawn().texture.get_height(), Grid.TILE_SIZE * Vector2(slope).length())), "reaching corner to corner, so they join")
	ok(corners.all(func(piece): return not piece.sprite._drawn().visible), "those filling the corners draw nothing")
	ok(corners.all(func(piece): return not combat.can_land_on(probe, piece.position)), "and still block")
	# Called off between the two.
	combat.snap_tether(alithia, "test")
	await their_turn(alithia)
	controller.set_selected_skill("phantom_wall")
	controller.begin_target_selection()
	await settle()
	controller.aim_click(start)
	controller.cancel_skill_selection()
	ok(not controller.waiting_for_destination(), "called off between the two, nothing is left waiting")
	log_line("")


var _wall_along := Vector2i.ZERO


## Walks the one acting to `tile`, through the same calls a click makes, and waits for them to get there.
func walk_to(tile: Vector2i):
	controller.find_path(tile)
	controller.move_player()
	var frames := 0
	await get_tree().process_frame
	while not controller.is_idle() and frames < 3000:
		await get_tree().process_frame
		frames += 1
	await settle()


## Where a wall can run up and down through the returned tile, with room on all sides for those watching it.
func room_to_watch_a_wall() -> Vector2i:
	var skill: SkillDefinition = SkillDatabase.skills.phantom_wall
	var probe: Dictionary = combat.summon_probe(skill, 0)
	var region: Rect2i = controller._astargrid.region
	for y in range(region.position.y + 3, region.end.y - 3):
		for x in range(region.position.x + 3, region.end.x - 3):
			var there := Vector2i(x, y)
			var needed := []
			for dx in range(-3, 4):
				needed.append(there + Vector2i(dx, 0))
			for dy in range(-3, 4):
				needed.append(there + Vector2i(0, dy))
			needed.append(there + Vector2i(-1, -1))
			needed.append(there + Vector2i(1, 1))
			if needed.all(func(tile): return controller.is_on_map(tile) and combat.can_land_on(probe, tile)):
				return there
	return Combat.NO_AREA


## Their mind, a moment: what `check` says as `viewer` sees it.
func in_the_mind_of(viewer: Dictionary, check: Callable):
	var believed: bool = combat.ai_believes
	combat.ai_believes = true
	combat._believer_side = viewer.side
	combat._believer = viewer
	var said = check.call()
	combat.ai_believes = believed
	combat._believer = {}
	return said


## ("if a player character passes by them, whoever enemy "saw that" by having it happen in their line of sight, or if
## they are cunning or higher smarts, have those enemies "see through" the illusion and ignore it"; "other illusions
## like the floor illusion should also work like that"; "lets lower the smarts requirment to trained".)
func seen_through_one_by_one():
	log_line("======== Seen through, one by one ========")
	var INSTINCT: int = CombatantDefinition.AiSmarts.INSTINCT
	var alithia := who("alithia")
	var enfina := who("enfina")
	var they := foes()
	ok(they.size() >= 3, "three to watch", "%d" % they.size())
	var saw: Dictionary = they[0]
	var missed: Dictionary = they[1]
	var trained: Dictionary = they[2]
	var c := room_to_watch_a_wall()
	ok(c != Combat.NO_AREA, "there is room", "%s" % c)
	combat.teleport_to(alithia, c + Vector2i(3, 0))
	# The rest, out of the way of the watching.
	for other in they.slice(3):
		other.alive = false
	saw["ai_smarts"] = INSTINCT
	missed["ai_smarts"] = INSTINCT
	trained["ai_smarts"] = CombatantDefinition.AiSmarts.TRAINED
	combat.teleport_to(saw, c + Vector2i(-3, 0))
	combat.teleport_to(missed, c + Vector2i(0, -3))
	combat.teleport_to(trained, c + Vector2i(0, 3))
	await their_turn(alithia)
	await combat.use_skill("phantom_wall", alithia, c + Vector2i(0, -1), false, false, c + Vector2i(0, 1))
	await settle()
	var wall_at: Dictionary = combat.get_combatant_at(c)
	ok(wall_at.has("object") and wall_at.get("illusion", false), "up it goes")
	combat.teleport_to(enfina, c + Vector2i(-1, 0))
	await their_turn(enfina)
	# Her own side walks through it, and stops on the far side of it.
	var reach: Dictionary = controller.get_reachable_tiles(enfina.position, enfina.movement_class, 2, enfina)
	ok(reach.has(c + Vector2i(1, 0)), "her side can walk through it", "%s" % [reach.keys()])
	ok(not reach.has(c) and not reach.has(c + Vector2i(0, 1)), "but not stop on it")
	ok(controller.get_grid_path(enfina.position, c + Vector2i(1, 0)).size() == 3, "straight through")
	controller.find_path(c)
	ok(controller.tile_map.local_to_map(controller._path[controller._path.size() - 1]) != c, "pointing at it, the walk ends short of it")
	# Movement for only the wall tile: they stay where they are.
	var had: int = controller.get_movement()
	controller.set_movement(1)
	await walk_to(c + Vector2i(1, 0))
	ok(enfina.position == c + Vector2i(-1, 0), "with only the movement to get into it, they do not start")
	controller.set_movement(had)
	# Nobody has any reason to doubt it yet.
	ok(not combat.sees_through(saw, wall_at) and in_the_mind_of(saw, func(): return combat.believes_illusion(wall_at)), "they believe it")
	ok(combat.illusions_to_pass(saw).is_empty(), "and it stops them")
	ok(in_the_mind_of(saw, func(): return controller.blocks_sight(c)), "and their eyes")
	await walk_to(c + Vector2i(1, 0))
	ok(enfina.position == c + Vector2i(1, 0), "through", "%s" % enfina.position)
	ok(combat.sees_through(saw, wall_at), "whoever saw that sees through it")
	ok(not combat.sees_through(missed, wall_at), "the rest of the wall hid it from whoever had only instinct to go on")
	ok(combat.sees_through(trained, wall_at), "and anybody trained works it out, in sight or not")
	ok(saw.sprite != null, "said over their heads")
	# It is nothing to them now.
	ok(not in_the_mind_of(saw, func(): return combat.believes_illusion(wall_at)), "in their mind it is not there")
	ok(not in_the_mind_of(saw, func(): return controller.blocks_sight(c)), "they see past it")
	ok(in_the_mind_of(missed, func(): return controller.blocks_sight(c)), "the one who missed it does not")
	var passable: Dictionary = combat.illusions_to_pass(saw)
	ok(passable.has(c + Vector2i(0, -1)) and passable.has(c) and passable.has(c + Vector2i(0, 1)), "all of the wall, not only where it was crossed")
	ok(combat.illusions_to_pass(missed).is_empty(), "and it still stops the one who missed it")
	# And they walk through it.
	combat.teleport_to(saw, c + Vector2i(-1, 0))
	var their_reach: Dictionary = controller.get_reachable_tiles(saw.position, saw.movement_class, 2, saw)
	ok(their_reach.has(c + Vector2i(2, 0)) == false and not their_reach.has(c), "not stopping on it either")
	await their_turn(saw)
	ok(controller.get_grid_path(saw.position, c + Vector2i(2, 0)).size() == 4, "their way goes through it", "%s" % [controller.get_grid_path(saw.position, c + Vector2i(2, 0))])
	combat.teleport_to(saw, c + Vector2i(-3, 0))
	combat.teleport_to(missed, c + Vector2i(-1, 0))
	await their_turn(missed)
	ok(controller.get_grid_path(missed.position, c + Vector2i(2, 0)).size() > 4, "the other's goes round", "%s" % [controller.get_grid_path(missed.position, c + Vector2i(2, 0))])
	combat.teleport_to(missed, c + Vector2i(0, -3))
	# Reading the board as each of them would.
	ok(combat.threat_map().has("threat"), "the danger view reads it, each as they see it")
	ok(combat._believer.is_empty(), "and leaves nobody's mind behind")
	# One of their own seen walking through it gives it away as well, and the AI's own walk does it.
	combat.teleport_to(saw, c + Vector2i(-1, 0))
	combat.teleport_to(missed, c + Vector2i(-3, 0))
	ok(not combat.sees_through(missed, wall_at), "one still fooled, watching")
	await their_turn(saw)
	controller.set_movement(2)
	await controller.ai_move(c + Vector2i(1, 1))
	await settle()
	ok(saw.position == c + Vector2i(1, 1), "the AI's own walk goes through it", "%s" % saw.position)
	ok(combat.sees_through(missed, wall_at), "and one of their own seen doing that gives it away too")
	# And a whole turn of theirs, thought through as they see it, ends on nothing of it.
	await their_turn(enfina)
	await real_turn(enfina, saw)
	ok(combat.combatants_at(c).size() == 1 and combat.combatants_at(c + Vector2i(0, 1)).size() == 1 and combat.combatants_at(c + Vector2i(0, -1)).size() == 1, "a whole turn of theirs ends on nothing of it", "%s" % saw.position)
	combat.teleport_to(saw, c + Vector2i(1, 1))
	# Whatever they saw, they saw: a walk back stops at the far side of it.
	await their_turn(enfina)
	controller.set_movement(6)
	ok(controller._turn_start_position != c, "no walk back ends inside it")
	# Somebody stopped partway through is who is there, not the wall.
	var was: Vector2i = enfina.position
	enfina.position = c
	controller.refresh_occupancy()
	ok(combat.get_combatant_at(c).get("id", -1) == enfina.id, "somebody caught inside it is who is there")
	enfina.position = was
	controller.refresh_occupancy()
	# The next one fools them again, and somebody unseen gives nothing away.
	combat.snap_tether(alithia, "test")
	await their_turn(alithia)
	await combat.use_skill("phantom_wall", alithia, c + Vector2i(0, -1), false, false, c + Vector2i(0, 1))
	await settle()
	var second: Dictionary = combat.get_combatant_at(c)
	ok(second.has("object") and not combat.sees_through(saw, second) and not combat.sees_through(trained, second), "a new wall fools them again")
	combat.teleport_to(enfina, c + Vector2i(-1, 0))
	await their_turn(enfina)
	combat.set_hidden(enfina, true)
	enfina["invisible"] = true
	await walk_to(c + Vector2i(1, 0))
	ok(enfina.position == c + Vector2i(1, 0), "unseen, through", "%s" % enfina.position)
	ok(not combat.sees_through(saw, second) and not combat.sees_through(trained, second), "and nobody is any the wiser")
	combat.set_hidden(enfina, false)
	# Nor anybody stunned or asleep.
	combat.snap_tether(alithia, "test")
	log_line("  -- the floor")
	await their_turn(alithia)
	saw.erase("sees_through")
	trained.erase("sees_through")
	missed.erase("sees_through")
	var prometheus := who("prometheus")
	combat.teleport_to(prometheus, c + Vector2i(0, 1))
	combat.teleport_to(enfina, c + Vector2i(-3, -1))
	combat.teleport_to(missed, c + Vector2i(0, -3))
	# Well away from the floor, out of its radius of three.
	await combat.use_skill("false_ground", alithia, c, false)
	await settle()
	ok(combat.zones.size() == 1, "laid", "%d" % combat.zones.size())
	if combat.zones.is_empty():
		log_line("")
		return
	var zone: Dictionary = combat.zones[0]
	# Whoever stands on it as it is laid gives nothing away by standing there.
	combat.sync_zones()
	ok(not combat.sees_through(trained, zone) and not combat.sees_through(saw, zone), "standing on it as it lands gives nothing away")
	# Everybody off it but whoever is about to walk on, each where they are wanted.
	var outside: Array = []
	var region: Rect2i = controller._astargrid.region
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var tile := Vector2i(x, y)
			if not tile in zone.tiles and controller.is_on_map(tile) and combat.can_land_on(saw, tile):
				outside.append(tile)
	ok(outside.size() > 4, "room round it", "%d" % outside.size())
	var edge: Vector2i = Combat.NO_AREA
	var step_on: Vector2i = Combat.NO_AREA
	for tile in outside:
		for way in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
			if edge == Combat.NO_AREA and (tile + way) in zone.tiles and combat.get_combatant_at(tile + way).is_empty():
				edge = tile
				step_on = tile + way
	ok(edge != Combat.NO_AREA, "a way on to it", "%s" % edge)
	combat.teleport_to(enfina, edge)
	# One who sees that step and one who, with only instinct, does not: anywhere out of sight of it, as the map has it.
	var unseen_from: Vector2i = Combat.NO_AREA
	var seen_from: Vector2i = Combat.NO_AREA
	for tile in outside:
		if tile == edge:
			continue
		var clear: bool = combat.has_line_of_sight(tile, step_on, 0)
		if clear and seen_from == Combat.NO_AREA and combat.get_position_distance(tile, step_on) <= 8:
			seen_from = tile
		elif not clear and unseen_from == Combat.NO_AREA:
			unseen_from = tile
	ok(seen_from != Combat.NO_AREA, "somewhere to see it from", "%s" % seen_from)
	combat.teleport_to(saw, seen_from)
	if unseen_from != Combat.NO_AREA:
		combat.teleport_to(missed, unseen_from)
	else:
		missed.alive = false
	var other_tile: Vector2i = outside.filter(func(tile): return tile != edge and tile != seen_from and tile != unseen_from)[0]
	combat.teleport_to(trained, other_tile)
	combat.sync_zones()
	ok(combat.false_ground_for(saw).has(step_on), "they will not step on it")
	await their_turn(enfina)
	await walk_to(step_on)
	ok(enfina.position == step_on, "on to it, unharmed", "%s" % enfina.position)
	ok(combat.sees_through(saw, zone), "whoever saw that sees through it")
	ok(combat.sees_through(trained, zone), "and anybody trained works it out")
	if missed.alive:
		ok(not combat.sees_through(missed, zone), "the one out of sight, with only instinct, does not")
		ok(combat.false_ground_for(missed).has(step_on), "and it still keeps them off")
		ok(combat.on_false_ground(missed, step_on), "and still counts as deadly to them")
	ok(not combat.false_ground_for(saw).has(step_on), "it no longer keeps them off")
	ok(not combat.on_false_ground(saw, step_on), "and it is no ground to fear")
	ok(combat.zones.has(zone), "and it is still there for anybody it still fools")
	# One who knows, stepping on it: it is not gone for the rest.
	var free_on_it: Array = zone.tiles.filter(func(tile): return combat.get_combatant_at(tile).is_empty() and combat.can_land_on(saw, tile))
	ok(not free_on_it.is_empty(), "room on it")
	if not free_on_it.is_empty():
		combat.teleport_to(saw, free_on_it[0])
		combat.sync_zones()
		ok(combat.zones.has(zone), "one who knows, standing on it, does not end it")
	log_line("")


func seeming():
	log_line("======== Seeming ========")
	var alithia := who("alithia")
	var enfina := who("enfina")
	var foe: Dictionary = foes()[0]
	await their_turn(alithia)
	await combat.use_skill("seeming", alithia, enfina.position, false)
	await settle()
	ok(combat.is_invisible(enfina) and enfina.get("until_acting", false), "she goes unnoticed")
	ok(enfina.has("looks_like"), "taken for one of them", enfina.get("looks_like", ""))
	ok(combat.hidden_from(foe, enfina), "hidden from them")
	# A step does not give it away.
	await their_turn(enfina)
	combat.step_gives_away(enfina)
	ok(combat.is_invisible(enfina), "a step gives nothing away")
	# Doing anything does: a blow at nobody, on an ally, anything.
	var heal := "run"
	await combat.use_skill(heal, enfina, enfina.position, false)
	await settle()
	ok(not combat.is_invisible(enfina) and not enfina.has("until_acting") and not enfina.has("looks_like"), "doing anything at all does")
	log_line("")


func false_ground():
	log_line("======== False Ground ========")
	var alithia := who("alithia")
	var foe: Dictionary = foes()[0]
	await their_turn(alithia)
	var middle: Vector2i = tile_away(foe.position, 5, foe)
	await combat.use_skill("false_ground", alithia, middle, false)
	await settle()
	ok(combat.zones.size() == 1 and combat.zones[0].get("false_ground", false), "it lies on the ground")
	var zone: Dictionary = combat.zones[0]
	ok(not combat.zone_tiles().is_empty(), "drawn for her side")
	var refused: Dictionary = combat.false_ground_for(foe)
	ok(refused.has(middle), "the enemy will not step on it")
	ok(combat.false_ground_for(alithia).is_empty(), "her side walks where they like")
	await their_turn(foe)
	var reach: Dictionary = controller.get_reachable_tiles(foe.position, foe.movement_class, 40, foe)
	ok(not zone.tiles.any(func(tile): return reach.has(tile)), "and it is out of their reach, however far they walk")
	# It does nothing to anybody.
	var hp: int = foe.hp
	combat.sync_zones()
	ok(foe.hp == hp and not combat.zones.is_empty(), "and does nothing")
	await their_turn(alithia)
	combat.snap_tether(alithia, "test")
	await settle()
	ok(combat.zones.is_empty(), "gone with the tether")
	log_line("")


func false_ground_seen_through():
	log_line("======== False Ground, seen through ========")
	var alithia := who("alithia")
	var foe: Dictionary = foes()[0]
	await their_turn(alithia)
	# Somebody standing in it as it lands walks off, and gives nothing away.
	await combat.use_skill("false_ground", alithia, foe.position, false)
	await settle()
	ok(combat.zones.size() == 1, "laid over them", "%d" % combat.zones.size())
	if combat.zones.is_empty():
		return
	var zone: Dictionary = combat.zones[0]
	ok(zone.caught.has(foe.id), "they were on it already, and it holds")
	ok(not combat.false_ground_for(foe).has(foe.position), "and may walk off it")
	# Off it, and they will not step back.
	var off: Vector2i = foe.position
	for tile in controller.get_reachable_tiles(foe.position, foe.movement_class, 40, foe):
		if not tile in zone.tiles and combat.can_land_on(foe, tile) and combat.get_combatant_at(tile).is_empty():
			off = tile
			break
	combat.teleport_to(foe, off)
	combat.sync_zones()
	ok(not zone.caught.has(foe.id) and not combat.zones.is_empty(), "off it, the ground still holds them off")
	ok(combat.false_ground_for(foe).has(zone.tiles[0]), "and they will not step back")
	# Thrown back on it, unharmed: it is seen for what it is, and the tether has nothing to hold.
	var on: Vector2i = zone.tiles[0]
	for tile in zone.tiles:
		if combat.can_land_on(foe, tile):
			on = tile
			break
	combat.teleport_to(foe, on)
	combat.sync_zones()
	await settle()
	ok(combat.zones.is_empty(), "thrown onto it, they see it for what it is")
	ok(not alithia.has("tether"), "and the tether lets go")
	log_line("")


func phantom_killer():
	log_line("======== Phantom Killer ========")
	var alithia := who("alithia")
	var foe: Dictionary = foes()[0]
	alithia.stats["mindfulness"] = 20
	foe.stats["mindfulness"] = 10
	await their_turn(alithia)
	await combat.use_skill("phantom_killer", alithia, foe.position, false)
	await settle()
	var wound: Dictionary = {}
	for entry in foe.status_effects:
		if entry.get("condition") != null and entry.condition.doubt_each_turn > 0:
			wound = entry
	ok(not wound.is_empty(), "they believe in it")
	ok(wound.condition.dot_type == Damage.Type.PSYCHIC, "a psychic wound")
	ok(wound.get("tether_of", -1) == alithia.tether.id, "held on her tether")
	# Each turn it wounds, until the doubt has grown past her Mindfulness: 10 + 3 x turns >= 20.
	var turns := 0
	var hurt := 0
	while foe.status_effects.any(func(entry): return entry.get("condition") != null and entry.condition.doubt_each_turn > 0) and turns < 8:
		var hp: int = foe.hp
		combat.start_of_turn_effects(foe)
		turns += 1
		if foe.hp < hp:
			hurt += 1
	ok(turns == 4, "they stop believing on the fourth turn", "%d" % turns)
	ok(hurt == 3, "and it wounded them on the three before", "%d" % hurt)
	combat._release_idle_tethers()
	ok(not alithia.has("tether"), "and her tether has nothing to hold")
	log_line("")


func fallen_friend():
	log_line("======== Fallen Friend ========")
	var alithia := who("alithia")
	var enfina := who("enfina")
	var foe: Dictionary = foes()[0]
	await their_turn(alithia)
	await combat.use_skill("fallen_friend", alithia, enfina.position, false)
	await settle()
	ok(enfina.get("looks_dead", false) and combat.is_invisible(enfina), "she looks dead")
	ok(combat.hidden_from(foe, enfina), "and the enemy ignores her")
	ok(enfina.sprite.lying, "lying where she stands")
	ok(alithia.tether.max == 200, "for as long as the tether holds")
	# A step gives it away.
	combat.step_gives_away(enfina)
	await settle()
	ok(not combat.is_invisible(enfina) and not enfina.get("looks_dead", false), "a step gives it away")
	ok(not enfina.sprite.lying, "and she is up")
	ok(not combat.conditions_of(enfina).any(func(condition): return condition.looks_dead), "the look gone")
	# The tether snapping does too, and so does a move.
	await their_turn(alithia)
	alithia.skill_used_this_turn = false
	combat.snap_tether(alithia, "test")
	await combat.use_skill("fallen_friend", alithia, enfina.position, false)
	await settle()
	ok(enfina.get("looks_dead", false), "again")
	combat.snap_tether(alithia, "test")
	await settle()
	ok(not enfina.get("looks_dead", false) and not combat.is_invisible(enfina), "the tether gone, so is the look")
	await their_turn(alithia)
	await combat.use_skill("fallen_friend", alithia, enfina.position, false)
	await settle()
	await their_turn(enfina)
	await combat.use_skill("run", enfina, enfina.position, false)
	await settle()
	ok(not enfina.get("looks_dead", false), "a move gives it away")
	log_line("")


func phantom_company():
	log_line("======== Phantom Company ========")
	var alithia := who("alithia")
	var foe: Dictionary = foes()[0]
	await their_turn(alithia)
	var at: Vector2i = tile_away(foe.position, 2, foe)
	var nerve_before: int = foe.get("shaken", 0)
	await combat.use_skill("phantom_company", alithia, at, false)
	await settle()
	var soldiers: Array = combat.combatants.filter(func(comb): return comb.get("alive", false) and comb.get("combatant_key", "") == "phantom_soldier")
	ok(soldiers.size() == 3, "three of them", "%d" % soldiers.size())
	ok(soldiers.all(func(one): return one.get("illusion", false) and one.max_hp == 1 and not one.has("summoner")), "images, nobody's to command")
	ok(combat.summons_of(alithia).is_empty() and not combat.secondary_grants(alithia).has("command"), "and nothing for her to command")
	ok(soldiers.all(func(one): return one.get("tether_of", -1) == alithia.tether.id), "held on her tether")
	ok(foe.get("shaken", 0) > nerve_before or not combat.sees_tile(foe, at), "whoever sees them loses some nerve", "%d" % foe.get("shaken", 0))
	ok(not combat.side_standing(0) == false, "her side stands, images apart")
	# A blow shatters one.
	combat.ai_believes = true
	combat._believer_side = 1
	ok(combat.ai_target_value(foe, soldiers[0], SkillDatabase.skills.greatsword_attack) > 0.0, "the enemy takes them for targets")
	combat.ai_believes = false
	var first: Dictionary = soldiers[0]
	combat.do_damage(foe, first, SkillDatabase.skills.greatsword_attack.damage_effect(), SkillDatabase.skills.greatsword_attack)
	await settle()
	ok(not first.alive, "one blow shatters one")
	ok(alithia.has("tether"), "the rest still held")
	combat.snap_tether(alithia, "test")
	await settle()
	ok(soldiers.all(func(one): return not one.alive), "the tether gone, so are they")
	log_line("")


func mislead():
	log_line("======== Mislead ========")
	var alithia := who("alithia")
	var foe: Dictionary = foes()[0]
	await their_turn(alithia)
	var spot: Vector2i = tile_away(alithia.position, 3, alithia)
	# No asking who: on to where it goes.
	controller.set_selected_skill("mislead")
	controller.begin_target_selection()
	ok(controller.waiting_for_destination(), "aimed at where the double goes, straight away")
	controller.cancel_skill_selection()
	await combat.use_skill("mislead", alithia, alithia.position, false, false, spot)
	await settle()
	var double := combat.double_of(alithia)
	ok(not double.is_empty() and double.position == spot, "a double stands where she pointed")
	ok(combat.is_invisible(alithia), "and she fades from sight")
	ok(combat.hidden_from(foe, alithia), "hidden from them")
	ok(not alithia.has("tether"), "no tether")
	# The secondary sends it about.
	ok(combat.secondary_grants(alithia).has("move_double"), "she can send it about with a secondary action")
	var range_tiles: Array = combat.get_range_tiles(SkillDatabase.skills.move_double, alithia.position, 0, alithia)
	ok(not range_tiles.is_empty() and range_tiles.all(func(tile): return combat.get_position_distance(tile, spot) <= 6), "up to six tiles from where it is", "%d" % range_tiles.size())
	var next: Vector2i = range_tiles[0]
	alithia.secondary_used_this_turn = false
	await combat.use_skill("move_double", alithia, next, false, true)
	await settle()
	ok(double.position == next, "it goes", "%s" % double.position)
	ok(alithia.secondary_used_this_turn, "for the secondary action")
	# An action on an enemy ends the invisibility, and the double stays.
	var bolt: SkillDefinition = SkillDatabase.skills.holy_lance
	combat.apply_effect(alithia, foe, bolt.damage_effect(), bolt, false)
	await settle()
	ok(not combat.is_invisible(alithia), "acting on an enemy ends the invisibility")
	ok(double.alive, "and the double stays")
	# Hit, it is gone; so is the secondary.
	combat.do_damage(foe, double, SkillDatabase.skills.greatsword_attack.damage_effect(), SkillDatabase.skills.greatsword_attack)
	await settle()
	ok(not double.alive, "until it is hit")
	ok(not combat.secondary_grants(alithia).has("move_double"), "and with it gone, nothing to send about")
	# Or dispelled.
	await their_turn(alithia)
	await combat.use_skill("mislead", alithia, alithia.position, false, false, spot)
	await settle()
	var second := combat.double_of(alithia)
	ok(not second.is_empty(), "another")
	combat.dispel_magic(who("prometheus"), second, SkillDatabase.skills.dispel_magic)
	await settle()
	# Dispel Magic reaches what came through a gate no deeper than its own: cast through its own here.
	ok(not second.alive or second.get("spell_gate", 0) > combat.spell_gate_of(SkillDatabase.skills.dispel_magic), "and Dispel Magic through as deep a gate ends it")
	log_line("")


func weird():
	log_line("======== Weird ========")
	var alithia := who("alithia")
	var near: Array = foes()
	await their_turn(alithia)
	var foe: Dictionary = near[0]
	await combat.use_skill("weird", alithia, foe.position, false)
	await settle()
	ok(alithia.tether.max == 400, "a tether of 400")
	ok(not combat._terror_of(foe).is_empty(), "they run from her")
	ok(combat.conditions_of(foe).any(func(condition): return condition.display_name == "Dread"), "and dread walks with them")
	var hp: int = foe.hp
	combat.start_of_turn_effects(foe)
	ok(foe.hp < hp, "a psychic wound as their turn starts", "%d -> %d" % [hp, foe.hp])
	combat.snap_tether(alithia, "test")
	ok(combat._terror_of(foe).is_empty() and not combat.conditions_of(foe).any(func(condition): return condition.display_name == "Dread"), "the tether gone, so is all of it")
	log_line("")


func a_disguise():
	log_line("======== Cyrus puts on a disguise ========")
	var cyrus := who("cyrus")
	var foe: Dictionary = foes()[0]
	var key: String = cyrus.combatant_key
	await their_turn(cyrus)
	# Nothing to put on, and not hidden.
	ok(combat.disguise_refusal(cyrus) != "", "not without one, and not in the open", combat.disguise_refusal(cyrus))
	ok(not combat.main_skills_of(cyrus).has("put_on_disguise") and not combat.secondary_grants(cyrus).has("put_on_disguise"), "so it is not offered")
	# One that fits nobody here.
	Campaign.give_item(key, "priest_robes")
	combat.set_hidden(cyrus, true)
	ok(combat.fitting_disguise(cyrus) == "" or foes().any(func(one): return one.combatant_key == "priest"), "robes of nobody here do not fit")
	# One that fits, by making one of them a priest.
	foe["combatant_key"] = "priest"
	combat.set_hidden(cyrus, false)
	ok(combat.disguise_refusal(cyrus) == "Only while hidden", "fitting, but only while hidden", combat.disguise_refusal(cyrus))
	ok(not combat.main_skills_of(cyrus).has("put_on_disguise"), "not offered out in the open")
	combat.set_hidden(cyrus, true)
	ok(combat.disguise_refusal(cyrus) == "", "hidden, he can", combat.disguise_refusal(cyrus))
	ok(combat.main_skills_of(cyrus).has("put_on_disguise"), "as his main action")
	ok(combat.secondary_skills_of(cyrus).has("put_on_disguise"), "or his secondary")
	ok(not combat.main_skills_of(who("enfina")).has("put_on_disguise"), "not for somebody who does not sneak")
	await combat.use_skill("put_on_disguise", cyrus, cyrus.position, false, true)
	await settle()
	ok(cyrus.get("disguised_as", "") == "priest", "he has it on")
	ok(cyrus.secondary_used_this_turn and not cyrus.skill_used_this_turn, "for the secondary action")
	ok(combat.is_invisible(cyrus), "walks in plain sight")
	combat.reveal_anyone_now_seen()
	ok(combat.is_hidden(cyrus), "and being seen does not give him away")
	ok(combat.hidden_from(foe, cyrus), "they take him for one of their own")
	ok(combat.disguise_refusal(cyrus) != "", "and he has it on already")
	# A nose is not fooled.
	var hound: Dictionary = foes()[1] if foes().size() > 1 else foe
	hound["sees_through_disguises"] = true
	ok(not combat.hidden_from(hound, cyrus), "a nose is not fooled")
	hound.erase("sees_through_disguises")
	# Acting against them ends it.
	var blow: SkillDefinition = SkillDatabase.skills.gun
	combat.apply_effect(cyrus, foe, blow.damage_effect(), blow, false)
	await settle()
	ok(not combat.is_hidden(cyrus) and not cyrus.has("disguised_as"), "doing something to them ends it")
	ok(Campaign.count_of(key, "priest_robes") == 1, "and he still has the robes")
	log_line("")
