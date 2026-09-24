extends Node
## The front door: every panel, every button, and what each of them leads to.

var LOG_PATH := HarnessLog.path_for("menu")

var _log: FileAccess = null
var _fail = 0
var menu: Control = null


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


func open_menu() -> Control:
	if menu != null and is_instance_valid(menu):
		menu.queue_free()
		await get_tree().process_frame
	menu = load("res://main_menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	await get_tree().process_frame
	return menu


## The button reading `text` on whichever panel is open.
func button(text: String) -> Button:
	for key in menu._panels:
		var panel = menu._panels[key]
		if not panel.visible:
			continue
		for node in panel.find_children("*", "Button", true, false):
			if node.text == text:
				return node
	return null


func visible_panel() -> String:
	for key in menu._panels:
		if menu._panels[key].visible:
			return key
	return ""


func run_test():
	await open_menu()
	ok(menu != null, "the menu scene opens")
	ok(menu.theme != null, "wearing the same theme as the rest of the game",
		menu.theme.resource_path if menu.theme else "none")
	# Not asserted: the harness points every suite at the battle scene so it can
	# drive one, so what the project starts on cannot be read from inside it.
	log_line("  NOTE  main scene while under test: %s" % ProjectSettings.get_setting("application/run/main_scene"))

	log_line("======== the front door ========")
	ok(visible_panel() == "root", "opens on the menu itself", visible_panel())
	for wanted in ["Play", "Arena Mode", "Options", "Exit"]:
		ok(button(wanted) != null, "there is a %s button" % wanted)
	# Nothing is lit up until the keyboard is used - see FocusOnDemand - so the
	# menu is asked for it rather than found holding it.
	var claimed := InputEventKey.new()
	claimed.physical_keycode = KEY_DOWN
	claimed.keycode = KEY_DOWN
	claimed.pressed = true
	Input.parse_input_event(claimed)
	await get_tree().process_frame
	await get_tree().process_frame
	var focused = menu.get_viewport().gui_get_focus_owner()
	ok(focused != null and focused is Button, "an arrow key gives it keyboard focus, so it can be played without a mouse",
		focused.text if focused is Button else "nothing")
	log_line("")

	log_line("======== Play, and the four ways in ========")
	button("Play").pressed.emit()
	await get_tree().process_frame
	ok(visible_panel() == "play", "Play leads to the four", visible_panel())
	var cards = menu._panels["play"].find_children("*", "Button", true, false)
	var ways = []
	for card in cards:
		if card.text != "Back":
			ways.append(card)
	ok(ways.size() == 4, "four of them", "%d" % ways.size())
	# Left to right, in the order asked for.
	var order = []
	for way in MainMenu.WAYS_IN:
		order.append(way.name)
	ok(order == ["Cyrus", "Prometheus", "Enfina", "Alithia"], "in the right order", "%s" % [order])
	for way in MainMenu.WAYS_IN:
		ok(ResourceLoader.exists(way.icon), "%s has their portrait" % way.name, way.icon)
		ok(way.description != "", "and a description")
		if way.has("dialogue"):
			ok(ResourceLoader.exists(way.dialogue), "%s's dialogue is there" % way.name, way.dialogue)
		if way.has("encounter"):
			ok(ResourceLoader.exists(way.encounter), "%s's encounter is there" % way.name, way.encounter)
		if way.has("then"):
			ok(ResourceLoader.exists(way.then), "and somewhere to go afterwards", way.then)
	# Every description has to fit on its card rather than running off it.
	var overflowing = []
	for card in ways:
		for label in card.find_children("*", "Label", true, false):
			if label.text.length() > 30 and label.autowrap_mode == TextServer.AUTOWRAP_OFF:
				overflowing.append(label.text)
	ok(overflowing.is_empty(), "and each of them wraps rather than running off the card",
		"%s" % [overflowing])
	log_line("")

	log_line("======== what each of the four actually starts ========")
	Campaign.reset()
	menu._start(MainMenu.WAYS_IN[0])
	ok(Campaign.story_dialogue.contains("cyrus_intro"), "Cyrus plays his introduction first",
		Campaign.story_dialogue)
	ok(Campaign.story_next_scene == MainMenu.EXPLORATION, "and then the crossroads",
		Campaign.story_next_scene)
	Campaign.clear_story()
	Campaign.current_map = ""
	menu._start(MainMenu.WAYS_IN[1])
	ok(Campaign.current_map.contains("laboratory_terrain_explore"),
		"Prometheus walks the laboratory", Campaign.current_map)
	menu._start(MainMenu.WAYS_IN[2])
	ok(Campaign.current_encounter != null and Campaign.current_encounter.resource_path.contains("watcher"),
		"Enfina to the watcher",
		Campaign.current_encounter.resource_path if Campaign.current_encounter else "none")
	Campaign.clear_story()
	Campaign.current_map = ""
	menu._start(MainMenu.WAYS_IN[3])
	# Her scene happens in the church rather than over black: it opens behind a
	# door and ends with her leaving the room, so she has to be standing in one.
	ok(Campaign.current_map.contains("church"), "Alithia starts at the church", Campaign.current_map)
	var church = load(Campaign.current_map).instantiate()
	var opener = null
	for child in church.get_children():
		if child is DialogueInteractable and child.get("automatic"):
			opener = child
	ok(opener != null and opener.dialogue != null
		and opener.dialogue.resource_path.contains("church_after_reveal_alithia_intro"),
		"and her scene plays on arrival",
		opener.dialogue.resource_path if opener != null and opener.dialogue != null else "nothing there")
	church.free()
	log_line("")

	log_line("======== a story plays over black and then moves on ========")
	Campaign.begin_story("res://Dialogue/cyrus_intro.dialogue", "start", MainMenu.EXPLORATION)
	var story = load("res://scenes/story.tscn").instantiate()
	get_tree().root.add_child(story)
	await get_tree().process_frame
	var black = null
	for layer in story.find_children("*", "CanvasLayer", true, false):
		for child in layer.get_children():
			if child is ColorRect:
				black = child
	ok(black != null, "there is a black screen behind the words")
	if black != null:
		ok(black.color == Color.BLACK, "genuinely black", "%s" % black.color)
		ok(black.anchor_right == 1.0 and black.anchor_bottom == 1.0, "covering all of it")
	story.queue_free()
	await get_tree().process_frame
	Campaign.clear_story()
	log_line("")

	log_line("======== Options ========")
	await open_menu()
	button("Options").pressed.emit()
	await get_tree().process_frame
	ok(visible_panel() == "options", "Options opens its own panel", visible_panel())
	ok(button("Resolution") != null and button("Volume") != null, "offering Resolution and Volume")

	button("Resolution").pressed.emit()
	await get_tree().process_frame
	ok(visible_panel() == "resolution", "Resolution leads to the sizes", visible_panel())
	for size in MainMenu.RESOLUTIONS:
		ok(button("%d x %d" % [size.x, size.y]) != null, "%dx%d is offered" % [size.x, size.y])
	button("Back").pressed.emit()
	await get_tree().process_frame
	ok(visible_panel() == "options", "Back returns to Options rather than the front", visible_panel())

	button("Volume").pressed.emit()
	await get_tree().process_frame
	ok(visible_panel() == "volume", "Volume has a panel of its own", visible_panel())
	var sliders = menu._panels["volume"].find_children("*", "HSlider", true, false)
	ok(sliders.size() == 2, "with a slider each for music and effects", "%d" % sliders.size())
	if sliders.size() == 2:
		var was_music = Music.volume("music")
		var was_sfx = Music.volume("sfx")
		sliders[0].value = 0.3
		await get_tree().process_frame
		ok(is_equal_approx(Music.volume("music"), 0.3), "moving one sets the music level",
			"%s" % Music.volume("music"))
		ok(is_equal_approx(Music.volume("sfx"), was_sfx), "and leaves the effects alone",
			"%s" % Music.volume("sfx"))
		sliders[1].value = 0.6
		await get_tree().process_frame
		ok(is_equal_approx(Music.volume("sfx"), 0.6), "the other sets the effects", "%s" % Music.volume("sfx"))
		# What the mixer is actually doing, not just what was remembered.
		var music_bus = AudioServer.get_bus_index("Music")
		ok(music_bus >= 0 and is_equal_approx(AudioServer.get_bus_volume_db(music_bus), linear_to_db(0.3)),
			"and the mixer is turned down with it",
			"%.2f dB" % AudioServer.get_bus_volume_db(music_bus))
		sliders[0].value = 0.0
		await get_tree().process_frame
		ok(AudioServer.is_bus_mute(music_bus), "all the way down is silence rather than an infinity")
		Music.set_volume("music", was_music)
		Music.set_volume("sfx", was_sfx)
	log_line("")

	log_line("======== the way back out ========")
	await open_menu()
	button("Play").pressed.emit()
	await get_tree().process_frame
	button("Back").pressed.emit()
	await get_tree().process_frame
	ok(visible_panel() == "root", "Back from Play returns to the front door", visible_panel())
	log_line("")

	log_line("======== the battle selector's cards hold their descriptions ========")
	var selector = load("res://scenes/level_select.tscn").instantiate()
	get_tree().root.add_child(selector)
	await get_tree().process_frame
	await get_tree().process_frame
	var loose = []
	for card in selector.find_children("*", "Button", true, false):
		for label in card.find_children("*", "Label", true, false):
			if label.autowrap_mode == TextServer.AUTOWRAP_OFF and label.text.length() > 30:
				loose.append(label.text)
			# The label has to sit inside the card it belongs to.
			if label.size.y > card.size.y:
				loose.append("%s is taller than its card" % label.text)
	ok(loose.is_empty(), "no description runs off its card", "%s" % [loose])
	selector.queue_free()
	log_line("")

	log_line("======== the arena hands you back where you came from ========")
	# It used to be a one-way door: the only way out was the main menu, which
	# threw the run away. Walking into it from the middle of a map and coming
	# back out should put you on the tile you left.
	Campaign.reset()
	ok(not Campaign.can_leave_arena(), "opened from the title screen there is nowhere to go back to")

	var sewer = "res://scenes/explore_crossroads.tscn"
	var stood_at = Vector2(1234, 567)
	Campaign.current_map = sewer
	Campaign.enter_arena_from("res://scenes/exploration.tscn", stood_at)
	ok(Campaign.can_leave_arena(), "opened from a map, there is")

	# An arena fight overwrites the live fields, which is why the way back is
	# held as a copy rather than read off them when the button is pressed.
	Campaign.current_map = ""
	Campaign.current_encounter = load("res://encounters/encounter_01_ambush.tres")
	Campaign.return_to_position = false
	Campaign.leave_arena()
	await get_tree().process_frame
	ok(Campaign.current_map == sewer, "the map is the one they left", Campaign.current_map)
	ok(Campaign.return_to_position, "and they are put back where they stood")
	ok(Campaign.return_position == stood_at, "on the tile itself",
		"%s" % Campaign.return_position)
	ok(not Campaign.can_leave_arena(), "and the way back is spent once used")

	# From a battle there is no tile, only the fight to go back to.
	Campaign.reset()
	var fight = load("res://encounters/encounter_01_ambush.tres")
	Campaign.current_encounter = fight
	Campaign.enter_arena_from("res://scenes/game.tscn")
	Campaign.current_encounter = null
	Campaign.leave_arena()
	await get_tree().process_frame
	ok(Campaign.current_encounter == fight, "the fight is the one they left")
	ok(not Campaign.return_to_position, "with no tile to stand on")

	# And starting over forgets it, so a fresh run cannot walk back into an old one.
	Campaign.enter_arena_from("res://scenes/exploration.tscn", Vector2.ZERO)
	Campaign.reset()
	ok(not Campaign.can_leave_arena(), "starting over forgets the way back")
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
