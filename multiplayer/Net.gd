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
## A machine that drops out takes its player with it, and what they steered goes
## to the other player (Coop.leave) - mid-fight too (the designer, 2026-10-29).
##
## Whom each steers (the designer, 2026-10-30): the joiner chooses whom to play
## as it first comes into the host's game (CharacterChoice, choose_characters),
## the host keeping the rest. After that a change is asked of the other player -
## the pause menu's Party Management (PlayersPanel) - and made only if they agree
## (ask_for, SteerRequest). The host is the one who leads: it can send the
## joiner away (kick). In a fight a change waits for a moment both machines'
## fights are sure to be at - one of the host's characters' turns - and goes
## along with the moves (_steer_when_both_can, the "steer" move), so neither
## machine ever plays a turn as the other thinks somebody else should.
##
## Following the host: the joiner never changes scene by itself
## (may_change_scene). Every change on the host is sent with Campaign as it
## stands then (scene_changing -> _follow), and the joiner puts that state on
## and changes too - so the map arriving does to the state what the host's
## arriving did. After that Campaign is kept the host's (_send_state): sent
## whenever it has changed and every few seconds anyway, and held back while
## the joiner is still changing scene. A joiner seated while the host is on a
## map comes straight there (_welcome), and one seated mid-fight into the fight.
## The host leaving sends the joiner back to the title screen.
##
## A fight under way, joined (the designer, 2026-10-30): the host keeps every
## fight's beginning - Campaign as it went in - and everything done in it
## since, in order (_history, _answers_given), alone or not. A joiner seated
## mid-fight is sent all of it with the seed (_join_fight), goes into the same
## fight from the same beginning and plays it through again, fast and behind a
## curtain, its own presses held (catching_up), until it stands where the
## host's does; then it plays on with it, and the characters it chose are
## handed over as soon as the fight allows.
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
const PROTOCOL := 2
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
const DATA_SCRIPTS := ["res://combat/resources/", "res://campaign/", "res://data/", "res://hacking/", "res://quicktime/"]
## How often a machine says where its groups' leaders are, walking - and,
## standing still, how long it goes without saying anyway.
const WALKS_A_SECOND := 20.0
const WALK_ANYWAY_SECONDS := 0.5
## How often the host says how its watch stands, on a watched map.
const WATCHES_A_SECOND := 10.0
## The one scene every fight is played in.
const FIGHT_SCENE := "res://scenes/game.tscn"
## The moves a fight sends - and "steer", who steers whom changing at that
## point of the fight (the host's alone to send).
const FIGHT_MOVES := ["walk", "skill", "end_turn", "undo", "ready", "deployed", "steer"]
## How much faster a fight joined under way is played through, catching up.
const CATCH_UP_SPEED := 8.0
## The presses on a map that do something to the world, which on a joiner are
## the host's to act on. Throwing (T) and the Outside Spell key (G) are not
## among them: their aiming and their choices are the joiner's own, on its own
## screen, and what they come to is done on the host (do_on_host).
const HOSTS_PRESSES: Array[StringName] = [&"interact", &"swap_leader", &"dash", &"listen", &"vault",
	&"ambush", &"take_off_disguise", &"next_disguise", &"take_down", &"pick_pocket"]
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

## Choosing whom to play: on the joiner, whether its player has, since joining,
## and the panel while it is up; on the host, the machines still choosing.
var _chosen := false
var _choice: Node = null
var _choosing := {}
## A change of who steers whom asked of this machine's player, while it is up.
var _request: Node = null
## The host, in a fight: changes agreed, waiting for a moment both fights are
## sure to be at - key -> player.
var _steering_due := {}
## Whether nothing has been done yet in the turn under way here.
var _turn_fresh := true
## The host: Campaign.controllers as the fight's own record last had them.
var _steering_noted := {}
## The joiner: the host's controllers, kept for once its fight is over.
var _controllers_after_fight = null

## A fight's beginning, kept for a joiner who comes in under way: Campaign as
## it went in, caught as the scene changed (_fight_start_due) and taken on as
## the fight began. Empty for a fight begun some other way.
var _fight_start_due := {}
var _fight_start := {}
## The host: everything done in the fight here, in order, as moves - its own,
## the joiner's and the changes of who steers whom - and every answer.
var _history: Array = []
var _answers_given := {}
## The joiner: a fight on its way here - what comes for it is kept, not dropped.
var _fight_coming := false
## The joiner, catching up: the fight's history to come, how much of the moves
## waiting is history still, the turn the host's fight was at, the answers.
var _catch_up_due := {}
var _history_left := 0
var _catch_up_turn := 0
var _known_answers := {}
var _caught_up := true
var _curtain: CanvasLayer = null

## Both choosing an answer (the designer, 2026-10-30), on the host: each
## player's pick for the line up now, and who began the conversation.
var _picks := {}
var _starter := -1


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


## The host sends player `id`'s machine away - Kick out on their row (the
## designer, 2026-10-30: the host leads). They are told why, then cut off.
func kick(id: int):
	if not is_host() or Coop.is_local(id):
		return
	var peer: int = Coop.player(id).get("peer", 0)
	if peer > 1 and _peer != null:
		_kicked.rpc_id(peer, "The host sent you out of the game.")
		_kicked_out[peer] = true
		# Long enough for the word to arrive before the line goes.
		_turned_away[peer] = Time.get_ticks_msec()


## The machines kicked out, to say so when they go.
var _kicked_out := {}


@rpc("authority", "reliable")
func _kicked(why):
	if not is_joiner():
		return
	var was_following := follows()
	told.emit(str(why))
	_close()
	if was_following:
		_back_to_the_title(str(why))


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
	_chosen = false
	_choosing.clear()
	_steering_due.clear()
	_controllers_after_fight = null
	_fight_coming = false
	_catch_up_due = {}
	_known_answers.clear()
	_picks.clear()
	_close_choice()
	_close_request()
	_end_catching_up()
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
	var kicked: bool = _kicked_out.get(peer, false)
	_kicked_out.erase(peer)
	_choosing.erase(peer)
	if not is_host():
		return
	var gone := false
	for id in range(Coop.players.size() - 1, -1, -1):
		if Coop.players[id].peer == peer:
			_picks.erase(id)
			Coop.leave(id)
			gone = true
	if gone:
		var said := "The other player was sent out of the game. Their characters are yours." if kicked \
			else "The other player has left. Their characters are yours."
		told.emit(said)
		say_in_game(said + "\n")
		# Mid-fight too (the designer, 2026-10-29): the turn under way, if it
		# was theirs, is this machine's player's now, and nothing more of theirs
		# is coming - nor any change of hands agreed with them.
		_moves.clear()
		_steering_due.clear()
		_close_request()
		if _fight != null and is_instance_valid(_fight) and not _fight.combat_over and not _fight.combatants.is_empty():
			Coop.fight_turn(_fight.player_of(_fight.get_current_combatant()) if _fight.controller.player_turn else Coop.ANYONE)
		# A conversation waiting on their answer goes on with this one's.
		_settle_picks()
		changed.emit()


