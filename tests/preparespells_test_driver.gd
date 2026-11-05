extends "res://StealthHarness.gd"
## Preparing spells (Campaign "Preparing spells"; the designer, 2026-11-05): so many by
## level, chosen at a long rest and as the Dungeon Demo begins, a lock keeping one through
## the next long rest, only those prepared in a fight or on a map, and a page on the sheet
## once somebody has finished. A window only for whoever steers that character.


func suite() -> String:
	return "preparespells"


func time_limit() -> float:
	return 200.0


func run_sections():
	the_numbers()
	nobody_asked_yet()
	await the_window()
	await a_long_rest()
	await into_a_fight()
	await on_a_map()
	await the_dungeon_demo()
	await waiting_on_somebody()


func the_numbers():
	log_line("======== how many ========")
	ok(Stats.spells_prepared_at(1) == 5, "5 at level 1", "%d" % Stats.spells_prepared_at(1))
	ok(Stats.spells_prepared_at(64) == 35, "35 at the top", "%d" % Stats.spells_prepared_at(64))
	var straight := true
	var last := 5
	for level in range(2, 65):
		var now := Stats.spells_prepared_at(level)
		if now < last or now > last + 1:
			straight = false
		last = now
	ok(straight, "and never more than one more a level between: a straight line")
	ok(Stats.spells_prepared_at(8) == 8 and Stats.spells_prepared_at(14) == 11 and Stats.spells_prepared_at(24) == 16, "8 at 8, 11 at 14, 16 at 24",
		"%d %d %d" % [Stats.spells_prepared_at(8), Stats.spells_prepared_at(14), Stats.spells_prepared_at(24)])
	log_line("")


func nobody_asked_yet():
	log_line("======== nobody asked yet ========")
	Campaign.reset()
	Campaign.set_party(["alithia", "enfina"], 14)
	ok(Campaign.is_prepared("alithia", "heal") and Campaign.is_prepared("alithia", "terror"), "with no list yet, everything they know")
	var choices := Campaign.prepare_choices("alithia")
	ok(choices.has("heal") and choices.has("compel"), "what she could prepare", "%d" % choices.size())
	ok(not choices.has("grace"), "not what she has not reached")
	ok(not choices.has("votive_flame"), "and only spells")
	ok(Campaign.prepare_choices("enfina").is_empty() and Campaign.casters_to_prepare() == ["alithia"], "Enfina has nothing to prepare", "%s" % [Campaign.casters_to_prepare()])
	log_line("")


func _panel_of(scene) -> PrepareSpells:
	return scene.preparing


func the_window():
	log_line("======== the window ========")
	var m = await open_map()
	Campaign.set_party(["prometheus", "alithia", "enfina"], 14)
	Campaign.asks_to_prepare = true
	Campaign.prepare_due = true
	await settle(4)
	var scene = m.scene
	var panel := _panel_of(scene)
	ok(panel != null, "put up on the map")
	if panel == null:
		await close_map(m)
		return
	ok(panel.preparing == "prometheus", "Prometheus first", panel.preparing)
	ok(MenuPause.is_held(), "and the game stands")
	ok(panel._title.text.contains("Prometheus"), "named", panel._title.text)
	var limit := Campaign.prepare_limit()
	ok(limit == 11, "11 at 14", "%d" % limit)
	ok(panel._count.text == "Prepared 0 of 11", "counted", panel._count.text)
	# Only what he knows: he starts with five.
	var offered: Array = panel._spell_buttons.keys()
	ok(offered.has("fire_blast") and not offered.has("wildfire"), "what he knows, not what he has yet to learn", "%s" % [offered])
	panel._spell_buttons["fire_blast"].set_pressed(true)
	panel._lock_buttons["wind_shot"].set_pressed(true)
	ok(panel._picked.has("fire_blast") and panel._picked.has("wind_shot"), "picked; a lock prepares it too", "%s" % [panel._picked])
	ok(panel._count.text == "Prepared 2 of 11", "counted", panel._count.text)
	panel._spell_buttons["wind_shot"].set_pressed(false)
	ok(panel._picked.has("wind_shot") and panel._spell_buttons["wind_shot"].button_pressed, "a locked one cannot be let go", panel._note.text)
	panel._lock_buttons["wind_shot"].set_pressed(false)
	panel._lock_buttons["wind_shot"].set_pressed(true)
	panel._done.pressed.emit()
	await settle()
	ok(Campaign.prepared_list("prometheus").size() == 2 and Campaign.locked_spells.prometheus == ["wind_shot"], "Done: his", "%s" % [Campaign.prepared_list("prometheus")])
	ok(Campaign.has_readied("prometheus"), "and he has finished")
	ok(panel.preparing == "alithia", "then Alithia", panel.preparing)
	# Hers: as many as she can have, and no more.
	var keys: Array = panel._spell_buttons.keys()
	for i in keys.size():
		panel._spell_buttons[keys[i]].set_pressed(true)
	ok(panel._picked.size() == limit, "no more than she can have", "%d of %d offered" % [panel._picked.size(), keys.size()])
	ok(panel._note.text.contains("%d" % limit), "and she is told", panel._note.text)
	panel._done.pressed.emit()
	await settle(3)
	ok(Campaign.preparing_left().is_empty(), "nobody left")
	ok(not Campaign.prepare_due, "nothing due")
	ok(not is_instance_valid(panel) or panel.is_queued_for_deletion(), "and it is gone")
	ok(not MenuPause.is_held(), "and the game goes on")
	Campaign.asks_to_prepare = false
	await close_map(m)


