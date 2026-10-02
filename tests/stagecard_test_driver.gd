extends "res://StealthHarness.gd"
## How a stealth map went: the tally and the rank on the card at the way out,
## the objectives under the bar - and starting it over from the pause menu.


func suite() -> String:
	return "stagecard"


func run_sections():
	await the_tally()
	await things_to_do()
	await the_card()
	await starting_over()


## Ghost, Shadow, Brawler - and what was counted on the way.
func the_tally():
	var m = await open_map()
	var post: Vector2i = m.post
	var sentry = add_guard(m, "Sentry", post, 0.0)
	sentry.pockets.assign(["pebble"])
	var watch = await watch_it(m, out_of_sight_of(m, row(post)))
	log_line("======== the tally ========")
	ok(watch.rank() == "Ghost" and watch.stats.noticed == 0, "nobody has noticed him: a ghost")
	await wait(0.3)
	ok(watch.stats.seconds > 0.2, "the time is counted", "%.2fs" % watch.stats.seconds)
	m.party.teleport(at(m, post + Vector2i.RIGHT * 3))
	await wait(0.15)
	m.party.teleport(at(m, m.away))
	ok(watch.stats.noticed == 1 and watch.rank() == "Shadow", "seen once: noticed, but never caught - a shadow", "%d" % watch.stats.noticed)
	settle_guard(watch, sentry, 180.0)
	m.party.teleport(at(m, post + Vector2i.RIGHT))
	await settle()
	ok(watch.pick_pocket() and watch.stats.pockets == 1, "a pocket picked is counted")
	ok(watch.take_down() and watch.stats.takedowns == 1, "a takedown")
	watch._caught_by(add_guard(m, "Late", post + Vector2i.RIGHT * 2, 0.0))
	ok(watch.stats.caught == 1 and watch.rank() == "Brawler", "caught: it came to blows")
	var card = watch.scorecard()
	ok(card.rank == "Brawler" and card.fights == 1 and card.takedowns == 1 and card.pockets == 1 and card.noticed >= 1,
		"and the card has it all", "%s" % [card])
	await close_map(m)


## Objectives: a flag to set, something to carry off, and some that hold only
## as long as nothing goes wrong.
func things_to_do():
	var m = await open_map()
	var post: Vector2i = m.post
	var sentry = add_guard(m, "Sentry", post, 0.0)
	var plant := PlantSpot.new()
	plant.item_key = "pebble"
	plant.planted_flag = "letter_left"
	place(m, plant, post + Vector2i.LEFT * 2, "Desk")
	var wants := {}
	for each in [["Leave the letter", StealthObjective.Kind.FLAG], ["Take the potion", StealthObjective.Kind.CARRY_ITEM],
			["Hurt nobody", StealthObjective.Kind.NOBODY_HARMED], ["No takedowns", StealthObjective.Kind.NO_TAKEDOWNS],
			["Never alarmed", StealthObjective.Kind.NEVER_ALARMED]]:
		var objective := StealthObjective.new()
		objective.description = each[0]
		objective.kind = each[1]
		objective.flag = "letter_left"
		objective.item_key = "cure_potion"
		m.map.add_child(objective)
		wants[each[0]] = objective
	var watch = await watch_it(m, behind(m, post))
	log_line("======== to do ========")
	var states = func(): return watch.objectives().map(func(o): return o[1])
	ok(states.call() == ["open", "open", "open", "open", "open"], "all to do, to begin with", "%s" % [states.call()])
	await settle()
	var listed = watch.find_children("*", "", true, false).filter(func(n): return n is StealthWatch._ObjectiveList)
	ok(listed.size() == 1 and listed[0].visible, "listed under the bar")
	log_line("======== done ========")
	Campaign.give_item(m.leader, "pebble")
	m.party.teleport(at(m, post + Vector2i.LEFT * 2 + Vector2i.RIGHT))
	ok(plant.is_available() and plant.prompt == "Leave the pebble here", "beside the desk with it: E leaves it", plant.prompt)
	plant.use(m.scene)
	ok(plant.planted and Campaign.count_of(m.leader, "pebble") == 0 and watch.objective_state(wants["Leave the letter"]) == "done",
		"left there: done")
	Campaign.give_item(m.leader, "cure_potion")
	ok(watch.objective_state(wants["Take the potion"]) == "done", "the potion taken: done")
	Campaign.take_item(m.leader, "cure_potion")
	ok(watch.objective_state(wants["Take the potion"]) == "done", "and it stays done, drunk or not")
	log_line("======== lost ========")
	m.party.teleport(at(m, behind(m, post)))
	await settle()
	watch.take_down()
	ok(watch.objective_state(wants["No takedowns"]) == "lost" and watch.objective_state(wants["Hurt nobody"]) == "lost",
		"a takedown: no takedowns, and nobody hurt, both lost")
	ok(watch.objective_state(wants["Never alarmed"]) == "open", "never alarmed still holds")
	var at_the_end = watch.objectives(true).map(func(o): return o[1])
	ok(at_the_end == ["done", "done", "lost", "lost", "done"], "at the way out, what still holds is done", "%s" % [at_the_end])
	watch.alert = 1.0
	await settle()
	ok(watch.objective_state(wants["Never alarmed"]) == "lost", "the map Alarmed, and that goes too")
	await close_map(m)


