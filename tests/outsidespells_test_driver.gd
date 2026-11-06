extends "res://StealthHarness.gd"
## New spells out of a fight (the designer, 2026-11-05): a tether frays by 5 a second on a
## map and one is held at a time; The Great Snare downs everybody round it; The Company
## Unseen hides everybody but Cyrus behind him, shortens the guards' eyes and hands the
## familiar to whoever does not play him.


func suite() -> String:
	return "outsidespells"


func time_limit() -> float:
	return 180.0


func run_sections():
	await tether_out_here()
	await great_snare()
	await the_company()
	await illusions_on_a_map()


func tether_out_here():
	log_line("======== a tether out of a fight ========")
	var m = await open_map()
	Campaign.set_party(["alithia"], 14)
	await settle()
	var guard := add_guard(m, "Near", m.post + Vector2i.RIGHT * 3, 180.0)
	var other := add_guard(m, "Other", m.post + Vector2i.RIGHT * 4, 180.0)
	var watch = await watch_it(m, m.post)
	var scene = m.scene
	var dread: SkillDefinition = SkillDatabase.skills.dread_visage
	ok(OutsideMoves.seconds_of(dread, OutsideMoves.Use.SCARE) == dread.tether_strength / 5, "lasts its tether over 5 a second", "%d" % OutsideMoves.seconds_of(dread, OutsideMoves.Use.SCARE))
	ok(OutsideMoves.use(scene, "alithia", "dread_visage") and guard.mood == Guard.Mood.FRIGHTENED or other.mood == Guard.Mood.FRIGHTENED, "cast on a guard")
	ok(watch.outside_tethers.has("alithia") and watch.outside_tethers.alithia.max == float(dread.tether_strength), "she holds the tether", "%s" % [watch.outside_tethers])
	var bar: float = watch.outside_tethers.alithia.bar
	watch._fray_outside(2.0)
	ok(is_equal_approx(watch.outside_tethers.alithia.bar, bar - 10.0), "two seconds take 10 off", "%s" % watch.outside_tethers.alithia.bar)
	# One at a time: another lets go of the first.
	var first: Guard = guard if guard.mood == Guard.Mood.FRIGHTENED else other
	ok(OutsideMoves.use(scene, "alithia", "bewilder"), "she casts another that is tethered")
	ok(watch.outside_tethers.alithia.name == "Bewilder", "and holds that instead", watch.outside_tethers.alithia.name)
	ok(first.mood != Guard.Mood.FRIGHTENED or first.mood == Guard.Mood.BEWILDERED, "and what the first did ends", "%s" % Guard.Mood.keys()[first.mood])
	# Worn through.
	watch._fray_outside(watch.outside_tethers.alithia.bar / 5.0 + 0.1)
	ok(not watch.outside_tethers.has("alithia"), "worn through, she holds nothing")
	await close_map(m)


func great_snare():
	log_line("======== The Great Snare ========")
	var snare: SkillDefinition = SkillDatabase.skills.great_snare
	ok(snare.outside_only() and snare.spell_slot_level == 3, "Pandora, and never in a fight")
	ok(OutsideMoves.use_of(snare) == OutsideMoves.Use.TRAP, "laid as a trap")
	ok(Combat.fighting_skills(["great_snare", "heal"]) == ["heal"], "and no part of anybody's kit in a fight")
	var m = await open_map()
	Campaign.set_party(["prometheus"], 14)
	Campaign.learned_spells = {"prometheus": ["great_snare"]}
	await settle()
	var near := add_guard(m, "Near", m.post + Vector2i.RIGHT * 6, 180.0)
	var by := add_guard(m, "By", m.post + Vector2i.RIGHT * 7, 180.0)
	var far := add_guard(m, "Far", m.post + Vector2i.RIGHT * 14, 180.0)
	var watch = await watch_it(m, m.post + Vector2i.RIGHT * 6 + Vector2i.DOWN * 8)
	var scene = m.scene
	ok(OutsideMoves.refusal(scene, "prometheus", "great_snare") == "", "he can lay it", OutsideMoves.refusal(scene, "prometheus", "great_snare"))
	ok(OutsideMoves.use(scene, "prometheus", "great_snare"), "he does")
	var trap = null
	for child in scene.get_children():
		if child is OutsideMoves.Trap:
			trap = child
	ok(trap != null and trap.burst_tiles == 3, "a great one", "%s" % [trap.burst_tiles if trap != null else "none"])
	trap.global_position = near.global_position
	await settle(4)
	ok(near.knocked_out, "the first onto it is down")
	ok(by.knocked_out, "and everybody round it")
	ok(not far.knocked_out, "not those far off")
	ok(not is_instance_valid(trap) or trap.is_queued_for_deletion(), "and it is spent")
	await close_map(m)


