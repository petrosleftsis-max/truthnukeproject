extends Node
## Space ends the turn - and only when pressing the button would have.

var LOG_PATH := HarnessLog.path_for("spacebar")
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
	get_tree().create_timer(180.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


func space() -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	event.keycode = KEY_SPACE
	event.pressed = true
	return event


## Hands the UI a space press the way the window would, and reports whether the
## turn ended.
func press_space(ui) -> bool:
	var ended = [false]
	var listener = func(): ended[0] = true
	ui.turn_ended.connect(listener)
	ui._unhandled_input(space())
	ui.turn_ended.disconnect(listener)
	return ended[0]


func run_test():
	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_02_sappers.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	for i in 6:
		await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	var controller = combat.controller
	var ui = combat.game_ui

	log_line("======== not while the party is still being placed ========")
	if combat.deployment_active:
		ok(not press_space(ui), "space does not begin the battle for you")
		combat.finish_deployment()
		await get_tree().process_frame
	log_line("")

	log_line("======== on a player's turn, it ends it ========")
	# Make sure it really is a player's turn and nothing is in flight.
	var hero = null
	for comb in combat.combatants:
		if comb.alive and comb.side == 0:
			hero = comb
			break
	for i in combat.combatants.size():
		if is_same(combat.combatants[i], hero):
			combat.current_combatant = i
	controller.set_controlled_combatant(hero)
	controller.player_turn = true
	controller.action_locked = false
	await get_tree().process_frame
	ok(not ui.get_node("Actions/EndTurnButton").disabled, "End Turn is pressable")
	ok(press_space(ui), "space ends the turn")
	log_line("")

	log_line("======== and refuses everything the button refuses ========")
	controller.action_locked = true
	ok(not press_space(ui), "not while an animation is resolving")
	controller.action_locked = false

	controller.player_turn = false
	ok(not press_space(ui), "not on somebody else's turn")
	controller.player_turn = true

	controller.set_selected_skill("greatsword_attack")
	controller.begin_target_selection()
	ok(not press_space(ui), "not while a skill is being aimed")
	controller.cancel_skill_selection()
	await get_tree().process_frame
	ok(press_space(ui), "and once aiming is cancelled, it works again")
	log_line("")

	log_line("======== nor with a menu over the map ========")
	var pause = game.get_node_or_null("PauseUI")
	if pause != null:
		pause._show_panel(pause.get_node("PausePanel"), pause._pause_buttons)
		await get_tree().process_frame
		ok(controller.a_menu_is_over_the_map(), "the pause menu counts as a menu")
		ok(not press_space(ui), "space does not end the turn behind it")
		pause._close()
		await get_tree().process_frame
		ok(not controller.a_menu_is_over_the_map(), "and closing it gives the map back")
		ok(press_space(ui), "space works again")
	log_line("")

	log_line("======== only the space bar ========")
	var enter := InputEventKey.new()
	enter.physical_keycode = KEY_ENTER
	enter.keycode = KEY_ENTER
	enter.pressed = true
	var ended = [false]
	var listener = func(): ended[0] = true
	ui.turn_ended.connect(listener)
	ui._unhandled_input(enter)
	ui.turn_ended.disconnect(listener)
	ok(not ended[0], "Enter does not end the turn - it belongs to dialogue and buttons")
	var released := space()
	released.pressed = false
	ui.turn_ended.connect(listener)
	ui._unhandled_input(released)
	ui.turn_ended.disconnect(listener)
	ok(not ended[0], "and letting go of space does nothing on its own")
	log_line("")

	log_line("======== the button says so ========")
	ok(ui.get_node("Actions/EndTurnButton").tooltip_text.contains("Space"),
		"the tooltip mentions the key", ui.get_node("Actions/EndTurnButton").tooltip_text)
	log_line("")

	game.queue_free()
	await get_tree().process_frame
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
