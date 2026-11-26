extends Node
## How the game feels, the proposals of 2026-11-16 as built from that day: the comfort dials, the party's weight and its
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
	await depth_next()
	await water()
	await blows()
	await interface_motion()
	await sound_follows()
	await conversations()
	await life_about()
	await the_pad()
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


func depth_next():
	log_line("======== depth, the next steps ========")
	LightView.plays_headless = true
	LightView.sky_ease_seconds = 0.0
	MapFeel.plays_headless = true
	Campaign.reset()
	Campaign.set_clock(12)
	Campaign.set_weather("clear", 5)
	Campaign.current_map = STAGE
	var scene: ExplorationScene = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(scene)
	await settle(8)
	scene.end_blocking_interaction()
	var pieces := {}
	for piece in get_tree().get_nodes_in_group(Depth.PIECES):
		if Depth.same_scene(piece, scene):
			pieces[String(piece.name)] = piece
	var tree: DepthPiece = pieces.get("YardTree")
	ok(tree != null, "the yard's tree")
	if tree != null:
		await settle(4)
		ok(tree.shade_now() > 0.0 and tree._shade != null and tree._shade.visible, "at noon under a clear sky its crown throws a dappled shade", "%.2f" % tree.shade_now())
		ok(tree._shade.get_global_rect().grow(Grid.TILE_SIZE).has_point(tree.global_position), "on the ground about it")
		var still: Vector2 = tree._sway
		Campaign.set_weather("wind", 5)
		await wait(0.6)
		var windy := 0.0
		for i in 30:
			await get_tree().process_frame
			windy = maxf(windy, tree._sway.length())
		ok(LightView.wind_over().length() > 0.3 and windy > still.length() and windy > Grid.TILE_SIZE * DepthPiece.SWAY_TILES * 0.2, "in a wind its crown leans and rocks",
			"%.1f px, still %.1f; wind %.2f" % [windy, still.length(), LightView.wind_over().length()])
		var leaves := int(MapFeel.made.get(&"leaf", 0))
		tree._next_leaves = 0.0
		await settle(3)
		ok(LightView.wind_over().length() < DepthPiece.LEAVES_FROM_WIND or int(MapFeel.made.get(&"leaf", 0)) > leaves, "and in a gale leaves are shaken loose",
			"wind %.2f, %d leaves" % [LightView.wind_over().length(), int(MapFeel.made.get(&"leaf", 0)) - leaves])
		Campaign.set_weather("clear", 5)
		Campaign.set_clock(0)
		await wait(0.5)
		ok(tree.shade_now() < 0.05, "at midnight there is no shade to throw", "%.2f" % tree.shade_now())
		Campaign.set_clock(12)
		await wait(0.3)
	var town: DepthPiece = pieces.get("TownBelow")
	ok(town != null, "the town below")
	if town != null:
		var clear_haze := town.haze_now()
		ok(clear_haze >= DepthPiece.HAZE_ALWAYS - 0.001, "what is far away is a little hazy on a clear day", "%.2f" % clear_haze)
		Campaign.set_weather("fog", 5)
		await wait(0.5)
		ok(town.haze_now() > clear_haze, "and hazier in mist", "%.2f" % town.haze_now())
		Campaign.set_weather("clear", 5)
		await wait(0.3)
	# Things that stand.
	var crate: DepthPiece = pieces.get("YardCrate")
	ok(crate != null and pieces.has("YardPillar") and pieces.has("YardStatue") and pieces.has("YardLampPost") and pieces.has("YardRailing"), "one of each thing that stands, in the yard")
	if crate != null:
		ok(crate.stands() and not tree.stands(), "a crate stands; a tree is not one of these")
		ok(is_equal_approx(crate.stand_height(), DepthPiece.STAND_HEIGHTS[DepthPiece.Kind.CRATE]) and is_equal_approx(crate.drawn_rect().size.y, crate.stand_height()) and is_equal_approx(crate.drawn_rect().end.y, crate.ground_rect().end.y), "drawn standing on the south edge of its tile, as tall as its kind is",
			"%s" % crate.drawn_rect())
		var party: ExplorationParty = scene.party
		var tile := float(Grid.TILE_SIZE)
		party.teleport(crate.position + Vector2(0.0, tile))
		await settle(4)
		ok(party.leader.z_index > crate.z_index, "whoever stands in front of it is drawn over it", "%d over %d" % [party.leader.z_index, crate.z_index])
		ok(crate.cuts_now().is_empty(), "and it is not cut away for them", "%s; leader %s, foot %.0f" % [crate.cuts_now(), party.leader.global_position, crate.foot_in_world()])
		party.teleport(crate.position + Vector2(0.0, -tile))
		await settle(4)
		ok(party.leader.z_index < crate.z_index, "whoever stands behind it is drawn under it", "%d under %d" % [party.leader.z_index, crate.z_index])
		ok(scene.is_walkable(crate.global_position), "it stops nobody by itself: that is the tile's to say")
	var bough: DepthPiece = pieces.get("YardBough")
	ok(bough != null, "and a bough at the screen's edge")
	if bough != null:
		ok(bough.z_index > LightView.SKY_Z and is_equal_approx(bough.moves_now(), Depth.PIECE_MOVES_EDGE), "at the very front, sliding fastest", "z %d, moves %.2f" % [bough.z_index, bough.moves_now()])
		scene.party.teleport(bough.drawn_in_world().get_center())
		await wait(Depth.PIECE_FADE_SECONDS * 2.5)
		ok(bough.fade_now() <= DepthPiece.EDGE_FADED + 0.01, "it fades while one of the party is under it", "%.2f" % bough.fade_now())
		scene.party.teleport(Grid.tile_to_world(Vector2i(12, 12)))
		await wait(Depth.PIECE_FADE_SECONDS * 2.5)
		ok(bough.fade_now() >= 0.99, "and is whole again when they have gone", "%.2f" % bough.fade_now())
	# A step up, on a map: whoever stands on raised ground is drawn up on it.
	var view: DepthView = scene.depth_view
	var raised := Vector2i(15, 18)
	ok(view.height_at(raised) > 0.0, "the terrace is raised ground")
	var hops := int(MapFeel.made.get(&"hop_dust", 0))
	scene.party.teleport(Grid.tile_to_world(raised))
	await wait(DepthView.MAP_HOP_SECONDS * 2.0)
	ok(is_equal_approx(scene.party.leader.ground_lift, view.height_at(raised)), "put on it, somebody is drawn up on it", "%.0f" % scene.party.leader.ground_lift)
	scene.party.teleport(Grid.tile_to_world(Vector2i(12, 20)))
	await wait(DepthView.MAP_HOP_SECONDS * 2.0)
	ok(scene.party.leader.ground_lift == 0.0 and int(MapFeel.made.get(&"hop_dust", 0)) >= hops + 2, "and comes down again, with a puff of dust each way",
		"%d puffs" % (int(MapFeel.made.get(&"hop_dust", 0)) - hops))
	await close(scene)
	LightView.plays_headless = false
	MapFeel.plays_headless = false


