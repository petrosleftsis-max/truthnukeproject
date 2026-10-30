extends Node
## Network play (docs/multiplayer_plan.md Step 2; the designer, 2026-10-29): two
## machines on one network, one hosting and the other joining. The host decides
## - it owns Campaign, the scene and the guards - and the joiner sends what its
## player does and shows what it is told. Godot's own high-level multiplayer
## (ENetMultiplayerPeer, @rpc), every call on this node: an autoload's path is
## the one node path the two machines are sure to share.
##
## Hosting and joining: host() / join(address) / leave(); active(), is_host(),
## is_joiner(), joined(). A host says so on the network once a second (BEACON,
## on DISCOVERY_PORT) and look_for_games() hears it; typing an address always
## works too, since a virtual LAN often passes no broadcasts on.
##
## Players: the joiner says hello with its devices, and the host seats a player
## for one of them (Coop.join with the joiner's peer) and sends the whole table -
## Coop.players and Campaign.controllers - to the joiner whenever it changes.
## Picking whom to steer on the joiner is a request to the host (ask_to_steer).
## A machine that drops out takes its player with it, and what they steered goes
## to the other player (Coop.leave) - mid-fight too (the designer, 2026-10-29).
##
## Nothing another machine sends is trusted: every call from the joiner is
## checked for who sent it and what it holds, and objects never travel
## (SceneMultiplayer.allow_object_decoding stays off).

## Hosting, joined, left, or a player in or out.
signal changed
## look_for_games heard a host, or one has gone quiet.
signal games_found
## Something to tell whoever is at this machine: joined, turned away, the host gone.
signal told(text: String)

const PORT := 24700
const DISCOVERY_PORT := 24701
## What a host's beacon begins with.
const BEACON := "MOT-HOST"
## What the two machines say to each other. Bumped whenever that changes; a
## joiner with another is turned away.
const PROTOCOL := 1
## A press from another machine's player arrives on device REMOTE_DEVICE_BASE +
## their number (Coop.player_of_event).
const REMOTE_DEVICE_BASE := 9000
const BEACON_SECONDS := 1.0
## How long a game goes unheard before the Join list forgets it.
const FORGET_SECONDS := 4.0
## How long joining may take before it is given up.
const JOIN_SECONDS := 8.0
## How long a machine that has connected has to say hello.
const HELLO_SECONDS := 6.0

enum Role { NONE, HOST, JOINER }

var role := Role.NONE
## The host's address and port - joining or joined.
var host_address := ""
var host_port := PORT
## Where the beacon is sent: every machine on the network - or, in a test, one.
var beacon_to := "255.255.255.255"
var discovery_port := DISCOVERY_PORT
## The games heard: "address:port" -> {name, address, port, protocol, heard}.
var found := {}
## What this machine calls its game in the other's Join list.
var game_name := ""

var _peer: ENetMultiplayerPeer = null
var _beacon: PacketPeerUDP = null
var _beacon_clock := 0.0
var _listener: PacketPeerUDP = null
## Joining: when it began (msec), to give it up after JOIN_SECONDS; -1 once seated.
var _joining_since := -1
## Joined: whether the host has seated this machine's player yet.
var _seated := false
## Peers connected that have not said hello: peer -> msec.
var _strangers := {}
## Peers whose hello was turned away, cut off once it has gone.
var _turned_away := {}
## The devices this machine's players played with before joining, to sit
## back down with on leaving.
var _own_devices: Array = []
var _table_due := false


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	game_name = _machine_name()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_host_gone)
	Coop.players_changed.connect(_on_players_changed)


func active() -> bool:
	return role != Role.NONE


func is_host() -> bool:
	return role == Role.HOST


func is_joiner() -> bool:
	return role == Role.JOINER


## Joining, and seated at the host's table.
func joined() -> bool:
	return role == Role.JOINER and _seated


## The Players panel's network half (PlayersPanel).
func make_panel() -> Control:
	return NetPanel.new()


