extends Node
## The stealth kit: throwing things, listening through walls, hiding spots,
## taking guards down and robbing them, the map's alert, dogs, wards and
## captains, who joins a fight and when, talking past a checkpoint, the ghost
## bonus - and combat bringing late arrivals in at the top of their round.

var LOG_PATH := HarnessLog.path_for("stealthkit")
const MAP := "res://scenes/explore_crossroads.tscn"
const TERRAIN := "res://scenes/crossroads_terrain.tscn"
const TALK := "res://Dialogue/stealth_stages.dialogue"
const BALLOON := "res://ui/dialogue_balloon.tscn"
const NOWHERE := Vector2i(-99999, -99999)

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
	get_tree().create_timer(240.0, true, false, true).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


func wait(seconds: float):
	await get_tree().create_timer(seconds).timeout


## Waits up to `seconds` for `condition` to hold. True if it did.
func until(condition: Callable, seconds: float) -> bool:
	var waited := 0.0
	while waited < seconds:
		if condition.call():
			return true
		await get_tree().process_frame
		waited += get_process_delta_time()
	return condition.call()


func run_test():
	await stealth_only_items()
	await throwing()
	await listening()
	await hiding()
	await takedowns()
	await takedown_heard()
	await bodies()
	await caught_red_handed()
	await vaulting()
	await back_after_a_fight()
	await alert_effects()
	await dogs()
	await wards()
	await who_joins()
	await questioning()
	await ghost()
	await disguise_exposed()
	await arriving_late()
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


## --- The map every section is played on ---


## A fresh crossroads with a StealthSetup on it and nobody watching yet. Put
## guards and hiding spots on it, then watch_it().
func open_map() -> Dictionary:
	Campaign.reset()
	Campaign.current_map = MAP
	var scene: ExplorationScene = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(scene)
	await settle(4)
	scene.end_blocking_interaction()
	var m := {}
	m.scene = scene
	m.map = scene.get_node("Map")
	m.tile_map = scene._tile_map
	m.sight = StealthSight.new(m.tile_map)
	m.party = scene.party
	m.leader = Campaign.party_members()[0].key
	m.post = find_post(m, m.tile_map.local_to_map(m.party.position_of_leader()))
	var setup := StealthSetup.new()
	setup.battle_terrain = load(TERRAIN)
	m.map.add_child(setup)
	m.setup = setup
	return m


func watch_it(m: Dictionary, party_tile: Vector2i) -> StealthWatch:
	m.party.teleport(at(m, party_tile))
	m.scene.begin_stealth()
	var watch: StealthWatch = m.scene.stealth
	watch.leave_for_battle = false
	m.away = party_tile
	await settle()
	return watch


func close_map(m: Dictionary):
	for node in get_tree().root.find_children("*", "", true, false):
		if node.scene_file_path == BALLOON:
			node.queue_free()
	m.scene.queue_free()
	await settle()
	Engine.time_scale = 1.0
	log_line("")


func at(m: Dictionary, tile: Vector2i) -> Vector2:
	return m.tile_map.to_global(m.tile_map.map_to_local(tile))


func add_guard(m: Dictionary, called: String, tile: Vector2i, facing: float = 0.0, key: String = "barbarian") -> Guard:
	var guard := Guard.new()
	guard.name = called
	guard.display_name = called
	guard.combatant_key = key
	guard.level = 2
	guard.facing_degrees = facing
	guard.looks_around = false
	m.map.add_child(guard)
	guard.global_position = at(m, tile)
	return guard


func add_spot(m: Dictionary, tile: Vector2i) -> HidingSpot:
	var spot := HidingSpot.new()
	m.map.add_child(spot)
	spot.global_position = at(m, tile)
	return spot


## Back to calm: nobody sure of anything, on their post and looking along it.
func settle_guard(watch: StealthWatch, guard: Guard, facing: float = 0.0):
	watch.suspicion[guard] = 0.0
	guard.mood = Guard.Mood.PATROLLING
	guard.facing_degrees = facing


## A click on the map at `where`, a world position, as the watch hears it.
func click(watch: StealthWatch, where: Vector2, button: MouseButton):
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.position = watch.get_canvas_transform() * where
	watch._unhandled_input(event)


func press(bar: StealthBar, keycode: Key):
	var key := InputEventKey.new()
	key.physical_keycode = keycode
	key.pressed = true
	bar._unhandled_key_input(key)


func standable(m: Dictionary, tile: Vector2i) -> bool:
	return m.scene.is_walkable(at(m, tile))


func gap(a: Vector2i, b: Vector2i) -> float:
	return Vector2(b - a).length()


## The first tile anybody can stand on that `wanted` says yes to.
func find_tile(m: Dictionary, wanted: Callable) -> Vector2i:
	var region: Rect2i = m.sight.region()
	for x in range(region.position.x, region.end.x):
		for y in range(region.position.y, region.end.y):
			var tile := Vector2i(x, y)
			if standable(m, tile) and wanted.call(tile):
				return tile
	return NOWHERE


## Somewhere none of `from` has a line to, and well away from all of them -
## out of sight, earshot and smell.
func out_of_sight_of(m: Dictionary, from: Array) -> Vector2i:
	var region: Rect2i = m.sight.region()
	for x in range(region.position.x, region.end.x):
		for y in range(region.position.y, region.end.y):
			var tile := Vector2i(x, y)
			if not standable(m, tile):
				continue
			var hidden := true
			for other in from:
				if gap(tile, other) < 6.0 or m.sight.clear(other, tile):
					hidden = false
					break
			if hidden:
				return tile
	return NOWHERE


## The guard's post and the tiles along the line they look down, either side.
func row(post: Vector2i) -> Array:
	var tiles := []
	for dx in range(-3, 9):
		tiles.append(post + Vector2i(dx, 0))
	return tiles


## A tile right behind somebody at `post` facing right, within reach.
func behind(m: Dictionary, post: Vector2i) -> Vector2i:
	for tile in [post + Vector2i.LEFT, post + Vector2i(-1, -1), post + Vector2i(-1, 1)]:
		if standable(m, tile):
			return tile
	return NOWHERE


## Somewhere a guard can stand and look right down four open tiles, with a
## free tile two behind them, near where the party arrived.
func find_post(m: Dictionary, start_tile: Vector2i) -> Vector2i:
	var frontier := [start_tile]
	var visited := {start_tile: true}
	while not frontier.is_empty():
		var tile: Vector2i = frontier.pop_front()
		var fits = standable(m, tile) and standable(m, tile + Vector2i.LEFT * 2) and standable(m, tile + Vector2i.LEFT)
		for step in range(1, 5):
			fits = fits and standable(m, tile + Vector2i.RIGHT * step)
		if fits and m.sight.clear(tile, tile + Vector2i.RIGHT * 4) and m.sight.clear(tile + Vector2i.LEFT * 2, tile + Vector2i.RIGHT * 4) \
				and tile.distance_to(start_tile) >= 3:
			return tile
		for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = tile + d
			if not visited.has(next) and m.sight.region().has_point(next) and standable(m, next):
				visited[next] = true
				frontier.append(next)
	return NOWHERE


## How full `guard`'s meter gets in a fifth of a second of somebody standing
## on `tile`, with the map `alert` on edge. Everything put back after.
func fill_over(m: Dictionary, watch: StealthWatch, guard: Guard, tile: Vector2i, alert: float) -> float:
	watch.alert = alert
	m.party.teleport(at(m, tile))
	settle_guard(watch, guard)
	await wait(0.2)
	var filled: float = watch.suspicion[guard]
	m.party.teleport(at(m, m.away))
	settle_guard(watch, guard)
	await settle()
	settle_guard(watch, guard)
	return filled


## display name -> the round they arrive on, for the guards in `fight`.
func arrivals(fight: EncounterDefinition) -> Dictionary:
	var rounds := {}
	for spawn in fight.spawns:
		if spawn.side == 1:
			rounds[spawn.display_name] = spawn.arrives_on_round
	return rounds


## --- The sections ---


