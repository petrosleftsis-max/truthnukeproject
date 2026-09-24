extends Node
## The game stops while a menu is over it, and a conversation can be left.
##
## Blocking input was never the same thing as stopping: a click that landed
## beside the pause panel went through to the map and moved somebody, and
## whatever was already in flight carried on behind it. Holding the tree is
## what "the menu is open" now means.

var LOG_PATH := HarnessLog.path_for("halt")
const PROBE = "res://Dialogue/_skip_probe.dialogue"
var _log: FileAccess
var _fail = 0

func log_line(t): _log.store_line(t); _log.flush()

func ok(condition: bool, label: String, detail: String = ""):
	if condition:
		log_line("  PASS  %s %s" % [label, detail])
	else:
		_fail += 1
		log_line("  FAIL  %s %s" % [label, detail])

func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(240.0).timeout.connect(func():
		log_line("DID NOT FINISH")
		get_tree().paused = false
		get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


func press(keycode: int):
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)


## An aimed click, in the coordinates a Control's own rect is measured in.
## Input.parse_input_event puts an event in at the window, where the stretch
## transform is still to be applied to it, and it lands somewhere else.
func click(control: Control):
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = control.get_global_rect().get_center()
		event.global_position = event.position
		get_viewport().push_input(event, true)
		await get_tree().process_frame


## Frames that pass whether or not the tree is held - process_frame is emitted
## either way, which is what makes a paused test runnable at all.
func frames(n: int = 3):
	for i in n:
		await get_tree().process_frame