func water():
	log_line("======== water, the next steps ========")
	LightView.plays_headless = true
	LightView.sky_ease_seconds = 0.0
	MapFeel.plays_headless = true
	Campaign.reset()
	Campaign.set_clock(12)
	Campaign.set_weather("clear", 5)
	Campaign.current_map = STAGE
	var scene: ExplorationScene = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(scene)
	await settle(8)
	scene.end_blocking_interaction()
	var view: LightView = LightView.showing
	var tile_map: TileMap = scene._tile_map
	ok(view != null and not view._water_tiles.is_empty(), "the Light stage has a pond")
	if view == null or view._water_tiles.is_empty():
		await close(scene)
		return
	# The tile of it furthest from land, and one at its edge.
	var deepest := Vector2i.ZERO
	var most := -1.0
	var shallow := Vector2i.ZERO
	var least := 9.0
	for tile in view._water_tiles:
		var depth := LightView.water_depth_at(tile_map.to_global(tile_map.map_to_local(tile)))
		if depth > most:
			most = depth
			deepest = tile
		if depth < least:
			least = depth
			shallow = tile
	ok(most > 0.0 and most <= 1.0, "it is deeper away from its shore", "%.2f at %s" % [most, deepest])
	var edge: Vector2 = tile_map.to_global(tile_map.map_to_local(shallow))
	var at_the_edge := 9.0
	for corner in [Vector2(-0.49, -0.49), Vector2(0.49, -0.49), Vector2(-0.49, 0.49), Vector2(0.49, 0.49)]:
		at_the_edge = minf(at_the_edge, LightView.water_depth_at(edge + corner * Grid.TILE_SIZE))
	ok(at_the_edge < 0.05, "and has no depth where it meets the land", "%.2f" % at_the_edge)
	ok(LightView.water_depth_at(Grid.tile_to_world(Vector2i(12, 12))) == 0.0, "the yard has none")
	ok(LightView.WATER_SHADER.contains("deep_tiles") and LightView.WATER_SHADER.contains("shore_pale"), "the water's shader darkens it by depth and pales it by the shore")
	# Wading: the water over their legs.
	var leader: CombatantSprite = scene.party.leader
	ok(leader.wading == 0.0, "on dry ground nobody wades")
	var feet_off := LightView.feet_of(leader) - leader.global_position
	scene.party.teleport(tile_map.to_global(tile_map.map_to_local(deepest)) - feet_off)
	await settle(4)
	var knee := leader.wading
	ok(knee > 0.0 and knee <= LightView.WADE_KNEE_TILES * Grid.TILE_SIZE + 0.5, "standing in it, the water is drawn over their legs", "%.0f px" % knee)
	ok(leader.get_node_or_null("Wade") != null and leader.get_node("Wade").visible, "by a part of the figure itself, so it sorts with them")
	scene.party.teleport(edge + Vector2(0.0, 0.0) - feet_off)
	await settle(4)
	ok(leader.wading > 0.0 and leader.wading <= knee, "no deeper nearer the shore", "%.0f px" % leader.wading)
	scene.party.teleport(Grid.tile_to_world(Vector2i(12, 12)))
	await settle(4)
	ok(leader.wading == 0.0 and not leader.get_node("Wade").visible, "out of it, none")
	# Wet prints: out of the water, the next steps leave them.
	var pond_south := Vector2i(deepest.x, deepest.y)
	while view._water_tiles.has(pond_south + Vector2i.DOWN):
		pond_south += Vector2i.DOWN
	scene.party.teleport(tile_map.to_global(tile_map.map_to_local(pond_south)))
	await settle(2)
	var prints := LightView.wet_prints_left
	var walked := 0.0
	while walked < Grid.tiles(3.0):
		var before: Vector2 = scene.party.leader.position
		if not scene.party._step(Vector2.DOWN, 1.0 / 60.0):
			break
		walked += before.distance_to(scene.party.leader.position)
		await get_tree().process_frame
	scene.party._set_walking(false)
	var wet_marks: Array = view._prints.marks.filter(func(mark): return mark.has("wet"))
	ok(LightView.wet_prints_left > prints and not wet_marks.is_empty(), "walking out of the water leaves wet prints", "%d prints over %.1f tiles" % [LightView.wet_prints_left - prints, walked / Grid.TILE_SIZE])
	ok(wet_marks.size() < 2 or float(wet_marks.back().wet) < float(wet_marks.front().wet), "each fainter than the last")
	scene.party.teleport(Grid.tile_to_world(Vector2i(12, 12)))
	await settle(2)
	# The world in it.
	ok(view._mirrored_world != null and view._mirrored_world.visible and is_equal_approx(view._mirrored_world.modulate.a, LightView.MIRROR_WORLD), "the world is mirrored in it, dimly")
	# Something landing in it.
	var splashes := LightView.splashes
	var heard := int(MapFeel.heard.get(&"water_splash", 0))
	var rings: int = view.wades_now().size()
	ok(LightView.land_in_water(tile_map.to_global(tile_map.map_to_local(deepest)), 1.0), "something landing in it is a splash")
	ok(LightView.splashes == splashes + 1 and int(MapFeel.heard.get(&"water_splash", 0)) == heard + 1 and view.wades_now().size() == rings + 1, "seen as a ring, and heard")
	ok(not LightView.land_in_water(Grid.tile_to_world(Vector2i(12, 12)), 1.0) and LightView.splashes == splashes + 1, "and on dry ground it is not")
	await close(scene)
	LightView.plays_headless = false
	MapFeel.plays_headless = false


