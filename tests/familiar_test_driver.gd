extends "res://StealthHarness.gd"
## Alithia's Find Familiar (the designer, 2026-10-26): cast on a map through a
## real World casting, the map's animal steered and seen through while the
## party waits; small gaps only it fits through, a flier over what stops only
## walkers; guards make it out only close up and shoo it, hounds smell it,
## nobody's guard ignores it; magic sensors feel it - and anybody invisible -
## through walls; Tab swaps who is steered and G lets it go; never in a fight.


## Who the last with_alithia placed, by name.
var made := {}


func suite() -> String:
	return "familiar"


func time_limit() -> float:
	return 300.0


func run_sections():
	the_spell()
	await casting()
	await small_gaps()
	await flying()
	await guards()
	await hounds_and_bystanders()
	await sensors()
	await what_it_sees()
	await caught_with_it_out()
	await the_bar()


## A crossroads with Alithia in the party, guards placed by `place_guards`
## (which gets the map), the party watched from somewhere out of every post's
## sight.
func with_alithia(place_guards: Callable = Callable(), hides_guards: bool = false) -> Dictionary:
	var m := await open_map()
	Campaign.add_member("alithia")
	await settle(2)
	m.setup.guards_seen_only_in_sight = hides_guards
	var posts: Array = [m.post]
	if place_guards.is_valid():
		posts.append_array(place_guards.call(m))
	var away := out_of_sight_of(m, posts)
	m.watch = await watch_it(m, away)
	return m


## Placers for with_alithia: who stands where, and the posts to keep the party
## out of sight of.
func _watchman_at_post(map: Dictionary) -> Array:
	made = {"watchman": add_guard(map, "Watchman", map.post, 0.0)}
	return []


func _hound_at_post(map: Dictionary) -> Array:
	var hound := add_guard(map, "Hound", map.post, 0.0, "bomber")
	hound.kind = Guard.Kind.DOG
	hound.smell_tiles = 3.0
	made = {"hound": hound}
	return []


func _bystander_at_post(map: Dictionary) -> Array:
	var bystander := add_guard(map, "Baker", map.post, 0.0)
	bystander.kind = Guard.Kind.CIVILIAN
	made = {"bystander": bystander}
	return []


## A sensor on the post, and a watchman some way off who cannot see it, to
## come and look.
func _sensor_at_post(map: Dictionary) -> Array:
	var sensor := add_guard(map, "Sensor", map.post, 0.0, "mimic")
	sensor.kind = Guard.Kind.SENSOR
	sensor.sense_tiles = 4.0
	made = {"sensor": sensor}
	var far := find_tile(map, func(tile): return gap(tile, map.post) >= 7.0 and gap(tile, map.post) <= 12.0 and not map.sight.clear(tile, map.post))
	if far == NOWHERE:
		return []
	made["watchman"] = add_guard(map, "Watchman", far, 180.0)
	return [far]


func familiar_tile(m: Dictionary) -> Vector2i:
	return tile_at(m, m.watch.familiar.global_position)


func put_familiar(m: Dictionary, tile: Vector2i):
	m.watch.familiar.global_position = at(m, tile)


func the_spell():
	log_line("======== the spell ========")
	var spell: SkillDefinition = SkillDatabase.skills.get("find_familiar")
	ok(spell != null, "Find Familiar is a skill")
	if spell == null:
		return
	ok(spell.spell_slot_level == 1 and spell.outside_only() and spell.icon != null, "a spell through the Gates of World, cast only outside a fight")
	var alithia: CombatantDefinition = CombatantDatabase.combatants["alithia"]
	ok(alithia.skills.has("find_familiar"), "and Alithia's")
	ok(not Combat.fighting_skills(alithia.skills).has("find_familiar") and Combat.fighting_skills(alithia.skills).has("heal"),
		"no part of her kit in a fight")
	ok(CharacterSheet.facts_of(spell, {"level": 1}) == ["Outside a fight", "World"], "the Moves page says so",
		"%s" % [CharacterSheet.facts_of(spell, {"level": 1})])
	for key in ["rat", "cat", "raven"]:
		var form: FamiliarForm = load("res://data/familiars/%s.tres" % key)
		ok(form != null and form.size <= Sizes.Size.SMALL and form.noticed_within <= 4.0, "a %s: small, and made out only close up" % key,
			"%s, %.1f tiles" % [Sizes.NAMES[form.size], form.noticed_within] if form != null else "missing")
	ok(load("res://data/familiars/raven.tres").movement_class == 1, "  and the raven flies")
	log_line("")