## `text` written where whoever is at this machine reads it: the map's log, or
## the fight's.
func say_in_game(text: String):
	var scene := get_tree().current_scene
	if scene is ExplorationScene:
		scene.log_message(text)
	elif scene is GameScene and scene.combat != null and is_instance_valid(scene.combat):
		scene.combat.update_information.emit(text)


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
	# One player for each machine, as a rule: the first device it named - and
	# whom they play is theirs to choose, coming in (choose_characters).
	_choosing[peer] = true
	Coop.join(int(devices[0]), "", peer)
	told.emit("%s has joined over the network." % Coop.name_of(Coop.players.size() - 1))
	say_in_game("%s has joined over the network, and is choosing whom to play.\n" % Coop.name_of(Coop.players.size() - 1))
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
	var steering := _plain_controllers(controllers)
	var first_time := not _seated
	_seated = true
	_joining_since = -1
	Coop.local_peer = multiplayer.get_unique_id()
	Coop.networked = true
	Coop.players = seats
	# In a fight who steers whom changes only with its moves ("steer"): the
	# host's table may be ahead of the fight here.
	if in_a_shared_fight() or _fight_coming:
		_controllers_after_fight = steering
	else:
		Campaign.controllers = steering
	if first_time:
		told.emit("Joined the game at %s." % host_address)
		changed.emit()
	Coop.players_changed.emit()


func _on_players_changed():
	# Another machine come or gone: a menu open holds the game, or no longer.
	MenuPause.reapply(get_tree())
	# Who steers whom changed in the middle of a fight here: at this point of it,
	# for the record - and for the joiner's fight, which changes with it.
	_note_steering()
	# Once for however many changes come in a frame.
	if is_host() and not _table_due:
		_table_due = true
		_send_table.call_deferred()


static func _plain_controllers(controllers) -> Dictionary:
	var steering := {}
	if controllers is Dictionary:
		for key in controllers:
			if typeof(key) == TYPE_STRING and typeof(controllers[key]) == TYPE_INT and controllers[key] > 0:
				steering[key] = controllers[key]
	return steering


## --- Choosing whom to play ---
##
## The joiner's player chooses whom of the party they play as they first come
## into the host's game, on a map or in a fight (the designer, 2026-10-30):
## CharacterChoice, put up once (_chosen). The host keeps the rest, and at
## least one of them. Until they have chosen, nobody offers to share the party
## out on their account (choosing).


## Whether player `id` is still choosing whom to play, having just joined.
func choosing(id: int) -> bool:
	if follows():
		return Coop.is_local(id) and not _chosen
	if is_host() and id >= 0 and id < Coop.players.size():
		return _choosing.has(Coop.players[id].peer)
	return false


## On the joiner, once its map or fight is up: the choice, if not made yet.
func _offer_the_choice():
	if not follows() or _chosen or (_choice != null and is_instance_valid(_choice)) or SceneTransition.is_changing():
		return
	# Into a fight under way, once it is caught up: who steers whom stands as
	# the host's does only then.
	if catching_up() or _fight_coming:
		return
	var scene := get_tree().current_scene
	if not scene is ExplorationScene and not (scene is GameScene and _fight != null and is_instance_valid(_fight)):
		return
	var mine := Coop.local_players()
	if mine.is_empty():
		return
	if not Coop.keys_of(mine[0]).is_empty():
		# Steering somebody already - chosen on the title screen's Players.
		choose_characters(Coop.keys_of(mine[0]))
		return
	_choice = CharacterChoice.new()
	_choice.chosen.connect(choose_characters)
	scene.add_child(_choice)


func _close_choice():
	if _choice != null and is_instance_valid(_choice):
		_choice.queue_free()
	_choice = null


## The joiner's player plays `keys` - asked of the host, which keeps the rest.
func choose_characters(keys: Array):
	_chosen = true
	_close_choice()
	if follows():
		_chose.rpc_id(1, keys.filter(func(key): return typeof(key) == TYPE_STRING))
	# Watching by choice is not to be offered the party to share out for it.
	if keys.is_empty():
		Coop.share_out_offered = Coop.party_shape()


@rpc("any_peer", "reliable")
func _chose(keys):
	var peer := multiplayer.get_remote_sender_id()
	if not is_host() or not _seated_peers().has(peer) or typeof(keys) != TYPE_ARRAY:
		return
	_choosing.erase(peer)
	var id := -1
	for each in Coop.players:
		if each.peer == peer:
			id = each.id
	var standing := PlayersPanel.party_now()
	var changes := {}
	for key in keys:
		if typeof(key) == TYPE_STRING and standing.has(key) and Coop.controller_of(key) != id:
			changes[key] = id
	# The host keeps somebody, while there is anybody to keep.
	var keeps := standing.filter(func(key): return not changes.has(key) and Coop.controller_of(key) != id)
	if keeps.is_empty() and not changes.is_empty():
		changes.erase(changes.keys().back())
	var theirs := standing.filter(func(key): return changes.has(key) or Coop.controller_of(key) == id)
	var names := theirs.map(func(key): return Campaign.display_name_of(key))
	say_in_game("%s plays %s.\n" % [Coop.name_of(id), " and ".join(names)] if not names.is_empty()
		else "%s watches for now.\n" % Coop.name_of(id))
	_change_steering(changes)
	if changes.is_empty():
		Coop.share_out_offered = Coop.party_shape()


## --- Asking for a change ---
##
## After that, whom each steers changes only if the other player agrees (the
## designer, 2026-10-30): a player asks for one of the other's characters, or
## offers one of their own (PlayersPanel in Party Management), and the other
## answers on their own screen (SteerRequest). The host makes the change - at
## once on a map, as soon as both fights can in a fight (_change_steering).


## This machine's player asks that `key` be steered by player `to` from now on.
func ask_for(key: String, to: int):
	if not with_another() or to < 0 or to >= Coop.players.size():
		return
	var mine := Coop.local_players()
	if mine.is_empty():
		return
	if is_host():
		var peer: int = _seated_peers()[0]
		_asked.rpc_id(peer, key, to, mine[0])
	else:
		_ask.rpc_id(1, key, to)
	say_in_game("You ask %s - %s to %s.\n" % [Coop.name_of(_other_than(mine[0])), Campaign.display_name_of(key), Coop.name_of(to)])


## The other player than `id`, of two.
func _other_than(id: int) -> int:
	for each in Coop.players:
		if each.id != id:
			return each.id
	return id


