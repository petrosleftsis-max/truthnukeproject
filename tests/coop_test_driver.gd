extends "res://StealthHarness.gd"
## Local co-op (Coop; docs/multiplayer_plan.md; the designer, 2026-10-29):
## players and their devices, whom each steers and the save that keeps it, the
## gate that drops a press from anybody without the focus, a group per player
## walking at once with one camera and a leash, a press acted out by whoever
## pressed it, the guards seeing everybody, a fight's turns given to their
## player, a reaction asked of the reactor's, menus and conversations held by
## whoever began them, and the Players panel.


func suite() -> String:
	return "coop"


func time_limit() -> float:
	return 300.0


func run_sections():
	players_and_devices()
	the_gate()
	await walking_together()
	await watched_together()
	await turns_in_a_fight()
	await held_by_one()
	await the_panel()
	await pings()
	await sharing_out()
	await the_familiar_asked_for()
	Coop.reset()
	Campaign.controllers.clear()


func key_event(physical: Key, pressed: bool = true) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = physical
	event.pressed = pressed
	return event


func pad_button(device: int, button: JoyButton, pressed: bool = true) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = button
	event.pressed = pressed
	return event


## Two players: the keyboard, and pad 1 steering `theirs`.
func two_players(theirs: Array):
	Coop.reset()
	Campaign.controllers.clear()
	Coop.join(Coop.KEYBOARD)
	Coop.join(0)
	for key in theirs:
		Campaign.controllers[key] = 1
	Coop.players_changed.emit()


func players_and_devices():
	log_line("======== players and devices ========")
	Coop.reset()
	ok(not Coop.on(), "one player, or none: no co-op, everything as it was")
	ok(Coop.ordered(["a", "b"]) == ["a", "b"], "  and the party's order untouched")
	ok(Coop.join(Coop.KEYBOARD) == 0 and Coop.join(0) == 1, "the keyboard joins as Player 1, a pad as Player 2")
	ok(Coop.join(0) == -1, "  the same pad not twice")
	ok(Coop.join(3) == -1 and Coop.players.size() == 2, "two at most: a third is turned away")
	ok(Coop.on(), "  two: co-op")
	Campaign.reset()
	Campaign.set_party(["alithia", "cyrus", "enfina"], 1)
	Campaign.controllers = {"cyrus": 1}
	ok(Coop.controller_of("cyrus") == 1 and Coop.controller_of("alithia") == 0, "Cyrus is Player 2's; anybody unpicked is Player 1's")
	ok(Coop.keys_of(1) == ["cyrus"] and Coop.keys_of(0) == ["alithia", "enfina"], "  each player's in marching order", "%s %s" % [Coop.keys_of(0), Coop.keys_of(1)])
	Campaign.controllers["enfina"] = 3
	ok(Coop.controller_of("enfina") == 0, "  steered by a player who is not playing: Player 1's")
	Campaign.controllers.erase("enfina")
	Coop.acting = 1
	ok(Campaign.leader() == "cyrus", "Player 2 acting: their leader leads, for the moment", Campaign.leader())
	Coop.acting = Coop.ANYONE
	ok(Campaign.leader() == "alithia", "  and nobody acting, Player 1's")
	var saved := Campaign.snapshot("", Vector2.ZERO)
	ok(saved.get("controllers", {}) == {"cyrus": 1}, "whom each steers goes into a save")
	Coop.leave(1)
	ok(Coop.players.size() == 1 and Coop.controller_of("cyrus") == 0 and not Campaign.controllers.has("cyrus"), "Player 2 leaves: Cyrus is Player 1's again")
	log_line("")


