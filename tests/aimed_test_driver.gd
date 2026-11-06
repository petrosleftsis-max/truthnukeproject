extends "res://StealthHarness.gd"
## Damaging moves on a map are aimed (MapAim, OutsideMoves "Aimed on a map"; the designer, 2026-11-07):
## picked, they only take aim; a hit starts the fight with everybody hit in it, and they take it before
## anybody's turn; a wall takes no fight; nobody there and it is spent. A trap that bursts starts one too.


func suite() -> String:
	return "aimed"


func time_limit() -> float:
	return 240.0


func run_sections():
	await taking_aim()
	await an_area_catches_them_all()
	await the_wall_and_the_empty_ground()
	await the_blow_lands_first()
	await nobody_left_to_fight()
	await a_bursting_trap_lands_first()


func taking_aim():
	log_line("======== taking aim ========")
	var m = await open_map()
	Campaign.set_party(["alithia"], 14)
	await settle()
	Campaign.current_encounter = null
	var guard := add_guard(m, "Guard", m.post + Vector2i.RIGHT * 3, 180.0)
	var watch = await watch_it(m, m.post)
	var scene = m.scene
	var flame: SkillDefinition = SkillDatabase.skills.votive_flame
	ok(OutsideMoves.use(scene, "alithia", "votive_flame"), "picked from the panel")
	ok(scene.map_aim != null and is_instance_valid(scene.map_aim), "it takes aim")
	ok(watch.spotted_by == null and Campaign.current_encounter == null, "and nothing has happened yet")
	ok(scene.map_aim.wants_pad_pointer(), "a pad's pointer stays up for it")
	var tile: Vector2i = watch.tile_of(guard.global_position)
	ok(OutsideMoves.in_reach(scene, "alithia", flame, tile), "the guard is in its reach")
	ok(OutsideMoves.aim_refusal(scene, "alithia", flame, tile + Vector2i.RIGHT * 40) == "Out of reach", "far off is refused")
	ok(OutsideMoves.aim_refusal(scene, "alithia", flame, tile + Vector2i.LEFT) == "Nobody there to hit", "a blow at one somebody needs that somebody", OutsideMoves.aim_refusal(scene, "alithia", flame, tile + Vector2i.LEFT))
	var struck: Dictionary = OutsideMoves.struck_at(scene, "alithia", flame, tile)
	ok(struck.guards == [guard], "it would catch him")
	scene.map_aim.cancel()
	await settle()
	ok(not is_instance_valid(scene.map_aim) or scene.map_aim.is_queued_for_deletion(), "put away: nothing spent")
	# He is watching now: any guard can be struck, not only one who has noticed nothing.
	guard.mood = Guard.Mood.SUSPICIOUS
	ok(OutsideMoves.fire_at(scene, "alithia", "votive_flame", tile) and watch.spotted_by == guard, "let go at somebody who has an idea, it still starts the fight")
	await close_map(m)
	log_line("")


func an_area_catches_them_all():
	log_line("======== an area catches them all ========")
	var m = await open_map()
	Campaign.set_party(["alithia"], 64)
	await settle()
	Campaign.current_encounter = null
	var spot: Vector2i = side_by_side(m)
	var one := add_guard(m, "One", spot, 180.0)
	var two := add_guard(m, "Two", spot + Vector2i.RIGHT, 180.0)
	var far := add_guard(m, "Far", m.post + Vector2i.RIGHT * 30, 180.0)
	var watch = await watch_it(m, m.post)
	watch.setup.joins_within_tiles = 2.0
	var scene = m.scene
	var splash: SkillDefinition = SkillDatabase.skills.holy_splash
	var aim: Vector2i = watch.tile_of(one.global_position)
	var struck: Dictionary = OutsideMoves.struck_at(scene, "alithia", splash, aim)
	ok(struck.guards.has(one) and struck.guards.has(two), "Holy Splash at one catches the one beside him", "radius %d, aim %s, tiles %s, two at %s, guards %s" % [splash.aoe_radius, aim, struck.tiles, watch.tile_of(two.global_position), struck.guards.size()])
	ok(not struck.guards.has(far), "not one far off")
	ok(OutsideMoves.fire_at(scene, "alithia", "holy_splash", aim), "let go")
	var fight: EncounterDefinition = Campaign.current_encounter
	var opener: Dictionary = fight.get_meta("opener", {})
	ok(opener.get("aim_offset", Vector2i.ONE) == Vector2i.ZERO, "the fight knows where it was aimed", "%s" % [opener])
	var there := fight.spawns.filter(func(spawn): return spawn.has_meta("guard") and spawn.arrives_on_round <= 1)
	ok(there.size() >= 2, "everybody it caught is in the fight from the start", "%d" % there.size())
	await close_map(m)
	log_line("")


