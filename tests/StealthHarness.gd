extends Node
## What the stealth suites share: a crossroads made a stealth map to play each
## section out on, and the helpers for putting guards on it and doing things
## to them. A driver extends this, names its suite and writes run_sections():
##
##     extends "res://StealthHarness.gd"
##
##     func suite() -> String:
##         return "alarm"
##
##     func run_sections():
##         await something()
##
## Copied beside the drivers by the runner, the way HarnessLog is.

const MAP := "res://scenes/explore_crossroads.tscn"
const TERRAIN := "res://scenes/crossroads_terrain.tscn"
const BALLOON := "res://ui/dialogue_balloon.tscn"
const NOWHERE := Vector2i(-99999, -99999)

var _log: FileAccess = null
var _fail = 0


## The suite's name, for its log. Every driver says.
func suite() -> String:
	return "stealth"


## How long the whole suite may take before it is called stuck.
func time_limit() -> float:
	return 240.0


## The sections, in order.
func run_sections():
	pass


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
	_log = FileAccess.open(HarnessLog.path_for(suite()), FileAccess.WRITE)
	get_tree().create_timer(time_limit(), true, false, true).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_sections()
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


func wait(seconds: float):
	await get_tree().create_timer(seconds).timeout


## Waits up to `seconds` for `condition` to hold. True if it did.
func until(condition: Callable, seconds: float) -> bool:
	var waited := 0.0
	while waited < seconds:
		if condition.call():
			return true
		await get_tree().process_frame
		waited += get_process_delta_time()
	return condition.call()


## --- The map every section is played on ---


## A fresh crossroads with a StealthSetup on it and nobody watching yet. Put
## guards and whatever else on it, then watch_it().
func open_map() -> Dictionary:
	Campaign.reset()
	Campaign.current_map = MAP
	var scene: ExplorationScene = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(scene)
	await settle(4)
	scene.end_blocking_interaction()
	var m := {}
	m.scene = scene
	m.map = scene.get_node("Map")
	m.tile_map = scene._tile_map
	m.sight = StealthSight.new(m.tile_map)
	m.party = scene.party
	m.leader = Campaign.party_members()[0].key
	m.post = find_post(m, m.tile_map.local_to_map(m.party.position_of_leader()))
	var setup := StealthSetup.new()
	setup.battle_terrain = load(TERRAIN)
	m.map.add_child(setup)
	m.setup = setup
	return m


func watch_it(m: Dictionary, party_tile: Vector2i) -> StealthWatch:
	m.party.teleport(at(m, party_tile))
	m.scene.begin_stealth()
	var watch: StealthWatch = m.scene.stealth
	watch.leave_for_battle = false
	m.away = party_tile
	await settle()
	return watch


func close_map(m: Dictionary):
	for node in get_tree().root.find_children("*", "", true, false):
		if node.scene_file_path == BALLOON:
			node.queue_free()
	m.scene.queue_free()
	await settle()
	Engine.time_scale = 1.0
	log_line("")


func at(m: Dictionary, tile: Vector2i) -> Vector2:
	return m.tile_map.to_global(m.tile_map.map_to_local(tile))


func tile_at(m: Dictionary, where: Vector2) -> Vector2i:
	return m.tile_map.local_to_map(m.tile_map.to_local(where))


func add_guard(m: Dictionary, called: String, tile: Vector2i, facing: float = 0.0, key: String = "barbarian") -> Guard:
	var guard := Guard.new()
	guard.name = called
	guard.display_name = called
	guard.combatant_key = key
	guard.level = 2
	guard.facing_degrees = facing
	guard.looks_around = false
	m.map.add_child(guard)
	guard.global_position = at(m, tile)
	return guard


func add_spot(m: Dictionary, tile: Vector2i) -> HidingSpot:
	var spot := HidingSpot.new()
	m.map.add_child(spot)
	spot.global_position = at(m, tile)
	return spot


