extends Node
## The players: who they are, what each plays with, which of the party each
## steers, and whose input counts right now (the designer, 2026-10-29;
## docs/multiplayer_plan.md). One player - the only one outside co-op - plays
## with everything, as the game always has, and nothing here changes a thing.
##
## With more than one (on()), each player has a device: the keyboard and mouse
## (KEYBOARD) or a pad, by its number. Over a network (Net) players on another
## machine have that machine's peer id, and only this machine's own are read
## from its devices.
##
## Two things say whose input counts:
##   focus    whose turn it is in a fight, or who opened the menu or started
##            the conversation that holds everybody. While somebody has it, the
##            others' presses are dropped before anything hears them (the gate).
##   acting   who the press being handled now came from. On a map everybody
##            walks at once, and what a press does - E, G, Tab, Stay - is done
##            as that player: Campaign.living_party() puts their characters
##            first, so Campaign.leader() is their leader, and
##            ExplorationScene.party is their group.
##
## Which character each player steers is Campaign.controllers (saved).

signal players_changed
signal focus_changed

const KEYBOARD := -1
## Any device at all - Pad reads every pad, as outside co-op.
const ANY_DEVICE := -2
## A press from another machine's player arrives on this device plus their
## number (Net).
const REMOTE_DEVICE_BASE := 9000
## Nobody in particular: everybody's input counts.
const ANYONE := -1
## Two at most (the designer, 2026-10-29).
const MAX_PLAYERS := 2
## Each player's colour, for their name, their characters' rings and turns.
const COLOURS := [Color("f2c14e"), Color("5ec8f2"), Color("e46fd0"), Color("7ed37b")]

## [{id, device, name, peer}] - `id` is the index; `peer` is the machine (0,
## or this machine's own peer id, for players here).
var players: Array = []
## Whose input counts, or ANYONE.
var focus := ANYONE : set = _set_focus
## Who the press being handled came from, or ANYONE.
var acting := ANYONE
## Taking new players: presses from devices nobody plays with get through.
var accepting_joins := false
## This machine's peer id once networked (Net sets it), else 0.
var local_peer := 0
## Set by Net while a network game is on.
var networked := false

var _gate: Node = null
## What focus was before a menu or a conversation took it.
var _focus_before := []


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Before everybody else's _process, so `acting` is clear of the last
	# frame's presses by the time anything reads it.
	process_priority = -10000
	process_physics_priority = -10000
	_gate = _Gate.new()
	_gate.name = "CoopGate"
	get_tree().root.add_child.call_deferred(_gate)
	get_tree().root.child_entered_tree.connect(_keep_gate_last)
	var dialogue = get_node_or_null("/root/DialogueManager")
	if dialogue != null:
		dialogue.dialogue_started.connect(_on_dialogue_started)
		dialogue.dialogue_ended.connect(_on_dialogue_ended)


func _process(_delta):
	acting = ANYONE


func _physics_process(_delta):
	acting = ANYONE


## Whether more than one person is playing.
func on() -> bool:
	return players.size() > 1 or networked


## --- Players ---


## Adds a player playing with `device`, here (or on `peer`'s machine) - their
## number, or -1 when the table is full or the device is taken.
func join(device: int, called: String = "", peer: int = -1) -> int:
	if players.size() >= MAX_PLAYERS:
		return -1
	var at := local_peer if peer < 0 else peer
	for player in players:
		if player.device == device and player.peer == at:
			return -1
	var id := players.size()
	players.append({"id": id, "device": device, "name": called if called != "" else "Player %d" % (id + 1), "peer": at})
	players_changed.emit()
	return id


## Takes player `id` out; those after them move up a number, and what they
## steered goes to the first player.
func leave(id: int):
	if id < 0 or id >= players.size():
		return
	players.remove_at(id)
	var renumbered := {}
	for key in Campaign.controllers:
		var was: int = Campaign.controllers[key]
		if was > id:
			renumbered[key] = was - 1
		elif was < id:
			renumbered[key] = was
	Campaign.controllers = renumbered
	for i in players.size():
		players[i].id = i
	if focus == id:
		focus = ANYONE
	players_changed.emit()


## Back to one player, with everything.
func reset():
	players.clear()
	focus = ANYONE
	acting = ANYONE
	accepting_joins = false
	_focus_before.clear()
	players_changed.emit()


func player(id: int) -> Dictionary:
	return players[id] if id >= 0 and id < players.size() else {}


func name_of(id: int) -> String:
	return player(id).get("name", "Player %d" % (id + 1))


func colour_of(id: int) -> Color:
	return COLOURS[posmod(id, COLOURS.size())]


func device_of_player(id: int) -> int:
	return player(id).get("device", ANY_DEVICE)