## The host: the joiner's player asks. Put to the host's player.
@rpc("any_peer", "reliable")
func _ask(key, to):
	var peer := multiplayer.get_remote_sender_id()
	if not is_host() or not _seated_peers().has(peer) or typeof(key) != TYPE_STRING or typeof(to) != TYPE_INT:
		return
	if not PlayersPanel.party_now().has(key) or to < 0 or to >= Coop.players.size():
		return
	var from := -1
	for each in Coop.players:
		if each.peer == peer:
			from = each.id
	_put_request_up(key, to, from, func(yes: bool):
		if yes:
			_change_steering({key: to})
		_answered.rpc_id(peer, key, to, yes))


## The joiner: the host's player asks. Put to this machine's player.
@rpc("authority", "reliable")
func _asked(key, to, from):
	if not follows() or typeof(key) != TYPE_STRING or typeof(to) != TYPE_INT or typeof(from) != TYPE_INT:
		return
	_put_request_up(key, to, from, func(yes: bool): _reply.rpc_id(1, key, to, yes))


## The host: the joiner's player's answer to the host's.
@rpc("any_peer", "reliable")
func _reply(key, to, yes):
	if not is_host() or not _seated_peers().has(multiplayer.get_remote_sender_id()) or typeof(key) != TYPE_STRING \
			or typeof(to) != TYPE_INT or typeof(yes) != TYPE_BOOL:
		return
	var asked := _other_than(Coop.local_players()[0]) if not Coop.local_players().is_empty() else 1
	_say_answer(key, to, asked, yes)
	if yes and PlayersPanel.party_now().has(key) and to >= 0 and to < Coop.players.size():
		_change_steering({key: to})


## The joiner: the host's player's answer to this one's.
@rpc("authority", "reliable")
func _answered(key, to, yes):
	if follows() and typeof(key) == TYPE_STRING and typeof(to) == TYPE_INT and typeof(yes) == TYPE_BOOL:
		_say_answer(key, to, 0, yes)


func _say_answer(key: String, to: int, asked: int, yes: bool):
	var later := in_a_shared_fight() and Coop.controller_of(key) != to
	if yes:
		say_in_game("[color=lightgreen]%s agrees[/color] - %s to %s%s.\n" % [Coop.name_of(asked), Campaign.display_name_of(key),
			Coop.name_of(to), ", as soon as the fight allows" if later else ""])
	else:
		say_in_game("%s would rather not - %s stays with %s.\n" % [Coop.name_of(asked), Campaign.display_name_of(key),
			Coop.name_of(Coop.controller_of(key))])


## The question up on this machine: `from` asks that `key` go to `to`.
## `answer` is called with the answer.
func _put_request_up(key: String, to: int, from: int, answer: Callable):
	_close_request()
	_request = SteerRequest.new()
	_request.key = key
	_request.to = to
	_request.from = from
	_request.answered.connect(func(yes: bool):
		_request = null
		answer.call(yes))
	get_tree().root.add_child(_request)


func _close_request():
	if _request != null and is_instance_valid(_request):
		_request.queue_free()
	_request = null


## The host: `changes` (key -> player) made - at once, or in a fight once both
## fights can take them (_steer_when_both_can).
func _change_steering(changes: Dictionary):
	if changes.is_empty():
		return
	if in_a_shared_fight():
		for key in changes:
			_steering_due[key] = changes[key]
		_steer_when_both_can()
		return
	for key in changes:
		if changes[key] <= 0:
			Campaign.controllers.erase(key)
		else:
			Campaign.controllers[key] = changes[key]
	Coop.players_changed.emit()


## The host, in a fight played on both: the changes agreed, made now if this is
## a moment the joiner's fight is sure to come to as well - one of the host's
## own characters' turns, standing waiting, since the joiner cannot play past
## that without the host's moves. The character whose turn it is changes hands
## only before anything has been done in it. Sent with the moves ("steer"), at
## this point of them (_note_steering).
func _steer_when_both_can():
	if _steering_due.is_empty() or not in_a_shared_fight() or not is_host():
		return
	var combat := _fight
	if combat.deployment_active or _playing_move or not combat.controller.player_turn \
			or not combat.controller.is_idle() or combat.controller.action_locked:
		return
	var current: Dictionary = combat.get_current_combatant()
	if not combat.plays_for_party(current) or not Coop.is_local(combat.player_of(current)):
		return
	var acting_key := _steering_key(combat, current)
	var made := []
	for key in _steering_due.keys():
		if key == acting_key and not _turn_fresh:
			continue
		var to: int = _steering_due[key]
		_steering_due.erase(key)
		if to <= 0:
			Campaign.controllers.erase(key)
		else:
			Campaign.controllers[key] = to
		made.append("%s is %s's now" % [Campaign.display_name_of(key), Coop.name_of(to)])
	if made.is_empty():
		return
	Coop.fight_turn(combat.player_of(current))
	Coop.players_changed.emit()
	say_in_game("%s.\n" % ", ".join(made))


## The key `comb`'s turn is steered by: theirs, or a summon's summoner's.
static func _steering_key(combat: Combat, comb: Dictionary) -> String:
	if comb.has("summoner"):
		return combat._combatant_by_id(comb.summoner).get("combatant_key", "")
	return comb.get("combatant_key", "")


## The host, in a fight: Campaign.controllers changed - written into the
## fight's record at this point of it, and sent with the moves when it is
## played on both.
func _note_steering():
	if follows() or _fight == null or not is_instance_valid(_fight) or not _fight.is_inside_tree() or _fight.combat_over:
		return
	var now := _plain_controllers(Campaign.controllers)
	if now == _steering_noted:
		return
	_steering_noted = now
	var move := [fight_turn, _fight.get_current_combatant().get("id", -1) if not _fight.combatants.is_empty() else -1, "steer", [now.duplicate()]]
	_history.append(move)
	if in_a_shared_fight():
		_fight_move.rpc(move[0], move[1], move[2], move[3])


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
	if follows():
		return
	var shared := is_host() and not _seated_peers().is_empty()
	if path == FIGHT_SCENE and Campaign.current_encounter != null and shared:
		var fight: EncounterDefinition = Campaign.current_encounter.duplicate()
		for meta in Campaign.current_encounter.get_meta_list():
			fight.set_meta(meta, Campaign.current_encounter.get_meta(meta))
		fight.set_meta("seed", randi())
		Campaign.current_encounter = fight
	var into_a_fight := path == FIGHT_SCENE and Campaign.current_encounter != null
	_fight_start_due = {}
	if not shared and not into_a_fight:
		return
	var state := Campaign.net_state()
	# Into a fight, alone or not: how it began, for whoever joins it under way.
	if into_a_fight:
		_fight_start_due = {"state": state}
	if shared:
		_follow.rpc(path, state, false)


## On a joiner, whether the map coming up is one the host is already on, so its
## party and bags are the host's as they stand - not set up again as arriving
## sets them (ExplorationScene._ready). Asked once, as the map comes up.
func arrives_as_it_stands() -> bool:
	var was := _arriving_as_it_stands
	_arriving_as_it_stands = false
	return was


