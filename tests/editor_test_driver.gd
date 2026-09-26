extends Node
## Headless test for the encounter editor tool: load -> move -> save -> reload,
## plus every validation rule that must block a save.
## Runs against a throwaway copy of the project, never the real one.

var LOG_PATH := HarnessLog.path_for("editor")
const ENCOUNTER = "res://encounters/encounter_01_ambush.tres"

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
	get_tree().create_timer(90.0).timeout.connect(func(): get_tree().quit(2))
	await get_tree().process_frame
	await get_tree().process_frame
	await run_test()


func make_editor(encounter: EncounterDefinition) -> Node:
	var editor = load("res://scenes/encounter_editor.tscn").instantiate()
	get_tree().root.add_child(editor)
	editor.encounter = encounter
	editor.rebuild()
	await get_tree().process_frame
	return editor


func run_test():
	log_line("======== the markers saved in the scene are usable as they are ========")
	# The editor scene keeps whatever markers were last built, and saving reads
	# their fields straight back. A field that comes back null rather than empty
	# would take the save down on a bag nobody had touched - and the file really
	# does write "starting_items = null" for markers made before the field
	# existed. So this asks what actually comes out of the scene, before
	# anything rebuilds and hides it.
	var as_saved = load("res://scenes/encounter_editor.tscn").instantiate()
	get_tree().root.add_child(as_saved)
	await get_tree().process_frame
	var checked := 0
	var broken := []
	for marker in as_saved.markers():
		checked += 1
		if not (marker.starting_items is Array):
			broken.append("%s: %s" % [marker.combatant_key, typeof(marker.starting_items)])
	ok(checked > 0, "there are markers saved in the scene", "%d" % checked)
	ok(broken.is_empty(), "and every bag reads back as a list", "%s" % [broken])
	as_saved.queue_free()
	await get_tree().process_frame
	log_line("")

	log_line("======== load from encounter ========")
	var original: EncounterDefinition = load(ENCOUNTER)
	var original_count = original.spawns.size()
	var bags_before := {}
	for spawn in original.spawns:
		if spawn.side == 0:
			bags_before[spawn.combatant_key] = Array(spawn.starting_items).duplicate()
	var original_terrain = original.terrain_scene
	var editor = await make_editor(original)

	ok(editor.get_node_or_null("TerrainPreview") != null, "terrain preview built")
	ok(editor.get_node_or_null("TerrainPreview/TileMap") != null, "preview exposes the TileMap")
	var grid = editor.get_node_or_null("TerrainPreview/Grid")
	ok(grid != null and grid.visible, "grid overlay turned on for placement")
	var markers = editor.markers()
	ok(markers.size() == original_count, "one marker per spawn", "%d" % markers.size())
	var by_name = {}
	for m in markers:
		by_name[m.effective_name()] = m
	ok(by_name.has("Ranger"), "display names carried onto markers", "%s" % [by_name.keys()])
	ok(markers[0].texture != null, "markers show the combatant icon")
	log_line("")

	log_line("======== markers sit on their spawn tiles ========")
	# Compared as a set of tiles rather than keyed by who stands on them: an
	# encounter can field three of the same combatant, and keying by name would
	# quietly keep only the last of them.
	var expected = {}
	for spawn in original.spawns:
		expected[spawn.position] = spawn.combatant_key
	var mismatches = 0
	for m in markers:
		var tile = m.grid_position()
		if not expected.has(tile) or expected[tile] != m.combatant_key:
			mismatches += 1
			log_line("    %s at %s, which no spawn asked for" % [m.combatant_key, tile])
	ok(mismatches == 0 and markers.size() == original.spawns.size(),
		"every marker round-trips to its own tile", "%d markers, %d spawns" % [markers.size(), original.spawns.size()])
	log_line("")

	log_line("======== drag, save, reload ========")
	var mover = by_name["Ranger"]
	var moved_from = mover.grid_position()
	# Drop it somewhere else legal, deliberately off-centre to prove snapping.
	# A tile the map says is free, found rather than written in: where a given
	# map has room is content, and a marker dropped in a wall is refused by the
	# very rules this is here to exercise.
	var drop_on = _free_tile(editor)
	# Deliberately off-centre, to prove the marker snaps to one tile.
	mover.position = Vector2(drop_on.x * Grid.TILE_SIZE + 11, drop_on.y * Grid.TILE_SIZE + 25)
	ok(mover.grid_position() == drop_on, "off-centre drop resolves to one tile", "%s" % mover.grid_position())
	editor.save_to_encounter()
	log_line("  NOTE  status after save: %s" % editor.status.replace("
", " / "))
	await get_tree().process_frame

	var reloaded: EncounterDefinition = ResourceLoader.load(ENCOUNTER, "", ResourceLoader.CACHE_MODE_IGNORE)
	ok(reloaded.spawns.size() == original_count, "spawn count preserved", "%d" % reloaded.spawns.size())
	ok(reloaded.terrain_scene == original_terrain or reloaded.terrain_scene.resource_path == original_terrain.resource_path,
		"terrain_scene preserved")
	ok(reloaded.display_name == original.display_name, "display_name preserved", "'%s'" % reloaded.display_name)
	var saved_ranger = null
	for spawn in reloaded.spawns:
		if spawn.display_name == "Ranger":
			saved_ranger = spawn
	ok(saved_ranger != null and saved_ranger.position == drop_on,
		"moved spawn saved at its new tile", "%s -> %s" % [moved_from, saved_ranger.position if saved_ranger else "?"])
	ok(saved_ranger != null and saved_ranger.combatant_key == "ranger" and saved_ranger.side == 1,
		"key and side preserved")
	var players_first = reloaded.spawns[0].side == 0 and reloaded.spawns[-1].side == 1
	ok(players_first, "saved in a stable order, players first")

	# Saving builds a fresh SpawnDefinition out of the markers, so anything the
	# marker does not carry is quietly dropped. Bags were not carried: one press
	# of the button emptied every one in the encounter and said nothing about it,
	# because the button reports how many spawns it wrote rather than what it
	# kept. Checked for every player, not just the one that moved.
	var emptied := []
	var kept := 0
	for spawn in reloaded.spawns:
		if spawn.side != 0:
			continue
		var was: Array = bags_before.get(spawn.combatant_key, [])
		if Array(spawn.starting_items) != was:
			emptied.append("%s had %s, now %s" % [spawn.combatant_key, was, spawn.starting_items])
		elif not was.is_empty():
			kept += 1
	ok(emptied.is_empty(), "and every bag survived the round trip", "%s" % [emptied])
	ok(kept > 0, "with something in at least one of them to survive",
		"%d bags checked" % kept)
	log_line("")

	log_line("======== the encounter still actually loads and plays ========")
	Campaign.current_encounter = reloaded
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	ok(combat.combatants.size() == original_count, "edited encounter spawns everyone", "%d" % combat.combatants.size())
	var ranger_in_game = null
	for comb in combat.combatants:
		if comb.name == "Ranger":
			ranger_in_game = comb
	ok(ranger_in_game != null and ranger_in_game.position == drop_on,
		"the dragged unit starts where it was dropped", "%s" % [ranger_in_game.position if ranger_in_game else "?"])
	get_tree().root.remove_child(game)
	game.free()
	log_line("")

	log_line("======== save refuses bad placements ========")
	var tile_map = editor.get_node("TerrainPreview/TileMap")

	var off_map = editor.markers()[0]
	var safe_spot = off_map.position
	off_map.position = Vector2(9999, 9999)
	ok(editor.placement_problem(off_map, tile_map).contains("off the edge"),
		"off the map rejected", "'%s'" % editor.placement_problem(off_map, tile_map))
	off_map.position = safe_spot

	var no_key = editor.markers()[1]
	var real_key = no_key.combatant_key
	no_key.combatant_key = ""
	ok(editor.placement_problem(no_key, tile_map).contains("no combatant chosen"),
		"empty combatant key rejected")
	no_key.combatant_key = real_key

	# Two markers on one tile: the exact mistake that put bob and alexandra
	# on the same tile by hand.
	var a = editor.markers()[0]
	var b = editor.markers()[1]
	var b_home = b.position
	b.position = a.position
	var before_bad_save = FileAccess.get_file_as_string(ENCOUNTER)
	editor.save_to_encounter()
	await get_tree().process_frame
	ok(FileAccess.get_file_as_string(ENCOUNTER) == before_bad_save,
		"overlapping markers block the save, file left untouched")
	b.position = b_home

	# All enemies removed.
	for m in editor.markers():
		if m.side == 1:
			m.queue_free()
	await get_tree().process_frame
	editor.save_to_encounter()
	await get_tree().process_frame
	ok(FileAccess.get_file_as_string(ENCOUNTER) == before_bad_save,
		"an encounter with no enemies blocks the save")
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


## A tile on the editor's map that a ground unit can stand on and no marker is
## already using - somewhere a drag can legally end.
func _free_tile(editor) -> Vector2i:
	var terrain = editor.get_node_or_null("TerrainPreview")
	var tile_map: TileMap = terrain.get_node("TileMap") if terrain != null else null
	if tile_map == null:
		return Vector2i(14, 12)
	var taken = {}
	for marker in editor.markers():
		taken[marker.grid_position()] = true
	for cell in tile_map.get_used_cells(0):
		var data = tile_map.get_cell_tile_data(0, cell)
		if data == null or 0 in data.get_custom_data("Blocks") or taken.has(cell):
			continue
		return cell
	return Vector2i(14, 12)
