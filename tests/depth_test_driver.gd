extends "res://StealthHarness.gd"
## 2.5D (Depth, DepthView; docs/2_5d_plan.md; the designer and their artist, 2026-11-13). What it decides, and that it is only a look:
## - which tiles are high ground, walls or neither, from their Blocks, agreeing with Combat.is_high tile for tile;
## - which are drawn lifted and by how much, which get a face under them, which never are (the TileSet's Lift) and which are things
##   standing on the floor (its Stands), on a painted map and on the real ones;
## - on a map, the nearer figure over the further, a lifted row over whoever is behind it and under whoever is on it or in front,
##   what lies on the ground under everybody and what is over everybody still so;
## - the cutaway: opened by somebody seen who stands behind something lifted, not by somebody unseen, nor by anybody in the open;
## - whoever stands up on raised ground is drawn that much higher, and a hop takes the drawing there;
## - a shut door and a wall that can be broken stand as tall as a wall, and drop when opened or broken;
## - thick mist rises over what is lifted, thin mist does not;
## - C: the lamps are told to the rows with where their light reaches, each piece lit its own way, and walls' feet shaded;
## - one seeded fight played with the view and without ends the same.

const STAGE := "res://maps/stealth_stages/stealth_9.tscn"
const STAGE_TERRAIN := "res://maps/stealth_stages/stealth_9_terrain.tscn"
const SAPPERS := "res://data/encounters/encounter_02_sappers.tres"
const HEIGHTS := "res://data/encounters/two_floors.tres"
const SEED := 20261113

var _game: Node = null


func suite() -> String:
	return "depth"


func time_limit() -> float:
	return 280.0


func run_sections():
	what_a_tile_is()
	a_painted_map()
	the_real_maps()
	where_a_figure_is_drawn()
	await as_the_rules_have_it()
	await on_the_stage()
	await up_on_raised_ground()
	await only_a_look()


func what_a_tile_is():
	log_line("======== what a tile is, from its Blocks ========")
	ok(Depth.kind_of_blocks([0, 2]) == Depth.Kind.HIGH, "stops a walker and not a flier: high ground")
	ok(Depth.kind_of_blocks([0, 2, 1]) == Depth.Kind.WALL and Depth.kind_of_blocks([1, 0, 2]) == Depth.Kind.WALL, "stops a flier too: a wall")
	ok(Depth.kind_of_blocks([0, 2, 3]) == Depth.Kind.FLOOR, "see-through (water, a railing): neither, never lifted")
	ok(Depth.kind_of_blocks([1]) == Depth.Kind.FLOOR and Depth.kind_of_blocks([]) == Depth.Kind.FLOOR and Depth.kind_of_blocks(null) == Depth.Kind.FLOOR,
		"stops no walker: floor")
	ok(Depth.lift_of(Depth.Kind.HIGH) == Depth.RAISED_LIFT and Depth.lift_of(Depth.Kind.WALL) == Depth.WALL_LIFT
		and Depth.lift_of(Depth.Kind.FLOOR) == 0.0 and Depth.lift_of(Depth.Kind.VOID) == 0.0, "high ground and walls are lifted, a wall higher; nothing else")
	Depth.walls_lifted = false
	ok(Depth.lift_of(Depth.Kind.WALL) == 0.0 and Depth.lift_of(Depth.Kind.HIGH) == Depth.RAISED_LIFT, "with walls not lifted, only high ground is")
	Depth.walls_lifted = true
	log_line("")


## A map painted for the purpose: a room with a terrace of raised ground, a barrel against it and a channel of the sewer's.
func painted() -> TileMap:
	var tile_map := TileMap.new()
	tile_map.tile_set = load("res://maps/tilesets/terrain_tileset.tres")
	StagePainter.paint(tile_map, PackedStringArray([
		"#######",
		"#.....#",
		"#.rr..#",
		"#.rb..#",
		"#.....#",
		"#######"]))
	# The sewer's channel, which the rules count as high ground and the TileSet's Lift keeps flat.
	tile_map.set_cell(0, Vector2i(5, 1), 0, Vector2i(3, 1), 0)
	return tile_map