func stealth_only_items():
	log_line("======== things for sneaking stay out of fights ========")
	Campaign.reset()
	Campaign.seed_party(["cyrus"])
	var pebble: ItemDefinition = ItemDatabase.item("pebble")
	var robes: ItemDefinition = ItemDatabase.item("priest_robes")
	ok(pebble != null and pebble.is_distraction() and pebble.distraction_radius > 0.0, "a Pebble is something to throw",
		"heard %d tiles off" % (pebble.distraction_radius if pebble else 0))
	ok(pebble.stealth_only() and robes.stealth_only(), "it and a disguise are both for a stealth map only")
	for key in ["pebble", "priest_robes", "tiny_bomb"]:
		Campaign.give_item("cyrus", key)
	ok(Campaign.distractions_of("cyrus") == ["pebble"], "carried, it is something to throw", "%s" % [Campaign.distractions_of("cyrus")])
	var in_a_fight = Campaign.combat_items_of("cyrus")
	ok(not in_a_fight.has("pebble") and not in_a_fight.has("priest_robes") and in_a_fight.has("tiny_bomb"),
		"never offered in a fight, where a bomb still is", "%s" % [in_a_fight])
	log_line("")


func throwing():
	var m = await open_map()
	var post: Vector2i = m.post
	var pebble: ItemDefinition = ItemDatabase.item("pebble")
	var guard = add_guard(m, "Listener", post, 0.0)
	guard.walk_speed_tiles = 6.0
	guard.search_seconds = 0.3
	var from: Vector2i = post + Vector2i.LEFT * 2
	var landing: Vector2i = post + Vector2i.RIGHT * 3
	var far_tile = find_tile(m, func(t): return gap(t, landing) > pebble.distraction_radius + 2.0 and gap(t, from) > 6.0 and not m.sight.clear(t, from))
	var far = add_guard(m, "FarOff", far_tile, 0.0)
	Campaign.give_item(m.leader, "pebble")
	Campaign.give_item(m.leader, "pebble")
	var watch = await watch_it(m, from)
	var bar: StealthBar = watch._bar
	var away = out_of_sight_of(m, row(post) + [far_tile])
	m.away = away
	await settle()

	log_line("======== T: throw something to make a noise ========")
	ok(far_tile != NOWHERE and away != NOWHERE, "(a guard out of earshot, and somewhere out of everybody's way)", "%s, %s" % [far_tile, away])
	ok(watch.throwable() == "pebble", "carrying pebbles, there is something to throw")
	ok(bar._throw.visible and bar._throw.text == "Throw Pebble x2 (T)", "the bar offers it, with how many", bar._throw.text)
	ok(watch.can_throw_to(landing), "three tiles in front of the guard, in a clear line from behind him, it can land")
	var wall = find_tile_or_wall(m, from, true)
	ok(wall != NOWHERE and not watch.can_throw_to(wall), "not on a wall", "%s" % wall)
	var blocked = find_tile(m, func(t): return gap(t, from) <= StealthWatch.THROW_TILES and not m.sight.clear(from, t))
	ok(blocked == NOWHERE or not watch.can_throw_to(blocked), "nor round a corner", "%s" % blocked)
	var too_far = find_tile(m, func(t): return gap(t, from) > StealthWatch.THROW_TILES + 0.5 and m.sight.clear(from, t))
	ok(too_far == NOWHERE or not watch.can_throw_to(too_far), "nor further than %d tiles, even in a clear line" % StealthWatch.THROW_TILES,
		"%s" % too_far)
	m.scene.begin_blocking_interaction()
	press(bar, KEY_T)
	ok(not watch.is_aiming(), "mid-conversation, T does nothing")
	m.scene.end_blocking_interaction()
	press(bar, KEY_T)
	ok(watch.is_aiming(), "T starts aiming")
	await settle()
	ok(bar._throw.text == "Aiming Pebble - click", "the bar says to click where", bar._throw.text)
	watch.cancel_throw()
	ok(not watch.is_aiming(), "and it can be called off")
	press(bar, KEY_T)
	click(watch, at(m, wall), MOUSE_BUTTON_LEFT)
	ok(watch.is_aiming() and Campaign.count_of(m.leader, "pebble") == 2,
		"a click where it cannot land throws nothing, and he is still aiming")

	log_line("======== it lands, and a guard goes to look ========")
	click(watch, at(m, landing), MOUSE_BUTTON_LEFT)
	ok(Campaign.count_of(m.leader, "pebble") == 1, "a click where it can, throws it")
	ok(not watch.is_aiming() and Campaign.count_of(m.leader, "pebble") == 1, "one fewer in the bag")
	ok(not watch._ripples.is_empty(), "a ring on the ground shows how far the sound carried")
	ok(guard.mood == Guard.Mood.INVESTIGATING and guard.last_seen.distance_to(at(m, landing)) < 1.0,
		"the guard within %d tiles of it goes to see" % pebble.distraction_radius, Guard.Mood.keys()[guard.mood])
	ok(far.mood == Guard.Mood.PATROLLING, "the one out of earshot hears nothing", Guard.Mood.keys()[far.mood])
	m.party.teleport(at(m, away))
	var got_there = await until(func(): return guard.mood == Guard.Mood.SEARCHING, 3.0)
	ok(got_there and guard.global_position.distance_to(at(m, landing)) < Grid.tiles(0.6), "he walks over and looks about")
	ok(watch.alert == 0.0 and watch.never_noticed(), "a noise is not a sighting: the map is no more on edge, and nobody has noticed him")
	Campaign.take_item(m.leader, "pebble")
	await settle()
	ok(watch.throwable() == "" and not watch.begin_throw() and not bar._throw.visible, "with nothing left to throw, there is no throwing")
	await close_map(m)


## A tile near `from` that stops sight - a wall - when `wall` is set.
func find_tile_or_wall(m: Dictionary, from: Vector2i, wall: bool) -> Vector2i:
	for r in range(1, int(StealthWatch.THROW_TILES)):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var tile = from + Vector2i(dx, dy)
				if m.sight.region().has_point(tile) and m.sight.stops_sight(tile) == wall:
					return tile
	return NOWHERE


func listening():
	var m = await open_map()
	var post: Vector2i = m.post
	m.setup.guards_seen_only_in_sight = true
	var guard = add_guard(m, "Unseen", post, 0.0)
	var hidden_from = out_of_sight_of(m, row(post))
	var watch = await watch_it(m, hidden_from)
	var bar: StealthBar = watch._bar
	await settle()

	log_line("======== a map that hides its guards ========")
	ok(hidden_from != NOWHERE, "(somewhere with walls between him and the guard)", "%s" % hidden_from)
	ok(not watch.guard_shown(guard) and not guard.visible, "a guard he has no line to is not drawn")
	ok(watch.seen_tiles().is_empty(), "nor what they are looking at")
	ok(bar._ears.visible and bar._ears.text == "Ears (Q)" and not bar._ears.disabled, "and the bar offers to listen", bar._ears.text)

	log_line("======== Q: listening through the walls ========")
	press(bar, KEY_Q)
	ok(watch.ears_left() > StealthWatch.EARS_SECONDS - 0.2, "Q listens, for %d seconds" % StealthWatch.EARS_SECONDS)
	await settle()
	ok(guard.visible and not watch.seen_tiles().is_empty(), "every guard heard, walls or not - and where they look")
	ok(bar._ears.disabled and bar._ears.text.begins_with("Listening"), "the bar counts it down", bar._ears.text)
	ok(not watch.listen(), "not twice at once")
	# Worn off, the way the clock would have it.
	watch._ears_left = 0.0
	watch._ears_cooldown -= StealthWatch.EARS_SECONDS
	await settle()
	ok(not guard.visible, "when it wears off, gone again")
	ok(watch.ears_cooldown() > StealthWatch.EARS_COOLDOWN - 0.2 and not watch.listen() and bar._ears.disabled and bar._ears.text.begins_with("Ears "),
		"and not again for %d seconds from then" % StealthWatch.EARS_COOLDOWN, bar._ears.text)

	log_line("======== seen when he could see them ========")
	var behind_him = find_tile(m, func(t): return m.sight.clear(t, post) and (t - post).x <= -2 and absi((t - post).y) <= -(t - post).x and gap(t, post) < 6.0)
	ok(behind_him != NOWHERE, "(somewhere behind the guard in a clear line)", "%s" % behind_him)
	m.party.teleport(at(m, behind_him))
	await settle()
	ok(guard.visible and watch.suspicion[guard] == 0.0, "in a line with him, behind him: drawn - and he none the wiser")
	m.party.teleport(at(m, hidden_from))
	await settle()
	watch.suspicion[guard] = 0.4
	ok(watch.guard_shown(guard), "and a guard growing sure of him is drawn wherever they are")
	watch.suspicion[guard] = 0.0
	m.setup.guards_seen_only_in_sight = false
	await settle()
	ok(guard.visible and not watch.listen() and not bar._ears.visible, "on a map that shows its guards there is nothing to listen for")
	await close_map(m)


