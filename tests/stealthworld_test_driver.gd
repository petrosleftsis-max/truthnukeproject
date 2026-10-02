extends "res://StealthHarness.gd"
## The stealth map itself: rounds known only once found out, the ghost where a
## guard thinks he is, noisy ground and creeping, doors, lamps in the dark, and
## guards noticing what has changed - a door left open, a lamp out, something
## gone, a hiding spot with a body stuffed in it.


func suite() -> String:
	return "stealthworld"


func run_sections():
	await known_rounds()
	await where_they_think_he_is()
	await noisy_ground()
	await doors()
	await lamps_in_the_dark()
	await something_gone()
	await a_boot_sticking_out()
	await thrown_from_hiding()


## A round is drawn only once found out, and then only while listening or with
## the pointer on him.
func known_rounds():
	var m = await open_map()
	m.setup.guards_seen_only_in_sight = true
	var post: Vector2i = m.post
	var walker = add_guard(m, "Walker", post, 0.0)
	walker.route_known_flag = "roster_read"
	var watch = await watch_it(m, out_of_sight_of(m, row(post)))
	walker.start([at(m, post), at(m, post + Vector2i.RIGHT * 4)], Actors.route)
	log_line("======== a round, found out ========")
	ok(not watch.route_known(walker) and watch.shown_routes().is_empty(), "nobody knows his round to begin with")
	watch.listen()
	ok(watch.shown_routes().is_empty(), "and listening does not tell it")
	watch._ears_left = 0.0
	Campaign.set_flag("roster_read")
	ok(watch.route_known(walker), "the roster read, it is known")
	ok(watch.shown_routes().is_empty(), "but not drawn while he is neither listening nor pointing at him")
	watch._ears_cooldown = 0.0
	watch.listen()
	var shown = watch.shown_routes()
	ok(shown.size() == 1 and shown[0][0] == walker and shown[0][1].size() == 2, "listening, it is drawn - both his stops")
	watch._ears_left = 0.0
	watch._hovered = walker
	ok(watch.shown_routes().size() == 1, "and with the pointer on him")
	watch._hovered = null
	ok(watch.shown_routes().is_empty(), "and not otherwise")
	await close_map(m)


## Out looking for somebody, a guard looks where he saw them - and a ghost of
## the leader stands there.
func where_they_think_he_is():
	var m = await open_map()
	var post: Vector2i = m.post
	var looker = add_guard(m, "Looker", post, 0.0)
	var watch = await watch_it(m, out_of_sight_of(m, row(post)))
	log_line("======== the ghost ========")
	ok(watch.sought_at().is_empty(), "nobody is looking for anybody")
	looker.last_seen = at(m, post + Vector2i.RIGHT * 3)
	looker.investigate(looker.last_seen)
	ok(watch.sought_at().is_empty(), "going to see about a noise is not looking for somebody")
	looker.hunting = true
	ok(watch.sought_at() == [looker.last_seen], "going after somebody he saw, the ghost stands where he saw them")
	ok(not m.party.leader.current_frame().is_empty(), "(drawn from the leader's own frame)")
	await close_map(m)


