extends Node
## The party can actually walk when exploration opens - on the configured map,
## and on any map that forgot to say where the party arrives.

var LOG_PATH := HarnessLog.path_for("walk")

var _log: FileAccess = null
var _fail = 0


func log_line(t: String):
	if _log:
		_log.store_line(t)
		_log.flush()


func ok(condition: bool, label: String, detail: String = ""):
	if condition:
		log_line("  PASS  %s %s" % [label, detail])
	else:
		_fail += 1
		log_line("  FAIL  %s %s" % [label, detail])


func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(120.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


## Boots exploration on `map` (empty for whatever it is configured with) and
## hands back the scene once the party is standing.
func open_exploration(map: String) -> Node:
	Campaign.reset()
	Campaign.current_map = map
	var scene = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(scene)
	for frame in range(0, 8):
		await get_tree().process_frame
	return scene


func party_of(scene: Node):
	for child in scene.get_children():
		if child is ExplorationParty:
			return child
	return null


## Every direction the party could actually take a step in from where it is.
func open_directions(party) -> int:
	var here = party.leader.position
	var count = 0
	for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		if party._can_stand(here + direction * 8.0):
			count += 1
	return count


func run_test():
	log_line("======== the configured map ========")
	var scene = await open_exploration("")
	var party = party_of(scene)
	ok(party != null, "a party exists")
	ok(party != null and party.leader != null, "with somebody leading it")
	ok(party != null and not party.frozen, "and it is not frozen")
	if party != null and party.leader != null:
		var here = party.leader.position
		ok(party._can_stand(here), "it starts on ground it can stand on", "%s" % here)
		ok(open_directions(party) == 4, "and can step in every direction",
			"%d of 4 open" % open_directions(party))
		# Walking is read straight off the keyboard in _process, so drive the
		# same function the game does rather than faking an input event.
		var before = party.leader.position
		party.leader.position = before + Vector2(64, 0)
		ok(party.leader.position != before, "moving the leader takes effect")
		party.leader.position = before
	log_line("")
	scene.queue_free()
	await get_tree().process_frame

	log_line("======== a map that never says where to arrive ========")
	# The battle map is not an exploration map and has no EntryPoint. It used to
	# put the party at the origin, which on a map whose painted area does not
	# reach the origin means sealed in the void with nowhere to step.
	var battle_map = await open_exploration("res://scenes/terrain.tscn")
	var stranded = party_of(battle_map)
	ok(stranded != null and stranded.leader != null, "a party is still built")
	if stranded != null and stranded.leader != null:
		var here = stranded.leader.position
		ok(here != Vector2.ZERO, "it does not fall back to the origin", "%s" % here)
		ok(stranded._can_stand(here), "it lands on ground it can stand on", "%s" % here)
		ok(open_directions(stranded) > 0, "and is not boxed in",
			"%d of 4 open" % open_directions(stranded))
	log_line("")
	battle_map.queue_free()
	await get_tree().process_frame

	log_line("======== exploration is pointed at an exploration map ========")
	var configured = load("res://scenes/exploration.tscn").instantiate()
	var default_map = configured.default_map
	ok(default_map.contains("explore"), "the default map is an exploration one", default_map)
	var map_scene = load(default_map)
	ok(map_scene != null, "and it loads")
	var instance = map_scene.instantiate()
	var entries = 0
	for child in instance.get_children():
		if child.get_script() != null and "entry_name" in child:
			entries += 1
	ok(entries > 0, "and it says where the party arrives", "%d entry point(s)" % entries)
	instance.queue_free()
	configured.queue_free()
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