## Where a joiner just seated should be: on the host's map, or wherever else it
## is but the title screen - into a fight under way too, from its beginning
## (_join_fight), when this machine kept how it began.
func _welcome(peer: int):
	var scene := get_tree().current_scene
	var path := scene.scene_file_path if scene != null else ""
	if path == "" or path == Campaign.MAIN_MENU:
		return
	if scene is GameScene and scene.combat != null:
		var combat: Combat = scene.combat
		if combat.combat_over:
			_waiting.rpc_id(peer, "The host is finishing a fight. You come in once it is done.")
		elif combat != _fight or _fight_start.is_empty():
			_waiting.rpc_id(peer, "The host is in a fight. You come in once it is over.")
		else:
			var state: Dictionary = _fight_start.state.duplicate(true)
			# The encounter it began with, and the seed it rolled from, which a
			# fight begun alone never wrote on it.
			var encounter = state.get("encounter")
			if encounter is Dictionary:
				encounter["meta"] = Dictionary(encounter.get("meta", {}))
				encounter.meta["seed"] = combat.fight_seed
			_join_fight.rpc_id(peer, state, _history.duplicate(true), _answers_given.duplicate(true), fight_turn)
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
	_expect_a_fight(path == FIGHT_SCENE)
	_follow_now()


## Into a fight under way: Campaign as the fight began, everything done in it
## since (`history`, `answers`), and the turn the host's has come to - to play
## it through from its beginning until this machine's fight stands there too.
@rpc("authority", "reliable")
func _join_fight(state, history, answers, turn):
	if not follows() or typeof(state) != TYPE_DICTIONARY or typeof(history) != TYPE_ARRAY \
			or typeof(answers) != TYPE_DICTIONARY or typeof(turn) != TYPE_INT:
		return
	var moves := []
	for move in history:
		if move is Array and move.size() == 4 and typeof(move[0]) == TYPE_INT and typeof(move[1]) == TYPE_INT \
				and typeof(move[2]) == TYPE_STRING and FIGHT_MOVES.has(move[2]) and move[3] is Array and is_plain(move[3]):
			moves.append(move)
	var given := {}
	for asked in answers:
		if typeof(asked) == TYPE_INT and is_plain(answers[asked]):
			given[asked] = answers[asked]
	_follow_due = {"path": FIGHT_SCENE, "state": state, "as_it_stands": false}
	_state_held = null
	_expect_a_fight(true)
	_catch_up_due = {"moves": moves, "answers": given, "turn": turn}
	told.emit("The host is in a fight - you come into it.")
	_follow_now()


## The joiner: a fight is on its way here (`coming`), or not. What the host
## sends for it from now on is kept for it rather than dropped, until it is up
## (fight_begins) - and nothing of the last one is played any more.
func _expect_a_fight(coming: bool):
	_fight_coming = coming
	if coming:
		_moves.clear()
		_answers.clear()
		_catch_up_due = {}


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
	Campaign.apply(state, _kept_here())


## The Campaign keys a state from the host leaves as this machine has them now:
## what a menu open here may change, and in a fight who steers whom, which
## changes there only with the fight's own moves.
func _kept_here() -> Array:
	var kept: Array = MENU_KEYS.duplicate() if _menu_open else []
	if in_a_shared_fight() or _fight_coming:
		kept.append("controllers")
	if not _hack_costs.is_empty():
		kept.append_array(HACK_KEYS)
	return kept


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
	# What the host has sent for this fight since it was on its way is kept.
	if not _fight_coming:
		_moves.clear()
		_answers.clear()
	_fight_coming = false
	_playing_move = false
	_replaying = false
	_questions = 0
	_checks_here.clear()
	_checks_there.clear()
	parted.clear()
	checked_turns = 0
	_turn_fresh = true
	_steering_noted = _plain_controllers(Campaign.controllers)
	_history.clear()
	_answers_given.clear()
	_known_answers.clear()
	_fight_start = _fight_start_due if not follows() else {}
	_fight_start_due = {}
	combat.turn_advanced.connect(_on_turn_advanced)
	if follows() and not _catch_up_due.is_empty():
		# Joined under way: everything done in it so far, ahead of what has
		# come since, played through fast until this fight stands where the
		# host's does (catching_up).
		_moves = _catch_up_due.moves + _moves
		_history_left = _catch_up_due.moves.size()
		_known_answers = _catch_up_due.answers
		_catch_up_turn = _catch_up_due.turn
		_catch_up_due = {}
		_begin_catching_up()


## Whether a fight here is being played on the other machine too.
func in_a_shared_fight() -> bool:
	return with_another() and _fight != null and is_instance_valid(_fight) and _fight.is_inside_tree() and not _fight.combat_over


## Whether this machine places the party before a fight - the host does; on the
## joiner only the host's placing, played here, does (Combat.finish_deployment).
func may_deploy() -> bool:
	return not in_a_shared_fight() or not follows() or _replaying


## A move made here in `combat`, for the other machine to make too: `kind` (one
## of FIGHT_MOVES) with `args` - plain data. Nothing while playing the other's.
## Kept in the fight's record whether or not anybody else is playing it.
func fight_move(combat: Combat, kind: String, args: Array):
	if _replaying or combat != _fight:
		return
	if kind == "deployed":
		var places := {}
		for comb in combat.combatants:
			if comb.get("side", 1) == 0 and not comb.has("object"):
				places[comb.get("id", -1)] = comb.position
		args = [places]
	else:
		_turn_fresh = false
	var move := [fight_turn, combat.get_current_combatant().get("id", -1), kind, args]
	if not follows():
		_history.append(move)
	if in_a_shared_fight():
		_fight_move.rpc(move[0], move[1], move[2], move[3])


@rpc("any_peer", "reliable")
func _fight_move(turn, comb_id, kind, args):
	if typeof(turn) != TYPE_INT or typeof(comb_id) != TYPE_INT or typeof(kind) != TYPE_STRING or typeof(args) != TYPE_ARRAY:
		return
	if not FIGHT_MOVES.has(kind) or not is_plain(args):
		return
	var sender := multiplayer.get_remote_sender_id()
	if follows():
		# The host's every move is taken - kept, too, while the fight is still
		# on its way here.
		if sender != 1 or not (in_a_shared_fight() or _fight_coming):
			return
	else:
		# Only from the machine of whoever steers the one moving - the party's
		# placing and who steers whom never from the joiner.
		if not in_a_shared_fight() or kind == "deployed" or kind == "steer":
			return
		var comb: Dictionary = _fight._combatant_by_id(comb_id)
		var id := _fight.player_of(comb) if not comb.is_empty() else -1
		if id < 0 or id >= Coop.players.size() or Coop.players[id].peer != sender:
			return
	_moves.append([turn, comb_id, kind, args])


