extends "res://StealthHarness.gd"
## Local co-op (Coop; docs/multiplayer_plan.md; the designer, 2026-10-29):
## players and their devices, whom each steers and the save that keeps it, the
## gate that drops a press from anybody without the focus, a group per player
## walking at once with one camera and a leash, a press acted out by whoever
## pressed it, the guards seeing everybody, a fight's turns given to their
## player, a reaction asked of the reactor's, menus and conversations held by
## whoever began them, and the Players panel. And (the designer, 2026-10-31) a
## picture both players' on one screen, each with a pointer; a conversation's
## hold let go when its balloon goes; the camera drawn to whoever began one; and
## Party Management, portraits and all, up for whoever joins the party.


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
	await a_picture_together()
	await a_talk_let_go()
	await the_camera_to_a_talk()
	await someone_joins()
	one_player_to_a_machine()
	await a_puppet_eases()
	each_their_own_lead()
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


## Over a network each machine has one player: everything pressed there is theirs,
## and on somebody else's turn looking is still anybody's (the designer, 2026-11-04).
func one_player_to_a_machine():
	log_line("======== one player to a machine ========")
	Coop.reset()
	Coop.join(Coop.KEYBOARD)
	Coop.join(2)
	ok(Coop.player_here() == Coop.ANYONE, "two on one screen: nobody in particular")
	Coop.players[0].peer = 1
	Coop.players[1].peer = 5
	Coop.local_peer = 5
	Coop.networked = true
	ok(Coop.player_here() == 1, "over a network, one on this machine: them")
	ok(Coop.player_of_event(key_event(KEY_E)) == 1 and Coop.player_of_event(pad_button(0, JOY_BUTTON_A)) == 1,
		"  the keyboard and any pad here are theirs - joined with pad 3, clicking with the mouse")
	ok(Coop.pointer_device() == Coop.ANY_DEVICE, "  and any pad here points")
	Coop.focus = 0
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	var middle := InputEventMouseButton.new()
	middle.button_index = MOUSE_BUTTON_MIDDLE
	middle.pressed = true
	ok(not Coop.lets_through(click) and not Coop.lets_through(key_event(KEY_E)), "the other's turn: a click on the board, and a press, are dropped")
	ok(Coop.lets_through(InputEventMouseMotion.new()), "  the pointer goes about")
	ok(Coop.lets_through(wheel) and Coop.lets_through(middle), "  the view zooms and pans")
	for action in [&"character_sheet", &"pause", &"danger_view", &"zoom_toggle"]:
		var pressed := InputEventAction.new()
		pressed.action = action
		pressed.pressed = true
		ok(Coop.lets_through(pressed), "  %s is theirs" % action)
	var end_turn := InputEventAction.new()
	end_turn.action = &"end_turn"
	end_turn.pressed = true
	ok(not Coop.lets_through(end_turn), "  End Turn is not")
	var holder := Node.new()
	add_child(holder)
	MenuPause.hold(holder)
	ok(Coop.lets_through(click), "a menu or a question open on this machine: its clicks get through, whoever's turn it is")
	MenuPause.release(holder)
	holder.queue_free()
	ok(not Coop.lets_through(click), "  shut, they do not")
	Coop.focus = Coop.ANYONE
	Coop.networked = false
	Coop.local_peer = 0
	# On one screen a menu is whoever opened it's alone, as it was.
	Coop.reset()
	Coop.join(Coop.KEYBOARD)
	Coop.join(0)
	Coop.focus = 0
	var theirs := Node.new()
	add_child(theirs)
	MenuPause.hold(theirs)
	ok(not Coop.lets_through(pad_button(0, JOY_BUTTON_A)), "on one screen a menu held by Player 1 is theirs alone")
	MenuPause.release(theirs)
	theirs.queue_free()
	Coop.focus = Coop.ANYONE
	Coop.reset()
	log_line("")