## --- Hosting and joining ---


## Opens this machine to another player, on `port` - every network it is on
## with `bind_ip` "*", or only that address (a test: 127.0.0.1).
func host(port: int = PORT, bind_ip: String = "*") -> Error:
	if active():
		return ERR_ALREADY_IN_USE
	var peer := ENetMultiplayerPeer.new()
	peer.set_bind_ip(bind_ip)
	var err := peer.create_server(port, Coop.MAX_PLAYERS - 1)
	if err != OK:
		told.emit("Could not host on port %d: %s." % [port, error_string(err)])
		return err
	_peer = peer
	multiplayer.multiplayer_peer = peer
	role = Role.HOST
	host_address = ""
	host_port = port
	Coop.local_peer = 1
	Coop.networked = true
	if Coop.players.is_empty():
		Coop.join(_device_here())
	for player in Coop.players:
		if player.peer == 0:
			player.peer = 1
	stop_looking()
	_beacon = PacketPeerUDP.new()
	_beacon.set_broadcast_enabled(true)
	_beacon.set_dest_address(beacon_to, discovery_port)
	_beacon_clock = 0.0
	changed.emit()
	Coop.players_changed.emit()
	return OK


## Joins the game hosted at `address` ("192.168.1.20", or with ":port").
func join(address: String, port: int = PORT) -> Error:
	if active():
		return ERR_ALREADY_IN_USE
	address = address.strip_edges()
	if address.count(":") == 1 and address.get_slice(":", 1).is_valid_int():
		port = int(address.get_slice(":", 1))
		address = address.get_slice(":", 0)
	if address == "":
		told.emit("Type the address of the machine hosting the game.")
		return ERR_INVALID_PARAMETER
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		told.emit("Could not join %s: %s." % [address, error_string(err)])
		return err
	_peer = peer
	multiplayer.multiplayer_peer = peer
	role = Role.JOINER
	host_address = address
	host_port = port
	_seated = false
	_joining_since = Time.get_ticks_msec()
	_own_devices = _devices_here()
	stop_looking()
	changed.emit()
	return OK


## Ends hosting, or leaves the game joined - this machine plays on alone.
func leave():
	if not active():
		return
	if is_host():
		for id in range(Coop.players.size() - 1, -1, -1):
			if not Coop.is_local(id):
				Coop.leave(id)
	_close()


## The host sends player `id`'s machine away - Leave on their row.
func send_away(id: int):
	if not is_host() or Coop.is_local(id):
		return
	var peer: int = Coop.player(id).get("peer", 0)
	if peer > 1 and _peer != null:
		_peer.disconnect_peer(peer)


func _close():
	if _beacon != null:
		_beacon.close()
		_beacon = null
	if _peer != null:
		_peer.close()
		_peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	var was_joiner := is_joiner()
	role = Role.NONE
	_seated = false
	_joining_since = -1
	_strangers.clear()
	_turned_away.clear()
	Coop.networked = false
	Coop.local_peer = 0
	if was_joiner:
		# The host's table was the host's: back to this machine's own players,
		# steering everybody.
		Coop.reset()
		Campaign.controllers.clear()
		for device in _own_devices:
			Coop.join(device)
	else:
		for player in Coop.players:
			player.peer = 0
	changed.emit()
	Coop.players_changed.emit()


func _on_peer_connected(peer: int):
	if is_host():
		_strangers[peer] = Time.get_ticks_msec()


func _on_peer_disconnected(peer: int):
	_strangers.erase(peer)
	_turned_away.erase(peer)
	if not is_host():
		return
	var gone := false
	for id in range(Coop.players.size() - 1, -1, -1):
		if Coop.players[id].peer == peer:
			Coop.leave(id)
			gone = true
	if gone:
		told.emit("The other player has left. Their characters are yours.")
		changed.emit()


func _on_connected():
	_hello.rpc_id(1, PROTOCOL, build_key(), _own_devices)


