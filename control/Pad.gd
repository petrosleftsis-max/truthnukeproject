extends Node
## Gamepads: which of keyboard-and-mouse or a pad is being used, a pointer the
## sticks move that does everything the mouse does, and the names of the
## buttons to put on screen.
##
## The pointer IS the mouse. Moving it moves the real cursor and sends the same
## motion and click events a mouse would, so everything built for the mouse -
## a hotspot lighting up under it, a click on a tile walking there, a puzzle
## piece dragged across - works from a pad unchanged, and nothing else in the
## game has to know which of the two it was.
##
## How the pad drives it depends on what is on screen (see mode()):
##   A fight              the pointer sits on a tile and the left stick or the
##                        D-pad step it from one to the next - only between
##                        the tiles that would do anything, while aiming or
##                        placing the party (see CController). A clicks
##   A picture            either stick points, A clicks, LB and RB turn a dial
##   Walking about        the left stick walks and the right one points - at a
##                        guard to read his round, or where to throw. A clicks
##                        only on the HUD or while something is being aimed;
##                        anywhere else it is "use"
##   A menu               the D-pad and left stick go from button to button;
##                        the right stick brings the pointer out for anything
##                        that only answers the mouse
##
## View opens the menus - inventory, journal, character sheet, whichever this
## place has - and LB and RB go from one to the next while one is open (see
## the pad_menu group below).
##
## The buttons themselves are actions in Project Settings > Input Map, keyboard
## and pad side by side, so either can be rebound there without touching code.
## key() names whichever is in use, for anything that tells the player what to
## press.
##
## Nodes can join in through groups, by having the methods named:
##   pad_board    pad_board_active() -> bool, pad_cursor_screen() -> Variant (where
##                its cursor tile is on the screen, or null) and pad_tile_step(way)
##                to step it. CController.
##   pad_walk     its being in the tree means walking about. ExplorationScene.
##   pad_pointer  wants_pad_pointer() -> bool: true keeps the pointer up while
##                walking about, and lets A click. StealthWatch, aiming a throw.
##   pad_menu     pad_menu_order() -> int, pad_menu_available() -> bool,
##                pad_menu_is_open() -> bool, pad_menu_open(), pad_menu_close().
##                The inventory, the journal, the character sheet.

## Says that keyboard-and-mouse or a pad has taken over, or that a different
## kind of pad has - anything showing button names should show them again.
signal changed

enum Mode { MENU, WALK, BOARD, PICTURE }

## The device the pointer's own mouse events claim to come from, so they can be
## told apart from a real mouse's.
const POINTER_DEVICE := 7031
## How fast the pointer crosses the screen at full tilt, in pixels a second.
const SPEED := 950.0
## How much a light tilt is slowed beyond that: the tilt is raised to this power,
## so the first half of the stick's travel is for fine work.
const CURVE := 1.8
## How much slower it goes over something it can click, so it does not sail
## past what it was aimed at.
const SLOW_OVER := 0.5
## How long the pointer stays up while walking about after the stick last
## moved it.
const HIDE_AFTER := 3.0
## How far a stick or trigger has to go before it counts as the pad being used:
## a resting stick drifts, and must not wrestle the game away from the mouse.
const WAKE := 0.4
## How far a real mouse has to move before it takes over again. The pointer
## moving the real cursor makes the system report it as moved too, to the
## pixel or near it.
const MOUSE_SLACK := 4.0
## How many of the places the pointer last moved the real cursor to are
## remembered - see _warp. A few frames' worth.
const WARPS_REMEMBERED := 12
## Holding the D-pad on the board: the wait before it starts stepping on its
## own, and the time between steps after that.
const STEP_DELAY := 0.35
const STEP_EVERY := 0.11
## The left stick on the board steps the cursor too, once pushed this far, and
## keeps stepping every this many seconds - slowest just past that, fastest
## pushed all the way.
const STICK_STEP := 0.5
const STICK_SLOW := 0.22
const STICK_FAST := 0.07