func the_company():
	log_line("======== The Company Unseen ========")
	var spell: SkillDefinition = SkillDatabase.skills.company_unseen
	ok(spell.outside_only() and spell.out_of_combat and spell.spell_slot_level == 5, "only out of a fight, as deep as the fifth gate")
	ok(OutsideMoves.iris_gate_for(spell) == 2, "paid through the Gates of Mnemosyne first", "%d" % OutsideMoves.iris_gate_for(spell))
	ok(Stats.outside_gate_name(2) == "Gates of Mnemosyne", "the higher gate for such things")
	ok(OutsideMoves.iris_gate_for(SkillDatabase.skills.invisibility) == 1 or not SkillDatabase.skills.invisibility.out_of_combat, "Iris still pays what it paid")
	var m = await open_map()
	Campaign.set_party(["prometheus", "cyrus", "alithia"], 32)
	Campaign.learned_spells = {"prometheus": ["company_unseen"]}
	await settle()
	var guard := add_guard(m, "Eyes", m.post + Vector2i.RIGHT * 12, 180.0)
	var dog := add_guard(m, "Nose", m.post + Vector2i.RIGHT * 3, 180.0)
	dog.kind = Guard.Kind.DOG
	var watch = await watch_it(m, m.post)
	var scene = m.scene
	ok(watch.company_refusal() == "", "it can be cast", watch.company_refusal())
	var seen_far: int = watch._seen.get(guard, {}).size()
	# Somebody told to stay put comes too.
	Campaign.set_leader("alithia")
	ok(scene.stay_here() and scene.staying.has("alithia"), "Alithia stays put")
	await settle(2)
	ok(OutsideMoves.use(scene, "prometheus", "company_unseen"), "cast")
	await settle(2)
	ok(scene.staying.is_empty() and scene.party.own_sprite_for("alithia") != null and not scene.party.stayers.has(scene.party.own_sprite_for("alithia")), "and she falls in behind him with the rest")
	ok(watch.company_on() and absf(watch.company_left - float(spell.outside_seconds)) < 1.0, "for its seconds", "%s" % watch.company_left)
	ok(watch.unseen("prometheus") and watch.unseen("alithia") and not watch.unseen("cyrus"), "everybody but Cyrus is unseen")
	ok(Campaign.leader() == "cyrus", "and follows him", Campaign.leader())
	ok(watch.company_refusal() != "", "it cannot be cast over itself")
	await settle(3)
	var from: Vector2i = watch.tile_of(guard.global_position)
	var reach := 0.0
	for tile in watch._seen.get(guard, {}):
		reach = maxf(reach, Vector2(tile - from).length())
	ok(reach <= StealthWatch.COMPANY_SIGHT_TILES, "the guard's eyes reach less far", "%s" % reach)
	# Noses and sensors still find them.
	var someone := {"key": "alithia", "tile": watch.tile_of(dog.global_position) + Vector2i.LEFT}
	watch._seen[dog] = {someone.tile: true}
	ok(watch.can_perceive(dog, someone), "a nose finds them")
	var eyes := {"key": "alithia", "tile": from + Vector2i.LEFT}
	watch._seen[guard] = {eyes.tile: true}
	ok(not watch.can_perceive(guard, eyes), "eyes do not")
	# It ends.
	watch._company_goes_on(watch.company_left + 0.1)
	ok(not watch.company_on(), "and it ends")
	await close_map(m)
	await the_company_for_two()


