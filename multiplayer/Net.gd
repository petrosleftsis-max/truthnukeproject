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
## works too, since a virtual LAN often passes no broadcasts on. Hosting also
## asks the router to open the game to the internet (UPnP; "Over the internet").
##
## Players: the joiner says hello with its devices, and the host seats a player
## for one of them (Coop.join with the joiner's peer) and sends the whole table -
## Coop.players and Campaign.controllers - to the joiner whenever it changes.
## Picking whom to steer on the joiner is a request to the host (ask_to_steer).
## A machine that drops out takes its player with it, and what they steered goes
## to the other player (Coop.leave) - mid-fight too (the designer, 2026-10-29).
##
## Following the host: the joiner never changes scene by itself
## (may_change_scene). Every change on the host is sent with Campaign as it
## stands then (scene_changing -> _follow), and the joiner puts that state on
## and changes too - so the map arriving does to the state what the host's
## arriving did. After that Campaign is kept the host's (_send_state): sent
## whenever it has changed and every few seconds anyway, and held back while
## the joiner is still changing scene. A joiner seated while the host is on a
## map comes straight there (_welcome); one seated mid-fight comes in once the
## fight is over. The host leaving sends the joiner back to the title screen.
##
## Guards: on a watched map only the host's watch decides anything; the
## joiner's is a puppet (StealthWatch.puppet, Guard.puppet) given how things
## stand there WATCHES_A_SECOND times a second (_watched): each guard's place,
## facing, mood and suspicion, the alert, the doors, the lamps and what is
## still lying about. Caught, the host builds the fight and changes scene, and
## the encounter goes with Campaign to the joiner like any other.
##
## Fights, replayed (docs/multiplayer_plan.md Step 2, 8): a fight is played on
## both machines from one seed and the same moves. The host gives the encounter
## its seed as it goes into the fight (scene_changing). Whoever's character it
## is moves on their own machine as anybody would, and each move - a walk, a
## skill, the end of the turn, a step back, a move readied, the party placed -
## is sent (fight_move) and done on the other machine too, once its fight has
## come to the same turn and stands waiting (_play_moves). The AI needs nothing
## sent: the seed makes its turns the same. A question in the middle of
## something (ReactionPrompt), a quick time or a hack is the decider's, on their
## machine, and what they decide is sent (decided). After every turn the
## joiner's fight_state is checked against the host's (_fight_check); told
## apart - something rolled outside Combat.rng - the host's numbers are put on
## the joiner's fight and the turn is written down (parted).
##
## Walking, presses and pings: on a map each machine walks its own players'
## groups and says where their leaders are WALKS_A_SECOND times a second
## (_walked, unreliable but in order); the other machine's copy of a group is a
## puppet (ExplorationParty.puppet) and walk_to's it there - on the host only
## once it has checked the group could stand there. A press on the joiner that
## does something to the world (HOSTS_PRESSES, and the number keys on a watched
## map) is not acted on there: it goes to the host (forwards), which hands it to
## the map as a press from that player's device - Coop.REMOTE_DEVICE_BASE plus
## their number - so it is done as them (Coop.acting). Stay Here is done on
## both, since who stays is the joiner's own line. A move used from the joiner's
## moves panel goes the same way (use_move). Pings go both ways.
##
## Nothing another machine sends is trusted: every call from the joiner is
## checked for who sent it and what it holds, and objects never travel
## (SceneMultiplayer.allow_object_decoding stays off) - a resource goes as its
## file, or as its script and stored properties (resource_to_data), and only
## the game's own data scripts are made from them (data_to_resource).

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
const BEACON_SECONDS := 1.0
## How long a game goes unheard before the Join list forgets it.
const FORGET_SECONDS := 4.0
## How long joining may take before it is given up.
const JOIN_SECONDS := 8.0
## How long a machine that has connected has to say hello.
const HELLO_SECONDS := 6.0
## How often the host looks whether Campaign has changed, and how long it goes
## at most without sending it anyway.
const STATE_SECONDS := 0.25
const STATE_ANYWAY_SECONDS := 3.0
## Where a resource sent as data may take its script from - the game's own
## data, never anything else.
const DATA_SCRIPTS := ["res://combat/resources/", "res://campaign/", "res://data/"]
## How often a machine says where its groups' leaders are, walking - and,
## standing still, how long it goes without saying anyway.
const WALKS_A_SECOND := 20.0
const WALK_ANYWAY_SECONDS := 0.5
## How often the host says how its watch stands, on a watched map.
const WATCHES_A_SECOND := 10.0
## The one scene every fight is played in.
const FIGHT_SCENE := "res://scenes/game.tscn"
## The moves a fight sends.
const FIGHT_MOVES := ["walk", "skill", "end_turn", "undo", "ready", "deployed"]
## The presses on a map that do something to the world, which on a joiner are
## the host's to act on.
const HOSTS_PRESSES: Array[StringName] = [&"interact", &"swap_leader", &"dash", &"listen", &"throw", &"vault",
	&"outside_spell", &"ambush", &"take_off_disguise", &"next_disguise", &"take_down", &"pick_pocket"]