var game: Node = null
var combat: Combat = null


func open_fight():
	await close_fight()
	Campaign.reset()
	Campaign.set_party(["enfina", "cyrus", "prometheus", "alithia"], 64)
	Campaign.current_map = "res://maps/crossroads_explore.tscn"
	Campaign.return_to_position = true
	var encounter: EncounterDefinition = load("res://data/encounters/encounter_03_watcher.tres").duplicate()
	Campaign.current_encounter = encounter
	game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(6)
	combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(2)
	for comb in combat.combatants:
		comb.reaction_used = true
		comb["accuracy"] = 200
		if comb.has("stats"):
			comb.hp = 900
			comb.max_hp = 900
	for key in ["alithia", "prometheus"]:
		var caster := who(key)
		for gate in caster.spell_slots.size():
			caster.spell_slots[gate] = 5
	await settle()


func close_fight():
	if game != null and is_instance_valid(game):
		game.queue_free()
		await settle(3)
	game = null
	combat = null
	Engine.time_scale = 1.0


func who(key: String) -> Dictionary:
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == key and not comb.get("illusion", false):
			return comb
	return {}


func a_foe() -> Dictionary:
	for comb in combat.combatants:
		if comb.get("side", 0) == 1 and comb.get("alive", false) and comb.has("stats") and not comb.has("object"):
			return comb
	return {}


## A free tile beside `comb`, to its east or its west.
func beside(comb: Dictionary, east: bool) -> Vector2i:
	return comb.position + (Vector2i.RIGHT if east else Vector2i.LEFT)


