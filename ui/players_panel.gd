extends VBoxContainer
class_name PlayersPanel
## Who is playing, and whom each steers (Coop; the designer, 2026-10-29). Two at
## most, on one screen: while this is up, a pad nobody plays with joins with A,
## and the keyboard with Enter. Each player has a row with a button for every
## character - pressed, that character is theirs (Campaign.controllers).
## Anybody nobody has picked is the first player's. On the title screen (every
## character), and on a map (the party as it stands, `only_party`) - put up by
## itself when a player is left steering nobody (ExplorationScene "Co-op").
## Over a network, Host and Join are here too (Net).

signal closed

const INK := Color("dce8f5")
const MUTED := Color("8296a9")
const CHARACTERS := "res://data/characters/"

## Only who is in the party now, standing - not every character there is.
var only_party := false
## A line over the rest - why it came up, when it came up by itself.
var note := ""

var _rows: VBoxContainer = null
var _hint: Label = null
## The network's half, when Net is there to fill it.
var network: Control = null


func _ready():
	name = "PlayersPanel"
	process_mode = Node.PROCESS_MODE_ALWAYS
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 14)
	var title := Label.new()
	title.theme_type_variation = GameFonts.HEADER
	title.text = "Players"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", INK)
	add_child(title)
	if note != "":
		var why := Label.new()
		why.name = "Note"
		why.text = note
		why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		why.custom_minimum_size = Vector2(640, 0)
		why.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		why.add_theme_font_size_override("font_size", 16)
		why.add_theme_color_override("font_color", Color("e8c27a"))
		add_child(why)
	_hint = Label.new()
	_hint.name = "Hint"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(640, 0)
	_hint.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", MUTED)
	_hint.text = "Up to %d on one screen. Press A on a pad, or Enter on the keyboard, to join. Then each player picks who they steer; anybody nobody picks is Player 1's." % Coop.MAX_PLAYERS
	if only_party:
		_hint.text = "Each player picks who they steer of the party as it stands; anybody nobody picks is Player 1's."
	add_child(_hint)
	_rows = VBoxContainer.new()
	_rows.name = "Rows"
	_rows.add_theme_constant_override("separation", 10)
	_rows.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(_rows)
	var net = get_node_or_null("/root/Net")
	if net != null and net.has_method("make_panel"):
		network = net.make_panel()
		network.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		add_child(network)
	var done := Button.new()
	done.name = "Done"
	done.text = Pad.hint("Done", &"ui_cancel")
	done.custom_minimum_size = Vector2(220, 42)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.pressed.connect(close)
	add_child(done)
	Coop.players_changed.connect(refresh)
	visibility_changed.connect(_on_visibility_changed)
	# Once whoever put it up has said whether it is showing yet.
	_on_visibility_changed.call_deferred()
	refresh()


func _exit_tree():
	Coop.accepting_joins = false


func _on_visibility_changed():
	Coop.accepting_joins = is_visible_in_tree()
	if is_visible_in_tree() and Coop.players.is_empty():
		# Whoever opened it is Player 1, with whatever they opened it with.
		Coop.join(Pad.pointer_pad if Pad.using_pad else Coop.KEYBOARD)


## Every character there is to steer, by key.
static func characters() -> Array:
	var found := []
	for key in CombatantDatabase.combatants:
		var definition: CombatantDefinition = CombatantDatabase.combatants[key]
		if definition != null and definition.resource_path.begins_with(CHARACTERS):
			found.append(key)
	found.sort()
	return found


## The party standing now, in marching order.
static func party_now() -> Array:
	return Array(Campaign.party_order).filter(func(key): return Campaign.is_alive(key))


## What a player plays with, in words.
static func device_name(device: int) -> String:
	if device == Coop.KEYBOARD:
		return "Keyboard and mouse"
	var called := Input.get_joy_name(device)
	return "Pad %d%s" % [device + 1, " (%s)" % called if called != "" else ""]


func refresh():
	if _rows == null:
		return
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for id in Coop.players.size():
		_rows.add_child(_row(id))


func _row(id: int) -> Control:
	var player: Dictionary = Coop.players[id]
	var row := HBoxContainer.new()
	row.name = "Player%d" % (id + 1)
	row.add_theme_constant_override("separation", 10)
	var who := Label.new()
	who.text = Coop.name_of(id)
	who.custom_minimum_size = Vector2(90, 0)
	who.add_theme_font_size_override("font_size", 17)
	who.add_theme_color_override("font_color", Coop.colour_of(id))
	row.add_child(who)
	var device := Label.new()
	device.text = device_name(player.device) if Coop.is_local(id) else "Over the network"
	device.custom_minimum_size = Vector2(190, 0)
	device.add_theme_font_size_override("font_size", 13)
	device.add_theme_color_override("font_color", MUTED)
	row.add_child(device)
	for key in (party_now() if only_party else characters()):
		var pick := Button.new()
		pick.name = key
		pick.toggle_mode = true
		pick.text = Campaign.display_name_of(key)
		pick.button_pressed = Coop.controller_of(key) == id
		pick.tooltip_text = "%s steers %s" % [Coop.name_of(id), Campaign.display_name_of(key)]
		pick.pressed.connect(choose.bind(key, id))
		row.add_child(pick)
	# Over a network the joiner leaves from the network half (Net), and the
	# host's Leave on the joiner's row sends their machine away.
	if id > 0 and not _joining():
		var leave := Button.new()
		leave.name = "Leave"
		leave.text = "Leave"
		leave.flat = true
		leave.pressed.connect(_leave.bind(id))
		row.add_child(leave)
	return row


func _net() -> Node:
	return get_node_or_null("/root/Net")


## Whether this machine joined somebody else's game, whose table is theirs.
func _joining() -> bool:
	var net := _net()
	return net != null and net.is_joiner()


func _leave(id: int):
	if Coop.is_local(id):
		Coop.leave(id)
	elif _net() != null:
		_net().send_away(id)


## `key` steered by player `id` from now on - on a joiner, asked of the host.
func choose(key: String, id: int):
	if _joining():
		_net().ask_to_steer(key, id)
		return
	if id <= 0:
		Campaign.controllers.erase(key)
	else:
		Campaign.controllers[key] = id
	Coop.players_changed.emit()


func close():
	Coop.accepting_joins = false
	closed.emit()


## A pad or the keyboard nobody plays with yet joins.
func _input(event: InputEvent):
	if not is_visible_in_tree() or not event.is_pressed() or event.is_echo():
		return
	var device := -99
	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A:
		device = event.device
	elif event is InputEventKey and event.is_action_pressed(&"ui_accept"):
		device = Coop.KEYBOARD
	# One player for each machine over a network.
	if device == -99 or _joining():
		return
	for player in Coop.players:
		if player.device == device and Coop.is_local(player.id):
			return
	if Coop.join(device) >= 0:
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent):
	if is_visible_in_tree() and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