func casting():
	log_line("======== calling it ========")
	var m := await with_alithia()
	var watch: StealthWatch = m.watch
	ok(watch.familiar_spell().get("caster", "") == "alithia" and watch.familiar_refusal() == "", "Alithia on the map: it can be called",
		watch.familiar_refusal())
	var world_before: int = Campaign.gates_left_outside("alithia")[1]
	var leader_at: Vector2 = m.party.position_of_leader()
	ok(watch.summon_familiar() and watch.familiar != null, "called")
	ok(Campaign.gates_left_outside("alithia")[1] == world_before - 1 and Campaign.gates_spent_outside.get("alithia", [0, 0])[1] == 1,
		"through a real World casting, off the next fight's", "%d -> %d" % [world_before, Campaign.gates_left_outside("alithia")[1]])
	ok(watch.familiar.form.name == "Rat" and watch.familiar.form.size == Sizes.Size.TINY, "a map that names none: a rat")
	var alithia_sprite = m.party.sprite_for("alithia")
	ok(alithia_sprite != null and watch.familiar.global_position.distance_to(alithia_sprite.global_position) < 1.0, "beside her")
	ok(watch.controlling_familiar() and m.party.rooted, "the player steers it, and the party waits where it stands")
	var from: Vector2 = watch.familiar.global_position
	var moved := false
	for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		if watch.familiar.step(direction, 0.2):
			moved = true
			break
	ok(moved and watch.familiar.global_position != from and m.party.position_of_leader() == leader_at, "it moves; the party does not")
	ok(m.scene.camera.position.distance_to(watch.familiar.global_position) < Grid.tiles(8.0), "the view goes with it")
	ok(watch.familiar_refusal() != "", "  and a second will not come while it is out", watch.familiar_refusal())
	watch.toggle_familiar_control()
	ok(not watch.controlling_familiar() and watch.familiar != null and not m.party.rooted, "Tab: back to the party - it stays where it is")
	watch.toggle_familiar_control()
	ok(watch.controlling_familiar() and m.party.rooted, "  and back to it")
	watch.dismiss_familiar()
	ok(watch.familiar == null and not watch.controlling_familiar() and not m.party.rooted, "let go: gone, and the party theirs again")
	ok(watch.summon_familiar(), "called again, with her second World casting")
	watch.dismiss_familiar()
	ok(Campaign.gates_left_outside("alithia")[1] == 0 and watch.familiar_refusal().contains("no castings"), "  and with none left, it will not come",
		watch.familiar_refusal())
	var comb := {"spell_slots": [0, 2, 0, 0]}
	Campaign.take_gates_spent_outside(comb, "alithia")
	ok(comb.spell_slots[1] == 0, "the next fight starts with both World castings spent", "%s" % [comb.spell_slots])
	await close_map(m)


func small_gaps():
	log_line("======== small gaps ========")
	var m := await with_alithia()
	var watch: StealthWatch = m.watch
	# A wall a tile thick, with floor either side of it.
	var wall := NOWHERE
	var region: Rect2i = m.sight.region()
	for x in range(region.position.x + 1, region.end.x - 1):
		for y in range(region.position.y, region.end.y):
			var tile := Vector2i(x, y)
			if m.scene._blocking.has(tile) and standable(m, tile + Vector2i.LEFT) and standable(m, tile + Vector2i.RIGHT):
				wall = tile
				break
		if wall != NOWHERE:
			break
	ok(wall != NOWHERE, "a wall a tile thick to try it on", "%s" % wall)
	if wall == NOWHERE:
		await close_map(m)
		return
	watch.summon_familiar()
	ok(not watch.familiar.can_be_at(at(m, wall)), "a plain wall stops it")
	m.scene.set_small_gap(wall, true)
	ok(watch.familiar.can_be_at(at(m, wall)) and not m.scene.is_walkable(at(m, wall)), "a small gap in it: the rat fits, nobody in the party does")
	ok(not m.scene.is_walkable_for(at(m, wall), Sizes.Size.HUMAN) and m.scene.is_walkable_for(at(m, wall), Sizes.Size.SMALL),
		"  nothing bigger than Small")
	put_familiar(m, wall + Vector2i.LEFT)
	for i in 40:
		watch.familiar.step(Vector2.RIGHT, 0.05)
	ok(familiar_tile(m).x > wall.x, "it goes through and out the other side", "%s -> %s" % [wall + Vector2i.LEFT, familiar_tile(m)])
	m.scene.set_small_gap(wall, false)
	watch.dismiss_familiar()
	await close_map(m)


