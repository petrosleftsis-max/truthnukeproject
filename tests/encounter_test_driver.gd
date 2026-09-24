extends Node
## Headless harness for the encounter system: data validity, per-encounter
## scene bring-up, pathfinding grid sizing, and party carry-over.

var LOG_PATH := HarnessLog.path_for("encounter")
const ENCOUNTERS = [
	"res://encounters/encounter_01_ambush.tres",
	"res://encounters/encounter_02_sappers.tres",
	"res://encounters/encounter_03_watcher.tres",
]

var _log: FileAccess = null
var _fail = 0
var _game: Node = null


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
	get_tree().create_timer(120.0).timeout.connect(func():
		log_line("WATCHDOG")
		get_tree().quit(2)
	)
	await get_tree().process_frame
	await get_tree().process_frame
	await run_test()


## Brings up game.tscn for `encounter`, exactly the way the level select does.
func load_battle(encounter: EncounterDefinition) -> Node:
	unload_battle()
	Campaign.current_encounter = encounter
	var packed: PackedScene = load("res://scenes/game.tscn")
	_game = packed.instantiate()
	get_tree().root.add_child(_game)
	await get_tree().process_frame
	await get_tree().process_frame
	return _game


func unload_battle():
	if _game != null:
		get_tree().root.remove_child(_game)
		_game.free()
		_game = null