func hiding():
	var m = await open_map()
	var post: Vector2i = m.post
	var guard = add_guard(m, "Looker", post, 0.0)
	var spot_far: Vector2i = post + Vector2i.RIGHT * 3
	var spot_near: Vector2i = post + Vector2i.RIGHT
	add_spot(m, spot_far)
	add_spot(m, spot_near)
	var watch = await watch_it(m, out_of_sight_of(m, row(post)))
	var bar: StealthBar = watch._bar

	log_line("======== a hiding spot ========")
	m.party.teleport(at(m, spot_far))
	await wait(0.3)
	ok(watch.suspicion[guard] == 0.0, "tucked into one three tiles in front of a guard, he is not seen", "%.2f" % watch.suspicion[guard])
	ok(watch.leader_hiding() and bar._status.text == "Hidden", "the bar says Hidden", bar._status.text)
	ok(m.party.leader.hidden_alpha == StealthWatch.HIDDEN_ALPHA, "and he is drawn fainter still", "%.2f" % m.party.leader.hidden_alpha)
	m.party.teleport(at(m, post + Vector2i.RIGHT * 2))
	await wait(0.15)
	ok(watch.suspicion[guard] > 0.0 and bar._status.text == "Sneaking", "a step out of it, he is", "%.2f" % watch.suspicion[guard])
	settle_guard(watch, guard)
	m.party.teleport(at(m, spot_near))
	await wait(0.15)
	ok(watch.suspicion[guard] > 0.0, "and one right beside a guard hides nobody", "%.2f" % watch.suspicion[guard])
	m.party.teleport(at(m, m.away))
	settle_guard(watch, guard)
	await settle()
	settle_guard(watch, guard)

	log_line("======== hunting for him, a guard looks behind the barrels ========")
	# Rooted to the spot, so it is his eyes that find him and not his feet.
	guard.walk_speed_tiles = 0.0
	# Sent by a noise near the spot: no reason to look behind anything.
	guard.hear(at(m, spot_far + Vector2i.UP), true)
	m.party.teleport(at(m, spot_far))
	await wait(0.2)
	ok(guard.mood == Guard.Mood.INVESTIGATING and not guard.is_hunting() and watch.suspicion[guard] == 0.0,
		"looking into a noise, he walks right past a hiding spot", "%.2f" % watch.suspicion[guard])
	# Having seen somebody there, and lost them.
	m.party.teleport(at(m, m.away))
	settle_guard(watch, guard)
	guard.mood = Guard.Mood.WATCHING
	guard.last_seen = at(m, spot_far + Vector2i.RIGHT * 2)
	guard.doubt_gone()
	ok(guard.is_hunting(), "going to look for somebody he saw, he is hunting")
	m.party.teleport(at(m, spot_far))
	await wait(0.2)
	ok(watch.suspicion[guard] > 0.1, "and sees into a hiding spot within %d tiles of where he saw them" % StealthWatch.SEARCH_SPOTS_TILES,
		"%.2f" % watch.suspicion[guard])
	m.party.teleport(at(m, m.away))
	settle_guard(watch, guard)
	guard.mood = Guard.Mood.WATCHING
	guard.last_seen = at(m, spot_far + Vector2i.RIGHT * 5)
	guard.doubt_gone()
	m.party.teleport(at(m, spot_far))
	await wait(0.2)
	ok(guard.is_hunting() and watch.suspicion[guard] == 0.0, "but not one further off than that", "%.2f" % watch.suspicion[guard])
	m.party.teleport(at(m, m.away))
	settle_guard(watch, guard)
	guard.hunting = false
	await settle()
	settle_guard(watch, guard)
	guard.kind = Guard.Kind.DOG
	m.party.teleport(at(m, spot_far))
	await wait(0.15)
	ok(watch.suspicion[guard] > 0.0, "a dog's nose finds him in one anyway", "%.2f" % watch.suspicion[guard])
	await close_map(m)


