extends Node
## Leaving the game from inside a conversation.
##
## A dialogue can steer the autoloads listed in the project's state shortcuts,
## so `do Campaign.to_main_menu()` is a line a writer can put anywhere. This
## checks that it really lands: the run cleared, the music stopped, the title
## screen up, and no balloon left talking over it.

var LOG_PATH := HarnessLog.path_for("bailout")
const WRITTEN = "res://Dialogue/_bailout_probe.dialogue"
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
	get_tree().create_timer(120.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


func run_test():
	log_line("======== a dialogue may call Campaign at all ========")
	var shortcuts = ProjectSettings.get_setting("dialogue_manager/runtime/state_autoload_shortcuts", PackedStringArray())
	ok("Campaign" in shortcuts, "Campaign is a state shortcut", "%s" % [shortcuts])
	ok(Campaign.has_method("to_main_menu"), "and carries to_main_menu()")
	log_line("")

	log_line("======== the line a writer would type ========")
	# A real .dialogue file, sitting in the project and imported like any other -
	# one written at runtime is never imported, so it cannot be loaded at all.
	var resource = load(WRITTEN)
	ok(resource != null, "it compiles")
	log_line("")

	log_line("======== and it takes the game home ========")
	# A run in progress, with something playing over it.
	Campaign.reset()
	Campaign.current_map = "res://church.tscn"
	Campaign.current_encounter = load("res://encounters/encounter_02_sappers.tres")
	Campaign.set_flag("bailout_probe_flag")
	Music.play("Elegy_of_the_End")
	ok(Campaign.flag("bailout_probe_flag"), "a run is under way")
	ok(Campaign.current_map != "", "on a map", Campaign.current_map)

	# Walk the conversation the way the balloon does, running its mutations.
	var line = await DialogueManager.get_next_dialogue_line(resource, "start")
	ok(line != null, "the conversation starts", line.text if line != null else "nothing")
	if line != null:
		# The next line is the `do`, and asking for it is what runs it.
		await DialogueManager.get_next_dialogue_line(resource, line.next_id)
	for i in 4:
		await get_tree().process_frame

	ok(Campaign.current_map == "", "the map is let go of", "'%s'" % Campaign.current_map)
	ok(Campaign.current_encounter == null, "and the encounter with it")
	ok(not Campaign.flag("bailout_probe_flag"), "the story flags are wiped")
	ok(Music.current() == "", "the music stops", "'%s'" % Music.current())
	log_line("")

	log_line("======== nothing is left talking over the title screen ========")
	var balloons := []
	for node in get_tree().root.get_children():
		if node.name.to_lower().contains("balloon"):
			balloons.append(node.name)
	ok(balloons.is_empty(), "no balloon outlives the scene change", "%s" % [balloons])
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