## Another machine's group: eased to where it is said to be, walking as it goes -
## not put there in jumps with no walk (the designer, 2026-11-04: "No walking
## animation and very jittery when LAN or metwork player walks").
func a_puppet_eases():
	log_line("======== another machine's group ========")
	var m := await open_map()
	two_players(["cyrus"])
	await settle(3)
	var scene: ExplorationScene = m.scene
	# Whoever joined has Party Management up, which holds the game on one screen.
	if scene._sharing != null:
		(scene._sharing.find_child("PlayersPanel", true, false) as PlayersPanel).close()
		await settle(3)
	var theirs: ExplorationParty = scene.groups[1]
	theirs.puppet = true
	var from := theirs.position_of_leader()
	var to := from + Vector2.RIGHT * Grid.tiles(1.0)
	theirs.walk_to(to, false, true)
	ok(theirs.position_of_leader() == from, "said to be a tile on: not there at once")
	await settle(2)
	ok(theirs._walking, "  its walk plays")
	var along := theirs.position_of_leader()
	ok(along != from and along.distance_to(to) < from.distance_to(to), "  on its way", "%s" % along)
	await settle(3)
	ok(theirs._walking, "  the frames between the words too")
	await wait(0.8)
	ok(theirs.position_of_leader().distance_to(to) <= 1.0, "  and it gets there", "%s, %s" % [theirs.position_of_leader(), to])
	theirs.walk_to(to, false, false)
	await settle(3)
	ok(not theirs._walking, "said to stand: stands")
	var door := from + Vector2.RIGHT * Grid.tiles(8.0)
	theirs.walk_to(door, true, false)
	ok(theirs.position_of_leader() == door and theirs.facing_left(), "too far to have walked - a door, a blink: there at once")
	theirs.puppet = false
	await close_map(m)
	Coop.reset()


## Whose lead is whose (the designer, 2026-11-04: "Let them see and change their
## lead"), and a fight's party the same however it is asked (Net).
func each_their_own_lead():
	log_line("======== each their own lead ========")
	Coop.reset()
	Campaign.reset()
	Campaign.set_party(["alithia", "cyrus", "enfina", "prometheus"], 8)
	Coop.join(Coop.KEYBOARD)
	Coop.join(0)
	Campaign.controllers = {"cyrus": 1, "prometheus": 1}
	ok(Campaign.is_leading("alithia") and Campaign.is_leading("cyrus") and not Campaign.is_leading("enfina"), "on one screen each player's lead is lit")
	Campaign.lead_within(Coop.keys_of(1), "prometheus")
	ok(Coop.keys_of(1)[0] == "prometheus" and Coop.keys_of(0)[0] == "alithia", "the lead passed round one player's: the other's stands", "%s" % [Campaign.party_order])
	Campaign.lead_within(Coop.keys_of(1), "cyrus")
	ok(Array(Campaign.party_order) == ["alithia", "cyrus", "enfina", "prometheus"], "  and back", "%s" % [Campaign.party_order])
	Coop.acting = 1
	var with_them_acting: Array = Campaign.battle_party()
	Coop.acting = 0
	ok(Campaign.battle_party() == with_them_acting and with_them_acting == ["alithia", "cyrus", "enfina", "prometheus"],
		"who fights, in the marching order, whoever pressed last: both machines' fights begin the same", "%s" % [with_them_acting])
	Coop.acting = Coop.ANYONE
	Coop.players[0].peer = 1
	Coop.players[1].peer = 5
	Coop.local_peer = 5
	Coop.networked = true
	ok(Campaign.lead_here() == "cyrus" and Campaign.is_leading("cyrus") and not Campaign.is_leading("alithia"),
		"over a network: this machine's player's lead, lit - not the host's", Campaign.lead_here())
	Coop.networked = false
	Coop.local_peer = 0
	Campaign.controllers.clear()
	Coop.reset()
	log_line("")


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
	var open := panel.get_node_or_null("Rows/Open2")
	ok(panel._rows.get_child_count() == Coop.MAX_PLAYERS and panel.get_node_or_null("Rows/Player1") != null and open != null
		and open.find_children("*", "Button", true, false).is_empty(),
		"  a slot for each of the %d players there can be: Player 2's open" % Coop.MAX_PLAYERS)
	var says: String = open.get_node("Line/How/Join").text if open != null else ""
	var keyboard_taken: bool = Coop.players[0].device == Coop.KEYBOARD
	ok(says.begins_with("Press %s on %s" % [PlayersPanel.join_button(), "a pad" if keyboard_taken else "another pad"])
		and says.ends_with("to join") and says.contains("Enter on the keyboard") != keyboard_taken,
		"  saying how to take it - naming only what nobody plays with yet", says)
	panel._input(pad_button(2, JOY_BUTTON_A))
	await settle(2)
	ok(Coop.players.size() == 2 and Coop.players[1].device == 2, "pad 3's A: Player 2 joins with it")
	ok(panel.get_node_or_null("Rows/Open2") == null and panel.get_node_or_null("Rows/Player2") != null
		and panel._rows.get_child_count() == Coop.MAX_PLAYERS, "  into the open slot")
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