func flying():
	log_line("======== a raven ========")
	var m := await with_alithia()
	var low := NOWHERE
	for tile in m.scene._blocking:
		if not m.scene._blocking_fliers.has(tile) and m.sight.region().has_point(tile):
			low = tile
			break
	m.setup.familiar_form = load("res://data/familiars/raven.tres")
	m.watch.summon_familiar()
	ok(m.watch.familiar.form.name == "Raven", "a map naming the raven: a raven")
	if low == NOWHERE:
		log_line("  NOTE  nothing on this map stops walkers but not fliers - the raven's flight is not tried here")
	else:
		ok(m.scene.is_walkable_for(at(m, low), Sizes.Size.SMALL, 1) and not m.scene.is_walkable_for(at(m, low), Sizes.Size.TINY, 0),
			"over what stops only walkers - which stops a rat", "%s" % low)
	m.watch.dismiss_familiar()
	await close_map(m)


func guards():
	log_line("======== a watchman ========")
	var m := await with_alithia(_watchman_at_post)
	var watch: StealthWatch = m.watch
	var watchman: Guard = made.watchman
	settle_guard(watch, watchman)
	watch.summon_familiar()
	put_familiar(m, m.post + Vector2i.RIGHT * 4)
	await wait(1.0)
	ok(watch.familiar != null and watch.familiar_doubt.get(watchman, 0.0) <= 0.0 and watch.sees(watchman, familiar_tile(m)),
		"in plain view four tiles off: a rat is nothing to look at twice", "%.2f" % watch.familiar_doubt.get(watchman, 0.0))
	var alert: float = watch.alert
	put_familiar(m, m.post + Vector2i.RIGHT)
	var gone := await until(func(): return watch.familiar == null, 6.0)
	ok(gone, "right in front of him: he makes it out, and is rid of it")
	ok(watchman.mood == Guard.Mood.INVESTIGATING or watchman.mood == Guard.Mood.SEARCHING, "  and goes to see what it was about",
		Guard.Mood.keys()[watchman.mood])
	ok(watch.alert > alert and watch.spotted_by == null, "  the map a little more on edge - and nobody caught", "%.2f -> %.2f" % [alert, watch.alert])
	ok(not m.party.rooted and not watch.controlling_familiar(), "  the party theirs again")
	await close_map(m)


func hounds_and_bystanders():
	log_line("======== a hound, and somebody who is nobody's guard ========")
	var m := await with_alithia(_hound_at_post)
	var watch: StealthWatch = m.watch
	watch.summon_familiar()
	put_familiar(m, m.post + Vector2i.LEFT * 2)
	ok(await until(func(): return watch.familiar == null, 6.0), "a hound smells it behind him, and chases it off")
	await close_map(m)
	m = await with_alithia(_bystander_at_post)
	watch = m.watch
	watch.summon_familiar()
	put_familiar(m, m.post + Vector2i.RIGHT)
	await wait(1.5)
	ok(watch.familiar != null and watch.familiar_doubt.get(made.bystander, 0.0) <= 0.0, "nobody's guard pays an animal no mind")
	await close_map(m)


