extends "res://StealthHarness.gd"
## Network play (Net; docs/multiplayer_plan.md Step 2). Two machines are two
## Godots on this one: this one hosts, and starts a second, headless, that plays
## the joiner's half (`--net-client`) and writes its own log - copied into this
## one's at the end, its FAILs counted with these, and its Godot's own output
## read for script errors. The two talk over 127.0.0.1 on ports of their own, so
## a game being played on this machine is left alone, and the beacon goes to
## 127.0.0.1 rather than out over the network.
##
## - the Players panel's network half, which listens for nothing until asked
## - hosting: the host's player is seated on peer 1; another version, another
##   build, an empty hello and a full table are turned away
## - resources as data: an encounter made on the spot goes as data and comes
##   back the same, one from a file goes as its file, and nothing but the game's
##   own data scripts is ever made from what arrives
## - finding and joining while the host is on a map: the joiner hears the
##   beacon, is seated as the second player on its own machine with the same
##   table, and comes straight onto the host's map, its group its own
## - Campaign followed: gold and a flag set on the host reach the joiner
## - the joiner will not change scene by itself, and follows the host's reload
## - whom to steer, picked on the joiner, is the host's to set
## - the joiner leaving takes its player with it, its characters go back, and
##   it is sent to the title screen; joining again it comes back onto the map;
##   the host leaving sends it to the title screen too

const TEST_PORT := 24790
const TEST_BEACON := 24791
## A stealth stage with guards, doors and lamps to watch over.
const STAGE := "res://maps/stealth_stages/stealth_5.tscn"

var _joiner_pid := -1
## What the other machine has said (say).
var _heard: Array = []


func suite() -> String:
	return "net_joiner" if joining_half() else "net"


func time_limit() -> float:
	return 260.0


static func joining_half() -> bool:
	return OS.get_cmdline_user_args().has("--net-client")


func run_sections():
	# The fight the harness starts in is not wanted by either half.
	if get_tree().current_scene != null:
		get_tree().current_scene.queue_free()
	await settle()
	Coop.reset()
	Campaign.controllers.clear()
	Net.discovery_port = TEST_BEACON
	Net.beacon_to = "127.0.0.1"
	if joining_half():
		await joiners_half()
	else:
		await hosts_half()


## --- Between the two machines ---


## A word to the other machine: how far this half has got, for it to wait on.
func say(what: String):
	if multiplayer.has_multiplayer_peer() and Net.active():
		_say.rpc(what)


@rpc("any_peer", "reliable")
func _say(what):
	_heard.append(str(what))


## Until the other machine has said `what`.
func hear(what: String, seconds: float = 20.0) -> bool:
	return await until(func(): return _heard.has(what), seconds)


## What the other machine said that begins with `start`, without it - or "".
func heard_after(start: String) -> String:
	for line in _heard:
		if line.begins_with(start):
			return line.trim_prefix(start)
	return ""


## The guard on `watch`'s map known as `id`, or null.
func guard_called(watch: StealthWatch, id: String) -> Guard:
	return thing_called(watch, watch.guards, id)


func thing_called(watch: StealthWatch, things: Array, id: String):
	for thing in things:
		if is_instance_valid(thing) and watch._id_of(thing) == id:
			return thing
	return null