func the_wall_and_the_empty_ground():
	log_line("======== a wall, and nobody ========")
	var m = await open_map()
	Campaign.set_party(["alithia"], 14)
	await settle()
	Campaign.current_encounter = null
	var guard := add_guard(m, "Guard", m.post + Vector2i.RIGHT * 7, 180.0)
	var watch = await watch_it(m, m.post)
	var scene = m.scene
	var from: Vector2i = OutsideMoves.member_tile(scene, "alithia")
	var spot := find_tile(m, func(tile): return gap(tile, from) >= 1.0 and gap(tile, from) <= 2.0 and standable(m, tile))
	var wall := BreakableWall.new()
	wall.name = "TestWall"
	m.map.add_child(wall)
	wall.global_position = at(m, spot)
	scene._collect_walls(m.map)
	var lance: SkillDefinition = SkillDatabase.skills.holy_lance
	var hermes: int = Campaign.gates_left_outside("alithia")[2]
	ok(OutsideMoves.fire_at(scene, "alithia", "holy_lance", spot) and wall.broken, "a spell at a wall brings it down")
	ok(Campaign.current_encounter == null and watch.spotted_by == null, "and no fight comes of that")
	ok(Campaign.gates_left_outside("alithia")[2] == hermes - 1, "the casting is spent here, there being no fight to pay it in")
	ok(not watch._ripples.is_empty(), "it is heard, and whoever comes may yet notice the party")
	# An area at nobody: spent, and heard where it lands.
	var splash: SkillDefinition = SkillDatabase.skills.holy_splash
	Campaign.set_party(["alithia"], 64)
	await settle()
	Campaign.current_encounter = null
	var empty: Vector2i = OutsideMoves.member_tile(scene, "alithia") + Vector2i.LEFT * 3
	var left_before: Array = Campaign.gates_left_outside("alithia").duplicate()
	var ripples: int = watch._ripples.size()
	if OutsideMoves.aim_refusal(scene, "alithia", splash, empty) == "":
		ok(OutsideMoves.fire_at(scene, "alithia", "holy_splash", empty), "an area can be let go at nobody")
		ok(Campaign.gates_left_outside("alithia") != left_before, "  it is spent")
		ok(Campaign.current_encounter == null, "  and no fight comes of it")
		ok(watch._ripples.size() >= ripples, "  heard where it lands, if it makes a noise")
	else:
		ok(false, "an area can be let go at nobody", OutsideMoves.aim_refusal(scene, "alithia", splash, empty))
	await close_map(m)
	log_line("")


## Plays the fight `fight` opens, up to its first turn.
func open_the_fight(fight: EncounterDefinition, party: Array, level: int) -> Array:
	Campaign.set_party(party, level)
	Campaign.current_encounter = fight
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(6)
	var combat: Combat = game.get_node("VisualCombat")
	await until(func(): return combat._opening_done, 10.0)
	await wait(3.0)
	return [game, combat]


## Two open tiles side by side, a few tiles from where the party stands.
func side_by_side(m: Dictionary) -> Vector2i:
	return find_tile(m, func(tile): return gap(tile, m.post) >= 3.0 and gap(tile, m.post) <= 6.0 and standable(m, tile) \
		and standable(m, tile + Vector2i.RIGHT) and m.sight.clear(m.post, tile))


func the_blow_lands_first():
	log_line("======== the blow lands before anybody's turn ========")
	var m = await open_map()
	Campaign.set_party(["alithia"], 64)
	await settle()
	Campaign.current_encounter = null
	var spot: Vector2i = side_by_side(m)
	var one := add_guard(m, "One", spot, 180.0)
	var two := add_guard(m, "Two", spot + Vector2i.RIGHT, 180.0)
	var watch = await watch_it(m, m.post)
	watch.leave_for_battle = false
	var scene = m.scene
	var aim: Vector2i = watch.tile_of(one.global_position)
	ok(OutsideMoves.fire_at(scene, "alithia", "holy_splash", aim), "Holy Splash let go at them")
	var fight: EncounterDefinition = Campaign.current_encounter
	await close_map(m)
	var opened: Array = await open_the_fight(fight, ["alithia"], 64)
	var combat: Combat = opened[1]
	var hurt := combat.combatants.filter(func(comb): return comb.get("side", 0) == 1 and comb.has("stats") and comb.get("hp", 0) < comb.get("max_hp", 0))
	var log_text: String = combat.game_ui.get_node("Actions/Information/Text").get_parsed_text()
	ok(hurt.size() >= 2, "everybody it caught is hurt", "%d of %d, aim %s, at %s, %s" % [hurt.size(), combat.combatants.size(), fight.get_meta("opener", {}).get("aim"),
		combat.combatants.map(func(comb): return [comb.get("name", ""), comb.get("position"), comb.get("hp", 0), comb.get("max_hp", 0)]), log_text.right(400)])
	ok(combat.round_number <= 1, "and no round has gone by", "round %d" % combat.round_number)
	opened[0].queue_free()
	await settle()
	log_line("")


