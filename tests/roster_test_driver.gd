extends Node
## Tests the roster/encounter link: deployment from the campaign party, tiles
## the player can rearrange, non-combatants sitting battles out, and story
## recruiting.

var LOG_PATH := HarnessLog.path_for("roster")
const ENCOUNTER = "res://encounters/encounter_01_ambush.tres"

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
	get_tree().create_timer(120.0).timeout.connect(func(): get_tree().quit(2))
	await get_tree().process_frame
	await get_tree().process_frame
	await run_test()


func load_battle() -> Node:
	if _game != null:
		get_tree().root.remove_child(_game)
		_game.free()
	Campaign.current_encounter = test_encounter()
	_game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(_game)
	await get_tree().process_frame
	await get_tree().process_frame
	return _game


func player_names(combat) -> Array:
	var names = []
	for comb in players(combat):
		names.append(comb.name)
	return names


## The party, in the order they were deployed. Enemies are spawned before the
## party, so combatants[0] is not a player.
func players(combat) -> Array:
	var found = []
	for comb in combat.combatants:
		if comb.side == 0:
			found.append(comb)
	return found


func run_test():
	log_line("======== the roster decides who fights ========")
	Campaign.reset()
	Campaign.seed_party(["cyrus", "enfina"])  # deliberately not the encounter's own order
	var game = await load_battle()
	var combat = game.get_node("VisualCombat")
	var controller = game.get_node("Controller")
	ok(player_names(combat).size() == 2, "only the roster is deployed, not the encounter's list", "%s" % [player_names(combat)])
	ok(players(combat)[0].combatant_key == "cyrus", "deployed in marching order", "%s" % players(combat)[0].combatant_key)
	ok(combat.deployment_tiles.size() == 4, "every player tile offered as an option", "%s" % [combat.deployment_tiles])
	log_line("")

	log_line("======== recruiting mid-story puts them in the next fight ========")
	Campaign.add_member("prometheus")
	ok(Campaign.party_order.size() == 3, "roster grew", "%s" % [Campaign.party_order])
	game = await load_battle()
	combat = game.get_node("VisualCombat")
	ok(player_names(combat).size() == 3, "the new recruit is deployed too", "%s" % [player_names(combat)])
	Campaign.remove_member("prometheus")
	game = await load_battle()
	combat = game.get_node("VisualCombat")
	ok(player_names(combat).size() == 2, "and leaving takes them back out", "%s" % [player_names(combat)])
	log_line("")

	log_line("======== a follower who can't fight stays out of battles ========")
	var tagalong: CombatantDefinition = CombatantDatabase.combatants["enfina"].duplicate()
	tagalong.name = "Tagalong"
	tagalong.can_fight = false
	CombatantDatabase.combatants["tagalong"] = tagalong
	Campaign.add_member("tagalong")
	ok(Campaign.living_party().has("tagalong"), "travels with the party")
	ok(not Campaign.battle_party().has("tagalong"), "but isn't in the battle party")
	ok(Campaign.party_members().size() == 3, "and still shows in the portraits", "%d" % Campaign.party_members().size())
	game = await load_battle()
	combat = game.get_node("VisualCombat")
	ok(not player_names(combat).has("Tagalong"), "not deployed into the encounter", "%s" % [player_names(combat)])
	Campaign.remove_member("tagalong")
	log_line("")

	log_line("======== choosing starting tiles ========")
	game = await load_battle()
	combat = game.get_node("VisualCombat")
	controller = game.get_node("Controller")
	ok(combat.deployment_active, "battle opens in deployment, not on a turn")
	ok(controller._deployment_active, "controller is placing, so movement input is off")
	var party = players(combat)
	var first = party[0]
	var second = party[1]
	var first_tile = first.position
	var second_tile = second.position
	# Swap the two heroes between their tiles.
	controller._deployment_selection = first
	controller._swap_deployed(first, second_tile)
	ok(first.position == second_tile and second.position == first_tile,
		"clicking a hero then an occupied tile swaps them", "%s <-> %s" % [first.position, second.position])
	ok(first.sprite.position == controller.tile_map.map_to_local(second_tile),
		"the sprite moves with them")
	# Move onto a free starting tile.
	var free_tile = Vector2i(-1, -1)
	for tile in combat.deployment_tiles:
		if combat.get_combatant_at(tile).is_empty():
			free_tile = tile
	ok(free_tile.x >= 0, "there is a spare starting tile", "%s" % free_tile)
	var vacated = first.position
	controller._swap_deployed(first, free_tile)
	ok(first.position == free_tile, "and moving onto a free one works", "%s" % first.position)
	ok(controller._occupied_spaces.has(free_tile) and not controller._occupied_spaces.has(vacated),
		"occupancy tracking follows the move", "left %s, took %s" % [vacated, free_tile])
	log_line("")

	log_line("======== enemies can't be rearranged ========")
	var enemy = null
	for comb in combat.combatants:
		if comb.side == 1:
			enemy = comb
	var enemy_tile = enemy.position
	controller._swap_deployed(second, enemy_tile)
	ok(enemy.position == enemy_tile, "an enemy's tile is not the player's to take", "%s" % enemy.position)
	var enemy_home = enemy.position
	controller._swap_deployed(enemy, free_tile)
	ok(enemy.position == enemy_home, "and an enemy can't be picked up either", "%s" % enemy.position)
	log_line("")

	log_line("======== beginning the battle ========")
	var ui = game.get_node("CanvasLayer/UI")
	ok(ui.get_node("Actions/EndTurnButton").text == "Begin Battle", "End Turn reads Begin Battle", "'%s'" % ui.get_node("Actions/EndTurnButton").text)
	combat.finish_deployment()
	await get_tree().process_frame
	ok(not combat.deployment_active, "deployment over")
	ok(not controller._deployment_active, "controller back to normal input")
	ok(ui.get_node("Actions/EndTurnButton").text != "Begin Battle", "button reads End Turn again", "'%s'" % ui.get_node("Actions/EndTurnButton").text)
	log_line("")

	log_line("======== menu-launched battles still work with no roster ========")
	Campaign.reset()
	game = await load_battle()
	combat = game.get_node("VisualCombat")
	var own_party = 0
	for spawn in test_encounter().spawns:
		if spawn.side == 0:
			own_party += 1
	ok(player_names(combat).size() == own_party, "falls back to the encounter's own party",
		"%s, encounter lists %d" % [player_names(combat), own_party])
	log_line("")

	Campaign.reset()
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


