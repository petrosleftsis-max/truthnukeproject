extends "res://StealthHarness.gd"
## Poisons: into supper, or thrown as darts; taking hold at once, shortly or
## after a while; and what each does - sick for five minutes, out cold, or too
## ill to stand with somebody coming to see to him.


func suite() -> String:
	return "poisons"


func run_sections():
	await only_for_sneaking()
	await into_his_supper()
	await at_once()
	await darts()
	await a_fever()


func only_for_sneaking():
	log_line("======== only for sneaking ========")
	Campaign.reset()
	Campaign.seed_party(["cyrus"])
	for key in ["emetic_powder", "knockout_drops", "sleeping_draught", "fever_tincture", "sleep_dart", "retching_dart", "fever_dart"]:
		var item: ItemDefinition = ItemDatabase.item(key)
		ok(item != null and item.is_poison() and item.stealth_only(), "%s is a poison, and only for a stealth map" % key)
	Campaign.give_item("cyrus", "sleep_dart")
	Campaign.give_item("cyrus", "emetic_powder")
	ok(Campaign.combat_items_of("cyrus").is_empty(), "none of them come to a fight")
	ok(Campaign.darts_of("cyrus") == ["sleep_dart"] and Campaign.food_poison_of("cyrus") == "emetic_powder",
		"the dart is a dart, the powder goes in food")
	log_line("")


## An emetic in his supper: he comes for it, eats it, and a few seconds later is
## off to be sick - seeing nothing - at the bucket.
func into_his_supper():
	var m = await open_map()
	var post: Vector2i = m.post
	var eater = add_guard(m, "Eater", post, 0.0)
	var supper := Edible.new()
	supper.eater = "Eater"
	supper.eaten_after_seconds = StealthWatch.LACE_SECONDS + 1.5
	place(m, supper, post + Vector2i.RIGHT, "Supper")
	var bucket_tile = find_tile(m, func(t): return gap(t, post) >= 3.0 and gap(t, post) <= 6.0)
	var bucket := RetchSpot.new()
	place(m, bucket, bucket_tile, "Bucket")
	Campaign.give_item(m.leader, "emetic_powder")
	var watch = await watch_it(m, behind(m, post))
	log_line("======== stirred in ========")
	ok(supper.is_available() and supper.prompt == "Stir Emetic Powder into the supper", "beside his supper with the powder: E stirs it in", supper.prompt)
	supper.use(m.scene)
	ok(watch.lacing() == "emetic_powder" and m.party.rooted and supper.poisoned_with == "",
		"E: he stands over it, stirring - not in yet")
	ok(watch.caught_red_handed(), "and anybody who saw him at it would know him at once")
	ok(watch.dash_refusal() != "" and watch.takedown_target() == null and not watch.lace(supper, "emetic_powder"),
		"nothing else meanwhile", watch.dash_refusal())
	var stirred = await until(func(): return supper.poisoned_with != "", StealthWatch.LACE_SECONDS + 0.5)
	ok(stirred and watch.lacing() == "" and not m.party.rooted, "%d seconds later it is in, and he can move" % StealthWatch.LACE_SECONDS)
	ok(supper.poisoned_with == "emetic_powder" and Campaign.count_of(m.leader, "emetic_powder") == 0, "in it, and out of the bag")
	ok(not supper.is_available(), "and nothing more to do with it")
	m.party.teleport(at(m, out_of_sight_of(m, row(post))))
	log_line("======== supper time ========")
	var eating = await until(func(): return eater.mood == Guard.Mood.EATING, 3.0)
	ok(eating, "his time comes, and he goes to eat")
	var ate = await until(func(): return supper.eaten, StealthWatch.EAT_SECONDS + 3.0)
	ok(ate and watch.brewing_in(eater) > 0.0, "he eats it - and nothing, yet", "%.1fs to go" % watch.brewing_in(eater))
	var sick = await until(func(): return eater.mood == Guard.Mood.RETCHING, StealthWatch.POISON_SOON + 1.0)
	ok(sick, "a few seconds later he is off to be sick")
	ok(eater.sees_nothing(), "seeing nothing")
	var there = await until(func(): return eater.errand_arrived(), 10.0)
	ok(there and tile_at(m, eater.global_position) == bucket_tile, "at the bucket")
	ok(absf(eater.errand_left() - StealthWatch.EMETIC_SECONDS) < 2.0, "for five minutes", "%.0fs" % eater.errand_left())
	await close_map(m)

	log_line("======== seen stirring it in ========")
	m = await open_map()
	post = m.post
	var looker = add_guard(m, "Looker", post, 0.0)
	var jug := Edible.new()
	jug.eater = "Looker"
	jug.eaten_after_seconds = 600.0
	place(m, jug, post + Vector2i.RIGHT * 3, "Jug")
	Campaign.give_item(m.leader, "emetic_powder")
	watch = await watch_it(m, post + Vector2i.RIGHT * 2)
	watch.suspicion[looker] = 0.0
	ok(watch.lace(jug, "emetic_powder"), "(starting to stir it in, in front of him)")
	var caught = await until(func(): return watch.spotted_by == looker, 1.0)
	ok(caught, "he knows at once what that was")
	ok(jug.poisoned_with == "" and Campaign.count_of(m.leader, "emetic_powder") == 1 and watch.lacing() == "",
		"caught at it, it never went in - and the powder is still in the bag")
	await close_map(m)


