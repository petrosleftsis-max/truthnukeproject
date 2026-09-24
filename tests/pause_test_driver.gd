extends Node
## Headless harness for the pause menu focus cycling and the camera gate.

var LOG_PATH := HarnessLog.path_for("pause")

var _log: FileAccess = null
var _fail = 0


func log_line(t: String):
	if _log:
		_log.store_line(t)
		_log.flush()


func ok(condition: bool, label: String, detail: String = ""):
	if condition:
		log_line("  PASS  %s %s" % [label, detail])
	else:
		_fail += 1
		log_line("  FAIL  %s %s" % [label, detail])


func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(60.0).timeout.connect(func():
		log_line("WATCHDOG")
		get_tree().quit(2)
	)
	await get_tree().process_frame
	await get_tree().process_frame
	run_test()


func find_node_by(node: Node, predicate: Callable):
	if predicate.call(node):
		return node
	for c in node.get_children():
		var f = find_node_by(c, predicate)
		if f != null:
			return f
	return null


func press_key(code: Key):
	var down = InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.pressed = true
	Input.parse_input_event(down)


func release_key(code: Key):
	var up = InputEventKey.new()
	up.keycode = code
	up.physical_keycode = code
	up.pressed = false
	Input.parse_input_event(up)


func tap_key(code: Key):
	press_key(code)
	await get_tree().process_frame
	release_key(code)
	await get_tree().process_frame


func focus_name() -> String:
	var f = get_viewport().gui_get_focus_owner()
	return "<none>" if f == null else str(f.name)


