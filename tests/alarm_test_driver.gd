extends "res://StealthHarness.gd"
## The map's alert: levels that never ease by themselves, a found body putting
## it up a level for good, a word from a disguised party settling it, bodies
## that stay down until somebody finds them and brings them round - and guards
## asleep at their posts.


func suite() -> String:
	return "alarm"


func run_sections():
	await levels()
	await a_word_in_the_ear()
	await brought_round()
	await asleep_at_the_post()
	await patience()
	await settled_by_other_means()
	await whose_gaze_matters()


## Up a level, down a level, and never below a pinned one.
func levels():
	var m = await open_map()
	var watch = await watch_it(m, m.post)
	log_line("======== levels ========")
	ok(watch.alert_level() == "Calm" and watch.alert_floor == 0.0, "calm to begin with")
	watch.raise_alert_level()
	ok(watch.alert_level() == "Wary" and is_equal_approx(watch.alert, StealthWatch.ALERT_WARY), "a level up is Wary", "%.2f" % watch.alert)
	ok(watch.lower_alert_level() and watch.alert_level() == "Calm", "and a level down is Calm again", "%.2f" % watch.alert)
	watch.raise_alert(0.5)
	watch.raise_alert_level(true)
	ok(watch.alert_level() == "Alarmed" and watch.alert_floor == StealthWatch.ALERT_ALARMED,
		"up from half way, pinned: Alarmed, and never below it", "%.2f, floor %.2f" % [watch.alert, watch.alert_floor])
	ok(not watch.lower_alert_level() and watch.alert_level() == "Alarmed", "so it will not settle")
	watch.raise_alert_level()
	ok(watch.alert == 1.0, "a level up from Alarmed is all the way", "%.2f" % watch.alert)
	var was: float = watch.alert
	await wait(0.4)
	ok(watch.alert == was, "and nothing brings it down by itself", "%.2f" % watch.alert)
	await close_map(m)


## Disguised, beside a guard the disguise fools: a word settles the map.
func a_word_in_the_ear():
	var m = await open_map()
	var post: Vector2i = m.post
	var fooled = add_guard(m, "Fooled", post, 180.0)
	fooled.recognises = Guard.Recognises.NO_DISGUISE
	var watch = await watch_it(m, post + Vector2i.RIGHT)
	var bar: StealthBar = watch._bar
	Campaign.give_item(m.leader, "priest_robes")

	log_line("======== nobody to have a word with ========")
	watch.raise_alert(0.5)
	ok(watch.reassure_target() == null and not watch.reassure(), "in his own clothes, there is nobody to talk round")
	watch.wear("priest_robes")
	watch._finish_change()
	await settle()
	ok(watch.suspicion[fooled] == 0.0, "(robed, and taken at face value)")
	ok(watch.reassure_target() == fooled, "robed, the guard beside him is one to have a word with")
	var shown = watch.prompt()
	ok(not shown.is_empty() and shown[1].has(["E", "Have a word", true]), "the prompt offers a word, on E",
		"%s" % [shown[1] if not shown.is_empty() else "none"])

	log_line("======== a word ========")
	press(bar, KEY_E)
	ok(fooled.mood == Guard.Mood.CHATTING and m.party.rooted, "E: the two of them stand and talk")
	ok(watch.alert_level() == "Wary", "and nothing is settled yet")
	var he_said = await until(func(): return watch.leader_says != "", 1.0)
	ok(he_said and StealthWatch.WORD_SAID.has(watch.leader_says), "he says his piece", watch.leader_says)
	var answered = await until(func(): return watch.saying.has(fooled), StealthWatch.REASSURE_SECONDS)
	ok(answered and StealthWatch.WORD_ANSWERED.has(watch.saying[fooled][0]) and watch.leader_says == "", "and the guard answers",
		"%s" % [watch.saying.get(fooled)])
	var settled = await until(func(): return watch.alert_level() == "Calm", StealthWatch.REASSURE_SECONDS + 1.0)
	ok(settled, "a couple of seconds later the map is a level calmer", "%.2f" % watch.alert)
	ok(not m.party.rooted and fooled.reassured, "he can move again, and that guard has heard it")
	watch.raise_alert(0.5)
	ok(watch.reassure_target() == null, "once each: the same guard is not talked round twice")

	log_line("======== not below where a body pinned it ========")
	var second = add_guard(m, "Second", post + Vector2i.RIGHT * 2, 180.0)
	second.recognises = Guard.Recognises.NO_DISGUISE
	watch.guards.append(second)
	watch.suspicion[second] = 0.0
	second.start([], Actors.route)
	watch.alert = 0.0
	watch.raise_alert_level(true)
	watch.raise_alert_level()
	ok(watch.alert_level() == "Alarmed" and watch.alert_floor == StealthWatch.ALERT_WARY, "(Alarmed, and pinned at Wary)")
	ok(watch.reassure(second), "a word with the next one")
	await until(func(): return not m.party.rooted, StealthWatch.REASSURE_SECONDS + 1.0)
	ok(watch.alert_level() == "Wary", "settles it to Wary", "%.2f" % watch.alert)
	second.reassured = false
	ok(watch.reassure_refusal() == "They won't settle - a body was found", "and no further", watch.reassure_refusal())
	shown = watch.prompt()
	ok(not shown.is_empty() and shown[1].has(["E", "They won't settle - a body was found", false]), "the prompt says why",
		"%s" % [shown[1] if not shown.is_empty() else "none"])

	log_line("======== a guard it does not fool ========")
	var sharp = add_guard(m, "Sharp", post + Vector2i.LEFT, 180.0)
	sharp.recognises = Guard.Recognises.ANY_DISGUISE
	ok(not watch._can_reassure(sharp), "nobody talks round a guard who sees through the robes")
	await close_map(m)


