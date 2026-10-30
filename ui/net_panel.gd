extends VBoxContainer
class_name NetPanel
## The Players panel's network half (Net, docs/multiplayer_plan.md Step 2): host
## a game, or join one - from the games heard on this network, or by typing an
## address - and, once on, leave it again. It listens for hosts only once asked
## to (Look for games), and only while it shows: listening on the network is
## what makes Windows ask about its firewall, which nobody playing on one
## screen should be asked.

const INK := Color("dce8f5")
const MUTED := Color("8296a9")
const WARM := Color("e8c27a")

var _status: Label = null
var _said: Label = null
var _host: Button = null
var _look: Button = null
var _games: VBoxContainer = null
var _typed: HBoxContainer = null
var _address: LineEdit = null
var _leave: Button = null


func _ready():
	name = "Network"
	add_theme_constant_override("separation", 8)
	var heading := Label.new()
	heading.theme_type_variation = GameFonts.HEADER
	heading.text = "Over a network"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", INK)
	add_child(heading)
	_status = _line("Status", MUTED)
	_said = _line("Said", WARM)
	_host = _button("Host", "Host a game", func(): Net.host())
	_look = _button("Look", "Look for games", _look_for_games)
	_games = VBoxContainer.new()
	_games.name = "Games"
	_games.add_theme_constant_override("separation", 4)
	add_child(_games)
	_typed = HBoxContainer.new()
	_typed.name = "Typed"
	_typed.alignment = BoxContainer.ALIGNMENT_CENTER
	_typed.add_theme_constant_override("separation", 8)
	add_child(_typed)
	_address = LineEdit.new()
	_address.name = "Address"
	_address.placeholder_text = "Address, as the host's screen shows it"
	_address.custom_minimum_size = Vector2(320, 0)
	_address.text_submitted.connect(func(_text): _join_typed())
	_typed.add_child(_address)
	var join := Button.new()
	join.name = "Join"
	join.text = "Join"
	join.custom_minimum_size = Vector2(90, 0)
	join.pressed.connect(_join_typed)
	_typed.add_child(join)
	_leave = _button("Leave", "Leave the game", func(): Net.leave())
	Net.changed.connect(refresh)
	Net.games_found.connect(refresh)
	Net.told.connect(_on_told)
	visibility_changed.connect(_stop_when_hidden)
	refresh()


func _exit_tree():
	if not Net.active():
		Net.stop_looking()


func _line(called: String, colour: Color) -> Label:
	var label := Label.new()
	label.name = called
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(640, 0)
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", colour)
	add_child(label)
	return label


func _button(called: String, text: String, does: Callable) -> Button:
	var button := Button.new()
	button.name = called
	button.text = text
	button.custom_minimum_size = Vector2(220, 36)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(does)
	add_child(button)
	return button


func _look_for_games():
	var err := Net.look_for_games()
	if err != OK:
		_said.text = "Could not listen for games on this network: %s." % error_string(err)
	refresh()


func _stop_when_hidden():
	if not is_visible_in_tree() and not Net.active():
		Net.stop_looking()
		refresh()


func _join_typed():
	if _address.text.strip_edges() != "":
		Net.join(_address.text)


func _on_told(text: String):
	_said.text = text


func refresh():
	if _status == null:
		return
	var idle := not Net.active()
	_host.visible = idle
	_look.visible = idle
	_look.disabled = Net.looking()
	_look.text = "Looking for games..." if Net.looking() else "Look for games"
	_typed.visible = idle
	_games.visible = idle and Net.looking()
	_leave.visible = not idle
	if Net.is_host():
		_leave.text = "Stop hosting"
		var addresses := Net.own_addresses()
		var lines := ["Hosting. On this network the other player finds this game with Look for games, or types %s." % (
			" or ".join(addresses) if not addresses.is_empty() else "this machine's address")]
		match Net.router:
			Net.Router.ASKING:
				lines.append("Asking the router to open the game to the internet...")
			Net.Router.OPEN:
				lines.append("Over the internet, the other player types %s:%d." % [Net.public_address, Net.host_port])
			Net.Router.CLOSED:
				lines.append("The router would not open the game to the internet. To play over the internet, both install a virtual LAN app - Tailscale, ZeroTier or Radmin VPN - join the same network in it, and join by the address it gives this machine.")
		_status.text = "\n".join(lines)
	elif Net.joined():
		_leave.text = "Leave the game"
		_status.text = "Joined the game at %s. The host's screen decides where everybody is." % Net.host_address
	elif Net.is_joiner():
		_leave.text = "Stop"
		_status.text = "Joining %s..." % Net.host_address
	else:
		_status.text = "Host a game for another player on this network, or join theirs."
	for child in _games.get_children():
		_games.remove_child(child)
		child.queue_free()
	if not idle or not Net.looking():
		return
	if Net.found.is_empty():
		var none := Label.new()
		none.text = "No game heard on this network yet."
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.add_theme_font_size_override("font_size", 13)
		none.add_theme_color_override("font_color", MUTED)
		_games.add_child(none)
		return
	for key in Net.found:
		var game: Dictionary = Net.found[key]
		var button := Button.new()
		button.text = "Join %s  (%s)" % [game.name, game.address]
		button.custom_minimum_size = Vector2(320, 34)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.disabled = game.protocol != Net.PROTOCOL
		if button.disabled:
			button.tooltip_text = "Another version of the game"
		button.pressed.connect(Net.join.bind(game.address, game.port))
		_games.add_child(button)
