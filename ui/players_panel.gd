extends VBoxContainer
class_name PlayersPanel
## Who is playing, and whom each steers (Coop; the designer, 2026-10-29). Two at
## most, on one screen: while this is up, a pad nobody plays with joins with A,
## and the keyboard with Enter. Each player has a slot - a line edged in their
## colour - with a button for every character - pressed, that character is
## theirs (Campaign.controllers). Every seat there is shows, one nobody has
## taken dashed and saying how to take it (the designer, 2026-10-31: "its a way
## to show them that it's up to two players").
## Anybody nobody has picked is the first player's. On the title screen (every
## character), and on a map or in a fight (the party as it stands, `only_party`)
## as the pause menu's Party Management (`management`; open_over) - put up by
## itself on a map when a player is left steering nobody (ExplorationScene
## "Co-op"). Over a network, Host and Join are here too (Net), and a change of
## whom each steers is asked of the other player, made only once they agree
## (Net.ask_for; the designer, 2026-10-30); the host can kick the joiner out.

signal closed

const INK := Color("dce8f5")
const MUTED := Color("8296a9")
const CHARACTERS := "res://data/characters/"
## A character's button: room for their portrait over their name.
const PICK_SIZE := Vector2(96, 118)
## Behind a player's slot, over the dimmed game; half as much behind an open one.
const SLOT_FILL := Color(0.043, 0.063, 0.094, 0.8)
## An open slot's dashes, and how thick.
const DASH := 10.0
const DASH_WIDTH := 2.0

## Only who is in the party now, standing - not every character there is.
var only_party := false
## Opened as the pause menu's Party Management, which it is called.
var management := false
## A line over the rest - why it came up, when it came up by itself.
var note := ""
## The player whose Kick out is waiting to be made sure of, or -1.
var _kicking := -1

var _rows: VBoxContainer = null
var _hint: Label = null
## The network's half, when Net is there to fill it.
var network: Control = null


func _ready():
	name = "PlayersPanel"
	process_mode = Node.PROCESS_MODE_ALWAYS
	alignment = BoxContainer.ALIGNMENT_CENTER
	# Over the whole screen, and what it does not take is nobody's: a container
	# only passes a click on, and with nothing under it to stop one the click went
	# through to the map and the HUD behind (the designer, 2026-11-04: "Party
	# management menu doesn't disable clicks on maps and other interfaces").
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_constant_override("separation", 14)
	var title := Label.new()
	title.name = "Title"
	title.theme_type_variation = GameFonts.HEADER
	title.text = "Party Management" if management else "Players"
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
	# What an open slot says changes with the pads plugged in and with hosting.
	Pad.changed.connect(_say_how_to_join)
	Input.joy_connection_changed.connect(_say_how_to_join.unbind(2))
	if net != null and net.has_signal("changed"):
		net.changed.connect(_say_how_to_join)
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
	_hint.text = _hint_text()
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for id in Coop.MAX_PLAYERS:
		_rows.add_child(_row(id) if id < Coop.players.size() else _open_slot(id))
	_say_how_to_join()


func _hint_text() -> String:
	var net := _net()
	if net != null and net.with_another() and net.in_the_game():
		return "Press one of the other player's characters to ask for them, or one of yours in their row to offer them. It changes once they agree - in a fight, as soon as the fight allows."
	if only_party:
		return "Each player picks who they steer of the party as it stands; anybody nobody picks is Player 1's."
	return "Each player picks who they steer; anybody nobody picks is Player 1's."


## A slot's box: edged in its player's colour while somebody plays there,
## dashed while nobody does yet.
func _slot(called: String, id: int, taken: bool) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.name = called
	var box := StyleBoxFlat.new()
	box.bg_color = SLOT_FILL if taken else Color(SLOT_FILL, SLOT_FILL.a * 0.5)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	if taken:
		box.border_color = Color(Coop.colour_of(id), 0.6)
		box.set_border_width_all(2)
		box.set_corner_radius_all(10)
	else:
		slot.draw.connect(_dash_round.bind(slot, Color(Coop.colour_of(id), 0.5)))
	slot.add_theme_stylebox_override("panel", box)
	return slot