func a_painted_map():
	log_line("======== a painted map: what is lifted, and what gets a face ========")
	var tile_map := painted()
	var lifts := Depth.lifts_of(tile_map)
	ok(lifts.get(Vector2i(2, 2), 0.0) == Depth.RAISED_LIFT and lifts.get(Vector2i(3, 2), 0.0) == Depth.RAISED_LIFT and lifts.get(Vector2i(2, 3), 0.0) == Depth.RAISED_LIFT,
		"raised ground is lifted", "%s" % [lifts.get(Vector2i(2, 2), 0.0)])
	ok(lifts.get(Vector2i(0, 0), 0.0) == Depth.WALL_LIFT and lifts.get(Vector2i(3, 5), 0.0) == Depth.WALL_LIFT, "walls are lifted, higher")
	ok(not lifts.has(Vector2i(1, 1)) and not lifts.has(Vector2i(4, 4)), "the floor is not")
	ok(Depth.kind_at(tile_map, Vector2i(3, 3)) == Depth.Kind.HIGH and Depth.stands_at(tile_map, Vector2i(3, 3)) and not lifts.has(Vector2i(3, 3)),
		"a barrel is high ground, but a thing standing on the floor: its floor is not lifted")
	ok(Depth.standers_of(tile_map) == [Vector2i(3, 3)], "and it is the only thing standing here", "%s" % [Depth.standers_of(tile_map)])
	ok(Depth.kind_at(tile_map, Vector2i(5, 1)) == Depth.Kind.HIGH and Depth.lift_at(tile_map, Vector2i(5, 1)) == 0.0 and not lifts.has(Vector2i(5, 1)),
		"the sewer's channel is high ground to the rules and never lifted (the TileSet's Lift)")
	ok(not Depth.stands_at(tile_map, Vector2i(2, 2)) and not Depth.stands_at(tile_map, Vector2i(1, 1)) and not Depth.stands_at(tile_map, Vector2i(0, 0)),
		"raised ground, floor and walls are no such thing")
	# Faces: wherever what lies to the south is lower.
	ok(Depth.face_under(lifts, Vector2i(2, 2)) == 0.0, "no face between two tiles of the same raised ground")
	ok(Depth.face_under(lifts, Vector2i(3, 2)) == Depth.RAISED_LIFT, "a face over a thing standing on the floor: the floor there is low")
	ok(Depth.face_under(lifts, Vector2i(2, 3)) == Depth.RAISED_LIFT, "a face where raised ground has floor to its south")
	ok(Depth.face_under(lifts, Vector2i(3, 0)) == Depth.WALL_LIFT, "a wall with floor to its south has a face as tall as it is lifted")
	ok(Depth.face_under(lifts, Vector2i(0, 2)) == 0.0, "a wall with more wall to its south has none")
	ok(Depth.face_under(lifts, Vector2i(3, 5)) == Depth.WALL_LIFT, "a wall with nothing to its south has one")
	ok(Depth.face_under(lifts, Vector2i(1, 1)) == 0.0 and Depth.face_under(lifts, Vector2i(3, 3)) == 0.0, "and what is not lifted has none")
	ok(Depth.slot("no_such_picture") == null, "an empty slot is no picture: code draws")
	# Raised ground against a wall: only what stands over its neighbour shows.
	tile_map.set_cell(0, Vector2i(3, 1), 0, StagePainter.FLOOR_ODD, StagePainter.RAISED_ALTERNATIVE)
	lifts = Depth.lifts_of(tile_map)
	ok(Depth.face_under(lifts, Vector2i(3, 0)) == Depth.WALL_LIFT - Depth.RAISED_LIFT, "a wall over raised ground shows only what stands over it",
		"%s" % [Depth.face_under(lifts, Vector2i(3, 0))])
	# Nothing to lift, nothing lifted.
	var bare := TileMap.new()
	bare.tile_set = tile_map.tile_set
	for x in 5:
		for y in 4:
			bare.set_cell(0, Vector2i(x, y), 0, StagePainter.FLOOR_ODD, 0)
	ok(Depth.lifts_of(bare).is_empty() and Depth.standers_of(bare).is_empty(), "a map of floor alone has nothing lifted and no faces")
	Depth.walls_lifted = false
	var without := Depth.lifts_of(tile_map)
	ok(not without.has(Vector2i(0, 0)) and without.has(Vector2i(2, 2)), "with walls not lifted, the same map lifts only its raised ground")
	Depth.walls_lifted = true
	bare.free()
	tile_map.free()
	log_line("")