func run_test():
	var pause_ui = find_node_by(get_tree().root, func(n): return n is CanvasLayer and n.has_method("set_resolution"))
	var cam = find_node_by(get_tree().root, func(n): return n is Camera2D and n.has_method("get_map_rect"))
	if pause_ui == null or cam == null:
		log_line("FAIL: pause_ui=%s cam=%s" % [pause_ui, cam])
		get_tree().quit(1)
		return

	var options_button = pause_ui.get_node("PausePanel/VBox/OptionsButton")
	var battles_button = pause_ui.get_node("PausePanel/VBox/LevelSelectButton")
	var main_menu_button = pause_ui.get_node("PausePanel/VBox/MainMenuButton")

	log_line("== Main Menu button ==")
	ok(main_menu_button != null, "Main Menu button exists", "text=%s" % main_menu_button.text)
	ok(main_menu_button.pressed.get_connections().size() > 0, "Main Menu button has a handler")
	log_line("")

	log_line("== focus loop wiring (should cycle both ways) ==")
	# Read off the menu rather than written down here: which buttons it carries
	# is a design decision that has changed more than once, and a list repeated
	# in the test only records what it used to be.
	var loop: Array = pause_ui._pause_buttons
	log_line("  NOTE  the menu offers: %s" % [loop.map(func(b): return b.text)])
	var broken := []
	for i in loop.size():
		var here: Control = loop[i]
		var below: Control = loop[(i + 1) % loop.size()]
		var above: Control = loop[(i - 1 + loop.size()) % loop.size()]
		if here.get_node(here.focus_neighbor_bottom) != below:
			broken.append("%s down goes to %s, not %s" % [here.text,
				here.get_node(here.focus_neighbor_bottom).text, below.text])
		if here.get_node(here.focus_neighbor_top) != above:
			broken.append("%s up goes to %s, not %s" % [here.text,
				here.get_node(here.focus_neighbor_top).text, above.text])
	ok(loop.size() >= 2, "there is a loop to walk", "%d buttons" % loop.size())
	ok(broken.is_empty(), "every button leads to its neighbours, and the ends wrap",
		"%s" % [broken])
	log_line("")

	log_line("== opening with Escape ==")
	ok(not pause_ui.get_node("PausePanel").visible, "starts closed")
	ok(get_viewport().gui_get_focus_owner() == null, "nothing focused while playing")
	await tap_key(KEY_ESCAPE)
	ok(pause_ui.get_node("PausePanel").visible, "Escape opened the Pause panel")
	# Held back rather than taken - see FocusOnDemand. The first arrow key is
	# what claims it, and lands on the first button rather than the second.
	ok(get_viewport().gui_get_focus_owner() == null,
		"nothing is lit up for a player using the mouse", "focus=%s" % focus_name())
	await tap_key(KEY_DOWN)
	ok(get_viewport().gui_get_focus_owner() == loop[0],
		"the first arrow key lights the first button", "focus=%s" % focus_name())
	log_line("")

	log_line("== arrow keys cycle the buttons ==")
	# All the way round and one past, so wrapping is walked rather than assumed.
	var wrong := []
	for i in range(1, loop.size() + 1):
		await tap_key(KEY_DOWN)
		var wanted: Control = loop[i % loop.size()]
		if get_viewport().gui_get_focus_owner() != wanted:
			wrong.append("step %d wanted %s, got %s" % [i, wanted.text, focus_name()])
	ok(wrong.is_empty(), "Down walks the whole loop and comes back round", "%s" % [wrong])
	await tap_key(KEY_UP)
	ok(get_viewport().gui_get_focus_owner() == loop[loop.size() - 1],
		"and Up from the first wraps to the last", "focus=%s" % focus_name())
	log_line("")

	log_line("== camera must not pan while the menu is open ==")
	cam.zoom = Vector2.ONE * 2.0 # zoomed in, so panning is actually possible
	cam.clamp_to_map()
	var before = cam.position
	press_key(KEY_D)
	for i in 10:
		await get_tree().process_frame
	release_key(KEY_D)
	await get_tree().process_frame
	ok(cam.position == before, "camera stayed put with menu open", "pos %s -> %s" % [before, cam.position])
	log_line("")

	log_line("== camera pans again once the menu closes ==")
	await tap_key(KEY_ESCAPE)
	ok(not pause_ui.get_node("PausePanel").visible, "Escape closed the panel")
	ok(get_viewport().gui_get_focus_owner() == null, "focus released", "focus=%s" % focus_name())
	before = cam.position
	press_key(KEY_D)
	for i in 10:
		await get_tree().process_frame
	release_key(KEY_D)
	await get_tree().process_frame
	ok(cam.position.x > before.x, "camera panned right", "pos %s -> %s" % [before, cam.position])
	log_line("")

	log_line("== the glossary opens from the pause menu ==")
	# Same book the main menu opens, reachable without leaving the fight.
	pause_ui._close()
	await get_tree().process_frame
	await tap_key(KEY_ESCAPE)
	ok(pause_ui.get_node("PausePanel").visible, "the pause menu is up")
	var book_button: Control = null
	for button in pause_ui._pause_buttons:
		if button.text == "Glossary":
			book_button = button
	ok(book_button != null, "there is a Glossary button")
	ok(book_button != null and pause_ui._pause_buttons.find(book_button)
		< pause_ui._pause_buttons.find(pause_ui.get_node("PausePanel/VBox/OptionsButton")),
		"and it sits above Options",
		"%s" % [pause_ui._pause_buttons.map(func(b): return b.text)])
	if book_button != null:
		book_button.pressed.emit()
		await get_tree().process_frame
		ok(pause_ui._glossary_showing(), "pressing it opens the book")
		ok(not pause_ui.get_node("PausePanel").visible, "and the menu steps aside for it")
		ok(pause_ui._glossary != null and pause_ui._glossary is GlossaryPanel,
			"it really is the glossary rather than a panel that looks like one")
		ok(get_tree().paused, "the game stays held while it is read")
		# Escape from a sub-panel goes back a step rather than dropping you out
		# of the menu entirely.
		await tap_key(KEY_ESCAPE)
		ok(not pause_ui._glossary_showing(), "Escape closes the book")
		ok(pause_ui.get_node("PausePanel").visible, "and lands back on the pause menu, not in the game")
		await tap_key(KEY_ESCAPE)
		ok(not get_tree().paused, "a second Escape leaves the menu and the game runs again")
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
