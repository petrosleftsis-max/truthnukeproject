extends "res://StealthHarness.gd"
## Gamepads: telling a pad from the keyboard and mouse, naming its buttons, and
## the pointer it drives - which is the mouse, so a hotspot lights up under it,
## a click on a tile walks there and a puzzle piece drags. Then each place the
## pad is played: walking about and sneaking, the battle board, the pictures,
## the menus View opens, and the pause menu.
##
## Everything a pad does here arrives as the window would hand it over, through
## Input.parse_input_event, from device 0.


func suite() -> String:
	return "pad"


func time_limit() -> float:
	return 420.0


func run_sections():
	Pad.warps = false
	# The harness boots into a battle. Each section brings what it needs, and a
	# board left lying about would have the pointer thinking it was on it.
	var booted = get_tree().current_scene
	if booted != null:
		booted.queue_free()
		await settle()
	await actions_and_names()
	await walking_and_sneaking()
	await throwing_and_hands()
	await the_menus()
	await on_the_board()
	await in_the_pictures()
	await battle_select()
	await volume_by_pad()
	await reaching_every_tile()
	await skipping_dialogue()


## --- Pressing things, the way a pad does ---


func button(which: JoyButton, down: bool):
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = which
	event.pressed = down
	event.pressure = 1.0 if down else 0.0
	Input.parse_input_event(event)


func tap(which: JoyButton):
	button(which, true)
	await settle(2)
	button(which, false)
	await settle(2)


func stick(axis: JoyAxis, value: float):
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)


## Holds `axis` at `value` for `frames`, then lets it go.
func push(axis: JoyAxis, value: float, frames: int = 10):
	stick(axis, value)
	await settle(frames)
	stick(axis, 0.0)
	await settle(2)


func key(code: Key):
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await settle(1)
	await settle(1)


## A real mouse moving to `at`, in the game's own pixels.
func mouse_to(at: Vector2):
	var event := InputEventMouseMotion.new()
	event.position = get_tree().root.get_final_transform() * at
	event.global_position = event.position
	Input.parse_input_event(event)
	await settle(2)


func wake_the_pad():
	if not Pad.using_pad:
		# A light touch on a trigger nothing listens to that lightly.
		stick(JOY_AXIS_TRIGGER_RIGHT, 0.45)
		await settle(2)
		stick(JOY_AXIS_TRIGGER_RIGHT, 0.0)
		await settle(2)


## The camera brought round to the party, as walking would have: a teleport
## leaves it where it was.
func follow(m: Dictionary):
	m.scene._follow_camera(m.party.position_of_leader())
	await settle(2)