func blows():
	log_line("======== a blow, from the side of whoever throws it ========")
	# The curve of a strike: back, into it, held, home.
	ok(CombatantSprite.strike_curve(0.0) == 0.0 and is_equal_approx(CombatantSprite.strike_curve(0.3), -1.0) and is_equal_approx(CombatantSprite.strike_curve(CombatantSprite.STRIKE_LANDS), 1.0)
		and is_equal_approx(CombatantSprite.strike_curve(0.55), 1.0) and is_equal_approx(CombatantSprite.strike_curve(1.0), 0.0), "a strike winds back, goes into the blow as it lands, holds and comes home")
	await open_fight()
	var cyrus := who("cyrus")
	var foe := a_foe()
	ok(not cyrus.is_empty() and not foe.is_empty(), "Cyrus and somebody to hit")
	if cyrus.is_empty() or foe.is_empty():
		await close_fight()
		return
	# Headless and not asked to play, none of it happens and nobody waits.
	var before: int = cyrus.sprite.strikes
	ok(MoveFeel.strike(combat, cyrus, SkillDatabase.skills["rapier"], foe.position) == 0.0 and cyrus.sprite.strikes == before, "unseen, nothing of it is played")
	MoveFeel.plays_headless = true
	MoveFeel.felt.clear()
	# Cyrus to the west of the foe, both looking the wrong way.
	var east_free: bool = combat.can_land_on(cyrus, beside(foe, false))
	var spot := beside(foe, not east_free)
	combat.teleport_to(cyrus, spot)
	await settle(2)
	var foe_is_east: bool = foe.position.x > cyrus.position.x
	cyrus.sprite.set_facing(foe_is_east)
	foe.sprite.set_facing(foe_is_east)
	var hp: int = foe.hp
	await combat.use_skill("rapier", cyrus, foe.position, false)
	# His own attack animation shows the blow alone: nothing stepped back and forth on top of it (the designer, 2026-11-21:
	# "because there is already an attack animation, it looks weird"; it was half of the wind-up and the step).
	var own: bool = cyrus.sprite.has_skill_animation(SkillDatabase.skills["rapier"].animation)
	ok(own and cyrus.sprite.strikes == before and int(MoveFeel.felt.get(&"struck", 0)) == 0, "Cyrus's rapier, an attack animation of his own: that alone, no wind-up or step on top", "own %s, %d struck" % [own, cyrus.sprite.strikes - before])
	ok(cyrus.sprite._drawn().flip_h == (not foe_is_east), "he turns to face what he aims at")
	ok(foe.hp < hp, "the blow lands as ever", "%d -> %d" % [hp, foe.hp])
	ok(foe.sprite._drawn().flip_h == foe_is_east, "and whoever is hit turns to whoever hit them")
	var lands: float = MoveFeel.strike(combat, cyrus, SkillDatabase.skills["rapier"], foe.position)
	ok(lands == 0.0 and cyrus.sprite.strikes == before, "over his own animation nothing is waited for", "%.2f s" % lands)
	# Somebody with no animation of their own for it (his frames swapped for some with none) winds up and goes into the blow.
	cyrus.sprite.show_as(SpriteFrames.new())
	var bare_lands: float = MoveFeel.strike(combat, cyrus, SkillDatabase.skills["rapier"], foe.position)
	ok(bare_lands > 0.0 and cyrus.sprite.strikes == before + 1 and int(MoveFeel.felt.get(&"struck", 0)) == 1, "without one, he winds up and goes into the blow, and is given the moment it takes", "%.2f s" % bare_lands)
	await wait(CombatantSprite.STRIKE_SECONDS + 0.3)
	ok(cyrus.sprite._drawn().rotation == 0.0 and cyrus.sprite._drawn().position.distance_to(cyrus.sprite.size_offset) < 0.01, "afterwards he stands as he stood")
	ok(cyrus.position == spot, "and never left his tile: only the picture moved")
	cyrus.sprite.end_strike()
	cyrus.sprite.show_as(null)
	# A spell gathers its light; a blade does not.
	var gathered := int(MoveFeel.felt.get(&"gathered", 0))
	var alithia := who("alithia")
	# Played as the fight plays a move, whether or not she could reach him from where she stands; with no animation of her own, so
	# that a lunge would show.
	alithia.sprite.show_as(SpriteFrames.new())
	var alithia_struck: int = alithia.sprite.strikes
	await combat._play_the_move(alithia, SkillDatabase.skills["sleep"], foe.position)
	ok(int(MoveFeel.felt.get(&"gathered", 0)) == gathered + 1, "a spell lights its caster as it gathers")
	ok(alithia.sprite.strikes == alithia_struck, "and one that hurts nobody is not a blow: she does not lunge")
	alithia.sprite.show_as(null)
	await combat._play_the_move(cyrus, SkillDatabase.skills["rapier"], foe.position)
	ok(int(MoveFeel.felt.get(&"gathered", 0)) == gathered + 1, "a rapier gathers none")
	# Resisted and vulnerable, felt.
	combat.show_damage(foe, 5, Damage.Type.FIRE, false, {"resisted": true})
	combat.show_damage(foe, 5, Damage.Type.FIRE, false, {"vulnerable": true})
	combat.show_damage(foe, 5, Damage.Type.FIRE, false, {})
	ok(int(MoveFeel.felt.get(&"resisted", 0)) == 1 and int(MoveFeel.felt.get(&"vulnerable", 0)) == 1, "a blow resisted and one they are vulnerable to are each felt, and a plain one is neither")
	# Each is an experiment with a switch.
	MoveFeel.strikes = false
	MoveFeel.faces = false
	MoveFeel.gathers = false
	MoveFeel.tells = false
	var struck: int = cyrus.sprite.strikes
	MoveFeel.felt.clear()
	cyrus.sprite.set_facing(foe_is_east)
	await combat.use_skill("rapier", cyrus, foe.position, false)
	combat.show_damage(foe, 5, Damage.Type.FIRE, false, {"resisted": true})
	ok(cyrus.sprite.strikes == struck and MoveFeel.felt.is_empty() and cyrus.sprite._drawn().flip_h == foe_is_east, "switched off, none of it is played")
	MoveFeel.strikes = true
	MoveFeel.faces = true
	MoveFeel.gathers = true
	MoveFeel.tells = true
	MoveFeel.plays_headless = false
	await close_fight()


