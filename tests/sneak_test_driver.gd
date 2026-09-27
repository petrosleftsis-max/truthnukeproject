extends Node
## Stealth maps: guards who patrol and look along a cone, a party that has to
## stay out of it, and the fight that starts where everybody stands when a
## guard is sure.

var LOG_PATH := HarnessLog.path_for("sneak")
const MAP := "res://scenes/explore_crossroads.tscn"
const TERRAIN := "res://scenes/crossroads_terrain.tscn"

var _log: FileAccess = null
var _fail = 0


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
	get_tree().create_timer(150.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


func wait(seconds: float):
	await get_tree().create_timer(seconds).timeout


func run_test():
	await sight_agrees_with_combat()
	await on_the_map()
	await in_disguise()
	await dashing()
	await reactions()
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


## The same walls hide the same people in both modes.
func sight_agrees_with_combat():
	log_line("======== a guard sees by combat's rule ========")
	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_02_sappers.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(4)
	var combat: Combat = game.get_node("VisualCombat")
	var controller = game.get_node("Controller")
	var tile_map: TileMap = game.get_node("Terrain/TileMap")
	var sight := StealthSight.new(tile_map)
	# Bodies are cover in a fight and not out here; take them off the board so
	# what is compared is the walls alone.
	controller._occupied_spaces.clear()
	var region: Rect2i = sight.region()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var disagree := []
	var clear_lines := 0
	for i in 3000:
		var a := Vector2i(rng.randi_range(region.position.x, region.end.x - 1), rng.randi_range(region.position.y, region.end.y - 1))
		var b := Vector2i(rng.randi_range(region.position.x, region.end.x - 1), rng.randi_range(region.position.y, region.end.y - 1))
		var theirs = combat.has_line_of_sight(a, b, 0)
		if theirs:
			clear_lines += 1
		if sight.clear(a, b) != theirs and disagree.size() < 5:
			disagree.append([a, b])
	ok(disagree.is_empty(), "3000 lines on the lab map, and the two agree on every one",
		"%d of them clear %s" % [clear_lines, disagree])
	ok(clear_lines > 100 and clear_lines < 2900, "with enough of both kinds to mean something", "%d clear" % clear_lines)
	game.queue_free()
	await settle()
	log_line("")


func on_the_map():
	Campaign.reset()
	Campaign.current_map = MAP
	var scene: ExplorationScene = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(scene)
	await settle(4)
	var map = scene.get_node("Map")
	var tile_map: TileMap = scene._tile_map
	var sight := StealthSight.new(tile_map)
	var party = scene.party
	var leader_key: String = Campaign.party_members()[0].key
	var start_tile = tile_map.local_to_map(party.position_of_leader())

	var post = find_post(scene, tile_map, sight, start_tile)
	ok(post.x > -99999, "open ground for a guard on the crossroads", "%s" % post)

	log_line("======== a map with a StealthSetup is watched ========")
	var setup := StealthSetup.new()
	setup.battle_terrain = load(TERRAIN)
	setup.fight_name = "Caught at the crossroads"
	map.add_child(setup)
	var guard := Guard.new()
	guard.name = "Watcher"
	guard.combatant_key = "barbarian"
	guard.level = 2
	guard.facing_degrees = 0.0
	guard.looks_around = false
	map.add_child(guard)
	guard.global_position = tile_map.to_global(tile_map.map_to_local(post))
	# Out of the way, and out of sight, before anybody starts looking.
	var hideout = post + Vector2i.LEFT * 2
	party.teleport(tile_map.to_global(tile_map.map_to_local(hideout)))
	scene.begin_stealth()
	var watch: StealthWatch = scene.stealth
	ok(watch != null and watch.guards.has(guard), "the watch knows its guard")
	watch.leave_for_battle = false
	await settle()
	ok(party.leader.hidden_alpha == StealthWatch.SNEAKING_ALPHA, "the party is drawn half-there, sneaking",
		"%.2f" % party.leader.hidden_alpha)
	# The wheel zooms here, where an ordinary map holds one framing.
	var camera = scene.camera
	ok(camera.allow_zoom and not camera.free_look, "the camera can be zoomed, and still follows the party")
	var zoom_before = camera.zoom.x
	var centred_on = camera.position
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = Vector2(50, 50)
	camera._unhandled_input(wheel)
	ok(camera.zoom.x < zoom_before, "the wheel pulls back to see more of the guards", "%.3f -> %.3f" % [zoom_before, camera.zoom.x])
	ok(camera.position == centred_on, "around the party, not towards the pointer")
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	camera._unhandled_input(wheel)
	ok(is_equal_approx(camera.zoom.x, zoom_before), "and back in again", "%.3f" % camera.zoom.x)

	log_line("======== the cone: ahead, not behind, not through walls ========")
	ok(watch.sees(guard, post + Vector2i.RIGHT * 3), "three tiles ahead is seen")
	ok(not watch.sees(guard, post + Vector2i.LEFT * 2), "two behind is not")
	ok(watch.sees(guard, post + Vector2i(3, 2)) == sight.clear(post, post + Vector2i(3, 2)),
		"off to one side but inside 160 degrees, it is down to the walls")
	var walled := Vector2i(-99999, -99999)
	for x in range(1, 25):
		for y in range(-6, 7):
			var tile = post + Vector2i(x, y)
			if walled.x == -99999 and sight.region().has_point(tile) and not sight.stops_sight(tile) \
					and not sight.clear(post, tile) and absf(rad_to_deg(Vector2.RIGHT.angle_to(Vector2(x, y)))) < 70.0:
				walled = tile
	if walled.x > -99999:
		ok(not watch.sees(guard, walled), "and somewhere inside the cone behind a wall is not seen", "%s" % walled)
	else:
		log_line("  (nothing inside the cone is behind a wall from here)")
	ok(watch.seen_tiles().has(post + Vector2i.RIGHT * 3) and not watch.seen_tiles().has(post + Vector2i.LEFT * 2),
		"what is drawn is what is seen")

	log_line("======== a meter, not an instant ========")
	party.teleport(tile_map.to_global(tile_map.map_to_local(post + Vector2i.RIGHT * 4)))
	await wait(0.25)
	var rising: float = watch.suspicion[guard]
	ok(rising > 0.0 and watch.spotted_by == null, "in view, the guard grows sure - not yet certain", "%.2f" % rising)
	var vignette: PressureVignette = watch._vignette
	ok(vignette.visible and vignette.tint() == StealthWatch.METER_DOUBT
		and absf(vignette.strength() - rising * StealthWatch.VIGNETTE_AT_FULL) < 0.08,
		"amber creeps in round the screen as the meter fills", "%.2f at a meter of %.2f" % [vignette.strength(), rising])
	var leaning = watch.camera_lean()
	ok(leaning > 0.0 and leaning <= StealthWatch.PRESSURE_ZOOM, "and the camera leans in, a little",
		"%.1f%%" % (leaning * 100.0))
	var tinted = vignette.strength()
	party.teleport(tile_map.to_global(tile_map.map_to_local(hideout)))
	await wait(0.4)
	ok(watch.suspicion[guard] < rising, "out of view again, the doubt drains away", "%.2f -> %.2f" % [rising, watch.suspicion[guard]])
	ok(vignette.strength() < tinted, "and the amber with it", "%.2f -> %.2f" % [tinted, vignette.strength()])
	ok(watch.camera_lean() < leaning * 0.2, "while the camera is already back - out of sight is out of sight",
		"%.1f%% -> %.1f%%" % [leaning * 100.0, watch.camera_lean() * 100.0])
	# A conversation holds everything.
	watch.suspicion[guard] = 0.0
	party.teleport(tile_map.to_global(tile_map.map_to_local(post + Vector2i.RIGHT * 2)))
	scene.begin_blocking_interaction()
	await wait(0.3)
	ok(guard.holding and watch.suspicion[guard] == 0.0, "mid-conversation, nobody is spotted and the guard stands still")
	scene.end_blocking_interaction()
	# Close up is quicker than far off.
	var close_fill = 1.0 / StealthWatch.SURE_WHEN_CLOSE
	var far_fill = 1.0 / StealthWatch.SURE_WHEN_FAR
	ok(close_fill > far_fill, "sure faster up close than far away",
		"%.1f s beside them, %.1f s at %d tiles" % [StealthWatch.SURE_WHEN_CLOSE, StealthWatch.SURE_WHEN_FAR, StealthWatch.FAR_TILES])

	log_line("======== caught: the fight is where everyone stands ========")
	var caught_on = post + Vector2i.RIGHT * 2
	party.teleport(tile_map.to_global(tile_map.map_to_local(caught_on)))
	for i in 60:
		if watch.spotted_by != null:
			break
		await wait(0.05)
	ok(watch.spotted_by == guard, "stay in view and the guard is sure")
	ok(party.frozen and guard.holding, "and everybody stops where they are")
	ok(watch._vignette.tint() == StealthWatch.METER_SURE and is_equal_approx(watch._vignette.strength(), StealthWatch.VIGNETTE_CAUGHT),
		"the edges of the screen go red before the fight", "%.2f" % watch._vignette.strength())
	var fight: EncounterDefinition = Campaign.current_encounter
	ok(fight != null and fight.terrain_scene != null and fight.terrain_scene.resource_path == TERRAIN,
		"a fight on the crossroads' own battle terrain", fight.terrain_scene.resource_path if fight and fight.terrain_scene else "none")
	ok(fight != null and fight.skip_deployment, "with nobody rearranged before it starts")
	var ours = fight.spawns.filter(func(s): return s.side == 0) if fight else []
	var theirs = fight.spawns.filter(func(s): return s.side == 1) if fight else []
	ok(ours.size() == 1 and ours[0].position == caught_on and fight.fighters == [leader_key],
		"%s alone, on the tile they were caught on" % leader_key, "%s" % [ours.map(func(s): return s.position)])
	ok(theirs.size() == 1 and theirs[0].position == post and theirs[0].combatant_key == "barbarian" and theirs[0].level == 2,
		"the guard on theirs, at their level", "%s" % [theirs.map(func(s): return [s.combatant_key, s.position, s.level])])
	ok(Campaign.has_map_to_return_to() and Campaign.return_position.distance_to(party.position_of_leader()) < 1.0,
		"and the map remembers where to put the party back")

	log_line("======== or the backup comes running ========")
	setup.backup = ["enfina"]
	var helped = watch.build_fight()
	var helped_ours = helped.spawns.filter(func(s): return s.side == 0)
	ok(helped.fighters == [leader_key, "enfina"] and helped_ours.size() == 2,
		"with backup set, Enfina fights too", "%s" % [helped.fighters])
	ok(helped_ours.size() == 2 and helped_ours[0].position == caught_on and helped_ours[1].position != caught_on
		and standable(scene, tile_map, helped_ours[1].position),
		"beside him, on ground of her own", "%s" % [helped_ours.map(func(s): return s.position)])
	setup.backup = []

	log_line("======== caught on a plank the fight does not have ========")
	# The crossroads lays planks over channels its battle terrain leaves as
	# water. Caught on one, he starts the fight on the nearest real floor.
	var plank = Vector2i(4, 6)
	ok(standable(scene, tile_map, plank) and watch._battle_blocking().has(plank),
		"(4, 6) is floor on the map and water in the fight")
	party.teleport(tile_map.to_global(tile_map.map_to_local(plank)))
	var off_plank = watch.build_fight().spawns.filter(func(s): return s.side == 0)
	ok(off_plank.size() == 1 and not watch._battle_blocking().has(off_plank[0].position)
		and Vector2(off_plank[0].position - plank).length() <= 2.0,
		"so he starts beside it, on floor the fight has", "%s" % [off_plank.map(func(s): return s.position)])
	party.teleport(tile_map.to_global(tile_map.map_to_local(caught_on)))
	log_line("")

	log_line("======== the fight comes up as built ========")
	# The one with backup: two player tiles, which would otherwise mean
	# arranging the party first - and Enfina, who is not even travelling with
	# him, has to be fielded because the encounter names her.
	ok(not Campaign.party_order.has("enfina"), "Enfina is not in the party walking the crossroads")
	Campaign.current_encounter = helped
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(6)
	var combat: Combat = game.get_node("VisualCombat")
	var sneaker = {}
	var backup = {}
	var barbarian = {}
	for comb in combat.combatants:
		if comb.side == 1:
			barbarian = comb
		elif comb.combatant_key == "enfina":
			backup = comb
		else:
			sneaker = comb
	ok(combat.combatants.size() == 3, "three in the fight", "%d" % combat.combatants.size())
	ok(not sneaker.is_empty() and sneaker.combatant_key == leader_key and sneaker.position == caught_on,
		"the one caught, where they were caught", "%s" % [sneaker.get("position")])
	ok(not backup.is_empty() and backup.position == helped_ours[1].position, "Enfina where the backup arrives",
		"%s" % [backup.get("position")])
	ok(not barbarian.is_empty() and barbarian.position == post, "the guard where they stood", "%s" % [barbarian.get("position")])
	ok(not combat.deployment_active, "and it starts without arranging anybody")
	game.queue_free()
	await settle()
	log_line("")

	log_line("======== guards walk their patrol ========")
	var walker := Guard.new()
	walker.name = "Walker"
	walker.combatant_key = "priest"
	walker.looks_around = false
	walker.pause_seconds = 0.2
	walker.walk_speed_tiles = 6.0
	var there = post + Vector2i.RIGHT * 4
	for point in [["PostA", post], ["PostB", there]]:
		var waypoint := Waypoint.new()
		waypoint.point_name = point[0]
		map.add_child(waypoint)
		waypoint.global_position = tile_map.to_global(tile_map.map_to_local(point[1]))
	walker.patrol = ["PostA", "PostB"]
	map.add_child(walker)
	walker.global_position = tile_map.to_global(tile_map.map_to_local(post))
	guard.queue_free()
	await settle()
	party.frozen = false
	party.teleport(tile_map.to_global(tile_map.map_to_local(hideout + Vector2i.LEFT)))
	scene.begin_stealth()
	watch = scene.stealth
	watch.leave_for_battle = false
	var started_at = walker.global_position
	await wait(0.6)
	var walked = walker.global_position.distance_to(started_at)
	ok(walked > Grid.tiles(1.0), "the guard walks towards their next waypoint", "%.1f tiles" % (walked / Grid.TILE_SIZE))
	ok(walker.facing.x > 0.5, "facing the way they walk", "%s" % walker.facing)

	log_line("======== once beaten, whoever fought is gone ========")
	watch._caught_by(walker)
	Campaign.finish_battle_from_exploration(true, [])
	Engine.time_scale = 1.0
	party.frozen = false
	scene.begin_stealth()
	await settle()
	ok(scene.stealth.guards.is_empty() and (not is_instance_valid(walker) or walker.is_queued_for_deletion()),
		"won, the map is walked back into without the guard who fought")
	ok(scene.stealth._bar != null and scene.stealth._bar.is_inside_tree(), "and still a stealth map, bar and all")
	scene.queue_free()
	await settle()
	log_line("")


## Disguises: worn from the bar, fooling whoever they fool, and Hide to take
## one off again - out of sight only.
func in_disguise():
	Campaign.reset()
	Campaign.current_map = MAP
	var scene: ExplorationScene = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(scene)
	await settle(4)
	var map = scene.get_node("Map")
	var tile_map: TileMap = scene._tile_map
	var sight := StealthSight.new(tile_map)
	var party = scene.party
	var leader_key: String = Campaign.party_members()[0].key
	var post = find_post(scene, tile_map, sight, tile_map.local_to_map(party.position_of_leader()))
	var setup := StealthSetup.new()
	setup.battle_terrain = load(TERRAIN)
	map.add_child(setup)
	var guard := Guard.new()
	guard.combatant_key = "barbarian"
	guard.looks_around = false
	guard.recognises = Guard.Recognises.OWN_ROLE
	map.add_child(guard)
	guard.global_position = tile_map.to_global(tile_map.map_to_local(post))
	var hideout = post + Vector2i.LEFT * 2
	party.teleport(tile_map.to_global(tile_map.map_to_local(hideout)))
	scene.begin_stealth()
	var watch: StealthWatch = scene.stealth
	watch.leave_for_battle = false
	var bar: StealthBar = watch._bar
	await settle()

	log_line("======== a disguise is an item, kept out of fights ========")
	var robes: ItemDefinition = ItemDatabase.item("priest_robes")
	ok(robes != null and robes.is_disguise() and robes.disguise_as == "priest", "Priest Robes pass for a Priest")
	Campaign.give_item(leader_key, "priest_robes")
	ok(Campaign.disguises_of(leader_key) == ["priest_robes"], "carried, it is one of %s's disguises" % leader_key)
	ok(not Campaign.combat_items_of(leader_key).has("priest_robes"), "and never offered in a fight",
		"%s" % [Campaign.combat_items_of(leader_key)])
	await settle()
	ok(bar != null and bar._buttons.size() == 1 and bar._buttons[0].text.contains("1  Priest Robes"),
		"the stealth bar offers it, on the 1 key", bar._buttons[0].text if bar and not bar._buttons.is_empty() else "none")
	ok(bar._status.text == "Sneaking" and bar._hide.disabled, "sneaking already, so there is nothing to Hide from",
		"'%s', hide: %s" % [bar._status.text, bar._hide.tooltip_text])

	log_line("======== putting it on takes a while ========")
	var press := InputEventKey.new()
	press.physical_keycode = KEY_1
	press.pressed = true
	bar._unhandled_key_input(press)
	await settle()
	var priest: CombatantDefinition = CombatantDatabase.combatants["priest"]
	ok(watch.changing_into() == "priest_robes" and watch.worn_by(leader_key) == "", "the 1 key starts him changing into the robes - not on yet")
	ok(party.rooted and not party.frozen, "standing still to do it, while the guards carry on")
	ok(bar._status.text.begins_with("Changing into Priest Robes"), "the bar counts it down", bar._status.text)
	ok(party.leader.showing() != priest.sprite_frames, "still himself while he changes")
	var shuffled = await until(func(): return absf(party.leader.rotation) > 0.01, 1.0)
	ok(shuffled, "shuffling about as he does", "%.2f" % party.leader.rotation)
	ok(not watch.wear("priest_robes") and not watch.dash(), "no starting again, and no dashing, part-way through")
	var on = await until(func(): return watch.worn_by(leader_key) == "priest_robes", StealthWatch.DISGUISE_SECONDS + 0.5)
	ok(on and watch.changing_into() == "", "%d seconds later, the robes are on" % StealthWatch.DISGUISE_SECONDS)
	ok(not party.rooted and party.leader.rotation == 0.0 and party.leader.scale == Vector2.ONE, "and he can move again, standing straight")

	log_line("======== worn, he is somebody else ========")
	ok(watch.worn_by(leader_key) == "priest_robes", "the 1 key put the robes on")
	ok(party.leader.showing() == priest.sprite_frames, "drawn as a Priest")
	ok(party.leader.hidden_alpha == 1.0, "and solid - walking about openly rather than sneaking")
	ok(bar._status.text == "Disguised as Priest", "the bar says so", bar._status.text)

	log_line("======== who it fools ========")
	var in_view = tile_map.to_global(tile_map.map_to_local(post + Vector2i.RIGHT * 3))
	var cases = [
		["barbarian", Guard.Recognises.OWN_ROLE, false, "a Barbarian who knows only Barbarians walks straight past"],
		["priest", Guard.Recognises.OWN_ROLE, true, "a Priest who knows every Priest is not fooled"],
		["barbarian", Guard.Recognises.ANY_DISGUISE, true, "one who sees through anything is not fooled"],
		["priest", Guard.Recognises.NO_DISGUISE, false, "one fooled by any disguise is, even a Priest by Priest's robes"],
	]
	for case in cases:
		guard.combatant_key = case[0]
		guard.recognises = case[1]
		watch.suspicion[guard] = 0.0
		party.teleport(in_view)
		await wait(0.3)
		var grew: float = watch.suspicion[guard]
		ok((grew > 0.0) == case[2], case[3], "%.2f" % grew)
		party.teleport(tile_map.to_global(tile_map.map_to_local(hideout)))
		watch.suspicion[guard] = 0.0
		await settle()
	ok(watch.spotted_by == null, "and nobody got as far as sure")

	log_line("======== Hide, but only out of sight ========")
	guard.combatant_key = "barbarian"
	guard.recognises = Guard.Recognises.OWN_ROLE
	party.teleport(in_view)
	await settle()
	var refusal = watch.hide_refusal()
	ok(refusal.contains("can see him") and not watch.hide_again() and watch.worn_by(leader_key) == "priest_robes",
		"in the Barbarian's view, Hide is refused - he keeps the robes on", refusal)
	ok(bar._hide.disabled and bar._hide.tooltip_text == refusal, "and the bar greys it out, saying why")
	party.teleport(tile_map.to_global(tile_map.map_to_local(hideout)))
	await settle()
	ok(watch.hide_refusal() == "" and not bar._hide.disabled, "out of view, he can")
	var hide_key := InputEventKey.new()
	hide_key.physical_keycode = KEY_H
	hide_key.pressed = true
	bar._unhandled_key_input(hide_key)
	await settle()
	ok(watch.worn_by(leader_key) == "", "H takes the robes off")
	ok(party.leader.showing() != priest.sprite_frames and party.leader.hidden_alpha == StealthWatch.SNEAKING_ALPHA,
		"and he is himself again, sneaking")
	ok(Campaign.count_of(leader_key, "priest_robes") == 1, "the robes back in the bag, to wear again")
	scene.queue_free()
	await settle()
	log_line("")


## The dash: three tiles in a blink, five seconds to recover, and anybody who
## sees it grows sure three times as fast.
func dashing():
	Campaign.reset()
	Campaign.current_map = MAP
	var scene: ExplorationScene = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(scene)
	await settle(4)
	scene.end_blocking_interaction()
	var map = scene.get_node("Map")
	var tile_map: TileMap = scene._tile_map
	var sight := StealthSight.new(tile_map)
	var party = scene.party
	var post = find_post(scene, tile_map, sight, tile_map.local_to_map(party.position_of_leader()))
	var setup := StealthSetup.new()
	setup.battle_terrain = load(TERRAIN)
	map.add_child(setup)
	# Out of earshot to begin with - a dash is heard now - and looking the
	# other way.
	var far_off: Vector2i = post
	var region: Rect2i = sight.region()
	for x in range(region.position.x, region.end.x):
		for y in range(region.position.y, region.end.y):
			var tile := Vector2i(x, y)
			if far_off == post and standable(scene, tile_map, tile) \
					and Vector2(tile - post).length() > StealthWatch.DASH_NOISE_TILES + 6.0 \
					and not sight.clear(tile, post + Vector2i.RIGHT * 2):
				far_off = tile
	var guard := Guard.new()
	guard.combatant_key = "barbarian"
	guard.looks_around = false
	guard.facing_degrees = 180.0
	map.add_child(guard)
	guard.global_position = tile_map.to_global(tile_map.map_to_local(far_off))
	var start = tile_map.to_global(tile_map.map_to_local(post + Vector2i.RIGHT))
	party.teleport(start)
	scene.begin_stealth()
	var watch: StealthWatch = scene.stealth
	watch.leave_for_battle = false
	var bar: StealthBar = watch._bar
	await settle()

	log_line("======== Shift: a burst of speed ========")
	party._set_facing(false)
	ok(watch.dash(), "the dash goes")
	await wait(StealthWatch.DASH_SECONDS + 0.15)
	var moved = (party.position_of_leader().x - start.x) / Grid.TILE_SIZE
	ok(moved > StealthWatch.DASH_TILES - 0.4 and moved <= StealthWatch.DASH_TILES + 0.05,
		"%d tiles the way he faces, in a blink" % StealthWatch.DASH_TILES, "%.2f tiles" % moved)
	ok(not party.dashing, "and it is over as quickly")
	ok(watch.suspicion[guard] == 0.0, "behind the guard, nobody noticed")
	ok(not watch.dash() and watch.dash_cooldown() > StealthWatch.DASH_COOLDOWN - 1.0,
		"then not again for a while", "%.1f s to go" % watch.dash_cooldown())
	await settle()
	ok(bar._dash.disabled and bar._dash.text.begins_with("Dash ") and bar._dash.text.ends_with("s"),
		"the bar counts it down", bar._dash.text)
	watch._dash_cooldown = 0.0
	await settle()
	ok(not bar._dash.disabled and bar._dash.text == "Dash (Shift)", "and says when it is ready", bar._dash.text)
	party.teleport(start)
	var shift := InputEventKey.new()
	shift.physical_keycode = KEY_SHIFT
	shift.pressed = true
	bar._unhandled_key_input(shift)
	ok(party.dashing and watch.dash_cooldown() == StealthWatch.DASH_COOLDOWN, "Shift is the key for it")
	await wait(StealthWatch.DASH_SECONDS + 0.15)

	log_line("======== heard, if not seen ========")
	# Right behind him now, looking away: a dash within earshot turns him round.
	var reset_guard = func(facing: float):
		guard.global_position = tile_map.to_global(tile_map.map_to_local(post))
		guard.mood = Guard.Mood.PATROLLING
		guard.facing_degrees = facing
		watch.suspicion[guard] = 0.0
	reset_guard.call(180.0)
	party.teleport(start)
	watch._dash_cooldown = 0.0
	await settle()
	watch.dash()
	await wait(0.4)
	ok(guard.mood != Guard.Mood.PATROLLING, "a guard within %d tiles hears the dash" % StealthWatch.DASH_NOISE_TILES,
		Guard.Mood.keys()[guard.mood])
	ok(guard.facing.x > 0.5, "and turns towards it", "%s" % guard.facing)

	log_line("======== seen dashing, and sure far sooner ========")
	ok(is_equal_approx(watch.fill_rate(4.0, true), watch.fill_rate(4.0, false) * StealthWatch.DASH_NOTICE),
		"a guard grows sure %d times as fast of somebody dashing" % StealthWatch.DASH_NOTICE)
	# Standing in view for as long as a dash lasts, as the measure.
	reset_guard.call(0.0)
	party.teleport(tile_map.to_global(tile_map.map_to_local(post + Vector2i.RIGHT * 2)))
	await settle()
	watch.suspicion[guard] = 0.0
	await wait(StealthWatch.DASH_SECONDS)
	var standing: float = watch.suspicion[guard]
	reset_guard.call(0.0)
	party.teleport(start)
	watch._dash_cooldown = 0.0
	await settle()
	watch.suspicion[guard] = 0.0
	watch.dash()
	await wait(StealthWatch.DASH_SECONDS)
	var dashed: float = watch.suspicion[guard]
	ok(dashed > standing * 2.0, "dashing across a guard's view fills the meter far faster than standing in it",
		"%.2f dashing, %.2f standing" % [dashed, standing])

	log_line("======== a wall stops it ========")
	var wall := Vector2i.ZERO
	for d in [Vector2i.UP, Vector2i.DOWN]:
		if wall == Vector2i.ZERO and not standable(scene, tile_map, post + Vector2i.RIGHT * 3 + d):
			wall = d
	if wall != Vector2i.ZERO:
		party.frozen = false
		party.dashing = false
		var against = tile_map.to_global(tile_map.map_to_local(post + Vector2i.RIGHT * 3))
		party.teleport(against)
		ok(party.dash(Vector2(wall), Grid.tiles(StealthWatch.DASH_TILES), StealthWatch.DASH_SECONDS), "a dash at a wall")
		await wait(StealthWatch.DASH_SECONDS + 0.15)
		var went = party.position_of_leader().distance_to(against) / Grid.TILE_SIZE
		ok(went < 0.6, "goes no further than the wall", "%.2f tiles" % went)
	else:
		log_line("  (no wall beside the guard's lane to dash into)")
	scene.queue_free()
	await settle()
	log_line("")


## Waits up to `seconds` for `condition` to hold. True if it did.
func until(condition: Callable, seconds: float) -> bool:
	var waited := 0.0
	while waited < seconds:
		if condition.call():
			return true
		await get_tree().process_frame
		waited += get_process_delta_time()
	return condition.call()


## Everything the moment of being seen does: the guard stopping and turning,
## going to look and giving up, Cyrus starting, the screen, the sound, and the
## catch itself.
func reactions():
	Campaign.reset()
	Campaign.current_map = MAP
	var scene: ExplorationScene = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(scene)
	await settle(4)
	scene.end_blocking_interaction()
	var map = scene.get_node("Map")
	var tile_map: TileMap = scene._tile_map
	var sight := StealthSight.new(tile_map)
	var party = scene.party
	var post = find_post(scene, tile_map, sight, tile_map.local_to_map(party.position_of_leader()))
	var at = func(tile: Vector2i) -> Vector2: return tile_map.to_global(tile_map.map_to_local(tile))
	# Somewhere nothing along the guard's row can see, to be out of the way.
	var away := Vector2i(-99999, -99999)
	var region: Rect2i = sight.region()
	for x in range(region.position.x, region.end.x):
		for y in range(region.position.y, region.end.y):
			var tile := Vector2i(x, y)
			if away.x != -99999 or not standable(scene, tile_map, tile):
				continue
			var hidden_from_all = true
			for dx in range(-2, 6):
				if sight.clear(post + Vector2i(dx, 0), tile):
					hidden_from_all = false
			if hidden_from_all:
				away = tile
	var setup := StealthSetup.new()
	setup.battle_terrain = load(TERRAIN)
	map.add_child(setup)
	var guard := Guard.new()
	guard.combatant_key = "barbarian"
	guard.looks_around = false
	guard.search_seconds = 0.4
	guard.walk_speed_tiles = 6.0
	map.add_child(guard)
	guard.global_position = at.call(post)
	party.teleport(at.call(away))
	var music = AudioServer.get_bus_index("Music")
	var effects_before = AudioServer.get_bus_effect_count(music)
	scene.begin_stealth()
	var watch: StealthWatch = scene.stealth
	watch.leave_for_battle = false
	await settle()
	ok(away.x > -99999, "somewhere out of every sight line", "%s" % away)
	ok(AudioServer.get_bus_effect_count(music) == effects_before + 1 and watch.music_cutoff() >= 20000.0,
		"a stealth map puts a low-pass on the music, open while nobody is looking")

	log_line("======== seen: the guard stops and turns ========")
	var off_axis = post + Vector2i(3, 2)
	party.teleport(at.call(off_axis))
	var seen = await until(func(): return guard.mood == Guard.Mood.WATCHING, 0.5)
	ok(seen and guard.last_seen.distance_to(at.call(off_axis)) < 1.0, "in view, the guard is watching him")
	ok(watch.startled(), "and Cyrus starts - a '!' over him")
	var flinched = await until(func(): return absf(party.leader.scale.x - 1.0) > 0.01, 0.2)
	ok(flinched, "with a flinch", "%s" % party.leader.scale)
	await wait(0.3)
	var towards = (at.call(off_axis) - guard.global_position).normalized()
	ok(guard.facing.dot(towards) > 0.97, "the guard turns to face him", "%.2f" % guard.facing.dot(towards))
	ok(watch._heart.playing or watch._beat_in > 0.0, "a heartbeat starts")
	ok(watch.music_cutoff() < 20000.0, "and the music muffles", "%d Hz" % watch.music_cutoff())
	ok(StealthWatch.pulse_rate(0.9) > StealthWatch.pulse_rate(0.1) * 3.0, "the '?' pulses faster the surer they are")

	log_line("======== lost him, then goes looking ========")
	party.teleport(at.call(away))
	await settle(2)
	ok(guard.mood == Guard.Mood.SUSPICIOUS, "out of view before he is sure, the guard stares after him")
	var went = await until(func(): return guard.mood == Guard.Mood.INVESTIGATING, 3.0)
	ok(went, "once the doubt has drained, he goes to where Cyrus was")
	ok(guard.half_cone() == Guard.HALF_CONE_ALERT, "watching 340 degrees while he does",
		"%d either side" % guard.half_cone())
	watch._refresh_seen(guard)
	var narrow = sight.seen_from(tile_map.local_to_map(tile_map.to_local(guard.global_position)), guard.facing).size()
	ok(watch._seen[guard].size() > narrow, "seeing more of the room than his usual cone", "%d tiles against %d" % [watch._seen[guard].size(), narrow])
	var searched = await until(func(): return guard.mood == Guard.Mood.SEARCHING, 2.0)
	ok(searched and guard.global_position.distance_to(guard.last_seen) < Grid.tiles(0.6),
		"he gets there and looks about", "%.1f tiles off" % (guard.global_position.distance_to(guard.last_seen) / Grid.TILE_SIZE))
	var gave_up = await until(func(): return guard.mood == Guard.Mood.PATROLLING, 3.0)
	ok(gave_up and guard.global_position.distance_to(at.call(post)) < Grid.tiles(0.2),
		"then gives it up and goes back to his post")
	ok(guard.half_cone() == Guard.HALF_CONE + guard.alert_cone and guard.facing.dot(Vector2.RIGHT) > 0.99,
		"looking the way he did, with his usual cone - a little wider while the map is on edge",
		"%d either side, %d of it the alert" % [guard.half_cone(), guard.alert_cone])
	ok(watch.alert_level() == "Wary",
		"the investigation put the map on edge", "%.2f, %s" % [watch.alert, watch.alert_level()])

	log_line("======== an arrow for a guard off the screen ========")
	var camera = scene.camera
	watch.suspicion[guard] = 0.9
	camera.position = at.call(post) + Vector2(Grid.tiles(30), 0)
	await settle(2)
	watch.suspicion[guard] = 0.9
	var arrows: Array = watch._arrows.arrows()
	var screen: Vector2 = watch._arrows.size
	ok(arrows.size() == 1 and arrows[0].guard == guard, "one arrow, for him", "%d" % arrows.size())
	if arrows.size() == 1:
		var point: Vector2 = arrows[0].at
		var margin = StealthWatch.ARROW_MARGIN
		var on_edge = absf(point.x - margin) < 1.0 or absf(point.x - (screen.x - margin)) < 1.0 \
				or absf(point.y - margin) < 1.0 or absf(point.y - (screen.y - margin)) < 1.0
		var off_there: Vector2 = guard.get_global_transform_with_canvas().origin
		ok(on_edge, "at the edge of the screen", "%s on %s" % [point, screen])
		ok((off_there - point).normalized().dot(arrows[0].towards) > 0.9, "pointing the way he is",
			"he is at %s" % off_there)
	camera.position = party.position_of_leader()
	watch.suspicion[guard] = 0.0
	await settle(2)

	log_line("======== caught ========")
	party.teleport(at.call(post + Vector2i.RIGHT * 2))
	var caught = await until(func(): return watch.spotted_by == guard, 2.0)
	ok(caught, "stood in view, he is caught")
	ok(Engine.time_scale < 0.5, "time crawls for a moment", "%.2f" % Engine.time_scale)
	ok(camera._shake > 0.0, "the screen shakes")
	ok(watch.pop_scale() < StealthWatch.CAUGHT_SIZE, "the '!' pops in, from small", "%.2f" % watch.pop_scale())
	ok(guard.sprite.modulate != Color.WHITE, "the guard flashes")
	ok(watch._sting.playing, "and a sting plays")
	ok(watch.music_cutoff() < 1000.0, "with the music at its most muffled", "%d Hz" % watch.music_cutoff())
	await get_tree().create_timer(StealthWatch.CAUGHT_SLOW_SECONDS + 0.2, true, false, true).timeout
	ok(is_equal_approx(Engine.time_scale, 1.0), "then time runs again", "%.2f" % Engine.time_scale)
	ok(is_equal_approx(watch.pop_scale(), StealthWatch.CAUGHT_SIZE), "and the '!' settles bigger than the '?' was",
		"%.2f" % watch.pop_scale())

	log_line("======== leaving puts it all back ========")
	# Mid-slow-motion, the way a scene change can arrive.
	watch._slowed = true
	Engine.time_scale = StealthWatch.CAUGHT_TIME_SCALE
	scene.queue_free()
	await settle(2)
	ok(is_equal_approx(Engine.time_scale, 1.0), "a map left mid-slow-motion leaves time running")
	ok(AudioServer.get_bus_effect_count(music) == effects_before, "and the music unmuffled")
	log_line("")


## Somewhere a guard can stand and look right down four open tiles, with a
## free tile two behind them, near where the party arrived.
func find_post(scene: ExplorationScene, tile_map: TileMap, sight: StealthSight, start_tile: Vector2i) -> Vector2i:
	var frontier := [start_tile]
	var visited := {start_tile: true}
	while not frontier.is_empty():
		var tile: Vector2i = frontier.pop_front()
		var fits = standable(scene, tile_map, tile) and standable(scene, tile_map, tile + Vector2i.LEFT * 2)
		for step in range(1, 5):
			fits = fits and standable(scene, tile_map, tile + Vector2i.RIGHT * step)
		if fits and sight.clear(tile, tile + Vector2i.RIGHT * 4) and tile.distance_to(start_tile) >= 3:
			return tile
		for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = tile + d
			if not visited.has(next) and sight.region().has_point(next) and standable(scene, tile_map, next):
				visited[next] = true
				frontier.append(next)
	return Vector2i(-99999, -99999)


func standable(scene: ExplorationScene, tile_map: TileMap, tile: Vector2i) -> bool:
	return scene.is_walkable(tile_map.to_global(tile_map.map_to_local(tile)))