func the_real_maps():
	log_line("======== the real maps ========")
	var stage = load(STAGE_TERRAIN).instantiate()
	var tile_map: TileMap = stage.get_node("TileMap")
	var lifts := Depth.lifts_of(tile_map)
	var terrace := true
	for x in range(14, 17):
		for y in range(18, 20):
			terrace = terrace and lifts.get(Vector2i(x, y), 0.0) == Depth.RAISED_LIFT
	ok(terrace, "the Light stage's yard has a terrace of raised ground, six tiles lifted")
	ok(Depth.face_under(lifts, Vector2i(15, 18)) == 0.0 and Depth.face_under(lifts, Vector2i(15, 19)) == Depth.RAISED_LIFT, "with faces only along its south edge")
	ok(Depth.stands_at(tile_map, Vector2i(13, 18)) and Depth.stands_at(tile_map, Vector2i(6, 11)) and not lifts.has(Vector2i(13, 18)),
		"its barrels stand on the floor, which is not lifted")
	ok(lifts.get(Vector2i(9, 7), 0.0) == Depth.WALL_LIFT and Depth.face_under(lifts, Vector2i(9, 7)) == Depth.WALL_LIFT, "the yard's north wall is lifted and shows its face")
	ok(lifts.get(Vector2i(9, 23), 0.0) == Depth.WALL_LIFT, "and its south wall is lifted over the row behind it")
	stage.free()
	var crossroads = load("res://maps/crossroads_terrain.tscn").instantiate()
	tile_map = crossroads.get_node("TileMap")
	lifts = Depth.lifts_of(tile_map)
	var channel := 0
	var lifted_channel := 0
	for tile in tile_map.get_used_cells(0):
		var atlas := tile_map.get_cell_atlas_coords(0, tile)
		if atlas == Vector2i(3, 1) or atlas == Vector2i(4, 1) or atlas == Vector2i(3, 0):
			channel += 1
			if lifts.has(tile):
				lifted_channel += 1
	ok(channel > 100 and lifted_channel == 0, "the crossroads' channel lies flat, every tile of it", "%d tiles, %d lifted" % [channel, lifted_channel])
	crossroads.free()
	log_line("")


func where_a_figure_is_drawn():
	log_line("======== on a map: who is drawn over whom ========")
	var tile := float(Grid.TILE_SIZE)
	var top := 0.0
	ok(Depth.z_at(tile * 9.5, top) > Depth.z_at(tile * 8.5, top), "the nearer of two figures is drawn over the further")
	ok(Depth.z_at(tile * 8.5, top) > Depth.z_at(tile * 8.2, top), "even a quarter of a tile nearer")
	var row := Depth.z_at(tile * 10.0, top)
	ok(Depth.z_at(tile * 9.5, top) < row, "whoever stands behind a lifted row is drawn under it")
	ok(Depth.z_at(tile * 10.5, top) >= row and Depth.z_at(tile * 11.5, top) > row, "whoever stands on it or in front of it is not")
	ok(Depth.stands_behind(tile * 9.5, tile * 10.0) and not Depth.stands_behind(tile * 10.5, tile * 10.0), "and only whoever is behind it is covered by it")
	var least := Depth.z_at(-5000.0, top)
	var most := Depth.z_at(999999.0, top)
	ok(least == ExplorationParty.PARTY_Z_BOTTOM and most == ExplorationParty.PARTY_Z_TOP - 1, "everybody is between the party's bottom and its top", "%d to %d" % [least, most])
	ok(ExplorationParty.PARTY_Z_BOTTOM - 1 < least and ExplorationParty.PARTY_Z_TOP > most, "so what lies on the ground is under everybody, and what is over everybody is still over them")
	ok(Depth.z_at(tile * 60.0, top) < ExplorationParty.PARTY_Z_TOP - 1, "a map sixty rows deep still sorts to its last row")
	ok(Depth.opens_a_cutaway(true, 1.0) and Depth.opens_a_cutaway(true, 0.5), "somebody seen opens a cutaway in what covers them")
	ok(not Depth.opens_a_cutaway(true, 0.0) and not Depth.opens_a_cutaway(false, 1.0), "somebody the player cannot see never does")
	# Mist that rises (LightView): thin, it lies under what is lifted; thick, some of it is over it.
	ok(LightView.high_mist_of(0.3, 0.0) == 0.0 and LightView.high_mist_of(0.0, 0.5) == 0.0, "a thin mist stays on the ground, under what is lifted")
	ok(LightView.high_mist_of(0.9, 0.0) > 0.3 and LightView.high_mist_of(1.0, 0.0) == LightView.HIGH_MIST_MOST, "a thick fog rises over raised ground",
		"%.2f" % LightView.high_mist_of(0.9, 0.0))
	ok(LightView.high_mist_of(0.0, 1.0) == LightView.HIGH_LOW_MIST_MOST and LightView.high_mist_of(0.0, 0.8) < LightView.high_mist_of(0.0, 1.0),
		"and so does the low mist of the stillest nights, less")
	log_line("")