func run_test():
	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_02_sappers.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await frames(6)
	var combat = game.get_node("VisualCombat")
	var controller = combat.controller
	var pause = game.get_node("PauseUI")
	var sheet = game.get_node("CharacterSheet")

	log_line("======== not even while the party is being placed ========")
	# Where this was worst. The controller's own menu guard sits below the
	# deployment branch, so during placement a click that missed the pause
	# panel went through and put somebody down. Holding the tree stops the
	# controller being handed the click at all, which is under the guard rather
	# than beside it.
	if combat.deployment_active:
		pause._show_panel(pause.get_node("PausePanel"), pause._pause_buttons)
		await frames(1)
		ok(get_tree().paused, "the pause menu holds the game during placement")
		ok(not controller.can_process(),
			"and the map is not handed input at all, guard or no guard")
		pause._close()
		await frames(1)
		ok(controller.can_process(), "closing it gives the map back")
		combat.finish_deployment()
		await frames(1)
	log_line("")

	log_line("======== the pause menu stops the game ========")
	ok(not get_tree().paused, "nothing is held to begin with")
	ok(pause.process_mode == Node.PROCESS_MODE_ALWAYS,
		"the pause menu itself keeps running while the game is held",
		"%d" % pause.process_mode)
	pause._show_panel(pause.get_node("PausePanel"), pause._pause_buttons)
	await frames(1)
	ok(get_tree().paused, "opening it holds the game")
	ok(controller.a_menu_is_over_the_map(), "and the map knows a menu is over it")
	ok(not controller.can_process(), "and is not being handed input while it is up")
	# Options is still the pause menu being open.
	pause._show_panel(pause.get_node("OptionsPanel"), pause._options_buttons)
	await frames(1)
	ok(get_tree().paused, "stepping into Options keeps it held")
	pause._close()
	await frames(1)
	ok(not get_tree().paused, "closing it lets the game go")
	log_line("")

	log_line("======== so does the character sheet ========")
	ok(sheet.process_mode == Node.PROCESS_MODE_ALWAYS,
		"the sheet keeps running too", "%d" % sheet.process_mode)
	sheet.open()
	await frames(1)
	ok(sheet.is_open(), "the sheet opens")
	ok(get_tree().paused, "and holds the game while it is read")
	sheet.close()
	await frames(1)
	ok(not get_tree().paused, "closing it lets the game go")
	log_line("")

	log_line("======== two menus, one game ========")
	# Either can be closed first, so a bool would have let the second close
	# unfreeze a game the first was still holding.
	sheet.open()
	pause._show_panel(pause.get_node("PausePanel"), pause._pause_buttons)
	await frames(1)
	ok(get_tree().paused, "both open, still held")
	sheet.close()
	await frames(1)
	ok(get_tree().paused, "the sheet closing does not speak for the pause menu")
	pause._close()
	await frames(1)
	ok(not get_tree().paused, "and only the last one out lets it go")
	log_line("")

	log_line("======== what Study opens holds the game like any other sheet ========")
	# It used to arrive unpaused, on the grounds that the skill that opened it
	# was still resolving. But Study costs an action and its whole payoff is the
	# reading, so the reading gets the same quiet pressing C gets - and the skill
	# picks up again the moment the sheet is closed.
	var foe = null
	for comb in combat.combatants:
		if comb.alive and comb.side == 1:
			foe = comb
			break
	foe["studied"] = true
	sheet.open_on(foe.name)
	await frames(1)
	ok(sheet.is_open(), "Study opens the sheet on who was measured", foe.name)
	ok(get_tree().paused, "and holds the game while it is read")
	# A hold nobody can release is a deadlock rather than a pause, so the panel
	# has to keep running while the tree does not.
	ok(sheet.process_mode == Node.PROCESS_MODE_ALWAYS,
		"the panel still runs, so it can always be closed again")
	sheet.close()
	await frames(1)
	ok(not get_tree().paused, "and closing it lets the game carry on")
	log_line("")

	log_line("======== C does not answer the pause menu ========")
	pause._show_panel(pause.get_node("PausePanel"), pause._pause_buttons)
	await frames(1)
	press(KEY_C)
	await frames(3)
	ok(not sheet.is_open(), "the sheet does not open behind the pause panel")
	ok(get_tree().paused, "and the game is still held")
	pause._close()
	await frames(1)
	press(KEY_C)
	await frames(3)
	ok(sheet.is_open(), "C opens the sheet once the pause menu is gone")
	ok(get_tree().paused, "which holds the game in its turn")
	press(KEY_C)
	await frames(3)
	ok(not sheet.is_open(), "and closes it again")
	ok(not get_tree().paused, "letting the game run")
	log_line("")

	log_line("======== the menu still answers a click while it holds ========")
	# Worth its own test: a paused Control takes focus on the press and then
	# never fires, so a pause menu that did not keep running would be a menu
	# you could not use and could not leave.
	pause._show_panel(pause.get_node("PausePanel"), pause._pause_buttons)
	await frames(2)
	ok(get_tree().paused, "the game is held")
	await click(pause.get_node("PausePanel/VBox/OptionsButton"))
	await frames(3)
	ok(pause.get_node("OptionsPanel").visible, "and Options still opens when pressed")
	pause._close()
	await frames(2)

	sheet.open()
	await frames(2)
	var member_buttons := []
	for child in sheet._members.get_children():
		if child is Button:
			member_buttons.append(child)
	if member_buttons.size() > 1 and sheet._members.visible:
		var was = sheet._index
		await click(member_buttons[1] if member_buttons[1] != member_buttons[was] else member_buttons[0])
		await frames(3)
		ok(sheet._index != was, "and the sheet still turns to another member",
			"%d -> %d" % [was, sheet._index])
	else:
		ok(true, "  (the sheet has nobody else to turn to here)")
	sheet.close()
	await frames(1)
	ok(not get_tree().paused, "everything let go")
	log_line("")

	log_line("======== a menu freed while holding ========")
	# A scene change frees the holder without it ever letting go, so the hold
	# has to expire with the holder rather than outlive it.
	var stray := Node.new()
	get_tree().root.add_child(stray)
	MenuPause.hold(stray)
	ok(get_tree().paused, "something holding the game holds it")
	stray.queue_free()
	await frames(2)
	MenuPause.release(pause)
	ok(not get_tree().paused, "and a holder that stopped existing stops holding")
	MenuPause.hold(pause)
	ok(get_tree().paused, "held again")
	MenuPause.clear(get_tree())
	ok(not get_tree().paused, "and a scene change clears the lot")
	log_line("")

	game.queue_free()
	await frames(2)

	log_line("======== the pause menu draws over a conversation ========")
	var pause_layer = load("res://ui/pause_ui.tscn").instantiate()
	var balloon_layer = load("res://ui/dialogue_balloon.tscn").instantiate()
	ok(pause_layer.layer > balloon_layer.layer,
		"Escape during a conversation opens something you can see",
		"pause %d vs balloon %d" % [pause_layer.layer, balloon_layer.layer])
	pause_layer.free()
	balloon_layer.free()
	log_line("")

	await _escape_during_a_conversation()
	await _skipping()

	get_tree().paused = false
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