## Walked across at an ordinary pace, noisy ground is heard; crept across, not.
func noisy_ground():
	var m = await open_map()
	var post: Vector2i = m.post
	var listener = add_guard(m, "Listener", post, 180.0)
	# A strip of gravel in front of him, behind his back as he faces away.
	var gravel := NoisyFloor.new()
	gravel.kind = NoisyFloor.Kind.GRAVEL
	gravel.size_tiles = Vector2i(3, 1)
	place(m, gravel, post + Vector2i.RIGHT * 2)
	var watch = await watch_it(m, post + Vector2i.RIGHT * 4)
	var party = m.party
	log_line("======== gravel ========")
	ok(watch.noisy_floor_at(post + Vector2i.RIGHT * 3) == gravel and watch.noisy_floor_at(post + Vector2i.RIGHT * 5) == null,
		"the patch covers its tiles and no others")
	var moods = await walk(party, Vector2.LEFT, 0.7, listener)
	ok(moods.has(Guard.Mood.LISTENING) and not moods.has(Guard.Mood.INVESTIGATING), "walked across, he hears it and turns to it",
		"%s" % [moods.map(func(mood): return Guard.Mood.keys()[mood])])
	settle_guard(watch, listener, 180.0)
	party.teleport(at(m, post + Vector2i.RIGHT * 4))
	await settle()
	watch.toggle_creep()
	await settle()
	ok(watch.creeping() and is_equal_approx(party.pace, StealthWatch.CREEP_PACE), "creeping, he walks at %d%% of his pace" % roundi(StealthWatch.CREEP_PACE * 100.0))
	moods = await walk(party, Vector2.LEFT, 0.8, listener)
	ok(watch.noisy_floor_at(tile_at(m, party.leader.global_position)) == gravel, "(on the gravel)")
	ok(moods == [Guard.Mood.PATROLLING], "crept across, not a sound", "%s" % [moods.map(func(mood): return Guard.Mood.keys()[mood])])
	watch.toggle_creep()
	await settle()
	ok(party.pace == 1.0, "and back to his own pace")

	log_line("======== broken glass ========")
	gravel.kind = NoisyFloor.Kind.BROKEN_GLASS
	settle_guard(watch, listener, 180.0)
	party.teleport(at(m, post + Vector2i.RIGHT * 4))
	await settle()
	ok(listener.mood == Guard.Mood.PATROLLING, "(put there, not walked there: not a sound)")
	moods = await walk(party, Vector2.LEFT, 0.35, listener)
	ok(moods.has(Guard.Mood.INVESTIGATING), "nobody treads on glass by accident: he comes to look",
		"%s" % [moods.map(func(mood): return Guard.Mood.keys()[mood])])
	await close_map(m)


## Walks the party `direction` for `seconds` of the game's own time, and says
## every mood `guard` was in along the way.
func walk(party: ExplorationParty, direction: Vector2, seconds: float, guard: Guard = null) -> Array:
	var moods := []
	var gone := 0.0
	while gone < seconds:
		var delta = maxf(get_process_delta_time(), 0.001)
		party._step(direction, delta)
		await get_tree().process_frame
		gone += delta
		if guard != null and not moods.has(guard.mood):
			moods.append(guard.mood)
	return moods


## Shut, a door stops walking and sight; open, neither. Left open, a guard who
## sees it comes and shuts it - and a guard walking through holds it open.
func doors():
	var m = await open_map()
	var post: Vector2i = m.post
	var keeper = add_guard(m, "Keeper", post, 0.0)
	var door := StealthDoor.new()
	place(m, door, post + Vector2i.RIGHT * 2, "Door")
	var watch = await watch_it(m, out_of_sight_of(m, row(post)))
	var beyond = post + Vector2i.RIGHT * 3
	log_line("======== shut ========")
	ok(not door.is_open and not watch.sees(keeper, beyond), "shut, he cannot see past it")
	ok(not m.scene.is_walkable(at(m, post + Vector2i.RIGHT * 2)), "and nobody walks through it")
	log_line("======== opened, and left open ========")
	keeper.facing_degrees = 180.0
	await settle()
	ok(watch.set_door(door, true, true) and door.is_open, "opened")
	ok(m.scene.is_walkable(at(m, post + Vector2i.RIGHT * 2)), "open, it can be walked through")
	keeper.facing_degrees = 0.0
	await settle()
	ok(watch.sees(keeper, beyond), "and seen through")
	var noticed = await until(func(): return keeper.mood == Guard.Mood.INVESTIGATING, 1.0)
	ok(noticed and watch.alert > 0.0, "seeing it left open, he comes to see about it - the map a little on edge", "%.2f" % watch.alert)
	var shut = await until(func(): return not door.is_open, 10.0)
	ok(shut, "and shuts it")
	var gone_back = await until(func(): return not door.passable(), 10.0)
	ok(gone_back and not watch.sees(keeper, beyond), "back at his post with it shut behind him, he cannot see past it")
	log_line("======== a guard walking through ========")
	settle_guard(watch, keeper, 0.0)
	keeper.global_position = at(m, post + Vector2i.RIGHT * 2)
	await settle()
	ok(door.held and door.passable() and not door.is_open, "a guard in the doorway holds it open without it being left open")
	keeper.global_position = at(m, post)
	await settle()
	ok(not door.held and not door.passable(), "and it swings shut behind him")
	await close_map(m)