## Section 8, the interface in motion (UiFeel): each thing happens, comes back to the size the game keeps it at (never to 1),
## and headless nothing moves.
func interface_motion():
	log_line("======== the interface in motion ========")
	UiFeel.plays_headless = true
	var holder := Control.new()
	get_tree().root.add_child(holder)
	# Buttons that answer, about their own size: one the game keeps bigger comes back to that.
	var button := Button.new()
	button.text = "Try"
	holder.add_child(button)
	await settle(2)
	button.scale = Vector2(1.25, 1.25)
	button.mouse_entered.emit()
	await wait(0.2)
	ok(button.scale.is_equal_approx(Vector2.ONE * 1.25 * UiFeel.HOVER), "a button swells under the pointer, from its own size", "%s" % button.scale)
	button.mouse_exited.emit()
	await wait(0.2)
	ok(button.scale.is_equal_approx(Vector2.ONE * 1.25), "and comes back to it, not to 1", "%s" % button.scale)
	button.button_down.emit()
	await wait(0.2)
	ok(button.scale.x < 1.25, "pressed, it dips", "%s" % button.scale)
	button.button_up.emit()
	await wait(0.2)
	ok(button.scale.is_equal_approx(Vector2.ONE * 1.25), "let go, it is back at its own size", "%s" % button.scale)
	# Back in the tree again, moved to another parent: its signals are not connected a second time.
	var connected := button.mouse_entered.get_connections().size()
	holder.remove_child(button)
	holder.add_child(button)
	ok(button.mouse_entered.get_connections().size() == connected, "a button come back into the tree is not connected twice", "%d" % button.mouse_entered.get_connections().size())
	# A press on a button that cannot be pressed: it shakes its head.
	var shut := Button.new()
	shut.text = "No"
	shut.disabled = true
	holder.add_child(shut)
	await settle(1)
	var refused := int(UiFeel.seen.get(&"refused", 0))
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	shut.gui_input.emit(press)
	await wait(0.1)
	var shaking: float = shut.rotation
	await wait(0.4)
	ok(int(UiFeel.seen.get(&"refused", 0)) == refused + 1 and not is_zero_approx(shaking) and is_zero_approx(shut.rotation),
		"a press it cannot take: it shakes its head and comes to rest", "%.3f, then %.3f" % [shaking, shut.rotation])
	# Panels that arrive: faded in, their size and pivot left as the interface's scale set them.
	var panel := PanelContainer.new()
	panel.visible = false
	holder.add_child(panel)
	panel.scale = Vector2(1.3, 1.3)
	await settle(1)
	var arrived := int(UiFeel.seen.get(&"arrived", 0))
	panel.visible = true
	await settle(1)
	var arriving: float = panel.modulate.a
	await wait(0.3)
	ok(int(UiFeel.seen.get(&"arrived", 0)) == arrived + 1 and arriving < 0.99 and is_equal_approx(panel.modulate.a, 1.0), "a panel coming up fades in",
		"%.2f, then %.2f" % [arriving, panel.modulate.a])
	ok(panel.scale.is_equal_approx(Vector2(1.3, 1.3)) and panel.pivot_offset == Vector2.ZERO, "and is never resized or moved: the HUD's parts are scaled by the interface's size",
		"%s about %s" % [panel.scale, panel.pivot_offset])
	# Whose turn: the action bar deals itself in, one button after the next.
	var bar := HBoxContainer.new()
	holder.add_child(bar)
	var dealt := []
	for i in 4:
		var one := Button.new()
		one.text = str(i)
		bar.add_child(one)
		dealt.append(one)
	await settle(2)
	UiFeel.deal_in(dealt)
	ok(dealt[3].modulate.a < 0.5, "a turn's action bar deals itself in: the last button is not there yet", "%.2f" % dealt[3].modulate.a)
	await wait(0.5)
	ok(dealt.all(func(one): return is_equal_approx(one.modulate.a, 1.0) and one.scale.is_equal_approx(Vector2.ONE)), "then all of it is, each at its own size")
	# The pointer crossing the bar as it deals in takes over the size only, never the fade (the designer, 2026-11-20: four of Cyrus's
	# slots went empty as his turn began, "Nothing where the skills were").
	UiFeel.deal_in(dealt)
	for one in dealt:
		UiFeel._hover(one, true)
		UiFeel._hover(one, false)
	UiFeel._press(dealt[2], true)
	UiFeel._press(dealt[2], false)
	await wait(0.5)
	ok(dealt.all(func(one): return is_equal_approx(one.modulate.a, 1.0) and one.scale.is_equal_approx(Vector2.ONE)),
		"the pointer going over the bar as it deals in leaves every button whole", "%s" % [dealt.map(func(one): return snappedf(one.modulate.a, 0.01))])
	# And one left see-through by a deal cut short is dealt again with the next, not left so for the rest of the fight.
	UiFeel.deal_in(dealt)
	var cut = dealt[1].get_meta(&"_feel_deal")
	cut.kill()
	ok(dealt[1].modulate.a < 0.99 and UiFeel.deal_left_unfinished(dealt[1]), "(a deal cut short leaves a button see-through)", "%.2f" % dealt[1].modulate.a)
	UiFeel.deal_in(dealt)
	await wait(0.5)
	ok(dealt.all(func(one): return is_equal_approx(one.modulate.a, 1.0)), "and the next deal brings it back whole")
	# And their face steps forward in the queue, settling where the current face stands.
	var face = load("res://ui/tq_icon.tscn").instantiate()
	holder.add_child(face)
	await settle(2)
	var stepped := int(UiFeel.seen.get(&"stepped", 0))
	face.set_current(true, 0)
	await wait(0.05)
	var swelling: float = face.scale.x
	await wait(0.45)
	ok(int(UiFeel.seen.get(&"stepped", 0)) == stepped + 1 and not is_equal_approx(swelling, 1.15) and is_equal_approx(face.scale.x, 1.15),
		"whose turn it is: their face steps forward and settles where the current face stands", "%.3f, then %.3f" % [swelling, face.scale.x])
	# Numbers that count.
	var label := Label.new()
	holder.add_child(label)
	await settle(1)
	UiFeel.count_to(label, 10, func(shown: int) -> String: return "%d gold" % shown)
	ok(label.text == "10 gold", "a number is written at once the first time", label.text)
	UiFeel.count_to(label, 40, func(shown: int) -> String: return "%d gold" % shown)
	await wait(0.1)
	var counting := label.text
	await wait(0.45)
	ok(counting != "10 gold" and counting != "40 gold" and label.text == "40 gold", "after that it counts to the new one", "%s on the way" % counting)
	# A number that changes pops, and is back at its own size.
	var tag := Label.new()
	tag.text = "3"
	holder.add_child(tag)
	tag.scale = Vector2(0.9, 0.9)
	await settle(1)
	UiFeel.pop(tag)
	await wait(0.05)
	var popping: float = tag.scale.x
	await wait(0.35)
	ok(popping > 0.9 and tag.scale.is_equal_approx(Vector2(0.9, 0.9)), "a number that changes pops, and is back at its own size", "%.3f, then %.3f" % [popping, tag.scale.x])
	# Headless, nothing moves and a number is simply written.
	UiFeel.plays_headless = false
	button.mouse_entered.emit()
	await settle(3)
	UiFeel.count_to(label, 5, func(shown: int) -> String: return "%d gold" % shown)
	ok(button.scale.is_equal_approx(Vector2.ONE * 1.25) and label.text == "5 gold", "headless, nothing moves, and a number is written at once")
	holder.queue_free()
	await settle(2)
	log_line("")