## Whether player `id` plays on this machine.
func is_local(id: int) -> bool:
	var found := player(id)
	return not found.is_empty() and (found.peer == 0 or found.peer == local_peer)


## The players on this machine, by number.
func local_players() -> Array:
	return range(players.size()).filter(is_local)


## --- Whose characters ---


## The player who steers `key` - the first player for anybody unassigned, or
## assigned to somebody no longer playing.
func controller_of(key: String) -> int:
	var id: int = Campaign.controllers.get(key, 0)
	return id if id >= 0 and id < maxi(players.size(), 1) else 0


## The living party `id` steers, in marching order.
func keys_of(id: int) -> Array:
	var mine := []
	for key in Campaign.party_order:
		if Campaign.is_alive(key) and controller_of(key) == id:
			mine.append(key)
	return mine


## The players steering nobody of the party standing - their characters gone
## from it, or fallen. Outside co-op, nobody.
func stranded() -> Array:
	if not on():
		return []
	var found := []
	for id in players.size():
		if keys_of(id).is_empty():
			found.append(id)
	return found


## How the party and who steers whom stand now - so a map offers to share them
## out again once for each change that leaves somebody steering nobody
## (ExplorationScene.share_out), not again and again.
func party_shape() -> String:
	var standing := Array(Campaign.party_order).filter(func(key): return Campaign.is_alive(key))
	return var_to_str([standing, Campaign.controllers, players.size()])


## The party_shape the map last offered to share out.
var share_out_offered := ""


## The players who steer anybody standing, by number.
func players_in_the_party() -> Array:
	var found := []
	for key in Campaign.party_order:
		if not Campaign.is_alive(key):
			continue
		var id := controller_of(key)
		if not found.has(id):
			found.append(id)
	found.sort()
	return found


## `keys` (Campaign's living party) with the acting player's - or, acting
## nobody, the first player's - first, each lot in marching order. Outside
## co-op, as they are.
func ordered(keys: Array) -> Array:
	if not on():
		return keys
	var first := acting if acting != ANYONE else _first_with_anybody(keys)
	var mine := []
	var rest := []
	for key in keys:
		if controller_of(key) == first:
			mine.append(key)
		else:
			rest.append(key)
	return mine + rest


func _first_with_anybody(keys: Array) -> int:
	var lowest := MAX_PLAYERS
	for key in keys:
		lowest = mini(lowest, controller_of(key))
	return lowest if lowest < MAX_PLAYERS else 0


## --- Devices ---


## The device `event` came from: a pad's number, or KEYBOARD for the keyboard
## and mouse. The pad pointer's mouse events are the pad's that moved it. A
## press made on another machine and handed in here (Net) keeps its own
## number, REMOTE_DEVICE_BASE and up.
func device_of(event: InputEvent) -> int:
	if event.device >= REMOTE_DEVICE_BASE:
		return event.device
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return event.device
	if event is InputEventMouse and event.device == Pad.POINTER_DEVICE:
		return Pad.pointer_pad
	return KEYBOARD


## Which of this machine's players `event` came from, or ANYONE for a device
## nobody here plays with. Outside co-op, the first player.
func player_of_event(event: InputEvent) -> int:
	if not on():
		return 0
	var device := device_of(event)
	if device >= REMOTE_DEVICE_BASE:
		# Another machine's player: theirs, and never anybody here.
		var id := device - REMOTE_DEVICE_BASE
		return id if id < players.size() and not is_local(id) else ANYONE
	for id in players.size():
		if players[id].device == device and is_local(id):
			return id
	return ANYONE


## Which pad may drive the pointer: ANY_DEVICE outside co-op and while
## nobody has the focus, KEYBOARD (none) while a keyboard player has it, else
## the pad of whoever does.
func pointer_device() -> int:
	if not on() or focus == ANYONE:
		return ANY_DEVICE
	return device_of_player(focus)


## How far `action` is held on `device`, 0 to 1: a pad's buttons and sticks,
## or the keyboard's keys and mouse buttons.
func strength(device: int, action: StringName) -> float:
	if not InputMap.has_action(action):
		return 0.0
	var dead := InputMap.action_get_deadzone(action)
	var most := 0.0
	for event in InputMap.action_get_events(action):
		if device == KEYBOARD:
			if event is InputEventKey:
				if (event.physical_keycode != KEY_NONE and Input.is_physical_key_pressed(event.physical_keycode)) \
						or (event.keycode != KEY_NONE and Input.is_key_pressed(event.keycode)):
					return 1.0
			elif event is InputEventMouseButton and Input.is_mouse_button_pressed(event.button_index):
				return 1.0
			continue
		if event.device >= 0 and event.device != device:
			continue
		if event is InputEventJoypadButton:
			if Input.is_joy_button_pressed(device, event.button_index):
				return 1.0
		elif event is InputEventJoypadMotion:
			var value := Input.get_joy_axis(device, event.axis)
			if signf(value) == signf(event.axis_value) and absf(value) > dead:
				most = maxf(most, inverse_lerp(dead, 1.0, minf(absf(value), 1.0)))
	return most