## A fight on `path`'s map, deployed, with nobody's question waiting.
func start_fight(encounter: EncounterDefinition) -> Combat:
	Campaign.reset()
	Campaign.current_encounter = encounter
	_game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(_game)
	await settle(4)
	var combat: Combat = _game.get_node("VisualCombat")
	combat.reaction_prompt = null
	return combat


func end_fight():
	if _game != null:
		_game.queue_free()
		_game = null
	Campaign.current_encounter = null
	await settle(3)


func as_the_rules_have_it():
	log_line("======== high ground is what the rules say it is ========")
	var combat := await start_fight(load(HEIGHTS))
	combat.finish_deployment()
	await settle(2)
	var tile_map: TileMap = combat.controller.tile_map
	var checked := 0
	var differ := []
	var high := 0
	for tile in tile_map.get_used_cells(0):
		checked += 1
		var mine: bool = Depth.kind_at(tile_map, tile) == Depth.Kind.HIGH
		if mine:
			high += 1
		if mine != combat.is_high(tile):
			differ.append(tile)
	ok(differ.is_empty() and high > 0, "every tile of the heights fight: high ground here is high ground to Combat.is_high", "%d tiles, %d high, differing %s" % [checked, high, differ.slice(0, 5)])
	ok(combat.depth_view == null, "and headless nothing of the depth is made")
	await end_fight()
	log_line("")