func the_gate():
	log_line("======== the gate ========")
	Coop.reset()
	Coop.join(Coop.KEYBOARD)
	Coop.join(0)
	ok(Coop.player_of_event(key_event(KEY_E)) == 0 and Coop.player_of_event(pad_button(0, JOY_BUTTON_A)) == 1, "a key is Player 1's, pad 1's button Player 2's")
	ok(Coop.player_of_event(pad_button(3, JOY_BUTTON_A)) == Coop.ANYONE and not Coop.lets_through(pad_button(3, JOY_BUTTON_A)), "a pad nobody plays with: dropped")
	Coop.accepting_joins = true
	ok(Coop.lets_through(pad_button(3, JOY_BUTTON_A)), "  unless the Players panel is taking new players")
	Coop.accepting_joins = false
	ok(Coop.lets_through(key_event(KEY_E)) and Coop.lets_through(pad_button(0, JOY_BUTTON_A)), "nobody with the focus: everybody gets through")
	Coop.focus = 1
	ok(not Coop.lets_through(key_event(KEY_E)) and Coop.lets_through(pad_button(0, JOY_BUTTON_A)), "Player 2 with the focus: the keyboard is dropped, their pad is not")
	ok(Coop.acting == 1, "  and who pressed is noted (acting)")
	ok(Coop.pointer_device() == 0, "  only their pad drives the pointer")
	Coop.focus = 0
	ok(Coop.pointer_device() == Coop.KEYBOARD, "Player 1's: no pad points")
	Coop.focus = Coop.ANYONE
	ok(Coop.pointer_device() == Coop.ANY_DEVICE, "nobody's: any pad, as outside co-op")
	var holder := Node.new()
	Coop.take_focus(1, holder)
	var inner := Node.new()
	Coop.take_focus(0, inner)
	ok(Coop.focus == 0, "focus taken twice: the latest has it")
	Coop.let_go(holder)
	Coop.let_go(inner)
	ok(Coop.focus == Coop.ANYONE, "  let go in either order: back to nobody's")
	holder.free()
	inner.free()
	Coop.reset()
	log_line("")