## On a dark map a guard makes somebody out only close up - unless a lamp
## lights them. A pebble knocks a lamp out; a guard who sees it out comes to
## light it again.
func lamps_in_the_dark():
	var m = await open_map()
	m.setup.dark = true
	m.setup.torch_light_tiles = 0.0
	var post: Vector2i = m.post
	var watcher = add_guard(m, "Watcher", post, 0.0)
	var lamp := Lamp.new()
	lamp.light_tiles = 1.5
	place(m, lamp, post + Vector2i.RIGHT * 4, "Lamp")
	Campaign.give_item(m.leader, "pebble")
	var watch = await watch_it(m, out_of_sight_of(m, row(post)))
	var far_lit = post + Vector2i.RIGHT * 4
	var far_dark = post + Vector2i.RIGHT * 4
	log_line("======== lit, and dark ========")
	ok(watch.lit_at(far_lit) > 0.0 and watch.lit_at(post + Vector2i.LEFT * 2) == 0.0, "lamplight where the lamp is, dark away from it")
	ok(watch.sees(watcher, far_lit), "a lit tile four off: he sees it")
	ok(watch.sees(watcher, post + Vector2i.RIGHT * 2), "a dark one two off: close enough to make out")
	log_line("======== knocked out ========")
	m.party.teleport(at(m, post + Vector2i.RIGHT * 7))
	await settle()
	watch.begin_throw()
	var threw = watch.throw_at(post + Vector2i.RIGHT * 4)
	ok(threw and not lamp.lit, "a pebble landing beside it knocks it out")
	ok(watch.lit_at(far_dark) == 0.0 and not watch.sees(watcher, far_dark), "dark now: four tiles off, he makes out nothing")
	m.party.teleport(at(m, out_of_sight_of(m, row(post))))
	settle_guard(watch, watcher, 0.0)
	var relit = await until(func(): return lamp.lit, 12.0)
	ok(relit, "seeing it out, he comes and lights it again")
	await close_map(m)

	log_line("======== put out by hand ========")
	m = await open_map()
	m.setup.dark = true
	var hand_lamp := Lamp.new()
	place(m, hand_lamp, m.post, "HandLamp")
	watch = await watch_it(m, m.post + Vector2i.RIGHT)
	ok(hand_lamp.is_available(), "beside a lit lamp, there is something to put out")
	hand_lamp.use(m.scene)
	ok(not hand_lamp.lit and not hand_lamp.is_available(), "E puts it out, quietly - and there is nothing more to do with it")
	await close_map(m)


## Something taken that a guard would miss: one who sees where it stood comes
## to look.
func something_gone():
	var m = await open_map()
	var post: Vector2i = m.post
	var keeper = add_guard(m, "Keeper", post, 180.0)
	var ledger := StealthPickup.new()
	ledger.item_key = "cure_potion"
	ledger.taken_flag = "took_it"
	place(m, ledger, post + Vector2i.RIGHT * 2, "Ledger")
	var watch = await watch_it(m, post + Vector2i.RIGHT * 3)
	log_line("======== taken ========")
	var had = Campaign.count_of(m.leader, "cure_potion")
	ok(ledger.is_available(), "beside it, it can be taken")
	ledger.use(m.scene)
	ok(ledger.taken and Campaign.count_of(m.leader, "cure_potion") == had + 1 and Campaign.flag("took_it"), "E: it is in his bag")
	ok(not ledger.is_available(), "and gone")
	m.party.teleport(at(m, out_of_sight_of(m, row(post))))
	await settle()
	keeper.facing_degrees = 0.0
	var missed = await until(func(): return keeper.mood == Guard.Mood.INVESTIGATING, 1.0)
	ok(missed and keeper.last_seen.distance_to(ledger.global_position) < 1.0, "a guard who sees where it stood comes to look")
	await close_map(m)