func on_the_stage():
	log_line("======== on the Light stage ========")
	LightView.plays_headless = true
	LightView.sky_ease_seconds = 0.0
	Campaign.reset()
	Campaign.set_clock(12)
	Campaign.current_map = STAGE
	var scene: ExplorationScene = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(scene)
	await settle(5)
	scene.end_blocking_interaction()
	var view: DepthView = scene.depth_view
	ok(view != null, "a view of the depth")
	if view == null:
		LightView.plays_headless = false
		scene.queue_free()
		await settle()
		return
	var tile_map: TileMap = scene._tile_map
	ok(view.lifts().size() == Depth.lifts_of(tile_map).size() and view.lifts().has(Vector2i(15, 19)), "it lifts what Depth says", "%d tiles" % view.lifts().size())
	ok(view.height_at(Vector2i(15, 19)) == Depth.RAISED_LIFT and view.height_at(Vector2i(8, 15)) == 0.0, "whoever stood on the terrace would be drawn its lift higher, and on the floor not at all")
	var rows: Array = view.rows()
	var sorted := not rows.is_empty()
	for i in range(1, rows.size()):
		sorted = sorted and rows[i].z_index >= rows[i - 1].z_index
	ok(sorted and rows[0].z_index >= ExplorationParty.PARTY_Z_BOTTOM and rows.back().z_index < ExplorationParty.PARTY_Z_TOP,
		"its rows are sorted north to south, among the figures", "%d rows" % rows.size())
	ok(view.get_index() == 0, "and it is drawn under the light's own ground and shade")
	# Who is drawn over whom.
	var leader: CombatantSprite = scene.party.leader
	scene.party.teleport(Grid.tile_to_world(Vector2i(8, 12)))
	await settle(2)
	var far := CombatantSprite.new()
	var near := CombatantSprite.new()
	for made in [far, near]:
		scene.add_child(made)
		made.setup(null, load("res://art/terrain/first_area_tiles.png"), false)
		made.z_as_relative = false
		made.z_index = ExplorationParty.PARTY_Z_TOP
	far.global_position = Grid.tile_to_world(Vector2i(8, 10))
	near.global_position = Grid.tile_to_world(Vector2i(8, 14))
	await settle(3)
	ok(far.z_index < leader.z_index and leader.z_index < near.z_index, "figures are sorted by where they stand: the further, the leader, the nearer",
		"%d, %d, %d" % [far.z_index, leader.z_index, near.z_index])
	var lamp = scene.find_children("YardLamp", "", true, false)
	ok(not lamp.is_empty() and lamp[0].z_index < far.z_index, "a lamp on the ground is under them all")
	# Behind the terrace, on its far side; and in front of it.
	var terrace_row = null
	for row in rows:
		if is_equal_approx(tile_map.to_global(row.position).y, Grid.tile_to_world(Vector2i(0, 18)).y - Grid.TILE_SIZE * 0.5):
			terrace_row = row
	far.global_position = Grid.tile_to_world(Vector2i(15, 17))
	near.global_position = Grid.tile_to_world(Vector2i(15, 20))
	await settle(3)
	ok(terrace_row != null and far.z_index < terrace_row.z_index and near.z_index > terrace_row.z_index, "the terrace is drawn over whoever is behind it and under whoever is in front")
	# The cutaway.
	var cuts := view.cuts_now()
	var for_far := false
	var for_near := false
	for cut in cuts:
		for_far = for_far or Vector2(cut.x, cut.y).distance_to(far.global_position) < 2.0
		for_near = for_near or Vector2(cut.x, cut.y).distance_to(near.global_position) < 2.0
	ok(for_far and not for_near, "whoever is behind it is seen through it, and whoever is in front needs no cutaway", "%d cutaways" % cuts.size())
	far._shown_alpha = 0.0
	far.hidden_alpha = 0.0
	await settle(2)
	for_far = false
	for cut in view.cuts_now():
		for_far = for_far or Vector2(cut.x, cut.y).distance_to(far.global_position) < 2.0
	ok(not for_far, "but not somebody the player cannot see")
	far._shown_alpha = 1.0
	far.hidden_alpha = 1.0
	far.global_position = Grid.tile_to_world(Vector2i(25, 22))
	await settle(2)
	for_far = false
	for cut in view.cuts_now():
		for_far = for_far or Vector2(cut.x, cut.y).distance_to(far.global_position) < 2.0
	ok(for_far, "against the hall's south wall, they are seen through the wall")
	# Somebody bigger than a tile: two by two, their node on their top-left tile and their drawing over the middle of the four.
	far.scale = Vector2(2.0, 2.0)
	far.set_size_offset(Vector2(Grid.TILE_SIZE, Grid.TILE_SIZE) * 0.5)
	far.global_position = Grid.tile_to_world(Vector2i(24, 21))
	await settle(2)
	var big_cut := Vector3.ZERO
	for cut in view.cuts_now():
		if Vector2(cut.x, cut.y).distance_to(DepthView.body_middle(far)) < 2.0:
			big_cut = cut
	ok(big_cut != Vector3.ZERO, "somebody two tiles by two against the hall's south wall is seen through it too")
	ok(is_equal_approx(big_cut.x, Grid.tile_to_world(Vector2i(24, 21)).x + Grid.TILE_SIZE * 0.5) and is_equal_approx(big_cut.y, Grid.tile_to_world(Vector2i(24, 21)).y + Grid.TILE_SIZE * 0.5),
		"about the middle of the four tiles they cover, not their own top-left one", "%s" % [big_cut])
	ok(is_equal_approx(big_cut.z, Depth.CUT_TILES * Grid.TILE_SIZE * 2.0), "and twice as far round them")
	far.global_position = Grid.tile_to_world(Vector2i(24, 19))
	await settle(2)
	big_cut = Vector3.ZERO
	for cut in view.cuts_now():
		if Vector2(cut.x, cut.y).distance_to(DepthView.body_middle(far)) < 2.0:
			big_cut = cut
	ok(big_cut == Vector3.ZERO, "a row further from the wall, nothing covers them and nothing is cut away")
	far.scale = Vector2.ONE
	far.set_size_offset(Vector2.ZERO)
	far.global_position = Grid.tile_to_world(Vector2i(25, 15))
	await settle(2)
	for_far = false
	for cut in view.cuts_now():
		for_far = for_far or Vector2(cut.x, cut.y).distance_to(far.global_position) < 2.0
	ok(not for_far, "in the middle of the hall, nothing is cut away for them")
	# A door and a wall that can be broken stand as tall as the walls while they are shut and whole.
	var door := StealthDoor.new()
	var wall := BreakableWall.new()
	scene.get_node("Map").add_child(door)
	scene.get_node("Map").add_child(wall)
	door.global_position = Grid.tile_to_world(Vector2i(22, 15))
	wall.global_position = Grid.tile_to_world(Vector2i(28, 15))
	await settle(3)
	var door_up = door.get_node_or_null("DepthUpright")
	var wall_up = wall.get_node_or_null("DepthUpright")
	ok(door_up != null and door_up.visible and door_up.lift == Depth.WALL_LIFT and door_up.face == Depth.WALL_LIFT, "a shut door stands as tall as a wall, its front showing",
		"%s" % [door_up.lift if door_up != null else -1.0])
	ok(wall_up != null and wall_up.visible and wall_up.lift == Depth.WALL_LIFT, "and so does a wall that can be broken, while it stands")
	ok(door_up != null and door_up.z_index > Depth.z_at(Grid.tile_to_world(Vector2i(22, 14)).y, view._top)
		and door_up.z_index <= Depth.z_at(Grid.tile_to_world(Vector2i(22, 15)).y, view._top), "sorted from its north edge, as a wall's row is")
	far.global_position = Grid.tile_to_world(Vector2i(22, 14))
	await settle(2)
	for_far = false
	for cut in view.cuts_now():
		for_far = for_far or Vector2(cut.x, cut.y).distance_to(far.global_position) < 2.0
	ok(for_far, "whoever is behind the door is seen through it")
	door.set_open(true)
	wall.broken = true
	await settle(3)
	ok(door_up != null and not door_up.visible and door.depth_lift() == 0.0, "opened, the door is down at once")
	ok(wall_up != null and not wall_up.visible, "and broken, the wall is rubble on the floor")
	for_far = false
	for cut in view.cuts_now():
		for_far = for_far or Vector2(cut.x, cut.y).distance_to(far.global_position) < 2.0
	ok(not for_far, "with nothing to see through any more")
	door.queue_free()
	wall.queue_free()
	# By night it is still there, darkened by the shade's own picture.
	Campaign.set_clock(23)
	await settle(4)
	ok(view._material.get_shader_parameter("shade_on") == 1.0 and view._material.get_shader_parameter("shade_map") != null, "by night the rows read the shade's own picture")
	# Light that knows height (C): the lamps are told to the rows, and where their light reaches by the light's own rule.
	await settle(3)
	var map: LightMap = scene.light
	ok(map != null and DepthView.lamp_reaches(map, Vector2i(14, 13)), "the yard's lamp reaches the floor beside it, by the light's own rule")
	ok(not DepthView.lamp_reaches(map, Vector2i(2, 2)) and not DepthView.lamp_reaches(null, Vector2i(14, 13)), "and no lamp reaches solid rock, nor anything with no light map")
	ok(int(view._material.get_shader_parameter("lamp_count")) > 0 and view._gate != null, "after dark the rows are told the lamps, and where their light reaches",
		"%s lamps" % [view._material.get_shader_parameter("lamp_count")])
	ok(view._face_material.get_shader_parameter("kind") == 1.0 and view._object_material.get_shader_parameter("kind") == 2.0 and view._material.get_shader_parameter("kind") == null,
		"a face is lit as facing us, a thing standing as round, a top as flat")
	var faces := 0
	var things := 0
	var wrong := 0
	for row in rows:
		if row.what == DepthView._Row.FACES:
			faces += 1
			wrong += 0 if row.material == view._face_material else 1
		elif row.what == DepthView._Row.THINGS:
			things += 1
			wrong += 0 if row.material == view._object_material else 1
		else:
			wrong += 0 if row.material == view._material else 1
	ok(faces > 0 and things > 0 and wrong == 0, "each row's tops, faces and things are drawn by a node of their own, lit its own way", "%d of faces, %d of things" % [faces, things])
	var before: int = map.version
	scene.relight_map()
	ok(map.version > before, "and the light's map counts each time it is worked out anew, for the view to see")
	# The foot of walls.
	ok(view._feet != null and view._feet.visible and view._feet.texture != null, "the foot of every wall and raised edge is shaded on the floor")
	ok(DepthView.foot_of(Depth.WALL_LIFT) == 1.0 and DepthView.foot_of(Depth.RAISED_LIFT) == 0.5 and DepthView.foot_of(0.0) == 0.0, "a wall's wholly, raised ground's by its height, the floor's not at all")
	LightView.plays_headless = false
	LightView.sky_ease_seconds = 2.5
	far.queue_free()
	near.queue_free()
	scene.queue_free()
	MenuPause.clear(get_tree())
	await settle(3)
	log_line("")