func walking_together():
	log_line("======== walking together ========")
	var m := await open_map()
	for key in ["alithia", "prometheus"]:
		if not Campaign.party_order.has(key):
			Campaign.add_member(key)
	await settle(2)
	two_players(["cyrus", "prometheus"])
	await settle(3)
	var scene: ExplorationScene = m.scene
	ok(scene.groups.size() == 2 and scene.groups[0] == scene._main_party, "a group per player, Player 1's the party it always was", "%s" % [scene.groups.keys()])
	var theirs: ExplorationParty = scene.groups.get(1)
	if theirs == null:
		await close_map(m)
		return
	var main: ExplorationParty = scene._main_party
	ok(main.own_sprite_for("cyrus") == null and theirs.own_sprite_for("cyrus") != null and theirs.own_sprite_for("prometheus") != null,
		"  Cyrus and Prometheus walk in Player 2's")
	ok(main.sprite_for("cyrus") == theirs.own_sprite_for("cyrus"), "  and the party finds them there (companions)")
	ok(scene.party == main, "nobody pressing: the party is Player 1's")
	Coop.acting = 1
	ok(scene.party == theirs and theirs.own_sprite_for(Campaign.leader()) != null, "Player 2 pressing: theirs, and their leader", Campaign.leader())
	Coop.acting = Coop.ANYONE
	var main_at := main.position_of_leader()
	var their_at := theirs.position_of_leader()
	var walked := false
	for i in 30:
		if theirs._step(Vector2.RIGHT, 0.05) or theirs._step(Vector2.DOWN, 0.05) or theirs._step(Vector2.LEFT, 0.05):
			walked = true
	ok(walked and theirs.position_of_leader() != their_at and main.position_of_leader() == main_at, "Player 2's group walks; Player 1's stays")
	# By the pad itself, if a headless run keeps a pad's state.
	Input.parse_input_event(_axis(0, JOY_AXIS_LEFT_X, 1.0))
	await settle(2)
	if absf(Input.get_joy_axis(0, JOY_AXIS_LEFT_X)) > 0.5:
		ok(theirs.held_direction().x > 0.5 and main.held_direction() == Vector2.ZERO, "pad 1's stick walks Player 2 alone",
			"%s / %s" % [theirs.held_direction(), main.held_direction()])
		Input.parse_input_event(_axis(0, JOY_AXIS_LEFT_X, 0.0))
	else:
		log_line("  (no pad state in a headless run - the stick read is not tried)")
	Input.parse_input_event(key_event(KEY_D))
	await settle(1)
	if Input.is_physical_key_pressed(KEY_D):
		ok(main.held_direction().x > 0.5 and theirs.held_direction() == Vector2.ZERO, "the keyboard walks Player 1 alone")
	Input.parse_input_event(key_event(KEY_D, false))
	await settle(1)
	ok(scene._frame_groups() and scene.camera.position.distance_to((main.leader.position + theirs.leader.position) / 2.0) < 2.0,
		"one camera, on the middle of both")
	var far := find_tile(m, func(tile): return gap(tile, tile_at(m, main.position_of_leader())) >= 13.0 and standable(m, tile))
	if far != NOWHERE:
		theirs.teleport(at(m, far))
		var further: Vector2 = at(m, far) + (at(m, far) - main.position_of_leader()).normalized() * Grid.tiles(1.0)
		ok(not scene._within_leash(theirs, further), "the leash: no further from the others than %d tiles" % ExplorationScene.LEASH_TILES)
		ok(scene._within_leash(theirs, at(m, far).lerp(main.position_of_leader(), 0.2)), "  but back towards them, yes")
		theirs.teleport(their_at)
	scene.begin_blocking_interaction()
	ok(main.frozen and theirs.frozen and scene.is_holding(), "a conversation holds both groups")
	scene.end_blocking_interaction()
	ok(not main.frozen and not theirs.frozen, "  and lets both go")
	var main_leader := Campaign.leader()
	Coop.acting = 1
	var their_leader := Campaign.leader()
	scene.swap_leader()
	Coop.acting = 1
	ok(Campaign.leader() != their_leader and Coop.controller_of(Campaign.leader()) == 1, "Tab, by Player 2: round their own", Campaign.leader())
	Coop.acting = Coop.ANYONE
	ok(Campaign.leader() == main_leader, "  Player 1's lead untouched", Campaign.leader())
	Coop.acting = 1
	var staying := Campaign.leader()
	ok(scene.stay_here(), "Stay Here, by Player 2: theirs stays", staying)
	await settle(2)
	Coop.acting = 1
	ok(Campaign.leader() != staying and Coop.controller_of(Campaign.leader()) == 1 and scene.staying.has(staying), "  the other of theirs leads them", Campaign.leader())
	Coop.acting = Coop.ANYONE
	ok(Campaign.leader() == main_leader, "  Player 1's lead untouched", Campaign.leader())
	theirs = scene.groups.get(1)
	ok(theirs != null and theirs.stayers.has(theirs.own_sprite_for(staying)), "  standing apart in their group")
	await close_map(m)
	Coop.reset()