## The other machine's moves, each once this fight has come to its turn and
## stands waiting for the one moving.
func _play_moves():
	if _playing_move or _moves.is_empty() or _fight_coming or not in_a_shared_fight():
		return
	var move: Array = _moves[0]
	var combat := _fight
	if move[2] == "deployed":
		if not combat.deployment_active:
			return
	elif move[2] == "steer":
		# Who steers whom changes at that point of the fight: once that turn is
		# here and standing waiting - or straight away in a turn the AI plays,
		# or one this fight has already gone past (a change written down as a
		# player went, in the middle of anything).
		if move[0] > fight_turn or combat.deployment_active:
			return
		if move[0] == fight_turn and combat.controller.player_turn and (not combat.controller.is_idle() or combat.controller.action_locked):
			return
	else:
		if move[0] != fight_turn or combat.deployment_active:
			return
		var comb: Dictionary = combat.get_current_combatant()
		if comb.get("id", -1) != move[1] or not combat.controller.player_turn \
				or not combat.controller.is_idle() or combat.controller.action_locked:
			return
	_moves.pop_front()
	if _history_left > 0:
		_history_left -= 1
	# The joiner's moves are part of the fight's record as the host plays them.
	if is_host():
		_history.append(move)
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
		"steer":
			if args.size() == 1 and args[0] is Dictionary:
				Campaign.controllers = _plain_controllers(args[0])
				_steering_noted = Campaign.controllers.duplicate()
				Coop.fight_turn(combat.player_of(comb) if controller.player_turn else Coop.ANYONE)
				Coop.players_changed.emit()


## What `who` decides - `deciding` called on their machine (a question put
## up, a quick time played, a hack) and its answer sent, so that on the other
## machine the same call waits for that answer instead. Outside a fight played
## on both machines, simply `deciding` called.
func decided(who: int, deciding: Callable):
	if not in_a_fight():
		return await deciding.call()
	_questions += 1
	var asked := _questions
	# Played through again, catching up: answered as it was the first time.
	if _known_answers.has(asked):
		var known = _known_answers[asked]
		_known_answers.erase(asked)
		return known
	if who < 0 or who >= Coop.players.size():
		who = 0
	var answer = null
	if not in_a_shared_fight() or Coop.is_local(who):
		answer = await deciding.call()
		if in_a_shared_fight():
			_answer.rpc(asked, answer)
	else:
		while not _answers.has(asked):
			if not in_a_shared_fight():
				answer = await deciding.call()
				break
			await get_tree().process_frame
		if _answers.has(asked):
			answer = _answers[asked]
			_answers.erase(asked)
	if not follows() and is_plain(answer):
		_answers_given[asked] = answer
	return answer


## Whether a fight is being played here now.
func in_a_fight() -> bool:
	return _fight != null and is_instance_valid(_fight) and _fight.is_inside_tree() and not _fight.combat_over


@rpc("any_peer", "reliable")
func _answer(asked, answer):
	if typeof(asked) != TYPE_INT or not is_plain(answer):
		return
	if (in_a_shared_fight() or (_fight_coming and multiplayer.get_remote_sender_id() == 1)):
		_answers[asked] = answer


func _on_turn_advanced(_comb: Dictionary):
	fight_turn += 1
	_turn_fresh = true
	if not in_a_fight():
		return
	if not follows():
		# Kept alone too, for a joiner who comes in later to be checked against.
		_checks_here[fight_turn] = hash(_fight.fight_state())
		_check(fight_turn)
	elif in_a_shared_fight():
		_fight_check.rpc_id(1, fight_turn, hash(_fight.fight_state()))


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
	# Far behind - a joiner playing the fight through - this fight's numbers
	# now are not the fight as it was then.
	if turn < fight_turn - 1:
		return
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


## --- Played afar ---
##
## A hack or a quick time outside a fight is played by whoever it is for, on
## their own screen: on the host, one set going by the joiner's player - their
## press done here - or a magic trap they must answer, or a conversation they
## began, is sent to the joiner to play (Hacking.run asks hack_afar, the rest
## quick_time_by), and what it comes to is waited for and settled here. A hack
## played for the host spends its gates and strain on the joiner as it goes,
## kept from the host's Campaign meanwhile, and says what it spent
## (hack_cost), which the host spends too. In a fight both go through decided.

## How many have been sent to be played afar, and their answers by number.
var _afar_asked := 0
var _afar_answers := {}
## The joiner, playing a hack for the host: what it has cost - {} otherwise.
var _hack_costs := {}
## The keys a hack played for the host may change, kept here while it plays.
const HACK_KEYS := ["gates_spent_outside", "party_state"]


## On the host: whether `player` plays on the other machine, so that what is
## theirs to play is played there.
func plays_afar(player: int) -> bool:
	return is_host() and with_another() and player >= 0 and player < Coop.players.size() and not Coop.is_local(player)


## Who began the conversation on the host's balloon now - the first player
## when there is none.
func conversation_starter() -> int:
	return _starter if is_host() and _balloon != null and is_instance_valid(_balloon) and _starter >= 0 else 0


## The host: `hack` (known by `id`) played by `player` on their machine, as
## `key` - and how it went, its costs spent here.
func hack_afar(player: int, hack: HackDefinition, id: String, key: String) -> Dictionary:
	_afar_asked += 1
	var asked := _afar_asked
	_hack_here.rpc_id(Coop.player(player).peer, asked, resource_to_data(hack), id, key)
	var answer = await _wait_from_afar(asked)
	if not answer is Array or answer.size() != 2 or not answer[0] is Dictionary or not answer[1] is Dictionary:
		return {"result": "walked_away"}
	var costs: Dictionary = answer[1]
	for gate in costs.get("gates", []):
		if typeof(gate) == TYPE_INT:
			Campaign.spend_gate_outside(key, gate)
	if int(costs.get("strain", 0)) > 0:
		Campaign.strain(key, int(costs.strain))
	var watch = Campaign.stealth_watch
	if float(costs.get("alert", 0.0)) > 0.0 and watch != null and is_instance_valid(watch):
		watch.raise_alert(clampf(float(costs.alert), 0.0, 1.0))
	var outcome: Dictionary = answer[0]
	var result := str(outcome.get("result", "walked_away"))
	if not result in ["success", "failed", "walked_away", "locked", "nobody", "busy"]:
		result = "walked_away"
	return {"result": result, "set_off": bool(outcome.get("set_off", false)), "locked_out": bool(outcome.get("locked_out", false))}


## `definition` played by `player`: here, or over a network on their machine -
## and whether it was done in time.
func quick_time_by(player: int, definition: QuickTimeDefinition) -> bool:
	if not plays_afar(player):
		return await QuickTime.run(definition)
	_afar_asked += 1
	var asked := _afar_asked
	_quick_time_here.rpc_id(Coop.player(player).peer, asked, resource_to_data(definition))
	return await _wait_from_afar(asked) == true