## A body stuffed into a hiding spot: a guard who comes within a couple of tiles
## with it in view notices, and pulls him out.
func a_boot_sticking_out():
	var m = await open_map()
	var post: Vector2i = m.post
	var spot_tile = post + Vector2i.RIGHT * 2
	var spot = add_spot(m, spot_tile)
	var passer = add_guard(m, "Passer", post, 180.0)
	var body = add_guard(m, "Body", out_of_sight_of(m, row(post)), 0.0)
	var watch = await watch_it(m, spot_tile + Vector2i.RIGHT)
	log_line("======== stuffed away ========")
	body.knock_out()
	watch._bodies[body] = false
	watch._dragging = body
	ok(watch.put_down(spot_tile) and watch.is_stashed(body), "(a body in the spot)")
	m.party.teleport(at(m, out_of_sight_of(m, row(post) + [spot_tile])))
	await settle()
	var far_tile = find_tile(m, func(t): return gap(t, spot_tile) >= 4.0 and gap(t, spot_tile) <= 6.0 and m.sight.clear(t, spot_tile))
	passer.global_position = at(m, far_tile)
	passer.facing_degrees = rad_to_deg(Vector2(spot_tile - far_tile).angle())
	await wait(0.4)
	ok(passer.mood == Guard.Mood.PATROLLING, "seen from four tiles off, it passes for a hiding spot")
	passer.global_position = at(m, post)
	passer.facing_degrees = 0.0
	var noticed = await until(func(): return passer.mood == Guard.Mood.INVESTIGATING, 1.0)
	ok(noticed, "two tiles off, he notices the boot sticking out")
	var found = await until(func(): return passer.mood == Guard.Mood.WAKING, 8.0)
	ok(found and watch.alert_floor > 0.0, "he looks, and finds him - the map up a level for good")
	var up = await until(func(): return not body.knocked_out, 10.0)
	ok(up and spot.is_free() and not watch.is_stashed(body), "and pulls him out, and brings him round")
	await close_map(m)


## Thrown from a hiding spot somebody has in view, the throw gives him away;
## from one nobody is looking at, it does not.
func thrown_from_hiding():
	var m = await open_map()
	var post: Vector2i = m.post
	var spot_tile = post + Vector2i.RIGHT * 4
	add_spot(m, spot_tile)
	var looker = add_guard(m, "Looker", post, 0.0)
	Campaign.give_item(m.leader, "pebble")
	var watch = await watch_it(m, spot_tile)
	log_line("======== thrown from hiding, in view ========")
	await wait(0.3)
	ok(watch.leader_hiding() and watch.suspicion[looker] == 0.0, "hidden in the spot, he is not seen")
	ok(watch.throw_watchers() == [looker], "but a throw from here would be")
	watch.begin_throw()
	ok(watch.throw_at(post + Vector2i.RIGHT * 2) and watch.spotted_by == looker, "thrown: he is seen doing it, and known")
	await close_map(m)

	log_line("======== thrown from hiding, unseen ========")
	m = await open_map()
	post = m.post
	spot_tile = post + Vector2i.RIGHT * 4
	add_spot(m, spot_tile)
	var away = add_guard(m, "LookingAway", post, 180.0)
	Campaign.give_item(m.leader, "pebble")
	watch = await watch_it(m, spot_tile)
	ok(watch.throw_watchers().is_empty(), "nobody looking at the spot")
	watch.begin_throw()
	ok(watch.throw_at(post + Vector2i.RIGHT * 2) and watch.spotted_by == null, "the throw goes unseen")
	ok(away.mood == Guard.Mood.INVESTIGATING, "and does what a pebble does")
	await close_map(m)