func a_long_rest():
	log_line("======== a long rest ========")
	Campaign.reset()
	Campaign.set_party(["alithia"], 14)
	Campaign.set_prepared("alithia", ["heal", "cleanse", "compel"], ["heal"])
	Campaign.finish_preparing("alithia")
	ok(Campaign.is_prepared("alithia", "cleanse") and not Campaign.is_prepared("alithia", "terror"), "her list stands")
	ok(Campaign.has_readied("alithia"), "and her page")
	Campaign.long_rest()
	ok(Campaign.prepared_list("alithia") == ["heal"], "after a long rest, only what she locked", "%s" % [Campaign.prepared_list("alithia")])
	ok(Campaign.prepare_due, "and she is to choose again")
	ok(not Campaign.has_readied("alithia"), "not finished yet")
	ok(Campaign.last_prepared.alithia == ["heal", "cleanse", "compel"], "what she had is remembered, to prepare the same")
	ok(Campaign.is_prepared("alithia", "cleanse") and not Campaign.is_prepared("alithia", "terror"), "and until she has been asked it still stands: no spell lost to a window she never saw")
	# The window offers the same again.
	var panel := PrepareSpells.new()
	get_tree().root.add_child(panel)
	await settle()
	ok(panel._picked == ["heal"] and panel._same.visible, "locked already in, and Same As Last Time")
	panel._same.pressed.emit()
	ok(panel._picked.size() == 3 and panel._picked.has("cleanse"), "the same as last time", "%s" % [panel._picked])
	# The lock comes off, and the spell goes.
	panel._lock_buttons["heal"].set_pressed(false)
	panel._spell_buttons["heal"].set_pressed(false)
	ok(not panel._picked.has("heal"), "with the lock off, she can let it go")
	panel._done.pressed.emit()
	await settle(3)
	ok(not Campaign.is_prepared("alithia", "heal"), "asked now, what she let go is gone")
	ok(not Campaign.prepared_list("alithia").has("heal") and Campaign.locked_spells.alithia.is_empty(), "and it has gone", "%s" % [Campaign.prepared_list("alithia")])
	# A save keeps it.
	var state := Campaign.snapshot("", Vector2.ZERO)
	ok(state.prepared_spells.alithia == Campaign.prepared_list("alithia") and state.has("locked_spells") and state.has("last_prepared"), "kept in a save")
	log_line("")