func a_picture_together():
	log_line("======== a picture on one screen, both players' ========")
	Campaign.set_party(["prometheus", "cyrus"], 8)
	two_players(["cyrus"])
	Coop.acting = 0
	DialogueManager.dialogue_started.emit(null)
	Coop.acting = Coop.ANYONE
	ok(Coop.focus == 0, "Player 1 begins a conversation: the focus theirs")
	Pictures.open("res://pictures/clues_desk.tscn")
	await settle(3)
	ok(Pictures.shared_here() and Pictures.first_pointer() == 0 and Pictures.second_pointer() == 1,
		"its picture is both players': the keyboard's the mouse, pad 1 a pointer of its own")
	ok(Coop.lets_through(pad_button(0, JOY_BUTTON_A)) and Coop.lets_through(key_event(KEY_E)), "  both get past the gate, the conversation's or not")
	ok(Coop.pointer_device() == Coop.KEYBOARD, "  and Player 2's pad never moves the mouse")
	var ledger: Hotspot = Pictures.current().find_child("LedgerSpot", true, false)
	ok(ledger != null, "the ledger on the desk")
	if ledger == null:
		Pictures.close()
		return
	Pictures.point_second(ledger.get_global_rect().get_center())
	var pointer = Pictures.find_child("SecondPointer", true, false)
	ok(ledger.pointed_by_other and pointer != null and pointer.visible and pointer.label.begins_with("Player 2"),
		"Player 2's pointer on it: outlined, and their name beside their pointer", pointer.label if pointer != null else "none")
	Input.parse_input_event(pad_button(0, JOY_BUTTON_A))
	await settle(2)
	Input.parse_input_event(pad_button(0, JOY_BUTTON_A, false))
	await settle(2)
	ok(ledger.was_examined() and Pictures.caption() != "", "  A: they look at it, and what it says is said", Pictures.caption())
	# Their own hand.
	Campaign.give_item("prometheus", "magnifying_glass")
	Pictures._refresh_bag()
	await settle(2)
	var glass: Button = Pictures.find_child("magnifying_glass", true, false)
	ok(glass != null, "the magnifying glass in the bag")
	if glass != null:
		Pictures.point_second(glass.get_global_rect().get_center())
		Input.parse_input_event(pad_button(0, JOY_BUTTON_A))
		await settle(2)
		Input.parse_input_event(pad_button(0, JOY_BUTTON_A, false))
		await settle(2)
		ok(Pictures.second_holding() == "magnifying_glass" and Pictures.holding() == "", "  A on it: in Player 2's hand, Player 1's empty",
			"%s / %s" % [Pictures.second_holding(), Pictures.holding()])
		Pictures.point_second(Pictures.current().get_global_rect().get_center())
		await settle(2)
		var ring: Control = Pictures._lens_ring
		ok(ring != null and ring.visible and (ring.position + ring.size / 2.0).distance_to(Pictures.second_at()) < 2.0,
			"  a lens in their hand looks round their pointer")
		Input.parse_input_event(pad_button(0, JOY_BUTTON_B))
		await settle(2)
		ok(Pictures.second_holding() == "" and Pictures.is_open(), "  B: put down, the picture still up")
	# A dial, with the shoulders.
	Pictures.open("res://pictures/clues_cabinet.tscn")
	await settle(3)
	var dials := Pictures.current().find_children("*", "PuzzleDial", true, false)
	ok(not dials.is_empty(), "the cabinet's lock, stacked on top")
	if not dials.is_empty():
		var dial: PuzzleDial = dials[0]
		var was := dial.value()
		Pictures.point_second(dial.get_global_rect().get_center())
		Input.parse_input_event(pad_button(0, JOY_BUTTON_RIGHT_SHOULDER))
		await settle(2)
		ok(dial.value() != was, "  RB on a dial: Player 2 turns it on", "%s -> %s" % [was, dial.value()])
		Input.parse_input_event(pad_button(0, JOY_BUTTON_LEFT_SHOULDER))
		await settle(2)
		ok(dial.value() == was, "  LB: and back")
	Pictures.back()
	await settle(2)
	# A piece, carried and put down.
	Pictures.open("res://pictures/clues_bin.tscn")
	await settle(3)
	var pieces := Pictures.current().find_children("*", "PuzzlePiece", true, false)
	ok(not pieces.is_empty(), "the torn letter in the bin")
	if not pieces.is_empty():
		var piece: PuzzlePiece = pieces[0]
		Pictures.point_second(piece.get_global_rect().get_center())
		Input.parse_input_event(pad_button(0, JOY_BUTTON_A))
		await settle(2)
		var carried: PuzzlePiece = Pictures._second_piece
		ok(carried != null, "  A on a piece: Player 2 picks it up")
		if carried != null:
			var slot: PuzzleSlot = carried.right_slot()
			Pictures.point_second(slot.get_global_rect().get_center())
			await settle(2)
			Input.parse_input_event(pad_button(0, JOY_BUTTON_A, false))
			await settle(2)
			ok(carried.sits_in == slot, "  carried to its place and let go: it sits in it")
	Pictures.close()
	await settle(2)
	ok(not Pictures.shared_here() and Coop.lets_through(key_event(KEY_E)) and not Coop.lets_through(pad_button(0, JOY_BUTTON_A)),
		"closed: the conversation's focus is Player 1's again")
	DialogueManager.dialogue_ended.emit(null)
	ok(Coop.focus == Coop.ANYONE, "  and over, everybody's")
	Coop.reset()
	log_line("")