## Whether `action` is held on `device`.
func held(device: int, action: StringName) -> bool:
	return strength(device, action) > 0.0


## Which way `device` holds the four actions, as Input.get_vector would for it alone.
func device_vector(device: int, left: StringName, right: StringName, up: StringName, down: StringName) -> Vector2:
	return Vector2(strength(device, right) - strength(device, left), strength(device, down) - strength(device, up)).limit_length(1.0)


## Which way player `id` is walking: their keys, all or nothing, or their stick
## (as Pad.direction, for them alone).
func direction(id: int, left: StringName, right: StringName, up: StringName, down: StringName) -> Vector2:
	var device := device_of_player(id)
	if device == KEYBOARD:
		return Pad.key_direction(left, right, up, down)
	if device < 0:
		return Pad.direction(left, right, up, down)
	return Pad.snap_to_axis(device_vector(device, left, right, up, down))


## --- Focus ---


func _set_focus(value: int):
	if value == focus:
		return
	focus = value
	focus_changed.emit()


## Gives the focus to player `id` until let_go(holder) - a menu opened, a
## conversation begun - and gives it back to whoever had it before.
func take_focus(id: int, holder: Object):
	if not on():
		return
	var given := id if id != ANYONE else focus
	_focus_before.append([holder.get_instance_id() if holder != null else 0, focus, given])
	focus = given


func let_go(holder: Object):
	var id := holder.get_instance_id() if holder != null else 0
	for i in range(_focus_before.size() - 1, -1, -1):
		if _focus_before[i][0] == id:
			# Only the latest gives the focus back; one let go from under
			# another hands what it had kept to the one above it.
			if i == _focus_before.size() - 1:
				focus = _focus_before[i][1]
			else:
				_focus_before[i + 1][1] = _focus_before[i][1]
			_focus_before.remove_at(i)
			return


## A menu holding the game (MenuPause): the player who opened it has it alone.
## Over a network a menu holds nothing (the designer, 2026-10-29) - each
## machine has its own screen, and the other plays on.
func menu_held(holder: Object):
	var net = get_node_or_null("/root/Net")
	if on() and acting != ANYONE and not (net != null and net.with_another()):
		take_focus(acting, holder)


func menu_released(holder: Object):
	let_go(holder)


## Every menu gone at once (a scene change): nobody keeps a menu's focus -
## a conversation still going keeps its own.
func menus_cleared():
	if _focus_before.is_empty():
		return
	var mine := get_instance_id()
	var first_before: int = _focus_before[0][1]
	var kept := []
	for entry in _focus_before:
		if entry[0] == mine:
			kept.append(entry)
	_focus_before = kept
	focus = kept.back()[2] if not kept.is_empty() else first_before


func _on_dialogue_started(_resource):
	# Whoever started it chooses (the plan's default - PROPOSAL); a
	# conversation nobody pressed for (walked into, after a fight) is the
	# first player's.
	if on():
		take_focus(acting if acting != ANYONE else (focus if focus != ANYONE else 0), self)


func _on_dialogue_ended(_resource):
	let_go(self)


## A fight's turn begun: `id` - whoever steers the one acting, or ANYONE for
## the AI's - has the board.
func fight_turn(id: int):
	if on():
		focus = id


## --- The gate ---
##
## The last node in the tree, so the first to hear every press (input goes from
## the end of the tree backwards): it notes who pressed, and drops the press if
## somebody else has the focus, or nobody here plays with that device.


func _keep_gate_last(node: Node):
	if node != _gate and _gate != null and _gate.is_inside_tree():
		get_tree().root.move_child.call_deferred(_gate, -1)


## Whether `event` gets through.
func lets_through(event: InputEvent) -> bool:
	if not on():
		return true
	var who := player_of_event(event)
	acting = who
	if who == ANYONE:
		return accepting_joins
	# A ping is for whenever - somebody else's turn above all (Pings).
	if event.is_action(&"ping"):
		return true
	return focus == ANYONE or who == focus


class _Gate extends Node:
	func _ready():
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _input(event: InputEvent):
		# On a joiner, a press that does something to the world goes to the host
		# instead (Net.forwards) - and catching up with a fight joined under way,
		# nothing of this machine's own is pressed (Net.drops).
		var net = get_node_or_null("/root/Net")
		if net != null and (net.drops(event) or net.forwards(event)):
			get_viewport().set_input_as_handled()
			return
		var coop = get_node_or_null("/root/Coop")
		if coop != null and not coop.lets_through(event):
			get_viewport().set_input_as_handled()