## Section 9, sound that follows the picture (SoundFollows): what the picture asks of the sound, by moment and by place, and that
## the buses' own effects follow it.
func sound_follows():
	log_line("======== sound that follows the picture ========")
	var follows: SoundFollows = SoundFollows._self
	ok(follows != null and is_instance_valid(follows) and follows.get_parent() == Music, "it is there on every screen, under the music")
	if follows == null or not is_instance_valid(follows):
		return
	Engine.time_scale = 1.0
	ok(follows.wants().hz == SoundFollows.CLEAR_HZ, "with nothing in the way it is clear", "%s" % [follows.wants()])
	MenuPause.hold(self)
	ok(follows.wants().hz == SoundFollows.MENU_HZ, "behind a menu, the music and the world are muffled")
	MenuPause.release(self)
	Engine.time_scale = 0.4
	ok(follows.wants().hz == SoundFollows.SLOW_HZ, "in slow motion, muffled less")
	Engine.time_scale = 1.0
	SoundFollows.give_way(0.3)
	ok(follows.wants().dip == SoundFollows.GIVE_WAY_DB, "the music gives way")
	await wait(0.9)
	ok(follows.wants().dip == 0.0, "and comes back")
	# Heard: the low-pass on the buses eases down behind a menu and up again.
	SoundFollows.plays_headless = true
	MenuPause.hold(self)
	await wait(1.2)
	var muffled: float = follows.cutoff
	MenuPause.release(self)
	await wait(1.8)
	ok(muffled < 2000.0 and follows.cutoff > 15000.0 and is_equal_approx(follows._music_muffle.cutoff_hz, follows.cutoff) and is_equal_approx(follows._world_muffle.cutoff_hz, follows.cutoff),
		"the music's and the world's low-pass ease down behind a menu and up again", "%.0f Hz, then %.0f" % [muffled, follows.cutoff])
	SoundFollows.plays_headless = false
	# By place, on the Light stage.
	LightView.plays_headless = true
	LightView.sky_ease_seconds = 0.0
	var scene := await open_map(STAGE)
	Campaign.set_clock(12)
	Campaign.set_weather("clear", 5)
	await wait(0.4)
	# Headless the map's camera does not follow: it is put on the leader, as the camera's own checks above do.
	scene.party.teleport(Grid.tile_to_world(Vector2i(8, 15)))
	scene.camera.position = scene.party.leader.position
	await settle(4)
	var yard := follows.wants()
	ok(yard.wet == 0.0 and yard.bed == &"" and yard.hz == SoundFollows.CLEAR_HZ, "out in the yard: no echo, no bed, clear", "%s" % [yard])
	scene.party.teleport(Grid.tile_to_world(Vector2i(24, 14)))
	scene.camera.position = scene.party.leader.position
	await settle(4)
	var hall := follows.wants()
	ok(hall.wet == SoundFollows.ECHO_HALL and hall.bed == &"indoors", "in the hall: an echo, and the room's own bed", "%s" % [hall])
	Campaign.set_weather("rain", 5)
	await wait(0.6)
	ok(follows.wants().hz == SoundFollows.RAIN_INDOORS_HZ, "indoors while it rains outside, muffled", "%s" % [follows.wants()])
	Campaign.set_weather("clear", 5)
	await wait(0.4)
	var watch = Campaign.stealth_watch
	ok(watch != null, "the stage is watched")
	if watch != null:
		watch.alert = StealthWatch.ALERT_WARY
		var wary: int = follows.wants().danger
		watch.alert = StealthWatch.ALERT_ALARMED
		var alarmed: int = follows.wants().danger
		watch.alert = 0.0
		ok(wary == 1 and alarmed == 2 and follows.wants().danger == 0, "the map on edge: a pulse, faster when Alarmed, none when calm", "%d, %d" % [wary, alarmed])
	LightView.plays_headless = false
	LightView.sky_ease_seconds = 2.5
	await close(scene)
	# A voice for each speaker.
	ok(SoundFollows.voice_pitch("Cyrus") < 1.0 and SoundFollows.voice_pitch("Alithia") > 1.0 and SoundFollows.voice_pitch("A Guard") == SoundFollows.voice_pitch("A Guard"),
		"each speaker's ticks have a pitch of their own, the same every time")
	var ticks := int(MapFeel.heard.get(&"voice_tick", 0))
	var letters := ["A", "b", " ", "c", "!", "d", "e"]
	for i in letters.size():
		SoundFollows.voice("Cyrus", letters[i], i)
	ok(int(MapFeel.heard.get(&"voice_tick", 0)) - ticks == 2, "a tick every second letter, none for a space or a mark", "%d" % (int(MapFeel.heard.get(&"voice_tick", 0)) - ticks))
	log_line("")


