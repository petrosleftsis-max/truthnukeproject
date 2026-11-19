class_name UiFeel
## The interface in motion (the proposals of 2026-11-16, section 8; the designer, 2026-11-16: "Do all"). The fight's HUD and the
## menus had no motion of their own but the health bars. Now, everywhere there is a button or a panel:
##
## - **Buttons that answer**: a button swells a little under the pointer (HOVER) and dips when pressed (PRESS); one that is
##   disabled, pressed, shakes its head and makes a small dull sound (the SoundBank's Refused, or its stand-in).
## - **Panels that arrive**: a panel coming up fades in over ARRIVE_SECONDS instead of appearing (only fades: see `arrive`).
## - **Whose turn**: as a turn begins their face in the queue steps forward (`step_forward`) and their action bar deals itself in,
##   one button after the next (`deal_in`).
## - **Numbers that count**: gold, health and castings count up or down to their new value (`count_to`) over COUNT_SECONDS.
##
## Listened for once, from the SceneTransition autoload, as the button click is (GameSounds.listen). A control with the meta
## `no_feel` is left alone. Only to look at: nothing waits on any of it, a button does what it did the instant it is pressed, and
## headless nothing moves (a number is simply written) unless `plays_headless` (a suite). `seen` counts what happened either way.
## All numbers PROPOSAL.

const HOVER := 1.045
const PRESS := 0.95
const SECONDS := 0.09
const SHAKE_DEGREES := 3.5
const SHAKE_SECONDS := 0.26
const ARRIVE_SECONDS := 0.11
const DEAL_EVERY := 0.022
const DEAL_SECONDS := 0.13
const STEP_FORWARD := 1.16
const COUNT_SECONDS := 0.35
const POP := 1.18
const NO_FEEL := &"no_feel"

static var plays_headless := false
## What happened, for a suite: &"hover", &"press", &"refused", &"arrived", &"dealt", &"stepped", &"counted", &"popped".
static var seen := {}


static func shown() -> bool:
	return plays_headless or DisplayServer.get_name() != "headless"


static func _note(what: StringName):
	seen[what] = int(seen.get(what, 0)) + 1


## Every button and panel in the game moves from now on. Once, from an autoload.
static func listen(tree: SceneTree):
	if not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)


static func _on_node_added(node: Node):
	# A node is added again each time it comes back into the tree (moved to another parent, a panel rebuilt): its signals are
	# connected only the first time.
	if not (node is BaseButton or node is PanelContainer) or node.has_meta(&"_feel_on"):
		return
	node.set_meta(&"_feel_on", true)
	if node is BaseButton:
		node.mouse_entered.connect(_hover.bind(node, true))
		node.mouse_exited.connect(_hover.bind(node, false))
		node.button_down.connect(_press.bind(node, true))
		node.button_up.connect(_press.bind(node, false))
		node.gui_input.connect(_maybe_refused.bind(node))
	elif node is PanelContainer:
		node.visibility_changed.connect(_arrived.bind(node))


static func _moves(control: Control) -> bool:
	return is_instance_valid(control) and control.is_inside_tree() and not control.has_meta(NO_FEEL) and shown()


## The meta `key` on `object`, or null if it has none. get_meta's own default does not do: a null default prints an error.
static func _meta(object: Object, key: StringName) -> Variant:
	return object.get_meta(key) if object.has_meta(key) else null


static func _tween_of(control: Control, key: StringName) -> Tween:
	var old = _meta(control, key)
	if old is Tween and old.is_valid():
		old.kill()
	var tween := control.create_tween()
	# The menus are up while the game is held, and a hit-stop must not freeze a button mid-press.
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ignore_time_scale(true)
	control.set_meta(key, tween)
	return tween


## The scale a control rests at: what it had before anything here moved it, kept while it is moved. A control the game scales
## itself is swollen and dipped about its own size and put back to it, never to 1.
static func rest_of(control: Control) -> Vector2:
	if not control.get_meta(&"_feel_moved", false):
		control.set_meta(&"_feel_rest", control.scale)
	return control.get_meta(&"_feel_rest", control.scale)