func takedowns():
	var m = await open_map()
	var post: Vector2i = m.post
	var sentry = add_guard(m, "Sentry", post, 0.0)
	sentry.pockets.assign(["pebble"])
	sentry.picked_flag = "kit_lifted"
	sentry.picked_message = "a ring of keys"
	var back_of_him = behind(m, post)
	# Somebody to find him once he is down: a clear view of his post, looking
	# the other way to start with.
	var finder_tile = find_tile(m, func(t): return gap(t, post) >= StealthWatch.TAKEDOWN_NOISE_TILES + 1.0 and gap(t, post) <= 8.0 and m.sight.clear(t, post) and t.x > post.x + 1)
	var finder = add_guard(m, "Finder", finder_tile, rad_to_deg(Vector2(finder_tile - post).angle()))
	var watch = await watch_it(m, out_of_sight_of(m, row(post) + [finder_tile]))
	var bar: StealthBar = watch._bar

	log_line("======== clicks: from behind, unnoticed ========")
	ok(back_of_him != NOWHERE and finder_tile != NOWHERE and m.away != NOWHERE, "(room behind him, and a second guard)")
	# In front of him: asked in the one frame, before he could react.
	m.party.teleport(at(m, post + Vector2i.RIGHT))
	var face_to_face = [watch.takedown_target(), watch.pocket_target()]
	click(watch, sentry.global_position, MOUSE_BUTTON_LEFT)
	click(watch, sentry.global_position, MOUSE_BUTTON_RIGHT)
	m.party.teleport(at(m, m.away))
	ok(face_to_face == [null, null], "face to face, there is nobody to take down or rob")
	ok(not sentry.knocked_out and not sentry.picked, "and clicking on him does neither")
	await settle()
	m.party.teleport(at(m, back_of_him))
	await settle(2)
	ok(watch.suspicion[sentry] == 0.0, "behind him, he has no idea")
	ok(watch.takedown_target() == sentry and watch.pocket_target() == sentry, "so he can be taken down, or robbed")
	ok(bar._takedown.visible and bar._pocket.visible, "and the bar offers both")
	var shown = watch.prompt()
	ok(not shown.is_empty() and shown[0] == sentry and shown[1] == [["Left click", "Take down", true], ["Right click", "Pick pocket", true], ["F", "Ambush", true]],
		"a prompt over him says which click does which - and that F springs a fight on him", "%s" % [shown[1] if not shown.is_empty() else "none"])
	await settle()
	var prompt: Control = watch._prompt
	var his_head = watch.get_viewport().get_canvas_transform() * sentry.global_position
	ok(prompt.visible and prompt.position.y + prompt.size.y < his_head.y and absf(prompt.position.x + prompt.size.x / 2.0 - his_head.x) < 2.0,
		"right over his head", "%s, his tile at %s" % [prompt.position, his_head])
	sentry.mood = Guard.Mood.WATCHING
	ok(watch.takedown_target() == null, "not while he is watching somebody")
	sentry.mood = Guard.Mood.PATROLLING
	sentry.can_be_taken_down = false
	ok(watch.takedown_target() == null and watch.pocket_target() == sentry, "nor if he is one who cannot be - his pockets still can")
	shown = watch.prompt()
	ok(not shown.is_empty() and shown[1][0] == ["Left click", "Can't be taken down", false],
		"and the prompt says so, rather than saying nothing", "%s" % [shown[1] if not shown.is_empty() else "none"])
	sentry.can_be_taken_down = true
	press(bar, KEY_G)
	ok(not sentry.knocked_out and not sentry.picked, "G is nothing now - it is the mouse")
	ok(watch.ambush_target() == sentry, "(and F is an ambush now, not a takedown)")
	var had = Campaign.count_of(m.leader, "pebble")
	click(watch, sentry.global_position, MOUSE_BUTTON_RIGHT)
	ok(Campaign.count_of(m.leader, "pebble") == had + 1 and not sentry.knocked_out, "a right click on him lifts what is in his pockets")
	ok(sentry.picked and Campaign.flag("kit_lifted"), "and sets the flag that says so")
	ok(watch.pocket_target() == null, "once")
	ok(watch.suspicion[sentry] == 0.0 and sentry.mood == Guard.Mood.PATROLLING, "without his noticing")
	await settle()
	ok(not bar._pocket.visible, "and the button goes")

	log_line("======== left click: out cold ========")
	# Not on him, but on the ground at his back: he is the only one it can mean.
	click(watch, at(m, back_of_him), MOUSE_BUTTON_LEFT)
	ok(sentry.knocked_out and watch.body_unfound(sentry), "a left click - anywhere, with him the only one - knocks him out, lying where he stood")
	ok(watch.takedown_target() == null, "nobody to knock out twice")
	m.party.teleport(at(m, post + Vector2i.RIGHT * 2))
	await wait(0.3)
	ok(watch.suspicion[sentry] == 0.0, "stand right in front of him and he sees nothing")
	var names = arrivals(watch.build_fight()).keys()
	ok(not names.has("Sentry") and names.has("Finder"), "and if it comes to a fight, he is not in it", "%s" % [names])

	log_line("======== found ========")
	m.party.teleport(at(m, m.away))
	settle_guard(watch, finder, rad_to_deg(Vector2(finder_tile - post).angle()))
	await settle()
	ok(watch.body_unfound(sentry) and watch.alert == 0.0, "nobody has seen him lying there yet")
	finder.facing_degrees = rad_to_deg(Vector2(post - finder_tile).angle())
	var found = await until(func(): return not watch.body_unfound(sentry), 1.0)
	ok(found, "a guard whose view falls on him finds him")
	ok(watch.alert_level() == "Wary" and watch.alert_floor == StealthWatch.ALERT_WARY,
		"and the alert goes a level up, pinned there", "%.2f, floor %.2f" % [watch.alert, watch.alert_floor])
	ok(finder.mood == Guard.Mood.WAKING and finder.errand_at().distance_to(sentry.global_position) < 1.0, "and goes to bring him round")
	await settle()
	ok(bar._alert.text == "Wary", "the bar says so", bar._alert.text)
	ok(sentry.knocked_out, "down until then")
	var woken = await until(func(): return not sentry.knocked_out, 14.0)
	ok(woken and watch.body_unfound(sentry) == false and not watch._bodies.has(sentry), "and brought round, he is up again")
	ok(sentry.mood == Guard.Mood.RETURNING or sentry.mood == Guard.Mood.PATROLLING, "and back to his post",
		"%s" % Guard.Mood.keys()[sentry.mood])
	ok(watch.alert_level() == "Wary", "the alert where the find put it", "%.2f" % watch.alert)
	await close_map(m)


## A takedown is heard: anybody near enough comes to look, and nobody further.
func takedown_heard():
	var m = await open_map()
	var post: Vector2i = m.post
	var sentry = add_guard(m, "Sentry", post, 0.0)
	var back_of_him = behind(m, post)
	var near_tile = find_tile(m, func(t): return t != back_of_him and gap(t, post) >= 1.5 and gap(t, post) <= StealthWatch.TAKEDOWN_NOISE_TILES - 0.5)
	# Looking away from where the party will be, so he hears it rather than sees it.
	var near = add_guard(m, "Near", near_tile, rad_to_deg(Vector2(near_tile - back_of_him).angle()))
	var far_tile = find_tile(m, func(t): return gap(t, post) > StealthWatch.TAKEDOWN_NOISE_TILES + 2.0 and not m.sight.clear(t, back_of_him))
	var far = add_guard(m, "Far", far_tile, 0.0)
	var watch = await watch_it(m, back_of_him)

	log_line("======== a takedown is heard ========")
	ok(near_tile != NOWHERE and far_tile != NOWHERE, "(a guard within earshot, and one beyond it)", "%s, %s" % [near_tile, far_tile])
	ok(watch.suspicion[near] == 0.0 and watch.suspicion[far] == 0.0, "nobody has noticed him yet")
	ok(watch.take_down(), "down he goes")
	ok(near.mood == Guard.Mood.INVESTIGATING and near.last_seen.distance_to(sentry.global_position) < 1.0,
		"and the guard %.1f tiles off comes to see what that was" % gap(near_tile, post), Guard.Mood.keys()[near.mood])
	ok(far.mood == Guard.Mood.PATROLLING, "the one %.1f tiles off hears nothing" % gap(far_tile, post), Guard.Mood.keys()[far.mood])
	ok(not watch._ripples.is_empty(), "a ring shows how far it carried")
	await close_map(m)