func sensors():
	log_line("======== a magic sensor ========")
	var m := await with_alithia(_sensor_at_post)
	var watch: StealthWatch = m.watch
	var sensor: Guard = made.sensor
	ok(not sensor.moves() and not sensor.fights(), "it never moves, and never fights")
	ok(watch.gaze_of(sensor) == StealthWatch.Gaze.FOOLED, "with no magic about, nothing to it")
	# Anybody visible, close by: nothing.
	var leader = m.party.leader
	var beside := find_tile(m, func(tile): return gap(tile, m.post) <= 2.0 and gap(tile, m.post) >= 1.0)
	m.party.teleport(at(m, beside))
	await wait(1.0)
	ok(watch.suspicion.get(sensor, 0.0) <= 0.0 and watch.spotted_by == null, "the party beside it, seen as they are: it feels nothing",
		"%.2f" % watch.suspicion.get(sensor, 0.0))
	m.party.teleport(at(m, m.away))
	await settle(2)
	# The familiar, through a wall if there is one about.
	watch.summon_familiar()
	ok(watch.gaze_of(sensor) == StealthWatch.Gaze.SEES, "the familiar out: it is danger")
	var spot := NOWHERE
	for dx in range(-4, 5):
		for dy in range(-4, 5):
			var tile: Vector2i = m.post + Vector2i(dx, dy)
			if Vector2(dx, dy).length() <= 3.5 and standable(m, tile) and not m.sight.clear(m.post, tile):
				spot = tile
	if spot == NOWHERE:
		spot = m.post + Vector2i.RIGHT * 3
		log_line("  NOTE  no wall within reach of the post - the sensor is tried in the open")
	var level := StealthWatch.level_of(watch.alert)
	put_familiar(m, spot)
	ok(await until(func(): return watch.familiar == null, 6.0), "it feels the familiar %s, and breaks the spell" % ("through a wall" if not m.sight.clear(m.post, spot) else "in the open"))
	ok(StealthWatch.level_of(watch.alert) == level + 1, "  and sounds: the map a level more on edge", "%d -> %d" % [level, StealthWatch.level_of(watch.alert)])
	if made.get("watchman") != null:
		ok(made.watchman.mood == Guard.Mood.INVESTIGATING or made.watchman.mood == Guard.Mood.SEARCHING, "  the nearest guard comes to look",
			Guard.Mood.keys()[made.watchman.mood])
	# Somebody invisible, close by: caught.
	watch._unseen[m.leader] = 60.0
	m.party.teleport(at(m, beside))
	ok(await until(func(): return watch.spotted_by == sensor, 6.0), "somebody invisible beside it: it feels the spell on them - caught")
	await close_map(m)


func what_it_sees():
	log_line("======== seeing through its eyes ========")
	var m := await with_alithia(_watchman_at_post, true)
	var watch: StealthWatch = m.watch
	var watchman: Guard = made.watchman
	await settle(2)
	ok(watch.hides_guards() and not watch.guard_shown(watchman), "a map that hides guards out of sight: this one, out of the party's, unseen")
	watch.summon_familiar()
	put_familiar(m, m.post + Vector2i.LEFT * 2)
	await settle(2)
	ok(watch.guard_shown(watchman), "the familiar can see him: shown")
	watch.dismiss_familiar()
	await settle(2)
	ok(not watch.guard_shown(watchman), "  let go: unseen again")
	await close_map(m)


func caught_with_it_out():
	log_line("======== caught while it is out ========")
	var m := await with_alithia(_watchman_at_post)
	var watch: StealthWatch = m.watch
	watch.summon_familiar()
	put_familiar(m, m.away)
	m.party.teleport(at(m, m.post + Vector2i.RIGHT * 2))
	ok(await until(func(): return watch.spotted_by != null, 6.0), "the party standing in his view is caught")
	ok(watch.familiar == null and not watch.controlling_familiar(), "  and the familiar slips away: no animal in the fight")
	await close_map(m)


func the_bar():
	log_line("======== on the bar ========")
	var m := await with_alithia()
	var watch: StealthWatch = m.watch
	var bar: StealthBar = watch.get_node("StealthHud/StealthBar")
	bar.refresh()
	ok(bar._familiar.visible and bar._familiar.text.begins_with("Find Familiar (World 2"), "a button for it, with its castings", bar._familiar.text)
	bar.outside_spell()
	ok(watch.familiar != null, "with only it known, the Outside Spell key calls it")
	bar.refresh()
	ok(bar._familiar.text.begins_with("Let the rat go"), "  then lets it go", bar._familiar.text)
	press(bar, KEY_V)
	ok(watch.familiar != null, "  the party's own keys do nothing meanwhile")
	bar.outside_spell()
	ok(watch.familiar == null, "  pressed again: let go")
	await close_map(m)
	# Prometheus too, past the Gates of Hermes: Invisibility as well - which?
	m = await open_map()
	Campaign.add_member("alithia")
	Campaign.add_member("prometheus")
	Campaign.reach_level(14, true)
	await settle(2)
	watch = await watch_it(m, out_of_sight_of(m, [m.post]))
	bar = watch.get_node("StealthHud/StealthBar")
	ok(not watch.invisibility_spell().is_empty() and not watch.familiar_spell().is_empty(), "both known at 14")
	bar.outside_spell()
	var choice = bar._choice
	ok(is_instance_valid(choice) and choice.find_child("Invisibility", true, false) != null and choice.find_child("Familiar", true, false) != null,
		"the key asks which")
	if is_instance_valid(choice):
		choice.find_child("Familiar", true, false).pressed.emit()
		await settle(2)
	ok(watch.familiar != null and not is_instance_valid(bar._choice), "  Find Familiar chosen: called")
	watch.dismiss_familiar()
	MenuPause.clear(get_tree())
	await close_map(m)
