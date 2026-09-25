extends Node
## Leaving a fight, Arena Mode's party, gates, empty hands, and carried bags.

var LOG_PATH := HarnessLog.path_for("leave")
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


func run_test():
	log_line("======== what each level opens ========")
	ok(Stats.gates_for_level(2)[2] == 2,
		"two through Hermes at level 2", "%s" % [Stats.gates_for_level(2).slice(1)])
	ok(Stats.gates_for_level(1)[2] == 0, "none at level 1")
	ok(Stats.gates_for_level(3)[2] == 3, "three at level 3")
	ok(Stats.gates_for_level(2)[3] == 1,
		"Yaldabaoth opens once at level 2", "%s" % [Stats.gates_for_level(2).slice(1)])
	ok(Stats.gates_for_level(3)[3] == 2,
		"and twice at level 3", "%s" % [Stats.gates_for_level(3).slice(1)])
	ok(Stats.gates_for_level(1)[3] == 0, "still none at level 1")
	log_line("")

	log_line("======== the crossroads starts Cyrus empty-handed ========")
	Campaign.reset()
	Campaign.current_map = "res://scenes/explore_crossroads.tscn"
	var walk = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(walk)
	for i in 5:
		await get_tree().process_frame
	ok(Campaign.living_party() == ["cyrus"], "he is on his own", "%s" % [Campaign.living_party()])
	var carried = Campaign.inventory_of("cyrus")
	var anything = false
	for slot in carried:
		if slot != "":
			anything = true
	ok(not anything, "and carrying nothing at all", "%s" % [carried.slice(0, 4)])
	ok(not CombatantDatabase.combatants["cyrus"].starting_items.is_empty(),
		"even though his kit says otherwise - the map overrode it",
		"%s" % [CombatantDatabase.combatants["cyrus"].starting_items])
	walk.queue_free()
	await get_tree().process_frame
	log_line("")

	log_line("======== what you carry in, you carry into the fight ========")
	Campaign.reset()
	Campaign.current_map = "res://scenes/laboratory_terrain_explore.tscn"
	var lab = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(lab)
	for i in 5:
		await get_tree().process_frame
	Campaign.give_item("cyrus", "shock_bottle")
	var packed = Campaign.inventory_of("cyrus").duplicate()
	var to_hand = Campaign.combat_items_of("cyrus")
	ok(not to_hand.is_empty(), "he has something packed", "%s" % [to_hand])
	# Walk into a fight the way an encounter trigger does.
	Campaign.begin_battle_from_exploration(
		load("res://encounters/encounter_02_sappers.tres"),
		"res://scenes/laboratory_terrain_explore.tscn", Vector2.ZERO, "test_trigger")
	lab.queue_free()
	await get_tree().process_frame
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	for i in 6:
		await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await get_tree().process_frame
	ok(Campaign.inventory_of("cyrus") == packed,
		"his bag came with him unchanged", "%s" % [Campaign.inventory_of("cyrus").slice(0, 4)])
	var cyrus = null
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == "cyrus":
			cyrus = comb
	if cyrus != null:
		ok(combat.items_of(cyrus) == to_hand,
			"and he can reach the same things in the fight", "%s" % [combat.items_of(cyrus)])
	log_line("")

	log_line("======== leaving a fight mid-swing does not take the game with it ========")
	# A hit-stop frozen at the moment the scene changes used to leave the whole
	# game at time_scale 0 - including the menu it was leaving to.
	combat.hit_stop(5.0)
	ok(Engine.time_scale == 0.0, "the world is frozen mid-hit", "%.1f" % Engine.time_scale)
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	ok(Engine.time_scale == 1.0,
		"and time starts again when the battle goes", "%.1f" % Engine.time_scale)
	log_line("")

	log_line("======== an AI walk that outlives its battle ========")
	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_02_sappers.tres")
	var game2 = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game2)
	for i in 6:
		await get_tree().process_frame
	var combat2 = game2.get_node("VisualCombat")
	if combat2.deployment_active:
		combat2.finish_deployment()
		await get_tree().process_frame
	var controller = combat2.controller
	ok(controller.still_in_a_battle(), "the controller knows it is in one")
	# Take the battle out of the tree, which is what pressing Arena Mode during
	# an enemy turn does to whatever coroutine is mid-await.
	get_tree().root.remove_child(game2)
	ok(not controller.still_in_a_battle(), "and knows when it is not")
	# The walk now has no tree to wait on. It should give up rather than reach
	# for get_tree() and take the game down with it.
	await controller.ai_move(Vector2i(0, 0))
	ok(true, "a walk asked for after the battle left simply returns")
	game2.queue_free()
	await get_tree().process_frame
	log_line("")

	log_line("======== going to the title screen stops the music ========")
	Music.play("Elegy_of_the_End")
	ok(Music.current() != "", "something is playing", Music.current())
	Campaign.to_main_menu()
	ok(Music.current() == "", "and the title screen is quiet", "'%s'" % Music.current())
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