## Presses acted on by both: what they change is the joiner's own line.
const BOTH_PRESSES: Array[StringName] = [&"stay_here"]

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
var _state_clock := 0.0
var _state_anyway := 0.0
var _state_digest := 0
## Joiner: a change of scene the host has asked for, waiting until a change
## already under way is over - {path, state}.
var _follow_due := {}
## Joiner: Campaign from the host, kept while a change of scene is under way.
var _state_held = null
var _following := false
var _arriving_as_it_stands := false
var _walk_clock := 0.0
## Player id -> [where, facing left, walking, msec] as last said.
var _walk_said := {}
var _watch_clock := 0.0
## The fight being played here, and how many turns of it have begun.
var _fight: Combat = null
var fight_turn := 0
## Moves from the other machine still to be done here: [turn, combatant id, kind, args].
var _moves: Array = []
var _playing_move := false
var _replaying := false
## Questions asked in this fight here, and the other machine's answers by number.
var _questions := 0
var _answers := {}
## The host: each side's fight_state hash by turn, until both are in.
var _checks_here := {}
var _checks_there := {}
## The turns the two fights were told apart and the joiner's put right, and how
## many turns have been checked and found the same.
var parted: Array = []
var checked_turns := 0
## The host: the balloon showing a conversation now. The joiner: its copy.
var _balloon: Node = null
var _mirror: ConversationMirror = null


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	game_name = _machine_name()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_host_gone)
	Coop.players_changed.connect(_on_players_changed)
	Pings.pinged.connect(_on_pinged)


func active() -> bool:
	return role != Role.NONE


func is_host() -> bool:
	return role == Role.HOST


func is_joiner() -> bool:
	return role == Role.JOINER


## Joining, and seated at the host's table.
func joined() -> bool:
	return role == Role.JOINER and _seated


## Playing with another machine right now: hosting with a joiner seated, or
## seated at a host's table.
func with_another() -> bool:
	return (is_host() and not _seated_peers().is_empty()) or joined()


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
	# Open on every network: the router is asked to let the internet in too.
	if bind_ip == "*":
		_open_router(port)
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


## Ends hosting, or leaves the game joined - this machine plays on alone. A
## joiner was in the host's story, so it goes back to the title screen.
func leave():
	if not active():
		return
	var was_following := follows()
	if is_host():
		for id in range(Coop.players.size() - 1, -1, -1):
			if not Coop.is_local(id):
				Coop.leave(id)
	_close()
	if was_following:
		_back_to_the_title("You have left the game.")


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
	if is_host():
		_close_router()
	role = Role.NONE
	_seated = false
	_joining_since = -1
	_strangers.clear()
	_turned_away.clear()
	_follow_due = {}
	_state_held = null
	_state_digest = 0
	_moves.clear()
	_balloon = null
	_close_mirror()
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
		# Mid-fight too (the designer, 2026-10-29): the turn under way, if it
		# was theirs, is this machine's player's now, and nothing more of theirs
		# is coming.
		_moves.clear()
		if _fight != null and is_instance_valid(_fight) and not _fight.combat_over and not _fight.combatants.is_empty():
			Coop.fight_turn(_fight.player_of(_fight.get_current_combatant()))
		changed.emit()


func _on_connected():
	_hello.rpc_id(1, PROTOCOL, build_key(), _own_devices)


func _on_connection_failed():
	told.emit("Could not reach %s." % host_address)
	_close()


func _on_host_gone():
	var was_following := follows()
	told.emit("The host has left the game.")
	_close()
	if was_following:
		_back_to_the_title("The host has left the game.")


## To the title screen's Players, saying `why` - unless already there.
func _back_to_the_title(why: String):
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path == Campaign.MAIN_MENU:
		return
	Campaign.to_main_menu("players", why)


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
	# The table first - the joiner follows only once seated - then where the
	# game is.
	_send_table()
	_welcome(peer)


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
	# Another machine come or gone: a menu open holds the game, or no longer.
	MenuPause.reapply(get_tree())
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


## --- Following the host ---


## This machine plays another's game - a seated joiner - and goes where it says.
func follows() -> bool:
	return joined()


## Whether SceneTransition may change scene to `path` - never on a joiner, but
## where the host has said.
func may_change_scene(_path: String) -> bool:
	if not follows() or _following:
		return true
	told.emit("The host decides where everybody goes.")
	return false


## The host is changing scene to `path` (SceneTransition, ExplorationScene.
## reload_map): the joiner comes too, with Campaign as it stands now. Into a
## fight, the encounter gets its seed first - a copy of it, so the file's own
## encounter never carries one into a fight played alone.
func scene_changing(path: String):
	if not is_host() or _seated_peers().is_empty():
		return
	if path == FIGHT_SCENE and Campaign.current_encounter != null:
		var fight: EncounterDefinition = Campaign.current_encounter.duplicate()
		for meta in Campaign.current_encounter.get_meta_list():
			fight.set_meta(meta, Campaign.current_encounter.get_meta(meta))
		fight.set_meta("seed", randi())
		Campaign.current_encounter = fight
	_follow.rpc(path, Campaign.net_state(), false)