func run_test():
	log_line("======== encounter data ========")
	for path in ENCOUNTERS:
		var enc: EncounterDefinition = load(path)
		log_line("%s -> '%s' (%d spawns)" % [path.get_file(), enc.display_name, enc.spawns.size()])
		ok(enc.terrain_scene != null, "  has a terrain scene")
		var seen := {}
		var players = 0
		var enemies = 0
		for spawn in enc.spawns:
			ok(CombatantDatabase.combatants.has(spawn.combatant_key),
				"  key '%s' exists" % spawn.combatant_key)
			ok(not seen.has(spawn.position),
				"  tile %s used once" % spawn.position)
			seen[spawn.position] = true
			if spawn.side == 0:
				players += 1
			else:
				enemies += 1
		ok(players > 0, "  has players", "%d" % players)
		ok(enemies > 0, "  has enemies", "%d" % enemies)
	log_line("")

	log_line("======== bring-up per encounter ========")
	for path in ENCOUNTERS:
		var enc: EncounterDefinition = load(path)
		var game = await load_battle(enc)
		var terrain = game.get_node_or_null("Terrain")
		var tile_map = game.get_node_or_null("Terrain/TileMap")
		var combat = game.get_node_or_null("VisualCombat")
		var controller = game.get_node_or_null("Controller")
		var camera = game.get_node_or_null("Camera2D")
		log_line("'%s':" % enc.display_name)
		ok(terrain != null, "  terrain instantiated as 'Terrain'")
		ok(tile_map != null, "  Terrain/TileMap resolves")
		# Player spawns are tiles the roster fills, not fixed people, so an
		# encounter with more starting tiles than the party has fighters
		# legitimately leaves some empty. Every enemy must appear; the player
		# side is capped by the roster.
		var enemy_spawns = 0
		for spawn in enc.spawns:
			if spawn.side != 0:
				enemy_spawns += 1
		var player_tiles = enc.spawns.size() - enemy_spawns
		var expected = enemy_spawns + mini(Campaign.battle_party().size(), player_tiles)
		ok(combat != null and combat.combatants.size() == expected,
			"  spawned everyone there was room and roster for",
			"%d of %d (%d enemies + up to %d party)" % [combat.combatants.size() if combat else -1, expected, enemy_spawns, player_tiles])
		# The pathfinding grid must match the map, not a hard-coded size.
		var used = tile_map.get_used_rect()
		ok(controller._astargrid.region == used,
			"  pathfinding grid matches map", "%s" % used)
		ok(camera != null and camera.get_map_rect().size == Vector2(used.size) * Grid.TILE_SIZE,
			"  camera clamped to this map", "%s" % camera.get_map_rect().size)
		# Every spawn must be somewhere a unit could actually stand.
		for spawn in enc.spawns:
			var definition = CombatantDatabase.combatants[spawn.combatant_key]
			ok(controller.is_in_bounds(spawn.position),
				"  %s in bounds at %s" % [spawn.combatant_key, spawn.position])
			ok(not controller.is_tile_blocking(spawn.position, definition.class_m),
				"  %s on a walkable tile at %s" % [spawn.combatant_key, spawn.position])
		log_line("")

	log_line("======== party carries damage forward ========")
	Campaign.reset()
	var enc1: EncounterDefinition = load(ENCOUNTERS[0])
	var game1 = await load_battle(enc1)
	var combat1 = game1.get_node("VisualCombat")
	var wounded = null
	for comb in combat1.combatants:
		if comb.side == 0:
			wounded = comb
			break
	var wounded_key = wounded.combatant_key
	var full_hp = wounded.hp
	wounded.hp = 3
	ok(wounded_key != "", "player carries its database key", "'%s'" % wounded_key)
	combat1.combat_finish()
	ok(Campaign.party_state.has(wounded_key), "party state recorded on combat end")
	ok(Campaign.party_state[wounded_key].hp == 3, "wounded hp stored", "%s" % Campaign.party_state.get(wounded_key))

	var enc2: EncounterDefinition = load(ENCOUNTERS[1])
	var game2 = await load_battle(enc2)
	var combat2 = game2.get_node("VisualCombat")
	var carried = null
	for comb in combat2.combatants:
		if comb.get("combatant_key", "") == wounded_key:
			carried = comb
			break
	ok(carried != null and carried.hp == 3,
		"next encounter starts them wounded", "hp=%s (full would be %s)" % [carried.hp if carried else "?", full_hp])
	log_line("")

	log_line("======== the dead stay dead, and reset revives ========")
	Campaign.party_state[wounded_key] = {"hp": 0, "alive": false}
	var game3 = await load_battle(load(ENCOUNTERS[2]))
	var combat3 = game3.get_node("VisualCombat")
	var found_dead = false
	for comb in combat3.combatants:
		if comb.get("combatant_key", "") == wounded_key:
			found_dead = true
	ok(not found_dead, "dead party member is left out of the next battle")
	ok(Campaign.is_party_wiped() == false, "party not reported wiped while others live")

	Campaign.reset()
	var game4 = await load_battle(load(ENCOUNTERS[2]))
	var combat4 = game4.get_node("VisualCombat")
	var revived = null
	for comb in combat4.combatants:
		if comb.get("combatant_key", "") == wounded_key:
			revived = comb
	# Full health means full for the level they spawn at HERE, which need not be
	# the level they were in the first encounter - Cyrus is 1 in the ambush and 3
	# in the watcher, and has different HP at each.
	ok(revived != null and revived.hp == revived.max_hp and revived.alive,
		"reset brings them back at full health",
		"hp=%s/%s" % [revived.hp if revived else "absent", revived.max_hp if revived else "?"])
	log_line("")

	log_line("======== level select ========")
	var menu = load("res://scenes/level_select.tscn").instantiate()
	get_tree().root.add_child(menu)
	await get_tree().process_frame
	var list = menu.get_node("Center/VBox/EncounterList")
	ok(list.get_child_count() == 3, "one button per encounter", "%d" % list.get_child_count())
	var first_encounter: EncounterDefinition = menu.encounters[0]
	ok(list.get_child(0).text == first_encounter.display_name,
		"first button carries the encounter's own name",
		"'%s' vs '%s'" % [list.get_child(0).text, first_encounter.display_name])
	var reset_button = menu.get_node("Center/VBox/ResetButton")
	ok(list.get_child(0).get_node(list.get_child(0).focus_neighbor_bottom) == list.get_child(1),
		"focus cycles between encounter buttons")
	ok(reset_button.get_node(reset_button.focus_neighbor_bottom) == list.get_child(0),
		"focus wraps from Reset back to the first encounter")
	# A wiped party leaves nothing playable, so entries must be disabled.
	Campaign.party_state = {"steve": {"hp": 0, "alive": false}}
	menu._rebuild()
	await get_tree().process_frame
	ok(Campaign.is_party_wiped(), "wiped party detected")
	ok(menu.get_node("Center/VBox/EncounterList").get_child(0).disabled,
		"encounters disabled while the party is wiped")
	Campaign.reset()
	menu._rebuild()
	await get_tree().process_frame
	ok(not menu.get_node("Center/VBox/EncounterList").get_child(0).disabled,
		"reset re-enables them")
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