func _on_connection_failed():
	told.emit("Could not reach %s." % host_address)
	_close()


func _on_host_gone():
	told.emit("The host has left the game.")
	_close()


## --- Players ---


## A joiner's first words: what it plays, and with what.
@rpc("any_peer", "reliable")
func _hello(protocol, build, devices):
	if not is_host():
		return
	var peer := multiplayer.get_remote_sender_id()
	if not _strangers.has(peer):
		return
	_strangers.erase(peer)
	var refusal := refusal_for(protocol, build, devices)
	if refusal != "":
		_turned_away[peer] = Time.get_ticks_msec()
		_refused.rpc_id(peer, refusal)
		return
	# One player for each machine, as a rule: the first device it named.
	Coop.join(int(devices[0]), "", peer)
	told.emit("%s has joined over the network." % Coop.name_of(Coop.players.size() - 1))
	changed.emit()


## Why a hello saying `protocol`, `build` and `devices` is turned away, or "".
func refusal_for(protocol, build, devices) -> String:
	if typeof(protocol) != TYPE_INT or protocol != PROTOCOL or typeof(build) != TYPE_STRING or build != build_key():
		return "That game is another version of Messengers of Truth."
	if typeof(devices) != TYPE_ARRAY or devices.is_empty() or typeof(devices[0]) != TYPE_INT \
			or devices[0] < Coop.KEYBOARD or devices[0] > 63:
		return "That game could not tell what you play with."
	if Coop.players.size() >= Coop.MAX_PLAYERS:
		return "That game is full."
	return ""


@rpc("authority", "reliable")
func _refused(why):
	if is_joiner():
		told.emit(str(why))
		_close()


## The whole table - who plays, on which machine, and whom each steers - for
## the joiner. Sent whenever it changes (Coop.players_changed).
func _send_table():
	_table_due = false
	if is_host() and not _seated_peers().is_empty():
		_table.rpc(Coop.players.duplicate(true), Campaign.controllers.duplicate())


@rpc("authority", "reliable")
func _table(players, controllers):
	if not is_joiner() or typeof(players) != TYPE_ARRAY or typeof(controllers) != TYPE_DICTIONARY:
		return
	var seats := []
	for each in players:
		if each is Dictionary and seats.size() < Coop.MAX_PLAYERS:
			seats.append({"id": seats.size(), "device": int(each.get("device", Coop.KEYBOARD)),
				"name": str(each.get("name", "")).left(24), "peer": int(each.get("peer", 0))})
	var steering := {}
	for key in controllers:
		if typeof(key) == TYPE_STRING and typeof(controllers[key]) == TYPE_INT:
			steering[key] = controllers[key]
	var first_time := not _seated
	_seated = true
	_joining_since = -1
	Coop.local_peer = multiplayer.get_unique_id()
	Coop.networked = true
	Coop.players = seats
	Campaign.controllers = steering
	if first_time:
		told.emit("Joined the game at %s." % host_address)
		changed.emit()
	Coop.players_changed.emit()


func _on_players_changed():
	# Once for however many changes come in a frame.
	if is_host() and not _table_due:
		_table_due = true
		_send_table.call_deferred()


## On the joiner: player `id` steers `key` from now on - asked of the host,
## which says so in the next table (PlayersPanel.choose).
func ask_to_steer(key: String, id: int):
	if joined():
		_steer.rpc_id(1, key, id)


@rpc("any_peer", "reliable")
func _steer(key, id):
	if not is_host() or not _seated_peers().has(multiplayer.get_remote_sender_id()):
		return
	if typeof(key) != TYPE_STRING or typeof(id) != TYPE_INT or not CombatantDatabase.combatants.has(key) \
			or id < 0 or id >= Coop.players.size():
		return
	if id == 0:
		Campaign.controllers.erase(key)
	else:
		Campaign.controllers[key] = id
	Coop.players_changed.emit()