func up_on_raised_ground():
	log_line("======== up on raised ground ========")
	LightView.plays_headless = true
	var encounter := EncounterDefinition.new()
	encounter.display_name = "On the terrace"
	encounter.terrain_scene = load(STAGE_TERRAIN)
	encounter.skip_deployment = true
	var spawns: Array[SpawnDefinition] = []
	for who in [["cyrus", 0, Vector2i(15, 17)], ["rat", 1, Vector2i(4, 10)]]:
		var one := SpawnDefinition.new()
		one.combatant_key = who[0]
		one.side = who[1]
		one.position = who[2]
		# Cat Burglar is his from 24.
		one.level = 30
		spawns.append(one)
	encounter.spawns = spawns
	var combat := await start_fight(encounter)
	await settle(3)
	var view: DepthView = combat.depth_view
	ok(view != null and not view.rows().is_empty() and view.rows()[0].get_parent() == combat.combatant_layer(), "in a fight the lifted rows are in the figures' own sorted layer")
	var cyrus: Dictionary = {}
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == "cyrus":
			cyrus = comb
	ok(not cyrus.is_empty() and view != null, "Cyrus is here, who climbs anywhere")
	if cyrus.is_empty() or view == null:
		LightView.plays_headless = false
		await end_fight()
		return
	var sprite: CombatantSprite = cyrus.sprite
	ok(sprite.ground_lift == 0.0, "on the floor he is drawn where he stands")
	var terrace_row = null
	for row in view.rows():
		if is_equal_approx(row.position.y, Grid.tile_to_world(Vector2i(0, 18)).y - Grid.TILE_SIZE * 0.5):
			terrace_row = row
	ok(terrace_row != null and sprite.position.y < terrace_row.position.y, "behind the terrace, he sorts under it")
	cyrus.position = Vector2i(15, 18)
	sprite.position = combat.sprite_point(cyrus)
	combat.controller.refresh_occupancy()
	ok(cyrus.get("up", false) and sprite.ground_lift == Depth.RAISED_LIFT, "up on it, he is drawn as much higher as it is lifted", "%s" % [sprite.ground_lift])
	ok(terrace_row != null and sprite.position.y > terrace_row.position.y, "and sorts over it")
	var drawn: Node2D = sprite._drawn()
	ok(drawn != null and is_equal_approx(drawn.position.y, -Depth.RAISED_LIFT / sprite.scale.y), "only the drawing moves: the node stays on its tile", "%s" % [drawn.position])
	ok(sprite.position == combat.sprite_point(cyrus), "which the rules read")
	cyrus.position = Vector2i(15, 20)
	sprite.position = combat.sprite_point(cyrus)
	combat.controller.refresh_occupancy()
	ok(not cyrus.get("up", false) and sprite.ground_lift == 0.0 and drawn.position.y == 0.0, "down again, he is drawn where he stands")
	# A hop carries the drawing from the one height to the other.
	sprite.hop(CombatantSprite.Hop.UP, 0.15, Depth.RAISED_LIFT)
	await wait(0.05)
	var midway: float = drawn.position.y
	await wait(0.3)
	ok(sprite.ground_lift == Depth.RAISED_LIFT and is_equal_approx(drawn.position.y, -Depth.RAISED_LIFT / sprite.scale.y), "a hop up leaves the drawing up there",
		"midway %.1f, landed %.1f" % [midway, drawn.position.y])
	sprite.hop(CombatantSprite.Hop.DOWN, 0.15, 0.0)
	await wait(0.4)
	ok(sprite.ground_lift == 0.0 and is_equal_approx(drawn.position.y, 0.0), "and a hop down brings it down")
	# Somebody bigger than a tile with raised ground among their feet: they sort from their top-left tile, so it would be drawn
	# over their legs.
	ok(sprite.z_index == 1, "a figure in a fight is drawn at the layer's own height")
	sprite.scale = Vector2(3.0, 3.0)
	sprite.position = Grid.tile_to_world(Vector2i(14, 16))
	await settle(2)
	ok(sprite.z_index == 2, "somebody three tiles by three with the terrace among their feet is drawn over it", "%s" % [sprite.z_index])
	sprite.position = Grid.tile_to_world(Vector2i(14, 21))
	await settle(2)
	ok(sprite.z_index == 1, "and as they were once they have stepped off it", "%s" % [sprite.z_index])
	sprite.scale = Vector2.ONE
	sprite.position = combat.sprite_point(cyrus)
	await settle(2)
	LightView.plays_headless = false
	await end_fight()
	log_line("")