func _wait_from_afar(asked: int):
	while not _afar_answers.has(asked):
		if not with_another():
			return null
		await get_tree().process_frame
	var answer = _afar_answers[asked]
	_afar_answers.erase(asked)
	return answer


## The joiner: a hack to play for the host, as `key`.
@rpc("authority", "reliable")
func _hack_here(asked, data, id, key):
	if not follows() or typeof(asked) != TYPE_INT or typeof(id) != TYPE_STRING or typeof(key) != TYPE_STRING:
		return
	var hack := data_to_resource(data) as HackDefinition
	var answer := [{"result": "busy"}, {}]
	if hack != null and not Hacking.running():
		_hack_costs = {"gates": [], "strain": 0, "alert": 0.0}
		var outcome: Dictionary = await Hacking.run(hack, id, null, {}, key)
		answer = [outcome, _hack_costs]
		_hack_costs = {}
	_from_afar.rpc_id(1, asked, answer)


## The joiner, playing a hack for the host: `what` it has cost - a gate, so much
## strain, so much alert.
func hack_cost(what: String, amount):
	if _hack_costs.is_empty():
		return
	match what:
		"gates":
			_hack_costs.gates.append(int(amount))
		"strain":
			_hack_costs.strain += int(amount)
		"alert":
			_hack_costs.alert += float(amount)


## The joiner: a quick time to play for the host.
@rpc("authority", "reliable")
func _quick_time_here(asked, data):
	if not follows() or typeof(asked) != TYPE_INT:
		return
	var definition := data_to_resource(data) as QuickTimeDefinition
	var done := false
	if definition != null and not QuickTime.running():
		done = await QuickTime.run(definition)
	_from_afar.rpc_id(1, asked, done)


@rpc("any_peer", "reliable")
func _from_afar(asked, answer):
	if is_host() and typeof(asked) == TYPE_INT and asked <= _afar_asked and _seated_peers().has(multiplayer.get_remote_sender_id()) \
			and is_plain(answer):
		_afar_answers[asked] = answer


## The host: the familiar asked for by `asker`, of its caster's player on the
## other machine - put to them there.
func ask_for_the_familiar(asker: int, asked: int):
	if plays_afar(asked):
		_familiar_asked.rpc_id(Coop.player(asked).peer, asker)


@rpc("authority", "reliable")
func _familiar_asked(asker):
	var scene := _map()
	if not follows() or typeof(asker) != TYPE_INT or scene == null or scene.familiar_keeper == null \
			or scene.familiar_keeper.familiar == null or Coop.local_players().is_empty():
		return
	var request := FamiliarRequest.new()
	request.keeper = scene.familiar_keeper
	request.asker = asker
	request.asked = Coop.local_players()[0]
	request.answered.connect(func(yes: bool): _familiar_answer.rpc_id(1, asker, yes))
	var layer := CanvasLayer.new()
	layer.name = "FamiliarRequest"
	layer.layer = 60
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	scene.add_child(layer)
	layer.add_child(request)
	request.tree_exited.connect(layer.queue_free)


@rpc("any_peer", "reliable")
func _familiar_answer(asker, yes):
	var scene := _map()
	if not is_host() or typeof(asker) != TYPE_INT or typeof(yes) != TYPE_BOOL or scene == null or scene.familiar_keeper == null:
		return
	var keeper: FamiliarKeeper = scene.familiar_keeper
	# Only from the machine of whoever steers its caster.
	if not _sent_by_whoever_plays(keeper.caster_player()):
		return
	keeper._on_answered(yes, asker)


## --- Catching up ---
##
## A joiner come into a fight under way plays everything done in it so far
## through again (fight_begins): Combat paces every turn at CATCH_UP_SPEED
## meanwhile (Combat._pace_turn), the sound is off, a curtain says how far it
## has got, and this machine's own presses are held (drops). Caught up - the
## history played, and its fight at the turn the host's was at - all is as
## ever.


## Whether this machine is playing a fight through to catch up with the host's.
func catching_up() -> bool:
	return not _caught_up


func _begin_catching_up():
	_caught_up = false
	_mute(true)
	if _curtain == null or not is_instance_valid(_curtain):
		_curtain = CanvasLayer.new()
		_curtain.name = "CatchingUp"
		_curtain.layer = 45
		var label := Label.new()
		label.name = "Line"
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_color_override("font_color", Color("e8c27a"))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		label.add_theme_constant_override("outline_size", 8)
		label.position = Vector2(40, 96)
		_curtain.add_child(label)
		get_tree().root.add_child(_curtain)
	Engine.time_scale = CATCH_UP_SPEED
	_keep_catching_up()


func _keep_catching_up():
	if _caught_up:
		return
	if not in_a_shared_fight():
		_end_catching_up()
		return
	if _history_left <= 0 and fight_turn >= _catch_up_turn:
		_end_catching_up()
		told.emit("Caught up with the fight.")
		say_in_game("[color=#e8c27a]Caught up with the fight.[/color]\n")
		return
	if _curtain != null and is_instance_valid(_curtain):
		_curtain.get_node("Line").text = "Catching up with the fight - turn %d of %d..." % [mini(fight_turn + 1, _catch_up_turn + 1), _catch_up_turn + 1]


func _end_catching_up():
	if _caught_up:
		return
	_caught_up = true
	_history_left = 0
	_known_answers.clear()
	_mute(false)
	if _curtain != null and is_instance_valid(_curtain):
		_curtain.queue_free()
	_curtain = null
	# Back to the pace of the turn under way.
	if in_a_fight() and not _fight.combatants.is_empty():
		_fight._pace_turn(_fight.get_current_combatant())
	else:
		Engine.time_scale = 1.0


func _mute(muted: bool):
	var bus := AudioServer.get_bus_index("Master")
	if bus < 0:
		return
	if muted:
		_was_muted = AudioServer.is_bus_mute(bus)
		AudioServer.set_bus_mute(bus, true)
	else:
		AudioServer.set_bus_mute(bus, _was_muted)


var _was_muted := false


## Whether `event` is held back from this machine's game: while catching up,
## every press but the pause menu's and a ping.
func drops(event: InputEvent) -> bool:
	if _caught_up or not event.is_pressed():
		return false
	return not (event.is_action(&"pause") or event.is_action(&"ui_cancel") or event.is_action(&"ping"))


## --- Conversations ---
##
## The host runs every conversation. Each line its balloon shows
## (DialogueBalloon.apply_dialogue_line -> conversation_line) goes to the joiner
## and is shown there in a copy (ConversationMirror), the joiner's own party held
## meanwhile. Whoever began it presses on through its lines: on the joiner that
## is sent back (answer_line) and done on the host's balloon. An answer is both
## players' to choose (the designer, 2026-10-30): each picks on their own screen
## (chose_here, and _converse from the joiner); the same one is taken, and two
## different ones are shown to both, who choose again (_settle_picks). The
## conversation's end closes the copy.


