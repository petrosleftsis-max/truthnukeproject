extends Node
## How the game feels, the proposals of 2026-11-16 as built from 2026-11-17: the comfort dials, the party's weight and its
## followers' fan, the softer map camera, and (further down, as they were built) the rest. View and feel only, so what is
## checked is that each thing happens, is switched off by its dial, and changes no rule.

var LOG_PATH := HarnessLog.path_for("feel")
const STAGE := "res://maps/stealth_stages/stealth_9.tscn"
## A map whose party is four: the fan needs somebody to follow.
const LAB := "res://maps/laboratory_explore.tscn"

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
	get_tree().create_timer(280.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


## Waits `seconds` of the game's own time.
func wait(seconds: float):
	var left := seconds
	while left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()


func open_map(map: String) -> ExplorationScene:
	Campaign.reset()
	Campaign.current_map = map
	var scene: ExplorationScene = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(scene)
	await settle(8)
	scene.end_blocking_interaction()
	return scene


func close(scene: Node):
	for action in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(action)
	scene.queue_free()
	await settle(3)


## The west end of a run of `length` walkable tiles with a walkable row above and below it, nearest the map's middle.
func open_run(scene: ExplorationScene, length: int) -> Vector2:
	var tile_map: TileMap = scene._tile_map
	var region := tile_map.get_used_rect()
	var middle := region.position + region.size / 2
	var rows := []
	for y in range(region.position.y + 1, region.end.y - 1):
		rows.append(y)
	rows.sort_custom(func(a, b): return absi(a - middle.y) < absi(b - middle.y))
	for y in rows:
		for x in range(region.position.x, region.end.x - length):
			var clear := true
			for step in range(length):
				for row in [y - 1, y, y + 1]:
					if not scene.is_walkable(tile_map.to_global(tile_map.map_to_local(Vector2i(x + step, row)))):
						clear = false
			if clear:
				return tile_map.map_to_local(Vector2i(x, y))
	return scene.party.leader.position


## A way the party can walk a good while from where it stands: the action to hold, or "" for none.
func open_way(party: ExplorationParty) -> Dictionary:
	var ways := {&"move_right": Vector2.RIGHT, &"move_left": Vector2.LEFT, &"move_down": Vector2.DOWN, &"move_up": Vector2.UP}
	for action in ways:
		var clear := true
		for step in range(1, 5):
			if not party._can_stand(party.leader.position + ways[action] * Grid.tiles(0.5) * step):
				clear = false
				break
		if clear:
			return {"action": action, "way": ways[action]}
	return {}


func run_test():
	await comfort()
	await walking()
	await the_view()
	await things()
	log_line("")
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0)


func comfort():
	log_line("======== the comfort dials ========")
	Comfort.forget()
	for dial in Comfort.DIALS:
		ok(is_equal_approx(Comfort.share(dial.key), 1.0), "%s begins at all of it" % dial.name)
	ok(Comfort.slow_motion(), "and slow motion on")
	var camera := CameraController.new()
	add_child(camera)
	camera.shake(10.0)
	ok(is_equal_approx(camera._shake, 10.0), "a shake of ten is ten", "%s" % camera._shake)
	camera._shake = 0.0
	Comfort.set_share(Comfort.SHAKE, 0.5)
	camera.shake(10.0)
	ok(is_equal_approx(camera._shake, 5.0), "at half, five", "%s" % camera._shake)
	camera._shake = 0.0
	Comfort.set_share(Comfort.SHAKE, 0.0)
	camera.shake(10.0)
	ok(camera._shake == 0.0, "and at nothing, none")
	Comfort.forget()
	ok(Comfort.share(Comfort.SHAKE) == 0.0, "the dial is kept in the settings file")
	Comfort.set_share(Comfort.SHAKE, 1.0)
	camera.queue_free()
	# Rumble: asked for whether or not a pad is there, and by the dial's share.
	var asked := Rumble.asked
	Rumble.thump(1.0, 0.2)
	ok(Rumble.asked == asked + 1 and Rumble.last.kind == &"thump" and is_equal_approx(Rumble.last.strong, 1.0), "a thump is asked of the pad", "%s" % Rumble.last)
	Comfort.set_share(Comfort.RUMBLE, 0.25)
	Rumble.thump(1.0, 0.2)
	ok(is_equal_approx(Rumble.last.strong, 0.25), "a quarter as hard with the dial at a quarter")
	Rumble.roll(1.0, 9.0)
	ok(Rumble.last.seconds <= Rumble.LONGEST, "and never longer than the longest", "%s" % Rumble.last.seconds)
	Comfort.set_share(Comfort.RUMBLE, 1.0)
	Rumble.blow(0.01)
	var after_scratch := Rumble.asked
	Rumble.blow(0.5)
	ok(Rumble.asked == after_scratch + 1 and Rumble.last.kind == &"thump", "a scratch is not felt, a heavy blow is a thump")
	Comfort.set_slow_motion(false)
	Comfort.forget()
	ok(not Comfort.slow_motion(), "slow motion can be turned off, and stays off")
	Comfort.set_slow_motion(true)
	# The dials themselves.
	var dials := ComfortDials.new()
	add_child(dials)
	await settle(2)
	ok(dials.controls().size() == Comfort.DIALS.size() + 1, "Options has a slider for each and a switch for slow motion", "%d" % dials.controls().size())
	var slider: HSlider = dials.controls()[0]
	slider.value = 0.3
	ok(is_equal_approx(Comfort.share(Comfort.DIALS[0].key), 0.3), "moving a slider moves its dial")
	slider.value = 1.0
	dials.queue_free()
	var pause = load("res://ui/pause_ui.tscn").instantiate()
	add_child(pause)
	await settle(2)
	ok(pause._comfort_panel != null and pause.get_node_or_null("OptionsPanel/VBox/ComfortButton") != null, "the pause menu's Options opens them")
	pause.queue_free()
	await settle(2)