## Button names, by layout. Godot names pad buttons by position - A is the
## bottom one whatever is printed on it - so each layout says what is printed.
const NAMES := {
	"xbox": {
		JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
		JOY_BUTTON_BACK: "View", JOY_BUTTON_GUIDE: "Guide", JOY_BUTTON_START: "Menu", JOY_BUTTON_MISC1: "Share", JOY_BUTTON_TOUCHPAD: "Touchpad",
		JOY_BUTTON_LEFT_STICK: "LS", JOY_BUTTON_RIGHT_STICK: "RS",
		JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
		"left_trigger": "LT", "right_trigger": "RT",
	},
	"playstation": {
		JOY_BUTTON_A: "Cross", JOY_BUTTON_B: "Circle", JOY_BUTTON_X: "Square", JOY_BUTTON_Y: "Triangle",
		JOY_BUTTON_BACK: "Create", JOY_BUTTON_GUIDE: "PS", JOY_BUTTON_START: "Options", JOY_BUTTON_MISC1: "Mic", JOY_BUTTON_TOUCHPAD: "Touchpad",
		JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
		JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1",
		"left_trigger": "L2", "right_trigger": "R2",
	},
	"nintendo": {
		JOY_BUTTON_A: "B", JOY_BUTTON_B: "A", JOY_BUTTON_X: "Y", JOY_BUTTON_Y: "X",
		JOY_BUTTON_BACK: "-", JOY_BUTTON_GUIDE: "Home", JOY_BUTTON_START: "+", JOY_BUTTON_MISC1: "Capture", JOY_BUTTON_TOUCHPAD: "Touchpad",
		JOY_BUTTON_LEFT_STICK: "LS", JOY_BUTTON_RIGHT_STICK: "RS",
		JOY_BUTTON_LEFT_SHOULDER: "L", JOY_BUTTON_RIGHT_SHOULDER: "R",
		"left_trigger": "ZL", "right_trigger": "ZR",
	},
}
const DPAD := {
	JOY_BUTTON_DPAD_UP: "Up", JOY_BUTTON_DPAD_DOWN: "Down",
	JOY_BUTTON_DPAD_LEFT: "Left", JOY_BUTTON_DPAD_RIGHT: "Right",
}
## Shorter than what Godot calls them, as the game has always written them.
const KEY_NAMES := {"Escape": "Esc"}

## Whether a pad is what is being played with right now.
var using_pad := false
## Which layout's names to show: "xbox", "playstation" or "nintendo".
var layout := "xbox"
## Whether moving the pointer moves the real cursor too. Off in tests and
## screenshot runs, which must leave the mouse of whoever is at the computer
## alone; everything else the pointer does still happens.
var warps := true

var _point := Vector2.ZERO
var _last_mode := Mode.MENU
var _last_keyboard := false
var _shown := false
var _idle := 0.0
var _clicking := false
var _step_dir := Vector2i.ZERO
var _step_wait := 0.0
var _downs := {}
var _warped: Array = []
var _board_version = 0


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_point = _screen_size() / 2.0
	# Before anything else hears it, so a press that a menu takes for itself -
	# the first A that lights a button up - still says a pad is in use.
	get_tree().root.window_input.connect(_notice)


## --- What is on screen ---


## How the pad drives the pointer right now. See the top of this file.
func mode() -> Mode:
	var journal = get_node_or_null("/root/Journal")
	if journal != null and journal.is_open():
		return Mode.MENU
	if get_viewport().gui_get_focus_owner() != null or _open_menu() != null:
		return Mode.MENU
	var pictures = get_node_or_null("/root/Pictures")
	if pictures != null and pictures.is_open():
		return Mode.PICTURE
	if MenuPause.held_by_another(self):
		return Mode.MENU
	for board in get_tree().get_nodes_in_group(&"pad_board"):
		if board.has_method("pad_board_active") and board.pad_board_active():
			return Mode.BOARD
	if not get_tree().get_nodes_in_group(&"pad_walk").is_empty():
		return Mode.WALK
	return Mode.MENU


## Whether the pointer is up. Always, from a pad, on the board and in a picture.
func pointer_showing() -> bool:
	return using_pad and _shown


## Where the pointer is, on the screen.
func pointer() -> Vector2:
	return _point


## Where the mouse is, on the screen - which, while a pad is in use, is its
## pointer. Ask this rather than the viewport: the pointer moves the real
## cursor along with it, but not when it cannot (another window has the
## focus) or must not (a test).
func screen_point() -> Vector2:
	return _point if using_pad else get_viewport().get_mouse_position()


## Puts the pointer at `at`, on the screen, and brings it up - for whatever
## knows where the player will want it: on the one whose turn it is, on the
## nearest guard when a throw is begun. Kept on the screen, as the mouse is.
## Nothing, from the mouse.
func point_at(at: Vector2):
	if not using_pad:
		return
	_show()
	_move_to(at.clamp(Vector2.ZERO, _screen_size() - Vector2.ONE))


## --- Button names ---