func conversation_line(balloon: Node):
	if not is_host() or _seated_peers().is_empty():
		return
	if balloon != _balloon:
		# Begun just now: by whoever has the focus - or, walked into, the first.
		_starter = Coop.focus if Coop.focus != Coop.ANYONE else 0
	_balloon = balloon
	_picks.clear()
	var line = balloon.dialogue_line
	var answers := []
	for response in line.responses:
		answers.append([str(response.text), bool(response.is_allowed)])
	# Choosing is both players', so neither's presses are kept from the
	# answers; pressing on through a line is whoever began it.
	Coop.focus = Coop.ANYONE if not answers.is_empty() else _starter
	_line.rpc(str(line.character), str(line.text), answers, _starter)


func conversation_over(balloon: Node):
	if balloon == _balloon:
		_balloon = null
		_picks.clear()
	if is_host() and not _seated_peers().is_empty():
		_line_over.rpc()


## Over a network: whether an answer picked on `balloon` waits for the other
## player's pick too.
func chooses_together(balloon: Node) -> bool:
	return is_host() and balloon == _balloon and not _seated_peers().is_empty()


## The host's player picked the `index`th answer on `balloon`.
func chose_here(balloon: Node, index: int):
	if not chooses_together(balloon) or index < 0:
		return
	var mine := Coop.local_players()
	_picks[mine[0] if not mine.is_empty() else 0] = index
	_settle_picks()


## Both picked the same: taken. Two different: both shown what each chose, and
## asked again. Somebody still to pick: each told how it stands.
func _settle_picks():
	if _balloon == null or not is_instance_valid(_balloon) or _picks.is_empty():
		return
	var line = _balloon.dialogue_line
	if line == null or line.responses.is_empty():
		_picks.clear()
		return
	var waiting_on := []
	for each in Coop.players:
		if not _picks.has(each.id):
			waiting_on.append(each.id)
	if not waiting_on.is_empty():
		var host_picked := Coop.local_players().any(func(id): return _picks.has(id))
		var other := _other_than(Coop.local_players()[0] if not Coop.local_players().is_empty() else 0)
		_balloon.show_choice_note("Waiting for %s to choose..." % Coop.name_of(other) if host_picked
			else "%s has chosen." % Coop.name_of(other), host_picked)
		_pick_note.rpc("Waiting for %s to choose..." % Coop.name_of(0) if not host_picked
			else "%s has chosen." % Coop.name_of(0), not host_picked)
		return
	var picks := _picks.duplicate()
	_picks.clear()
	var first: int = picks.values()[0]
	if picks.values().all(func(pick): return pick == first):
		_balloon.respond_from_afar(first)
		return
	var said := []
	for id in picks:
		said.append("%s chose \"%s\"" % [Coop.name_of(id), str(line.responses[picks[id]].text)])
	var note := "%s - choose again, the same answer." % ", ".join(said)
	_balloon.choose_again(note)
	_pick_again.rpc(note)


## The joiner: how the choosing stands - `waiting` once its own pick is in.
@rpc("authority", "reliable")
func _pick_note(text, waiting):
	if follows() and _mirror != null and is_instance_valid(_mirror) and typeof(text) == TYPE_STRING:
		_mirror.show_pick_note(text, waiting == true)


## The joiner: the two picks differed - choose again.
@rpc("authority", "reliable")
func _pick_again(text):
	if follows() and _mirror != null and is_instance_valid(_mirror) and typeof(text) == TYPE_STRING:
		_mirror.choose_again(text)


@rpc("authority", "reliable")
func _line(character, text, answers, starter):
	if not follows() or typeof(character) != TYPE_STRING or typeof(text) != TYPE_STRING \
			or typeof(answers) != TYPE_ARRAY or typeof(starter) != TYPE_INT:
		return
	var shown := []
	for answer in answers:
		if answer is Array and answer.size() == 2 and typeof(answer[0]) == TYPE_STRING:
			shown.append([answer[0], bool(answer[1])])
	if _mirror == null or not is_instance_valid(_mirror):
		_mirror = ConversationMirror.new()
		get_tree().root.add_child(_mirror)
	_mirror.show_line(character, text, shown, Coop.is_local(starter))
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


## On the joiner: pressed on (`choice` -1) - whoever began it - or picked the
## `choice`th answer (ConversationMirror).
func answer_line(choice: int):
	if follows():
		_converse.rpc_id(1, choice)


@rpc("any_peer", "reliable")
func _converse(choice):
	if not is_host() or typeof(choice) != TYPE_INT or _balloon == null or not is_instance_valid(_balloon):
		return
	var sender := multiplayer.get_remote_sender_id()
	var from := -1
	for each in Coop.players:
		if each.peer == sender:
			from = each.id
	if from < 0:
		return
	if choice < 0:
		# Pressing on: only the machine of whoever began it.
		if from == _starter:
			_balloon.advance_from_afar()
		return
	var line = _balloon.dialogue_line
	if line == null or choice >= line.responses.size() or not line.responses[choice].is_allowed:
		return
	_picks[from] = choice
	_settle_picks()


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
	_say_where_the_familiar_is(scene, now)


## Alithia's familiar (FamiliarKeeper): the host says how it stands whenever
## that changes, and every WALK_ANYWAY_SECONDS; whichever machine's player
## steers it says where they walk it.
var _familiar_said := ""
var _familiar_said_at := 0


func _say_where_the_familiar_is(scene: ExplorationScene, now: int):
	var keeper: FamiliarKeeper = scene.familiar_keeper
	if keeper == null:
		return
	if is_host():
		var state := keeper.net_state()
		var text := var_to_str(state)
		if text == _familiar_said and now - _familiar_said_at < WALK_ANYWAY_SECONDS * 1000.0:
			return
		_familiar_said = text
		_familiar_said_at = now
		_familiar_is.rpc(state)
	elif keeper.familiar != null and keeper.controlling and keeper.steerer >= 0 and Coop.is_local(keeper.steerer) \
			and not keeper.familiar.puppet:
		_familiar_walked.rpc_id(1, keeper.steerer, keeper.familiar.global_position, keeper.familiar._facing_left)


@rpc("authority", "unreliable_ordered")
func _familiar_is(state):
	var scene := _map()
	if follows() and typeof(state) == TYPE_DICTIONARY and scene != null and scene.familiar_keeper != null \
			and not SceneTransition.is_changing():
		scene.familiar_keeper.apply_net_state(state)