## An open slot's dashed edge.
func _dash_round(slot: Control, colour: Color):
	var edge := Rect2(Vector2.ONE * DASH_WIDTH / 2.0, slot.size - Vector2.ONE * DASH_WIDTH)
	var corners := [edge.position, Vector2(edge.end.x, edge.position.y), edge.end, Vector2(edge.position.x, edge.end.y)]
	for i in corners.size():
		slot.draw_dashed_line(corners[i], corners[(i + 1) % corners.size()], colour, DASH_WIDTH, DASH)


## The slot of player `id`, nobody playing there yet: whose it would be, and
## how to take it (_say_how_to_join) where their characters would be.
func _open_slot(id: int) -> Control:
	var slot := _slot("Open%d" % (id + 1), id, false)
	var line := HBoxContainer.new()
	line.name = "Line"
	line.add_theme_constant_override("separation", 10)
	line.custom_minimum_size = Vector2(0, PICK_SIZE.y)
	slot.add_child(line)
	var who := Label.new()
	who.text = "Player %d" % (id + 1)
	who.custom_minimum_size = Vector2(90, 0)
	who.add_theme_font_size_override("font_size", 17)
	who.add_theme_color_override("font_color", Color(Coop.colour_of(id), 0.6))
	line.add_child(who)
	var device := Label.new()
	device.text = "Not playing yet"
	device.custom_minimum_size = Vector2(190, 0)
	device.add_theme_font_size_override("font_size", 13)
	device.add_theme_color_override("font_color", MUTED)
	line.add_child(device)
	var how := VBoxContainer.new()
	how.name = "How"
	how.alignment = BoxContainer.ALIGNMENT_CENTER
	how.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(how)
	var join := Label.new()
	join.name = "Join"
	join.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	join.add_theme_font_size_override("font_size", 16)
	join.add_theme_color_override("font_color", INK)
	how.add_child(join)
	var other := Label.new()
	other.name = "Else"
	other.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	other.add_theme_font_size_override("font_size", 13)
	other.add_theme_color_override("font_color", MUTED)
	how.add_child(other)
	return slot


## What each open slot says: how to take it on this screen, naming only what is
## free - and, hosting, that the other machine's player may take it.
func _say_how_to_join():
	if _rows == null:
		return
	var net := _net()
	for slot in _rows.get_children():
		if not String(slot.name).begins_with("Open"):
			continue
		var join: Label = slot.get_node("Line/How/Join")
		var other: Label = slot.get_node("Line/How/Else")
		join.text = "Waiting for the host's game" if _joining() else how_to_join()
		other.text = "or from another machine, over the network" if net != null and net.is_host() else ""
		other.visible = other.text != ""


## How to take a slot on this screen, naming only what nobody here plays with
## yet: "Press Cross on a pad, or Enter on the keyboard, to join".
static func how_to_join() -> String:
	var keyboard_free := true
	var pad_playing := false
	for id in Coop.local_players():
		if Coop.device_of_player(id) == Coop.KEYBOARD:
			keyboard_free = false
		else:
			pad_playing = true
	var pad := "%s on %s" % [join_button(), "another pad" if pad_playing else "a pad"]
	if keyboard_free:
		return "Press %s, or Enter on the keyboard, to join" % pad
	return "Press %s to join" % pad


## What the pads nobody plays with yet print on the button that joins - the
## bottom one: Cross, A or B - or, where they differ, the last pad played with.
static func join_button() -> String:
	var layouts := {}
	for device in Input.get_connected_joypads():
		if Coop.local_players().all(func(id): return Coop.device_of_player(id) != device):
			layouts[Pad.layout_named(Input.get_joy_name(device))] = true
	var layout: String = layouts.keys()[0] if layouts.size() == 1 else Pad.layout
	return Pad.NAMES[layout][JOY_BUTTON_A]