## What to press for the first of `actions` that has something bound for the
## device in use - "E" or "A", "Space" or "Y" - or `otherwise` when none has.
## For the mouse's half of things, which is no action: "Left click".
func key(actions, otherwise: String = "") -> String:
	if actions is String or actions is StringName:
		actions = [actions]
	for action in actions:
		if not InputMap.has_action(action):
			continue
		for event in InputMap.action_get_events(action):
			var named := _name_of(event)
			if named != "":
				return named
	return otherwise


## `text` with what to press after it in brackets - "Back (Esc)", "Back (B)" -
## or plain `text` when nothing is bound for the device in use.
func hint(text: String, actions, otherwise: String = "") -> String:
	var named := key(actions, otherwise)
	return text if named == "" else "%s (%s)" % [text, named]


func _name_of(event: InputEvent) -> String:
	if using_pad:
		if event is InputEventJoypadButton:
			if DPAD.has(event.button_index):
				return "D-pad " + DPAD[event.button_index]
			return NAMES[layout].get(event.button_index, "Button %d" % event.button_index)
		if event is InputEventJoypadMotion:
			match event.axis:
				JOY_AXIS_TRIGGER_LEFT:
					return NAMES[layout]["left_trigger"]
				JOY_AXIS_TRIGGER_RIGHT:
					return NAMES[layout]["right_trigger"]
				JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y:
					return "Left stick"
				_:
					return "Right stick"
		return ""
	if event is InputEventKey:
		var code: Key = event.keycode
		if code == KEY_NONE:
			# What is printed on that key in the player's own layout - Z on a
			# German keyboard where an English one has Y. A headless run has no
			# keyboard to ask, and keeps the English.
			code = event.physical_keycode
			if DisplayServer.get_name() != "headless":
				code = DisplayServer.keyboard_get_keycode_from_physical(code)
		var text := OS.get_keycode_string(code)
		return KEY_NAMES.get(text, text)
	return ""


## Which layout's names a pad goes by, from what it calls itself. An Xbox's
## unless it says it is something else - which most pads either are, or copy.
func layout_named(pad_name: String) -> String:
	var name := pad_name.to_lower()
	for sign in ["playstation", "dualshock", "dualsense", "ps3", "ps4", "ps5", "sony"]:
		if name.contains(sign):
			return "playstation"
	for sign in ["nintendo", "switch", "joy-con", "pro controller"]:
		if name.contains(sign):
			return "nintendo"
	return "xbox"


## --- Presses ---


## True for the press of `action`, once - a trigger included. A stick or a
## trigger reports itself over and over while held, and every one of those is
## "pressed"; this is the moment it went down. Ask it for the same event as
## often as you like: it is the event that went down, not the asking.
func went_down(event: InputEvent, action: StringName) -> bool:
	if not event.is_action_pressed(action):
		return false
	if not event is InputEventJoypadMotion:
		return true
	if not Input.is_action_just_pressed(action):
		return false
	var frame := Engine.get_process_frames()
	var seen = _downs.get(action)
	if seen != null and seen[0] == frame:
		return seen[1] == event
	_downs[action] = [frame, event]
	return true


func _input(event: InputEvent):
	if event is InputEventMouse and event.device == POINTER_DEVICE:
		return
	if not using_pad:
		return
	var now := mode()
	if event.is_action(&"pointer_click"):
		_on_click_button(event, now)
		return
	if _menus(event):
		return
	if now == Mode.PICTURE and _shown:
		# A dial turns to the wheel; so LB and RB turn it, over whatever the
		# pointer is on.
		if went_down(event, &"menus_previous"):
			get_viewport().set_input_as_handled()
			_wheel(MOUSE_BUTTON_WHEEL_DOWN)
		elif went_down(event, &"menus_next"):
			get_viewport().set_input_as_handled()
			_wheel(MOUSE_BUTTON_WHEEL_UP)
		return
	if now == Mode.MENU and _shown and (event is InputEventJoypadButton or event is InputEventJoypadMotion) \
			and _keyboard_menu():
		# Going from button to button again: the pointer steps aside for the
		# highlight, rather than two things on screen both looking chosen.
		for way in [&"ui_up", &"ui_down", &"ui_left", &"ui_right"]:
			if went_down(event, way):
				_hide()
				return


