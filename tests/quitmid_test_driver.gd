extends Node
## Leaving a battle while it is somebody else's turn.
##
## An enemy's turn is a coroutine several awaits deep - walk, then hit, then a
## pause to read it by - and the scene it is standing on is freed underneath it
## the moment the title screen is asked for. Whatever it was in the middle of
## has to not matter by then.

var LOG_PATH := HarnessLog.path_for("quitmid")
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
	# Real seconds and paused or not, so the watchdog cannot be stopped by the
	# very thing it is watching for.
	get_tree().create_timer(240.0, true, false, true).timeout.connect(func():
		log_line("DID NOT FINISH")
		Engine.time_scale = 1.0
		get_tree().paused = false
		get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


## Waiting that survives a frozen time scale and a held tree, which is the
## state this test is trying to catch the game in.
func real_seconds(seconds: float):
	await get_tree().create_timer(seconds, true, false, true).timeout


func frames(n: int = 4):
	for i in n:
		await get_tree().process_frame


func run_test():
	# Leaving at one moment proves very little: an enemy's turn is a walk, then
	# a swing, then a beat held after it, and each of those is a different place
	# for the coroutine to be standing when the ground goes. So leave at several.
	for wait_before_leaving in [0.0, 0.15, 0.4, 0.8, 1.3]:
		await leave_during_an_enemy_turn(wait_before_leaving)
	Engine.time_scale = 1.0
	get_tree().paused = false
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func leave_during_an_enemy_turn(wait_before_leaving: float):
	log_line("======== leaving %.2fs into an enemy's turn ========" % wait_before_leaving)
	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_02_sappers.tres")
	get_tree().change_scene_to_file("res://scenes/game.tscn")
	await frames(8)
	var game = get_tree().current_scene
	if game == null or not game.has_node("VisualCombat"):
		ok(false, "a battle is on screen")
		return
	var combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await frames(2)

	var handed_over := false
	for attempt in 30:
		if combat.combatants[combat.current_combatant].side == 1:
			handed_over = true
			break
		combat.advance_turn()
		await frames(3)
	ok(handed_over, "  an enemy has the turn",
		combat.combatants[combat.current_combatant].name)
	await real_seconds(wait_before_leaving)

	var pause = game.get_node("PauseUI")
	pause._show_panel(pause.get_node("PausePanel"), pause._pause_buttons)
	await frames(2)
	pause._on_main_menu_pressed()
	await real_seconds(2.5)

	ok(Engine.time_scale == 1.0, "  time is running afterwards",
		"time_scale = %s" % Engine.time_scale)
	ok(not get_tree().paused, "  the tree is not left held")
	ok(not SceneTransition._changing, "  the transition finished")
	var scene = get_tree().current_scene
	ok(scene != null and scene is MainMenu, "  the title screen is up and whole",
		"" if scene == null else scene.name)
	if scene is MainMenu:
		scene._show("options")
		await frames(2)
		ok(scene._panels["options"].visible, "  and answers a press")
		scene._show("root")
		await frames(2)
	log_line("")
