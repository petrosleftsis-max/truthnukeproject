extends "res://StealthHarness.gd"
## Stealth mode (StealthWatch "Stealth mode"; the designer, 2026-11-04 and 05):
## only Cyrus creeping, and anybody invisible, go unnoticed by a guard who cannot
## see them. Anybody else walking near a guard is noticed as if seen, walls or no
## walls, and so is Cyrus when he is not creeping; standing still, nobody is. Ctrl
## turns creeping on and off rather than being held.


func suite() -> String:
	return "openly"


func time_limit() -> float:
	return 240.0


func run_sections():
	await somebody_walking_openly()
	await cyrus_creeping()
	await somebody_who_cannot_creep()


## The map with `party` on it, a watchman looking one way and the party behind
## him - out of his sight, near enough to be noticed walking.
func behind_a_guard(party: Array) -> Dictionary:
	var m := await open_map()
	Campaign.set_party(party, 8)
	await settle(3)
	m.party = m.scene.party
	m.leader = Campaign.party_members()[0].key
	m.guard = add_guard(m, "Watchman", m.post, 0.0)
	var behind := find_tile(m, func(tile): return tile.x < m.post.x and gap(tile, m.post) >= 3.0 and gap(tile, m.post) <= 6.0 and standable(m, tile + Vector2i.UP) and standable(m, tile + Vector2i.DOWN))
	m.watch = await watch_it(m, behind)
	settle_guard(m.watch, m.guard, 0.0)
	await settle(2)
	return m


## Up and down, as the keys would walk them.
func walk_about(m: Dictionary, frames: int = 24):
	var way := Vector2.UP
	for i in frames:
		if i % 8 == 0:
			way = -way
		m.party._step(way, 1.0 / 60.0)
		await settle(1)


func someone_of(watch: StealthWatch, key: String) -> Dictionary:
	for someone in watch._party_standing():
		if someone.key == key:
			return someone
	return {}


func somebody_walking_openly():
	log_line("======== somebody walking openly ========")
	var m := await behind_a_guard(["enfina"])
	var watch: StealthWatch = m.watch
	var guard: Guard = m.guard
	ok(not watch.stealthing("enfina"), "Enfina cannot go to stealth mode")
	ok(not watch.can_perceive(guard, someone_of(watch, "enfina")), "  and the watchman cannot see her, behind him")
	await settle(20)
	ok(watch.suspicion[guard] == 0.0, "standing still: nothing", "%.2f" % watch.suspicion[guard])
	await walk_about(m)
	ok(watch.suspicion[guard] > 0.0, "walking near him: he starts to be sure of her, as if he saw her", "%.2f" % watch.suspicion[guard])
	settle_guard(watch, guard, 0.0)
	await settle(3)
	var far := find_tile(m, func(tile): return tile.x < m.post.x and gap(tile, m.post) >= StealthWatch.WALKING_NOTICED_TILES + 2.0 and standable(m, tile + Vector2i.UP) and standable(m, tile + Vector2i.DOWN))
	if far != NOWHERE:
		m.party.teleport(at(m, far))
		settle_guard(watch, guard, 0.0)
		await settle(3)
		await walk_about(m)
		ok(watch.suspicion[guard] == 0.0, "further off than %d tiles: nothing" % StealthWatch.WALKING_NOTICED_TILES, "%.2f" % watch.suspicion[guard])
	await close_map(m)


func cyrus_creeping():
	log_line("======== Cyrus, creeping ========")
	var m := await behind_a_guard(["cyrus"])
	var watch: StealthWatch = m.watch
	var guard: Guard = m.guard
	var bar: StealthBar = watch.stealth_bar()
	ok(not watch.stealthing("cyrus") and is_equal_approx(m.party.leader.hidden_alpha, 1.0), "not creeping: not in stealth mode, and drawn solid",
		"%.2f" % m.party.leader.hidden_alpha)
	await walk_about(m)
	ok(watch.suspicion[guard] > 0.0, "  and walking near a guard he is noticed like anybody", "%.2f" % watch.suspicion[guard])
	settle_guard(watch, guard, 0.0)
	await settle(3)
	press(bar, KEY_CTRL)
	await settle(2)
	ok(watch.creeping() and watch.stealthing("cyrus"), "Ctrl: creeping - stealth mode")
	ok(m.party.pace < 1.0 and is_equal_approx(m.party.leader.hidden_alpha, StealthWatch.SNEAKING_ALPHA), "  slower, and drawn half-there")
	ok(watch.creeping(), "  and still on with the key let go: it turns on and off rather than being held")
	settle_guard(watch, guard, 0.0)
	await settle(2)
	await walk_about(m)
	ok(watch.suspicion[guard] == 0.0, "  walking near the guard, unnoticed", "%.2f" % watch.suspicion[guard])
	press(bar, KEY_CTRL)
	await settle(2)
	ok(not watch.creeping() and is_equal_approx(m.party.pace, 1.0), "Ctrl again: off")
	await walk_about(m)
	ok(watch.suspicion[guard] > 0.0, "  and he is noticed again", "%.2f" % watch.suspicion[guard])
	await close_map(m)
	# Somebody who cannot, walking behind him, is noticed all the same.
	m = await behind_a_guard(["cyrus", "enfina"])
	watch = m.watch
	guard = m.guard
	watch.toggle_creep()
	await settle(2)
	await walk_about(m, 40)
	ok(watch.stealthing("cyrus") and not watch.stealthing("enfina") and watch.suspicion[guard] > 0.0,
		"Cyrus creeping with Enfina behind him: it is her he notices", "%.2f" % watch.suspicion[guard])
	await close_map(m)


func somebody_who_cannot_creep():
	log_line("======== nobody who can ========")
	var m := await behind_a_guard(["enfina"])
	var watch: StealthWatch = m.watch
	var guard: Guard = m.guard
	var bar: StealthBar = watch.stealth_bar()
	ok(not watch.can_creep_here(), "Enfina alone: nobody to creep")
	watch.toggle_creep()
	await settle(2)
	ok(not watch.creeping() and is_equal_approx(m.party.pace, 1.0), "  Ctrl does nothing")
	bar.refresh()
	ok(bar._creep.disabled, "  and the bar's Creep is greyed", bar._creep.tooltip_text)
	# Invisible, anybody goes unnoticed - no creeping about it.
	watch._unseen["enfina"] = 30.0
	await settle(2)
	ok(watch.stealthing("enfina") and watch.can_creep_here(), "invisible: in stealth mode, and she can creep")
	settle_guard(watch, guard, 0.0)
	await settle(2)
	await walk_about(m)
	ok(watch.suspicion[guard] == 0.0, "  walking near the guard, unnoticed", "%.2f" % watch.suspicion[guard])
	watch._unseen.clear()
	await close_map(m)
