extends "res://StealthHarness.gd"
## From a stealth map into the fight: springing an ambush (F), guards fighting
## with whatever is still in their pockets, and the more on edge the map, the
## sooner and the more of them come.


func suite() -> String:
	return "ambush"


func run_sections():
	await springing_an_ambush()
	await robbed_before_the_fight()
	await caught_off_guard_in_the_fight()
	await the_barracks_turn_out()
	await within_a_turn()


## Beside a guard who has no idea: F starts the fight, and he - and anybody
## else who had not noticed - is caught off guard. Whoever was already growing
## sure is not.
func springing_an_ambush():
	var m = await open_map()
	var post: Vector2i = m.post
	var mark = add_guard(m, "Mark", post, 0.0)
	mark.pockets.assign(["cure_potion", "pebble"])
	var edgy_tile = find_tile(m, func(t): return gap(t, post) >= 2.0 and gap(t, post) <= 3.0 and t.x > post.x)
	var edgy = add_guard(m, "Edgy", edgy_tile, 0.0)
	var watch = await watch_it(m, behind(m, post))
	var bar: StealthBar = watch._bar
	log_line("======== an ambush ========")
	ok(watch.ambush_target() == mark, "behind a guard with no idea, there is somebody to spring on")
	var shown = watch.prompt()
	ok(not shown.is_empty() and shown[1].has(["F", "Ambush", true]), "the prompt says F", "%s" % [shown[1] if not shown.is_empty() else "none"])
	await settle()
	ok(bar._ambush.visible, "and the bar offers it")
	watch.suspicion[edgy] = 0.4
	edgy.mood = Guard.Mood.SUSPICIOUS
	press(bar, KEY_F)
	ok(watch.spotted_by == mark, "F: the fight starts, on him")
	var fight: EncounterDefinition = Campaign.current_encounter
	var by_name := {}
	for spawn in fight.spawns if fight != null else []:
		if spawn.side == 1:
			by_name[spawn.display_name] = spawn
	ok(by_name.has("Mark") and by_name.Mark.surprised, "he is caught off guard")
	ok(by_name.has("Edgy") and not by_name.Edgy.surprised, "the one already wondering about something is not")
	ok(by_name.has("Mark") and Array(by_name.Mark.starting_items) == ["cure_potion"],
		"and he fights with what is in his pockets - the potion, not the pebble", "%s" % [by_name.Mark.starting_items if by_name.has("Mark") else "none"])
	ok(not watch.never_noticed(), "a fight is no ghost's way out")
	await close_map(m)

	log_line("======== nobody to spring on ========")
	m = await open_map()
	var sharp = add_guard(m, "Sharp", m.post, 180.0)
	# At his back, looking the other way.
	watch = await watch_it(m, m.post + Vector2i.RIGHT * 4)
	ok(watch.ambush_target() == null, "four tiles off, too far to spring on him")
	m.party.teleport(at(m, m.post + Vector2i.RIGHT * 2))
	await settle()
	ok(watch.ambush_target() == sharp, "two tiles off, near enough")
	sharp.facing_degrees = 0.0
	await wait(0.2)
	ok(watch.suspicion[sharp] > 0.0 and watch.ambush_target() == null, "but once he has seen him it is no ambush")
	await close_map(m)


## Robbed first, a guard fights with nothing in his pockets.
func robbed_before_the_fight():
	var m = await open_map()
	var post: Vector2i = m.post
	var mark = add_guard(m, "Mark", post, 0.0)
	mark.pockets.assign(["cure_potion"])
	var watch = await watch_it(m, behind(m, post))
	log_line("======== robbed first ========")
	ok(watch.pick_pocket(mark), "(his potion lifted)")
	var spawn: SpawnDefinition = null
	for each in watch.build_fight().spawns:
		if each.display_name == "Mark":
			spawn = each
	ok(spawn != null and spawn.starting_items.is_empty(), "he comes to the fight with nothing to drink",
		"%s" % [spawn.starting_items if spawn != null else "not there"])
	await close_map(m)


## In the fight itself: caught off guard, a turn is lost; a potion in the pocket
## is drunk when he is badly hurt, and a bomb is one more thing to throw.
func caught_off_guard_in_the_fight():
	log_line("======== in the fight ========")
	Campaign.reset()
	var encounter: EncounterDefinition = load("res://encounters/encounter_02_sappers.tres").duplicate(true)
	var marked: SpawnDefinition = null
	for spawn in encounter.spawns:
		if spawn.side == 1 and marked == null:
			marked = spawn
	marked.display_name = "Marked"
	marked.surprised = true
	marked.starting_items.assign(["cure_potion", "tiny_bomb", "pebble"])
	Campaign.current_encounter = encounter
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(6)
	var combat: Combat = game.get_node("VisualCombat")
	var enemy: Dictionary = {}
	for comb in combat.combatants:
		if comb.name == "Marked":
			enemy = comb
	ok(not enemy.is_empty(), "(the surprised one is on the field)")
	if enemy.is_empty():
		game.queue_free()
		await settle()
		return
	ok(combat.has_restriction(enemy, "skips_turn") and combat._why_turn_lost(enemy) == "caught off guard",
		"caught off guard, he will lose his turn", combat._why_turn_lost(enemy))
	# Caught off guard is a 1-turn condition, and every duration runs to the end
	# of the turn after its number (Combat.turns_stored): two turns lost.
	combat.start_of_turn_effects(enemy)
	ok(combat.has_restriction(enemy, "skips_turn"), "the turn it is taken from")
	combat.end_of_turn_effects(enemy)
	combat.start_of_turn_effects(enemy)
	ok(combat.has_restriction(enemy, "skips_turn"), "and the one after")
	combat.end_of_turn_effects(enemy)
	ok(not combat.has_restriction(enemy, "skips_turn"), "and only those - gone as the second ends")
	ok(combat.items_of(enemy) == ["cure_potion", "tiny_bomb"], "his pocket: the potion and the bomb - nothing only for sneaking",
		"%s" % [combat.items_of(enemy)])
	ok(combat._ai_main_keys(enemy).has("tiny_bomb"), "the bomb is one more thing he could throw")
	ok(not await combat._ai_drink_from_pocket(enemy), "unhurt, he keeps the potion")
	enemy.hp = int(enemy.max_hp * 0.3)
	var hurt: int = enemy.hp
	ok(await combat._ai_drink_from_pocket(enemy), "badly hurt, he drinks it")
	ok(enemy.hp > hurt and not combat.items_of(enemy).has("cure_potion"), "mended, and it is gone from his pocket",
		"%d -> %d, %s" % [hurt, enemy.hp, combat.items_of(enemy)])
	game.queue_free()
	await settle()
	log_line("")