## Bodies: robbed, dragged at half pace, dropped, and hidden for good in a
## hiding spot - which is then no good for hiding in.
func bodies():
	var m = await open_map()
	var post: Vector2i = m.post
	var sentry = add_guard(m, "Sentry", post, 0.0)
	sentry.pockets.assign(["pebble"])
	sentry.picked_flag = "kit_body_lifted"
	var back_of_him = behind(m, post)
	# A hiding spot well away, with room round it.
	var spot_tile = find_tile(m, func(t): return gap(t, post) >= 4.0 and gap(t, post) <= 9.0 and standable(m, t + Vector2i.LEFT) and standable(m, t + Vector2i.RIGHT))
	var spot = add_spot(m, spot_tile)
	var watch = await watch_it(m, back_of_him)
	var bar: StealthBar = watch._bar
	var party = m.party
	ok(spot_tile != NOWHERE, "(a hiding spot some way off)", "%s" % spot_tile)
	watch.take_down()
	await settle()

	log_line("======== a body's pockets ========")
	ok(watch.pocket_target() == sentry and bar._pocket.visible, "out cold, his pockets can be picked")
	var had = Campaign.count_of(m.leader, "pebble")
	click(watch, sentry.global_position, MOUSE_BUTTON_RIGHT)
	ok(Campaign.count_of(m.leader, "pebble") == had + 1 and Campaign.flag("kit_body_lifted"), "a right click on him lifts them")

	log_line("======== dragging ========")
	ok(watch.drag_target() == sentry and bar._drag.visible and bar._drag.text == "Drag body (Left click)", "beside a body, he can pick it up",
		bar._drag.text)
	ok(watch.takedown_target() == null, "and there is nobody to take down - a body is not somebody to hit again")
	click(watch, sentry.global_position, MOUSE_BUTTON_LEFT)
	ok(watch.dragging() == sentry, "a left click on it picks it up")
	ok(party.pace == StealthWatch.DRAG_PACE, "and he walks at %d%% of his pace" % roundi(StealthWatch.DRAG_PACE * 100.0))
	ok(watch.dash_refusal() != "" and not watch.dash(), "no dashing with a body", watch.dash_refusal())
	ok(watch.wear_refusal() != "", "nor changing clothes", watch.wear_refusal())
	await settle()
	ok(bar._dash.disabled and bar._drag.text == "Drop body (Left click)", "the bar greys the dash and offers to put it down", bar._drag.text)
	var from = party.leader.global_position
	for i in 20:
		party._step(Vector2.LEFT, 1.0 / 60.0)
	var walked = party.leader.global_position.distance_to(from)
	var usual = party.move_speed * 20.0 / 60.0
	ok(absf(walked - usual * StealthWatch.DRAG_PACE) < 1.0, "a third of a second's walk covers half the usual ground",
		"%.0f px, against %.0f" % [walked, usual])
	await settle()
	var behind_him = sentry.global_position.distance_to(party.leader.global_position)
	ok(absf(behind_him - party.follow_spacing) < 2.0, "the body follows, a place behind him", "%.0f px back" % behind_him)
	ok(watch.body_unfound(sentry), "dragged about, it can still be found")

	log_line("======== dropped ========")
	click(watch, party.leader.global_position, MOUSE_BUTTON_LEFT)
	ok(watch.dragging() == null and party.pace == 1.0, "a left click puts it down, and he walks at his own pace again")
	var lies_at = sentry.global_position
	party._step(Vector2.LEFT, 1.0 / 60.0)
	await settle()
	ok(sentry.global_position == lies_at and not watch.is_stashed(sentry), "it stays where it was put down")
	click(watch, sentry.global_position, MOUSE_BUTTON_LEFT)
	ok(watch.dragging() == sentry, "and can be picked up again")

	log_line("======== hidden for good ========")
	party.teleport(at(m, spot_tile))
	await settle()
	ok(watch.leader_hiding() and watch.stash_spot() == spot, "standing at a free hiding spot, it is somewhere to put him")
	ok(bar._drag.text == "Hide body (Left click)", "the bar offers to hide him", bar._drag.text)
	var shown = watch.prompt()
	ok(not shown.is_empty() and shown[0] == spot and shown[1] == [["Left click", "Hide the body here", true]],
		"and the prompt hangs over the spot", "%s" % [shown[1] if not shown.is_empty() else "none"])
	click(watch, at(m, spot_tile + Vector2i.RIGHT), MOUSE_BUTTON_LEFT)
	ok(watch.is_stashed(sentry) and spot.holds_body == sentry and watch.dragging() == null, "a left click stuffs him into it")
	await settle()
	ok(not sentry.visible and not watch.guard_shown(sentry), "out of sight")
	ok(not watch.body_unfound(sentry), "where no guard will ever find him")
	ok(not spot.is_free() and not watch.leader_hiding(), "and nobody can hide there any more - not even him, standing in it")
	ok(watch.stash_spot() == null and watch.drag_target() == null and watch.pocket_target() == null,
		"it holds one body, and there is nothing more to do with this one")

	log_line("======== robbed where he is hidden ========")
	# Another pocketful, as though he had not been robbed before he went in.
	sentry.picked = false
	sentry.picked_flag = "kit_stashed_lifted"
	ok(watch.pocket_target() == sentry, "a body in a hiding spot can still have its pockets picked, from beside it")
	shown = watch.prompt()
	ok(not shown.is_empty() and shown[0] == sentry and shown[1] == [["Right click", "Pick pocket", true]], "and the prompt says so",
		"%s" % [shown[1] if not shown.is_empty() else "none"])
	var before = Campaign.count_of(m.leader, "pebble")
	click(watch, at(m, spot_tile), MOUSE_BUTTON_RIGHT)
	ok(Campaign.count_of(m.leader, "pebble") == before + 1 and Campaign.flag("kit_stashed_lifted") and watch.is_stashed(sentry),
		"a right click on the spot lifts them, and he stays hidden")

	log_line("======== found in it, by a guard hunting nearby ========")
	var hunter_tile = find_tile(m, func(t): return gap(t, spot_tile) >= 2.0 and gap(t, spot_tile) <= 5.0 and m.sight.clear(t, spot_tile))
	var hunter := Guard.new()
	hunter.combatant_key = "barbarian"
	m.map.add_child(hunter)
	hunter.global_position = at(m, hunter_tile)
	hunter.facing_degrees = rad_to_deg(Vector2(spot_tile - hunter_tile).angle())
	# Walking by, with no reason to look: nothing.
	watch._refresh_seen(hunter)
	watch._look_for_bodies(hunter)
	ok(watch.alert < 0.5, "a guard glancing at the spot sees nothing in it", "%.2f" % watch.alert)
	# Looking for somebody seen near it: he looks in.
	hunter.last_seen = at(m, spot_tile + Vector2i.RIGHT)
	hunter.hunting = true
	hunter.mood = Guard.Mood.INVESTIGATING
	watch._refresh_seen(hunter)
	watch._look_for_bodies(hunter)
	ok(watch.alert_level() == "Wary" and watch.alert_floor == StealthWatch.ALERT_WARY,
		"one hunting for somebody seen near it looks in and finds him: the alert a level up, and pinned there",
		"%.2f, floor %.2f" % [watch.alert, watch.alert_floor])
	ok(hunter.mood == Guard.Mood.WAKING and hunter.errand_at() == sentry.global_position,
		"and he goes to bring him round", "%s" % Guard.Mood.keys()[hunter.mood])
	await close_map(m)


## Caught and the fight won, the map carries on from where it stood: whoever
## fought is gone, and the rest is as it was left.
func back_after_a_fight():
	var m = await open_map()
	var post: Vector2i = m.post
	var tiles = stage_for_the_fight(m, post)
	log_line("======== back after a won fight ========")
	ok(not tiles.values().has(NOWHERE), "(somewhere for everybody)", "%s" % [tiles])
	if tiles.values().has(NOWHERE):
		await close_map(m)
		return
	put_back_everybody(m, post, tiles)
	m.setup.joins_within_tiles = 3.0
	m.setup.tiles_per_late_round = 0.0
	Campaign.give_item(m.leader, "priest_robes")
	var watch = await watch_it(m, tiles.away)
	var sentry: Guard = m.map.get_node("Sentry")
	var napper: Guard = m.map.get_node("Napper")
	var fighter: Guard = m.map.get_node("Fighter")
	# One lying where he fell, one robbed and stuffed into the hiding spot.
	napper.knock_out()
	watch._bodies[napper] = false
	m.party.teleport(at(m, behind(m, post)))
	await settle()
	ok(watch.take_down() and watch.pick_pocket(), "(one knocked out and robbed)")
	watch._dragging = sentry
	m.party.teleport(at(m, tiles.spot))
	watch.put_down()
	ok(watch.is_stashed(sentry), "(and hidden)")
	watch.wear("priest_robes")
	watch._finish_change()
	watch.raise_alert(0.4)
	var pebbles = Campaign.count_of(m.leader, "pebble")
	# Caught beside the one who will fight, well away from the one who will not.
	m.party.teleport(at(m, tiles.caught))
	watch._caught_by(fighter)
	var state: Dictionary = Campaign.stealth_state.get(MAP, {})
	ok(state.get("fighting", []) == ["Fighter"], "caught, the map remembers who is in the fight", "%s" % [state.get("fighting")])
	Campaign.finish_battle_from_exploration(true, [])
	ok(state.defeated == ["Fighter"], "and, won, who lost it", "%s" % [state.defeated])

	# Walking back in: the same map, the same people on it.
	m.scene.queue_free()
	await settle()
	Engine.time_scale = 1.0
	Campaign.current_map = MAP
	var scene: ExplorationScene = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(scene)
	await settle(4)
	scene.end_blocking_interaction()
	var back := {"scene": scene, "map": scene.get_node("Map"), "tile_map": scene._tile_map, "party": scene.party}
	back.sight = StealthSight.new(back.tile_map)
	var setup := StealthSetup.new()
	setup.battle_terrain = load(TERRAIN)
	back.map.add_child(setup)
	put_back_everybody(back, post, tiles)
	scene.begin_stealth()
	watch = scene.stealth
	watch.leave_for_battle = false
	await settle()
	var names = watch.guards.map(func(g): return String(g.name))
	ok(not names.has("Fighter"), "the guard who fought and lost is not there", "%s" % [names])
	ok(names.has("Faraway") and not watch.guards.filter(func(g): return g.name == "Faraway")[0].knocked_out,
		"the one who never came is, still on watch")
	var napper_back: Guard = back.map.get_node("Napper")
	var sentry_back: Guard = back.map.get_node("Sentry")
	ok(napper_back.knocked_out and watch.body_unfound(napper_back), "the one lying where he fell still lies there, not yet found")
	ok(sentry_back.knocked_out and sentry_back.picked and watch.is_stashed(sentry_back) and not back.map.get_node("Spot").is_free(),
		"the one stuffed into the hiding spot is still in it, and still robbed")
	ok(watch.worn_by(Campaign.party_members()[0].key) == "priest_robes", "still in the robes")
	ok(absf(watch.alert - state.alert) < 0.01 and not watch.never_noticed(), "the map as on edge as it was, and no ghost",
		"%.2f" % watch.alert)
	ok(Campaign.count_of(Campaign.party_members()[0].key, "pebble") == pebbles, "and his bag as it was")
	ok(watch._bar != null and watch._bar.is_inside_tree(), "a stealth map still, bar and all")
	scene.queue_free()
	await settle()
	log_line("")


