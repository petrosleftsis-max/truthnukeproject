extends Node
## Builds the stealth test stages and the menu that opens them. Run it from a
## terminal in the project folder:
##
##     godot --headless --path . --import
##     godot --headless --path . res://tools/build_stealth_stages.tscn
##
## A scene rather than a --script, because the stages' nodes lean on the
## autoloads (Campaign and the databases), which --script does not load.
##
## Each stage is two scenes: stages/stealth_N_terrain
## is only the map, which the fight is played on; stages/stealth_N is that map
## with the guards, the hiding spots and the rest put on it, which is what the
## party walks. Once built they are ordinary scenes - open them and change
## anything - but running this again rebuilds them from what is written here,
## and any hand edits go with it.
##
## Layouts are carved out of solid rock with room(), one rectangle at a time,
## and painted by StagePainter. Everything placed is placed on a tile.

const TILESET := "res://tilesets/terrain_tileset.tres"
const GRID := "res://scenes/grid_overlay.gd"
const SPARKLE := "res://imagese/icon/interactable_anim.tres"
const TALK := "res://Dialogue/stealth_stages.dialogue"
const ATLAS := "res://imagese/terrain/tile map 1st area.png"
const OUT := "res://stages/"


func _ready():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	stage_tools()
	stage_watch()
	stage_escort()
	stage_disguise()
	print("Stealth stages built.")
	get_tree().quit()


## --- Carving ---

class Carve:
	var cells: Array = []
	var width := 0

	func _init(w: int, h: int):
		width = w
		for y in h:
			var row := []
			row.resize(w)
			row.fill("#")
			cells.append(row)

	## Floor - or `ch` - over the rectangle from (x0, y0) to (x1, y1), inclusive.
	func room(x0: int, y0: int, x1: int, y1: int, ch := "."):
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				cells[y][x] = ch

	func put(x: int, y: int, ch: String):
		cells[y][x] = ch

	func rows() -> PackedStringArray:
		var out := PackedStringArray()
		for row in cells:
			out.append("".join(row))
		return out


## --- Scenes ---

func tile_position(tile: Vector2i) -> Vector2:
	return Vector2(tile) * Grid.TILE_SIZE + Grid.HALF_TILE


## Saves the map alone - what the fight is played on.
func make_terrain(stage: String, carve: Carve) -> String:
	var root := Node2D.new()
	root.name = stage.capitalize().replace(" ", "") + "Terrain"
	var tiles := TileMap.new()
	tiles.name = "TileMap"
	tiles.tile_set = load(TILESET)
	root.add_child(tiles)
	tiles.owner = root
	StagePainter.paint(tiles, carve.rows())
	var grid := Node2D.new()
	grid.name = "Grid"
	grid.set_script(load(GRID))
	root.add_child(grid)
	grid.owner = root
	var path = OUT + stage + "_terrain.tscn"
	_save(root, path)
	print("\n%s\n%s" % [path, "\n".join(carve.rows())])
	return path