func the_company_for_two():
	log_line("======== The Company Unseen, for two ========")
	var m = await open_map()
	Campaign.set_party(["prometheus", "cyrus", "alithia"], 32)
	Campaign.learned_spells = {"prometheus": ["company_unseen"]}
	await settle()
	Coop.join(Coop.KEYBOARD)
	Coop.join(0)
	Campaign.controllers = {"alithia": 1, "prometheus": 1}
	Coop.players_changed.emit()
	await settle(3)
	var watch = await watch_it(m, m.post)
	var scene = m.scene
	var keeper = scene.familiar_keeper
	ok(Coop.controller_of("cyrus") == 0 and Coop.controller_of("alithia") == 1, "one plays Cyrus, the other the rest")
	ok(OutsideMoves.use(scene, "prometheus", "company_unseen"), "cast")
	await settle(3)
	ok(Coop.keys_of(0).size() == 3 and Coop.keys_of(1).is_empty(), "they all follow Cyrus, in his player's group", "%s" % [Coop.keys_of(0)])
	ok(watch.company_other == 1, "the other player is the one without him")
	ok(scene._stranded().is_empty(), "and is not offered the party to share out")
	# A familiar called now is theirs.
	var form = load("res://data/familiars/rat.tres") if ResourceLoader.exists("res://data/familiars/rat.tres") else null
	if form != null:
		keeper.summon("alithia", form)
		await settle(2)
		ok(keeper.steerer == 1 and keeper.controlling, "a familiar called meanwhile is the other player's", "%d" % keeper.steerer)
		ok(keeper.swap_for(1), "theirs to give back")
		ok(keeper.swap_for(1) and keeper.steerer == 1, "and take again, without asking anybody")
		keeper.take_control(false)
		keeper.familiar.queue_free()
		keeper.familiar = null
	watch._company_goes_on(watch.company_left + 0.1)
	await settle(3)
	ok(Coop.controller_of("alithia") == 1 and Coop.controller_of("prometheus") == 1 and Coop.keys_of(1).size() == 2, "it over, who steers whom is as it was")
	Coop.leave(1)
	Coop.leave(0)
	Campaign.controllers = {}
	await close_map(m)


func illusions_on_a_map():
	log_line("======== the illusions on a map ========")
	var m = await open_map()
	Campaign.set_party(["alithia", "cyrus"], 64)
	Campaign.choose_subclass("alithia", "illusory_shepherd")
	await settle()
	var near := add_guard(m, "Near", m.post + Vector2i.RIGHT * 8, 180.0)
	var far := add_guard(m, "Far", m.post + Vector2i.RIGHT * 24, 180.0)
	var watch = await watch_it(m, m.post)
	var scene = m.scene
	# Phantom Noise: Iris first, and heard further than a Lure.
	var noise: SkillDefinition = SkillDatabase.skills.phantom_noise
	ok(OutsideMoves.use_of(noise) == OutsideMoves.Use.LURE, "Phantom Noise is a lure", "%d" % OutsideMoves.use_of(noise))
	ok(noise.lure_tiles > OutsideMoves.LURE_TILES, "heard further than a plain one", "%s" % noise.lure_tiles)
	ok(OutsideMoves.payment("alithia", noise).get("iris", 0) == 1, "paid through Iris", "%s" % [OutsideMoves.payment("alithia", noise)])
	var iris: int = Campaign.outside_gates_left("alithia")[1]
	ok(OutsideMoves.use(scene, "alithia", "phantom_noise"), "she casts it", OutsideMoves.refusal(scene, "alithia", "phantom_noise"))
	ok(Campaign.outside_gates_left("alithia")[1] == iris - 1, "a casting of Iris")
	ok(near.mood == Guard.Mood.INVESTIGATING, "the guard near it goes to look")
	# Seeming: a disguise, for the party, without a thing in the bags.
	var seeming: SkillDefinition = SkillDatabase.skills.seeming
	ok(OutsideMoves.use_of(seeming) == OutsideMoves.Use.SEEMING, "Seeming is its own")
	ok(watch.gaze_of(far) == watch.Gaze.SEES, "before it they are seen")
	ok(OutsideMoves.use(scene, "alithia", "seeming"), "she casts it", OutsideMoves.refusal(scene, "alithia", "seeming"))
	ok(watch.worn_by("alithia") == watch.SEEMING and watch.worn_by("cyrus") == watch.SEEMING, "all of them")
	ok(watch.gaze_of(far) == watch.Gaze.FOOLED, "and a guard takes them for his own", "%d" % watch.gaze_of(far))
	far.recognises = Guard.Recognises.ANY_DISGUISE
	ok(watch.gaze_of(far) == watch.Gaze.SEES, "but not one nothing fools")
	far.recognises = Guard.Recognises.OWN_ROLE
	watch._wear_off_seeming(1000.0)
	ok(watch.worn_by("alithia") == "", "and it wears off")
	# Mislead: Mnemosyne first; unseen, with a double ahead.
	var mislead: SkillDefinition = SkillDatabase.skills.mislead
	ok(OutsideMoves.use_of(mislead) == OutsideMoves.Use.MISLEAD, "Mislead is its own")
	ok(OutsideMoves.payment("alithia", mislead).get("iris", 0) == 2, "paid through Mnemosyne", "%s" % [OutsideMoves.payment("alithia", mislead)])
	ok(OutsideMoves.use(scene, "alithia", "mislead"), "she casts it", OutsideMoves.refusal(scene, "alithia", "mislead"))
	ok(watch.unseen("alithia"), "she is unseen")
	ok(not watch.unseen("cyrus"), "and nobody else")
	await close_map(m)