func walking():
	log_line("======== the party's weight, and followers with a mind ========")
	var scene := await open_map(LAB)
	var party: ExplorationParty = scene.party
	ok(party != null and party.leader != null, "a party on the map")
	party.teleport(open_run(scene, 7))
	await settle(2)
	var way := {"action": &"move_right", "way": Vector2.RIGHT}
	ok(not way.is_empty(), "with room to walk", "%s" % way)
	if way.is_empty():
		await close(scene)
		return
	ok(party.gait() == 0.0, "standing, it has none of its pace")
	var from: Vector2 = party.leader.position
	Input.action_press(way.action)
	await get_tree().process_frame
	await get_tree().process_frame
	var early := party.gait()
	ok(early > 0.0, "a key held, it sets off at once", "gait %.2f" % early)
	await wait(ExplorationParty.EASE_IN_SECONDS * 2.5)
	ok(is_equal_approx(party.gait(), 1.0), "and is at its full pace a moment later", "gait %.2f" % party.gait())
	ok((party.leader.position - from).dot(way.way) > 1.0, "it has walked that way")
	Input.action_release(way.action)
	var let_go: Vector2 = party.leader.position
	await get_tree().process_frame
	await get_tree().process_frame
	var just_after: Vector2 = party.leader.position
	await wait(ExplorationParty.EASE_OUT_SECONDS * 3.0)
	var stopped: Vector2 = party.leader.position
	ok(party.gait() == 0.0 and not party._walking, "let go, it stops", "gait %.2f" % party.gait())
	ok((stopped - let_go).dot(way.way) >= 0.0 and stopped.distance_to(let_go) < Grid.tiles(0.4), "within a few steps: it glides no further than that",
		"%.1f px" % stopped.distance_to(let_go))
	await settle(4)
	ok(party.leader.position == stopped, "and stays stopped")
	# The fan: those behind step out of the line once the leader has stood a while, and back in as it sets off.
	if party.followers.is_empty():
		log_line("  (nobody follows on this map: the fan is not checked)")
	else:
		ok(party._fan.is_empty() or party._fan[0] == Vector2.ZERO or party._stood < ExplorationParty.FAN_AFTER_SECONDS, "just stopped, they are in the line")
		await wait(ExplorationParty.FAN_AFTER_SECONDS + 1.6)
		var spots := 0
		for i in party.followers.size():
			var spot: Vector2 = party._fan_spot(i)
			if spot != Vector2.ZERO:
				spots += 1
			ok(party._fan[i].distance_to(spot) < 1.0, "after a while follower %d stands where the fan puts them" % i, "%s of %s" % [party._fan[i], spot])
			ok(party._fits(party.followers[i].position), "on ground they fit on")
		ok(spots > 0, "at least one of them out of the line", "%d" % spots)
		Input.action_press(way.action)
		await wait(0.8)
		var back := true
		for i in party.followers.size():
			if party._fan[i].length() > 1.0:
				back = false
		ok(back, "walking again, they fall back into the line")
		Input.action_release(way.action)
		party.fans = false
		await wait(ExplorationParty.FAN_AFTER_SECONDS + 1.0)
		ok(party._fan[0] == Vector2.ZERO, "a map that keeps its line keeps it (fans off)")
	await close(scene)