## Where everybody goes for back_after_a_fight: the one to be caught by, the
## one well away who will not join, one to lie knocked out, the hiding spot, and
## where to be caught and to wait.
func stage_for_the_fight(m: Dictionary, post: Vector2i) -> Dictionary:
	var tiles := {}
	tiles.fighter = find_tile(m, func(t): return gap(t, post) >= StealthWatch.TAKEDOWN_NOISE_TILES + 1.0 and gap(t, post) <= 8.0 and standable(m, t + Vector2i.RIGHT))
	tiles.caught = tiles.fighter + Vector2i.RIGHT
	tiles.faraway = find_tile(m, func(t): return gap(t, tiles.caught) > 8.5 and gap(t, post) > StealthWatch.TAKEDOWN_NOISE_TILES + 1.0)
	# Lying where neither of the two left standing could see him.
	tiles.napper = find_tile(m, func(t): return gap(t, post) > StealthWatch.TAKEDOWN_NOISE_TILES + 1.0 and t != tiles.caught and not m.sight.clear(tiles.fighter, t) and not m.sight.clear(tiles.faraway, t))
	tiles.spot = find_tile(m, func(t): return gap(t, post) >= 2.0 and gap(t, post) <= 5.0 and t.x < post.x)
	tiles.away = out_of_sight_of(m, row(post) + [tiles.fighter, tiles.faraway])
	return tiles


## The guards and the hiding spot for back_after_a_fight, on `m`'s map: the
## same names on the same tiles every time the map is built.
func put_back_everybody(m: Dictionary, post: Vector2i, tiles: Dictionary):
	var sentry = add_guard(m, "Sentry", post, 0.0)
	sentry.pockets.assign(["pebble"])
	add_guard(m, "Napper", tiles.napper, 0.0)
	# Both looking away from the sentry's post, where all this happens.
	add_guard(m, "Fighter", tiles.fighter, rad_to_deg(Vector2(tiles.fighter - post).angle()))
	add_guard(m, "Faraway", tiles.faraway, rad_to_deg(Vector2(tiles.faraway - post).angle()))
	var spot = add_spot(m, tiles.spot)
	spot.name = "Spot"


## Seen dragging a body or changing clothes, he is known at once - no meter.
func caught_red_handed():
	var m = await open_map()
	var post: Vector2i = m.post
	var guard = add_guard(m, "Sharp", post, 0.0)
	Campaign.give_item(m.leader, "priest_robes")
	var watch = await watch_it(m, out_of_sight_of(m, row(post)))

	log_line("======== seen dragging a body ========")
	# A body to be dragging: put on the map after the watch began, so it is
	# nobody the watch knows to find.
	var body := Guard.new()
	body.combatant_key = "barbarian"
	m.map.add_child(body)
	body.global_position = at(m, m.away)
	body.knock_out()
	watch._dragging = body
	watch._drag_path = [body.global_position]
	ok(watch.caught_red_handed(), "dragging a body is being caught red-handed")
	# Far off, where a meter would take its time.
	m.party.teleport(at(m, post + Vector2i.RIGHT * 4))
	await settle(2)
	ok(watch.spotted_by == guard, "a guard who sees him at it is sure of him on the spot", "%.2f" % watch.suspicion[guard])
	await close_map(m)

	m = await open_map()
	post = m.post
	guard = add_guard(m, "Sharp", post, 0.0)
	# One who takes the robes at face value - once they are on.
	guard.recognises = Guard.Recognises.NO_DISGUISE
	Campaign.give_item(m.leader, "priest_robes")
	watch = await watch_it(m, out_of_sight_of(m, row(post)))
	log_line("======== seen changing clothes ========")
	watch.wear("priest_robes")
	ok(watch.caught_red_handed(), "so is changing into a disguise")
	m.party.teleport(at(m, post + Vector2i.RIGHT * 4))
	await settle(2)
	ok(watch.spotted_by == guard, "seen at it, he is known at once - even by one the robes would fool", "%.2f" % watch.suspicion[guard])
	ok(watch.changing_into() == "" and watch.worn_by(m.leader) == "", "and never gets them on")
	await close_map(m)


## V: over a barrel to the free tile beyond - not over a wall, and not onto
## something in the way. On stage 1, where there are barrels to try.
func vaulting():
	Campaign.reset()
	Campaign.current_map = "res://stages/stealth_1.tscn"
	var scene: ExplorationScene = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(scene)
	await settle(4)
	scene.end_blocking_interaction()
	var watch: StealthWatch = scene.stealth
	watch.leave_for_battle = false
	# Nobody watching: this is about the hop, not about being seen making it.
	watch.set_process(false)
	var m := {"scene": scene, "tile_map": scene._tile_map, "party": scene.party}
	var bar: StealthBar = watch._bar

	log_line("======== V: vaulting ========")
	ok(watch.is_cover(Vector2i(28, 5)), "a barrel is something to vault: in the way on foot, clear in the air")
	ok(not watch.is_cover(Vector2i(0, 0)), "a wall is not: it stops fliers too")
	m.party.teleport(at(m, Vector2i(27, 5)))
	m.party._set_facing(false)
	await settle()
	ok(watch.vault_over() == [Vector2i(28, 5), Vector2i(29, 5)], "beside one, with floor straight across it, he can go over",
		"%s" % [watch.vault_over()])
	ok(bar._vault.visible, "and the bar offers it")
	var shown = watch.prompt()
	ok(not shown.is_empty() and shown[1] == [["V", "Vault over", true]] and shown[0] == at(m, Vector2i(28, 5)),
		"the prompt hangs over the barrel", "%s" % [shown[1] if not shown.is_empty() else "none"])
	press(bar, KEY_V)
	ok(m.party.vaulting, "V hops")
	await wait(StealthWatch.VAULT_SECONDS + 0.15)
	var landed = m.tile_map.local_to_map(m.tile_map.to_local(m.party.leader.global_position))
	ok(not m.party.vaulting and landed == Vector2i(29, 5), "and he lands on the far side", "%s" % landed)
	# Two barrels one behind the other: nowhere to land.
	m.party.teleport(at(m, Vector2i(25, 5)))
	await settle()
	var over = watch.vault_over()
	ok(not over.has(Vector2i(25, 6)), "not over a barrel with another right behind it", "%s" % [over])
	# Nor with his hands full.
	m.party.teleport(at(m, Vector2i(27, 5)))
	watch._dragging = watch.guards[0]
	ok(watch.vault_over().is_empty() and watch.vault_refusal() != "" and not watch.vault(), "nor dragging a body", watch.vault_refusal())
	watch._dragging = null
	scene.queue_free()
	await settle()
	log_line("")