## The machines with a player seated at the host's table.
func _seated_peers() -> Array:
	var peers := []
	for player in Coop.players:
		if player.peer > 1 and not peers.has(player.peer):
			peers.append(player.peer)
	return peers


## --- Finding games ---


## Listens for hosts on this network, for the Join list (found, games_found) -
## on every network with `bind_ip` "*", or only that address.
func look_for_games(bind_ip: String = "*") -> Error:
	if _listener != null:
		return OK
	var udp := PacketPeerUDP.new()
	var err := udp.bind(discovery_port, bind_ip)
	if err != OK:
		return err
	_listener = udp
	return OK


func stop_looking():
	if _listener != null:
		_listener.close()
		_listener = null
	if not found.is_empty():
		found.clear()
		games_found.emit()


func looking() -> bool:
	return _listener != null


func _listen():
	var now := Time.get_ticks_msec()
	var heard_new := false
	while _listener.get_available_packet_count() > 0:
		var text := _listener.get_packet().get_string_from_utf8()
		var address := _listener.get_packet_ip()
		var parts := text.split("|", true, 3)
		if parts.size() < 4 or parts[0] != BEACON or not parts[1].is_valid_int() or not parts[2].is_valid_int():
			continue
		var key := "%s:%s" % [address, parts[2]]
		if not found.has(key):
			heard_new = true
		found[key] = {"address": address, "port": int(parts[2]), "protocol": int(parts[1]),
			"name": parts[3].left(40), "heard": now}
	for key in found.keys():
		if now - found[key].heard > FORGET_SECONDS * 1000.0:
			found.erase(key)
			heard_new = true
	if heard_new:
		games_found.emit()


func _process(delta: float):
	if _beacon != null:
		_beacon_clock -= delta
		if _beacon_clock <= 0.0:
			_beacon_clock = BEACON_SECONDS
			_beacon.put_packet(("%s|%d|%d|%s" % [BEACON, PROTOCOL, host_port, game_name.replace("|", " ")]).to_utf8_buffer())
	if _listener != null:
		_listen()
	var now := Time.get_ticks_msec()
	if is_joiner() and _joining_since >= 0 and now - _joining_since > JOIN_SECONDS * 1000.0:
		told.emit("No answer from %s." % host_address)
		_close()
	if is_host():
		for peer in _strangers.keys():
			if now - _strangers[peer] > HELLO_SECONDS * 1000.0:
				_strangers.erase(peer)
				_peer.disconnect_peer(peer)
		for peer in _turned_away.keys():
			# Long enough for the refusal to arrive before the line goes.
			if now - _turned_away[peer] > 500:
				_turned_away.erase(peer)
				_peer.disconnect_peer(peer)


## --- What a machine is ---


## What two machines have to share to play one game: this protocol, this Godot,
## and the same moves, characters and things, by name.
static func build_key() -> String:
	var names: Array = SkillDatabase.skills.keys() + CombatantDatabase.combatants.keys() + ItemDatabase.items.keys()
	names.sort()
	return "%d/%s/%x" % [PROTOCOL, Engine.get_version_info().string, hash(",".join(names))]


## This machine's addresses on its networks, to tell a friend.
static func own_addresses() -> Array:
	var addresses := []
	for address in IP.get_local_addresses():
		if address.count(".") == 3 and not address.begins_with("127.") and not address.begins_with("169.254."):
			addresses.append(address)
	addresses.sort()
	return addresses


static func _machine_name() -> String:
	for variable in ["COMPUTERNAME", "HOSTNAME"]:
		var value := OS.get_environment(variable)
		if value != "":
			return value.left(30)
	return "A game"


## What this machine's first player plays with - or whatever was used last.
func _device_here() -> int:
	return Pad.pointer_pad if Pad.using_pad else Coop.KEYBOARD


func _devices_here() -> Array:
	var devices := []
	for id in Coop.local_players():
		devices.append(Coop.device_of_player(id))
	if devices.is_empty():
		devices.append(_device_here())
	return devices