## Whichever was touched last is what is being used. Heard as the window gets
## it, in the window's pixels rather than the game's.
func _notice(event: InputEvent):
	if event is InputEventMouse and event.device == POINTER_DEVICE:
		return
	if event is InputEventJoypadButton:
		if event.pressed:
			_use(true, event.device)
	elif event is InputEventJoypadMotion:
		if absf(event.axis_value) >= WAKE:
			_use(true, event.device)
	elif event is InputEventKey:
		if event.pressed:
			_use(false)
	elif event is InputEventMouseButton:
		if event.pressed:
			_use(false)
	elif event is InputEventMouseMotion:
		var at: Vector2 = get_tree().root.get_final_transform().affine_inverse() * event.position
		if not using_pad:
			_point = at
		elif at.distance_to(_point) > MOUSE_SLACK and not _sent_there(at):
			_point = at
			_use(false)


func _use(pad: bool, device: int = -1):
	var kind := layout_named(Input.get_joy_name(device)) if pad and device >= 0 else layout
	if pad == using_pad and kind == layout:
		return
	var was_pad := using_pad
	using_pad = pad
	layout = kind
	if pad and not was_pad:
		_point = get_viewport().get_mouse_position().clamp(Vector2.ZERO, _screen_size() - Vector2.ONE)
		_idle = 0.0
		_last_mode = mode()
		_last_keyboard = _last_mode == Mode.MENU and _keyboard_menu()
		_settle_for(_last_mode)
	elif not pad:
		if _clicking:
			_clicking = false
			_button(MOUSE_BUTTON_LEFT, false)
		_shown = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	changed.emit()


## A: a click where the pointer is, held for as long as A is - which is a drag,
## for a puzzle piece or anything else that is dragged. Or, where A is not the
## pointer's, left alone for whatever else it is.
func _on_click_button(event: InputEvent, now: Mode):
	if event.is_pressed():
		if event.is_echo() or not _a_clicks(now):
			return
		get_viewport().set_input_as_handled()
		_clicking = true
		_button(MOUSE_BUTTON_LEFT, true)
	elif _clicking:
		get_viewport().set_input_as_handled()
		_clicking = false
		_button(MOUSE_BUTTON_LEFT, false)


func _a_clicks(now: Mode) -> bool:
	match now:
		Mode.BOARD, Mode.PICTURE:
			return true
		Mode.WALK:
			return _shown and (_over_something() or _wanted())
	return _shown and get_viewport().gui_get_focus_owner() == null


## Whether something wants the pointer up while walking about.
func _wanted() -> bool:
	for node in get_tree().get_nodes_in_group(&"pad_pointer"):
		if node.has_method("wants_pad_pointer") and node.wants_pad_pointer():
			return true
	return false


## Whether the pointer is on something on screen a click does something to: a
## button, or anything that shows a hand or the like when the mouse is over it.
func _over_something() -> bool:
	var control := get_viewport().gui_get_hovered_control()
	while control != null:
		if control is BaseButton and not control.disabled:
			return true
		if control.mouse_default_cursor_shape != Control.CURSOR_ARROW:
			return true
		if control.mouse_filter == Control.MOUSE_FILTER_STOP:
			return false
		control = control.get_parent() as Control
	return false


## --- The menus: inventory, journal, character sheet ---


## View opens the first of the menus this place has, or closes whichever is
## open; LB and RB, with one open, go to the one before or after it.
func _menus(event: InputEvent) -> bool:
	var step := 0
	if went_down(event, &"menus"):
		step = 0
	elif went_down(event, &"menus_previous"):
		step = -1
	elif went_down(event, &"menus_next"):
		step = 1
	else:
		return false
	var open := _open_menu()
	if step != 0 and open == null:
		return false
	get_viewport().set_input_as_handled()
	if open != null:
		open.pad_menu_close()
		if step == 0:
			return true
	var ring := _ring()
	if ring.is_empty():
		return true
	var start := ring.find(open) if open != null else (-1 if step >= 0 else 0)
	if step == 0:
		step = 1
	for i in range(1, ring.size() + 1):
		var next = ring[posmod(start + step * i, ring.size())]
		if next == open:
			continue
		if next.pad_menu_available():
			next.pad_menu_open()
			# Most of what is in these is only for the mouse - a slot to
			# click, a clue to pick - so the pointer comes up with it, unless
			# the menu has put a button under the D-pad already.
			if get_viewport().gui_get_focus_owner() == null:
				_idle = 0.0
				_show()
			return true
	return true


## Every menu there is, in order.
func _ring() -> Array:
	var ring := get_tree().get_nodes_in_group(&"pad_menu").filter(func(node): return node.has_method("pad_menu_open"))
	ring.sort_custom(func(a, b): return a.pad_menu_order() < b.pad_menu_order())
	return ring


