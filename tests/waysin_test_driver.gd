extends Node
## The four cards on the Play panel, each pressed, each checked for where it goes.

var LOG_PATH := HarnessLog.path_for("waysin")
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
	await get_tree().process_frame
	await run_test()

func run_test():
	var menu = load("res://main_menu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame

	log_line("======== every card names something that exists ========")
	for way in MainMenu.WAYS_IN:
		ok(ResourceLoader.exists(way.icon), "%s has its portrait" % way.name, way.icon)
		for field in ["dialogue", "map", "encounter"]:
			if way.has(field):
				ok(ResourceLoader.exists(way[field]), "%s's %s is there" % [way.name, field], way[field])
		ok(way.has("dialogue") or way.has("map") or way.has("encounter"),
			"%s opens something" % way.name)
	log_line("")

	log_line("======== where each card actually sends you ========")
	for way in MainMenu.WAYS_IN:
		Campaign.current_map = "sentinel"
		Campaign.current_encounter = null
		Campaign.clear_story()
		menu._start(way)
		var went := ""
		if way.has("dialogue"):
			went = "story: %s then %s" % [Campaign.story_dialogue, Campaign.story_next_scene]
			ok(Campaign.story_dialogue == way.dialogue, "%s queues its dialogue" % way.name, went)
		elif way.has("map"):
			went = "map: %s" % Campaign.current_map
			ok(Campaign.current_map == way.map, "%s sets the map" % way.name, went)
			ok(Campaign.target_entry == "", "%s arrives at the map's own entry" % way.name)
		elif way.has("encounter"):
			went = "fight: %s" % (Campaign.current_encounter.display_name if Campaign.current_encounter else "none")
			ok(Campaign.current_encounter != null, "%s loads its encounter" % way.name, went)
	log_line("")

	log_line("======== the church opens on Alithia's conversation ========")
	var church = load("res://church.tscn").instantiate()
	add_child(church)
	await get_tree().process_frame
	var entry: Node = null
	var arrival: Node = null
	for child in church.get_children():
		if child is EntryPoint:
			entry = child
		if child is DialogueInteractable and child.get("automatic"):
			arrival = child
	ok(entry != null, "the church has an entry point", entry.entry_name if entry else "")
	ok(arrival != null, "and something that fires on arrival")
	if arrival != null and entry != null:
		ok(arrival.dialogue != null, "which has a dialogue",
			arrival.dialogue.resource_path if arrival.dialogue else "none")
		ok(arrival.dialogue.resource_path.contains("alithia_intro"),
			"and it is Alithia's", arrival.dialogue.resource_path)
		var reach = entry.position.distance_to(arrival.position)
		ok(reach <= arrival.interaction_radius,
			"the party arrives inside its reach", "%.0f away, reach %.0f" % [reach, arrival.interaction_radius])
	# Nothing else in the church should go off by being stood next to.
	for child in church.get_children():
		if child is DialogueInteractable and child != arrival:
			ok(not child.get("automatic"), "%s still waits to be talked to" % child.name)
	log_line("")

	log_line("======== every screen has a way back to the menu ========")
	# The pause overlay: Exit used to quit, which in a web build does nothing.
	var pause = load("res://ui/pause_ui.tscn").instantiate()
	add_child(pause)
	await get_tree().process_frame
	var pause_texts := []
	for button in pause.get_node("PausePanel/VBox").find_children("*", "Button", true, false):
		pause_texts.append(button.text)
	ok(not ("Exit" in pause_texts), "the pause menu no longer offers Exit", "%s" % [pause_texts])
	ok("Main Menu" in pause_texts, "and offers Main Menu instead", "%s" % [pause_texts])
	ok("Arena Mode" in pause_texts, "with Battle Select renamed", "%s" % [pause_texts])
	ok(pause.has_method("_on_main_menu_pressed"), "and it is wired to something")
	# Volume under Options, the same sliders the main menu shows.
	var pause_sliders = pause.get_node("OptionsPanel/VBox").find_children("*", "HSlider", true, false)
	ok(pause_sliders.size() == 2, "the pause options carry both volume sliders",
		"%d" % pause_sliders.size())
	if pause_sliders.size() == 2:
		# Moving one really moves the level, rather than only the handle.
		var was = Music.volume("music")
		pause_sliders[0].value = 0.35
		await get_tree().process_frame
		ok(absf(Music.volume("music") - 0.35) < 0.001,
			"and moving one changes the volume", "%s -> %s" % [was, Music.volume("music")])
		Music.set_volume("music", was)
	pause.queue_free()

	# Arena Mode itself.
	var arena = load("res://scenes/level_select.tscn").instantiate()
	add_child(arena)
	await get_tree().process_frame
	ok(arena.get_node("Center/VBox/Title").text == "Arena Mode",
		"the battle list is called Arena Mode", arena.get_node("Center/VBox/Title").text)
	var back = arena.get_node_or_null("Center/VBox/MainMenuButton")
	ok(back != null, "and has a way back to the menu")
	ok(back != null and back.pressed.get_connections().size() > 0,
		"which is connected to something")
	arena.queue_free()

	# And the main menu still calls it that.
	var menu_labels := []
	for button in menu.find_children("*", "Button", true, false):
		menu_labels.append(button.text)
	ok("Arena Mode" in menu_labels, "the main menu calls it Arena Mode too", "%s" % [menu_labels])
	ok("Exit" in menu_labels, "and the title screen still offers Exit", "%s" % [menu_labels])
	log_line("")

	log_line("======== the way back to the menu that dialogue can call ========")
	ok(Campaign.has_method("to_main_menu"), "Campaign.to_main_menu() exists")
	ok(ResourceLoader.exists(Campaign.MAIN_MENU), "and the menu scene is there", Campaign.MAIN_MENU)
	var shortcuts = ProjectSettings.get_setting("dialogue_manager/runtime/state_autoload_shortcuts", PackedStringArray())
	ok("Campaign" in shortcuts, "and dialogue can reach Campaign", "%s" % [shortcuts])
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