func alert_effects():
	var m = await open_map()
	var post: Vector2i = m.post
	var guard = add_guard(m, "Edgy", post, 0.0)
	var watch = await watch_it(m, out_of_sight_of(m, row(post)))

	log_line("======== the map's alert ========")
	ok(watch.alert_level() == "Calm" and guard.half_cone() == Guard.HALF_CONE and guard.alert_pace == 0.0, "calm, to begin with")
	watch.raise_alert(0.5)
	await settle()
	ok(watch.alert_level() == "Wary", "half way up it is Wary")
	ok(is_equal_approx(guard.alert_pace, StealthWatch.ALERT_PACE * 0.5), "every guard walks quicker",
		"+%d%%" % roundi(guard.alert_pace * 100.0))
	ok(guard.alert_cone == snappedf(StealthWatch.ALERT_CONE * 0.5, StealthWatch.FACING_STEP_DEGREES) and guard.half_cone() == Guard.HALF_CONE + guard.alert_cone,
		"and looks wider", "%d either side" % guard.half_cone())
	watch.raise_alert(5.0)
	await settle()
	ok(watch.alert == 1.0 and watch.alert_level() == "Alarmed", "no higher than all the way", "%.2f" % watch.alert)
	ok(guard.half_cone() == Guard.HALF_CONE + StealthWatch.ALERT_CONE, "%d degrees wider either side, at the top" % StealthWatch.ALERT_CONE)
	var calm = await fill_over(m, watch, guard, post + Vector2i.RIGHT * 3, 0.0)
	var alarmed = await fill_over(m, watch, guard, post + Vector2i.RIGHT * 3, 1.0)
	ok(alarmed > calm * 1.3, "and grows sure quicker - up to %d%% at the top" % roundi(StealthWatch.ALERT_FILL * 100.0),
		"%.2f alarmed, %.2f calm, in a fifth of a second" % [alarmed, calm])
	watch.alert = 1.0
	await wait(0.3)
	ok(watch.alert == 1.0, "and it never eases by itself", "%.2f" % watch.alert)
	await close_map(m)


## Two tiles within `reach` of each other with a wall between them.
func walled_pair(m: Dictionary, reach: float) -> Array:
	var region: Rect2i = m.sight.region()
	var r = floori(reach)
	for x in range(region.position.x, region.end.x):
		for y in range(region.position.y, region.end.y):
			var a := Vector2i(x, y)
			if not standable(m, a):
				continue
			for dx in range(-r, r + 1):
				for dy in range(-r, r + 1):
					var b = a + Vector2i(dx, dy)
					if Vector2(dx, dy).length() <= reach and Vector2(dx, dy).length() >= 2.0 and standable(m, b) and not m.sight.clear(a, b):
						return [a, b]
	return []


func dogs():
	var m = await open_map()
	var pair = walled_pair(m, 3.0)
	log_line("======== a dog: a nose, not eyes ========")
	ok(pair.size() == 2, "(two tiles with a wall between them, within a nose's reach)", "%s" % [pair])
	if pair.size() != 2:
		await close_map(m)
		return
	var dog = add_guard(m, "Hound", pair[0], 0.0, "bomber")
	dog.kind = Guard.Kind.DOG
	var watch = await watch_it(m, out_of_sight_of(m, [pair[0]]))
	m.party.teleport(at(m, pair[1]))
	await wait(0.15)
	ok(watch.suspicion[dog] > 0.0, "a dog smells him through the wall", "%.2f" % watch.suspicion[dog])
	m.party.teleport(at(m, m.away))
	settle_guard(watch, dog)
	await settle()
	var plain_view = find_tile(m, func(t): return gap(t, pair[0]) > dog.smell_tiles + 1.5 and gap(t, pair[0]) < 8.0 and m.sight.clear(pair[0], t))
	dog.facing_degrees = rad_to_deg(Vector2(plain_view - pair[0]).angle())
	settle_guard(watch, dog, dog.facing_degrees)
	m.party.teleport(at(m, plain_view))
	await wait(0.15)
	ok(plain_view != NOWHERE and watch.suspicion[dog] == 0.0, "but in plain view beyond its nose, looking right at him, nothing",
		"%s" % plain_view)
	ok(dog.sees_through(ItemDatabase.item("priest_robes")), "and no disguise fools a nose")
	await close_map(m)


func wards():
	var m = await open_map()
	var post: Vector2i = m.post
	var ward = add_guard(m, "Statue", post, 0.0, "mimic")
	ward.kind = Guard.Kind.WARD
	ward.ward_turn_degrees = 90.0
	var watch = await watch_it(m, out_of_sight_of(m, row(post)))

	log_line("======== a ward: turns, sees, never moves ========")
	var was = ward.facing
	await wait(0.5)
	var turned = rad_to_deg(absf(was.angle_to(ward.facing)))
	ok(turned > 25.0 and turned < 65.0, "it turns on the spot by itself", "%.0f degrees in half a second, at 90 a second" % turned)
	ward.ward_turn_degrees = 0.0
	settle_guard(watch, ward)
	m.party.teleport(at(m, post + Vector2i.RIGHT * 3))
	await wait(0.15)
	ok(watch.suspicion[ward] > 0.0, "it grows sure of somebody in view like anyone", "%.2f" % watch.suspicion[ward])
	ok(ward.mood == Guard.Mood.PATROLLING and ward.global_position == at(m, post), "but does not stop, turn or step towards them")
	m.party.teleport(at(m, m.away))
	settle_guard(watch, ward)
	await settle()
	settle_guard(watch, ward)
	watch.make_noise(at(m, post + Vector2i.RIGHT), 4.0, true)
	ok(ward.mood == Guard.Mood.PATROLLING, "a noise means nothing to it")
	m.party.teleport(at(m, behind(m, post)))
	var down = watch.takedown_target()
	m.party.teleport(at(m, m.away))
	ok(down == null, "it cannot be taken down from behind")
	ok(ward.sees_through(ItemDatabase.item("priest_robes")), "no disguise fools it")
	ok(arrivals(watch.build_fight()).is_empty(), "and it never fights")
	await close_map(m)


func who_joins():
	var m = await open_map()
	var post: Vector2i = m.post
	var caught_on: Vector2i = post + Vector2i.RIGHT * 2
	m.setup.joins_within_tiles = 3.0
	m.setup.tiles_per_late_round = 4.0
	var captain = add_guard(m, "Captain", post, 0.0)
	captain.shout_tiles = 8.0
	var near_tile = find_tile(m, func(t): return gap(t, caught_on) > 4.5 and gap(t, caught_on) < 7.0 and gap(t, post) <= 7.5)
	var far_tile = find_tile(m, func(t): return gap(t, post) > 9.5 and gap(t, caught_on) > 9.5)
	var near = add_guard(m, "Near", near_tile)
	var far = add_guard(m, "Far", far_tile)
	var watch = await watch_it(m, out_of_sight_of(m, row(post) + [near_tile, far_tile]))

	log_line("======== who is in the fight, and when ========")
	m.party.teleport(at(m, caught_on))
	var fight = watch.build_fight()
	# Measured from where the fight puts him, which is where he stands unless
	# that is not floor in the fight.
	var caught_at: Vector2i = fight.spawns[0].position
	var near_gap = gap(near_tile, caught_at)
	var far_gap = gap(far_tile, caught_at)
	ok(near_tile != NOWHERE and far_tile != NOWHERE and m.away != NOWHERE, "(a guard a little way off, and one well off)",
		"%.1f and %.1f tiles" % [near_gap, far_gap])
	var rounds = arrivals(fight)
	ok(rounds.get("Captain") == 1, "whoever is within %d tiles is in from the start" % m.setup.joins_within_tiles)
	ok(rounds.get("Near") == 1 + ceili((near_gap - 3.0) / 4.0) and rounds.get("Near", 0) > 1,
		"further off, a round later for every %d tiles more" % m.setup.tiles_per_late_round, "Near on round %s" % rounds.get("Near"))
	ok(rounds.get("Far") == 1 + ceili((far_gap - 3.0) / 4.0) and rounds.get("Far", 0) > rounds.get("Near", 0),
		"and further still, later still", "Far on round %s" % rounds.get("Far"))
	m.setup.tiles_per_late_round = 0.0
	rounds = arrivals(watch.build_fight())
	ok(rounds.keys() == ["Captain"], "with nobody coming late, only the near ones fight", "%s" % [rounds.keys()])
	m.setup.joins_within_tiles = 0.0
	rounds = arrivals(watch.build_fight())
	ok(rounds.size() == 3 and rounds.values().all(func(r): return r == 1), "with no limit, everyone, all at once", "%s" % [rounds])
	m.setup.joins_within_tiles = 3.0
	m.setup.tiles_per_late_round = 4.0

	log_line("======== a captain's shout ========")
	captain.kind = Guard.Kind.CAPTAIN
	watch._caught_by(captain)
	rounds = arrivals(Campaign.current_encounter)
	ok(watch.alert == 1.0, "a captain sure of him puts the whole map on alarm")
	ok(rounds.get("Near") == 1, "everybody within his shout is in from the first round", "round %s" % rounds.get("Near"))
	ok(rounds.get("Far") == 1 + ceili((far_gap - 3.0) / (4.0 * 2.0)),
		"anybody beyond it on his way as late arrivals come to an alarmed map - twice as quick", "round %s" % rounds.get("Far"))
	await close_map(m)