## The map with everything on it: the terrain placed in it as an instance, so
## the stage and the fight share one map - change the terrain, and both change.
func begin_stage(terrain_path: String, name: String) -> Node2D:
	var root := Node2D.new()
	root.name = name
	var base: PackedScene = ResourceLoader.load(terrain_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	var terrain = base.instantiate()
	terrain.name = "Terrain"
	root.add_child(terrain)
	# Only the instance itself belongs to the stage; what is inside it stays
	# the terrain's, which is what makes it saved as a reference, not a copy.
	terrain.owner = root
	return root


func finish_stage(root: Node, path: String):
	_save(root, path)


func _save(root: Node, path: String):
	var packed := PackedScene.new()
	var err = packed.pack(root)
	if err != OK:
		push_error("Could not pack %s: %d" % [path, err])
	err = ResourceSaver.save(packed, path)
	if err != OK:
		push_error("Could not save %s: %d" % [path, err])
	root.free()


func place(root: Node, node: Node2D, called: String, tile: Vector2i) -> Node2D:
	node.name = called
	node.position = tile_position(tile)
	root.add_child(node)
	node.owner = root
	return node


func entry(root: Node, tile: Vector2i):
	var point := Marker2D.new()
	point.set_script(load("res://exploration/EntryPoint.gd"))
	point.set("entry_name", "start")
	place(root, point, "EntryPoint", tile)


func map_setup(root: Node, members: Array[String], carries: Array[String] = []):
	var setup := Node.new()
	setup.name = "MapSetup"
	setup.set_script(load("res://exploration/MapSetup.gd"))
	setup.set("members", members)
	setup.set("level", 2)
	setup.set("empty_handed", true)
	if not carries.is_empty():
		setup.set("everyone_carries", carries)
	root.add_child(setup)
	setup.owner = root


func stealth_setup(root: Node, terrain_path: String, fight_name: String) -> StealthSetup:
	var setup := StealthSetup.new()
	setup.name = "StealthSetup"
	setup.battle_terrain = ResourceLoader.load(terrain_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	setup.fight_name = fight_name
	# Every stage: guards seen only when he could see them, so Cat's Ears (Q)
	# is worth having.
	setup.guards_seen_only_in_sight = true
	root.add_child(setup)
	setup.owner = root
	return setup


func waypoint(root: Node, called: String, tile: Vector2i):
	var point := Waypoint.new()
	point.point_name = called
	place(root, point, "Waypoint_" + called, tile)


func guard(root: Node, called: String, key: String, tile: Vector2i, facing: float = 0.0, patrol: Array[String] = []) -> Guard:
	var watcher := Guard.new()
	watcher.combatant_key = key
	watcher.level = 2
	watcher.facing_degrees = facing
	watcher.patrol = patrol
	watcher.back_and_forth = true
	place(root, watcher, called, tile)
	return watcher


func hiding_spot(root: Node, tile: Vector2i, index: int):
	var spot := HidingSpot.new()
	# A stack of planks from the tileset to crouch behind.
	var crate := AtlasTexture.new()
	crate.atlas = load(ATLAS)
	crate.region = Rect2(768, 0, 192, 192)
	spot.look = crate
	spot.look_scale = 0.8
	place(root, spot, "HidingSpot%d" % index, tile)


func talk(root: Node, called: String, tile: Vector2i, cue: String, prompt: String, automatic := false) -> Node2D:
	var node := Node2D.new()
	node.set_script(load("res://exploration/DialogueInteractable.gd"))
	node.set("dialogue", load(TALK))
	node.set("dialogue_title", cue)
	node.set("only_once", true)
	node.set("automatic", automatic)
	node.set("prompt", prompt)
	node.set("interaction_radius", Grid.tiles(1.25))
	if not automatic:
		node.set("sprite_frames", load(SPARKLE))
	return place(root, node, called, tile)


func goal(root: Node, tile: Vector2i, stage: int, cue: String) -> StealthGoal:
	var exit := StealthGoal.new()
	exit.completed_flag = "stage%d_done" % stage
	exit.ghost_flag = "stage%d_ghost" % stage
	exit.dialogue = load(TALK)
	exit.dialogue_title = cue
	exit.interaction_radius = Grid.tiles(0.9)
	exit.sprite_frames = load(SPARKLE)
	# Played on their own from the title screen, so they go back to its list.
	exit.ends_at_menu = true
	place(root, exit, "Goal", tile)
	return exit


## --- The stages ---


## 1. The tools: pebbles to throw, hiding spots, a guard with the keys in his
## pocket, a sentry to take down and a patrol who will find him if you do - and
## guards you only see when you can see them, so listen (Q).
func stage_tools():
	var c := Carve.new(38, 21)
	c.room(1, 1, 6, 7)              # where he starts
	c.room(7, 3, 21, 4)             # the corridor the key-holder walks
	c.room(10, 1, 10, 2)            # nooks off it, to hide in
	c.room(16, 1, 16, 2)
	c.room(13, 5, 13, 6)
	c.room(22, 1, 36, 12)           # the storage hall
	for barrel in [[25, 6, "b"], [25, 7, "b"], [30, 9, "b"], [31, 9, "o"], [34, 3, "b"], [35, 3, "b"], [28, 5, "o"]]:
		c.put(barrel[0], barrel[1], barrel[2])
	c.room(33, 13, 34, 13)          # into the vault
	c.room(31, 14, 36, 19)          # the vault
	for torch in [[0, 4], [21, 8], [37, 6], [37, 16]]:
		c.put(torch[0], torch[1], "T")
	var terrain = make_terrain("stealth_1", c)
	var root = begin_stage(terrain, "Stage1Tools")
	# Tucked into the corner: the corridor's view through the door stops short
	# of it, so the key-holder coming back does not find him standing there.
	entry(root, Vector2i(2, 7))
	map_setup(root, ["cyrus"], ["pebble", "pebble", "pebble"])
	stealth_setup(root, terrain, "Caught in the storerooms")
	var spots := 0
	for tile in [Vector2i(10, 1), Vector2i(16, 1), Vector2i(13, 6), Vector2i(36, 2), Vector2i(24, 11)]:
		hiding_spot(root, tile, spots)
		spots += 1
	# He turns a few tiles short of the start room's door, so his view back
	# through it is a narrow one.
	waypoint(root, "keys_west", Vector2i(11, 3))
	waypoint(root, "keys_east", Vector2i(21, 4))
	var keys = guard(root, "KeyHolder", "barbarian", Vector2i(11, 3), 0.0, ["keys_west", "keys_east"])
	keys.display_name = "Key Holder"
	keys.pockets.assign(["pebble", "pebble"])
	keys.picked_flag = "stage1_keys"
	keys.picked_message = "a ring of keys"
	var sentry = guard(root, "Sentry", "ranger", Vector2i(27, 2), 90.0)
	sentry.display_name = "Sentry"
	waypoint(root, "hall_west", Vector2i(23, 11))
	waypoint(root, "hall_east", Vector2i(35, 11))
	waypoint(root, "hall_north", Vector2i(35, 6))
	var rounds = guard(root, "HallPatrol", "barbarian", Vector2i(23, 11), 0.0, ["hall_west", "hall_east", "hall_north"])
	rounds.display_name = "Hall Patrol"
	rounds.pause_seconds = 1.0
	var exit = goal(root, Vector2i(34, 17), 1, "s1_goal")
	exit.requires_flag = "stage1_keys"
	exit.locked_message = "The vault is locked. The corridor guard jingled as he walked - he has the keys."
	finish_stage(root, OUT + "stealth_1.tscn")


## 2. The watch: a statue that turns and sees through anything, a hound whose
## nose finds you through walls, a captain whose shout brings the barracks -
## and a fight that only has the nearby guards in it at first.
func stage_watch():
	var c := Carve.new(44, 19)
	c.room(1, 7, 5, 11)             # where he starts
	c.room(6, 9, 6, 9)
	c.room(7, 2, 21, 16)            # the courtyard
	for pillar in [[10, 5, "b"], [18, 5, "b"], [10, 13, "b"], [18, 13, "b"], [14, 3, "o"], [14, 15, "o"]]:
		c.put(pillar[0], pillar[1], pillar[2])
	c.room(22, 9, 22, 9)
	c.room(23, 8, 32, 10)           # the hound's corridor
	c.room(27, 7, 27, 7)
	c.room(25, 1, 29, 6)            # a storeroom to wait in
	c.put(25, 1, "b")
	c.put(29, 1, "b")
	c.room(30, 1, 42, 2)            # the passage round the back
	c.room(37, 3, 37, 3)            # a gap the sentry looks up through
	c.room(33, 9, 33, 9)
	c.room(34, 4, 42, 16)           # the barracks
	for barrel in [[36, 8, "b"], [36, 10, "b"], [39, 13, "o"]]:
		c.put(barrel[0], barrel[1], barrel[2])
	for torch in [[0, 9], [43, 10], [43, 13]]:
		c.put(torch[0], torch[1], "T")
	var terrain = make_terrain("stealth_2", c)
	var root = begin_stage(terrain, "Stage2Watch")
	# Off the line through the one-tile door, which the statue's turning gaze
	# looks straight down every time it comes round.
	entry(root, Vector2i(2, 7))
	map_setup(root, ["cyrus"], ["pebble", "pebble"])
	var setup = stealth_setup(root, terrain, "Caught by the watch")
	setup.joins_within_tiles = 7.0
	setup.tiles_per_late_round = 5.0
	var ward = guard(root, "Statue", "mimic", Vector2i(14, 9))
	ward.kind = Guard.Kind.WARD
	ward.display_name = "Watchful Statue"
	ward.ward_turn_degrees = 35.0
	ward.can_be_taken_down = false
	waypoint(root, "hound_west", Vector2i(24, 9))
	waypoint(root, "hound_east", Vector2i(32, 9))
	var hound = guard(root, "Hound", "bomber", Vector2i(24, 9), 0.0, ["hound_west", "hound_east"])
	hound.kind = Guard.Kind.DOG
	hound.display_name = "Hound"
	hound.walk_speed_tiles = 1.8
	var sentry = guard(root, "Sentry", "barbarian", Vector2i(37, 5), -90.0)
	sentry.display_name = "Sentry"
	sentry.looks_around = false
	var captain = guard(root, "Captain", "barbarian", Vector2i(40, 10), 180.0)
	captain.kind = Guard.Kind.CAPTAIN
	captain.display_name = "Captain"
	captain.shout_tiles = 14.0
	waypoint(root, "barracks_west", Vector2i(35, 15))
	waypoint(root, "barracks_east", Vector2i(41, 15))
	var rounds = guard(root, "BarracksPatrol", "ranger", Vector2i(35, 15), 0.0, ["barracks_west", "barracks_east"])
	rounds.display_name = "Barracks Patrol"
	goal(root, Vector2i(42, 1), 2, "s2_goal")
	finish_stage(root, OUT + "stealth_2.tscn")


## 3. The escort: Enfina follows, and she can be seen as well as he can. Hiding
## spots come in pairs - one for each of them - and there is a bonus for
## getting her out without so much as a "?".
func stage_escort():
	var c := Carve.new(40, 16)
	c.room(1, 2, 5, 6)              # the cell - off the corridor's line, so
	c.room(3, 7, 3, 7)              # nobody down it sees in
	c.room(1, 8, 34, 9)             # the long corridor
	for x in [9, 17, 25]:
		c.room(x, 5, x, 7)          # nooks deep enough for two
	c.room(35, 4, 38, 13)           # the way out
	for torch in [[0, 4], [0, 8], [39, 8], [39, 11]]:
		c.put(torch[0], torch[1], "T")
	var terrain = make_terrain("stealth_3", c)
	var root = begin_stage(terrain, "Stage3Escort")
	entry(root, Vector2i(3, 4))
	map_setup(root, ["cyrus", "enfina"])
	stealth_setup(root, terrain, "Caught with the prisoner")
	talk(root, "Freed", Vector2i(3, 4), "s3_start", "Talk", true)
	var spots := 0
	for x in [9, 17, 25]:
		for y in [5, 6]:
			hiding_spot(root, Vector2i(x, y), spots)
			spots += 1
	# He turns short of the cell door, so the cell is never in his view.
	waypoint(root, "cells_west", Vector2i(8, 9))
	waypoint(root, "cells_east", Vector2i(33, 8))
	var warden = guard(root, "Warden", "barbarian", Vector2i(33, 8), 180.0, ["cells_east", "cells_west"])
	warden.display_name = "Warden"
	warden.walk_speed_tiles = 1.5
	# Still, and watching the south of the way out: a quiet lane along the
	# corridor's far side and up the east wall, for whoever notices it. A guard
	# sweeping about here would see all of the room at one moment or another.
	var door = guard(root, "DoorGuard", "ranger", Vector2i(38, 12), 135.0)
	door.display_name = "Door Guard"
	door.looks_around = false
	goal(root, Vector2i(37, 5), 3, "s3_goal")
	finish_stage(root, OUT + "stealth_3.tscn")


## 4. The disguise: Priest robes from a locker. The priest at the checkpoint
## knows his own and asks questions; the hall guard is fooled by any robe; the
## door guard by none - go round him, and out of the robes first.
func stage_disguise():
	var c := Carve.new(40, 16)
	c.room(1, 5, 6, 10)             # where he starts
	c.room(7, 7, 34, 8)             # the corridor
	c.room(14, 5, 14, 6)            # the checkpoint
	c.room(31, 4, 31, 6)            # the door guard's post
	c.room(27, 9, 27, 11)           # the way round
	c.room(27, 12, 34, 14)
	c.put(30, 13, "b")
	c.put(31, 12, "o")
	c.room(35, 5, 38, 14)           # the way out
	for torch in [[0, 7], [39, 9], [39, 12]]:
		c.put(torch[0], torch[1], "T")
	var terrain = make_terrain("stealth_4", c)
	var root = begin_stage(terrain, "Stage4Disguise")
	# In the corner, out of the line the hall guard looks down.
	entry(root, Vector2i(2, 10))
	map_setup(root, ["cyrus"])
	stealth_setup(root, terrain, "Caught in the chapter house")
	talk(root, "Locker", Vector2i(2, 6), "s4_locker", "Search the locker")
	hiding_spot(root, Vector2i(29, 13), 0)
	var priest = guard(root, "CheckpointPriest", "priest", Vector2i(14, 5), 90.0)
	priest.display_name = "Checkpoint Priest"
	priest.looks_around = false
	priest.recognises = Guard.Recognises.OWN_ROLE
	priest.questions = load(TALK)
	priest.questions_title = "s4_checkpoint"
	priest.passed_flag = "stage4_passed"
	waypoint(root, "hall_west", Vector2i(18, 7))
	waypoint(root, "hall_east", Vector2i(26, 8))
	var hall = guard(root, "HallGuard", "barbarian", Vector2i(18, 7), 0.0, ["hall_west", "hall_east"])
	hall.display_name = "Hall Guard"
	hall.recognises = Guard.Recognises.NO_DISGUISE
	var door = guard(root, "DoorGuard", "barbarian", Vector2i(31, 4), 90.0)
	door.display_name = "Door Guard"
	door.looks_around = false
	door.recognises = Guard.Recognises.ANY_DISGUISE
	goal(root, Vector2i(37, 13), 4, "s4_goal")
	finish_stage(root, OUT + "stealth_4.tscn")
