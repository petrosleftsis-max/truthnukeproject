extends Node
var LOG_PATH := HarnessLog.path_for("probe")
var _log: FileAccess
func log_line(t): _log.store_line(t); _log.flush()

func send(event, at):
	event.position = at
	event.global_position = at
	get_viewport().push_input(event, true)

func click(at, pressed):
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	send(e, at)

func motion(at, mask):
	var e := InputEventMouseMotion.new()
	e.relative = Vector2(2, 1)
	e.button_mask = mask
	send(e, at)

func who(c): return "none" if c == null else "%s(%s)" % [c.name, c.get_class()]

func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	await get_tree().process_frame
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
	log_line("play: %s  rect %s  visible_in_tree=%s" % [who(play), play.get_global_rect(), play.is_visible_in_tree()])
	var presses = [0]
	play.pressed.connect(func(): presses[0] += 1)
	var mid = play.get_global_rect().get_center()

	click(mid, true)
	await get_tree().process_frame
	log_line("after down: focus=%s hovered=%s presses=%d" % [who(get_viewport().gui_get_focus_owner()), who(get_viewport().gui_get_hovered_control()), presses[0]])
	motion(mid + Vector2(2, 1), MOUSE_BUTTON_MASK_LEFT)
	await get_tree().process_frame
	log_line("after move: focus=%s hovered=%s presses=%d" % [who(get_viewport().gui_get_focus_owner()), who(get_viewport().gui_get_hovered_control()), presses[0]])
	click(mid + Vector2(2, 1), false)
	for i in 3:
		await get_tree().process_frame
	log_line("after up: focus=%s hovered=%s presses=%d" % [who(get_viewport().gui_get_focus_owner()), who(get_viewport().gui_get_hovered_control()), presses[0]])

	# And with no motion at all, for comparison.
	var menu2 = load("res://main_menu.tscn").instantiate()
	top.add_child(menu2)
	for i in 3:
		await get_tree().process_frame
	var play2: Button = null
	for node in menu2.find_children("*", "Button", true, false):
		if node.visible and node.text == "Play":
			play2 = node
			break
	var p2 = [0]
	play2.pressed.connect(func(): p2[0] += 1)
	var mid2 = play2.get_global_rect().get_center()
	click(mid2, true)
	await get_tree().process_frame
	click(mid2, false)
	for i in 3:
		await get_tree().process_frame
	log_line("no-motion click on the real menu: presses=%d" % p2[0])

	log_line("FAILURES: 0")
	get_tree().quit(0)