func _open_menu() -> Node:
	for node in get_tree().get_nodes_in_group(&"pad_menu"):
		if node.has_method("pad_menu_is_open") and node.pad_menu_is_open():
			return node
	return null


## --- Moving it ---


func _process(delta: float):
	if not using_pad:
		return
	var now := mode()
	var keyboard := now == Mode.MENU and _keyboard_menu()
	if now != _last_mode or keyboard != _last_keyboard:
		# Something new on screen - or, still in a menu, one the D-pad could go
		# round giving way to one it cannot, a button pressed in the first
		# having opened the second.
		_last_mode = now
		_last_keyboard = keyboard
		_settle_for(now)
	if now == Mode.BOARD:
		_on_the_board(delta)
		return
	_step_dir = Vector2i.ZERO
	var push := _stick(now)
	if push != Vector2.ZERO:
		_idle = 0.0
		_show()
		var speed := SPEED * pow(minf(push.length(), 1.0), CURVE)
		if _over_something():
			speed *= SLOW_OVER
		_move_to((_point + push.normalized() * speed * delta).clamp(Vector2.ZERO, _screen_size() - Vector2.ONE))
	else:
		_idle += delta
	if now == Mode.PICTURE:
		_show()
	elif now == Mode.WALK and _shown and _idle >= HIDE_AFTER and not _clicking and not _wanted():
		# Not in a menu, where it stays put until the D-pad takes over: the
		# player may be reading what is under it.
		_hide()


## On the board the pointer is the board's cursor tile, wherever that is on the
## screen - which moves as the view does - and the left stick and the D-pad
## step it.
func _on_the_board(delta: float):
	var board = _board()
	if board == null:
		return
	_show()
	_step_tiles(board, delta)
	var at = board.pad_cursor_screen()
	if at != null and (at as Vector2).distance_to(_point) > 0.5:
		_move_to(at)
	elif board.get("pad_version") != _board_version:
		# Something else to aim, or nothing now: the same tile, but what it
		# would do needs showing again.
		_motion(_point, Vector2.ZERO)
	_board_version = board.get("pad_version")


func _board() -> Node:
	for board in get_tree().get_nodes_in_group(&"pad_board"):
		if board.has_method("pad_board_active") and board.pad_board_active():
			return board
	return null


## The pointer up or not, for what has just come on screen. Always on the
## board and in a picture. Walking about, only while it is used. In a menu the
## D-pad can go round - the pause menu, the end of a battle, a question - not,
## the D-pad and A being the way through it; in one it cannot - the inventory,
## the journal - up, since there is no other way.
func _settle_for(now: Mode):
	match now:
		Mode.BOARD, Mode.PICTURE:
			_show()
		Mode.WALK:
			if not _wanted():
				_hide()
		Mode.MENU:
			if _keyboard_menu():
				_hide()
			else:
				_idle = 0.0
				_show()


## Whether what is on screen is a menu the D-pad can go round: a button has the
## keyboard already, or one is waiting for it (FocusOnDemand).
func _keyboard_menu() -> bool:
	if get_viewport().gui_get_focus_owner() != null:
		return true
	for keeper in get_tree().get_nodes_in_group(&"focus_on_demand"):
		if keeper.has_method("is_waiting") and keeper.is_waiting():
			return true
	return false


## Which way the sticks that move the pointer here are pushed.
func _stick(now: Mode) -> Vector2:
	var left := Input.get_vector(&"pointer_left", &"pointer_right", &"pointer_up", &"pointer_down")
	var right := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	if now == Mode.PICTURE:
		return (left + right).limit_length(1.0)
	return right


## The D-pad or the left stick on the board: a tile at a time, and on by
## itself while held - quicker the further the stick is pushed. The stick goes
## the eight ways the D-pad does, whichever its angle is nearest.
func _step_tiles(board: Node, delta: float):
	var way := Vector2i(
		int(Input.is_action_pressed(&"tile_right")) - int(Input.is_action_pressed(&"tile_left")),
		int(Input.is_action_pressed(&"tile_down")) - int(Input.is_action_pressed(&"tile_up")))
	var every := STEP_EVERY
	if way == Vector2i.ZERO:
		var stick := Input.get_vector(&"pointer_left", &"pointer_right", &"pointer_up", &"pointer_down")
		if stick.length() >= STICK_STEP:
			var eighth := roundi(stick.angle() / (PI / 4.0))
			way = Vector2i(roundi(cos(eighth * PI / 4.0)), roundi(sin(eighth * PI / 4.0)))
			every = lerpf(STICK_SLOW, STICK_FAST, inverse_lerp(STICK_STEP, 1.0, minf(stick.length(), 1.0)))
	if way == Vector2i.ZERO:
		_step_dir = Vector2i.ZERO
		return
	if way != _step_dir:
		_step_dir = way
		_step_wait = STEP_DELAY
	else:
		_step_wait -= delta
		if _step_wait > 0.0:
			return
		_step_wait = every
	_idle = 0.0
	board.pad_tile_step(way)


