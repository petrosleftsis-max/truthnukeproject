extends Node
## Characters walked about the map from dialogue.

var LOG_PATH := HarnessLog.path_for("actors")

var _log: FileAccess = null
var _fail = 0
var scene: Node = null
var tile_map: TileMap = null


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
	get_tree().create_timer(180.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


## Runs frames until `check` is true or the budget runs out, so a walk can be
## waited on without the test knowing how long it should take.
func until(check: Callable, seconds: float = 20.0) -> bool:
	var frames = int(seconds * 60.0)
	for i in frames:
		if check.call():
			return true
		await get_tree().process_frame
	return false


func tile_of(sprite: Node2D) -> Vector2i:
	return tile_map.local_to_map(sprite.position)


func run_test():
	Campaign.reset()
	scene = load("res://scenes/exploration.tscn").instantiate()
	ok(scene != null, "the exploration scene loads")
	if scene == null:
		log_line("FAILURES: %d" % _fail)
		get_tree().quit(1)
		return
	get_tree().root.add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	tile_map = scene._tile_map
	ok(tile_map != null, "with a map under it")

	log_line("======== the scene hands itself to Actors ========")
	ok(Actors._scene == scene, "Actors knows which scene is on")
	ok(Actors._tile_map == tile_map, "and which map")
	ok(Actors._grid != null, "and has a grid to find its way around with")
	ok(Actors._grid.region == tile_map.get_used_rect(), "covering the whole map",
		"%s vs %s" % [Actors._grid.region, tile_map.get_used_rect()])
	log_line("")

	log_line("======== a party member walks where dialogue sends them ========")
	var leader_key = Campaign.leader()
	var walker = scene.party.sprite_for(leader_key)
	ok(walker != null, "the party is addressable by combatant key", leader_key)
	var from = tile_of(walker)
	# Somewhere reachable but not adjacent, so this is a walk rather than a step.
	var to = _open_tile_away_from(from, 6)
	Actors.walk_behind(leader_key, to.x, to.y)
	ok(Actors.is_walking(leader_key), "the walk starts")
	var arrived = await until(func(): return not Actors.is_walking(leader_key))
	ok(arrived, "and finishes on its own")
	ok(tile_of(walker) == to, "on the tile it was sent to", "%s -> %s, wanted %s" % [from, tile_of(walker), to])
	log_line("")

	log_line("======== walking is what a dialogue line waits for ========")
	var back = _open_tile_away_from(tile_of(walker), 5)
	# An array, not a bool: a lambda captures locals by value, so a plain flag
	# set inside one never reaches the test that is watching it.
	var done = [false]
	# Exactly what `do Actors.walk(...)` does: the addon awaits the call.
	var awaited = func():
		await Actors.walk(leader_key, back.x, back.y)
		done[0] = true
	awaited.call()
	await get_tree().process_frame
	ok(not done[0], "the call has not returned while the character is still walking")
	await until(func(): return done[0])
	ok(done[0], "and returns once they arrive")
	ok(tile_of(walker) == back, "where they were sent", "%s wanted %s" % [tile_of(walker), back])
	log_line("")

	log_line("======== someone who is not in the party can be walked in ========")
	# Nothing placed in advance: named straight out of the combatant database.
	var guard_key = "barbarian"
	var meeting = _open_tile_away_from(tile_of(walker), 3)
	Actors.enter_behind(guard_key, meeting.x, meeting.y)
	var guard = Actors._actor(guard_key, false)
	ok(guard != null, "a character was built for the scene", guard_key)
	ok(guard != null and guard.visible, "and is on screen")
	var started_outside = guard != null and not tile_map.get_used_rect().has_point(tile_of(guard))
	ok(started_outside, "starting outside the map, so they walk in rather than appear",
		"%s, map is %s" % [tile_of(guard) if guard else "?", tile_map.get_used_rect()])
	var walked_in = await until(func(): return not Actors.is_walking(guard_key))
	ok(walked_in, "the walk in finishes")
	ok(tile_of(guard) == meeting, "at the spot it was sent to", "%s wanted %s" % [tile_of(guard), meeting])
	log_line("")

	log_line("======== and walked back out again ========")
	Actors.exit_behind(guard_key)
	var left = await until(func(): return not Actors.is_walking(guard_key))
	ok(left, "the walk out finishes")
	await get_tree().process_frame
	ok(not is_instance_valid(guard) or not guard.visible,
		"and someone this scene invented is gone from it")
	log_line("")

	log_line("======== a party member is only shown out, never taken away ========")
	Actors.exit_behind(leader_key)
	await until(func(): return not Actors.is_walking(leader_key))
	await get_tree().process_frame
	ok(is_instance_valid(walker), "the party member still exists - they are the player's")
	ok(not walker.visible, "just walked out of sight")
	walker.visible = true
	log_line("")

	log_line("======== facing ========")
	Actors.place(leader_key, 10, 10)
	Actors.face(leader_key, "left")
	ok(walker.get("_facing_left") == true or _flipped(walker), "told left, faces left")
	Actors.face(leader_key, "right")
	ok(not _flipped(walker), "told right, faces right")
	# Someone to the left of them turns them left, wherever they are.
	Actors.place(guard_key if is_instance_valid(guard) else leader_key, 4, 10)
	if is_instance_valid(guard):
		Actors.face(leader_key, guard_key)
		ok(_flipped(walker), "and facing someone to the left turns them that way")
	log_line("")

	log_line("======== a walk goes around things rather than through them ========")
	var blocked = _first_blocked_tile()
	if blocked == Vector2i(-9999, -9999):
		log_line("  NOTE  this map has nothing blocking on it, so there is nothing to route around")
	else:
		var route = Actors._route(tile_map.map_to_local(_open_neighbour(blocked)), tile_map.map_to_local(blocked))
		var ends_open = not Actors._grid.is_point_solid(tile_map.local_to_map(route[route.size() - 1]))
		ok(ends_open, "sent at a wall, the walk ends somewhere standable instead",
			"%s" % tile_map.local_to_map(route[route.size() - 1]))
		var crosses_wall = false
		for point in route:
			if Actors._grid.is_point_solid(tile_map.local_to_map(point)):
				crosses_wall = true
		ok(not crosses_wall, "and no step of a route stands in a wall")
	log_line("")

	log_line("======== the exploration camera is fixed ========")
	var cam = scene.camera
	ok(cam != null, "the scene has a camera")
	ok(not cam.allow_zoom, "which the player cannot zoom")
	ok(not cam.free_look, "nor pan, since WASD walks the party")
	var held = cam.zoom.x
	# Wider than the 0.7 it used to open at. Which value exactly is framing, and
	# yours to change - that it is fixed is what this tests.
	ok(held < 0.7, "held wider than it used to be", "%s" % held)
	# The wheel, and the call behind it, both leave it where it is.
	cam.zoom_at_screen_point(held * 2.0, Vector2(400, 300))
	ok(is_equal_approx(cam.zoom.x, held), "asking it to zoom in changes nothing", "%s" % cam.zoom.x)
	cam.zoom_at_screen_point(held * 0.5, Vector2(400, 300))
	ok(is_equal_approx(cam.zoom.x, held), "and neither does asking it to zoom out", "%s" % cam.zoom.x)
	var wheel = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = Vector2(400, 300)
	cam._unhandled_input(wheel)
	ok(is_equal_approx(cam.zoom.x, held), "the wheel itself does nothing either", "%s" % cam.zoom.x)
	# The battle camera is untouched by any of this.
	var battle_cam = CameraController.new()
	ok(battle_cam.allow_zoom, "a camera is zoomable unless it says otherwise, so battle still is")
	battle_cam.free()
	log_line("")

	log_line("======== pressing E, or just walking into it ========")
	# Every kind of interactable can fire on approach now, not only doors and
	# ambushes.
	for kind in [DialogueInteractable.new(), ExamineInteractable.new(), DoorInteractable.new(), EncounterInteractable.new()]:
		ok("automatic" in kind, "%s can be set to fire on approach" % kind.get_script().resource_path.get_file())
		ok(not kind.automatic, "and asks for a key press unless told otherwise")
		kind.free()

	var talker = DialogueInteractable.new()
	talker.name = "AutoTalker"
	talker.automatic = true
	talker.dialogue = load("res://Dialogue/flag_example.dialogue")
	talker.position = scene.party_position()
	scene.get_node("Map").add_child(talker) if scene.has_node("Map") else scene.add_child(talker)
	scene._interactables.append(talker)
	await get_tree().process_frame
	ok(not talker.contact_spent, "nothing has fired yet")
	scene._check_contact_triggers(scene.party_position())
	ok(talker.contact_spent, "walking into it starts the conversation without a key press")
	ok(scene._blocking_interaction, "and the party is held while it plays")

	# Standing in it must not start it again the moment it ends.
	scene.end_blocking_interaction()
	scene._check_contact_triggers(scene.party_position())
	ok(talker.contact_spent, "standing in it afterwards does not start it over")
	ok(not scene._blocking_interaction, "the party is free to walk away")
	# Walking out and back in is what "again" means.
	scene._check_contact_triggers(scene.party_position() + Vector2(2000, 2000))
	ok(not talker.contact_spent, "walking out of range arms it again")
	talker.queue_free()
	scene._interactables.erase(talker)
	log_line("")

	log_line("======== a conversation that leads into a fight ========")
	var ambush = DialogueInteractable.new()
	ambush.name = "SewerAmbush"
	ambush.dialogue = load("res://Dialogue/flag_example.dialogue")
	ambush.encounter_after = load("res://encounters/encounter_01_ambush.tres")
	scene.add_child(ambush)
	await get_tree().process_frame
	ok("encounter_after" in ambush, "a conversation can name the fight it leads to")
	Campaign.reset()
	Campaign.current_encounter = null
	# What the end of the conversation does, without a scene change to chase.
	ambush._start_encounter_after(null, scene)
	ok(Campaign.current_encounter != null, "when it ends, the fight is the one queued up",
		Campaign.current_encounter.display_name if Campaign.current_encounter else "none")
	ok(Campaign.has_map_to_return_to(), "with this map remembered to come back to")
	# And it does not happen twice.
	Campaign.finish_battle_from_exploration(true)
	Campaign.current_encounter = null
	ambush._start_encounter_after(null, scene)
	ok(Campaign.current_encounter == null, "a fight already won does not happen again")
	ambush.queue_free()
	log_line("")

	log_line("======== a named marker is a place to walk to ========")
	# On a tile someone can stand on, so this tests the marker and not the
	# routing-around-walls that has its own section below.
	var spot = Actors._nearest_open_tile(Vector2i(9, 9))
	var marker = Waypoint.new()
	marker.name = "Gate"
	marker.position = tile_map.map_to_local(spot)
	scene.get_node("Map").add_child(marker) if scene.has_node("Map") else scene.add_child(marker)
	await get_tree().process_frame
	Actors.walk_behind(leader_key, "gate")
	ok(Actors.is_walking(leader_key), "dialogue can name the marker instead of a tile, and the case need not match")
	await until(func(): return not Actors.is_walking(leader_key))
	ok(tile_of(walker) == spot, "and the walk ends on it", "%s, marker is on %s" % [tile_of(walker), spot])
	ok(not marker.visible == false, "the marker itself is not something the player sees walking about")
	Actors.walk_behind("gate", 5, 5)
	ok(not Actors.is_walking("gate"), "and a marker is a place, never an actor")
	log_line("")

	log_line("======== nonsense in a dialogue does not take the scene down ========")
	Actors.walk_behind("nobody_at_all", 5, 5)
	ok(not Actors.is_walking("nobody_at_all"), "an unknown name is a warning, not a crash")
	Actors.walk_behind(leader_key, "no_such_waypoint")
	ok(not Actors.is_walking(leader_key), "so is an unknown waypoint")
	ok(is_instance_valid(scene), "the scene is still standing")
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func _flipped(sprite: Node2D) -> bool:
	for child in sprite.get_children():
		if child is AnimatedSprite2D or child is Sprite2D:
			return child.flip_h
	return false


## A tile roughly `distance` away that someone can stand on, so the tests walk
## a real distance without hardcoding this map's layout.
func _open_tile_away_from(from: Vector2i, distance: int) -> Vector2i:
	for offset in [Vector2i(distance, 0), Vector2i(-distance, 0), Vector2i(0, distance), Vector2i(0, -distance)]:
		var tile = from + offset
		if Actors._grid.region.has_point(tile) and not Actors._grid.is_point_solid(tile):
			return tile
	return Actors._nearest_open_tile(from + Vector2i(distance, 0))


func _first_blocked_tile() -> Vector2i:
	var region = Actors._grid.region
	for x in range(region.position.x, region.position.x + region.size.x):
		for y in range(region.position.y, region.position.y + region.size.y):
			var tile = Vector2i(x, y)
			if Actors._grid.is_point_solid(tile) and _open_neighbour(tile) != tile:
				return tile
	return Vector2i(-9999, -9999)


func _open_neighbour(tile: Vector2i) -> Vector2i:
	for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var next = tile + offset
		if Actors._grid.region.has_point(next) and not Actors._grid.is_point_solid(next):
			return next
	return tile