func the_view():
	log_line("======== the map's camera, softer ========")
	# Headless the view is fixed to the leader, as it was.
	var scene := await open_map("")
	var party: ExplorationParty = scene.party
	var camera: Camera2D = scene.camera
	var pinned := camera.position
	camera.position = party.leader.position
	camera.clamp_to_map()
	ok(pinned.distance_to(camera.position) < 0.5, "headless the view is on the leader, as it was", "%s of %s" % [pinned, camera.position])
	await close(scene)
	CameraController.moves_headless = true
	scene = await open_map("")
	party = scene.party
	camera = scene.camera
	var way := open_way(party)
	if way.is_empty():
		ok(false, "room to walk")
		CameraController.moves_headless = false
		await close(scene)
		return
	await wait(ExplorationScene.ARRIVE_SECONDS + 1.5)
	Input.action_press(way.action)
	await wait(0.25)
	var feel: Dictionary = scene.view_feel()
	ok(feel.ahead.dot(way.way) > 0.0, "walking, the view looks ahead the way they go", "%s" % feel.ahead)
	ok(feel.ahead.length() <= Grid.tiles(ExplorationScene.LOOK_AHEAD_TILES) + 0.5, "by no more than it may")
	await wait(0.5)
	Input.action_release(way.action)
	await wait(ExplorationScene.LOOK_AHEAD_HOLD + 3.0)
	feel = scene.view_feel()
	var on_them: Vector2 = camera.position
	camera.position = party.leader.position
	camera.clamp_to_map()
	ok(feel.ahead == Vector2.ZERO and on_them.distance_to(camera.position) < 1.0, "standing a while, it comes back onto them", "%s, %.1f px off" % [feel.ahead, on_them.distance_to(camera.position)])
	# With the dial at nothing it is fixed to the leader.
	Comfort.set_share(Comfort.SWAY, 0.0)
	Input.action_press(way.action)
	await wait(0.3)
	var fixed: Vector2 = camera.position
	camera.position = party.leader.position
	camera.clamp_to_map()
	ok(fixed.distance_to(camera.position) < Grid.tiles(0.12), "with camera sway at nothing the view is fixed to them even walking", "%.1f px off" % fixed.distance_to(camera.position))
	ok(scene.view_feel().ahead.length() < 0.5 and scene.view_feel().room == 0.0, "and neither looks ahead nor eases into a room")
	Input.action_release(way.action)
	Comfort.set_share(Comfort.SWAY, 1.0)
	await close(scene)
	# Rooms: a small enclosed place is one, a yard is not, a wall is not.
	scene = await open_map(STAGE)
	var tile_map: TileMap = scene._tile_map
	var small := 0
	var open := 0
	var walls_small := 0
	for cell in tile_map.get_used_cells(0):
		var walkable: bool = scene.is_walkable(tile_map.to_global(tile_map.map_to_local(cell)))
		var is_small: bool = scene.small_room_at(cell)
		if not walkable and is_small:
			walls_small += 1
		elif walkable and is_small:
			small += 1
		elif walkable:
			open += 1
	ok(small > 0 and open > 0 and walls_small == 0, "the Light stage has small rooms and open ground, and no wall is a room", "%d small, %d open, %d walls" % [small, open, walls_small])
	ok(small <= open, "most of it is not a small room")
	await close(scene)
	CameraController.moves_headless = false


