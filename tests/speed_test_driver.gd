extends Node
## How fast enemy turns play: a setting kept between runs, the whole battle sped
## up while an enemy acts and back to normal the moment the player's turn comes,
## a hit-stop coming back to the turn's speed rather than to normal, and nothing
## left running fast once the battle is gone.

var LOG_PATH := HarnessLog.path_for("speed")

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
	# Real seconds: the battle below runs at other speeds on purpose.
	get_tree().create_timer(200.0, true, false, true).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


func real_wait(seconds: float):
	await get_tree().create_timer(seconds, true, false, true).timeout


func start_fight() -> Array:
	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_02_sappers.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	for i in 4:
		await get_tree().process_frame
	var combat: Combat = game.get_node("VisualCombat")
	combat.finish_deployment()
	await get_tree().process_frame
	return [game, combat, game.get_node("Controller")]


## Waits, in real time, for a player's turn with nothing moving - and no
## hit-stop still holding the game from the enemy's last blow, which can
## outlast the turn it landed in.
func until_players_turn(combat: Combat, controller) -> bool:
	for i in 600:
		var comb = combat.get_current_combatant()
		if comb.side == 0 and controller.player_turn and controller.is_idle() and combat._hit_stop_depth == 0:
			return true
		if combat.combat_over:
			return false
		await real_wait(0.05)
	return false


## Ends player turns until an enemy's begins. Returns that enemy, or {}.
func until_enemys_turn(combat: Combat, controller) -> Dictionary:
	for i in 12:
		if not await until_players_turn(combat, controller):
			return {}
		combat.advance_turn()
		var comb = combat.get_current_combatant()
		if comb.side == 1:
			return comb
		ok(Engine.time_scale == 1.0, "another of the party's turns runs at normal speed", "%s" % Engine.time_scale)
	return {}