## The sappers' fight from SEED, the party passing every turn, for `rounds` of the party's turns: its state after each.
func play(rounds: int) -> Array:
	var source: EncounterDefinition = load(SAPPERS)
	var encounter := EncounterDefinition.new()
	encounter.display_name = "Depth"
	encounter.terrain_scene = source.terrain_scene
	var spawns: Array[SpawnDefinition] = []
	var used := []
	for wanted in [["enfina", 0], ["cyrus", 0], ["barbarian", 1], ["ranger", 1]]:
		for spawn in source.spawns:
			if spawn.combatant_key == wanted[0] and spawn.side == wanted[1] and not used.has(spawn):
				used.append(spawn)
				spawns.append(spawn.duplicate())
				break
	encounter.spawns = spawns
	encounter.set_meta("seed", SEED)
	var combat := await start_fight(encounter)
	combat.finish_deployment()
	var states := []
	var turns := 0
	while not combat.combat_over and turns < rounds:
		while not combat.combat_over and not (combat.controller.player_turn and combat.plays_for_party(combat.get_current_combatant())):
			await get_tree().process_frame
		if combat.combat_over:
			break
		states.append(combat.fight_state())
		await combat.advance_turn()
		turns += 1
	states.append("view" if combat.depth_view != null else "no view")
	await end_fight()
	return states


func only_a_look():
	log_line("======== only a look: the same fight with it and without ========")
	GameSettings._enemy_speed = 2
	var without: Array = await play(8)
	LightView.plays_headless = true
	var with: Array = await play(8)
	LightView.plays_headless = false
	ok(without.back() == "no view" and with.back() == "view", "one fight played headless with nothing drawn, and once with the depth made")
	var same := without.size() == with.size() and without.size() > 4
	var parted := -1
	for i in mini(without.size(), with.size()) - 1:
		if without[i] != with[i]:
			same = false
			parted = i if parted < 0 else parted
	ok(same, "from one seed, the fight is the same after every one of the party's turns", "%d turns, parted at %d" % [without.size() - 1, parted])
	log_line("")
