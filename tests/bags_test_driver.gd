extends Node
## Who carries what into which fight.
##
## A battle opened from Arena Mode hands out exactly what its spawns list, and
## nothing when they list nothing. A battle walked into from a map keeps the
## bags the party walked in with.

var LOG_PATH := HarnessLog.path_for("bags")
var _log: FileAccess
var _fail = 0

func log_line(t): _log.store_line(t); _log.flush()

func ok(condition: bool, label: String, detail: String = ""):
	if condition:
		log_line("  PASS  %s %s" % [label, detail])
	else:
		_fail += 1
		log_line("  FAIL  %s %s" % [label, detail])

func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(200.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


func carried(key: String) -> Array:
	var held := []
	for slot in Campaign.inventory_of(key):
		if slot != "":
			held.append(slot)
	return held


func run_test():
	log_line("======== a spawn can say what somebody brings ========")
	var spawn := SpawnDefinition.new()
	ok("starting_items" in spawn, "a spawn has a bag to fill")
	ok(spawn.starting_items.is_empty(), "empty until somebody fills it")
	log_line("")

	log_line("======== Arena Mode hands out what the encounter says ========")
	var encounter: EncounterDefinition = load("res://encounters/encounter_02_sappers.tres").duplicate(true)
	# Give the first player spawn a bag, and empty every other one - the shipped
	# encounters arm their whole party, and this is about a spawn that does not.
	var filled_key = ""
	for spawn_definition in encounter.spawns:
		if spawn_definition.side != 0:
			continue
		if filled_key == "":
			spawn_definition.starting_items = ["cure_potion", "tiny_bomb"]
			filled_key = spawn_definition.combatant_key
		else:
			spawn_definition.starting_items = []
	Campaign.reset()
	# Somebody carrying junk from an earlier run, to prove it is replaced.
	Campaign.set_inventory("cyrus", ["medicine", "medicine", "medicine"])
	Campaign.current_encounter = encounter
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	for i in 6:
		await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await get_tree().process_frame

	var party = Campaign.battle_party()
	ok(not party.is_empty(), "somebody turned up", "%s" % [party])
	var first = party[0]
	ok(carried(first) == ["cure_potion", "tiny_bomb"],
		"the first fighter carries what the spawn listed", "%s: %s" % [first, carried(first)])
	var others_empty := []
	for key in party.slice(1):
		if not carried(key).is_empty():
			others_empty.append("%s: %s" % [key, carried(key)])
	ok(others_empty.is_empty(),
		"and nobody else was handed anything at all", "%s" % [others_empty])
	# What the fight itself offers them.
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == first:
			ok(combat.items_of(comb) == ["cure_potion", "tiny_bomb"],
				"the Consumables panel shows the same two", "%s" % [combat.items_of(comb)])
	game.queue_free()
	await get_tree().process_frame
	log_line("")

	log_line("======== a character's own kit is not an arena supply ========")
	var stocked := []
	for key in CombatantDatabase.combatants:
		var definition: CombatantDefinition = CombatantDatabase.combatants[key]
		if not definition.starting_items.is_empty():
			stocked.append(key)
	ok(not stocked.is_empty(), "somebody has a kit in the database", "%s" % [stocked])
	Campaign.reset()
	var bare: EncounterDefinition = load("res://encounters/encounter_02_sappers.tres").duplicate(true)
	for spawn_definition in bare.spawns:
		spawn_definition.starting_items = []
	Campaign.current_encounter = bare
	var second = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(second)
	for i in 6:
		await get_tree().process_frame
	var bare_combat = second.get_node("VisualCombat")
	if bare_combat.deployment_active:
		bare_combat.finish_deployment()
		await get_tree().process_frame
	var anybody_holding := []
	for comb in bare_combat.combatants:
		if comb.side == 0 and not bare_combat.items_of(comb).is_empty():
			anybody_holding.append("%s: %s" % [comb.name, bare_combat.items_of(comb)])
	ok(anybody_holding.is_empty(),
		"an encounter that lists nothing gives nothing", "%s" % [anybody_holding])
	second.queue_free()
	await get_tree().process_frame
	log_line("")

	log_line("======== what you walk in with, you keep ========")
	Campaign.reset()
	Campaign.current_map = "res://skills/laboratory_terrain_explore.tscn"
	var walk = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(walk)
	for i in 5:
		await get_tree().process_frame
	var walker = Campaign.living_party()[0]
	Campaign.set_inventory(walker, ["shock_bottle", "cure_potion"])
	var packed = carried(walker)
	Campaign.begin_battle_from_exploration(
		load("res://encounters/encounter_02_sappers.tres"),
		"res://skills/laboratory_terrain_explore.tscn", Vector2.ZERO, "bags_trigger")
	walk.queue_free()
	await get_tree().process_frame
	var third = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(third)
	for i in 6:
		await get_tree().process_frame
	var map_combat = third.get_node("VisualCombat")
	if map_combat.deployment_active:
		map_combat.finish_deployment()
		await get_tree().process_frame
	ok(carried(walker) == packed,
		"the bag they walked in with is untouched by the encounter's spawns",
		"%s: %s" % [walker, carried(walker)])
	third.queue_free()
	await get_tree().process_frame
	log_line("")

	log_line("======== a map hands out what it says it does, and no more ========")
	# Maps used to hand out nothing at all. One of them now opens a stretch of
	# the story with a kit, so the rule to check is that the bags match the
	# map's own MapSetup rather than that they are empty.
	for map in ["res://scenes/explore_crossroads.tscn",
			"res://skills/laboratory_terrain_explore.tscn", "res://church.tscn"]:
		Campaign.reset()
		Campaign.current_map = map
		var scene = load("res://scenes/exploration.tscn").instantiate()
		get_tree().root.add_child(scene)
		for i in 5:
			await get_tree().process_frame
		var declared: MapSetup = null
		for node in scene.get_node(scene.MAP_NODE).get_children():
			if node is MapSetup:
				declared = node
		var unexplained := []
		var missing := []
		for key in Campaign.living_party():
			var kit: Array = declared.kit_for(key) if declared != null else []
			var bag: Array = carried(key)
			# Every kit item is there...
			for item in kit:
				if not item in bag:
					missing.append("%s has no %s" % [key, item])
			# ...and nothing is there that the map did not put there, as long as
			# the map empties them first. A map that does not is entitled to
			# whatever their database entry gives them.
			if declared != null and declared.empty_handed:
				for item in bag:
					if not item in kit:
						unexplained.append("%s also has %s" % [key, item])
		ok(missing.is_empty(), "%s hands out everything it names" % map.get_file(),
			"%s" % [missing])
		ok(unexplained.is_empty(), "%s hands out nothing it does not" % map.get_file(),
			"%s" % [unexplained])
		if declared != null and declared.hands_kit_out():
			log_line("  NOTE  %s opens with %s, plus %s" % [map.get_file(),
				declared.everyone_carries, declared.also_carries])
		scene.queue_free()
		await get_tree().process_frame
	log_line("")

	log_line("======== but the arena kits them out ========")
	for path in DirAccess.open("res://encounters").get_files():
		if not path.ends_with(".tres"):
			continue
		Campaign.reset()
		var fight: EncounterDefinition = load("res://encounters/".path_join(path))
		Campaign.current_encounter = fight
		var arena = load("res://scenes/game.tscn").instantiate()
		get_tree().root.add_child(arena)
		for i in 6:
			await get_tree().process_frame
		var fight_combat = arena.get_node("VisualCombat")
		if fight_combat.deployment_active:
			fight_combat.finish_deployment()
			await get_tree().process_frame
		var empty_handed := []
		for comb in fight_combat.combatants:
			if comb.side == 0 and comb.alive and fight_combat.items_of(comb).is_empty():
				empty_handed.append(comb.name)
		ok(empty_handed.is_empty(), "%s arms its party" % fight.display_name,
			"nobody gave anything to %s" % [empty_handed])
		arena.queue_free()
		await get_tree().process_frame
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