## On a joiner, whether the map coming up is one the host is already on, so its
## party and bags are the host's as they stand - not set up again as arriving
## sets them (ExplorationScene._ready). Asked once, as the map comes up.
func arrives_as_it_stands() -> bool:
	var was := _arriving_as_it_stands
	_arriving_as_it_stands = false
	return was


## Where a joiner just seated should be: on the host's map, or wherever else it
## is but the title screen. Not into a fight under way - it comes in after it.
func _welcome(peer: int):
	var scene := get_tree().current_scene
	var path := scene.scene_file_path if scene != null else ""
	if path == "" or path == Campaign.MAIN_MENU:
		return
	if scene is GameScene and scene.combat != null and not scene.combat.combat_over:
		_waiting.rpc_id(peer, "The host is in a fight. You come in once it is over.")
		return
	var state := Campaign.net_state()
	if scene is ExplorationScene:
		# Where the host's party stands now, not where it came in.
		state.return_position = scene.party_position()
		state.return_to_position = true
	_follow.rpc_id(peer, path, state, true)


@rpc("authority", "reliable")
func _waiting(why):
	if follows():
		told.emit(str(why))


## Go to `path` with `state` on - `as_it_stands` when the host is already
## there (arrives_as_it_stands).
@rpc("authority", "reliable")
func _follow(path, state, as_it_stands):
	if not follows() or typeof(path) != TYPE_STRING or typeof(state) != TYPE_DICTIONARY:
		return
	if not path.begins_with("res://") or not path.ends_with(".tscn") or not ResourceLoader.exists(path):
		return
	_follow_due = {"path": path, "state": state, "as_it_stands": as_it_stands == true}
	_state_held = null
	_follow_now()


func _follow_now():
	if _follow_due.is_empty() or SceneTransition.is_changing():
		return
	var due := _follow_due
	_follow_due = {}
	_close_mirror()
	Campaign.apply(due.state)
	_arriving_as_it_stands = due.as_it_stands
	_following = true
	SceneTransition.change_scene(due.path)
	_following = false


@rpc("authority", "reliable")
func _state(state):
	if not follows() or typeof(state) != TYPE_DICTIONARY:
		return
	if SceneTransition.is_changing() or not _follow_due.is_empty():
		_state_held = state
		return
	# While a menu here is open, what it may change stays as it has it.
	Campaign.apply(state, MENU_KEYS if _menu_open else [])


## Campaign to the joiner, when it has changed since last sent - or anyway,
## once in a while.
func _send_state():
	var state := Campaign.net_state()
	var digest := hash(var_to_str(state))
	if digest == _state_digest and _state_anyway > 0.0:
		return
	_state_digest = digest
	_state_anyway = STATE_ANYWAY_SECONDS
	_state.rpc(state)


## --- Fights, replayed ---


## A fight has come up here (Combat._ready).
func fight_begins(combat: Combat):
	_fight = combat
	fight_turn = 0
	_moves.clear()
	_playing_move = false
	_replaying = false
	_questions = 0
	_answers.clear()
	_checks_here.clear()
	_checks_there.clear()
	parted.clear()
	checked_turns = 0
	combat.turn_advanced.connect(_on_turn_advanced)


## Whether a fight here is being played on the other machine too.
func in_a_shared_fight() -> bool:
	return with_another() and _fight != null and is_instance_valid(_fight) and _fight.is_inside_tree() and not _fight.combat_over


## Whether this machine places the party before a fight - the host does; on the
## joiner only the host's placing, played here, does (Combat.finish_deployment).
func may_deploy() -> bool:
	return not in_a_shared_fight() or not follows() or _replaying


## A move made here in `combat`, for the other machine to make too: `kind` (one
## of FIGHT_MOVES) with `args` - plain data. Nothing while playing the other's.
func fight_move(combat: Combat, kind: String, args: Array):
	if _replaying or combat != _fight or not in_a_shared_fight():
		return
	if kind == "deployed":
		var places := {}
		for comb in combat.combatants:
			if comb.get("side", 1) == 0 and not comb.has("object"):
				places[comb.get("id", -1)] = comb.position
		args = [places]
	_fight_move.rpc(fight_turn, combat.get_current_combatant().get("id", -1), kind, args)


@rpc("any_peer", "reliable")
func _fight_move(turn, comb_id, kind, args):
	if typeof(turn) != TYPE_INT or typeof(comb_id) != TYPE_INT or typeof(kind) != TYPE_STRING or typeof(args) != TYPE_ARRAY:
		return
	if not FIGHT_MOVES.has(kind) or not in_a_shared_fight():
		return
	# Only from the machine of whoever steers the one moving - the party's
	# placing, from the host.
	var sender := multiplayer.get_remote_sender_id()
	if kind == "deployed":
		if sender != 1:
			return
	else:
		var comb: Dictionary = _fight._combatant_by_id(comb_id)
		var id := _fight.player_of(comb) if not comb.is_empty() else -1
		if id < 0 or id >= Coop.players.size() or Coop.players[id].peer != sender:
			return
	_moves.append([turn, comb_id, kind, args])


