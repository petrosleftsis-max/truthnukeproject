extends Node
## The Town Demo (maps/TownDemo.tscn; the designer, 2026-11-27): where the party starts, its doors - shut, opened and shut again by
## hand, the one to another map not made yet - the cracked wall drawn like the walls beside it and hiding the path behind it until
## it breaks, what the party has not seen kept in darkness (HiddenPlaces), a door broken in a fight staying broken, a shut door
## standing in a fight on its map's own ground (StealthWatch.build_fight, on a stealth stage with doors), and the public build
## showing the plain stand-in for my pictures (Release.picture).

var LOG_PATH := HarnessLog.path_for("towndemo")
var _log: FileAccess
var _fail = 0

const TOWN := "res://maps/TownDemo.tscn"
const STAGE_WITH_DOORS := "res://maps/stealth_stages/stealth_5.tscn"


func log_line(t): _log.store_line(t); _log.flush()

func ok(condition: bool, label: String, detail: String = ""):
	if condition:
		log_line("  PASS  %s %s" % [label, detail])
	else:
		_fail += 1
		log_line("  FAIL  %s %s" % [label, detail])


func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(240.0, true, false, true).timeout.connect(func():
		log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


func open_map(map: String) -> ExplorationScene:
	Campaign.reset()
	Campaign.current_map = map
	Campaign.target_entry = ""
	var scene: ExplorationScene = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(scene)
	await settle(8)
	scene.end_blocking_interaction()
	return scene


func close(scene: Node):
	scene.queue_free()
	await settle(3)


func tile_of(scene: ExplorationScene, node: Node2D) -> Vector2i:
	return scene._tile_map.local_to_map(scene._tile_map.to_local(node.global_position))


func run_test():
	await the_town()
	await a_door_in_a_fight()
	the_public_build()


func the_town():
	log_line("======== the town ========")
	var scene := await open_map(TOWN)
	var leader := tile_of(scene, scene.party.sprite_for(Campaign.party_members()[0].key))
	ok(leader == Vector2i(10, 12), "the party starts in the hall", "%s" % leader)
	# Dusk, with lamps along its streets (the designer, 2026-11-27: "Towndemo to be dusk and also have some lights on the street").
	ok(Campaign.time_of_day == Light.Hour.DUSK, "dusk", "%d" % Campaign.time_of_day)
	var lamps := scene.find_children("*", "LightSource", true, false)
	var astray := []
	for lamp in lamps:
		var data = scene._tile_map.get_cell_tile_data(0, tile_of(scene, lamp))
		if not lamp.lit or data == null or 0 in data.get_custom_data("Blocks"):
			astray.append("%s %s lit %s" % [lamp.name, tile_of(scene, lamp), lamp.lit])
	ok(lamps.size() == 13 and astray.is_empty(), "thirteen lamps lit along the streets, each on open ground", "%d %s" % [lamps.size(), astray])
	var doors := {}
	for door in scene.find_children("*", "StealthDoor", true, false):
		doors[door.name] = door
	ok(doors.size() == 5, "five doors", "%s" % [doors.keys()])
	for key in ["DoorWest", "DoorEast", "DoorHall", "DoorNorth", "DoorElsewhere"]:
		var door = doors.get(key)
		ok(door != null and not door.passable() and scene._shut.has(tile_of(scene, door)), "  %s shut, nobody walks through" % key)
	var west = doors.DoorWest
	west.interact(scene)
	ok(west.passable() and not scene._shut.has(Vector2i(0, 6)), "opened by hand: a way through")
	west.interact(scene)
	ok(not west.passable() and scene._shut.has(Vector2i(0, 6)), "and shut again")
	var elsewhere = doors.DoorElsewhere
	ok(elsewhere.leads_elsewhere and elsewhere.prompt == "Go through" and tile_of(scene, elsewhere) == Vector2i(52, -11),
		"the door at 52,-11 leads to another map")
	elsewhere.interact(scene)
	await settle()
	ok(Campaign.current_map == TOWN and not elsewhere.passable(), "with none made yet, it does not open")
	log_line("")

	log_line("======== the cracked wall ========")
	var wall: BreakableWall = null
	for each in scene.walls():
		if each.name == "CrackedWall":
			wall = each
	ok(wall != null and tile_of(scene, wall) == Vector2i(34, 15) and not wall.broken, "a cracked wall at 34,15, standing")
	if wall == null:
		await close(scene)
		return
	ok(wall.like_the_walls and not wall._wall_beside().is_empty(), "drawn like the wall beside it, with cracks")
	ok(wall.hidden_tiles().size() == 8 and wall.hidden_tiles().has(Vector2i(34, 16)) and wall.hidden_tiles().has(Vector2i(34, 23)),
		"hiding the path, 34,16 to 34,23")
	log_line("")

	log_line("======== what the party has not seen ========")
	var hidden: HiddenPlaces = scene.find_children("*", "HiddenPlaces", true, false)[0] if not scene.find_children("*", "HiddenPlaces", true, false).is_empty() else null
	ok(hidden != null, "darkness over this map")
	if hidden == null:
		await close(scene)
		return
	await settle(2)
	ok(hidden.in_sight(leader) and hidden.seen(Vector2i(12, 13)), "the hall round the party, in sight")
	ok(not hidden.seen(Vector2i(-5, 5)), "a room behind its shut door, never seen")
	hidden.look([Vector2i(2, 6)])
	ok(not hidden.seen(Vector2i(-5, 6)), "looking at its shut door from outside, still not")
	west.interact(scene)
	hidden.look([Vector2i(2, 6)])
	ok(hidden.seen(Vector2i(-5, 6)) and hidden.in_sight(Vector2i(-5, 6)), "the door opened: seen through it")
	west.interact(scene)
	hidden.look([Vector2i(2, 6)])
	ok(hidden.seen(Vector2i(-5, 6)) and not hidden.in_sight(Vector2i(-5, 6)), "shut again: remembered, but out of sight")
	hidden.look([Vector2i(34, 14)])
	ok(not hidden.seen(Vector2i(34, 16)) and not hidden.seen(Vector2i(34, 20)), "the path behind the wall: hidden while it stands")
	scene.break_wall(wall)
	hidden.look([Vector2i(34, 14)])
	var revealed := wall.hidden_tiles().all(func(tile): return hidden.seen(tile))
	ok(wall.broken and revealed, "broken: the whole path is seen at once")
	ok(String(Campaign.flags.get(HiddenPlaces.FLAG % TOWN, "")).contains("34,20"), "what was seen kept with the map")
	log_line("")

	log_line("======== a door broken in a fight ========")
	var hall = doors.DoorHall
	Campaign.set_flag(hall.broken_flag_for(scene.map_path()))
	scene._collect_doors(hall.get_parent())
	ok(hall.broken and hall.passable() and not scene._shut.has(Vector2i(26, 10)), "broken there, it stays broken here: a way through")
	hall.interact(scene)
	ok(hall.passable(), "and there is nothing left of it to shut")
	await close(scene)
	log_line("")


func a_door_in_a_fight():
	log_line("======== a shut door in a fight on its map ========")
	var scene := await open_map(STAGE_WITH_DOORS)
	var watch = scene.stealth
	ok(watch != null, "a watched map with doors")
	if watch == null:
		await close(scene)
		return
	var shut := []
	for door in scene.find_children("*", "StealthDoor", true, false):
		if not door.passable():
			shut.append(tile_of(scene, door))
	var doors_in_fight := watch.build_fight().spawns.filter(func(spawn): return spawn.combatant_key == "door")
	ok(not shut.is_empty() and doors_in_fight.size() == shut.size(), "every shut door stands in the fight", "%d of %d" % [doors_in_fight.size(), shut.size()])
	ok(doors_in_fight.all(func(spawn): return shut.has(spawn.position) and String(spawn.get_meta("wall_flag", "")).begins_with("broken_door:")),
		"on its own tile, and broken there it stays broken")
	var door: BattleObjectDefinition = CombatantDatabase.combatants.get("door")
	ok(door != null and door.breakable and not door.wall and not door.interactable, "a door anybody can break")
	await close(scene)
	log_line("")


func the_public_build():
	log_line("======== my pictures in the public build ========")
	var door: CombatantDefinition = CombatantDatabase.combatants.get("door")
	var tree: CombatantDefinition = CombatantDatabase.combatants.get("sacred_tree")
	ok(door.portrait().resource_path.ends_with("door_icon.png") and tree.map_still().resource_path.ends_with("sacred_tree_sheet.png"),
		"here, my placeholder pictures")
	Release.pretend = true
	ok(door.portrait().resource_path == Release.STAND_IN_PICTURE and tree.map_still().resource_path == Release.STAND_IN_PICTURE,
		"in the public build, the plain stand-in in their place")
	var cyrus: CombatantDefinition = CombatantDatabase.combatants.get("cyrus")
	ok(cyrus.portrait() == null or cyrus.portrait().resource_path != Release.STAND_IN_PICTURE, "the designer's own pictures as they are")
	Release.pretend = false