func _row(id: int) -> Control:
	var player: Dictionary = Coop.players[id]
	var slot := _slot("Player%d" % (id + 1), id, true)
	var row := HBoxContainer.new()
	row.name = "Line"
	row.add_theme_constant_override("separation", 10)
	slot.add_child(row)
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
		row.add_child(_pick(key, id))
	# Over a network the joiner leaves from the network half (Net), and the
	# host - who leads - can kick the joiner out, once it is sure.
	if id > 0 and not _joining():
		if Coop.is_local(id):
			var leave := Button.new()
			leave.name = "Leave"
			leave.text = "Leave"
			leave.flat = true
			leave.pressed.connect(_leave.bind(id))
			row.add_child(leave)
		elif _kicking == id:
			var sure := Label.new()
			sure.text = "Kick %s out?" % Coop.name_of(id)
			sure.add_theme_color_override("font_color", Color("e8c27a"))
			row.add_child(sure)
			var yes := Button.new()
			yes.name = "KickYes"
			yes.text = "Kick out"
			yes.pressed.connect(_kick.bind(id))
			row.add_child(yes)
			var no := Button.new()
			no.name = "KickNo"
			no.text = "Keep"
			no.pressed.connect(func():
				_kicking = -1
				refresh())
			row.add_child(no)
		else:
			var kick := Button.new()
			kick.name = "Kick"
			kick.text = "Kick out"
			kick.flat = true
			kick.tooltip_text = "Send %s's machine out of the game" % Coop.name_of(id)
			kick.pressed.connect(func():
				_kicking = id
				refresh())
			row.add_child(kick)
	return slot


## The button for player `id` steering `key`: their portrait over their name
## (the designer, 2026-10-31), edged in the player's colour while it is theirs.
func _pick(key: String, id: int) -> Button:
	var pick := Button.new()
	pick.name = key
	pick.toggle_mode = true
	pick.text = Campaign.display_name_of(key)
	pick.button_pressed = Coop.controller_of(key) == id
	pick.tooltip_text = "%s steers %s" % [Coop.name_of(id), Campaign.display_name_of(key)]
	pick.custom_minimum_size = PICK_SIZE
	pick.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pick.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	pick.expand_icon = true
	pick.add_theme_font_size_override("font_size", 14)
	var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
	pick.icon = definition.portrait() if definition != null else null
	var theirs := StyleBoxFlat.new()
	theirs.bg_color = Color(Coop.colour_of(id), 0.22)
	theirs.border_color = Coop.colour_of(id)
	theirs.set_border_width_all(3)
	theirs.set_corner_radius_all(6)
	theirs.set_content_margin_all(6)
	pick.add_theme_stylebox_override("pressed", theirs)
	pick.add_theme_stylebox_override("hover_pressed", theirs)
	pick.pressed.connect(choose.bind(key, id))
	return pick


func _net() -> Node:
	return get_node_or_null("/root/Net")


## Whether this machine joined somebody else's game, whose table is theirs.
func _joining() -> bool:
	var net := _net()
	return net != null and net.is_joiner()


func _leave(id: int):
	if Coop.is_local(id):
		Coop.leave(id)


func _kick(id: int):
	_kicking = -1
	if _net() != null:
		_net().kick(id)
	refresh()


## `key` steered by player `id` from now on - over a network, asked of the
## other player (Net.ask_for), the buttons left as they stand until they agree.
func choose(key: String, id: int):
	var net := _net()
	if net != null and net.with_another():
		if not net.in_the_game():
			# Nothing has begun: chosen outright, as on one screen.
			if Coop.controller_of(key) != id:
				net.pick_at_the_table(key, id)
		elif Coop.controller_of(key) != id:
			net.ask_for(key, id)
		refresh()
		return
	if _joining():
		return
	if id <= 0:
		Campaign.controllers.erase(key)
	else:
		Campaign.controllers[key] = id
	Coop.players_changed.emit()
	# In a fight, whose turn this is may be somebody else's now.
	var scene := get_tree().current_scene if is_inside_tree() else null
	if scene is GameScene and scene.combat != null and is_instance_valid(scene.combat) and not scene.combat.combat_over \
			and not scene.combat.combatants.is_empty():
		var combat: Combat = scene.combat
		Coop.fight_turn(combat.player_of(combat.get_current_combatant()) if combat.controller.player_turn else Coop.ANYONE)


## The panel over `scene` - a map or a fight - with the party as it stands, as
## the pause menu's Party Management: on a layer of its own, dimmed behind,
## holding the game while it is up (over a network, only this machine's own
## party). Done frees it.
static func open_over(scene: Node, note: String = "") -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = "PartyManagement"
	layer.layer = 60
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	scene.add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var panel := PlayersPanel.new()
	panel.only_party = true
	panel.management = true
	panel.note = note
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.closed.connect(func():
		MenuPause.release(panel)
		layer.queue_free())
	layer.add_child(panel)
	MenuPause.hold(panel)
	return layer


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
