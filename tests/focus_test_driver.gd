extends Node
## Nothing is highlighted until somebody reaches for the keyboard.
##
## A menu that grabs focus the moment it opens leaves its first option lit up
## under a mouse that is nowhere near it, in the same colours as hover - so two
## options look picked and the first looks picked permanently.

var LOG_PATH := HarnessLog.path_for("focus")
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
	get_tree().create_timer(180.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


func focused() -> Control:
	return get_viewport().gui_get_focus_owner()


## Presses a key the way a player reaching for the arrows does.
func press_key(keycode: int):
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)


func move_mouse():
	var event := InputEventMouseMotion.new()
	event.position = Vector2(400, 300)
	event.relative = Vector2(8, 4)
	Input.parse_input_event(event)


## Aimed input. Input.parse_input_event puts an event in at the window, where
## it is still to be run through the stretch transform, so a position taken off
## a Control's own rect lands somewhere else entirely. push_input with local
## coordinates puts it in where the rect is measured.
func send_at(event: InputEvent, at: Vector2):
	event.position = at
	get_viewport().push_input(event, true)


func drag_to(at: Vector2, holding := false):
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(8, 4)
	if holding:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	send_at(event, at)


func click_at(at: Vector2, pressed: bool):
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	send_at(event, at)


func run_test():
	log_line("======== the title screen opens with nothing lit ========")
	var menu = load("res://main_menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	for i in 3:
		await get_tree().process_frame
	ok(focused() == null, "no option is highlighted on arrival",
		"" if focused() == null else focused().name)
	var keeper = menu.get_node_or_null("FocusOnDemand")
	ok(keeper != null, "but the keyboard's place is held")
	log_line("")

	log_line("======== reaching for the keyboard claims it ========")
	press_key(KEY_DOWN)
	for i in 3:
		await get_tree().process_frame
	ok(focused() != null, "an arrow key lights the first option",
		"" if focused() == null else focused().text)
	if focused() != null:
		ok(focused().text == "Play", "which is the top of the menu", focused().text)
	log_line("")

	log_line("======== and the mouse takes it away again ========")
	move_mouse()
	for i in 3:
		await get_tree().process_frame
	ok(focused() == null, "moving the mouse lets the highlight go",
		"" if focused() == null else focused().name)
	log_line("")

	log_line("======== every panel, not just the first ========")
	menu._show("options")
	for i in 2:
		await get_tree().process_frame
	ok(focused() == null, "options opens unlit too",
		"" if focused() == null else focused().name)
	press_key(KEY_DOWN)
	for i in 3:
		await get_tree().process_frame
	ok(focused() != null and focused().text == "Resolution",
		"and the keyboard starts at the top of this one",
		"" if focused() == null else focused().text)
	move_mouse()
	await get_tree().process_frame
	menu.queue_free()
	await get_tree().process_frame
	log_line("")

	log_line("======== Arena Mode ========")
	Campaign.reset()
	var arena = load("res://scenes/level_select.tscn").instantiate()
	get_tree().root.add_child(arena)
	for i in 3:
		await get_tree().process_frame
	ok(focused() == null, "no card is picked out on arrival",
		"" if focused() == null else focused().name)
	ok(arena.get_node_or_null("FocusOnDemand") != null, "and it holds a place too")
	press_key(KEY_DOWN)
	for i in 3:
		await get_tree().process_frame
	ok(focused() != null, "which the keyboard can claim")
	arena.queue_free()
	await get_tree().process_frame
	log_line("")

	log_line("======== the pause menu ========")
	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_02_sappers.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	for i in 6:
		await get_tree().process_frame
	var pause = game.get_node_or_null("PauseUI")
	ok(pause != null, "there is a pause menu")
	if pause != null:
		# The pause menu opens the way the player opens it, on Escape.
		pause._show_panel(pause.get_node("PausePanel"), pause._pause_buttons)
		for i in 3:
			await get_tree().process_frame
		ok(focused() == null, "which opens with nothing chosen",
			"" if focused() == null else focused().name)
		press_key(KEY_DOWN)
		for i in 3:
			await get_tree().process_frame
		ok(focused() != null, "and answers the keyboard",
			"" if focused() == null else focused().text)
		# Closed rather than left standing: an open pause menu holds the whole
		# game now, and everything after this would run against a frozen tree.
		pause._close()
		await get_tree().process_frame
	game.queue_free()
	await get_tree().process_frame
	log_line("")

	await _a_click_with_a_wobble_in_it()

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


## A click is a press, a little movement, and a release - hands are not still.
## Letting go of focus in the middle of that threw the whole click away, because
## Godot cancels a button's press the moment it loses focus, and the menu had to
## be clicked two or three times before anything happened.
func _a_click_with_a_wobble_in_it():
	log_line("======== a click survives the hand moving ========")
	ok(not get_tree().paused, "the game is running, so a click means something")
	# On a layer of its own, above whatever the main scene has on screen. A
	# click is aimed, unlike a key press, and picking finds the topmost canvas
	# layer first - the running game's HUD would take every one of these.
	var top := CanvasLayer.new()
	top.layer = 200
	get_tree().root.add_child(top)
	var menu = load("res://main_menu.tscn").instantiate()
	top.add_child(menu)
	for i in 3:
		await get_tree().process_frame

	var play: Button = null
	for node in menu.find_children("*", "Button", true, false):
		if node.visible and node.text == "Play":
			play = node
			break
	ok(play != null, "the top of the menu is there to press")
	if play == null:
		top.queue_free()
		return

	var presses = [0]
	play.pressed.connect(func(): presses[0] += 1)
	var middle = play.get_global_rect().get_center()

	click_at(middle, true)
	await get_tree().process_frame
	drag_to(middle + Vector2(2, 1), true)
	await get_tree().process_frame
	ok(get_viewport().gui_get_focus_owner() == play,
		"the button keeps the keyboard while it is being held",
		"" if get_viewport().gui_get_focus_owner() == null else get_viewport().gui_get_focus_owner().name)
	click_at(middle + Vector2(2, 1), false)
	for i in 3:
		await get_tree().process_frame
	ok(presses[0] == 1, "and one click is one press", "%d" % presses[0])
	log_line("")

	log_line("======== which is exactly what letting go would cost ========")
	# The same click with the old behaviour spliced back into the middle of it,
	# so the reason for the rule is written down rather than remembered.
	var keeper = menu.get_node_or_null("FocusOnDemand")
	presses[0] = 0
	click_at(middle, true)
	await get_tree().process_frame
	if keeper != null:
		keeper._let_go()
	await get_tree().process_frame
	click_at(middle, false)
	for i in 3:
		await get_tree().process_frame
	ok(presses[0] == 0, "losing focus mid-click loses the click",
		"%d presses" % presses[0])
	log_line("")

	# And the mouse still takes the highlight away once nothing is held down.
	drag_to(Vector2(20, 20), false)
	for i in 3:
		await get_tree().process_frame
	ok(get_viewport().gui_get_focus_owner() == null,
		"moving off with nothing held still lets the highlight go",
		"" if get_viewport().gui_get_focus_owner() == null else get_viewport().gui_get_focus_owner().name)
	top.queue_free()
	await get_tree().process_frame
