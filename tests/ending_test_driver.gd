extends Node
## How a battle ends: the encounter's own last word, and the way out.

var LOG_PATH := HarnessLog.path_for("ending")
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


## Wipes one side out, the way the last blow of a battle does.
func rout(combat, side: int):
	for comb in combat.combatants:
		if comb.side == side and comb.alive:
			comb.hp = 0
			combat.combatant_die(comb)


func run_test():
	log_line("======== an encounter can say how it ended ========")
	var encounter := EncounterDefinition.new()
	ok("victory_dialogue" in encounter, "there is somewhere to put the winning words")
	ok("defeat_dialogue" in encounter, "and the losing ones")
	ok(encounter.victory_dialogue_title == "start", "starting at 'start' unless told otherwise",
		encounter.victory_dialogue_title)
	var authored := 0
	for path in DirAccess.open("res://encounters").get_files():
		if not path.ends_with(".tres"):
			continue
		var real: EncounterDefinition = load("res://encounters/".path_join(path))
		if real.victory_dialogue != null or real.defeat_dialogue != null:
			authored += 1
	log_line("  (%d of the encounters have closing words written so far)" % authored)

	# Closing words are said over the result panel, so a conversation that
	# leaves the scene is a conversation that throws the panel away. The command
	# exists and is worth having - just not on the last word of a battle.
	for path in DirAccess.open("res://encounters").get_files():
		if not path.ends_with(".tres"):
			continue
		var real: EncounterDefinition = load("res://encounters/".path_join(path))
		for closing in [real.victory_dialogue, real.defeat_dialogue]:
			if closing == null:
				continue
			var source = FileAccess.open(closing.resource_path, FileAccess.READ)
			if source == null:
				continue
			var written = source.get_as_text()
			ok(not written.contains("to_main_menu"),
				"%s does not walk out of its own battle" % closing.resource_path.get_file())
	log_line("")

	log_line("======== the way out of a won battle ========")
	# The Watcher rather than the Lab Fight: the Lab Fight finishes its story
	# and has its own way out, tested further down.
	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_03_watcher.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	for i in 6:
		await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await get_tree().process_frame
	var result = game.get_node("ResultUI")
	ok(result != null, "there is a result panel")
	ok(not result.get_node("Panel").visible, "which stays out of the way while the fight runs")
	var main_menu_button = result.get_node_or_null("Panel/VBox/MainMenuButton")
	ok(main_menu_button != null, "and carries a way to the title screen")
	rout(combat, 1)
	await get_tree().process_frame
	ok(result.get_node("Panel").visible, "wiping out the enemy brings it up")
	ok(result.get_node("Panel/VBox/Title").text == "Victory", "reading Victory",
		result.get_node("Panel/VBox/Title").text)
	if main_menu_button != null:
		ok(main_menu_button.visible, "with Main Menu offered next to Back")
		ok(result.get_node("Panel/VBox/BackButton").visible, "and the way back still there")
	# The Lab Fight used to end by leaving on its own: its victory dialogue was
	# a single line, `do Campaign.to_main_menu()`, so the panel came up and the
	# screen immediately faded out from under it and the win was never read.
	# Winning stays where it is and lets the player pick the way out.
	for i in 30:
		await get_tree().process_frame
	ok(not SceneTransition._changing,
		"and winning does not take the player anywhere on its own")
	ok(result.get_node("Panel").visible, "the panel is still up a moment later")
	game.queue_free()
	await get_tree().process_frame
	log_line("")

	log_line("======== and out of one walked into from a map ========")
	# Entered the way the party enters one from a map, which used to leave
	# Continue as the only button on the panel.
	Campaign.reset()
	Campaign.begin_battle_from_exploration(
		load("res://encounters/encounter_03_watcher.tres"),
		"res://scenes/laboratory_terrain_explore.tscn", Vector2.ZERO, "ending_trigger")
	var second = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(second)
	for i in 6:
		await get_tree().process_frame
	var map_combat = second.get_node("VisualCombat")
	if map_combat.deployment_active:
		map_combat.finish_deployment()
		await get_tree().process_frame
	var map_result = second.get_node("ResultUI")
	rout(map_combat, 1)
	await get_tree().process_frame
	ok(map_result.get_node("Panel").visible, "winning it shows the panel here too")
	ok(map_result.get_node("Panel/VBox/Title").text == "Victory", "still reading Victory",
		map_result.get_node("Panel/VBox/Title").text)
	ok(map_result.get_node("Panel/VBox/BackButton").text == "Continue",
		"the map is offered as Continue", map_result.get_node("Panel/VBox/BackButton").text)
	ok(map_result.get_node("Panel/VBox/MainMenuButton").visible,
		"and the title screen is a choice as well")
	second.queue_free()
	await get_tree().process_frame
	log_line("")

	log_line("======== a fight that finishes its story ========")
	# The Lab Fight is the end of what it belongs to, so winning it offers the
	# title screen and nothing else - not Back to the battle list, and not
	# Continue on to the map. It used to go there on its own, without asking.
	for entered_from_a_map in [false, true]:
		Campaign.reset()
		var lab: EncounterDefinition = load("res://encounters/encounter_02_sappers.tres")
		ok(lab.victory_ends_the_run, "the Lab Fight says so itself")
		if entered_from_a_map:
			Campaign.begin_battle_from_exploration(lab,
				"res://scenes/laboratory_terrain_explore.tscn", Vector2.ZERO, "lab_trigger")
		else:
			# Campaign.reset() does not forget the map, so the previous section's
			# one is still there unless it is put down explicitly - and without
			# this the "from the battle list" half of this loop was quietly the
			# same case as the other half.
			Campaign.current_map = ""
			Campaign.return_to_position = false
			Campaign.current_encounter = lab
		ok(Campaign.has_map_to_return_to() == entered_from_a_map,
			"set up as a fight %s" % ("walked into from a map" if entered_from_a_map else "picked from the battle list"))
		var lab_game = load("res://scenes/game.tscn").instantiate()
		get_tree().root.add_child(lab_game)
		for i in 6:
			await get_tree().process_frame
		var lab_combat = lab_game.get_node("VisualCombat")
		if lab_combat.deployment_active:
			lab_combat.finish_deployment()
			await get_tree().process_frame
		var lab_result = lab_game.get_node("ResultUI")
		rout(lab_combat, 1)
		# Its closing words are an empty stub, so the panel arrives behind them.
		for i in 30:
			await get_tree().process_frame
		var how = "from the map" if entered_from_a_map else "from the battle list"
		ok(lab_result.get_node("Panel").visible, "winning it shows the panel %s" % how)
		ok(lab_result.get_node("Panel/VBox/Title").text == "Victory", "  reading Victory",
			lab_result.get_node("Panel/VBox/Title").text)
		ok(lab_result.get_node("Panel/VBox/MainMenuButton").visible, "  offering the title screen")
		ok(not lab_result.get_node("Panel/VBox/BackButton").visible,
			"  and nothing else", lab_result.get_node("Panel/VBox/BackButton").text)
		ok(not SceneTransition._changing, "  without going there on its own")
		lab_game.queue_free()
		await get_tree().process_frame
	log_line("")

	log_line("======== but losing it still lets you try again ========")
	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_02_sappers.tres")
	var lost = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(lost)
	for i in 6:
		await get_tree().process_frame
	var lost_combat = lost.get_node("VisualCombat")
	if lost_combat.deployment_active:
		lost_combat.finish_deployment()
		await get_tree().process_frame
	var lost_result = lost.get_node("ResultUI")
	rout(lost_combat, 0)
	for i in 10:
		await get_tree().process_frame
	ok(lost_result.get_node("Panel/VBox/Title").text == "Defeat", "losing reads Defeat",
		lost_result.get_node("Panel/VBox/Title").text)
	ok(lost_result.get_node("Panel/VBox/BackButton").visible,
		"and the way back to another go is still there")
	lost.queue_free()
	await get_tree().process_frame
	log_line("")

	log_line("======== closing words hold the panel back ========")
	Campaign.reset()
	var talkative: EncounterDefinition = load("res://encounters/encounter_02_sappers.tres").duplicate(true)
	talkative.victory_dialogue = load("res://Dialogue/church_after_reveal_clown.dialogue")
	talkative.victory_dialogue_title = "start"
	Campaign.current_encounter = talkative
	var third = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(third)
	for i in 6:
		await get_tree().process_frame
	var talk_combat = third.get_node("VisualCombat")
	if talk_combat.deployment_active:
		talk_combat.finish_deployment()
		await get_tree().process_frame
	var talk_result = third.get_node("ResultUI")
	rout(talk_combat, 1)
	await get_tree().process_frame
	ok(not talk_result.get_node("Panel").visible,
		"the panel waits while the encounter has its say")
	# However the conversation ends, the panel arrives.
	DialogueManager.dialogue_ended.emit(talkative.victory_dialogue)
	await get_tree().process_frame
	ok(talk_result.get_node("Panel").visible, "and comes up once the talking stops")
	third.queue_free()
	await get_tree().process_frame
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