## Anything placed on a tile of the map: a lamp, a door, a plate.
func place(m: Dictionary, node: Node2D, tile: Vector2i, called: String = "") -> Node2D:
	if called != "":
		node.name = called
	m.map.add_child(node)
	node.global_position = at(m, tile)
	return node


## Back to calm: nobody sure of anything, on their post and looking along it.
func settle_guard(watch: StealthWatch, guard: Guard, facing: float = 0.0):
	watch.suspicion[guard] = 0.0
	guard.mood = Guard.Mood.PATROLLING
	guard.facing_degrees = facing


## A click on the map at `where`, a world position, as the watch hears it.
func click(watch: StealthWatch, where: Vector2, button: MouseButton):
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.position = watch.get_canvas_transform() * where
	watch._unhandled_input(event)


func press(bar: StealthBar, keycode: Key):
	var key := InputEventKey.new()
	key.physical_keycode = keycode
	key.pressed = true
	bar._unhandled_key_input(key)


func standable(m: Dictionary, tile: Vector2i) -> bool:
	return m.scene.is_walkable(at(m, tile))


func gap(a: Vector2i, b: Vector2i) -> float:
	return Vector2(b - a).length()


## The first tile anybody can stand on that `wanted` says yes to.
func find_tile(m: Dictionary, wanted: Callable) -> Vector2i:
	var region: Rect2i = m.sight.region()
	for x in range(region.position.x, region.end.x):
		for y in range(region.position.y, region.end.y):
			var tile := Vector2i(x, y)
			if standable(m, tile) and wanted.call(tile):
				return tile
	return NOWHERE


## Somewhere none of `from` has a line to, and well away from all of them -
## out of sight, earshot and smell.
func out_of_sight_of(m: Dictionary, from: Array) -> Vector2i:
	var region: Rect2i = m.sight.region()
	for x in range(region.position.x, region.end.x):
		for y in range(region.position.y, region.end.y):
			var tile := Vector2i(x, y)
			if not standable(m, tile):
				continue
			var hidden := true
			for other in from:
				if gap(tile, other) < 6.0 or m.sight.clear(other, tile):
					hidden = false
					break
			if hidden:
				return tile
	return NOWHERE


## The guard's post and the tiles along the line they look down, either side.
func row(post: Vector2i) -> Array:
	var tiles := []
	for dx in range(-3, 9):
		tiles.append(post + Vector2i(dx, 0))
	return tiles


## A tile right behind somebody at `post` facing right, within reach.
func behind(m: Dictionary, post: Vector2i) -> Vector2i:
	for tile in [post + Vector2i.LEFT, post + Vector2i(-1, -1), post + Vector2i(-1, 1)]:
		if standable(m, tile):
			return tile
	return NOWHERE


## Somewhere a guard can stand and look right down four open tiles, with a
## free tile two behind them, near where the party arrived.
func find_post(m: Dictionary, start_tile: Vector2i) -> Vector2i:
	var frontier := [start_tile]
	var visited := {start_tile: true}
	while not frontier.is_empty():
		var tile: Vector2i = frontier.pop_front()
		var fits = standable(m, tile) and standable(m, tile + Vector2i.LEFT * 2) and standable(m, tile + Vector2i.LEFT)
		for step in range(1, 5):
			fits = fits and standable(m, tile + Vector2i.RIGHT * step)
		if fits and m.sight.clear(tile, tile + Vector2i.RIGHT * 4) and m.sight.clear(tile + Vector2i.LEFT * 2, tile + Vector2i.RIGHT * 4) \
				and tile.distance_to(start_tile) >= 3:
			return tile
		for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = tile + d
			if not visited.has(next) and m.sight.region().has_point(next) and standable(m, next):
				visited[next] = true
				frontier.append(next)
	return NOWHERE


## Who is in a fight built on the map, by name, with the round each comes on.
func arrivals(fight: EncounterDefinition) -> Dictionary:
	var found := {}
	for spawn in fight.spawns:
		if spawn.side == 1:
			found[spawn.display_name] = spawn.arrives_on_round
	return found