## A ward that is sure, with everybody who would fight out of it: no fight with nobody in it.
func nobody_left_to_fight():
	log_line("======== nobody left to fight ========")
	var m = await open_map()
	Campaign.set_party(["alithia"], 14)
	await settle()
	Campaign.current_encounter = null
	var spot: Vector2i = side_by_side(m)
	var ward := add_guard(m, "Ward", spot, 180.0)
	ward.kind = Guard.Kind.WARD
	var watchman := add_guard(m, "Watchman", spot + Vector2i.RIGHT, 180.0)
	var watch = await watch_it(m, m.post)
	watchman.knock_out()
	var alert: int = watch.alert_floor
	var level: float = watch.alert
	watch._caught_by(ward)
	ok(watch.spotted_by == null and Campaign.current_encounter == null, "a ward sure of them, and nobody left to fight: no fight")
	ok(watch.alert > level or watch.alert_floor > alert, "the alert goes up", "%s" % watch.alert)
	var after: float = watch.alert
	watch._caught_by(ward)
	ok(watch.alert == after and watch.spotted_by == null, "once")
	await close_map(m)
	# With somebody who would, as ever.
	m = await open_map()
	Campaign.set_party(["alithia"], 14)
	await settle()
	Campaign.current_encounter = null
	spot = side_by_side(m)
	ward = add_guard(m, "Ward", spot, 180.0)
	ward.kind = Guard.Kind.WARD
	watchman = add_guard(m, "Watchman", spot + Vector2i.RIGHT, 180.0)
	watch = await watch_it(m, m.post)
	watch._caught_by(ward)
	ok(watch.spotted_by == ward and Campaign.current_encounter != null, "with somebody who would fight, the fight is on")
	await close_map(m)
	log_line("")


func a_bursting_trap_lands_first():
	log_line("======== a trap that bursts ========")
	var m = await open_map()
	Campaign.set_party(["prometheus"], 14)
	Campaign.learned_spells = {"prometheus": ["great_snare"]}
	await settle()
	Campaign.current_encounter = null
	var spot: Vector2i = side_by_side(m)
	var near := add_guard(m, "Near", spot, 180.0)
	var by := add_guard(m, "By", spot + Vector2i.RIGHT, 180.0)
	var far := add_guard(m, "Far", m.post + Vector2i.RIGHT * 30, 180.0)
	var watch = await watch_it(m, m.post)
	watch.leave_for_battle = false
	var scene = m.scene
	var pandora: int = Campaign.gates_left_outside("prometheus")[3]
	var snare: SkillDefinition = SkillDatabase.skills.great_snare
	var tile: Vector2i = OutsideMoves.reach_tiles(scene, "prometheus", snare)[0]
	ok(OutsideMoves.fire_at(scene, "prometheus", "great_snare", tile), "laid")
	ok(Campaign.gates_left_outside("prometheus")[3] == pandora - 1, "paid as it is laid")
	ok(Campaign.current_encounter == null, "nothing happens until somebody steps on it")
	var trap = null
	for child in scene.get_children():
		if child is OutsideMoves.Trap:
			trap = child
	trap.global_position = near.global_position
	await settle(4)
	var fight: EncounterDefinition = Campaign.current_encounter
	ok(fight != null and fight.get_meta("opener", {}).get("trap", false), "the fight starts")
	await close_map(m)
	if fight == null:
		return
	var gates_in_the_fight := -1
	var opened: Array = await open_the_fight(fight, ["prometheus"], 14)
	var combat: Combat = opened[1]
	var hurt := combat.combatants.filter(func(comb): return comb.get("side", 0) == 1 and comb.has("stats") and comb.get("hp", 0) < comb.get("max_hp", 0))
	ok(hurt.size() >= 2, "everybody within three tiles is hurt", "%d" % hurt.size())
	var held := combat.combatants.filter(func(comb): return comb.get("side", 0) == 1 and combat.has_restriction(comb, "prevents_movement"))
	ok(held.size() == 1, "and the one who stepped on it is held fast", "%d" % held.size())
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == "prometheus":
			gates_in_the_fight = comb.spell_slots[3]
	ok(gates_in_the_fight == pandora - 1, "and it costs nothing more in the fight", "%d" % gates_in_the_fight)
	opened[0].queue_free()
	await settle()
	log_line("")