func run_test():
	log_line("======== the setting ========")
	var normal := GameSettings.NORMAL_SPEED
	var very_fast := GameSettings.ENEMY_SPEEDS.find(3.0)
	var fast := GameSettings.ENEMY_SPEEDS.find(2.0)
	var very_slow := GameSettings.ENEMY_SPEEDS.find(0.5)
	ok(very_slow >= 0 and GameSettings.ENEMY_SPEEDS.find(0.75) >= 0, "slower speeds are on offer as well as faster ones", "%s" % [GameSettings.ENEMY_SPEEDS])
	ok(GameSettings.ENEMY_SPEEDS.size() == GameSettings.ENEMY_SPEED_NAMES.size(), "each with a name")
	ok(GameSettings.enemy_speed_index() == normal, "normal speed until somebody asks otherwise")
	ok(GameSettings.enemy_time_scale() == 1.0, "which is no change at all")
	var config := ConfigFile.new()
	config.set_value("audio", "music", 0.4)
	config.save(GameSettings.PATH)
	var picker := BattleSpeedPicker.new()
	ok(picker.buttons.size() == GameSettings.ENEMY_SPEEDS.size(), "a button for each speed", "%d" % picker.buttons.size())
	ok(picker.buttons[normal].button_pressed and not picker.buttons[very_fast].button_pressed, "with the one in use pressed")
	ok(picker.heading() == "Enemy turns: Normal", "and named above them", picker.heading())
	ok(picker.buttons[very_slow].text == "0.5×" and picker.buttons[fast].text == "2×", "each button says its multiplier",
		"%s" % [picker.buttons.map(func(b): return b.text)])
	picker.buttons[very_fast].pressed.emit()
	ok(GameSettings.enemy_speed_index() == very_fast and GameSettings.enemy_time_scale() == 3.0, "picking Very fast takes",
		"%s" % GameSettings.enemy_time_scale())
	ok(picker.heading() == "Enemy turns: Very fast", "and the name above says so", picker.heading())
	config = ConfigFile.new()
	config.load(GameSettings.PATH)
	ok(config.get_value(GameSettings.SECTION, GameSettings.SPEED_KEY, -1) == 3.0, "and is written down as the speed itself",
		"%s" % config.get_value(GameSettings.SECTION, GameSettings.SPEED_KEY, -1))
	ok(config.get_value("audio", "music", -1.0) == 0.4, "beside the volume, which is left alone")
	GameSettings._enemy_speed = -1
	ok(GameSettings.enemy_speed_index() == very_fast, "so it is still there next time the game starts")
	var again := BattleSpeedPicker.new()
	ok(again.buttons[very_fast].button_pressed and not again.buttons[normal].button_pressed, "and the picker opens on it")
	# A speed saved before the list changed still means that speed.
	config.set_value(GameSettings.SECTION, GameSettings.SPEED_KEY, 2.0)
	config.save(GameSettings.PATH)
	GameSettings._enemy_speed = -1
	ok(GameSettings.enemy_time_scale() == 2.0, "a saved speed reads back as that speed, wherever it sits in the list")
	picker.free()
	again.free()
	log_line("")

	log_line("======== where it is set ========")
	var menu = load("res://main_menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	await get_tree().process_frame
	ok(not menu._panels["options"].find_children("*", "BattleSpeedPicker", true, false).is_empty(),
		"the title screen's Options has it")
	menu.queue_free()
	await get_tree().process_frame
	log_line("")

	log_line("======== an enemy's turn, fast ========")
	GameSettings.set_enemy_speed_index(GameSettings.ENEMY_SPEEDS.find(2.0))
	var parts = await start_fight()
	var game = parts[0]
	var combat: Combat = parts[1]
	var controller = parts[2]
	var pause = game.get_node("PauseUI")
	ok(pause._speed != null and pause._speed.get_parent() == pause.get_node("OptionsPanel/VBox"), "the pause menu's Options has it too")
	var looped = pause._speed != null
	if looped:
		for button in pause._speed.buttons:
			looped = looped and pause._options_buttons.has(button)
	ok(looped, "and its buttons are in the keyboard's loop there")
	var enemy = await until_enemys_turn(combat, controller)
	ok(not enemy.is_empty(), "an enemy's turn came round", enemy.get("name", "nobody"))
	ok(Engine.time_scale == 2.0, "and plays at the speed asked for", "%s" % Engine.time_scale)
	combat.hit_stop(0.03)
	ok(Engine.time_scale == 0.0, "a hit-stop still stops it")
	await real_wait(0.1)
	ok(Engine.time_scale == 2.0 or combat.get_current_combatant().side == 0,
		"and gives it back at the turn's speed, not at normal", "%s" % Engine.time_scale)
	ok(await until_players_turn(combat, controller), "the party's turn comes round again")
	ok(Engine.time_scale == 1.0, "at normal speed", "%s" % Engine.time_scale)
	log_line("")

	log_line("======== leaving in the middle of it ========")
	enemy = await until_enemys_turn(combat, controller)
	ok(not enemy.is_empty(), "another enemy's turn", enemy.get("name", "nobody"))
	ok(Engine.time_scale == 2.0, "running fast", "%s" % Engine.time_scale)
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	ok(Engine.time_scale == 1.0, "walking out of the battle puts the game back to normal speed", "%s" % Engine.time_scale)
	log_line("")

	log_line("======== an enemy's turn, slow ========")
	GameSettings.set_enemy_speed_index(GameSettings.ENEMY_SPEEDS.find(0.5))
	parts = await start_fight()
	game = parts[0]
	combat = parts[1]
	controller = parts[2]
	enemy = await until_enemys_turn(combat, controller)
	ok(not enemy.is_empty(), "an enemy's turn", enemy.get("name", "nobody"))
	ok(Engine.time_scale == 0.5, "plays at half speed, for watching what they do", "%s" % Engine.time_scale)
	combat.hit_stop(0.03)
	await real_wait(0.1)
	ok(Engine.time_scale == 0.5, "and a hit-stop gives back the slow speed, not normal", "%s" % Engine.time_scale)
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	ok(Engine.time_scale == 1.0, "and walking out puts it back to normal", "%s" % Engine.time_scale)
	log_line("")

	log_line("======== normal means normal ========")
	GameSettings.set_enemy_speed_index(GameSettings.NORMAL_SPEED)
	parts = await start_fight()
	game = parts[0]
	combat = parts[1]
	controller = parts[2]
	enemy = await until_enemys_turn(combat, controller)
	ok(not enemy.is_empty(), "an enemy's turn", enemy.get("name", "nobody"))
	ok(Engine.time_scale == 1.0, "at the speed of everything else", "%s" % Engine.time_scale)
	game.queue_free()
	await get_tree().process_frame
	log_line("")

	Engine.time_scale = 1.0
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
