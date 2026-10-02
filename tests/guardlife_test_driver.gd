extends "res://StealthHarness.gd"
## Guards with lives of their own: two who meet to talk - overheard, and
## missed when one of them does not come - and somebody who is nobody's guard,
## who runs to tell one what they saw.


func suite() -> String:
	return "guardlife"


func run_sections():
	await a_word_between_them()
	await nobody_came()
	await nobodys_guard()


## A chat: they meet, talk with their view the narrower for it, are overheard
## from close by, and go back.
func a_word_between_them():
	var m = await open_map()
	var post: Vector2i = m.post
	var first = add_guard(m, "First", post, 0.0)
	var second = add_guard(m, "Second", post + Vector2i.RIGHT * 4, 180.0)
	var chat := GuardChat.new()
	chat.name = "Chat"
	chat.first_guard = "First"
	chat.second_guard = "Second"
	chat.first_after_seconds = 0.3
	chat.every_seconds = 600.0
	chat.lines.assign(["The captain's in a mood.", "When isn't he?"])
	chat.seconds_per_line = 0.6
	chat.earshot_tiles = 5.0
	chat.overheard_flag = "heard_them"
	m.map.add_child(chat)
	# Near enough to hear, round a wall from both of them.
	var hidden_from_them = func(t): return not m.sight.clear(t, post) and not m.sight.clear(t, post + Vector2i.RIGHT) and not m.sight.clear(t, post + Vector2i.RIGHT * 4)
	var ear = find_tile(m, func(t): return gap(t, post) <= 4.5 and hidden_from_them.call(t))
	var watch = await watch_it(m, ear if ear != NOWHERE else out_of_sight_of(m, row(post)))
	log_line("======== they meet ========")
	ok(ear != NOWHERE, "(somewhere to listen from, out of their sight)", "%s" % ear)
	var met = await until(func(): return watch._chats[0].phase == "talking", 8.0)
	ok(met and first.mood == Guard.Mood.CHATTING and second.mood == Guard.Mood.CHATTING, "time comes, and they stand and talk")
	ok(second.global_position.distance_to(first.global_position) <= Grid.tiles(1.6), "the second come to stand beside the first")
	ok(is_equal_approx(first.half_cone(), Guard.HALF_CONE * Guard.CHATTING_CONE), "their minds on it, their view narrower",
		"%d either side" % first.half_cone())
	ok(watch.saying.has(first) and watch.saying[first] == ["The captain's in a mood.", true], "the first line, made out from round the corner",
		"%s" % [watch.saying.get(first)])
	var heard = await until(func(): return Campaign.flag("heard_them"), 4.0)
	ok(heard, "every word of it overheard")
	var back = await until(func(): return first.mood != Guard.Mood.CHATTING and second.mood != Guard.Mood.CHATTING, 2.0)
	ok(back and watch.saying.is_empty(), "and they go back to their rounds")
	ok(watch.never_noticed(), "without either of them noticing him")
	await close_map(m)


## When one of them does not come, the other goes looking - and the map is a
## little more on edge for it.
func nobody_came():
	var m = await open_map()
	var post: Vector2i = m.post
	var first = add_guard(m, "First", post, 0.0)
	# Out of his sight, so it is the check-in that sends him, not seeing him fall.
	var second_tile = find_tile(m, func(t): return gap(t, post) >= 3.0 and gap(t, post) <= 5.0 and not m.sight.clear(post, t))
	var second = add_guard(m, "Second", second_tile, 0.0)
	var chat := GuardChat.new()
	chat.first_guard = "First"
	chat.second_guard = "Second"
	chat.first_after_seconds = 0.5
	m.map.add_child(chat)
	var watch = await watch_it(m, out_of_sight_of(m, row(post) + [second_tile]))
	log_line("======== a check-in missed ========")
	second.knock_out()
	watch._bodies[second] = false
	var looking = await until(func(): return first.mood == Guard.Mood.INVESTIGATING, 3.0)
	ok(looking and first.last_seen.distance_to(second.global_position) < 1.0, "with the other out cold, he goes looking where he should be")
	ok(watch.alert > 0.0, "the map a little more on edge for it", "%.2f" % watch.alert)
	var found = await until(func(): return first.mood == Guard.Mood.WAKING, 8.0)
	ok(found, "and finds him")
	await close_map(m)


## Somebody who is nobody's guard: sure of him, they run to the nearest guard,
## who comes to look. They never fight.
func nobodys_guard():
	var m = await open_map()
	var post: Vector2i = m.post
	var clerk = add_guard(m, "Clerk", post, 0.0)
	clerk.kind = Guard.Kind.CIVILIAN
	var guard_tile = out_of_sight_of(m, row(post))
	var watchman = add_guard(m, "Watchman", guard_tile, 0.0)
	var watch = await watch_it(m, out_of_sight_of(m, row(post) + [guard_tile]))
	log_line("======== seen by a clerk ========")
	ok(not arrivals(watch.build_fight()).has("Clerk"), "nobody's guard is never in a fight")
	m.party.teleport(at(m, post + Vector2i.RIGHT * 3))
	var ran = await until(func(): return watch.is_reporting(clerk), 3.0)
	ok(ran and clerk.mood == Guard.Mood.REPORTING and watch.spotted_by == null, "sure of him, the clerk does not catch him - he runs to tell somebody")
	m.party.teleport(at(m, out_of_sight_of(m, row(post) + [guard_tile, tile_at(m, clerk.global_position)])))
	var told = await until(func(): return not watch.is_reporting(clerk), 20.0)
	ok(told and watchman.mood == Guard.Mood.INVESTIGATING and watchman.is_hunting(),
		"and the watchman he tells goes to look for him", "%s" % Guard.Mood.keys()[watchman.mood])
	ok(watchman.last_seen.distance_to(at(m, post + Vector2i.RIGHT * 3)) < Grid.tiles(1.5), "where the clerk saw him")
	await close_map(m)

	log_line("======== a takedown seen ========")
	m = await open_map()
	post = m.post
	var victim = add_guard(m, "Victim", post, 0.0)
	var seer_tile = find_tile(m, func(t): return gap(t, post) >= 3.0 and gap(t, post) <= 6.0 and m.sight.clear(t, behind(m, post)) and t.x < post.x)
	var seer = add_guard(m, "Seer", seer_tile, rad_to_deg(Vector2(behind(m, post) - seer_tile).angle()))
	seer.kind = Guard.Kind.CIVILIAN
	seer.recognises = Guard.Recognises.NO_DISGUISE
	var wait_tile = out_of_sight_of(m, row(post) + [seer_tile])
	add_guard(m, "Help", out_of_sight_of(m, row(post) + [seer_tile, wait_tile]), 0.0)
	Campaign.give_item(m.leader, "priest_robes")
	var watch2 = await watch_it(m, wait_tile)
	# Robed, so the clerk has no reason to grow sure of him before he does it.
	watch2.wear("priest_robes")
	watch2._finish_change()
	m.party.teleport(at(m, behind(m, post)))
	await settle()
	ok(seer_tile != NOWHERE and watch2.suspicion[seer] == 0.0, "(a clerk looking on, taking him for a priest)", "%s" % seer_tile)
	ok(watch2.take_down(victim), "(the takedown)")
	ok(watch2.is_reporting(seer), "seen doing it, the clerk runs to tell")
	seer.knock_out()
	await settle()
	ok(not watch2.is_reporting(seer), "stopped on the way, nobody is told")
	await close_map(m)