## A body stays down until found; whoever finds it brings it round. Knock the
## finder out on his way and it is lying there to be found again - without
## putting the map up a second time.
func brought_round():
	var m = await open_map()
	var post: Vector2i = m.post
	var body = add_guard(m, "Body", post, 0.0)
	var finder_tile = find_tile(m, func(t): return gap(t, post) >= 3.0 and gap(t, post) <= 6.0 and m.sight.clear(t, post))
	var finder = add_guard(m, "Finder", finder_tile, rad_to_deg(Vector2(finder_tile - post).angle()))
	var watch = await watch_it(m, out_of_sight_of(m, [post, finder_tile]))
	log_line("======== down until found ========")
	ok(finder_tile != NOWHERE, "(a finder with a line to him)", "%s" % finder_tile)
	body.knock_out()
	watch._bodies[body] = false
	await wait(1.0)
	ok(body.knocked_out and watch.body_unfound(body), "a knocked-out guard nobody has seen stays down")
	finder.facing_degrees = rad_to_deg(Vector2(post - finder_tile).angle())
	var found = await until(func(): return not watch.body_unfound(body), 1.0)
	ok(found and finder.mood == Guard.Mood.WAKING, "seen, he is found and the finder sets off to him")
	ok(watch.alert_level() == "Wary", "the map a level up", "%.2f" % watch.alert)

	log_line("======== the finder stopped on his way ========")
	finder.knock_out()
	await settle()
	ok(watch.body_unfound(body), "with the finder down too, the body is lying there to be found again")
	var another_tile = find_tile(m, func(t): return gap(t, post) >= 2.0 and gap(t, post) <= 6.0 and m.sight.clear(t, post) and t != finder_tile)
	var another = add_guard(m, "Another", another_tile, rad_to_deg(Vector2(post - another_tile).angle()))
	watch.guards.append(another)
	watch.suspicion[another] = 0.0
	another.start([], Actors.route)
	await until(func(): return not watch.body_unfound(body), 1.0)
	ok(not watch.body_unfound(body) and watch.alert_level() == "Wary", "found again, the map is no further up for it", "%.2f" % watch.alert)
	var up = await until(func(): return not body.knocked_out, 12.0)
	ok(up and (body.mood == Guard.Mood.RETURNING or body.mood == Guard.Mood.PATROLLING), "and this time he is brought round",
		"%s" % Guard.Mood.keys()[body.mood])
	await close_map(m)