func into_a_fight():
	log_line("======== into a fight ========")
	Campaign.reset()
	Campaign.set_party(["enfina", "cyrus", "alithia"], 14)
	Campaign.set_prepared("alithia", ["heal", "compel"], [])
	Campaign.finish_preparing("alithia")
	Campaign.current_map = "res://maps/crossroads_explore.tscn"
	Campaign.return_to_position = true
	Campaign.current_encounter = load("res://data/encounters/encounter_03_watcher.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(6)
	var combat: Combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(2)
	var alithia := {}
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == "alithia":
			alithia = comb
	ok(alithia.skill_list.has("heal") and alithia.skill_list.has("compel"), "what she prepared she has")
	ok(not alithia.skill_list.has("cleanse") and not alithia.skill_list.has("terror"), "and nothing else she could cast", "%s" % [alithia.skill_list])
	ok(alithia.skill_list.has("votive_flame") and alithia.skill_list.has("intuition"), "her other moves are not spells: they stay")
	# The sheet: a page once she has finished.
	var sheet: CharacterSheet = null
	for node in get_tree().get_nodes_in_group(&"pad_menu"):
		if node is CharacterSheet:
			sheet = node
	ok(sheet != null, "the sheet")
	if sheet != null:
		ok(sheet._pages_of({"key": "alithia"}) == 4, "she has the Prepared page", "%d" % sheet._pages_of({"key": "alithia"}))
		ok(sheet._pages_of({"key": "enfina"}) == 3, "Enfina has not")
		sheet.open_on("Alithia")
		await settle()
		sheet._show_page(3)
		await settle()
		var names := []
		for row in sheet._stat_rows.get_children():
			names.append(String(row.name))
		ok(names.has("Move_heal") and names.has("Move_compel") and not names.has("Move_cleanse"), "with what she prepared on it", "%s" % [names])
		sheet._show_page(1)
		await settle()
		ok(sheet._stat_rows.find_child("Move_heal", true, false) != null and sheet._stat_rows.find_child("Move_cleanse", true, false) == null, "in a fight the Moves page has what she can use")
		sheet.close()
	game.queue_free()
	await settle(3)
	log_line("")


func on_a_map():
	log_line("======== on a map ========")
	# What goes through Iris (Invisibility) is left behind with the rest.
	Campaign.reset()
	Campaign.set_party(["prometheus"], 14)
	Campaign.learned_spells = {"prometheus": ["invisibility", "fire_blast"]}
	var through_iris: bool = Campaign.outside_spells("prometheus").has("invisibility")
	Campaign.set_prepared("prometheus", ["fire_blast"], [])
	Campaign.finish_preparing("prometheus")
	ok(through_iris and not Campaign.outside_spells("prometheus").has("invisibility"), "a spell not prepared is not cast through Iris either")
	Campaign.reset()
	Campaign.set_party(["alithia"], 14)
	ok(OutsideMoves.moves_of("alithia").has("cleanse"), "known and no list: on the panel")
	Campaign.set_prepared("alithia", ["heal"], [])
	ok(OutsideMoves.moves_of("alithia").has("heal") and not OutsideMoves.moves_of("alithia").has("cleanse"), "with a list, only what is on it")
	log_line("")


func the_dungeon_demo():
	log_line("======== as the Dungeon Demo begins ========")
	var demo: DungeonDefinition = load("res://data/dungeons/dungeon_demo.tres")
	ok(demo.prepares_spells, "it says so")
	Campaign.reset()
	Campaign.asks_to_prepare = true
	Campaign.start_dungeon(demo)
	ok(Campaign.prepare_due, "due before anything else")
	# Knowing every spell in there, Prometheus has the lot to choose from.
	ok(Campaign.prepare_choices("prometheus").has("wildfire"), "he has the lot to choose from")
	ok(await until(func(): return get_tree().current_scene is ExplorationScene and get_tree().current_scene.preparing != null, 40.0), "the map opens on the window")
	var scene = get_tree().current_scene
	if scene is ExplorationScene and scene.preparing != null:
		var panel: PrepareSpells = scene.preparing
		ok(panel.preparing == Campaign.casters_to_prepare()[0], "the first caster", panel.preparing)
		panel._open_sheets()
		await settle()
		var sheet: CharacterSheet = null
		for node in get_tree().get_nodes_in_group(&"pad_menu"):
			if node is CharacterSheet:
				sheet = node
		ok(sheet != null and sheet._open, "the character sheets open over it")
		if sheet != null:
			sheet.close()
		await settle()
		panel._glossary.pressed.emit()
		await settle()
		ok(panel._glossary_panel != null and panel._glossary_panel.visible, "and the glossary")
		panel._glossary_panel.visible = false
		while is_instance_valid(panel) and not panel.is_queued_for_deletion() and panel.preparing != "":
			panel._done.pressed.emit()
			await settle()
		ok(not Campaign.prepare_due, "everybody done")
		Campaign.asks_to_prepare = false
		await settle()
		get_tree().current_scene.queue_free()
		await settle()
	Campaign.asks_to_prepare = false
	log_line("")


func waiting_on_somebody():
	log_line("======== waiting on somebody ========")
	# Two players, on one machine playing at being two: whoever has no caster waits.
	Campaign.reset()
	Campaign.set_party(["enfina", "alithia"], 14)
	Coop.join(Coop.KEYBOARD)
	Coop.join(0)
	Campaign.controllers = {"alithia": 1}
	Coop.networked = true
	var mine := Coop.local_peer
	# Player 2 is on the other machine.
	Coop.players[1].peer = mine + 1
	var panel := PrepareSpells.new()
	get_tree().root.add_child(panel)
	await settle()
	ok(Campaign.preparing_left() == ["alithia"], "Alithia still to prepare")
	ok(panel.own_left().is_empty(), "and she is the other player's")
	ok(panel.waiting, "so this one waits")
	ok(panel._title.text.contains("Waiting for") and panel._title.text.contains(Coop.name_of(1)), "and is told for whom", panel._title.text)
	ok(not panel._done.visible and not panel._scroll.visible, "with no window of hers to see")
	ok(panel._sheets.visible and panel._glossary.visible, "but the sheets and the glossary")
	ok(not MenuPause.is_held(), "not a menu keeping what comes from the other machine")
	# They finish, on their machine.
	Campaign.prepared_spells["alithia"] = ["heal"]
	Campaign.spells_readied["alithia"] = true
	await settle(3)
	ok(not is_instance_valid(panel) or panel.is_queued_for_deletion(), "they finish, and it is gone")
	Coop.networked = false
	Coop.players[1].peer = mine
	Coop.leave(1)
	Coop.leave(0)
	Campaign.controllers = {}
	log_line("")