func things():
	log_line("======== things to use and to find ========")
	MapFeel.plays_headless = true
	var scene := await open_map(STAGE)
	var doors: Array = scene.find_children("*", "StealthDoor", true, false)
	ok(not doors.is_empty(), "the Light stage has doors", "%d" % doors.size())
	if not doors.is_empty():
		var door: StealthDoor = doors[0]
		if door.is_open:
			scene.stealth.set_door(door, false, true)
			await wait(StealthDoor.SWING_SECONDS * 2.0)
		ok(door.swing() == 0.0 and door.depth_footprint(false).is_equal_approx(Rect2(0, 0, 1, 1)), "a shut door stands across its tile")
		var creaks := int(MapFeel.heard.get(&"door_creak", 0))
		var thuds := int(MapFeel.heard.get(&"door_shut", 0))
		scene.stealth.set_door(door, true, true)
		ok(door.passable(), "opened, it can be walked through at once")
		ok(door.swing() < 1.0, "but is drawn still swinging", "%.2f" % door.swing())
		await wait(StealthDoor.SWING_SECONDS * 0.5)
		var part: Rect2 = door.depth_footprint(false)
		ok(door.swing() > 0.0 and door.swing() < 1.0 and part.size.x < 1.0 and part.size.x > StealthDoor.LEAF_TILES, "half way, its leaf is part of the way round", "%.2f, %s" % [door.swing(), part])
		await wait(StealthDoor.SWING_SECONDS * 1.5)
		ok(door.swing() == 1.0 and door.depth_footprint(false).is_equal_approx(Rect2(0, 0, StealthDoor.LEAF_TILES, 1)), "and then it is open, back against its frame")
		ok(int(MapFeel.heard.get(&"door_creak", 0)) == creaks + 1, "it creaks as it goes")
		scene.stealth.set_door(door, false, true)
		await wait(StealthDoor.SWING_SECONDS * 2.0)
		ok(door.swing() == 0.0 and int(MapFeel.heard.get(&"door_shut", 0)) == thuds + 1, "shut again, it comes to rest with a thud")
		ok(door.reach_rect().size.y >= Grid.TILE_SIZE, "what is in reach goes round the whole door")
	# A lamp put out.
	var lamps: Array = scene.find_children("*", "Lamp", true, false).filter(func(lamp): return lamp.lit and lamp.can_be_put_out)
	ok(not lamps.is_empty(), "and lamps", "%d" % lamps.size())
	if not lamps.is_empty():
		var lamp: Lamp = lamps[0]
		var smokes := int(MapFeel.made.get(&"smoke", 0))
		ok(lamp.glow() == 1.0, "a lit lamp glows")
		lamp.set_lit(false)
		ok(not lamp.lit and int(MapFeel.made.get(&"smoke", 0)) == smokes + 1, "put out, it is out at once and sends up smoke")
		ok(lamp.glow() > 0.0, "its glow still dying")
		await wait(Lamp.GLOW_OUT_SECONDS * 1.6)
		ok(lamp.glow() == 0.0, "and gone a moment later")
		lamp.set_lit(false)
		ok(int(MapFeel.made.get(&"smoke", 0)) == smokes + 1, "one already out sends up none")
	# In reach.
	scene.party.teleport(doors[0].position + Vector2(0.0, Grid.TILE_SIZE) if not doors.is_empty() else scene.party.leader.position)
	scene._on_party_moved(scene.party.leader.position)
	await settle(3)
	ok(scene.reach_mark != null, "the map has a mark for what is in reach")
	if scene.reach_mark != null:
		ok(scene._current_target != null and scene.reach_mark.target == scene._current_target, "beside a door, the door is marked", "%s" % [scene._current_target])
		ok(scene.reach_mark._word_label.text != "" and scene.reach_mark._key_label.text != "", "with the key and the word beside it", "%s %s" % [scene.reach_mark._key_label.text, scene.reach_mark._word_label.text])
		ok(scene.reach_mark.outline().size.y >= Grid.TILE_SIZE, "and an outline round it")
		scene.party.teleport(scene.party.leader.position + Vector2(0.0, Grid.TILE_SIZE * 6.0))
		scene._on_party_moved(scene.party.leader.position)
		await settle(2)
		ok(scene._current_target == null and scene.reach_mark.target == null, "walked away, nothing is marked")
	# Something taken.
	var pickups: Array = scene.find_children("*", "StealthPickup", true, false).filter(func(pickup): return not pickup.taken)
	if pickups.is_empty():
		log_line("  (nothing to take on this stage: the flight to the bag is checked by hand)")
		var fliers := int(MapFeel.made.get(&"pickup", 0))
		MapFeel.fly_to_bag(scene, null, Vector2(300, 300), Vector2(40, 600))
		ok(int(MapFeel.made.get(&"pickup", 0)) == fliers + 1, "something flies to the bag")
	else:
		var fliers := int(MapFeel.made.get(&"pickup", 0))
		pickups[0].mark_taken()
		ok(pickups[0].taken and int(MapFeel.made.get(&"pickup", 0)) == fliers + 1, "taken, it is gone at once and flies to the bag")
		await wait(MapFeel.PICKUP_RISE_SECONDS + MapFeel.PICKUP_FLY_SECONDS + 0.2)
		ok(int(MapFeel.heard.get(&"picked_up", 0)) >= 1, "landing with a tick")
	# A wall broken.
	var walls: Array = scene.find_children("*", "BreakableWall", true, false).filter(func(wall): return not wall.broken)
	if walls.is_empty():
		log_line("  (no breakable wall on this stage)")
	else:
		var rubble := int(MapFeel.made.get(&"rubble", 0))
		scene.break_wall(walls[0])
		ok(walls[0].broken and int(MapFeel.made.get(&"rubble", 0)) == rubble + 1 and int(MapFeel.made.get(&"hang", 0)) >= 1 and int(MapFeel.heard.get(&"wall_breaks", 0)) >= 1,
			"a wall broken throws rubble, leaves dust hanging and is heard")
	await close(scene)
	MapFeel.plays_headless = false