func a_talk_let_go():
	log_line("======== a conversation gone without a word ========")
	two_players([])
	Coop.acting = 1
	DialogueManager.dialogue_started.emit(null)
	Coop.acting = Coop.ANYONE
	var balloon: Node = load("res://ui/dialogue_balloon.tscn").instantiate()
	get_tree().root.add_child(balloon)
	await settle(2)
	ok(Coop.focus == 1 and Coop.talking() and Coop.conversation_starter == 1, "Player 2 begins one: theirs, and the balloon up")
	balloon.queue_free()
	await settle(2)
	ok(Coop.focus == Coop.ANYONE and not Coop.talking() and Coop.conversation_starter == Coop.ANYONE,
		"its balloon gone with no end said - the scene changed under it: everybody's again")
	ok(Coop.lets_through(key_event(KEY_E)) and Coop.lets_through(pad_button(0, JOY_BUTTON_A)), "  both players' presses get through")
	Coop.reset()
	log_line("")


func the_camera_to_a_talk():
	log_line("======== the camera, to whoever began a conversation ========")
	var m := await open_map()
	for key in ["alithia", "prometheus"]:
		if not Campaign.party_order.has(key):
			Campaign.add_member(key)
	await settle(2)
	two_players(["cyrus"])
	await settle(3)
	var scene: ExplorationScene = m.scene
	var theirs: ExplorationParty = scene.groups.get(1)
	var main: ExplorationParty = scene._main_party
	var from := tile_at(m, main.position_of_leader())
	var far := find_tile(m, func(tile): return gap(tile, from) >= 8.0 and gap(tile, from) <= 9.0 and standable(m, tile))
	if theirs == null or far == NOWHERE:
		ok(false, "two groups, apart")
		await close_map(m)
		return
	theirs.teleport(at(m, far))
	await settle(3)
	Coop.acting = 1
	DialogueManager.dialogue_started.emit(null)
	Coop.acting = Coop.ANYONE
	for i in 90:
		await get_tree().process_frame
	ok(scene.conversation_shot == 1 and scene.camera.position.distance_to(theirs.leader.position) < Grid.tiles(1.0),
		"Player 2 begins one: the camera glides onto their leader", "%s vs %s" % [scene.camera.position, theirs.leader.position])
	DialogueManager.dialogue_ended.emit(null)
	for i in 90:
		await get_tree().process_frame
	var middle: Vector2 = (main.leader.position + theirs.leader.position) / 2.0
	ok(scene.conversation_shot == -1 and scene.camera.position.distance_to(middle) < Grid.tiles(1.0),
		"  over: back to framing both", "%s vs %s" % [scene.camera.position, middle])
	await close_map(m)
	Coop.reset()


func someone_joins():
	log_line("======== somebody joins: Party Management ========")
	var m := await open_map()
	if Campaign.party_order.has("enfina"):
		Campaign.remove_member("enfina")
	if not Campaign.party_order.has("alithia"):
		Campaign.add_member("alithia")
	two_players(["alithia"])
	await settle(3)
	var scene: ExplorationScene = m.scene
	ok(scene._sharing == null, "two players, the party shared out")
	Campaign.add_member("enfina")
	await settle(4)
	var panel: PlayersPanel = scene._sharing.find_child("PlayersPanel", true, false) if scene._sharing != null else null
	ok(panel != null and panel.management and panel.note.begins_with("Enfina joins"), "Enfina joins: Party Management comes up for who steers her",
		panel.note if panel != null else "none")
	var row: Node = panel.find_child("Player2", true, false) if panel != null else null
	var pick: Button = row.find_child("enfina", true, false) if row != null else null
	ok(pick != null and pick.icon != null, "  each of the party with their portrait")
	if pick != null:
		pick.pressed.emit()
		ok(Coop.controller_of("enfina") == 1, "  pressed on Player 2's row: Enfina is theirs")
		panel.close()
	await settle(3)
	Campaign.remove_member("enfina")
	Coop.reset()
	await settle(3)
	Campaign.add_member("enfina")
	await settle(4)
	ok(scene._sharing == null, "playing alone, somebody joining puts nothing up")
	await close_map(m)