## The other machine's moves, each once this fight has come to its turn and
## stands waiting for the one moving.
func _play_moves():
	if _playing_move or _moves.is_empty() or not in_a_shared_fight():
		return
	var move: Array = _moves[0]
	var combat := _fight
	if move[2] == "deployed":
		if not combat.deployment_active:
			return
	else:
		if move[0] != fight_turn or combat.deployment_active:
			return
		var comb: Dictionary = combat.get_current_combatant()
		if comb.get("id", -1) != move[1] or not combat.controller.player_turn \
				or not combat.controller.is_idle() or combat.controller.action_locked:
			return
	_moves.pop_front()
	_playing_move = true
	_replaying = true
	await _make(combat, move[2], move[3])
	_replaying = false
	_playing_move = false


func _make(combat: Combat, kind: String, args: Array):
	var controller := combat.controller
	var comb: Dictionary = combat.get_current_combatant()
	match kind:
		"walk":
			if args.size() == 1 and args[0] is Array:
				controller.walk_along(args[0])
		"skill":
			if args.size() == 5 and typeof(args[0]) == TYPE_STRING and SkillDatabase.skills.has(args[0]) \
					and typeof(args[1]) == TYPE_VECTOR2I and typeof(args[2]) == TYPE_BOOL \
					and typeof(args[3]) == TYPE_VECTOR2I and typeof(args[4]) == TYPE_INT:
				combat.aim_choice = args[4]
				await combat.use_skill(args[0], comb, args[1], true, args[2], args[3])
		"end_turn":
			await combat.advance_turn()
		"undo":
			controller.undo_move()
		"ready":
			if args.size() == 6 and typeof(args[0]) == TYPE_INT and typeof(args[1]) == TYPE_STRING \
					and typeof(args[2]) == TYPE_INT and typeof(args[3]) == TYPE_VECTOR2I and typeof(args[4]) == TYPE_INT \
					and typeof(args[5]) == TYPE_INT:
				combat.ready_action(combat._combatant_by_id(args[0]), args[1], args[2], args[3], args[4],
					combat._combatant_by_id(args[5]))
		"deployed":
			if args.size() == 1 and args[0] is Dictionary:
				for comb_id in args[0]:
					var placed: Dictionary = combat._combatant_by_id(int(comb_id))
					if not placed.is_empty() and placed.get("side", 1) == 0 and typeof(args[0][comb_id]) == TYPE_VECTOR2I:
						controller._set_deployed_position(placed, args[0][comb_id])
				controller.update_points_weight()
				combat.finish_deployment()


## What `who` decides - `deciding` called on their machine (a question put
## up, a quick time played, a hack) and its answer sent, so that on the other
## machine the same call waits for that answer instead. Outside a fight played
## on both machines, simply `deciding` called.
func decided(who: int, deciding: Callable):
	if not in_a_shared_fight():
		return await deciding.call()
	_questions += 1
	var asked := _questions
	if who < 0 or who >= Coop.players.size():
		who = 0
	if Coop.is_local(who):
		var answer = await deciding.call()
		_answer.rpc(asked, answer)
		return answer
	while not _answers.has(asked):
		if not in_a_shared_fight():
			return await deciding.call()
		await get_tree().process_frame
	var given = _answers[asked]
	_answers.erase(asked)
	return given


@rpc("any_peer", "reliable")
func _answer(asked, answer):
	if typeof(asked) == TYPE_INT and in_a_shared_fight() and is_plain(answer):
		_answers[asked] = answer


func _on_turn_advanced(_comb: Dictionary):
	fight_turn += 1
	if not in_a_shared_fight():
		return
	var digest := hash(_fight.fight_state())
	if is_host():
		_checks_here[fight_turn] = digest
		_check(fight_turn)
	else:
		_fight_check.rpc_id(1, fight_turn, digest)


@rpc("any_peer", "reliable")
func _fight_check(turn, digest):
	if is_host() and typeof(turn) == TYPE_INT and typeof(digest) == TYPE_INT and _seated_peers().has(multiplayer.get_remote_sender_id()):
		_checks_there[turn] = digest
		_check(turn)


## The host: the two fights as each was when `turn` began. Told apart, the
## joiner's is put right from this one, and it is written down.
func _check(turn: int):
	if not _checks_here.has(turn) or not _checks_there.has(turn):
		return
	var same: bool = _checks_here[turn] == _checks_there[turn]
	_checks_here.erase(turn)
	_checks_there.erase(turn)
	if same:
		checked_turns += 1
		return
	parted.append(turn)
	push_warning("Net: the two fights told apart at turn %d - something rolled outside Combat.rng. The joiner's is put right from the host's." % turn)
	var numbers := {}
	for comb in _fight.combatants:
		numbers[comb.get("id", -1)] = [comb.get("hp", 0), comb.get("position", Vector2i.ZERO), comb.get("alive", false)]
	_put_right.rpc(turn, numbers)