## Knockout drops: out cold the moment he has had them - a body lying by his
## supper, to be found.
func at_once():
	var m = await open_map()
	var post: Vector2i = m.post
	var eater = add_guard(m, "Eater", post, 0.0)
	var supper := Edible.new()
	supper.eater = "Eater"
	supper.eaten_after_seconds = 0.3
	supper.poisoned_with = "knockout_drops"
	place(m, supper, post + Vector2i.RIGHT, "Supper")
	var watch = await watch_it(m, out_of_sight_of(m, row(post)))
	log_line("======== knockout drops ========")
	var down = await until(func(): return eater.knocked_out, StealthWatch.EAT_SECONDS + 4.0)
	ok(down and supper.eaten, "the moment he has eaten, he is out cold")
	ok(watch.body_unfound(eater), "lying there, a body to be found")
	await close_map(m)


## Darts: T picks what to throw, a click on a guard throws it.
func darts():
	var m = await open_map()
	var post: Vector2i = m.post
	var target = add_guard(m, "Target", post, 180.0)
	var other_tile = find_tile(m, func(t): return gap(t, post) >= 4.0 and gap(t, post) <= 7.0 and not m.sight.clear(t, post + Vector2i.RIGHT * 3))
	var other = add_guard(m, "Other", other_tile, 0.0)
	# Just past him, looking away.
	var third = add_guard(m, "Third", post + Vector2i.RIGHT * 4, 0.0)
	Campaign.give_item(m.leader, "pebble")
	Campaign.give_item(m.leader, "sleep_dart")
	Campaign.give_item(m.leader, "retching_dart")
	var watch = await watch_it(m, post + Vector2i.RIGHT * 3)
	var bar: StealthBar = watch._bar
	log_line("======== picking what to throw ========")
	ok(watch.throwables() == ["pebble", "sleep_dart", "retching_dart"], "pebbles and darts to throw", "%s" % [watch.throwables()])
	await settle()
	var extra = bar._other_throws.map(func(b): return b.text)
	ok(bar._throw.text == "Throw Pebble x1 (T)" and extra == ["Sleep Dart x1", "Retching Dart x1"],
		"the bar has a button for each - no dart hidden behind the pebbles", "%s, %s" % [bar._throw.text, extra])
	bar._other_throws[0].pressed.emit()
	ok(watch.aiming() == "sleep_dart", "a click on one aims it")
	watch.cancel_throw()
	watch._last_thrown = ""
	press(bar, KEY_T)
	ok(watch.aiming() == "pebble", "T aims the first")
	press(bar, KEY_T)
	ok(watch.aiming() == "sleep_dart", "T again, the next", watch.aiming())
	await settle()
	ok(bar._throw.text == "Aiming Sleep Dart - click (T: next)", "the bar says which", bar._throw.text)
	log_line("======== a sleep dart ========")
	click(watch, target.global_position, MOUSE_BUTTON_LEFT)
	ok(target.knocked_out and Campaign.count_of(m.leader, "sleep_dart") == 0, "a click on him: out cold, at once, without a sound")
	ok(other.mood == Guard.Mood.PATROLLING, "nobody hears a thing")
	ok(watch.throwable() == "pebble", "with no more darts, T is back to pebbles")
	log_line("======== a retching dart, delayed ========")
	watch.begin_throw("retching_dart")
	ok(watch.throw_at(tile_at(m, third.global_position)), "thrown at the one just past him")
	ok(absf(watch.brewing_in(third) - StealthWatch.POISON_DELAY) < 0.5, "it will be a quarter of a minute before it takes hold",
		"%.1fs" % watch.brewing_in(third))
	ok(third.mood == Guard.Mood.PATROLLING, "and until then he carries on as if nothing had happened")
	watch._brewing[third][1] = 0.05
	var sick = await until(func(): return third.mood == Guard.Mood.RETCHING, 1.0)
	ok(sick, "then off he goes to be sick")
	log_line("======== a miss ========")
	Campaign.give_item(m.leader, "sleep_dart")
	watch.begin_throw("sleep_dart")
	var empty = post + Vector2i.RIGHT * 2
	ok(watch.dart_target(empty) == null and watch.throw_at(empty), "thrown where nobody is")
	ok(Campaign.count_of(m.leader, "sleep_dart") == 0, "it is lost")
	await close_map(m)


## A fever: too ill to stand, and the nearest guard comes to see to him - both
## of them watching half as wide - until it passes.
func a_fever():
	var m = await open_map()
	var post: Vector2i = m.post
	var patient = add_guard(m, "Patient", post, 0.0)
	var nurse_tile = find_tile(m, func(t): return gap(t, post) >= 3.0 and gap(t, post) <= 6.0)
	var nurse = add_guard(m, "Nurse", nurse_tile, 0.0)
	var watch = await watch_it(m, out_of_sight_of(m, row(post) + [nurse_tile]))
	log_line("======== a fever ========")
	watch.dose(patient, ItemDatabase.item("fever_dart"))
	ok(patient.mood == Guard.Mood.SICK and is_equal_approx(patient.half_cone(), Guard.HALF_CONE * Guard.UNWELL_CONE),
		"at once, he is too ill to stand, watching half as wide", "%d either side" % patient.half_cone())
	ok(nurse.mood == Guard.Mood.TENDING and watch.tending(nurse) == patient, "and the nearest guard comes to see to him")
	var there = await until(func(): return nurse.errand_arrived(), 8.0)
	ok(there and nurse.global_position.distance_to(patient.global_position) <= Grid.tiles(1.6), "beside him")
	ok(is_equal_approx(nurse.half_cone(), Guard.HALF_CONE * Guard.UNWELL_CONE), "watching as narrowly as he is")
	patient.watching(at(m, post + Vector2i.RIGHT))
	ok(patient.mood == Guard.Mood.SICK, "something catching his eye does not get him up")
	patient._errand_left = 0.05
	var better = await until(func(): return patient.mood != Guard.Mood.SICK, 1.0)
	await settle()
	ok(better and nurse.mood != Guard.Mood.TENDING and watch.tending(nurse) == null, "better, both go back to their rounds")
	await close_map(m)
