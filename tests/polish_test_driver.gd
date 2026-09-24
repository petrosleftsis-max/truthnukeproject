extends Node
## The dialogue balloon takes the shared theme, and every scene change fades.

var LOG_PATH := HarnessLog.path_for("polish")

## Every script that could change a scene. If one of these calls the engine
## directly it skips the fade, which is invisible until somebody notices one
## transition snapping while the rest do not.
const SCENE_CHANGERS = [
	"res://ui/level_select.gd",
	"res://ui/pause_ui.gd",
	"res://ui/result_ui.gd",
	"res://exploration/EncounterInteractable.gd",
	"res://exploration/ExplorationScene.gd",
	"res://scenes/game.gd",
]

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
	get_tree().create_timer(120.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


func run_test():
	log_line("======== the balloon wears the shared theme ========")
	var balloon = load("res://ui/dialogue_balloon.tscn").instantiate()
	get_tree().root.add_child(balloon)
	await get_tree().process_frame

	# A local theme that paints panels and buttons would override the project's
	# and put the dialogue back out of step with everything else.
	var local = balloon.balloon.theme
	if local != null:
		ok(not local.has_stylebox("panel", "PanelContainer"),
			"its own theme no longer paints panels")
		ok(not local.has_stylebox("normal", "Button"),
			"nor buttons")
		ok(local.default_font_size > 0, "but it keeps the dialogue font size",
			"%d" % local.default_font_size)
	else:
		ok(true, "it has no theme of its own at all")

	var project_theme = load(ProjectSettings.get_setting("gui/theme/custom"))
	ok(project_theme != null, "the project theme is set", ProjectSettings.get_setting("gui/theme/custom"))
	ok(project_theme.has_stylebox("panel", "PanelContainer"),
		"and it is the one that paints panels now")
	# The colour the rest of the game uses for the thing you are looking at.
	var accent = Color("4a86c8")
	ok(balloon.character_label.get_theme_color("default_color").is_equal_approx(accent),
		"the speaker's name is in the accent colour",
		"%s" % balloon.character_label.get_theme_color("default_color"))
	balloon.queue_free()
	await get_tree().process_frame
	log_line("")

	log_line("======== the transition exists and starts clear ========")
	ok(SceneTransition != null, "SceneTransition is an autoload")
	ok(SceneTransition is CanvasLayer, "and a CanvasLayer")
	ok(SceneTransition.layer > 15, "above the pause menu and the reaction prompt",
		"layer %d" % SceneTransition.layer)
	ok(SceneTransition._screen != null, "with a screen to fade")
	ok(SceneTransition._screen.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"which never swallows a click")
	# The opening fade will have finished long before now.
	for frame in range(0, 60):
		await get_tree().process_frame
	ok(SceneTransition._screen.modulate.a < 0.01, "and it has faded up from black by now",
		"alpha %s" % SceneTransition._screen.modulate.a)
	log_line("")

	log_line("======== fading covers the screen and clears again ========")
	await SceneTransition.fade_out()
	ok(SceneTransition._screen.modulate.a > 0.99, "fading out reaches full black",
		"alpha %s" % SceneTransition._screen.modulate.a)
	await SceneTransition.fade_in()
	ok(SceneTransition._screen.modulate.a < 0.01, "and fading in clears it",
		"alpha %s" % SceneTransition._screen.modulate.a)
	log_line("")

	log_line("======== a change fades, swaps, and fades back ========")
	Campaign.reset()
	SceneTransition.change_scene("res://scenes/level_select.tscn")
	ok(SceneTransition._changing, "a change is in flight")
	# Asking again mid-fade must not start a second one, which would leave the
	# screen black over a scene nobody asked for.
	SceneTransition.change_scene("res://scenes/exploration.tscn")
	await get_tree().process_frame
	ok(SceneTransition._changing, "and a second request is ignored while it runs")
	var covered = false
	for frame in range(0, 120):
		await get_tree().process_frame
		if SceneTransition._screen.modulate.a > 0.99:
			covered = true
		if not SceneTransition._changing:
			break
	ok(covered, "the screen was fully covered at some point")
	ok(not SceneTransition._changing, "the change finished")
	ok(SceneTransition._screen.modulate.a < 0.01, "and left the screen clear",
		"alpha %s" % SceneTransition._screen.modulate.a)
	var arrived = get_tree().current_scene
	ok(arrived != null and arrived.scene_file_path.contains("level_select"),
		"on the scene that was actually asked for",
		arrived.scene_file_path if arrived else "none")
	log_line("")

	log_line("======== nothing skips the fade ========")
	for path in SCENE_CHANGERS:
		if not ResourceLoader.exists(path):
			continue
		var file = FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var source = file.get_as_text()
		ok(not source.contains("change_scene_to_file"),
			"%s goes through SceneTransition" % path.get_file(),
			"" if not source.contains("change_scene_to_file") else "calls the engine directly")
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