func _axis(device: int, axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = axis
	event.axis_value = value
	return event


func watched_together():
	log_line("======== watched together ========")
	var m := await open_map()
	Campaign.add_member("alithia")
	await settle(2)
	two_players(["cyrus"])
	await settle(3)
	var scene: ExplorationScene = m.scene
	var from := tile_at(m, m.party.position_of_leader())
	var watch: StealthWatch = await watch_it(m, from)
	var theirs: ExplorationParty = scene.groups.get(1)
	var spot := find_tile(m, func(tile): return gap(tile, from) >= 3.0 and gap(tile, from) <= 6.0 and standable(m, tile))
	if theirs == null or spot == NOWHERE:
		ok(false, "(Player 2's group and somewhere for it)")
		await close_map(m)
		return
	theirs.teleport(at(m, spot))
	await settle(2)
	var standing := watch._party_standing().filter(func(one): return one.key == "cyrus")
	ok(standing.size() == 1 and standing[0].tile == spot, "the guards see Cyrus where Player 2 walked him")
	var fight := watch.build_fight()
	var his := fight.spawns.filter(func(each): return each.combatant_key == "cyrus")
	ok(his.size() == 1 and gap(his[0].position, spot) <= 1.0, "  and a fight starts with him there")
	await close_map(m)
	Coop.reset()


func turns_in_a_fight():
	log_line("======== a fight's turns ========")
	Campaign.reset()
	Campaign.set_party(["alithia", "cyrus"], 8)
	two_players(["cyrus"])
	var encounter: EncounterDefinition = load("res://data/encounters/encounter_02_sappers.tres").duplicate(true)
	encounter.fighters.assign(["alithia", "cyrus"])
	encounter.skip_deployment = true
	Campaign.current_encounter = encounter
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(8)
	var combat: Combat = game.get_node("VisualCombat")
	var by := {}
	for comb in combat.combatants:
		by[comb.get("combatant_key", "")] = comb
	ok(by.has("alithia") and by.has("cyrus"), "(both in the fight)")
	if not by.has("cyrus"):
		game.queue_free()
		await settle()
		return
	_give_turn(combat, by.cyrus)
	ok(Coop.focus == 1, "Cyrus's turn: Player 2 has the board", "focus %d" % Coop.focus)
	ok(not Coop.lets_through(key_event(KEY_E)) and Coop.lets_through(pad_button(0, JOY_BUTTON_A)), "  the keyboard can't act for him")
	_give_turn(combat, by.alithia)
	ok(Coop.focus == 0 and Coop.lets_through(key_event(KEY_E)) and not Coop.lets_through(pad_button(0, JOY_BUTTON_A)), "Alithia's: Player 1's, and the pad waits")
	combat.game_ui._announce_turn(by.cyrus)
	var said: String = combat.game_ui._turn_banner._label.text
	ok("Player 2" in said, "the turn banner says whose", said)
	var enemy: Dictionary = {}
	for comb in combat.combatants:
		if comb.get("side", 0) == 1 and comb.get("alive", false):
			enemy = comb
			break
	var prompt: ReactionPrompt = combat.reaction_prompt
	if prompt != null and not enemy.is_empty():
		_asked = false
		_ask(prompt, by.cyrus, enemy)
		await settle(2)
		ok(Coop.focus == 1, "a reaction of Cyrus's: Player 2 is asked, on Alithia's turn", "focus %d" % Coop.focus)
		prompt._answer_with(false)
		await until(func(): return _asked, 2.0)
		ok(Coop.focus == 0, "  answered: back to Player 1")
	game.queue_free()
	await settle(3)
	Coop.reset()
	log_line("")


var _asked := false


## The reaction question, put up without waiting on it here.
func _ask(prompt: ReactionPrompt, reactor: Dictionary, enemy: Dictionary):
	await prompt.ask(reactor, enemy, SkillDatabase.skills["rapier"])
	_asked = true


func _give_turn(combat: Combat, comb: Dictionary):
	combat.current_combatant = combat.combatants.find(comb)
	combat.controller.set_controlled_combatant(comb)


func held_by_one():
	log_line("======== a menu or a conversation, by one player ========")
	Coop.reset()
	Coop.join(Coop.KEYBOARD)
	Coop.join(0)
	var menu := Node.new()
	get_tree().root.add_child(menu)
	Coop.acting = 1
	MenuPause.hold(menu)
	Coop.acting = Coop.ANYONE
	ok(Coop.focus == 1 and get_tree().paused, "Player 2 opens a menu: the game holds, and the menu is theirs")
	ok(not Coop.lets_through(key_event(KEY_E)), "  the keyboard can't reach into it")
	MenuPause.release(menu)
	ok(Coop.focus == Coop.ANYONE and not get_tree().paused, "  closed: everybody's again")
	menu.queue_free()
	Coop.acting = 1
	DialogueManager.dialogue_started.emit(null)
	Coop.acting = Coop.ANYONE
	ok(Coop.focus == 1, "Player 2 starts a conversation: theirs to answer")
	DialogueManager.dialogue_ended.emit(null)
	ok(Coop.focus == Coop.ANYONE, "  over: everybody's")
	DialogueManager.dialogue_started.emit(null)
	ok(Coop.focus == 0, "one nobody pressed for (walked into): Player 1's")
	DialogueManager.dialogue_ended.emit(null)
	await settle()
	Coop.reset()
	log_line("")


func the_panel():
	log_line("======== the Players panel ========")
	Coop.reset()
	Campaign.controllers.clear()
	var layer := CanvasLayer.new()
	get_tree().root.add_child(layer)
	var panel := PlayersPanel.new()
	layer.add_child(panel)
	await settle(3)
	ok(Coop.players.size() == 1 and Coop.accepting_joins, "opened: whoever opened it is Player 1, and others may join")
	panel._input(pad_button(2, JOY_BUTTON_A))
	await settle(2)
	ok(Coop.players.size() == 2 and Coop.players[1].device == 2, "pad 3's A: Player 2 joins with it")
	var row := panel.find_child("Player2", true, false)
	var pick: Button = row.find_child("enfina", true, false) if row != null else null
	ok(pick != null, "  a button for each character on their row")
	if pick != null:
		pick.pressed.emit()
		ok(Coop.controller_of("enfina") == 1, "  pressed: Enfina is Player 2's")
	panel.close()
	layer.queue_free()
	await settle(2)
	ok(not Coop.accepting_joins, "closed: nobody else joins")
	log_line("")


func pings():
	log_line("======== pings ========")
	var m := await open_map()
	if not Campaign.party_order.has("cyrus"):
		Campaign.add_member("cyrus")
	two_players(["cyrus"])
	await settle(3)
	var scene: ExplorationScene = m.scene
	var from := tile_at(m, m.party.position_of_leader())
	var spot := find_tile(m, func(tile): return gap(tile, from) >= 3.0 and gap(tile, from) <= 5.0 and standable(m, tile))
	var guard := add_guard(m, "Watchman", spot, 0.0)
	await watch_it(m, from)
	Pings.clear()
	var made := Pings.ping(1, at(m, spot))
	ok(Pings.pings.size() == 1 and made.label == "Watchman", "Player 2 pings the watchman: named", "%s" % made.get("label", ""))
	var log_text: RichTextLabel = scene.game_ui.get_node_or_null("Actions/Information/Text")
	ok(log_text == null or "Player 2" in log_text.get_parsed_text() and "pings" in log_text.get_parsed_text(), "  and said in the log")
	var empty := find_tile(m, func(tile): return gap(tile, from) >= 2.0 and gap(tile, spot) >= 3.0 and standable(m, tile))
	ok(Pings.ping(1, at(m, empty)).label == "here", "a spot with nothing on it: \"here\"")
	Pings.ping(1, at(m, empty))
	ok(Pings.pings.filter(func(each): return each.player == 1).size() == Pings.PINGS_EACH, "  no more than %d at once each: the oldest goes" % Pings.PINGS_EACH)
	Coop.focus = 0
	var event := InputEventKey.new()
	event.physical_keycode = KEY_Z
	event.pressed = true
	var pad := pad_button(0, JOY_BUTTON_MISC1)
	ok(Coop.lets_through(pad) and Pings.has_method("ping"), "on somebody else's turn too: a ping gets past the gate")
	Coop.focus = Coop.ANYONE
	var before := Pings.pings.size()
	Pings._input(pad)
	ok(Pings.pings.size() >= before and Pings.pings.back().player == 1, "pad 1's Share: Player 2's ping")
	Pings._process(Pings.PING_SECONDS + 0.5)
	ok(Pings.pings.is_empty(), "and %d seconds on, gone" % int(Pings.PING_SECONDS))
	await close_map(m)
	Coop.reset()
	Pings.clear()
	var alone := pad_button(0, JOY_BUTTON_MISC1)
	Pings._input(alone)
	ok(Pings.pings.is_empty(), "playing alone, Share is Hide UI's, not a ping")


func sharing_out():
	log_line("======== a player left steering nobody ========")
	var m := await open_map()
	for key in ["alithia", "prometheus"]:
		if not Campaign.party_order.has(key):
			Campaign.add_member(key)
	await settle(2)
	two_players(["cyrus"])
	await settle(3)
	var scene: ExplorationScene = m.scene
	ok(scene._sharing == null, "everybody steers somebody: nothing to share out")
	Campaign.remove_member("cyrus")
	await settle(4)
	ok(scene._sharing != null and Coop.stranded() == [1], "Cyrus leaves the party: Player 2 steers nobody, and the Players panel comes up")
	var panel := scene._sharing.find_child("PlayersPanel", true, false) as PlayersPanel if scene._sharing != null else null
	var row: Node = panel.find_child("Player2", true, false) if panel != null else null
	ok(panel != null and panel.only_party and row != null and row.find_child("cyrus", true, false) == null and row.find_child("prometheus", true, false) != null,
		"  the party as it stands, to share out")
	if row != null and row.find_child("prometheus", true, false) != null:
		row.find_child("prometheus", true, false).pressed.emit()
		panel.close()
		await settle(3)
		ok(scene._sharing == null and Coop.keys_of(1) == ["prometheus"], "Prometheus is Player 2's now", "%s" % [Coop.keys_of(1)])
		ok(scene.groups.has(1) and scene.groups[1].own_sprite_for("prometheus") != null, "  walking in their group")
	Campaign.controllers.erase("prometheus")
	Coop.players_changed.emit()
	await settle(3)
	ok(scene._sharing != null, "left with nobody again, a different way: offered again")
	if scene._sharing != null:
		(scene._sharing.find_child("PlayersPanel", true, false) as PlayersPanel).close()
	await settle(3)
	ok(scene._sharing == null, "Done leaves it as it is")
	await settle(4)
	ok(scene._sharing == null, "  and it is not offered again for the same")
	await close_map(m)
	Coop.reset()


func the_familiar_asked_for():
	log_line("======== the familiar, asked for ========")
	var m := await open_map()
	for key in ["alithia", "cyrus"]:
		if not Campaign.party_order.has(key):
			Campaign.add_member(key)
	Campaign.set_leader("alithia")
	await settle(2)
	two_players(["cyrus"])
	await settle(3)
	var scene: ExplorationScene = m.scene
	var keeper: FamiliarKeeper = scene.familiar_keeper
	var mine: ExplorationParty = scene._main_party
	var theirs: ExplorationParty = scene.groups.get(1)
	ok(theirs != null and scene.summon_familiar() and keeper.steerer == 0 and mine.rooted and not theirs.rooted,
		"Alithia (Player 1's) calls it: Player 1 steers it, their group waits")
	keeper.perch()
	ok(keeper.perched() and not keeper.swap_for(1) and keeper.asking == null, "on her shoulder, Player 2 can't ask for it")
	keeper.swap_for(0)
	ok(keeper.controlling and keeper.steerer == 0 and not keeper.perched(), "Player 1's Tab: off her shoulder, theirs again")
	ok(keeper.swap_for(1) and is_instance_valid(keeper.asking) and Coop.focus == 0, "Player 2's Tab: Player 1 is asked, and only they can answer")
	ok(not Coop.lets_through(pad_button(0, JOY_BUTTON_A)) and Coop.lets_through(key_event(KEY_E)), "  Player 2's pad waits on the answer")
	keeper.asking.answer(false)
	await settle(2)
	ok(keeper.steerer == 0 and keeper.asking == null and Coop.focus == Coop.ANYONE, "refused: Player 1 keeps it")
	keeper.swap_for(1)
	keeper.asking.answer(true)
	await settle(2)
	ok(keeper.steerer == 1 and keeper.familiar.player == 1 and theirs.rooted and not mine.rooted, "allowed: Player 2 steers it, and it is their group that waits")
	Coop.acting = 0
	ok(not scene.controlling_familiar() and not keeper.may_dismiss(1) and keeper.may_dismiss(0), "  Player 1 walks free; only Player 1 lets it go")
	Coop.acting = Coop.ANYONE
	ok(keeper.swap_for(1) and not keeper.controlling and not theirs.rooted, "Player 2's Tab again: handed back")
	scene.dismiss_familiar()
	await close_map(m)
	Coop.reset()
