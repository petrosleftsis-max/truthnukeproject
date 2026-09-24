extends Node
## Headless test for exploration mode: map loading, walking, collision,
## followers, interactables, and the battle hand-off in both directions.

var LOG_PATH := HarnessLog.path_for("explore")
# The multi-member exploration map. Followers, dimmed portraits and passing
# the lead all need more than one person, and the crossroads is deliberately
# Cyrus on his own (see its MapSetup).
const MAP = "res://skills/laboratory_terrain_explore.tscn"

var _log: FileAccess = null
var _fail = 0
var _scene: Node = null


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
	get_tree().create_timer(120.0).timeout.connect(func(): get_tree().quit(2))
	await get_tree().process_frame
	await get_tree().process_frame
	await run_test()


func load_exploration() -> Node:
	if _scene != null:
		get_tree().root.remove_child(_scene)
		_scene.free()
	Campaign.current_map = MAP
	_scene = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(_scene)
	await get_tree().process_frame
	await get_tree().process_frame
	return _scene


func tap_key(code: Key):
	var down = InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	var up = InputEventKey.new()
	up.keycode = code
	up.physical_keycode = code
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame


func hold_key(code: Key, frames: int):
	var down = InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.pressed = true
	Input.parse_input_event(down)
	for i in frames:
		await get_tree().process_frame
	var up = InputEventKey.new()
	up.keycode = code
	up.physical_keycode = code
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame


func run_test():
	Campaign.reset()
	log_line("======== scene comes up ========")
	var scene = await load_exploration()
	var map = scene.get_node_or_null("Map")
	ok(map != null, "map instantiated as 'Map'")
	ok(map.get_node_or_null("TileMap") != null, "Map/TileMap resolves (camera clamp path)")
	ok(scene.party != null and scene.party.leader != null, "party spawned")
	# However many the map says, less the leader - the crossroads is Cyrus
	# alone, the laboratory is four. See MapSetup.
	var expected_followers = Campaign.living_party().size() - 1
	ok(scene.party.followers.size() == expected_followers,
		"a follower for everyone but the leader",
		"%d of %d" % [scene.party.followers.size(), expected_followers])
	# Count isn't pinned - the map is content and gains things over time. What
	# matters is that discovery is recursive and finds the ones under test.
	var found_names = []
	for item in scene._interactables:
		found_names.append(item.name)
	ok(scene._interactables.size() >= 4, "interactables discovered in the map", "%d: %s" % [scene._interactables.size(), found_names])
	# By kind rather than by name, since what a map is called its things is
	# content: what matters is that discovery reaches into nested nodes.
	var kinds = 0
	for item in scene._interactables:
		if item is ExamineInteractable or item is DialogueInteractable or item is DoorInteractable or item is EncounterInteractable:
			kinds += 1
	ok(kinds >= 2, "and they are real interactables of more than one kind", "%d of %d" % [kinds, scene._interactables.size()])
	var entry_node = null
	for child in map.get_children():
		if child is EntryPoint:
			entry_node = child
	var entry = entry_node.position if entry_node != null else Vector2.ZERO
	ok(scene.party_position() == entry, "party starts at the EntryPoint", "%s" % scene.party_position())
	log_line("")

	log_line("======== HUD in exploration mode ========")
	var ui = scene.get_node("CanvasLayer/UI")
	ok(not ui.get_node("TurnQueue").visible, "turn queue hidden")
	ok(not ui.get_node("Actions/Movement").visible, "movement counter hidden")
	ok(not ui.get_node("Actions/EndTurnButton").visible, "End Turn hidden")
	ok(ui.get_node("Status").visible, "party status still shown")
	ok(ui.get_node("Actions/Information").visible, "message log still shown")
	log_line("")

	log_line("======== party portraits ========")
	var status_panel = ui.get_node("Status")
	ok(status_panel.get_child_count() == Campaign.living_party().size(),
		"a portrait per party member",
		"%d for %s" % [status_panel.get_child_count(), Campaign.living_party()])
	var portrait_names = []
	for child in status_panel.get_children():
		portrait_names.append(child.name)
	var leader_name = CombatantDatabase.combatants[Campaign.leader()].name
	ok(portrait_names[0] == leader_name, "leader's portrait is first", "%s" % [portrait_names])
	ok(status_panel.get_child(0).modulate == Color.WHITE, "leader drawn at full brightness")
	ok(status_panel.get_child(1).modulate != Color.WHITE, "followers dimmed")
	ok(Campaign.party_order.size() > 1, "roster taken from the map's own party", "%s at level %d" % [Campaign.party_order, Campaign.party_level])
	log_line("")

	log_line("======== changing who leads (Tab) ========")
	var led_before = Campaign.leader()
	var stood = scene.party_position()
	await tap_key(KEY_TAB)
	var led_after = Campaign.leader()
	ok(led_after != led_before, "Tab passes the lead", "%s -> %s" % [led_before, led_after])
	ok(Campaign.party_order[0] == led_after, "marching order updated", "%s" % [Campaign.party_order])
	ok(scene.party_position() == stood, "the party doesn't move when the lead changes", "%s" % scene.party_position())
	var swapped_names = []
	for child in ui.get_node("Status").get_children():
		swapped_names.append(child.name)
	ok(swapped_names[0] != portrait_names[0], "portraits reorder to match", "%s" % [swapped_names])
	# Round the whole line, however long it is - one Tab has been spent above.
	for i in Campaign.party_order.size() - 1:
		await tap_key(KEY_TAB)
	ok(Campaign.leader() == led_before, "cycling all the way round comes back", "%s" % Campaign.leader())
	log_line("")

	log_line("======== a dead member can't lead ========")
	Campaign.party_state[Campaign.leader()] = {"hp": 0, "alive": false}
	var fallen = Campaign.leader()
	ok(fallen != "" and Campaign.is_alive(fallen), "lead passes to someone still standing", "%s" % fallen)
	ok(Campaign.party_members().size() == Campaign.party_order.size() - 1,
		"the fallen leave the portrait column",
		"%d of %d" % [Campaign.party_members().size(), Campaign.party_order.size()])
	Campaign.party_state.clear()
	log_line("")

	log_line("======== collision comes from the tile Blocks data ========")
	var tile_map = map.get_node("TileMap")
	var blocked_tile = Vector2i(-1, -1)
	var open_tile = Vector2i(-1, -1)
	var used = tile_map.get_used_rect()
	for x in range(used.position.x, used.position.x + used.size.x):
		for y in range(used.position.y, used.position.y + used.size.y):
			var data = tile_map.get_cell_tile_data(0, Vector2i(x, y))
			if data == null:
				continue
			if 0 in data.get_custom_data("Blocks"):
				if blocked_tile.x < 0:
					blocked_tile = Vector2i(x, y)
			elif open_tile.x < 0:
				open_tile = Vector2i(x, y)
	ok(blocked_tile.x >= 0, "map has a blocking tile to test", "%s" % blocked_tile)
	ok(not scene.is_walkable(tile_map.map_to_local(blocked_tile)), "blocking tile rejected")
	ok(scene.is_walkable(tile_map.map_to_local(open_tile)), "open tile accepted", "%s" % open_tile)
	ok(not scene.is_walkable(Vector2(-500, -500)), "off the map rejected")
	log_line("")

	log_line("======== walking ========")
	# Headless runs uncapped, so a frame's delta is tiny - walk until the party
	# has actually covered ground rather than for a fixed frame count.
	var map_rect = scene.camera.get_map_rect()
	scene.party.teleport(map_rect.position + map_rect.size * 0.5) # mid-map, where the camera clamp doesn't bind
	var before = scene.party_position()
	var frames = 0
	# Somewhere with a clear run east, found rather than assumed: where the map
	# happens to put its entry point is content, and a party pressed against a
	# wall proves nothing about whether a line of three spreads out behind its
	# leader.
	scene.party.teleport(_open_run_east(scene, 6))
	await get_tree().process_frame
	before = scene.party_position()
	var down = InputEventKey.new()
	down.keycode = KEY_D
	down.physical_keycode = KEY_D
	down.pressed = true
	Input.parse_input_event(down)
	while scene.party_position().x - before.x < Grid.tiles(3.75) and frames < 4000:
		await get_tree().process_frame
		frames += 1
	var up = InputEventKey.new()
	up.keycode = KEY_D
	up.physical_keycode = KEY_D
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame
	var after = scene.party_position()
	ok(after.x > before.x, "WASD moves the leader east", "%s -> %s" % [before, after])
	ok(scene.camera.position == after,
		"camera follows the leader where the map allows", "camera %s" % scene.camera.position)
	var first = scene.party.followers[0].position
	var second = scene.party.followers[1].position
	ok(first.x < after.x and after.distance_to(first) > Grid.tiles(0.3),
		"follower trails behind on the route walked", "leader %s, follower %s" % [after, first])
	ok(second.x < first.x, "second follower is further back still", "%s vs %s" % [second, first])
	log_line("")

	log_line("======== camera clamp still applies while following ========")
	# The map's own top-left, which is not the origin on a map painted into
	# negative coordinates.
	var corner = scene._tile_map.get_used_rect().position
	scene.party.teleport(scene._tile_map.map_to_local(corner))
	scene._follow_camera(scene.party_position())
	var view = scene.camera.get_visible_world_size()
	# Measured from the map's own top-left, which is not the origin: a map can be
	# painted into negative coordinates, and half a viewport from (0,0) is then
	# nowhere in particular.
	var limit = scene.camera.get_map_rect().position + view * 0.5
	ok(scene.camera.position.x >= limit.x - 0.01 and scene.camera.position.y >= limit.y - 0.01,
		"camera stops at the map edge instead of following past it",
		"camera %s, limit %s" % [scene.camera.position, limit])
	log_line("")

	log_line("======== walking into a wall ========")
	# Put the leader right against a blocking tile and push into it.
	var wall_local = tile_map.map_to_local(blocked_tile)
	scene.party.teleport(wall_local + Vector2(-Grid.tiles(1.25), 0))
	var wall_before = scene.party_position()
	await hold_key(KEY_D, 30)
	ok(scene.party_position().x < wall_local.x - Grid.tiles(0.3),
		"the party is stopped by the wall", "%s -> %s (wall at %s)" % [wall_before, scene.party_position(), wall_local])
	log_line("")

	log_line("======== interacting ========")
	# Found by what they are rather than by name: which interactables a map
	# carries, and what they are called, is content.
	var signpost = null
	var ambush = null
	for item in scene._interactables:
		if signpost == null and item is ExamineInteractable:
			signpost = item
		if ambush == null and item is EncounterInteractable:
			ambush = item
	if signpost == null:
		# Same as the ambush below: what a map carries is content, and the rules
		# being checked here are not.
		signpost = ExamineInteractable.new()
		signpost.name = "TestSignpost"
		signpost.text = "A test signpost, placed because this map has none."
		signpost.position = scene.party_position()
		scene.add_child(signpost)
		scene._interactables.append(signpost)
		log_line("  NOTE  this map has nothing to examine, so the test placed one")
	ok(signpost != null, "there is something to examine", signpost.name)
	if ambush == null:
		# No ambush on this map, so the test brings its own rather than skipping
		# the rules it is here to check.
		ambush = EncounterInteractable.new()
		ambush.name = "TestAmbush"
		ambush.encounter = load("res://encounters/encounter_01_ambush.tres")
		ambush.position = scene.party_position()
		scene.add_child(ambush)
		scene._interactables.append(ambush)
		log_line("  NOTE  this map has no encounter trigger, so the test placed one")
	scene.party.teleport(signpost.global_position)
	scene._update_prompt()
	ok(scene._current_target == signpost, "nearest interactable detected", "%s" % [scene._current_target.name if scene._current_target else "none"])
	log_line("")

	log_line("======== what the banner says to press ========")
	var banner = ui.get_node("Actions/SelectTargetMessage/MarginContainer/Label")
	ok(banner.text == "Press E to interact",
		"a signpost is interacted with, not talked to", banner.text)
	# Talking belongs to a conversation and to nothing else on the map. Stood in
	# front of one, alone, so which of the two is nearer never comes into it.
	var chatty = DialogueInteractable.new()
	chatty.name = "TestNeighbour"
	chatty.position = scene.party_position()
	scene.add_child(chatty)
	var other_interactables = scene._interactables.duplicate()
	scene._interactables = [chatty]
	scene._update_prompt()
	ok(scene._current_target == chatty, "standing in front of somebody to talk to",
		"%s" % [scene._current_target.name if scene._current_target else "none"])
	ok(banner.text == "Press E to talk", "who is talked to", banner.text)
	scene._interactables = other_interactables
	chatty.queue_free()

	# Asked of the classes themselves rather than of a list written out here,
	# so a new kind of interactable is covered the day it is added.
	var claims_to_talk := []
	for kind in [DoorInteractable.new(), EncounterInteractable.new(), ExamineInteractable.new(),
		Interactable.new()]:
		if kind.prompt.to_lower() == "talk":
			claims_to_talk.append(kind.get_script().resource_path.get_file())
		kind.free()
	ok(claims_to_talk.is_empty(), "and nothing else in the game claims to talk",
		"%s" % [claims_to_talk])
	# A fight is worth naming, so encounter triggers keep a word of their own.
	var trigger = EncounterInteractable.new()
	ok(trigger.prompt.to_lower() == "fight", "a fight still says what it is",
		"Press E to %s" % trigger.prompt.to_lower())
	trigger.free()
	var door = DoorInteractable.new()
	var lookable = ExamineInteractable.new()
	ok(door.prompt.to_lower() == "interact" and lookable.prompt.to_lower() == "interact",
		"while doors and things to look at are plain interactions",
		"%s, %s" % [door.prompt, lookable.prompt])
	door.free()
	lookable.free()

	# A word saved on a placed node beats the class default, which is how three
	# of them went on saying Examine, Fight and Read after the change.
	var overriding := []
	for map_path in ["res://scenes/explore_crossroads.tscn", "res://church.tscn",
		"res://skills/laboratory_terrain_explore.tscn"]:
		var saved_text = FileAccess.get_file_as_string(map_path)
		for word in ["Read", "Examine", "Enter"]:
			if saved_text.contains('prompt = "%s"' % word):
				overriding.append("%s still says %s" % [map_path.get_file(), word])
	ok(overriding.is_empty(), "and no map overrides it with a word of its own",
		"%s" % [overriding])
	# The log is a BBCode RichTextLabel filled with append_text, which doesn't
	# touch .text - the rendered content is get_parsed_text().
	var log_text = ui.get_node("Actions/Information/Text")
	var before_text_length = log_text.get_parsed_text().length()
	signpost.interact(scene)
	var parsed = log_text.get_parsed_text()
	ok(parsed.length() > before_text_length, "examining writes to the message log")
	# Whatever the sign says, rather than a phrase from an older draft of it:
	# the words on a signpost are content and get rewritten.
	ok(parsed.contains(signpost.text.substr(0, 20)), "the sign's own text appears",
		"wanted '%s'" % signpost.text)
	log_line("")

	log_line("======== starting a battle from the map ========")
	scene.party.teleport(ambush.global_position)
	var stood_at = scene.party_position()
	Campaign.begin_battle_from_exploration(ambush.encounter, scene.map_path(), stood_at, ambush.trigger_id)
	ok(Campaign.has_map_to_return_to(), "campaign knows to come back")
	ok(Campaign.current_map == MAP, "remembers which map", "%s" % Campaign.current_map)
	ok(Campaign.return_position == stood_at, "remembers where the party stood", "%s" % Campaign.return_position)
	ok(Campaign.current_encounter == ambush.encounter, "the right encounter is queued")
	log_line("")

	log_line("======== coming back after winning ========")
	Campaign.finish_battle_from_exploration(true)
	# Whatever this ambush calls itself - the id defaults to the node name.
	ok(Campaign.is_trigger_cleared(ambush.trigger_id), "beaten trigger retired", ambush.trigger_id)
	var returned = await load_exploration()
	ok(returned.party_position() == stood_at,
		"party returns to the exact spot it left", "%s" % returned.party_position())
	var still_there = false
	for item in returned._interactables:
		if item.name == "GoblinAmbush" and item.is_available():
			still_there = true
	ok(not still_there, "the beaten fight is no longer offered")
	log_line("")

	log_line("======== doors ========")
	Campaign.travel_to_map("res://scenes/explore_crossroads.tscn", "start")
	ok(Campaign.target_entry == "start" and not Campaign.return_to_position,
		"a door targets an entry point rather than remembered coordinates")
	var arrived = await load_exploration()
	ok(arrived.party_position() == entry, "arrives at the named entry point", "%s" % arrived.party_position())
	log_line("")

	log_line("======== the fallen don't walk ========")
	Campaign.party_state["cyrus"] = {"hp": 0, "alive": false}
	var short_handed = await load_exploration()
	var walking = Campaign.party_order.size() - 2  # one dead, one leading
	ok(short_handed.party.followers.size() == walking,
		"a dead party member is left out of the line",
		"%d of %d followers" % [short_handed.party.followers.size(), walking])
	Campaign.reset()
	log_line("")

	log_line("======== the laboratory hands out its own kit ========")
	# What the party is carrying at the start of this stretch is the map's to
	# say, the same way who is there and what is playing already are.
	var lab_scene = await load_exploration()
	var setup: MapSetup = null
	for node in lab_scene.get_node(lab_scene.MAP_NODE).get_children():
		if node is MapSetup:
			setup = node
	ok(setup != null, "the laboratory says how it starts")
	if setup != null:
		ok(setup.hands_kit_out(), "and hands something out",
			"%s plus %s" % [setup.everyone_carries, setup.also_carries])
		var missing_kit := []
		for key in Campaign.living_party():
			var carried = Campaign.inventory_of(key)
			var wanted = setup.kit_for(key)
			for item in wanted:
				if not item in carried:
					missing_kit.append("%s has no %s" % [key, item])
		ok(missing_kit.is_empty(), "everybody walks in with what it names",
			"%s" % [missing_kit])
		# The specifics, since they are the thing that was asked for.
		var without_cure := []
		for key in Campaign.living_party():
			if not "cure_potion" in Campaign.inventory_of(key):
				without_cure.append(key)
		ok(without_cure.is_empty(), "a cure potion each", "%s" % [without_cure])
		ok("tiny_bomb" in Campaign.inventory_of("cyrus"), "and a bomb for Cyrus on top",
			"%s" % [Campaign.inventory_of("cyrus")])
		# Empty Handed and the kit compose: nobody is still carrying what their
		# database entry happens to list.
		if setup.empty_handed:
			var extras := []
			for key in Campaign.living_party():
				for item in Campaign.inventory_of(key):
					if item != "" and not item in setup.kit_for(key):
						extras.append("%s also has %s" % [key, item])
			ok(extras.is_empty(), "and nothing their database entry lists on top of it",
				"%s" % [extras])
	log_line("")

	log_line("======== Only Once means once, whichever way it is reached ========")
	# It was only ever enforced for things you walk into. Everything you press E
	# on - every signpost, every conversation - was marked by nobody, so the box
	# was ticked and the scene played again every time you pressed the key.
	# A scene of its own: `scene` was freed by the reload the kit section does,
	# and adding a child to a freed node takes the whole engine down rather than
	# failing politely.
	var here = await load_exploration()
	var once := DialogueInteractable.new()
	once.name = "OnceOnly"
	once.only_once = true
	once.position = here.party_position()
	here.add_child(once)
	ok(once.is_available(), "it starts available")
	once.use(here)
	ok(not once.is_available(), "using it spends it",
		"contact_spent=%s" % once.contact_spent)
	# And the scene stops offering it, which is what the player sees.
	var others = here._interactables.duplicate()
	here._interactables = [once]
	here._update_prompt()
	ok(here._current_target == null, "so nothing is prompting for it any more",
		"%s" % [here._current_target.name if here._current_target else "none"])
	here._interactables = others
	once.queue_free()

	# The other half of the rule: something that did nothing is not spent by
	# having been tried.
	# An examinable too, because that class overrides is_available and so had to
	# be taught to ask the base class about Only Once at all.
	var looked := ExamineInteractable.new()
	looked.name = "LookedOnce"
	looked.only_once = true
	looked.text = "Once is enough."
	looked.position = here.party_position()
	here.add_child(looked)
	looked.use(here)
	ok(not looked.is_available(), "an examinable marked once is spent as well",
		"contact_spent=%s" % looked.contact_spent)
	looked.queue_free()

	var locked := ExamineInteractable.new()
	locked.name = "LockedOnce"
	locked.only_once = true
	locked.requires_flag = "a_flag_nobody_has_set"
	locked.text = "Still shut."
	locked.position = here.party_position()
	here.add_child(locked)
	locked.use(here)
	ok(locked.is_available(), "a locked one is not spent by being tried",
		"contact_spent=%s" % locked.contact_spent)
	Campaign.set_flag("a_flag_nobody_has_set", true)
	locked.use(here)
	ok(not locked.is_available(), "and is spent once it actually happens")
	locked.queue_free()

	# The crossroads node that was reported, as it is written on the map.
	var crossroads = FileAccess.get_file_as_string("res://scenes/explore_crossroads.tscn")
	var block = crossroads.get_slice('[node name="DialogueInteractable2"', 1).get_slice("[node ", 0)
	ok(block.contains("only_once = true"), "the reported node still asks for once")
	ok(not block.contains("automatic = true"),
		"and is one you press E on, which is exactly the case that was broken")
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


## The centre of a tile with `length` walkable tiles in a row to its east, so a
## walking test has somewhere to walk.
func _open_run_east(scene: Node, length: int) -> Vector2:
	var tile_map: TileMap = scene._tile_map
	var region = tile_map.get_used_rect()
	# Searched outward from the middle of the map, so the run found is somewhere
	# the camera is free to follow rather than pinned against the border.
	var middle = region.position + region.size / 2
	var rows = []
	for y in range(region.position.y, region.position.y + region.size.y):
		rows.append(y)
	rows.sort_custom(func(a, b): return absi(a - middle.y) < absi(b - middle.y))
	for y in rows:
		for x in range(region.position.x, region.position.x + region.size.x - length):
			var clear = true
			for step in range(length):
				if not scene.is_walkable(tile_map.map_to_local(Vector2i(x + step, y))):
					clear = false
					break
			if clear:
				return tile_map.map_to_local(Vector2i(x, y))
	return scene.party_position()