## Where `node` in the world is on the screen.
func screen_of(world: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world


## Where the middle of `control` is on the screen.
func middle_of(control: Control) -> Vector2:
	return control.get_global_transform_with_canvas() * (control.size / 2.0)


## --- Sections ---


func actions_and_names():
	log_line("======== the actions, and what they are called ========")
	var wanted := ["ui_accept", "ui_cancel", "pause", "menus", "menus_previous", "menus_next", "inventory",
		"journal", "character_sheet", "pointer_click", "pointer_left", "pointer_right", "pointer_up",
		"pointer_down", "look_left", "look_right", "look_up", "look_down", "move_left", "move_right",
		"move_up", "move_down", "interact", "swap_leader", "dash", "listen", "throw", "vault", "ambush",
		"take_off_disguise", "next_disguise", "take_down", "pick_pocket", "creep", "patience",
		"pan_left", "pan_right", "pan_up", "pan_down", "tile_left", "tile_right", "tile_up", "tile_down",
		"danger_view", "end_turn", "undo_move", "skill_previous", "skill_next", "skill_tab", "zoom_toggle"]
	var missing := wanted.filter(func(action): return not InputMap.has_action(action))
	ok(missing.is_empty(), "every action the game asks for is in the input map", "%s" % [missing])
	var all_devices := true
	for action in wanted:
		for event in InputMap.action_get_events(action) if InputMap.has_action(action) else []:
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				all_devices = all_devices and event.device == -1
	ok(all_devices, "and every pad binding answers any pad, not only the first one plugged in")
	ok(not Pad.using_pad, "nothing touched yet: keyboard and mouse")
	ok(Pad.key(&"interact") == "E" and Pad.key(&"end_turn") == "Space" and Pad.key(&"ui_cancel") == "Esc",
		"the keyboard's names: E, Space, Esc", "%s %s %s" % [Pad.key(&"interact"), Pad.key(&"end_turn"), Pad.key(&"ui_cancel")])
	ok(Pad.key(&"take_down", "Left click") == "Left click", "and the mouse's half, which no key is",
		Pad.key(&"take_down", "Left click"))
	ok(Pad.hint("Back", &"ui_cancel") == "Back (Esc)" and Pad.hint("Creep", &"next_disguise") == "Creep",
		"a hint puts the key in brackets, and leaves them off with nothing to press", Pad.hint("Back", &"ui_cancel"))
	var changes := [0]
	var counter := func(): changes[0] += 1
	Pad.changed.connect(counter)
	stick(JOY_AXIS_LEFT_X, 0.2)
	await settle(2)
	ok(not Pad.using_pad, "a resting stick's drift is not somebody picking up the pad")
	stick(JOY_AXIS_LEFT_X, 0.0)
	await tap(JOY_BUTTON_B)
	ok(Pad.using_pad and changes[0] == 1, "a button is: the pad is in use, and anything naming keys is told",
		"%d" % changes[0])
	ok(Pad.key(&"interact") == "A" and Pad.key(&"throw") == "RT" and Pad.key(&"patience") == "LT"
		and Pad.key(&"vault") == "D-pad Up" and Pad.key(&"swap_leader") == "RS" and Pad.key(&"menus") == "View",
		"now the pad's names", "%s %s %s %s %s %s" % [Pad.key(&"interact"), Pad.key(&"throw"), Pad.key(&"patience"),
			Pad.key(&"vault"), Pad.key(&"swap_leader"), Pad.key(&"menus")])
	ok(Pad.key(&"take_down", "Left click") == "X" and Pad.hint("Back", &"ui_cancel") == "Back (B)",
		"the mouse's clicks are buttons too", Pad.key(&"take_down", "Left click"))
	ok(Pad.key(&"creep") == "" and Pad.key([&"journal", &"menus"]) == "View",
		"Ctrl has no button - the stick creeps - and the journal is under View")
	ok(Pad.layout_named("PS5 Controller") == "playstation" and Pad.layout_named("DualSense Wireless Controller") == "playstation"
		and Pad.layout_named("Nintendo Switch Pro Controller") == "nintendo"
		and Pad.layout_named("Xbox Series Controller") == "xbox" and Pad.layout_named("") == "xbox",
		"what a pad calls itself says whose names to use")
	Pad.layout = "playstation"
	ok(Pad.key(&"interact") == "Cross" and Pad.key(&"pause") == "Options" and Pad.key(&"throw") == "R2",
		"a PlayStation pad's", "%s %s %s" % [Pad.key(&"interact"), Pad.key(&"pause"), Pad.key(&"throw")])
	Pad.layout = "nintendo"
	ok(Pad.key(&"interact") == "B" and Pad.key(&"ui_cancel") == "A", "a Nintendo one's, its A and B the other way round")
	Pad.layout = "xbox"
	await key(KEY_K)
	ok(not Pad.using_pad and changes[0] == 2, "a key: back to the keyboard", "%d" % changes[0])
	await tap(JOY_BUTTON_B)
	var where := Pad.pointer()
	await mouse_to(where + Vector2(2, 1))
	ok(Pad.using_pad, "the mouse twitching a pixel or two is not the mouse being used - the pointer moving it does that")
	Pad._warped.append(where + Vector2(80, 0))
	await mouse_to(where + Vector2(80, 0))
	ok(Pad.using_pad, "nor is the system late in saying the mouse got to where the pointer sent it a moment ago")
	Pad._warped.clear()
	await mouse_to(where + Vector2(300, 200))
	ok(not Pad.using_pad and Pad.pointer().distance_to(where + Vector2(300, 200)) < 1.0,
		"moved properly, the mouse has it back, and the pointer starts from there next time")
	Pad.changed.disconnect(counter)

	log_line("")
	log_line("======== a trigger goes down once ========")
	var downs := [0]
	var count_downs := func(event): if Pad.went_down(event, &"throw"): downs[0] += 1
	get_tree().root.window_input.connect(count_downs)
	stick(JOY_AXIS_TRIGGER_RIGHT, 0.3)
	await settle(2)
	ok(downs[0] == 0, "not pressed far enough")
	stick(JOY_AXIS_TRIGGER_RIGHT, 0.8)
	stick(JOY_AXIS_TRIGGER_RIGHT, 0.9)
	await settle(2)
	stick(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await settle(2)
	ok(downs[0] == 1, "squeezed further and further, it went down the once", "%d" % downs[0])
	stick(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await settle(2)
	stick(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await settle(2)
	ok(downs[0] == 2, "let go and squeezed again, twice", "%d" % downs[0])
	stick(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await settle(2)
	get_tree().root.window_input.disconnect(count_downs)
	log_line("")


func walking_and_sneaking():
	var m = await open_map()
	var post: Vector2i = m.post
	var sentry = add_guard(m, "Sentry", post, 0.0)
	sentry.route_known_flag = "pad_knows_the_round"
	Campaign.set_flag("pad_knows_the_round", true)
	var watch = await watch_it(m, out_of_sight_of(m, row(post)))
	await follow(m)
	var bar: StealthBar = watch._bar
	var ui = m.scene.game_ui

	log_line("======== walking about ========")
	await wake_the_pad()
	ok(Pad.mode() == Pad.Mode.WALK, "on a map, walking about")
	ok(not Pad.pointer_showing(), "no pointer: the left stick walks and A is use")
	var from: Vector2 = m.party.position_of_leader()
	stick(JOY_AXIS_LEFT_X, 1.0)
	await settle(3)
	ok(m.party.held_direction().is_equal_approx(Vector2.RIGHT) and not m.party.light_touch(), "the stick pushed all the way is walking")
	ok(not watch.creeping(), "and not creeping")
	await settle(10)
	ok(m.party.position_of_leader().x > from.x, "he walks", "%s -> %s" % [from, m.party.position_of_leader()])
	stick(JOY_AXIS_LEFT_X, 0.4)
	await settle(3)
	ok(m.party.light_touch() and watch.creeping(), "only a little way, and he creeps",
		"%.2f" % m.party.held_direction().length())
	ok(bar._status.text.begins_with("Creeping"), "and the bar says so", bar._status.text)
	stick(JOY_AXIS_LEFT_X, 0.0)
	await settle(3)
	ok(m.party.held_direction() == Vector2.ZERO and not watch.creeping(), "let go, standing still")
	var d := InputEventKey.new()
	d.physical_keycode = KEY_D
	d.keycode = KEY_D
	d.pressed = true
	Input.parse_input_event(d)
	await settle(2)
	ok(m.party.held_direction().is_equal_approx(Vector2.RIGHT) and not m.party.light_touch(),
		"a key is all or nothing - it never creeps by itself")
	d = d.duplicate()
	d.pressed = false
	Input.parse_input_event(d)
	await settle(2)
	await wake_the_pad()
	stick(JOY_AXIS_TRIGGER_LEFT, 1.0)
	await settle(3)
	ok(watch.patient(), "LT held is Patience")
	stick(JOY_AXIS_TRIGGER_LEFT, 0.0)
	await settle(3)
	ok(not watch.patient(), "let go, it is not")

	log_line("")
	log_line("======== the pointer, on the right stick ========")
	var before := Pad.pointer()
	var standing: Vector2 = m.party.position_of_leader()
	stick(JOY_AXIS_RIGHT_X, 1.0)
	await settle(10)
	stick(JOY_AXIS_RIGHT_X, 0.0)
	await settle(2)
	ok(Pad.pointer_showing() and Pad.pointer().x > before.x + 20.0, "the right stick brings it out and moves it",
		"%s -> %s" % [before, Pad.pointer()])
	ok(m.party.position_of_leader().is_equal_approx(standing), "without walking anybody")
	# Near enough him to have him on screen.
	m.party.teleport(at(m, behind(m, post)))
	await follow(m)
	Pad.point_at(screen_of(sentry.global_position))
	await settle(3)
	ok(watch.route_shown(sentry), "on a guard whose round is known, it shows it")
	ok(await until(func(): return not Pad.pointer_showing(), Pad.HIDE_AFTER + 1.0), "left alone a while, it goes again")
	ok(not watch.route_shown(sentry), "and points at nobody once it has")

	log_line("")
	log_line("======== the buttons ========")
	ok(bar._dash.text == "Dash (RB)" and bar._ears.text == "Ears (LB)" and bar._creep.text == "Creep"
		and bar._patience.text == "Patience (LT)", "the bar names a pad's buttons",
		"%s, %s, %s, %s" % [bar._dash.text, bar._ears.text, bar._creep.text, bar._patience.text])
	ok(bar._creep.tooltip_text.contains("stick only a little way"), "and says how a pad creeps")
	ok(bar._alert.tooltip_text.contains("(A beside one)"), "a word with a guard is A - not the R it once said", bar._alert.tooltip_text)
	# Listening is for a map where guards are only seen in sight.
	m.setup.guards_seen_only_in_sight = true
	var cooldown_before: float = watch.ears_cooldown()
	await tap(JOY_BUTTON_LEFT_SHOULDER)
	ok(watch.ears_left() > 0.0 and cooldown_before == 0.0, "LB listens")
	stick(JOY_AXIS_LEFT_X, 1.0)
	await settle(2)
	await tap(JOY_BUTTON_RIGHT_SHOULDER)
	ok(watch.dash_cooldown() > 0.0, "RB dashes, the way the stick is pushed")
	stick(JOY_AXIS_LEFT_X, 0.0)
	await settle(2)
	await key(KEY_K)
	ok(bar._dash.text.begins_with("Dash") and bar._ears.text.begins_with("Listening"), "(and the keyboard's names come back)")
	await close_map(m)


func throwing_and_hands():
	var m = await open_map()
	var post: Vector2i = m.post
	var sentry = add_guard(m, "Sentry", post, 0.0)
	sentry.pockets.assign(["pebble"])
	var back_of_him = behind(m, post)
	Campaign.give_item(m.leader, "pebble")
	Campaign.give_item(m.leader, "pebble")
	Campaign.give_item(m.leader, "pebble")
	Campaign.give_item(m.leader, "sleep_dart")
	Campaign.give_item(m.leader, "priest_robes")
	var from: Vector2i = post + Vector2i.LEFT * 2
	var watch = await watch_it(m, from)
	await follow(m)
	var bar: StealthBar = watch._bar
	var landing: Vector2i = post + Vector2i.RIGHT * 3

	log_line("======== throwing ========")
	await wake_the_pad()
	ok(bar._throw.text == "Throw Pebble x3 (RT)", "the bar says RT throws", bar._throw.text)
	stick(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await settle(3)
	stick(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await settle(3)
	ok(watch.is_aiming() and watch.aiming() == "pebble", "RT starts aiming")
	ok(Pad.pointer_showing() and Pad.pointer().distance_to(screen_of(sentry.global_position)) < 2.0,
		"with the pointer on the guard to throw at, not wherever it was left",
		"%s, him at %s" % [Pad.pointer(), screen_of(sentry.global_position)])
	ok(bar._throw.text == "Aiming Pebble - RT or A (D-pad: next)", "and the bar says how to let go", bar._throw.text)
	await tap(JOY_BUTTON_DPAD_RIGHT)
	ok(watch.aiming() == "sleep_dart", "the D-pad's right: the next thing to throw")
	await tap(JOY_BUTTON_DPAD_LEFT)
	ok(watch.aiming() == "pebble", "and its left, back again")
	ok(watch.worn_by(m.leader) == "", "(neither of which touched the disguise in his bag)")
	await wait(Pad.HIDE_AFTER + 0.5)
	ok(Pad.pointer_showing(), "aiming, the pointer stays up however long it is left")
	Pad.point_at(screen_of(at(m, landing)))
	await settle(2)
	stick(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await settle(3)
	stick(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await settle(3)
	ok(not watch.is_aiming() and Campaign.count_of(m.leader, "pebble") == 2, "RT again throws it where the pointer is")
	stick(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await settle(3)
	stick(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await settle(3)
	await tap(JOY_BUTTON_B)
	ok(not watch.is_aiming() and Campaign.count_of(m.leader, "pebble") == 2, "B puts it away")
	stick(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await settle(3)
	stick(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await settle(3)
	Pad.point_at(screen_of(at(m, landing)))
	await settle(2)
	await tap(JOY_BUTTON_A)
	await settle(2)
	ok(not watch.is_aiming() and Campaign.count_of(m.leader, "pebble") == 1, "and A, while aiming, is the mouse's click: thrown")
	settle_guard(watch, sentry)
	await settle(2)

	log_line("")
	log_line("======== hands on him ========")
	m.party.teleport(at(m, back_of_him))
	await follow(m)
	await settle(3)
	ok(watch.takedown_target() == sentry and watch.pocket_target() == sentry, "(behind him, unnoticed)")
	var shown = watch.prompt()
	ok(not shown.is_empty() and shown[1].size() >= 2 and shown[1][0][0] == "X" and shown[1][1][0] == "Y",
		"the prompt over him says X and Y, not clicks", "%s" % [shown[1] if not shown.is_empty() else "none"])
	ok(bar._takedown.text == "Take down (X)" and bar._pocket.text == "Pick pocket (Y)", "and so does the bar",
		"%s, %s" % [bar._takedown.text, bar._pocket.text])
	await tap(JOY_BUTTON_Y)
	ok(sentry.picked, "Y picks his pocket")
	await tap(JOY_BUTTON_X)
	ok(sentry.knocked_out, "X knocks him out")
	await tap(JOY_BUTTON_X)
	ok(watch.dragging() == sentry, "X again, beside him, takes up the body")
	ok(bar._drag.text == "Drop body (X)" or bar._drag.text == "Hide body (X)", "the bar saying X puts him down", bar._drag.text)
	await tap(JOY_BUTTON_X)
	ok(watch.dragging() == null, "and X puts him down")

	log_line("")
	log_line("======== disguises on the D-pad ========")
	m.party.teleport(at(m, m.away))
	await follow(m)
	await settle(3)
	await tap(JOY_BUTTON_DPAD_RIGHT)
	ok(watch._changing_into == "priest_robes", "the D-pad's right puts on the next disguise he carries")
	ok(await until(func(): return watch.worn_by(m.leader) == "priest_robes", StealthWatch.DISGUISE_SECONDS + 2.0), "(and on it goes)")
	ok(bar._hide.text == "Hide (D-pad Left)", "the bar says how to take it off", bar._hide.text)
	await tap(JOY_BUTTON_DPAD_LEFT)
	ok(watch.worn_by(m.leader) == "", "and the D-pad's left takes it off")
	await key(KEY_K)
	await close_map(m)


func the_menus():
	var m = await open_map()
	var watch = await watch_it(m, m.post + Vector2i.LEFT * 3)
	# As it is in the game, where the journal asks which scene it is in.
	get_tree().current_scene = m.scene
	var sheet = m.scene.get_node("CharacterSheet")
	var inventory = m.scene.get_node("InventoryUI")
	var pause = m.scene.get_node("PauseUI")

	log_line("======== View, and LB and RB ========")
	await wake_the_pad()
	await tap(JOY_BUTTON_BACK)
	ok(Journal.is_open(), "on a map, View opens the journal first")
	ok(Pad.mode() == Pad.Mode.MENU, "which is a menu")
	await tap(JOY_BUTTON_RIGHT_SHOULDER)
	ok(not Journal.is_open() and inventory.is_open(), "RB: on to the inventory")
	ok(Pad.pointer_showing(), "with the pointer up, the slots being things to click")
	ok(watch.ears_left() == 0.0, "(and LB and RB, with a menu open, are not the ears and the dash)")
	await tap(JOY_BUTTON_RIGHT_SHOULDER)
	ok(not inventory.is_open() and sheet.is_open(), "RB: the character sheet")
	await tap(JOY_BUTTON_RIGHT_SHOULDER)
	ok(not sheet.is_open() and Journal.is_open(), "RB: round to the journal again")
	await tap(JOY_BUTTON_LEFT_SHOULDER)
	ok(not Journal.is_open() and sheet.is_open(), "LB goes the other way")
	await tap(JOY_BUTTON_BACK)
	ok(not sheet.is_open() and not Journal.is_open() and not inventory.is_open(), "View again closes it")
	ok(Pad.mode() == Pad.Mode.WALK, "and it is walking about again")
	await tap(JOY_BUTTON_BACK)
	await tap(JOY_BUTTON_RIGHT_SHOULDER)
	await tap(JOY_BUTTON_B)
	ok(not inventory.is_open(), "B closes the inventory, as Escape does")
	ok(inventory._hint.text.contains("Press A on a slot") and inventory._hint.text.contains("View or B to close"),
		"which says what to press", inventory._hint.text)

	log_line("")
	log_line("======== pause ========")
	await tap(JOY_BUTTON_B)
	ok(not pause.get_node("PausePanel").visible, "B is back, not pause: nothing to go back from, nothing happens")
	await tap(JOY_BUTTON_START)
	ok(pause.get_node("PausePanel").visible, "Menu pauses")
	ok(not Pad.pointer_showing(), "with no pointer: the D-pad goes from button to button")
	await tap(JOY_BUTTON_DPAD_DOWN)
	ok(get_viewport().gui_get_focus_owner() != null, "and it does")
	await tap(JOY_BUTTON_B)
	ok(not pause.get_node("PausePanel").visible, "B closes it")
	await tap(JOY_BUTTON_START)
	await tap(JOY_BUTTON_START)
	ok(not pause.get_node("PausePanel").visible, "and so does Menu")
	await tap(JOY_BUTTON_BACK)
	ok(Journal.is_open(), "(the journal open)")
	await tap(JOY_BUTTON_START)
	ok(not pause.get_node("PausePanel").visible, "Menu does not open the pause menu over another menu")
	await tap(JOY_BUTTON_B)
	ok(not Journal.is_open(), "B closes that one")
	await tap(JOY_BUTTON_START)
	await tap(JOY_BUTTON_DPAD_DOWN)
	ok(get_viewport().gui_get_focus_owner() == pause._pause_buttons[0], "(the D-pad on Glossary)")
	await tap(JOY_BUTTON_A)
	await settle(2)
	ok(pause._glossary_showing() and Pad.pointer_showing(),
		"A opens the glossary - which the D-pad cannot go round, so the pointer comes up for it")
	await tap(JOY_BUTTON_B)
	await settle(2)
	ok(pause.get_node("PausePanel").visible and not Pad.pointer_showing(), "B, back to the pause menu, and the pointer goes again")
	pause._close()
	await settle(2)

	log_line("")
	log_line("======== A, where it is not the pointer's ========")
	await tap(JOY_BUTTON_START)
	var focus_on_demand = pause.get_node_or_null("FocusOnDemand")
	stick(JOY_AXIS_RIGHT_X, 1.0)
	await settle(4)
	stick(JOY_AXIS_RIGHT_X, 0.0)
	await settle(2)
	ok(Pad.pointer_showing() and get_viewport().gui_get_focus_owner() == null,
		"in a menu, the right stick brings the pointer out instead", "%s" % [focus_on_demand])
	var resume: Control = pause._pause_buttons[0]
	var clicked := [0]
	var count_click := func(): clicked[0] += 1
	for b in pause._pause_buttons:
		b.pressed.connect(count_click)
	var panel: Control = pause.get_node("PausePanel")
	Pad.point_at(panel.get_global_transform_with_canvas() * Vector2(panel.size.x / 2.0, -20.0))
	await settle(2)
	await tap(JOY_BUTTON_A)
	ok(get_viewport().gui_get_focus_owner() == null and clicked[0] == 0,
		"A with the pointer up is a click where it is - on nothing, it does nothing, and lights no button up")
	Pad.point_at(middle_of(resume))
	await settle(2)
	await tap(JOY_BUTTON_A)
	ok(clicked[0] == 1, "and on a button, presses it", "%d" % clicked[0])
	for b in pause._pause_buttons:
		if b.pressed.is_connected(count_click):
			b.pressed.disconnect(count_click)
	# What it pressed was the glossary, which is still up, and still holds the
	# game.
	pause._close()
	await key(KEY_K)
	await close_map(m)


func on_the_board():
	Campaign.reset()
	Campaign.current_encounter = load("res://data/encounters/encounter_02_sappers.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await settle(6)
	var combat = game.get_node("VisualCombat")
	var controller = combat.controller
	var ui = combat.game_ui
	var camera = combat.camera

	log_line("======== placing the party ========")
	ok(combat.deployment_active, "(this fight starts with the party to place)")
	await wake_the_pad()
	ok(Pad.mode() == Pad.Mode.BOARD and Pad.pointer_showing(), "the board, with the pointer up")
	var places: Array = controller.pad_tiles()
	var spots: Array = combat.deployment_tiles
	ok(not places.is_empty() and places.all(func(tile): return spots.has(tile) or controller.get_combatant_at_position(tile) != null),
		"the cursor goes only between the tiles the party can be placed on", "%d tiles" % places.size())
	ok(places.has(controller.pad_cursor()), "and starts on one of them", "%s" % controller.pad_cursor())
	var banner: String = ui.get_node("Actions/SelectTargetMessage/MarginContainer/Label").text
	ok(banner.begins_with("A on a hero") and banner.contains("X, then A on Begin Battle"), "the banner says what to press on a pad", banner)
	var seen := {controller.pad_cursor(): true}
	for i in places.size() + 2:
		await tap(JOY_BUTTON_DPAD_RIGHT)
		seen[controller.pad_cursor()] = true
		await tap(JOY_BUTTON_DPAD_DOWN)
		seen[controller.pad_cursor()] = true
	ok(seen.keys().all(func(tile): return places.has(tile)), "stepping about never leaves them")
	seen.clear()
	for i in places.size():
		await tap(JOY_BUTTON_RIGHT_SHOULDER)
		seen[controller.pad_cursor()] = true
	ok(seen.size() == places.size(), "and RB goes through every one of them", "%d of %d" % [seen.size(), places.size()])
	var hero = null
	for comb in combat.combatants:
		if comb.alive and comb.side == 0:
			hero = comb
			break
	var empty_spot := Vector2i(-1, -1)
	for tile in spots:
		if controller.get_combatant_at_position(tile) == null:
			empty_spot = tile
			break
	if empty_spot != Vector2i(-1, -1):
		controller._pad_move_cursor(hero.position)
		await settle(3)
		await tap(JOY_BUTTON_A)
		controller._pad_move_cursor(empty_spot)
		await settle(3)
		await tap(JOY_BUTTON_A)
		await settle(2)
		ok(hero.position == empty_spot, "A on one of the party, then A on a free tile, moves them there",
			"%s, wanted %s" % [hero.position, empty_spot])
	await tap(JOY_BUTTON_X)
	ok(ui.pad_panel_open() and get_viewport().gui_get_focus_owner() == ui.get_node("Actions/EndTurnButton"),
		"Square: along the bottom there is only Begin Battle", "%s" % get_viewport().gui_get_focus_owner())
	await tap(JOY_BUTTON_A)
	await settle(4)
	ok(not combat.deployment_active, "and A begins it")

	for i in combat.combatants.size():
		if is_same(combat.combatants[i], hero):
			combat.current_combatant = i
	controller.set_controlled_combatant(hero)
	controller.player_turn = true
	controller.action_locked = false
	camera.position = Grid.tile_to_world(hero.position)
	await settle(4)

	log_line("")
	log_line("======== the board ========")
	ok(controller.pad_cursor() == hero.position, "the cursor goes to whoever's turn it is",
		"%s, him at %s" % [controller.pad_cursor(), hero.position])
	ok(controller.pad_tiles().is_empty(), "and goes anywhere on the map")
	var on_tile := func() -> bool:
		return Pad.pointer().distance_to(screen_of(controller.tile_map.map_to_local(controller.pad_cursor()))) < 1.0
	await settle(2)
	ok(on_tile.call(), "the pointer sits on the cursor's tile")
	await tap(JOY_BUTTON_DPAD_RIGHT)
	ok(controller.pad_cursor() == hero.position + Vector2i.RIGHT, "the D-pad steps one tile", "%s" % controller.pad_cursor())
	var from: Vector2i = controller.pad_cursor()
	await push(JOY_AXIS_LEFT_X, -1.0, 3)
	ok(controller.pad_cursor().x < from.x and controller.pad_cursor().y == from.y, "and so does the left stick",
		"%s -> %s" % [from, controller.pad_cursor()])
	from = controller.pad_cursor()
	stick(JOY_AXIS_LEFT_X, 0.7)
	stick(JOY_AXIS_LEFT_Y, 0.7)
	await settle(3)
	stick(JOY_AXIS_LEFT_X, 0.0)
	stick(JOY_AXIS_LEFT_Y, 0.0)
	await settle(2)
	ok(controller.pad_cursor() == from + Vector2i(1, 1), "diagonally too", "%s -> %s" % [from, controller.pad_cursor()])
	from = controller.pad_cursor()
	button(JOY_BUTTON_DPAD_DOWN, true)
	await wait(Pad.STEP_DELAY + Pad.STEP_EVERY * 2.5)
	button(JOY_BUTTON_DPAD_DOWN, false)
	await settle(3)
	ok(controller.pad_cursor().y >= from.y + 2, "held, it keeps stepping", "%s" % controller.pad_cursor())
	ok(ui.map_view_rect().grow(2.0).has_point(Pad.pointer()) and on_tile.call(), "the view going along, so it is never under the HUD",
		"%s in %s" % [Pad.pointer(), ui.map_view_rect()])
	var wall := Vector2i(-1, -1)
	var beside := Vector2i(-1, -1)
	for tile in controller.tile_map.get_used_cells(0):
		if controller.is_in_bounds(tile) and controller.is_tile_blocking(tile, hero.movement_class):
			for way in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if controller.is_in_bounds(tile + way) and not controller.is_tile_blocking(tile + way, hero.movement_class):
					wall = tile
					beside = tile + way
					break
		if wall != Vector2i(-1, -1):
			break
	if wall != Vector2i(-1, -1):
		controller._pad_move_cursor(beside)
		controller.pad_tile_step(wall - beside)
		ok(controller.pad_cursor() == wall, "onto a tile nobody can walk on, as the mouse can be")
	controller._pad_move_cursor(hero.position)
	await settle(3)
	var cam_before: Vector2 = camera.position
	await push(JOY_AXIS_RIGHT_X, 1.0, 20)
	await settle(2)
	ok(camera.position.x > cam_before.x, "the right stick moves the view", "%s -> %s" % [cam_before, camera.position])
	ok(ui.map_view_rect().grow(2.0).has_point(Pad.pointer()) and on_tile.call(), "and the cursor comes along, onto a tile still in view")
	camera.position = Grid.tile_to_world(hero.position)
	controller._pad_move_cursor(hero.position)
	await settle(3)

	log_line("")
	log_line("======== walking ========")
	var target := Vector2i(-1, -1)
	for way in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP, Vector2i(1, 1), Vector2i(-1, 1)]:
		if controller.can_move_to(hero.position + way) and controller.get_combatant_at_position(hero.position + way) == null:
			target = hero.position + way
			break
	ok(target != Vector2i(-1, -1), "(somewhere beside him to walk to)")
	var start: Vector2i = hero.position
	controller.pad_tile_step(target - hero.position)
	await settle(3)
	await tap(JOY_BUTTON_A)
	ok(await until(func(): return hero.position == target and controller.is_idle(), 5.0), "A on a tile walks there",
		"%s, wanted %s" % [hero.position, target])

	log_line("")
	log_line("======== Square: the panel along the bottom ========")
	ok(ui.keys_hint().contains("the skills, Undo Move and End Turn") and ui.keys_hint().contains("(Y)"),
		"End Turn's hint names the pad's buttons", ui.keys_hint())
	var marks_shown := false
	for slot in ui.action_buttons():
		var mark = slot.get_node_or_null(ui.HOTKEY_MARK)
		marks_shown = marks_shown or (mark != null and mark.visible)
	ok(not marks_shown, "the skills lose their 1-9: those are keys")
	await tap(JOY_BUTTON_X)
	var focused = get_viewport().gui_get_focus_owner()
	ok(ui.pad_panel_open() and focused is Button and focused.get_meta(ui.SKILL_META, "") != "",
		"Square opens the panel, on the first skill", "%s" % focused)
	ok(Pad.mode() == Pad.Mode.MENU and not Pad.pointer_showing(), "which the D-pad goes round, without the pointer")
	var round_it: Array = ui._pad_panel_buttons()
	ok(round_it.has(ui._undo_button) and round_it.has(ui.get_node("Actions/EndTurnButton")),
		"Undo Move and End Turn are in it")
	var linked := {focused: true}
	var to_visit := [focused]
	while not to_visit.is_empty():
		var here: Control = to_visit.pop_back()
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			var there = here.get_node_or_null(here.get_focus_neighbor(side))
			if there != null and not linked.has(there):
				linked[there] = true
				to_visit.append(there)
	ok(round_it.all(func(b): return linked.has(b)), "every button in it can be got to with the D-pad, from the first",
		"%d of %d" % [linked.size(), round_it.size()])
	var first_slot: Control = focused
	await tap(JOY_BUTTON_DPAD_RIGHT)
	var right_of = get_viewport().gui_get_focus_owner()
	ok(right_of != null and right_of.get_meta(ui.SKILL_META, "") != "" and right_of.get_global_rect().get_center().y == first_slot.get_global_rect().get_center().y,
		"right from the first skill is the next skill along, not a tab above", "%s" % right_of)
	var reached := {}
	for way in [JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_RIGHT,
			JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_DOWN,
			JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_UP]:
		await tap(way)
		reached[get_viewport().gui_get_focus_owner()] = true
	ok(reached.has(ui._undo_button) and reached.has(ui.get_node("Actions/EndTurnButton")),
		"the D-pad gets to both", "%s" % [reached.keys()])
	ui._undo_button.grab_focus()
	await tap(JOY_BUTTON_A)
	await settle(3)
	ok(hero.position == start and not ui.pad_panel_open(), "A on Undo Move walks him back, and it is the map again",
		"%s" % hero.position)
	await tap(JOY_BUTTON_X)
	await tap(JOY_BUTTON_X)
	ok(not ui.pad_panel_open() and get_viewport().gui_get_focus_owner() == null, "Square again: back to the map")
	await tap(JOY_BUTTON_X)
	await tap(JOY_BUTTON_B)
	ok(not ui.pad_panel_open(), "and so does B")

	log_line("")
	log_line("======== aiming from it ========")
	await tap(JOY_BUTTON_X)
	var skill_button = get_viewport().gui_get_focus_owner()
	var skill_key: String = skill_button.get_meta(ui.SKILL_META, "") if skill_button != null else ""
	await tap(JOY_BUTTON_A)
	await settle(2)
	ok(controller.is_skill_selected() and controller._selected_skill == skill_key and not ui.pad_panel_open(),
		"A on a skill aims it, out on the map", skill_key)
	var aim_tiles: Array = controller.pad_tiles()
	ok(not aim_tiles.is_empty() and aim_tiles.has(controller.pad_cursor()), "the cursor on one of the tiles it could go")
	await tap(JOY_BUTTON_B)
	await settle(3)
	ok(not controller.is_skill_selected() and ui.pad_panel_open() and get_viewport().gui_get_focus_owner() == skill_button,
		"B puts it away - and it is the panel again, on that skill", "%s" % get_viewport().gui_get_focus_owner())
	await tap(JOY_BUTTON_B)

	log_line("")
	log_line("======== what an aim locks onto ========")
	controller.set_selected_skill("gun")
	controller.begin_target_selection()
	await settle(3)
	var aimed: Array = controller.pad_tiles()
	var at_somebody: bool = not aimed.is_empty() and aimed.all(func(tile):
		var comb = controller.get_combatant_at_position(tile)
		return comb != null and controller.refusal_at(tile, comb) == "")
	ok(at_somebody, "a gun: only whoever it can hit", "%s" % [aimed])
	var hittable := 0
	for comb in combat.combatants:
		if comb.alive and controller._range_preview_positions.has(comb.position) and controller.refusal_at(comb.position, comb) == "":
			hittable += 1
	ok(aimed.size() == hittable, "every one of them", "%d of %d" % [aimed.size(), hittable])
	ok(aimed.has(controller.pad_cursor()), "the cursor on one already")
	await settle(2)
	ok(on_tile.call(), "and the pointer with it, so what the shot would do is showing")
	seen = {}
	for i in aimed.size():
		await tap(JOY_BUTTON_RIGHT_SHOULDER)
		seen[controller.pad_cursor()] = true
	ok(seen.size() == aimed.size(), "RB goes through them all - LB and RB are the targets' while aiming",
		"%d of %d" % [seen.size(), aimed.size()])
	ok(controller._selected_skill == "gun", "(and not the skills')")
	if aimed.size() > 1:
		var was: Vector2i = controller.pad_cursor()
		var moved := false
		for way in [JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_UP]:
			await tap(way)
			moved = moved or controller.pad_cursor() != was
		ok(moved and aimed.has(controller.pad_cursor()), "the D-pad jumps from one to the next, over the tiles between")
	controller.cancel_skill_selection()
	controller.set_selected_skill("fireball")
	controller.begin_target_selection()
	await settle(3)
	var area: Array = controller.pad_tiles()
	var could_go: Array = controller._range_preview_positions.filter(func(tile):
		var comb = controller.get_combatant_at_position(tile)
		return controller.refusal_at(tile, comb if comb != null else {}) == "")
	ok(not area.is_empty() and area.size() == could_go.size(), "a fireball: every tile it could land on",
		"%d of %d" % [area.size(), could_go.size()])
	controller.cancel_skill_selection()
	controller.set_selected_skill("greatsword_attack")
	controller.begin_target_selection()
	await settle(3)
	var nobody: bool = controller._range_preview_positions.all(func(tile):
		var comb = controller.get_combatant_at_position(tile)
		return comb == null or controller.refusal_at(tile, comb) != "")
	ok(not nobody or controller.pad_tiles().size() == controller._range_preview_positions.size(),
		"a sword with nobody in reach: every tile of its reach, to see it")
	controller.cancel_skill_selection()
	await settle(2)

	log_line("")
	log_line("======== the rest ========")
	stick(JOY_AXIS_TRIGGER_LEFT, 1.0)
	await settle(3)
	ok(controller.is_showing_danger(), "LT held shows where enemies could strike")
	stick(JOY_AXIS_TRIGGER_LEFT, 0.0)
	await settle(3)
	ok(not controller.is_showing_danger(), "let go, it goes")
	var zoom_before: float = camera.zoom.x
	await tap(JOY_BUTTON_RIGHT_STICK)
	ok(is_equal_approx(camera.zoom.x, camera.min_zoom), "RS: out to the whole map", "%.3f" % camera.zoom.x)
	await tap(JOY_BUTTON_RIGHT_STICK)
	ok(is_equal_approx(camera.zoom.x, zoom_before), "and back", "%.3f" % camera.zoom.x)
	await tap(JOY_BUTTON_RIGHT_SHOULDER)
	ok(controller.is_skill_selected(), "on the map, RB picks a skill straight off")
	await tap(JOY_BUTTON_B)
	ok(not controller.is_skill_selected() and not ui.pad_panel_open(), "and B puts it away - to the map, where it came from")
	var sheet = game.get_node("CharacterSheet")
	await tap(JOY_BUTTON_BACK)
	ok(sheet.is_open(), "in a fight, View opens the character sheet first")
	await tap(JOY_BUTTON_RIGHT_SHOULDER)
	ok(not sheet.is_open() and Journal.is_open(), "and RB goes on to the journal")
	await tap(JOY_BUTTON_BACK)
	ok(not Journal.is_open(), "(closed)")
	var ended := [false]
	ui.turn_ended.connect(func(): ended[0] = true)
	await tap(JOY_BUTTON_Y)
	ok(ended[0], "Y ends the turn")

	log_line("")
	log_line("======== over ========")
	game.get_node("ResultUI")._show_panel()
	await settle(3)
	ok(Pad.mode() == Pad.Mode.MENU and not Pad.pointer_showing(),
		"the battle over, the result is a menu, not the board - no pointer, the D-pad and A go round it")
	await tap(JOY_BUTTON_A)
	ok(get_viewport().gui_get_focus_owner() != null, "A lights up its first button, as a key would")
	await key(KEY_K)
	ok(ui.keys_hint().begins_with("End this character's turn (Space)\n1-9"), "(and back on the keyboard, the keys)")
	game.queue_free()
	await settle(3)
	log_line("")


## Stepping a way from tile to tile reaches every tile there is to reach, from
## any of them - however scattered they are, and with holes where cover is.
func reaching_every_tile():
	log_line("======== every tile can be stepped to ========")
	var ways := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var stuck := 0
	var sets := 0
	for trial in 60:
		var tiles: Array = []
		if trial % 2 == 0:
			var count := rng.randi_range(2, 24)
			while tiles.size() < count:
				var tile := Vector2i(rng.randi_range(0, 14), rng.randi_range(0, 14))
				if not tiles.has(tile):
					tiles.append(tile)
		else:
			for x in range(-6, 7):
				for y in range(-6, 7):
					if absi(x) + absi(y) <= 6 and rng.randf() > 0.45:
						tiles.append(Vector2i(x, y))
		if tiles.size() < 2:
			continue
		sets += 1
		for from_tile in tiles:
			var reached := {from_tile: true}
			var frontier := [from_tile]
			while not frontier.is_empty():
				var here: Vector2i = frontier.pop_back()
				for way in ways:
					var there := CController.next_tile(tiles, here, way)
					if not reached.has(there):
						reached[there] = true
						frontier.append(there)
			if reached.size() < tiles.size():
				stuck += 1
				break
	ok(stuck == 0, "from every tile of %d scattered and holed sets, every other one" % sets,
		"%d sets with one out of reach" % stuck)
	log_line("")


func skipping_dialogue():
	log_line("======== B skips a conversation - once it is sure ========")
	Campaign.reset()
	var balloon = load("res://ui/dialogue_balloon.tscn").instantiate()
	get_tree().root.add_child(balloon)
	balloon.start(load("res://dialogue/test.dialogue"), "start")
	await settle(30)
	var first_line = balloon.dialogue_line
	ok(balloon.can_skip(), "(a line up, with nothing to answer)")
	await wake_the_pad()
	await tap(JOY_BUTTON_B)
	ok(balloon.is_asking_to_skip(), "B asks whether to skip")
	ok(get_viewport().gui_get_focus_owner() == balloon._skip_yes, "with Skip under A already")
	ok(not Pad.pointer_showing(), "and no pointer: the D-pad and A answer it")
	await tap(JOY_BUTTON_B)
	ok(not balloon.is_asking_to_skip() and balloon.dialogue_line == first_line, "B again: no, and the line is still up")
	ok(get_viewport().gui_get_focus_owner() == balloon.balloon, "the balloon has A back, for the next line")
	await tap(JOY_BUTTON_B)
	await tap(JOY_BUTTON_A)
	await settle(30)
	ok(not balloon.is_asking_to_skip() and balloon.dialogue_line != first_line and balloon.dialogue_line.responses.size() > 0,
		"B then A: skipped - up to the question, which is not skipping's to answer")
	balloon.queue_free()
	await settle(2)

	log_line("")
	log_line("======== the Skip button asks too ========")
	await key(KEY_K)
	balloon = load("res://ui/dialogue_balloon.tscn").instantiate()
	get_tree().root.add_child(balloon)
	balloon.start(load("res://dialogue/test.dialogue"), "start")
	await settle(30)
	first_line = balloon.dialogue_line
	balloon.skip_button.pressed.emit()
	await settle(2)
	ok(balloon.is_asking_to_skip() and balloon.dialogue_line == first_line, "clicking Skip asks first, and skips nothing yet")
	ok(get_viewport().gui_get_focus_owner() == null, "with no button lit up under a mouse that is elsewhere")
	balloon._skip_no.pressed.emit()
	await settle(2)
	ok(not balloon.is_asking_to_skip() and balloon.dialogue_line == first_line, "Keep reading: carries on where it was")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await settle(2)
	ok(not balloon.is_asking_to_skip(), "Escape is still the pause menu's, not a skip")
	balloon.skip_button.pressed.emit()
	await settle(2)
	balloon._skip_yes.pressed.emit()
	await settle(30)
	ok(balloon.dialogue_line != first_line, "Skip: skipped")
	balloon.queue_free()
	await settle(2)
	log_line("")

func in_the_pictures():
	Pictures.leave_for_map = false
	Campaign.reset()
	Pictures.open("res://pictures/clues_office.tscn")
	await settle(3)
	Pictures._intro = 1.0
	await settle(2)
	var office: Picture = Pictures.current()

	log_line("======== a picture ========")
	await wake_the_pad()
	ok(Pad.mode() == Pad.Mode.PICTURE, "a picture")
	ok(Pad.pointer_showing(), "with the pointer always up")
	ok(Pictures._journal_button.text == "Journal (View)" and Pictures._back.text == "Back (B)", "its buttons naming the pad's",
		"%s, %s" % [Pictures._journal_button.text, Pictures._back.text])
	var roster: Hotspot = office.get_node("RosterSpot")
	Pad.point_at(middle_of(roster) + Vector2(0, 200))
	await settle(2)
	ok(not roster.is_hovered(), "(away from the roster)")
	Pad.point_at(middle_of(roster))
	await settle(3)
	ok(roster.is_hovered() and Pictures._hovered == roster, "moved onto something, it lights up")
	ok(Pictures._hover_label.text.begins_with(roster.display_name), "and says what it is", Pictures._hover_label.text)
	ok(Pad._over_something(), "over something to click, it goes slower, so it stops there rather than sailing past")
	var before := Pad.pointer()
	await push(JOY_AXIS_RIGHT_Y, 1.0, 6)
	ok(Pad.pointer().y > before.y, "the right stick moves it here too", "%s -> %s" % [before, Pad.pointer()])
	Pad.point_at(middle_of(roster))
	await settle(3)
	await tap(JOY_BUTTON_A)
	ok(roster.was_examined(), "A on it is a click")
	Pad.point_at(middle_of(office.get_node("CabinetSpot")))
	await settle(3)
	await tap(JOY_BUTTON_A)
	await settle(3)
	Pictures._intro = 1.0
	await settle(2)
	var cabinet: Picture = Pictures.current()
	ok(cabinet != office and cabinet.name == "Cabinet", "into the cabinet", "%s" % [cabinet.name if cabinet != null else "nothing"])
	var dial: PuzzleDial = cabinet.get_node("Lock/First")
	var was: int = dial.index
	Pad.point_at(middle_of(dial))
	await settle(3)
	await tap(JOY_BUTTON_RIGHT_SHOULDER)
	ok(dial.index == posmod(was + 1, dial.values.size()), "RB turns the dial under it on", "%d -> %d" % [was, dial.index])
	await tap(JOY_BUTTON_LEFT_SHOULDER)
	ok(dial.index == was, "LB back", "%d" % dial.index)
	await tap(JOY_BUTTON_B)
	ok(Pictures.current() == office, "B goes back a picture")

	log_line("")
	log_line("======== dragging ========")
	Pictures.open("res://pictures/clues_bin.tscn")
	await settle(3)
	Pictures._intro = 1.0
	await settle(2)
	var piece: PuzzlePiece = Pictures.current().get_node("Letter/Piece1")
	var piece_was: Vector2 = piece.position
	Pad.point_at(middle_of(piece))
	await settle(3)
	button(JOY_BUTTON_A, true)
	await settle(3)
	ok(piece._dragging, "A held on a piece picks it up")
	stick(JOY_AXIS_LEFT_X, 1.0)
	await settle(8)
	stick(JOY_AXIS_LEFT_X, 0.0)
	await settle(2)
	ok(piece.position.x > piece_was.x + 10.0, "the stick carries it", "%s -> %s" % [piece_was, piece.position])
	button(JOY_BUTTON_A, false)
	await settle(3)
	ok(not piece._dragging, "and letting go of A puts it down")
	Pictures.close()
	await settle(3)
	await key(KEY_K)
	ok(Pictures._journal_button == null or not is_instance_valid(Pictures._journal_button)
		or Pictures._journal_button.text == "Journal (J)", "(and the keys are named again)")
	log_line("")


func battle_select():
	Campaign.reset()
	var arena = load("res://scenes/level_select.tscn").instantiate()
	get_tree().root.add_child(arena)
	await settle(3)
	var way_out: Button = arena._main_menu_button

	log_line("======== Battle Select ========")
	await tap(JOY_BUTTON_DPAD_DOWN)
	ok(get_viewport().gui_get_focus_owner() != null, "the D-pad lights up the first battle")
	await tap(JOY_BUTTON_DPAD_UP)
	ok(get_viewport().gui_get_focus_owner() == way_out, "and up from it, round to the way out - it is in the loop",
		"%s" % get_viewport().gui_get_focus_owner())
	await tap(JOY_BUTTON_DPAD_UP)
	ok(get_viewport().gui_get_focus_owner() == arena._reset_button, "with Reset above it")
	# Counted rather than followed: the real thing leaves the scene.
	for connection in way_out.pressed.get_connections():
		way_out.pressed.disconnect(connection.callable)
	var left := [0]
	way_out.pressed.connect(func(): left[0] += 1)
	await tap(JOY_BUTTON_B)
	ok(left[0] == 1, "B goes back, as that button does", "%d" % left[0])
	arena.queue_free()
	await settle(2)
	await key(KEY_K)
	log_line("")


## The volume sliders, in both places they are, with nothing but the D-pad.
func volume_by_pad():
	var music_was: float = Music.volume("music")
	var sfx_was: float = Music.volume("sfx")

	log_line("======== volume, from the main menu ========")
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	await settle(3)
	menu._show("volume")
	await settle(2)
	await tap(JOY_BUTTON_DPAD_DOWN)
	ok(get_viewport().gui_get_focus_owner() is Button, "the D-pad lights up Back", "%s" % get_viewport().gui_get_focus_owner())
	await tap(JOY_BUTTON_DPAD_UP)
	var on = get_viewport().gui_get_focus_owner()
	ok(on is HSlider, "and up from it is a slider", "%s" % on)
	if on is HSlider:
		var level: float = on.value
		await tap(JOY_BUTTON_DPAD_LEFT)
		ok(on.value < level, "which the D-pad's left turns down", "%.2f -> %.2f" % [level, on.value])
	menu.queue_free()
	await settle(2)

	log_line("")
	log_line("======== volume, from the pause menu ========")
	var m = await open_map()
	await watch_it(m, m.post + Vector2i.LEFT * 3)
	var pause = m.scene.get_node("PauseUI")
	await tap(JOY_BUTTON_START)
	pause._show_panel(pause.get_node("OptionsPanel"), pause._options_buttons)
	await settle(2)
	await tap(JOY_BUTTON_DPAD_DOWN)
	ok(get_viewport().gui_get_focus_owner() != null, "Options: the D-pad lights up its first button")
	await tap(JOY_BUTTON_DPAD_UP)
	on = get_viewport().gui_get_focus_owner()
	ok(on is HSlider, "up from it, round to the last slider - they are in the loop", "%s" % on)
	if on is HSlider:
		var level: float = on.value
		await tap(JOY_BUTTON_DPAD_RIGHT if level < 1.0 else JOY_BUTTON_DPAD_LEFT)
		ok(not is_equal_approx(on.value, level), "and the D-pad's sides move it", "%.2f -> %.2f" % [level, on.value])
	pause._close()
	Music.set_volume("music", music_was)
	Music.set_volume("sfx", sfx_was)
	await key(KEY_K)
	await close_map(m)