@rpc("any_peer", "unreliable_ordered")
func _familiar_walked(id, at, facing_left):
	if not is_host() or typeof(id) != TYPE_INT or typeof(at) != TYPE_VECTOR2 or typeof(facing_left) != TYPE_BOOL:
		return
	var scene := _map()
	if scene == null or scene.familiar_keeper == null or not _sent_by_whoever_plays(id):
		return
	var keeper: FamiliarKeeper = scene.familiar_keeper
	# Only theirs while they steer it - and only where it can be.
	if keeper.familiar == null or not keeper.controlling or keeper.steerer != id or not keeper.familiar.can_be_at(at):
		return
	keeper.familiar.puppet_to(at, facing_left)


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
				_press.rpc_id(1, player, {"kind": "action", "action": String(action), "pointed": _pointed_here()})
				pressed = true
		return pressed
	var data := _press_data(event)
	if data.is_empty():
		return false
	# What its pointer is on here, for whatever the press asks of a pointer there.
	data["pointed"] = _pointed_here()
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
	_pointing[id] = str(data.get("pointed", ""))
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


## On a joiner: player `key`'s `move`, used on the host (OutsideMoves.use) -
## at the guard this machine's pointer is on, if it is on one.
func use_move(key: String, move: String):
	if follows():
		_use_move.rpc_id(1, key, move, _pointed_here())


@rpc("any_peer", "reliable")
func _use_move(key, move, pointed):
	if not is_host() or typeof(key) != TYPE_STRING or typeof(move) != TYPE_STRING or typeof(pointed) != TYPE_STRING:
		return
	var id := Coop.controller_of(key)
	var scene := _map()
	if scene == null or not _sent_by_whoever_plays(id):
		return
	var before := Coop.acting
	Coop.acting = id
	_pointing[id] = pointed
	OutsideMoves.use(scene, key, move)
	Coop.acting = before


## --- Aimed, and chosen, on the joiner's own screen ---
##
## What is pointed at with the pointer on a map - where a throw lands, a click
## on a guard, which way a readied cone points, the guard a move is used on -
## and what is chosen in a little menu (who goes unseen, which spell the Outside
## Spell key casts, the familiar called or let go) is the joiner's player's
## to do on their own screen, against the host's guards as they are shown
## there. Only what it comes to is sent (do_on_host), with the guard their
## pointer is on, and done on the host as their player; anything a press there
## asks of the pointer reads theirs (pointing_afar, pointed_guard), never this
## machine's own.

## What may be done on the host this way.
const DONE_AFAR := ["throw", "click", "ready", "invisible", "summon_familiar", "dismiss_familiar"]

## The host: the guard each other machine's player last pointed at, by player.
var _pointing := {}


## On a joiner: `what` (one of DONE_AFAR) with `args`, done on the host as this
## machine's player.
func do_on_host(what: String, args: Array):
	var mine := Coop.local_players()
	if follows() and not mine.is_empty() and DONE_AFAR.has(what):
		var id: int = Coop.acting if Coop.acting != Coop.ANYONE and Coop.is_local(Coop.acting) else mine[0]
		_done_afar.rpc_id(1, id, what, args, _pointed_here())


## The guard this machine's pointer is on, on a watched map, as the host knows
## him - or "".
func _pointed_here() -> String:
	var scene := _map()
	if scene == null or scene.stealth == null or not is_instance_valid(scene.stealth):
		return ""
	var guard = scene.stealth._hovered
	return scene.stealth._id_of(guard) if guard != null and is_instance_valid(guard) else ""


## On the host: whether the press or the doing being handled is another
## machine's player's - so that what it asks of the pointer is theirs.
func pointing_afar() -> bool:
	return is_host() and Coop.acting != Coop.ANYONE and Coop.acting < Coop.players.size() and not Coop.is_local(Coop.acting)


## The guard on `watch`'s map that the player whose press this is pointed at on
## their machine, or null.
func pointed_guard(watch) -> Guard:
	var id := str(_pointing.get(Coop.acting, ""))
	if id == "" or watch == null:
		return null
	for guard in watch.guards:
		if is_instance_valid(guard) and watch._id_of(guard) == id:
			return guard
	return null


@rpc("any_peer", "reliable")
func _done_afar(id, what, args, pointed):
	if not is_host() or typeof(id) != TYPE_INT or typeof(what) != TYPE_STRING or not DONE_AFAR.has(what) \
			or typeof(args) != TYPE_ARRAY or typeof(pointed) != TYPE_STRING or not is_plain(args):
		return
	var scene := _map()
	if scene == null or not _sent_by_whoever_plays(id):
		return
	var watch = scene.stealth if scene.stealth != null and is_instance_valid(scene.stealth) else null
	var before := Coop.acting
	Coop.acting = id
	_pointing[id] = pointed
	match what:
		"throw":
			if watch != null and args.size() == 2 and typeof(args[0]) == TYPE_STRING and typeof(args[1]) == TYPE_VECTOR2I \
					and watch.throwables().has(args[0]):
				watch._aiming = args[0]
				if not watch.throw_at(args[1]):
					watch._aiming = ""
		"click":
			if watch != null and args.size() == 2 and typeof(args[0]) == TYPE_BOOL and typeof(args[1]) == TYPE_VECTOR2I:
				watch.click_at(args[1], args[0])
		"ready":
			if watch != null and args.size() == 5 and typeof(args[0]) == TYPE_STRING and typeof(args[1]) == TYPE_STRING \
					and typeof(args[2]) == TYPE_INT and typeof(args[3]) == TYPE_VECTOR2I and typeof(args[4]) == TYPE_STRING \
					and Coop.controller_of(args[0]) == id:
				var watched: Guard = null
				for guard in watch.guards:
					if is_instance_valid(guard) and watch._id_of(guard) == args[4]:
						watched = guard
				watch.ready_outside(args[0], args[1], args[2], args[3], watched)
		"invisible":
			if watch != null and args.size() == 1 and args[0] is Array:
				watch.go_invisible(args[0].filter(func(key): return typeof(key) == TYPE_STRING))
		"summon_familiar":
			scene.summon_familiar()
		"dismiss_familiar":
			if scene.familiar_keeper != null and scene.familiar_keeper.may_dismiss(id):
				scene.dismiss_familiar()
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
			Campaign.apply(_state_held, _kept_here())
			_state_held = null
		# Out of the fight: who steers whom is the host's table's again.
		if _controllers_after_fight != null and not in_a_shared_fight() and not _fight_coming:
			Campaign.controllers = _controllers_after_fight
			_controllers_after_fight = null
			Coop.players_changed.emit()
		_offer_the_choice()
		_keep_catching_up()
	if with_another():
		_say_where(delta)
		_stand_for_menus()
		_play_moves()
	if is_host() and not _seated_peers().is_empty():
		_say_how_it_stands(delta)
		if not _steering_due.is_empty():
			if in_a_shared_fight():
				_steer_when_both_can()
			else:
				# The fight over with changes still waiting: made now.
				var due := _steering_due.duplicate()
				_steering_due.clear()
				_change_steering(due)
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