## The card at the way out: rank, tally, objectives, and Continue.
func the_card():
	log_line("======== the card ========")
	var card := StealthScorecard.new()
	get_tree().root.add_child(card)
	var continued := [false]
	card.open({"rank": "Shadow", "says": "Noticed, but never caught.", "seconds": 95.0, "noticed": 2, "fights": 0,
		"takedowns": 1, "poisoned": 0, "bodies_found": 0, "pockets": 1,
		"objectives": [["Take the potion", "done"], ["Hurt nobody", "lost"]]}, func(): continued[0] = true)
	await settle()
	var texts = card.find_children("*", "Label", true, false).map(func(l): return l.text)
	ok(texts.has("Shadow") and texts.has("Noticed, but never caught."), "the rank, and what it means")
	ok(texts.has("1:35") and texts.has("Times noticed"), "the tally", "%s" % [texts])
	ok(texts.has("Take the potion - done") and texts.has("Hurt nobody - missed"), "and what there was to do")
	card.continue_button.pressed.emit()
	await settle()
	ok(continued[0] and not is_instance_valid(card), "Continue carries on, and it goes")
	log_line("")


## Restart Stage: the stage as it was when he walked in - bag, flags and all.
func starting_over():
	log_line("======== starting over ========")
	var menu: MainMenu = load("res://main_menu.tscn").instantiate()
	menu._set_up_stage(MainMenu.STEALTH_STAGES[0])
	menu.free()
	var scene: ExplorationScene = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(scene)
	await settle(4)
	for node in get_tree().root.find_children("*", "", true, false):
		if node.scene_file_path == BALLOON:
			node.queue_free()
	scene.end_blocking_interaction()
	var leader: String = Campaign.party_members()[0].key
	var arrived: Vector2 = scene.party.position_of_leader()
	ok(Campaign.can_restart_stealth(), "walked onto a stealth stage, there is somewhere to start over from")
	var pebbles = Campaign.count_of(leader, "pebble")
	var pause = scene.get_node("PauseUI")
	pause._show_panel(pause.get_node("PausePanel"), pause._pause_buttons)
	ok(pause._restart.visible and pause._pause_buttons.has(pause._restart), "the pause menu offers it")
	pause._close()
	# Mid-fade into a fight a catch started: that fight is on its way whatever
	# happens, so starting over is not offered - it used to empty the fight
	# out from under the fade and land in the sewer ambush.
	var fight := EncounterDefinition.new()
	Campaign.current_encounter = fight
	SceneTransition._changing = true
	ok(not Campaign.can_restart_stealth(), "while the screen fades into something else, there is no starting over")
	Campaign.restart_stealth()
	ok(Campaign.current_encounter == fight, "and asking anyway changes nothing")
	pause._show_panel(pause.get_node("PausePanel"), pause._pause_buttons)
	ok(not pause._restart.visible, "the pause menu does not offer it")
	pause._close()
	SceneTransition._changing = false
	Campaign.current_encounter = null
	# Things change: a pebble thrown, a flag set, the party moved on.
	Campaign.take_item(leader, "pebble")
	Campaign.set_flag("stage1_keys")
	scene.party.teleport(arrived + Vector2(Grid.tiles(3), 0))
	Campaign.stealth_state[Campaign.current_map] = {"defeated": ["KeyHolder"]}
	pause._on_restart_pressed()
	scene.queue_free()
	var again = await until(func(): return get_tree().current_scene is ExplorationScene and get_tree().current_scene != scene, 6.0)
	ok(again, "Restart Stage: the stage again")
	if again:
		var fresh: ExplorationScene = get_tree().current_scene
		await settle(4)
		ok(Campaign.count_of(leader, "pebble") == pebbles and not Campaign.flag("stage1_keys"), "with his bag and the flags as they were")
		ok(fresh.party.position_of_leader().distance_to(arrived) < 1.0, "where he walked in")
		ok(fresh.stealth != null and fresh.stealth.guards.any(func(g): return String(g.name) == "KeyHolder"),
			"and everybody back at their posts")
	if is_instance_valid(scene):
		scene.queue_free()
	await settle()
	log_line("")