## A key going down, from this machine's keyboard.
func key_event(physical: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = physical
	event.keycode = physical
	event.pressed = true
	return event


## Until this machine shows a map, settled.
func on_a_map(seconds: float = 20.0) -> bool:
	return await until(func(): return get_tree().current_scene is ExplorationScene and not SceneTransition.is_changing(), seconds)


func on_the_title_screen(seconds: float = 20.0) -> bool:
	return await until(func(): return get_tree().current_scene != null \
		and get_tree().current_scene.scene_file_path == Campaign.MAIN_MENU and not SceneTransition.is_changing(), seconds)


## --- The host's half ---


func hosts_half():
	log_line("======== the Players panel's network half ========")
	var panel := PlayersPanel.new()
	get_tree().root.add_child(panel)
	await settle()
	ok(panel.network is NetPanel and panel.network.get_node_or_null("Host") != null and panel.network.get_node_or_null("Look") != null,
		"the Players panel has Host, Look for games and an address to join")
	ok(not Net.looking(), "  and opening it listens for nothing - no firewall question for a game on one screen")
	panel.queue_free()
	await settle()
	Coop.reset()
	log_line("")

	log_line("======== hosting ========")
	ok(Net.host(TEST_PORT, "127.0.0.1") == OK, "hosts a game")
	ok(Net.is_host() and Coop.networked and Coop.local_peer == 1, "  and is the host, on peer 1")
	ok(Coop.players.size() == 1 and Coop.players[0].peer == 1 and Coop.is_local(0),
		"  its own player seated on its own machine", "%s" % [Coop.players])
	ok(Net.refusal_for(Net.PROTOCOL + 1, Net.build_key(), [Coop.KEYBOARD]) != "", "  another version is turned away")
	ok(Net.refusal_for(Net.PROTOCOL, "another build", [Coop.KEYBOARD]) != "", "  and another build")
	ok(Net.refusal_for(Net.PROTOCOL, Net.build_key(), []) != "", "  and a hello naming nothing to play with")
	ok(Net.refusal_for(Net.PROTOCOL, Net.build_key(), [Coop.KEYBOARD]) == "", "  and the same version is let in")
	MenuPause.hold(self)
	ok(get_tree().paused, "hosting with nobody joined yet, a menu holds the game as it always has")
	MenuPause.release(self)
	ok(not get_tree().paused, "  and lets it go")
	log_line("")

	resources_as_data()

	log_line("======== the host on a map ========")
	Campaign.reset()
	Campaign.current_map = MAP
	SceneTransition.change_scene(Campaign.EXPLORATION_SCENE)
	ok(await on_a_map(), "the host walks onto the crossroads")
	var scene: ExplorationScene = get_tree().current_scene
	scene.end_blocking_interaction()
	# Somebody joins on the way - as a conversation would have them - so the
	# party is no longer what the map's arriving made it.
	Campaign.add_member("enfina")
	Campaign.add_member("alithia")
	await settle()
	var party := Array(Campaign.party_order)
	ok(party.size() >= 3, "  with a party to share, two of them joined since arriving", "%s" % [party])
	# All but the first are the joiner's from the moment it is seated - two, so
	# that one of them can stay behind while the other leads.
	for key in party.slice(1):
		Campaign.controllers[key] = 1
	ok(Net.is_plain(Campaign.net_state()), "  and Campaign as it stands is plain data, to send")
	start_joiner()
	log_line("")

	log_line("======== joining a game under way ========")
	ok(await until(func(): return Coop.players.size() == 2, 40.0), "the joiner is seated", "%s" % [Coop.players])
	if Coop.players.size() == 2:
		ok(Coop.players[1].peer > 1 and not Coop.is_local(1) and Coop.is_local(0),
			"  as the second player, on its own machine", "%s" % [Coop.players])
		ok(Net.refusal_for(Net.PROTOCOL, Net.build_key(), [Coop.KEYBOARD]) == "That game is full.",
			"  and with two seated, a third is turned away: the table is full")
	say("party:" + ",".join(party))
	ok(await hear("on the map"), "and it comes straight onto the host's map")
	ok(scene.groups.has(1) and scene.groups[1].puppet and not scene.groups[0].puppet,
		"  here its group is walked from there, and the host's from here", "%s" % [scene.groups.keys()])
	log_line("")

	log_line("======== Campaign followed ========")
	Campaign.gold += 25
	Campaign.set_flag("net_probe")
	say("gold:%d" % Campaign.gold)
	ok(await hear("state followed", 15.0), "gold and a flag set on the host reach the joiner", "%s" % [_heard])
	ok(await hear("stayed"), "the joiner will not change scene by itself")
	log_line("")

	log_line("======== walking together ========")
	var m := {"scene": scene, "tile_map": scene._tile_map, "sight": StealthSight.new(scene._tile_map)}
	var home := tile_at(m, scene._main_party.position_of_leader())
	var theirs := find_tile(m, func(tile): return gap(tile, home) >= 4.0 and gap(tile, home) <= 6.0)
	var mine := find_tile(m, func(tile): return gap(tile, home) >= 2.0 and gap(tile, home) <= 3.0 and gap(tile, theirs) >= 2.0)
	var wall := NOWHERE
	for x in range(home.x - 8, home.x + 8):
		for y in range(home.y - 8, home.y + 8):
			if wall == NOWHERE and not standable(m, Vector2i(x, y)) and gap(Vector2i(x, y), home) >= 2.0:
				wall = Vector2i(x, y)
	say("walk:%d,%d" % [theirs.x, theirs.y])
	ok(await until(func(): return scene.groups.has(1) and scene.groups[1].position_of_leader().distance_to(at(m, theirs)) < Grid.tiles(1.0), 10.0),
		"the joiner's group, walked over there, shows here where it went")
	scene._main_party.teleport(at(m, mine))
	say("host at:%d,%d" % [mine.x, mine.y])
	ok(await hear("saw the host"), "  and the host's, moved here, shows there")
	var joiners_place: Vector2 = scene.groups[1].position_of_leader()
	say("wall:%d,%d" % [wall.x, wall.y])
	ok(await hear("claimed the wall"), "the joiner says its group is in a wall")
	await settle(10)
	ok(wall != NOWHERE and scene.groups[1].position_of_leader().distance_to(at(m, wall)) > Grid.tiles(0.5),
		"  and the host does not put it there", "%s %s" % [wall, joiners_place])
	log_line("")

	log_line("======== a press on the joiner, done here ========")
	var sign := ExamineInteractable.new()
	sign.text = "A notice, nailed up."
	sign.sets_flag = "net_sign_read"
	scene.get_node("Map").add_child(sign)
	sign.global_position = scene.groups[1].leader.global_position
	scene._interactables.append(sign)
	say("sign up")
	ok(await until(func(): return Campaign.flag("net_sign_read"), 10.0),
		"E pressed on the joiner examines what is beside the joiner's group here: its flag is set")
	say("read")
	var joiners_leader: String = Coop.keys_of(1)[0] if not Coop.keys_of(1).is_empty() else ""
	ok(await hear("stayed here"), "Stay Here is pressed on the joiner")
	ok(await until(func(): return scene.staying.has(joiners_leader), 5.0), "  and done here too: their leader stays",
		"%s %s" % [joiners_leader, scene.staying.keys()])
	log_line("")

	log_line("======== pings ========")
	Pings.clear()
	Pings.ping(0, scene._main_party.position_of_leader())
	say("pinged")
	ok(await hear("saw the ping"), "a ping made here shows on the joiner's screen")
	ok(await until(func(): return Pings.pings.any(func(ping): return ping.player == 1), 10.0),
		"  and one made there shows here, the joiner's", "%s" % [Pings.pings])
	log_line("")

	log_line("======== a reload, followed ========")
	# A map coming up again sets its own cast again - Enfina goes, as she would
	# through a door - and does the same on the joiner.
	var before := scene.get_instance_id()
	say("reloading")
	scene.reload_map()
	ok(await until(func(): return get_tree().current_scene is ExplorationScene and get_tree().current_scene.get_instance_id() != before \
		and not SceneTransition.is_changing(), 20.0), "the host reloads the map")
	scene = get_tree().current_scene
	scene.end_blocking_interaction()
	ok(await hear("followed the reload"), "  and the joiner comes too")
	log_line("")

	log_line("======== a menu over a network ========")
	# The map has just offered to share the party out - the joiner steers nobody
	# of it now - and that panel is a menu too. Done with it first.
	for offered in scene.find_children("*", "PlayersPanel", true, false):
		offered.close()
	await settle()
	MenuPause.hold(self)
	await settle()
	ok(not get_tree().paused, "a menu open here stops nothing")
	ok(scene._main_party.in_a_menu and (not scene.groups.has(1) or not scene.groups[1].in_a_menu),
		"  but this machine's own group stands for it, and not the other's")
	MenuPause.release(self)
	await settle()
	ok(not scene._main_party.in_a_menu, "  and walks again once it closes")
	log_line("")

	log_line("======== guards, run by the host ========")
	Campaign.current_map = STAGE
	before = scene.get_instance_id()
	say("to the stage")
	scene.reload_map()
	ok(await until(func(): return get_tree().current_scene is ExplorationScene and get_tree().current_scene.get_instance_id() != before \
		and not SceneTransition.is_changing(), 20.0), "the host goes on to a watched map, a stealth stage")
	scene = get_tree().current_scene
	scene.end_blocking_interaction()
	var watch: StealthWatch = scene.stealth
	ok(watch != null and not watch.puppet and watch.guards.size() >= 2,
		"  where the host's watch decides, over its guards", "%d" % (watch.guards.size() if watch != null else 0))
	ok(await hear("on the stage"), "  and the joiner comes too")
	if watch != null and watch.guards.size() >= 2:
		# Everybody held, so that nothing moves but what is moved here.
		for group in scene.all_groups():
			group.frozen = true
		await settle()
		var guard: Guard = watch.guards[0]
		var spot := guard.global_position + Vector2(Grid.tiles(1.0), 0.0)
		guard.global_position = spot
		guard.facing = Vector2.LEFT
		say("guard:%s|%d,%d" % [watch._id_of(guard), int(spot.x), int(spot.y)])
		ok(await hear("guard followed"), "a guard moved here stands there, facing the same way")
		var door: StealthDoor = watch._doors[0] if not watch._doors.is_empty() else null
		if door != null:
			door.set_open(not door.is_open)
			watch._apply_door(door)
			say("door:%s|%s" % [watch._id_of(door), "open" if door.is_open else "shut"])
			ok(await hear("door followed"), "a door opened or shut here is so there")
		var lamp: Lamp = null
		for each in watch._lamps:
			if lamp == null and each.lit and each.can_be_put_out:
				lamp = each
		if lamp != null:
			watch.put_out(lamp)
			say("lamp:%s" % watch._id_of(lamp))
			ok(await hear("lamp followed"), "a lamp put out here is out there")
		watch.alert = 0.6
		watch.suspicion[guard] = 0.7
		say("alert:%s" % watch._id_of(guard))
		ok(await hear("alert followed"), "the alert, and how sure a guard is, are the same there")
		var other: Guard = watch.guards[1]
		other.knock_out()
		say("out:%s" % watch._id_of(other))
		ok(await hear("out followed"), "a guard knocked out here is down there")
		for group in scene.all_groups():
			group.frozen = false
	log_line("")

	log_line("======== whom to steer ========")
	var spare := ""
	for key in PlayersPanel.characters():
		if not party.has(key):
			spare = key
			break
	say("spare:" + spare)
	ok(await until(func(): return Coop.controller_of(spare) == 1, 15.0),
		"the joiner asks to steer %s, and the host makes it so" % spare, "%s" % [Campaign.controllers])
	say("steered")
	ok(await hear("table agrees"), "  and the joiner's table says the same", "%s" % [_heard])
	log_line("")

	log_line("======== leaving ========")
	say("leave")
	ok(await until(func(): return Coop.players.size() == 1, 15.0), "the joiner leaving takes its player with it",
		"%s" % [Coop.players])
	ok(party.size() < 2 or (Coop.controller_of(party[1]) == 0 and not Campaign.controllers.has(party[1])),
		"  and its characters are the host's player's again", "%s" % [Campaign.controllers])
	ok(Net.is_host() and get_tree().current_scene is ExplorationScene, "  while the host hosts on, on its map")
	ok(await until(func(): return Coop.players.size() == 2, 40.0), "the joiner joins again", "%s" % [Coop.players])
	ok(await hear("back on the map"), "  and comes back onto the map")
	Net.leave()
	ok(not Net.active() and not Coop.networked and Coop.players.size() == 1 and Coop.players[0].peer == 0,
		"stopping, the host plays on alone", "%s" % [Coop.players])
	ok(get_tree().current_scene is ExplorationScene, "  on its map")
	log_line("")
	await joiner_finished()


func resources_as_data():
	log_line("======== resources as data ========")
	var fight := EncounterDefinition.new()
	fight.display_name = "Caught at the crossroads"
	fight.terrain_scene = load(TERRAIN)
	var spawn := SpawnDefinition.new()
	spawn.combatant_key = "barbarian"
	spawn.side = 1
	spawn.position = Vector2i(4, 5)
	fight.spawns.append(spawn)
	fight.set_meta("seed", 4242)
	var data = Net.resource_to_data(fight)
	ok(Net.is_plain(data), "an encounter made on the spot goes as plain data")
	var back := Net.data_to_resource(data) as EncounterDefinition
	ok(back != null and back.display_name == fight.display_name and back.terrain_scene == fight.terrain_scene
		and back.spawns.size() == 1 and back.spawns[0].combatant_key == "barbarian" and back.spawns[0].side == 1
		and back.spawns[0].position == Vector2i(4, 5) and back.get_meta("seed", 0) == 4242,
		"  and comes back the same: its name, its map, who stands where, its seed")
	var from_file: EncounterDefinition = load("res://data/encounters/encounter_02_sappers.tres")
	ok(Net.data_to_resource(Net.resource_to_data(from_file)) == from_file, "  one from a file goes as its file")
	ok(Net.data_to_resource({"script": "res://multiplayer/Net.gd", "props": {}, "meta": {}}) == null
		and Net.data_to_resource({"script": "res://campaign/Campaign.gd", "props": {}, "meta": {}}) == null
		and Net.data_to_resource({"path": "user://anything.tres", "meta": {}}) == null,
		"  and nothing but the game's own data is ever made from what arrives")
	log_line("")


## Starts the second Godot, on this same copy of the project, to join.
func start_joiner():
	DirAccess.remove_absolute(HarnessLog.path_for("net_joiner"))
	var args := ["--headless", "--path", ProjectSettings.globalize_path("res://")]
	var dir := OS.get_environment("MOT_TEST_LOG_DIR")
	if dir != "":
		DirAccess.remove_absolute(dir.path_join("net_joiner_godot.log"))
		args += ["--log-file", dir.path_join("net_joiner_godot.log")]
	args += ["--", "--net-client"]
	_joiner_pid = OS.create_process(OS.get_executable_path(), args)
	ok(_joiner_pid > 0, "starts a second Godot to join it", "pid %d" % _joiner_pid)


## Waits for the joiner's Godot to end, then copies its log into this one.
func joiner_finished():
	if _joiner_pid <= 0:
		return
	var ended := await until(func(): return not OS.is_process_running(_joiner_pid), 40.0)
	if not ended:
		OS.kill(_joiner_pid)
	ok(ended, "the joiner's Godot finished by itself")
	log_line("======== the joiner's half, from its own log ========")
	var text := FileAccess.get_file_as_string(HarnessLog.path_for("net_joiner"))
	ok(text.contains("FAILURES: 0"), "the joiner's half came through", "" if text != "" else "(no log)")
	for line in text.split("\n"):
		if line.strip_edges() == "" or line.begins_with("FAILURES:"):
			continue
		if line.contains("  FAIL  "):
			_fail += 1
		log_line("  | " + line)
	var dir := OS.get_environment("MOT_TEST_LOG_DIR")
	if dir != "":
		var errors := []
		for line in FileAccess.get_file_as_string(dir.path_join("net_joiner_godot.log")).split("\n"):
			if line.contains("SCRIPT ERROR"):
				errors.append(line.strip_edges())
		ok(errors.is_empty(), "and its Godot had no script errors", "%s" % [errors])
	log_line("")


## --- The joiner's half ---


func joiners_half():
	log_line("======== finding the host ========")
	ok(Net.look_for_games("127.0.0.1") == OK, "listens for games on the network")
	ok(await until(func(): return not Net.found.is_empty(), 20.0), "hears the host's beacon", "%s" % [Net.found])
	var game: Dictionary = Net.found.values()[0] if not Net.found.is_empty() else {}
	ok(game.get("port", 0) == TEST_PORT and game.get("protocol", -1) == Net.PROTOCOL and game.get("address", "") == "127.0.0.1",
		"  which says where it is, its port and its version", "%s" % [game])
	log_line("")

	log_line("======== joining a game under way ========")
	ok(Net.join(game.get("address", "127.0.0.1"), game.get("port", TEST_PORT)) == OK, "joins it")
	ok(await until(func(): return Net.joined(), 20.0), "  and is seated")
	ok(Coop.networked and Coop.players.size() == 2 and Coop.is_local(1) and not Coop.is_local(0),
		"  as the second player, the first on the host's machine", "%s, this machine %d" % [Coop.players, Coop.local_peer])
	ok(not Net.looking(), "  and has stopped listening")
	ok(await on_a_map(), "comes straight onto the host's map")
	await until(func(): return heard_after("party:") != "", 10.0)
	var party := heard_after("party:").split(",")
	ok(Campaign.current_map == MAP and Array(Campaign.party_order) == Array(party),
		"  the crossroads, with the host's party", "%s %s" % [Campaign.current_map, Campaign.party_order])
	var scene: ExplorationScene = get_tree().current_scene
	ok(party.size() >= 2 and Coop.controller_of(party[1]) == 1 and scene.groups.has(1) and not scene.groups[1].puppet
		and scene.groups.has(0) and scene.groups[0].puppet,
		"  its own group walked here, the host's from there", "%s" % [scene.groups.keys()])
	say("on the map")
	log_line("")

	log_line("======== Campaign followed ========")
	await until(func(): return heard_after("gold:") != "", 10.0)
	var gold := int(heard_after("gold:"))
	ok(await until(func(): return Campaign.gold == gold and Campaign.flag("net_probe"), 10.0),
		"gold and a flag set on the host arrive", "%d of %d" % [Campaign.gold, gold])
	if Campaign.gold == gold and Campaign.flag("net_probe"):
		say("state followed")
	SceneTransition.change_scene(Campaign.MAIN_MENU)
	await settle(20)
	ok(get_tree().current_scene == scene and not SceneTransition.is_changing(), "asked to change scene by itself, it stays")
	say("stayed")
	log_line("")

	log_line("======== walking together ========")
	var m := {"scene": scene, "tile_map": scene._tile_map, "sight": StealthSight.new(scene._tile_map)}
	await until(func(): return heard_after("walk:") != "", 10.0)
	var going := Vector2i(int(heard_after("walk:").get_slice(",", 0)), int(heard_after("walk:").get_slice(",", 1)))
	var mine: ExplorationParty = scene.groups.get(1)
	ok(mine != null and not mine.puppet, "its own group, walked here")
	if mine != null:
		mine.teleport(at(m, going))
	say("walked")
	await until(func(): return heard_after("host at:") != "", 10.0)
	var hosts := Vector2i(int(heard_after("host at:").get_slice(",", 0)), int(heard_after("host at:").get_slice(",", 1)))
	ok(await until(func(): return scene.groups.has(0) and scene.groups[0].position_of_leader().distance_to(at(m, hosts)) < Grid.tiles(1.0), 10.0),
		"the host's group, moved there, shows here where it went")
	say("saw the host")
	await until(func(): return heard_after("wall:") != "", 10.0)
	var wall := Vector2i(int(heard_after("wall:").get_slice(",", 0)), int(heard_after("wall:").get_slice(",", 1)))
	Net._walked.rpc_id(1, 1, at(m, wall), false, false)
	say("claimed the wall")
	log_line("")

	log_line("======== a press on the joiner, done on the host ========")
	await hear("sign up")
	# The same notice here, to see that nothing here is the one examined.
	var sign := ExamineInteractable.new()
	sign.text = "A notice, nailed up."
	scene.get_node("Map").add_child(sign)
	sign.global_position = mine.leader.global_position
	scene._interactables.append(sign)
	get_viewport().push_input(key_event(KEY_E))
	ok(await until(func(): return Campaign.flag("net_sign_read"), 10.0),
		"E pressed here is done on the host - the flag the notice there leaves arrives")
	ok(not sign.contact_spent, "  and nothing here is examined")
	await hear("read")
	var leader: String = Coop.keys_of(1)[0] if not Coop.keys_of(1).is_empty() else ""
	get_viewport().push_input(key_event(KEY_X))
	await settle()
	ok(scene.staying.has(leader), "Stay Here pressed here is done here", "%s %s" % [leader, scene.staying.keys()])
	say("stayed here")
	log_line("")

	log_line("======== pings ========")
	await hear("pinged")
	ok(await until(func(): return Pings.pings.any(func(ping): return ping.player == 0), 10.0),
		"the host's ping shows here, the host's", "%s" % [Pings.pings])
	say("saw the ping")
	# The group as it is now: staying rebuilt the line.
	Pings.ping(1, scene.groups[1].position_of_leader() if scene.groups.has(1) else Vector2.ZERO)
	log_line("")

	log_line("======== a reload, followed ========")
	await hear("reloading")
	ok(await until(func(): return get_tree().current_scene is ExplorationScene and get_tree().current_scene != scene \
		and not SceneTransition.is_changing(), 20.0), "follows the host through a reload of the map")
	scene = get_tree().current_scene
	say("followed the reload")
	log_line("")

	log_line("======== guards, run by the host ========")
	await hear("to the stage")
	ok(await until(func(): return get_tree().current_scene is ExplorationScene and get_tree().current_scene != scene \
		and not SceneTransition.is_changing(), 20.0) and Campaign.current_map == STAGE, "follows the host onto a watched map")
	scene = get_tree().current_scene
	var watch: StealthWatch = scene.stealth
	ok(watch != null and watch.puppet and watch.guards.all(func(guard): return guard.puppet),
		"  its watch only shows the host's, and so does every guard on it")
	MenuPause.hold(self)
	await settle()
	ok(not get_tree().paused, "a menu open here stops nothing - the guards go on")
	MenuPause.release(self)
	say("on the stage")
	if watch == null:
		return
	await until(func(): return heard_after("guard:") != "", 15.0)
	var guard := guard_called(watch, heard_after("guard:").get_slice("|", 0))
	var spot := Vector2(float(heard_after("guard:").get_slice("|", 1).get_slice(",", 0)), float(heard_after("guard:").get_slice("|", 1).get_slice(",", 1)))
	ok(guard != null and await until(func(): return guard.global_position.distance_to(spot) < 2.0 and guard.facing.x < 0.0, 10.0),
		"a guard the host moved stands here where it does, facing the same way", "%s at %s" % [guard, guard.global_position if guard != null else Vector2.ZERO])
	say("guard followed")
	if await until(func(): return heard_after("door:") != "", 10.0):
		var door: StealthDoor = thing_called(watch, watch._doors, heard_after("door:").get_slice("|", 0))
		var wanted := heard_after("door:").get_slice("|", 1) == "open"
		ok(door != null and await until(func(): return door.is_open == wanted, 10.0), "a door the host opened or shut is so here", "%s" % wanted)
		say("door followed")
	if await until(func(): return heard_after("lamp:") != "", 10.0):
		var lamp: Lamp = thing_called(watch, watch._lamps, heard_after("lamp:"))
		ok(lamp != null and await until(func(): return not lamp.lit, 10.0), "a lamp the host put out is out here")
		say("lamp followed")
	await until(func(): return heard_after("alert:") != "", 10.0)
	ok(await until(func(): return absf(watch.alert - 0.6) < 0.01 and guard != null and absf(watch.suspicion.get(guard, 0.0) - 0.7) < 0.01, 10.0),
		"the host's alert, and how sure its guard is, are the same here", "%.2f %.2f" % [watch.alert, watch.suspicion.get(guard, 0.0)])
	say("alert followed")
	await until(func(): return heard_after("out:") != "", 10.0)
	var other := guard_called(watch, heard_after("out:"))
	ok(other != null and await until(func(): return other.knocked_out, 10.0), "a guard the host knocked out is down here")
	say("out followed")
	log_line("")

	log_line("======== whom to steer ========")
	await until(func(): return heard_after("spare:") != "", 10.0)
	var spare := heard_after("spare:")
	Net.ask_to_steer(spare, 1)
	ok(await until(func(): return Coop.controller_of(spare) == 1, 10.0),
		"asks to steer %s, and the host's table says it does" % spare, "%s" % [Campaign.controllers])
	await hear("steered")
	say("table agrees" if Coop.controller_of(spare) == 1 else "table disagrees")
	log_line("")

	log_line("======== leaving ========")
	ok(await hear("leave"), "the host says to leave")
	Net.leave()
	ok(not Net.active() and not Coop.networked and Coop.players.size() == 1 and Coop.is_local(0) and Campaign.controllers.is_empty(),
		"left, it plays on alone: one player, here, steering everybody", "%s %s" % [Coop.players, Campaign.controllers])
	ok(await on_the_title_screen(), "  and, out of the host's story, is on the title screen")
	ok(Net.join("127.0.0.1", TEST_PORT) == OK and await until(func(): return Net.joined(), 20.0), "joins again")
	ok(await on_a_map(), "  and is back on the host's map")
	say("back on the map")
	ok(await until(func(): return not Net.active(), 20.0), "the host leaves")
	ok(await on_the_title_screen(), "  and that sends it to the title screen")
	log_line("")