## Built for this test rather than borrowed from the game.
##
## Deployment is about a roster being fitted into starting tiles, so these rules
## only have anything to prove when there are more tiles than there are people
## to stand on them - and how many starting tiles a hand-made encounter offers
## is content, which moves. Four player tiles and two enemies, on whatever
## tiles the map says are walkable.
var _built: EncounterDefinition = null

func test_encounter() -> EncounterDefinition:
	if _built != null:
		return _built
	var borrowed: EncounterDefinition = load(ENCOUNTER)
	_built = EncounterDefinition.new()
	_built.display_name = "Roster Test"
	_built.terrain_scene = borrowed.terrain_scene
	var map = borrowed.terrain_scene.instantiate()
	add_child(map)
	var tile_map: TileMap = map.get_node("TileMap")
	var open: Array = []
	for cell in tile_map.get_used_cells(0):
		var data = tile_map.get_cell_tile_data(0, cell)
		if data != null and not (0 in data.get_custom_data("Blocks")):
			open.append(cell)
		if open.size() >= 6:
			break
	map.queue_free()
	var spawns: Array[SpawnDefinition] = []
	for i in mini(open.size(), 6):
		var spawn = SpawnDefinition.new()
		spawn.combatant_key = ["cyrus", "enfina", "prometheus", "alithia", "priest", "ranger"][i]
		spawn.side = 0 if i < 4 else 1
		spawn.position = open[i]
		spawns.append(spawn)
	_built.spawns = spawns
	return _built