## Asleep: sees nothing, can be robbed and taken down from in front, and a
## noise near enough wakes him - to go and see what it was.
func asleep_at_the_post():
	var m = await open_map()
	var post: Vector2i = m.post
	var sleeper = add_guard(m, "Sleeper", post, 0.0)
	sleeper.asleep = true
	sleeper.pockets.assign(["pebble"])
	var watch = await watch_it(m, post + Vector2i.RIGHT)
	log_line("======== asleep ========")
	ok(sleeper.mood == Guard.Mood.ASLEEP and sleeper.sees_nothing(), "he starts asleep, seeing nothing")
	await wait(0.4)
	ok(watch.suspicion[sleeper] == 0.0, "stood right in front of him, he notices nothing")
	ok(watch.pocket_target() == sleeper and watch.takedown_target() == sleeper, "his pockets and his lights are there for the taking, from in front")
	ok(watch.pick_pocket(), "robbed")
	ok(sleeper.mood == Guard.Mood.ASLEEP, "and he sleeps on")
	log_line("======== woken ========")
	watch.make_noise(at(m, post + Vector2i.RIGHT * 2), 3.0, false)
	ok(sleeper.mood == Guard.Mood.INVESTIGATING, "a noise near him wakes him, and he goes to see what it was",
		"%s" % Guard.Mood.keys()[sleeper.mood])
	ok(not sleeper.sees_nothing(), "awake, he sees again")
	await close_map(m)


## Patience: held, time runs twice as fast - and anything that holds the game,
## or a catch, puts it back.
func patience():
	var m = await open_map()
	var post: Vector2i = m.post
	var sentry = add_guard(m, "Sentry", post, 0.0)
	var watch = await watch_it(m, out_of_sight_of(m, row(post)))
	var bar: StealthBar = watch._bar
	log_line("======== patience ========")
	ok(Engine.time_scale == 1.0 and bar._patience.visible, "a button for it, and time as usual")
	bar._patience.button_down.emit()
	await settle()
	ok(Engine.time_scale == StealthWatch.PATIENCE_SCALE and watch.hurried() and bar._patience.button_pressed,
		"held down, time runs twice as fast", "%.1f" % Engine.time_scale)
	m.scene.begin_blocking_interaction()
	await settle()
	ok(Engine.time_scale == 1.0, "a conversation holds everything - and time is as usual through it")
	m.scene.end_blocking_interaction()
	await settle()
	ok(Engine.time_scale == StealthWatch.PATIENCE_SCALE, "and still held after, it hurries again")
	bar._patience.button_up.emit()
	await settle()
	ok(Engine.time_scale == 1.0 and not watch.hurried() and not bar._patience.button_pressed, "let go, it is back to normal")
	bar._patience.button_down.emit()
	await settle()
	watch._caught_by(sentry)
	ok(Engine.time_scale == StealthWatch.CAUGHT_TIME_SCALE and not watch.hurried(), "caught: the slow moment of the catch, not a hurried one")
	await wait(StealthWatch.CAUGHT_SLOW_SECONDS + 0.3)
	ok(Engine.time_scale == 1.0, "and time back to normal after it", "%.1f" % Engine.time_scale)
	await close_map(m)
	ok(Engine.time_scale == 1.0, "gone with the map")