@rpc("authority", "reliable")
func _put_right(turn, numbers):
	if not follows() or not in_a_shared_fight() or typeof(numbers) != TYPE_DICTIONARY:
		return
	push_warning("Net: this fight parted from the host's at turn %d; put right from it." % turn)
	for comb_id in numbers:
		var comb: Dictionary = _fight._combatant_by_id(int(comb_id))
		var said = numbers[comb_id]
		if comb.is_empty() or not said is Array or said.size() < 3 or typeof(said[1]) != TYPE_VECTOR2I:
			continue
		comb.hp = int(said[0])
		comb.alive = bool(said[2])
		if comb.position != said[1]:
			var was: Vector2i = comb.position
			comb.position = said[1]
			var sprite = comb.get("sprite")
			if sprite != null and is_instance_valid(sprite):
				sprite.position = _fight.controller.tile_map.map_to_local(said[1])
			_fight.controller.reposition_combatant(was, said[1])
	_fight.update_combatants.emit(_fight.combatants)


## --- Conversations ---
##
## The host runs every conversation. Each line its balloon shows
## (DialogueBalloon.apply_dialogue_line -> conversation_line) goes to the joiner
## and is shown there in a copy (ConversationMirror), the joiner's own party held
## meanwhile. Whoever has the focus - who started it - goes on and chooses: on
## the joiner that is sent back (answer_line) and done on the host's balloon. The
## conversation's end closes the copy.


func conversation_line(balloon: Node):
	if not is_host() or _seated_peers().is_empty():
		return
	_balloon = balloon
	var line = balloon.dialogue_line
	var answers := []
	for response in line.responses:
		answers.append([str(response.text), bool(response.is_allowed)])
	_line.rpc(str(line.character), str(line.text), answers, Coop.focus)


func conversation_over(balloon: Node):
	if balloon == _balloon:
		_balloon = null
	if is_host() and not _seated_peers().is_empty():
		_line_over.rpc()


@rpc("authority", "reliable")
func _line(character, text, answers, decider):
	if not follows() or typeof(character) != TYPE_STRING or typeof(text) != TYPE_STRING \
			or typeof(answers) != TYPE_ARRAY or typeof(decider) != TYPE_INT:
		return
	var shown := []
	for answer in answers:
		if answer is Array and answer.size() == 2 and typeof(answer[0]) == TYPE_STRING:
			shown.append([answer[0], bool(answer[1])])
	if _mirror == null or not is_instance_valid(_mirror):
		_mirror = ConversationMirror.new()
		get_tree().root.add_child(_mirror)
	_mirror.show_line(character, text, shown, Coop.is_local(decider))
	_hold_for_conversation(true)


@rpc("authority", "reliable")
func _line_over():
	_close_mirror()


func _close_mirror():
	if _mirror != null and is_instance_valid(_mirror):
		_mirror.queue_free()
	_mirror = null
	_hold_for_conversation(false)


## A conversation on the host holds the joiner's own party too.
func _hold_for_conversation(held: bool):
	var scene := _map()
	if scene == null:
		return
	for group in scene.all_groups():
		if is_instance_valid(group) and not group.puppet:
			group.frozen = held


## On the joiner, whose conversation it is: pressed on (`choice` -1), or chose
## the `choice`th answer (ConversationMirror).
func answer_line(choice: int):
	if follows():
		_converse.rpc_id(1, choice)


@rpc("any_peer", "reliable")
func _converse(choice):
	if not is_host() or typeof(choice) != TYPE_INT or _balloon == null or not is_instance_valid(_balloon):
		return
	# Only the machine of whoever has the conversation.
	var sender := multiplayer.get_remote_sender_id()
	if Coop.focus < 0 or Coop.focus >= Coop.players.size() or Coop.players[Coop.focus].peer != sender:
		return
	if choice < 0:
		_balloon.advance_from_afar()
	else:
		_balloon.respond_from_afar(choice)


## --- Menus ---
##
## Over a network an open menu does not stop the world (the designer,
## 2026-10-29): MenuPause pauses nothing and Coop gives no menu the focus. Only
## this machine's own groups stand where they are while a menu is open here.
##
## What a menu on the joiner changes - the bags, the gear, gold, spells
## learned, paths chosen (MENU_KEYS) - is the joiner's own doing: while one is
## open the host's Campaign goes on arriving but for those, which stay as the
## joiner has them; once it closes, those of them it changed are sent to the
## host (_menu_changes), which takes them and sends Campaign back to both. A
## menu that changes none of them (the Players panel, the journal) sends
## nothing. The host trusts the joiner with that much.

const MENU_KEYS := ["inventories", "containers", "stacks", "equipped", "gear", "gold", "learned_spells",
	"subclasses", "path_change_open"]

var _menu_open := false
## The joiner: MENU_KEYS as they stood when a menu opened.
var _before_the_menu := {}


func _stand_for_menus():
	var held := MenuPause.is_held()
	if follows() and held != _menu_open:
		if held:
			_before_the_menu = _menu_part()
		else:
			_send_what_the_menu_changed()
	_menu_open = held
	var scene := _map()
	if scene == null:
		return
	for id in Coop.local_players():
		var group = scene.groups.get(id)
		if group != null and is_instance_valid(group):
			group.in_a_menu = held