## The more on edge the map when he is caught, the sooner the far guards come
## - and on a Wary or Alarmed map, the barracks turn out.
func the_barracks_turn_out():
	var m = await open_map()
	var post: Vector2i = m.post
	var far_tile = find_tile(m, func(t): return gap(t, post) >= 9.0 and gap(t, post) <= 12.0)
	add_guard(m, "Near", post, 0.0)
	add_guard(m, "Far", far_tile, 0.0)
	m.setup.joins_within_tiles = 3.0
	m.setup.tiles_per_late_round = 3.0
	m.setup.reinforcements.assign(["barbarian", "ranger", "barbarian"])
	var watch = await watch_it(m, post + Vector2i.RIGHT)
	log_line("======== sooner, the more on edge ========")
	ok(far_tile != NOWHERE, "(one guard far off)", "%s" % far_tile)
	var calm = arrivals(watch.build_fight()).get("Far", 0)
	watch.alert = 1.0
	var alarmed = arrivals(watch.build_fight()).get("Far", 0)
	ok(calm > 2 and alarmed < calm, "far off, he comes on round %d of a calm map and %d of an alarmed one" % [calm, alarmed])

	log_line("======== the barracks ========")
	watch.alert = 0.0
	ok(fresh_faces(watch.build_fight()).is_empty(), "calm: nobody sent for")
	watch.alert = 0.5
	var wary = fresh_faces(watch.build_fight())
	ok(wary.size() == 2 and wary.all(func(r): return r == 3), "Wary: half of them, on round 3", "%s" % [wary])
	watch.alert = 0.9
	var all_out = fresh_faces(watch.build_fight())
	ok(all_out.size() == 3 and all_out.all(func(r): return r == 2), "Alarmed: all of them, on round 2", "%s" % [all_out])
	await close_map(m)


## The rounds the enemies nobody saw on the map arrive on - the reinforcements.
func fresh_faces(fight: EncounterDefinition) -> Array:
	var rounds := []
	for spawn in fight.spawns:
		if spawn.side == 1 and not spawn.has_meta("guard"):
			rounds.append(spawn.arrives_on_round)
	return rounds




## Whoever could hit somebody in the party on his first turn is in the fight
## from its start, however far off the map says late arrivals begin.
func within_a_turn():
	var m = await open_map()
	var post: Vector2i = m.post
	m.setup.joins_within_tiles = 0.5
	m.setup.tiles_per_late_round = 3.0
	var beside = add_guard(m, "Beside", post + Vector2i.RIGHT, 0.0)
	var shooter = add_guard(m, "Shooter", post + Vector2i.RIGHT * 2, 0.0, "ranger")
	var faraway = add_guard(m, "Faraway", post + Vector2i.RIGHT * 3, 0.0)
	var watch = await watch_it(m, post)
	log_line("======== within a turn ========")
	var manhattan = func(t: Vector2i) -> int: return absi(t.x - post.x) + absi(t.y - post.y)
	var swing: int = watch.reach_of(faraway)
	var walk: int = CombatantDatabase.combatants["barbarian"].movement
	ok(watch.reach_of(shooter) > 6, "a ranger shoots further than a barbarian swings", "%d against %d" % [watch.reach_of(shooter), swing])
	# In his range with a clear line; and a barbarian too far to walk up and swing.
	var in_his_sights = find_tile(m, func(t): return manhattan.call(t) >= 6 and manhattan.call(t) <= 9 and m.sight.clear(t, post))
	var out_of_it = find_tile(m, func(t): return manhattan.call(t) > walk + swing + 2 and gap(t, post) < 20.0)
	ok(in_his_sights != NOWHERE and out_of_it != NOWHERE, "(a tile in the ranger's sights, and one beyond a turn of a barbarian)",
		"%s, %s" % [in_his_sights, out_of_it])
	shooter.global_position = at(m, in_his_sights)
	faraway.global_position = at(m, out_of_it)
	ok(watch.threatens(beside, [post]) and watch.threatens(shooter, [post]) and not watch.threatens(faraway, [post]),
		"beside him, or with him in his sights, they could hit him; the far one could not")
	var rounds = arrivals(watch.build_fight())
	ok(rounds.get("Beside") == 1 and rounds.get("Shooter") == 1, "so both are there from the start", "%s" % [rounds])
	ok(rounds.get("Faraway", 0) > 1, "and the far one comes late, as the map says", "%s" % [rounds])
	await close_map(m)