## Settling the map without a word in a guard's ear: a conversation that says
## so, something used that says so, or a guard's own conversation instead.
func settled_by_other_means():
	var m = await open_map()
	var post: Vector2i = m.post
	var talker = add_guard(m, "Talker", post, 180.0)
	talker.recognises = Guard.Recognises.NO_DISGUISE
	talker.small_talk = load("res://Dialogue/stealth_stages.dialogue")
	talker.small_talk_title = "s5_goal"
	var horn := ExamineInteractable.new()
	horn.text = "You sound the all-clear."
	horn.settles_alert = true
	place(m, horn, post + Vector2i.RIGHT * 3, "Horn")
	var watch = await watch_it(m, post + Vector2i.RIGHT)
	log_line("======== in a conversation ========")
	watch.raise_alert(0.9)
	ok(Campaign.settle_alert() and watch.alert_level() == "Wary", "do Campaign.settle_alert() settles it a level", watch.alert_level())
	log_line("======== something used ========")
	horn.use(m.scene)
	ok(watch.alert_level() == "Calm", "using something with Settles Alert does too", watch.alert_level())
	ok(not Campaign.settle_alert(), "and calm, there is nothing more to settle")
	log_line("======== a guard with something of his own to say ========")
	Campaign.give_item(m.leader, "priest_robes")
	watch.wear("priest_robes")
	watch._finish_change()
	await settle()
	ok(watch.reassure_refusal(talker) == "", "calm as it is, he is still worth a word")
	ok(watch.reassure(talker) and m.scene.is_holding(), "E plays his own conversation instead, and everything waits on it")
	ok(talker.reassured and watch.leader_says == "", "(once, and none of the few words)")
	for node in get_tree().root.find_children("*", "", true, false):
		if node.scene_file_path == BALLOON:
			node.queue_free()
	DialogueManager.dialogue_ended.emit(talker.small_talk)
	await settle()
	ok(not m.scene.is_holding(), "and when it ends, on it goes")
	await close_map(m)
	ok(not Campaign.settle_alert(), "off a stealth map, it does nothing")


## In a disguise, whose view matters: purple for a guard who sees through it,
## amber for one who would ask questions first, grey for one it fools - and
## the same, pointing at a disguise on the bar before it is on.
func whose_gaze_matters():
	var m = await open_map()
	var post: Vector2i = m.post
	var fooled = add_guard(m, "Fooled", post, 180.0)
	fooled.recognises = Guard.Recognises.NO_DISGUISE
	var sharp_tile = find_tile(m, func(t): return gap(t, post) >= 8.0 and gap(t, post) <= 12.0)
	var sharp = add_guard(m, "Sharp", sharp_tile, 0.0)
	sharp.recognises = Guard.Recognises.ANY_DISGUISE
	var asker_tile = find_tile(m, func(t): return gap(t, post) >= 14.0 and gap(t, sharp_tile) >= 8.0)
	var asker = add_guard(m, "Asker", asker_tile, 0.0, "priest")
	asker.questions = load("res://Dialogue/stealth_stages.dialogue")
	Campaign.give_item(m.leader, "priest_robes")
	var watch = await watch_it(m, out_of_sight_of(m, row(post) + [sharp_tile, asker_tile]))
	log_line("======== whose gaze matters ========")
	var gazes = func(): return [watch.gaze_of(fooled), watch.gaze_of(sharp), watch.gaze_of(asker)]
	var G = StealthWatch.Gaze
	ok(gazes.call() == [G.SEES, G.SEES, G.SEES], "in his own clothes, every guard's view is danger")
	watch.preview_disguise = "priest_robes"
	await settle()
	ok(watch.gaze_of(fooled, "priest_robes") == G.FOOLED and watch.seen_by_gaze()[G.FOOLED].has(post),
		"pointing at the robes, the one they would fool is shown grey")
	watch.preview_disguise = ""
	watch.wear("priest_robes")
	watch._finish_change()
	await settle()
	ok(gazes.call() == [G.FOOLED, G.SEES, G.ASKS], "in them: grey for the one they fool, purple for the one who sees through, amber for the priest with questions",
		"%s" % [gazes.call()])
	asker.questioned = true
	ok(watch.gaze_of(asker) == G.SEES, "once he has asked, and not been fooled, he just sees through them")
	asker.fooled = true
	ok(watch.gaze_of(asker) == G.FOOLED, "talked round, he is fooled for good")
	await close_map(m)