func _menu_part() -> Dictionary:
	var part := {}
	for key in MENU_KEYS:
		var value = Campaign.get(key)
		part[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	return part


func _send_what_the_menu_changed():
	var now := _menu_part()
	var changed_keys := {}
	for key in MENU_KEYS:
		if var_to_str(now[key]) != var_to_str(_before_the_menu.get(key)):
			changed_keys[key] = now[key]
	_before_the_menu = {}
	if not changed_keys.is_empty() and is_plain(changed_keys):
		_menu_changes.rpc_id(1, changed_keys)


@rpc("any_peer", "reliable")
func _menu_changes(changes):
	if not is_host() or typeof(changes) != TYPE_DICTIONARY or not _seated_peers().has(multiplayer.get_remote_sender_id()):
		return
	for key in changes:
		if not MENU_KEYS.has(key):
			continue
		var value = changes[key]
		# Only what is already of that kind: a bag for a bag, a number for gold.
		if typeof(value) != typeof(Campaign.get(key)):
			continue
		Campaign.set(key, value.duplicate(true) if value is Dictionary or value is Array else value)


## --- Guards ---


## How the host's watch stands, to the joiner.
func _say_how_it_stands(delta: float):
	_watch_clock -= delta
	if _watch_clock > 0.0:
		return
	_watch_clock = 1.0 / WATCHES_A_SECOND
	var scene := _map()
	if scene != null and scene.stealth != null and not scene.stealth.puppet:
		_watched.rpc(scene.stealth.net_state())


@rpc("authority", "unreliable_ordered")
func _watched(state):
	if not follows() or typeof(state) != TYPE_DICTIONARY:
		return
	var scene := _map()
	if scene != null and scene.stealth != null and scene.stealth.puppet and not SceneTransition.is_changing():
		scene.stealth.apply_net_state(state)


## --- Walking, presses and pings ---


## The map being walked, or null.
func _map() -> ExplorationScene:
	var scene := get_tree().current_scene
	return scene if scene is ExplorationScene and scene.is_inside_tree() else null


## Where this machine's players' groups are, to the other machine: walking,
## WALKS_A_SECOND times a second; standing, every WALK_ANYWAY_SECONDS.
func _say_where(delta: float):
	_walk_clock -= delta
	if _walk_clock > 0.0:
		return
	_walk_clock = 1.0 / WALKS_A_SECOND
	var scene := _map()
	if scene == null:
		return
	var now := Time.get_ticks_msec()
	for id in Coop.local_players():
		var group = scene.groups.get(id, scene._main_party if scene.groups.is_empty() else null)
		if group == null or not is_instance_valid(group) or group.puppet or group.leader == null:
			continue
		var said: Array = [group.position_of_leader(), group.facing_left(), group._walking]
		var last: Array = _walk_said.get(id, [])
		if not last.is_empty() and last.slice(0, 3) == said and now - last[3] < WALK_ANYWAY_SECONDS * 1000.0:
			continue
		_walk_said[id] = said + [now]
		_walked.rpc(id, said[0], said[1], said[2])


@rpc("any_peer", "unreliable_ordered")
func _walked(id, at, facing_left, walking):
	if typeof(id) != TYPE_INT or typeof(at) != TYPE_VECTOR2 or typeof(facing_left) != TYPE_BOOL or typeof(walking) != TYPE_BOOL:
		return
	if not _sent_by_whoever_plays(id):
		return
	var scene := _map()
	if scene == null or not scene.groups.has(id):
		return
	var group: ExplorationParty = scene.groups[id]
	if not is_instance_valid(group) or not group.puppet:
		return
	# The host has the last word on where anybody can stand.
	if is_host() and not scene.is_walkable(at):
		return
	group.walk_to(at, facing_left, walking)


## Whether the call being handled came from the machine player `id` plays on:
## on the host, theirs; on the joiner, the host, for one of the host's players.
func _sent_by_whoever_plays(id: int) -> bool:
	if id < 0 or id >= Coop.players.size() or Coop.is_local(id):
		return false
	var sender := multiplayer.get_remote_sender_id()
	if is_host():
		return Coop.players[id].peer == sender
	return follows() and sender == 1


## On a joiner: whether `event` is a press that does something to the world,
## sent to the host to be done there as its player instead of here (the gate,
## Coop._Gate). Stay Here is sent and done here too.
func forwards(event: InputEvent) -> bool:
	if not follows() or not event.is_pressed() or event.is_echo() or event.device >= Coop.REMOTE_DEVICE_BASE:
		return false
	var scene := _map()
	# A menu or a conversation open here has its own keys.
	if scene == null or scene.is_holding():
		return false
	var player := Coop.player_of_event(event)
	if player == Coop.ANYONE or not Coop.is_local(player):
		return false
	if event is InputEventJoypadMotion:
		# A trigger: what it presses, by name (Pad.went_down knows a trigger held).
		var pressed := false
		for action in HOSTS_PRESSES:
			if Pad.went_down(event, action):
				_press.rpc_id(1, player, {"kind": "action", "action": String(action)})
				pressed = true
		return pressed
	var data := _press_data(event)
	if data.is_empty():
		return false
	for action in BOTH_PRESSES:
		if event.is_action_pressed(action):
			_press.rpc_id(1, player, data)
			return false
	var the_hosts := HOSTS_PRESSES.any(func(action): return event.is_action_pressed(action))
	# The number keys put a disguise on, on a watched map.
	if event is InputEventKey and event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_9 and scene.stealth != null:
		the_hosts = true
	if not the_hosts:
		return false
	_press.rpc_id(1, player, data)
	return true


static func _press_data(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		return {"kind": "key", "keycode": event.keycode, "physical": event.physical_keycode}
	if event is InputEventJoypadButton:
		return {"kind": "button", "button": event.button_index}
	return {}


## A press made on the joiner, by player `id`, done here as theirs.
@rpc("any_peer", "reliable")
func _press(id, data):
	if not is_host() or typeof(id) != TYPE_INT or typeof(data) != TYPE_DICTIONARY or not _sent_by_whoever_plays(id):
		return
	var event: InputEvent = null
	match data.get("kind"):
		"key":
			if typeof(data.get("keycode")) != TYPE_INT or typeof(data.get("physical")) != TYPE_INT:
				return
			var key := InputEventKey.new()
			key.keycode = data.keycode
			key.physical_keycode = data.physical
			event = key
		"button":
			if typeof(data.get("button")) != TYPE_INT:
				return
			var button := InputEventJoypadButton.new()
			button.button_index = data.button
			event = button
		"action":
			var named := StringName(str(data.get("action")))
			if not HOSTS_PRESSES.has(named) and not BOTH_PRESSES.has(named):
				return
			var action := InputEventAction.new()
			action.action = StringName(str(data.action))
			event = action
	if event == null:
		return
	event.pressed = true
	event.device = Coop.REMOTE_DEVICE_BASE + id
	# Into the scene as any press is, through the gate - never into Input,
	# which would think this machine's own keys were down.
	get_viewport().push_input(event)


## On a joiner: `action`, done here by player `id` some other way than a press
## (a button on the moves panel), done on the host too.
func pressed_here(action: StringName, id: int):
	if follows() and Coop.is_local(id):
		_press.rpc_id(1, id, {"kind": "action", "action": String(action)})


## On a joiner: player `key`'s `move` from the moves panel, used on the host
## (OutsideMovesPanel).
func use_move(key: String, move: String):
	if follows():
		_use_move.rpc_id(1, key, move)


@rpc("any_peer", "reliable")
func _use_move(key, move):
	if not is_host() or typeof(key) != TYPE_STRING or typeof(move) != TYPE_STRING:
		return
	var id := Coop.controller_of(key)
	var scene := _map()
	if scene == null or not _sent_by_whoever_plays(id):
		return
	var before := Coop.acting
	Coop.acting = id
	OutsideMoves.use(scene, key, move)
	Coop.acting = before


func _on_pinged(player: int, at: Vector2, label: String):
	if active() and Coop.is_local(player):
		_ping.rpc(player, at, label)


@rpc("any_peer", "reliable")
func _ping(player, at, label):
	if typeof(player) != TYPE_INT or typeof(at) != TYPE_VECTOR2 or typeof(label) != TYPE_STRING:
		return
	if _sent_by_whoever_plays(player):
		Pings.show_ping(player, at, label.left(60))


## --- Resources as data ---


## `resource` as plain data for the other machine: its file, when it has one of
## its own, or else its script and stored properties - never the object.
static func resource_to_data(resource: Resource):
	if resource == null:
		return null
	var data := {"meta": {}}
	for meta in resource.get_meta_list():
		data.meta[meta] = value_to_data(resource.get_meta(meta))
	if resource.resource_path.begins_with("res://") and not resource.resource_path.contains("::"):
		data["path"] = resource.resource_path
		return data
	var script: Script = resource.get_script()
	data["script"] = script.resource_path if script != null else ""
	data["props"] = {}
	for property in resource.get_property_list():
		if property.usage & PROPERTY_USAGE_STORAGE and property.name not in ["script", "resource_local_to_scene", "resource_name", "resource_path"]:
			data.props[property.name] = value_to_data(resource.get(property.name))
	return data


static func value_to_data(value):
	if value is Resource:
		return {"__resource": resource_to_data(value)}
	if value is Object:
		return null
	if value is Array:
		var items := []
		for each in value:
			items.append(value_to_data(each))
		return items
	if value is Dictionary:
		var copy := {}
		for key in value:
			copy[value_to_data(key)] = value_to_data(value[key])
		return copy
	return value


## A resource back from resource_to_data: loaded from the game's own files, or
## made from one of its own data scripts - anything else is nothing.
static func data_to_resource(data) -> Resource:
	if not data is Dictionary:
		return null
	var made: Resource = null
	var path := str(data.get("path", ""))
	if path != "":
		if not path.begins_with("res://") or not ResourceLoader.exists(path):
			return null
		made = load(path)
		if made != null and not Dictionary(data.get("meta", {})).is_empty():
			# A file's resource is shared by everything that loaded it: metadata
			# for this one fight goes on a copy.
			made = made.duplicate()
	else:
		var script_path := str(data.get("script", ""))
		var ours := false
		for root in DATA_SCRIPTS:
			ours = ours or script_path.begins_with(root)
		if not ours or not script_path.ends_with(".gd") or not ResourceLoader.exists(script_path):
			return null
		var script = load(script_path)
		# A resource's script, and nothing that is not one is ever made.
		if not script is GDScript or not script.can_instantiate() \
				or not ClassDB.is_parent_class(script.get_instance_base_type(), &"Resource"):
			return null
		made = script.new()
		var stored := {}
		for property in made.get_property_list():
			if property.usage & PROPERTY_USAGE_STORAGE:
				stored[property.name] = true
		var props = data.get("props", {})
		if props is Dictionary:
			for key in props:
				if typeof(key) == TYPE_STRING and stored.has(key) and key != "script":
					var value = data_to_value(props[key])
					var current = made.get(key)
					if current is Array and value is Array:
						var typed: Array = current.duplicate()
						typed.clear()
						for each in value:
							typed.append(each)
						made.set(key, typed)
					else:
						made.set(key, value)
	if made == null:
		return null
	var metas = data.get("meta", {})
	if metas is Dictionary:
		for meta in metas:
			if typeof(meta) == TYPE_STRING or typeof(meta) == TYPE_STRING_NAME:
				made.set_meta(meta, data_to_value(metas[meta]))
	return made


static func data_to_value(value):
	if value is Dictionary and value.size() == 1 and value.has("__resource"):
		return data_to_resource(value.__resource)
	if value is Array:
		var items := []
		for each in value:
			items.append(data_to_value(each))
		return items
	if value is Dictionary:
		var copy := {}
		for key in value:
			copy[data_to_value(key)] = data_to_value(value[key])
		return copy
	return value


## Whether `value` is plain data, with no object anywhere in it - what may go to
## the other machine.
static func is_plain(value) -> bool:
	if value is Object:
		return false
	if value is Array:
		for each in value:
			if not is_plain(each):
				return false
		return true
	if value is Dictionary:
		for key in value:
			if not is_plain(key) or not is_plain(value[key]):
				return false
	return true


## The machines with a player seated at the host's table.
func _seated_peers() -> Array:
	var peers := []
	for player in Coop.players:
		if player.peer > 1 and not peers.has(player.peer):
			peers.append(player.peer)
	return peers


## --- Over the internet (docs/multiplayer_plan.md Step 3) ---
##
## Hosting on every network (bind "*") also asks the router to open the game's
## port to the internet (UPnP), on a thread of its own, since a router can take
## seconds to answer. Opened, the host's public address is shown to send to the
## friend (public_address); not - some providers share one address among many
## homes, some routers will not do it - the Players panel says so and points at
## a virtual LAN app (Tailscale, ZeroTier, Radmin VPN): both join the same one
## and use the address it shows as on a LAN. The port is shut again on leaving,
## and as the game closes. A host bound to one address (a test's 127.0.0.1)
## never asks.

enum Router { UNASKED, ASKING, OPEN, CLOSED }

## What came of asking the router.
var router := Router.UNASKED
## The host's address on the internet, once the router has opened the port.
var public_address := ""
var _upnp: UPNP = null
var _router_thread: Thread = null


func _open_router(port: int):
	if _router_thread != null:
		# Still asking for the last time this hosted.
		_router_thread.wait_to_finish()
	router = Router.ASKING
	_router_thread = Thread.new()
	_router_thread.start(_ask_router.bind(port))


## On its own thread: the router found, the port mapped, the address asked.
func _ask_router(port: int):
	var upnp := UPNP.new()
	var answer := {}
	if upnp.discover(2000, 2, "InternetGatewayDevice") == UPNP.UPNP_RESULT_SUCCESS \
			and upnp.get_gateway() != null and upnp.get_gateway().is_valid_gateway() \
			and upnp.add_port_mapping(port, port, "Messengers of Truth", "UDP") == UPNP.UPNP_RESULT_SUCCESS:
		answer = {"upnp": upnp, "address": upnp.query_external_address(), "port": port}
	_router_answered.call_deferred(answer)


func _router_answered(answer: Dictionary):
	if _router_thread != null:
		_router_thread.wait_to_finish()
		_router_thread = null
	if answer.has("upnp") and is_host() and answer.port == host_port and router == Router.ASKING:
		_upnp = answer.upnp
		public_address = str(answer.address)
		router = Router.OPEN
	else:
		if answer.has("upnp"):
			# Hosting stopped while the router was being asked: shut it again.
			answer.upnp.delete_port_mapping(answer.port, "UDP")
		router = Router.CLOSED if is_host() else Router.UNASKED
	changed.emit()


func _close_router():
	if _upnp != null:
		_upnp.delete_port_mapping(host_port, "UDP")
		_upnp = null
	public_address = ""
	router = Router.UNASKED


func _exit_tree():
	if _router_thread != null:
		_router_thread.wait_to_finish()
		_router_thread = null
	_close_router()


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
	if is_host() and not _seated_peers().is_empty():
		_state_clock -= delta
		_state_anyway -= delta
		if _state_clock <= 0.0:
			_state_clock = STATE_SECONDS
			_send_state()
	if follows():
		_follow_now()
		if _state_held != null and _follow_due.is_empty() and not SceneTransition.is_changing():
			Campaign.apply(_state_held, MENU_KEYS if _menu_open else [])
			_state_held = null
	if with_another():
		_say_where(delta)
		_stand_for_menus()
		_play_moves()
	if is_host() and not _seated_peers().is_empty():
		_say_how_it_stands(delta)
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