func questioning():
	var m = await open_map()
	var post: Vector2i = m.post
	var checkpoint = add_guard(m, "Checkpoint", post, 0.0, "priest")
	checkpoint.recognises = Guard.Recognises.OWN_ROLE
	checkpoint.questions = load(TALK)
	checkpoint.questions_title = "s4_checkpoint"
	checkpoint.passed_flag = "kit_passed"
	var strict_tile = out_of_sight_of(m, row(post))
	var strict = add_guard(m, "Strict", strict_tile, 0.0, "priest")
	strict.questions = load(TALK)
	strict.passed_flag = "kit_never_set"
	Campaign.give_item(m.leader, "priest_robes")
	var watch = await watch_it(m, out_of_sight_of(m, row(post) + [strict_tile]))

	log_line("======== stopped for questions ========")
	ok(watch.wear("priest_robes"), "(in Priest's robes)")
	watch._finish_change()
	m.party.teleport(at(m, post + Vector2i.RIGHT * 3))
	var stopped = await until(func(): return checkpoint.questioned, 2.0)
	ok(stopped, "a Priest who knows Priests stops a stranger in Priest's robes")
	var sure: float = watch.suspicion[checkpoint]
	ok(sure >= StealthWatch.QUESTION_AT and sure < 1.0 and watch.spotted_by == null, "half sure - before he is sure", "%.2f" % sure)
	ok(m.scene.is_holding(), "and everything waits on the answers")
	for node in get_tree().root.find_children("*", "", true, false):
		if node.scene_file_path == BALLOON:
			node.queue_free()
	Campaign.set_flag("kit_passed")
	watch.answered(checkpoint)
	ok(checkpoint.fooled and watch.suspicion[checkpoint] == 0.0 and not m.scene.is_holding(), "good answers: he waves him on")
	await wait(0.3)
	ok(watch.suspicion[checkpoint] == 0.0 and watch.spotted_by == null, "and pays him no more mind", "%.2f" % watch.suspicion[checkpoint])
	ok(not checkpoint.sees_through(ItemDatabase.item("priest_robes")), "fooled for good")
	watch.answered(strict)
	ok(watch.spotted_by == strict, "bad answers: he is sure, and it is a fight")
	await close_map(m)


func ghost():
	var m = await open_map()
	var post: Vector2i = m.post
	add_guard(m, "Watcher", post, 0.0)
	var clean := StealthGoal.new()
	clean.completed_flag = "kit_out"
	clean.ghost_flag = "kit_ghost"
	var seen := StealthGoal.new()
	seen.completed_flag = "kit_out_again"
	seen.ghost_flag = "kit_ghost_again"
	for goal in [clean, seen]:
		m.map.add_child(goal)
		# Nowhere anybody walks, so only interact() sets it off.
		goal.global_position = Vector2(-100000, -100000)
	var watch = await watch_it(m, out_of_sight_of(m, row(post)))
	var bar: StealthBar = watch._bar
	await settle()

	log_line("======== the ghost bonus ========")
	ok(watch.never_noticed() and bar._ghost.visible and bar._ghost.text == "Unseen", "nobody has noticed him, and the bar says so")
	clean.interact(m.scene)
	ok(Campaign.flag("kit_out") and Campaign.flag("kit_ghost"), "out without a '?': made it, and a ghost")
	m.party.teleport(at(m, post + Vector2i.RIGHT * 3))
	await settle(2)
	m.party.teleport(at(m, m.away))
	ok(not watch.never_noticed(), "a moment in view, and somebody has noticed")
	await settle()
	ok(not bar._ghost.visible, "Unseen goes from the bar")
	seen.interact(m.scene)
	ok(Campaign.flag("kit_out_again") and not Campaign.flag("kit_ghost_again"), "out after that: made it, and no more")
	await close_map(m)


func disguise_exposed():
	var m = await open_map()
	var post: Vector2i = m.post
	var guard = add_guard(m, "Sharp", post, 0.0)
	guard.recognises = Guard.Recognises.ANY_DISGUISE
	Campaign.give_item(m.leader, "priest_robes")
	var watch = await watch_it(m, out_of_sight_of(m, row(post)))

	log_line("======== a disguise that fools nobody is worse than none ========")
	var plain = await fill_over(m, watch, guard, post + Vector2i.RIGHT * 3, 0.0)
	watch.wear("priest_robes")
	watch._finish_change()
	var dressed = await fill_over(m, watch, guard, post + Vector2i.RIGHT * 3, 0.0)
	ok(dressed > plain * 1.5, "to a guard it does not fool, somebody walking about openly in one is noticed %dx as fast" % StealthWatch.DISGUISE_EXPOSED,
		"%.2f in robes, %.2f sneaking, in a fifth of a second" % [dressed, plain])
	await close_map(m)


func named(combat: Combat, called: String) -> Dictionary:
	for comb in combat.combatants:
		if comb.name == called:
			return comb
	return {}


func arriving_late():
	log_line("======== combat: arriving late ========")
	Campaign.reset()
	var encounter: EncounterDefinition = load("res://encounters/encounter_02_sappers.tres").duplicate(true)
	var late: SpawnDefinition = null
	var later: SpawnDefinition = null
	for spawn in encounter.spawns:
		if spawn.side == 1 and spawn.combatant_key == "barbarian" and late == null:
			late = spawn
		elif spawn.side == 1 and spawn.combatant_key == "ranger":
			later = spawn
	late.arrives_on_round = 2
	late.display_name = "Latecomer"
	later.arrives_on_round = 3
	later.display_name = "Straggler"
	Campaign.current_encounter = encounter
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(6)
	var combat: Combat = game.get_node("VisualCombat")
	var rebuilt := [0]
	combat.update_turn_queue.connect(func(_c, _q): rebuilt[0] += 1)
	ok(combat.deployment_active, "(held at deployment, so nobody takes a turn under the test)")
	ok(named(combat, "Latecomer").is_empty() and named(combat, "Straggler").is_empty(), "two of the enemy are not on the field to begin with")
	ok(combat.arriving().size() == 2 and combat.round_number == 1, "they are on their way")
	combat.turn = combat.turn_queue.size() - 1
	combat.set_next_combatant()
	var latecomer = named(combat, "Latecomer")
	ok(combat.round_number == 2 and not latecomer.is_empty(), "the top of round 2 brings the first")
	ok(not latecomer.is_empty() and latecomer.position == late.position, "onto their own tile", "%s" % [latecomer.get("position")])
	ok(combat.turn_queue.has(combat.combatants.find(latecomer)), "and into the turn order")
	ok(rebuilt[0] >= 1, "the turn queue along the top is rebuilt for them")
	ok(named(combat, "Straggler").is_empty() and combat.arriving().size() == 1, "the other still on the way")
	# Somebody standing on the second one's tile when they come.
	combat.combatants[0].position = later.position
	combat.turn = combat.turn_queue.size() - 1
	combat.set_next_combatant()
	var straggler = named(combat, "Straggler")
	ok(combat.round_number == 3 and not straggler.is_empty(), "round 3 brings the second")
	ok(not straggler.is_empty() and straggler.position != later.position and gap(straggler.position, later.position) <= 2.0,
		"beside their tile, which somebody is standing on", "%s" % [straggler.get("position")])
	ok(combat.arriving().is_empty(), "and nobody is left to come")
	game.queue_free()
	await settle()
	log_line("")