## Moves `control` to `factor` of its resting scale; at 1 it is at rest again once there.
static func _scale_to(control: Control, factor: float, seconds: float = SECONDS):
	var rest := rest_of(control)
	control.set_meta(&"_feel_moved", true)
	control.pivot_offset = control.size * 0.5
	var tween := _tween_of(control, &"_feel_scale")
	tween.tween_property(control, "scale", rest * factor, seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	if is_equal_approx(factor, 1.0):
		tween.tween_callback(func(): control.set_meta(&"_feel_moved", false))


static func _hover(button: BaseButton, on: bool):
	if not _moves(button) or button.disabled:
		return
	if on:
		_note(&"hover")
	_scale_to(button, HOVER if on else 1.0)


static func _press(button: BaseButton, down: bool):
	if not _moves(button):
		return
	if down:
		_note(&"press")
	_scale_to(button, PRESS if down else (HOVER if button.is_hovered() and not button.disabled else 1.0))


static func _maybe_refused(event: InputEvent, button: BaseButton):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and button.disabled:
		refuse(button)


## `control` shakes its head: what was asked of it cannot be done just now.
static func refuse(control: Control):
	_note(&"refused")
	if not _moves(control):
		return
	MapFeel.sound(&"refused", -12.0)
	control.pivot_offset = control.size * 0.5
	var shake := _tween_of(control, &"_feel_shake")
	var turn := deg_to_rad(SHAKE_DEGREES)
	for swing in [1.0, -0.8, 0.5, -0.25, 0.0]:
		shake.tween_property(control, "rotation", turn * swing, SHAKE_SECONDS / 5.0).set_trans(Tween.TRANS_SINE)


static func _arrived(panel: Control):
	if panel.is_visible_in_tree():
		arrive(panel)


## `panel` comes up: faded in. Only its alpha: the HUD's parts are scaled and placed by the interface's size (combat_ui's
## apply_ui_scale, about their own pivots), so a panel is never grown or moved here. One whose alpha the game is keeping for its
## own reasons (anything but whole) is left alone.
static func arrive(panel: Control):
	_note(&"arrived")
	if not _moves(panel) or panel.modulate.a < 0.99:
		return
	panel.modulate.a = 0.0
	var tween := _tween_of(panel, &"_feel_arrive")
	tween.tween_property(panel, "modulate:a", 1.0, ARRIVE_SECONDS)


## `buttons` deal themselves in, one after the next: a turn's action bar.
static func deal_in(buttons: Array):
	_note(&"dealt")
	var nth := 0
	for button in buttons:
		# Dealt a moment after they were asked for (call_deferred), so some may be gone already: the bar rebuilt meanwhile.
		if not is_instance_valid(button) or not button is Control or not _moves(button) or not button.is_visible_in_tree() or button.modulate.a < 0.99:
			continue
		var rest := rest_of(button)
		button.set_meta(&"_feel_moved", true)
		button.pivot_offset = button.size * 0.5
		button.modulate.a = 0.0
		button.scale = rest * 0.82
		var tween := _tween_of(button, &"_feel_scale")
		tween.tween_interval(DEAL_EVERY * nth)
		tween.tween_property(button, "modulate:a", 1.0, DEAL_SECONDS)
		tween.parallel().tween_property(button, "scale", rest, DEAL_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.tween_callback(func(): button.set_meta(&"_feel_moved", false))
		nth += 1


## `face` steps forward: whoever's turn it is, in the queue. From the size of the rest it swells past `rest` (the size the
## current face is kept at) and settles there.
static func step_forward(face: Control, rest: Vector2):
	_note(&"stepped")
	if not _moves(face):
		return
	var tween := _tween_of(face, &"_feel_scale")
	face.scale = Vector2.ONE
	tween.tween_property(face, "scale", rest * STEP_FORWARD / 1.04, SECONDS).set_ease(Tween.EASE_OUT)
	tween.tween_property(face, "scale", rest, SECONDS * 1.6).set_ease(Tween.EASE_IN_OUT)


## `label` counts from the number it last showed to `to`, written each step by `write` (a number -> the text). The first time,
## and headless, it is simply written.
static func count_to(label: Label, to: int, write: Callable):
	var from = _meta(label, &"_feel_number")
	label.set_meta(&"_feel_number", to)
	if from == null or int(from) == to or not _moves(label) or not label.is_visible_in_tree():
		var old = _meta(label, &"_feel_count")
		if old is Tween and old.is_valid():
			old.kill()
		label.text = write.call(to)
		return
	_note(&"counted")
	var tween := _tween_of(label, &"_feel_count")
	tween.tween_method(func(value: float): label.text = write.call(roundi(value)), float(from), float(to), COUNT_SECONDS).set_ease(Tween.EASE_OUT)


## A small pop: something on the HUD has just changed (a gate's castings).
static func pop(control: Control):
	_note(&"popped")
	if not _moves(control) or not control.is_visible_in_tree():
		return
	var rest := rest_of(control)
	control.set_meta(&"_feel_moved", true)
	control.pivot_offset = control.size * 0.5
	var tween := _tween_of(control, &"_feel_scale")
	tween.tween_property(control, "scale", rest * POP, SECONDS * 0.6).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", rest, SECONDS * 1.6).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func(): control.set_meta(&"_feel_moved", false))
