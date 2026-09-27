extends Node
## The demos are playable as shipped: the stealth demo's guards can walk their
## patrols, the goal can be reached from the start, the map is its battle
## terrain tile for tile, and its locker, notice board and pictures are wired
## to things that exist.

var LOG_PATH := HarnessLog.path_for("demos")
const DEMO := "res://scenes/stealth_demo.tscn"

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


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


func run_test():
	log_line("======== the launcher points at the demo ========")
	var launcher = load("res://scenes/try_stealth_demo.tscn").instantiate()
	ok(launcher.map == DEMO and ResourceLoader.exists(launcher.map), "F6 on try_stealth_demo opens the demo map", launcher.map)
	launcher.free()

	log_line("======== the stealth demo comes up watched ========")
	Campaign.reset()
	Campaign.current_map = DEMO
	var scene: ExplorationScene = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(scene)
	await settle(4)
	var tile_map: TileMap = scene._tile_map
	var watch: StealthWatch = scene.stealth
	ok(watch != null, "it is a stealth map")
	ok(watch != null and watch.guards.size() == 3, "with three guards", "%d" % (watch.guards.size() if watch else 0))
	ok(Campaign.party_members().size() == 1 and Campaign.party_members()[0].key == "cyrus", "Cyrus alone")
	var tile = func(node: Node2D) -> Vector2i: return tile_map.local_to_map(tile_map.to_local(node.global_position))
	var on_floor = func(at: Vector2i) -> bool: return scene.is_walkable(tile_map.to_global(tile_map.map_to_local(at)))
	var start: Vector2i = tile_map.local_to_map(scene.party_position())
	ok(on_floor.call(start), "the party starts on floor", "%s" % start)

	log_line("======== the map is its battle terrain ========")
	var blocked = watch._battle_blocking()
	var differ := []
	var region: Rect2i = tile_map.get_used_rect()
	for x in range(region.position.x, region.end.x):
		for y in range(region.position.y, region.end.y):
			var at := Vector2i(x, y)
			if on_floor.call(at) == blocked.has(at) and differ.size() < 5:
				differ.append(at)
	ok(differ.is_empty(), "every tile walkable on the map is walkable in the fight, and no other", "%s" % [differ])

	log_line("======== every guard can walk their beat ========")
	for guard in watch.guards:
		ok(on_floor.call(tile.call(guard)), "%s starts on floor" % guard.name, "%s" % tile.call(guard))
		var points := []
		for waypoint in guard.patrol:
			var at = Actors.waypoint_position(waypoint)
			ok(at != null, "  their waypoint '%s' exists" % waypoint)
			if at != null:
				points.append(at)
				ok(on_floor.call(tile_map.local_to_map(tile_map.to_local(at))), "  and is on floor")
		for i in range(1, points.size()):
			var route: Array = Actors.route(points[i - 1], points[i])
			ok(not route.is_empty() and route.back().distance_to(points[i]) < 1.0, "  and there is a way between them",
				"%d steps" % route.size())

	log_line("======== the goal can be reached ========")
	var goal: Node2D = scene.get_node("Map/Goal")
	var path: Array = Actors.route(scene.party_position(), goal.global_position)
	ok(not path.is_empty() and path.back().distance_to(goal.global_position) < 1.0, "a way from the start to the goal",
		"%d steps" % path.size())
	for called in ["Locker", "NoticeBoard", "Goal"]:
		var node: Node2D = scene.get_node("Map/%s" % called)
		ok(on_floor.call(tile.call(node)), "%s stands somewhere it can be reached" % called, "%s" % tile.call(node))

	log_line("======== the locker, the board and the pictures ========")
	var locker: DialogueInteractable = scene.get_node("Map/Locker")
	var dialogue = locker.dialogue
	ok(dialogue != null and dialogue.get_cues().has("locker") and dialogue.get_cues().has("goal") and dialogue.get_cues().has("pouch"),
		"the demo conversation has the locker, the goal and the pouch in it")
	var board: PictureInteractable = scene.get_node("Map/NoticeBoard")
	ok(ResourceLoader.exists(board.picture), "the notice board has a picture", board.picture)
	Pictures.leave_for_map = false
	Pictures.open(board.picture)
	await settle()
	var shown: Picture = Pictures.current()
	ok(shown != null and shown.title == "The Guard Room", "which opens", shown.title if shown else "none")
	var box: Hotspot = shown.get_node("StrongboxSpot")
	ok(box.takes_item == "tiny_bomb" and ItemDatabase.item("tiny_bomb") != null, "its strongbox takes the Tiny Bomb the locker hands out")
	ok(not shown.get_node("PouchSpot").visible and not shown.get_node("OpenBox").visible, "shut until then")
	var scrap: Hotspot = shown.get_node("ScrapSpot")
	ok(ResourceLoader.exists(scrap.opens_picture), "the scrap of map opens its own picture")
	Pictures.click(scrap)
	await settle()
	ok(Pictures.current() != shown and Pictures.current().title == "A Scrap of Map", "which it does")
	Pictures.close()
	await settle()

	log_line("======== caught in the demo, the fight is on real floor ========")
	watch.leave_for_battle = false
	var fight = watch.build_fight()
	var fighters = fight.spawns.filter(func(s): return s.side == 0)
	var guards = fight.spawns.filter(func(s): return s.side == 1)
	ok(fighters.size() == 1 and guards.size() == 3, "Cyrus and the three guards", "%d and %d" % [fighters.size(), guards.size()])
	var bad := []
	for spawn in fight.spawns:
		if blocked.has(spawn.position):
			bad.append(spawn.position)
	ok(bad.is_empty(), "every one of them on floor the lab fight has", "%s" % [bad])
	scene.queue_free()
	await settle()

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