## Section 10, conversations: the speaker steps up (lit, the others dimmed, put back after), the bars for the lines that matter,
## and the camera's slow push over a long exchange.
func conversations():
	log_line("======== conversations ========")
	UiFeel.plays_headless = true
	# The map's camera eases only if it may move headless when the map opens.
	CameraController.moves_headless = true
	var scene := await open_map(LAB)
	var cyrus = Actors.figure_of("Cyrus")
	var alithia = Actors.figure_of("Alithia")
	ok(cyrus is CombatantSprite and alithia is CombatantSprite and Actors.figure_of("Nobody Here") == null, "a speaker's figure is found by name, and nobody is made up for one who is not there")
	if cyrus is CombatantSprite and alithia is CombatantSprite:
		cyrus.set_talk_tint(Color(0.5, 0.5, 0.5))
		var drawn: Node2D = cyrus._drawn()
		ok(drawn.self_modulate.r < 0.6, "a conversation's tint is multiplied into how the figure is drawn", "%s" % drawn.self_modulate)
		cyrus.set_talk_tint(Color.WHITE)
		var balloon = load("res://ui/dialogue_balloon.tscn").instantiate()
		get_tree().root.add_child(balloon)
		await settle(2)
		balloon._step_up("Cyrus")
		await wait(0.4)
		var lit: Color = cyrus.talk_tint
		balloon._step_up("Alithia")
		await wait(0.4)
		ok(lit.r > 1.0 and alithia.talk_tint.r > 1.0 and cyrus.talk_tint.r < 0.8, "whoever speaks is lit, and whoever spoke before is dimmed", "%s, then %s and %s" % [lit, alithia.talk_tint, cyrus.talk_tint])
		DialogueBalloon.speaker_steps_up = false
		balloon._step_up("Cyrus")
		await wait(0.4)
		ok(cyrus.talk_tint.r < 0.8, "and with its switch off, nobody is lit or dimmed any more")
		DialogueBalloon.speaker_steps_up = true
		balloon._show_bars(true)
		await wait(0.6)
		var bars_in: bool = balloon.bars_shown()
		balloon._show_bars(false)
		await wait(0.6)
		ok(bars_in and not balloon.bars_shown(), "a line that matters brings bars in at the top and the bottom, and the next takes them away")
		balloon.queue_free()
		await wait(0.5)
		ok(cyrus.talk_tint.is_equal_approx(Color.WHITE) and alithia.talk_tint.is_equal_approx(Color.WHITE), "the conversation over, everybody is as they were",
			"%s, %s" % [cyrus.talk_tint, alithia.talk_tint])
	# The camera listens: over a long exchange it pushes in, a little at a time.
	var hold := RefCounted.new()
	Coop._talks.append([hold, 0])
	await wait(3.0)
	var pushing: float = scene._talk_seconds
	var room: float = scene.view_feel().room
	Coop._end_talk(hold)
	await wait(0.3)
	ok(pushing > 2.0 and room > 0.0 and scene._talk_seconds == 0.0, "while they talk the camera pushes in slowly, and lets go after", "%.1f s, %.4f" % [pushing, room])
	CameraController.moves_headless = false
	UiFeel.plays_headless = false
	await close(scene)
	log_line("")