func _move_to(at: Vector2):
	var before := _point
	_point = at
	_motion(at, at - before)
	_warp(at)


func _show():
	if _shown:
		return
	_shown = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_motion(_point, Vector2.ZERO)
	_warp(_point)


## Moves the real cursor to `at`. The system reports that as the mouse moving,
## and not always by the next frame, by when the pointer may have gone on - so
## the last few places it was sent are remembered, and a report of the mouse
## arriving at one of them is not taken for somebody picking the mouse up.
func _warp(at: Vector2):
	if not warps or not DisplayServer.window_is_focused():
		return
	get_viewport().warp_mouse(at)
	_warped.append(at)
	if _warped.size() > WARPS_REMEMBERED:
		_warped.pop_front()


## Whether the mouse being at `at` is only the pointer having put it there.
func _sent_there(at: Vector2) -> bool:
	for sent in _warped:
		if at.distance_to(sent) <= MOUSE_SLACK:
			return true
	return false


func _hide():
	if not _shown and Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
		return
	_shown = false
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


## --- The mouse events it sends ---
##
## Through Input, like the system's own, so that everything downstream - the
## hover, the click, Input's idea of where the mouse is - happens just as it
## would for a mouse. They arrive in window pixels, which the window turns into
## the game's own, so they are sent in window pixels too.


func _motion(at: Vector2, by: Vector2):
	var event := InputEventMouseMotion.new()
	event.device = POINTER_DEVICE
	event.position = _to_window(at)
	event.global_position = event.position
	event.relative = by
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if _clicking else 0
	Input.parse_input_event(event)


func _button(which: MouseButton, down: bool):
	var event := InputEventMouseButton.new()
	event.device = POINTER_DEVICE
	event.button_index = which
	event.pressed = down
	event.position = _to_window(_point)
	event.global_position = event.position
	if down and which == MOUSE_BUTTON_LEFT:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.factor = 1.0
	Input.parse_input_event(event)


func _wheel(which: MouseButton):
	_button(which, true)
	_button(which, false)


func _to_window(at: Vector2) -> Vector2:
	return get_tree().root.get_final_transform() * at


func _screen_size() -> Vector2:
	return get_viewport().get_visible_rect().size


## --- Walking and panning: keys, or the stick ---
##
## Which way `left`/`right`/`up`/`down` are held, keys and stick both - but
## never mixed. Input.get_vector adds every source of an action together, so
## with a pad plugged in whose stick rests a little off centre (one here rests
## a fifth of the way down), holding A on the keyboard walked the party left
## and slowly down. Any of the keys held, the keys alone say which way, all or
## nothing; none, the stick does - snapped straight along an axis when it is
## nearly so, since a stick pushed left is never quite level either.

## Along one axis less than this share of the other, the stick is taken as
## pushed straight along the other: about 17 degrees either side.
const AXIS_SNAP := 0.3


func direction(left: StringName, right: StringName, up: StringName, down: StringName) -> Vector2:
	var keys := Vector2(_key_held(right) - _key_held(left), _key_held(down) - _key_held(up))
	if keys != Vector2.ZERO:
		return keys.limit_length(1.0)
	var held := Input.get_vector(left, right, up, down)
	var most := maxf(absf(held.x), absf(held.y))
	if absf(held.x) < AXIS_SNAP * most:
		held.x = 0.0
	if absf(held.y) < AXIS_SNAP * most:
		held.y = 0.0
	return held


## 1.0 when a key bound to `action` is down, 0.0 otherwise.
func _key_held(action: StringName) -> float:
	if not InputMap.has_action(action):
		return 0.0
	for event in InputMap.action_get_events(action):
		if not event is InputEventKey:
			continue
		if event.physical_keycode != KEY_NONE and Input.is_physical_key_pressed(event.physical_keycode):
			return 1.0
		if event.keycode != KEY_NONE and Input.is_key_pressed(event.keycode):
			return 1.0
	return 0.0