## --- Talking ---


## Starts the probe conversation and hands back the balloon, once the first
## line is on screen.
func _open_probe() -> Node:
	var balloon = load("res://ui/dialogue_balloon.tscn").instantiate()
	get_tree().root.add_child(balloon)
	balloon.start(load(PROBE), "start")
	# Long enough for the first line to have finished typing itself out.
	await frames(30)
	return balloon


func _escape_during_a_conversation():
	log_line("======== Escape reaches the pause menu mid-conversation ========")
	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_02_sappers.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await frames(6)
	var pause = game.get_node("PauseUI")
	var balloon = await _open_probe()
	ok(balloon.balloon.visible, "the conversation is up")
	ok(not get_tree().paused, "and the game is running")

	press(KEY_ESCAPE)
	await frames(4)
	ok(pause.get_node("PausePanel").visible,
		"Escape opens the pause menu rather than being swallowed")
	ok(get_tree().paused, "which holds the game")

	# The conversation must not advance behind it.
	var held_on = balloon.dialogue_line
	balloon._on_balloon_gui_input(_click())
	await frames(2)
	ok(balloon.dialogue_line == held_on, "and a click does not advance the line behind it")

	press(KEY_ESCAPE)
	await frames(4)
	ok(not pause.get_node("PausePanel").visible, "Escape again closes it")
	ok(not get_tree().paused, "and the conversation carries on")
	balloon.queue_free()
	game.queue_free()
	await frames(2)
	log_line("")


func _click() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


func _skipping():
	log_line("======== skipping a conversation still runs it ========")
	Campaign.reset()
	Campaign.set_party(["cyrus"], 1)
	ok(not Campaign.has_member("prometheus"), "Prometheus is not in the party yet")
	ok(not Campaign.flag("skip_probe_reached_the_end"), "and the end has not been reached")

	var balloon = await _open_probe()
	ok(balloon.skip_button != null, "the balloon offers a way out")
	ok(balloon.skip_button.visible, "which is on screen")
	ok(balloon.skip_button.focus_mode == Control.FOCUS_NONE,
		"and never takes the keyboard off the balloon")

	var ended = [false]
	var manager = get_node("/root/DialogueManager")
	manager.dialogue_ended.connect(func(_r): ended[0] = true, CONNECT_ONE_SHOT)
	balloon.skip_conversation()
	await frames(30)

	ok(ended[0], "pressing Skip reaches the end of the conversation")
	ok(Campaign.has_member("prometheus"),
		"and everything it did still happened - Prometheus joined")
	ok(Campaign.flag("skip_probe_reached_the_end"),
		"including the line after the one that was on screen")
	ok(not is_instance_valid(balloon) or not balloon.balloon.visible,
		"and the balloon is gone")
	log_line("")

	log_line("======== but it stops at a question ========")
	Campaign.reset()
	Campaign.set_party(["cyrus"], 1)
	var asking = load("res://ui/dialogue_balloon.tscn").instantiate()
	get_tree().root.add_child(asking)
	asking.start(load(PROBE), "asks")
	await frames(30)
	asking.skip_conversation()
	await frames(20)
	ok(is_instance_valid(asking) and asking.balloon.visible,
		"the conversation is still on screen")
	ok(is_instance_valid(asking) and asking.dialogue_line != null
		and asking.dialogue_line.responses.size() > 0,
		"waiting on the answer, which is the player's to give")
	ok(not Campaign.flag("skip_probe_answered"),
		"and nothing past the question has been run")
	if is_instance_valid(asking):
		asking.queue_free()
	await frames(2)
	log_line("")
