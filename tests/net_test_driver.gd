extends "res://StealthHarness.gd"
## Network play (Net; docs/multiplayer_plan.md Step 2). Two machines are two
## Godots on this one: this one hosts, and starts a second, headless, that plays
## the joiner's half (`--net-client`) and writes its own log - copied into this
## one's at the end, its FAILs counted with these, and its Godot's own output
## read for script errors. The two talk over 127.0.0.1 on ports of their own, so
## a game being played on this machine is left alone, and the beacon goes to
## 127.0.0.1 rather than out over the network.
##
## - hosting: the host's player is seated on peer 1; another version, another
##   build, an empty hello and a full table are turned away
## - finding and joining: the joiner hears the beacon, joins, and is seated as
##   the second player, on its own machine, with the same table as the host
## - whom to steer, picked on the joiner, is the host's to set, and both say so
## - the joiner leaving takes its player with it and its characters go back;
##   on its own again it plays everybody, and so does the host once it stops

const TEST_PORT := 24790
const TEST_BEACON := 24791

var _joiner_pid := -1
## What the other machine has said (say).
var _heard: Array = []


func suite() -> String:
	return "net_joiner" if joining_half() else "net"


func time_limit() -> float:
	return 200.0


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
	start_joiner()
	log_line("")

	log_line("======== joining ========")
	ok(await until(func(): return Coop.players.size() == 2, 40.0), "the joiner is seated", "%s" % [Coop.players])
	if Coop.players.size() == 2:
		ok(Coop.players[1].peer > 1 and not Coop.is_local(1) and Coop.is_local(0),
			"  as the second player, on its own machine", "%s" % [Coop.players])
		ok(Net.refusal_for(Net.PROTOCOL, Net.build_key(), [Coop.KEYBOARD]) == "That game is full.",
			"  and with two seated, a third is turned away: the table is full")
	say("seated")
	ok(await hear("steering"), "the joiner asks to steer Cyrus")
	ok(await until(func(): return Coop.controller_of("cyrus") == 1, 10.0),
		"  and the host makes it so", "%s" % [Campaign.controllers])
	say("steered")
	ok(await hear("table agrees"), "  and the joiner's table says the same", "%s" % [_heard])
	log_line("")

	log_line("======== leaving ========")
	say("leave")
	ok(await until(func(): return Coop.players.size() == 1, 15.0), "the joiner leaving takes its player with it",
		"%s" % [Coop.players])
	ok(Coop.controller_of("cyrus") == 0 and not Campaign.controllers.has("cyrus"),
		"  and Cyrus is the host's player's again", "%s" % [Campaign.controllers])
	ok(Net.is_host(), "  while the host hosts on")
	Net.leave()
	ok(not Net.active() and not Coop.networked and Coop.players.size() == 1 and Coop.players[0].peer == 0,
		"stopping, the host plays on alone", "%s" % [Coop.players])
	log_line("")
	await joiner_finished()


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

	log_line("======== joining ========")
	ok(Net.join(game.get("address", "127.0.0.1"), game.get("port", TEST_PORT)) == OK, "joins it")
	ok(await until(func(): return Net.joined(), 20.0), "  and is seated")
	ok(Coop.networked and Coop.players.size() == 2 and Coop.is_local(1) and not Coop.is_local(0),
		"  as the second player, the first on the host's machine", "%s, this machine %d" % [Coop.players, Coop.local_peer])
	ok(not Net.looking(), "  and has stopped listening")
	ok(await hear("seated"), "the host says it is seated too")
	Net.ask_to_steer("cyrus", 1)
	say("steering")
	ok(await until(func(): return Coop.controller_of("cyrus") == 1, 10.0),
		"asks to steer Cyrus, and the host's table says it does", "%s" % [Campaign.controllers])
	await hear("steered")
	say("table agrees" if Coop.controller_of("cyrus") == 1 else "table disagrees")
	log_line("")

	log_line("======== leaving ========")
	ok(await hear("leave"), "the host says to leave")
	Net.leave()
	ok(not Net.active() and not Coop.networked and Coop.players.size() == 1 and Coop.is_local(0) and Campaign.controllers.is_empty(),
		"left, it plays on alone: one player, here, steering everybody", "%s %s" % [Coop.players, Campaign.controllers])
	log_line("")