## Section 11, life about the place (MapLife, the moths, the banners): each thing happens, and keeps to where it belongs.
func life_about():
	log_line("======== life about the place ========")
	MapLife.plays_headless = true
	LightView.plays_headless = true
	LightView.sky_ease_seconds = 0.0
	var scene := await open_map(STAGE)
	Campaign.set_clock(12)
	Campaign.set_weather("clear", 5)
	await wait(0.4)
	var lives := {}
	for life in get_tree().get_nodes_in_group(MapLife.GROUP):
		lives[String(life.name)] = life
	ok(lives.has("YardBirds") and lives.has("GrassByTheGate") and lives.has("WallCat") and lives.has("TorchBearerChatter"),
		"the Light stage has birds, grass, a cat on its wall and a guard who talks to himself", "%s" % [lives.keys()])
	var birds: MapLife = lives.get("YardBirds")
	if birds != null:
		ok(birds.members().size() == birds.count and birds.members().all(func(one): return one.state == &"here"), "the birds peck about, the party far off")
		scene.party.teleport(birds.to_global(birds.ground().get_center()))
		await wait(0.5)
		ok(birds.members().all(func(one): return one.state == &"off"), "the party comes near: they take off")
		scene.party.teleport(Grid.tile_to_world(Vector2i(3, 21)))
		for one in birds._members:
			one.time = 0.0
		await wait(0.3)
		ok(birds.members().all(func(one): return one.state == &"here"), "and once the party has gone, they come back")
	var grass: MapLife = lives.get("GrassByTheGate")
	if grass != null:
		var tuft: Dictionary = grass.members()[0]
		scene.party.teleport(grass.to_global(tuft.at) + Vector2(-Grid.tiles(0.25), 0.0))
		await wait(0.6)
		ok(grass.members()[0].bend > 0.2, "grass bends away from whoever stands in it", "%.2f" % grass.members()[0].bend)
		scene.party.teleport(Grid.tile_to_world(Vector2i(12, 20)))
		await wait(0.8)
		MapLife.blast_at(get_tree(), grass.to_global(grass.ground().get_center()) + Vector2(Grid.tiles(1.5), 0.0), 1.0)
		await wait(0.1)
		ok(grass.members().any(func(one): return one.bend < -0.15), "and away from a blast beside it", "%s" % [grass.members().map(func(one): return snappedf(one.bend, 0.01))])
	var banner: WindBanner = null
	for one in get_tree().get_nodes_in_group(WindBanner.GROUP):
		if String(one.name) == "YardBanner":
			banner = one
	if banner != null:
		scene.party.teleport(banner.global_position + Vector2(-Grid.tiles(0.4), 0.0))
		await wait(0.2)
		ok(banner.pushed().x > 0.1, "a banner is brushed aside by whoever walks by it", "%s" % banner.pushed())
	var chatter: MapLife = lives.get("TorchBearerChatter")
	if chatter != null:
		SpeechBubbles.plays_headless = true
		var guard = chatter.get_node_or_null(chatter.speaker)
		chatter.say_next()
		await settle(2)
		ok(guard != null and SpeechBubbles.bubble_over(guard) != null, "the guard says one of his lines in a bubble over himself")
		SpeechBubbles.plays_headless = false
	# Moths at the yard's lamps: at night, not at noon.
	var moths_now := func() -> int:
		var flying := 0
		for entry in LightView.showing._lights:
			var moths = entry.get("moths")
			if moths != null and is_instance_valid(moths) and moths.emitting:
				flying += 1
		return flying
	var by_day: int = moths_now.call()
	Campaign.set_clock(23)
	await wait(1.5)
	var by_night: int = moths_now.call()
	ok(by_day == 0 and by_night > 0, "moths circle the lamps at night, and not by day", "%d by day, %d at night" % [by_day, by_night])
	Campaign.set_clock(12)
	await close(scene)
	# The lab's rats keep to its floor.
	scene = await open_map(LAB)
	await wait(0.3)
	var rats: MapLife = null
	for life in get_tree().get_nodes_in_group(MapLife.GROUP):
		if String(life.name) == "LabRats":
			rats = life
	ok(rats != null and rats.members().size() == rats.count, "rats in the laboratory")
	if rats != null:
		var tile_map: TileMap = scene._tile_map
		var on_floor := rats.members().all(func(one): return Depth.kind_at(tile_map, tile_map.local_to_map(tile_map.to_local(rats.to_global(one.at)))) == Depth.Kind.FLOOR)
		ok(on_floor, "and they keep to its floor")
	await close(scene)
	MapLife.plays_headless = false
	LightView.plays_headless = false
	LightView.sky_ease_seconds = 2.5
	log_line("")


## Section 7, the pad in your hands: rumble for blows and for somebody near death, a click a moment early kept and acted on.
func the_pad():
	log_line("======== the pad in your hands ========")
	await open_fight()
	var cyrus := who("cyrus")
	var asked: int = Rumble.asked
	combat.show_damage(cyrus, 90, Damage.Type.PHYSICAL)
	var light: Dictionary = Rumble.last.duplicate()
	combat.show_damage(cyrus, 450, Damage.Type.PHYSICAL)
	var heavy: Dictionary = Rumble.last.duplicate()
	ok(Rumble.asked == asked + 2 and light.get("kind") == &"tap" and heavy.get("kind") == &"thump", "a blow is a tap in the hands, a heavy one a thump", "%s, %s" % [light, heavy])
	combat.show_damage(cyrus, 3, Damage.Type.PHYSICAL)
	ok(Rumble.asked == asked + 2, "and a scratch is nothing")
	# Near death, a heartbeat.
	cyrus.hp = int(cyrus.max_hp * 0.1)
	Rumble.last = {}
	await settle(4)
	ok(Rumble.last.get("kind") == &"heart", "with one of the party near death, a heartbeat", "%s" % [Rumble.last])
	cyrus.hp = cyrus.max_hp
	# A click let go of a moment before the end of what was playing is kept, and acted on as it ends.
	var controller: CController = combat.controller
	controller.set_controlled_combatant(cyrus)
	controller.player_turn = true
	controller.action_locked = true
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	controller._unhandled_input(release)
	var kept: bool = controller.early_click_kept()
	controller.action_locked = false
	await settle(3)
	ok(kept and not controller.early_click_kept(), "a click a moment early is kept, and acted on as what was playing ends")
	controller.action_locked = true
	controller._unhandled_input(release)
	await wait(0.35)
	ok(not controller.early_click_kept(), "and one longer before that is let go")
	controller.action_locked = false
	await close_fight()
	log_line("")
