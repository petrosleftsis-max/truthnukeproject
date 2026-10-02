extends Node
## The stealth test stages are playable as built: the menu opens them, each is
## watched, its guards can walk their beats, the party starts somewhere nobody
## is looking, the goal can be reached, the map is its battle terrain, and what
## each stage is there to show is actually on it.

var LOG_PATH := HarnessLog.path_for("stages")
const MENU := "res://scenes/try_stealth_stages.tscn"
const TALK := "res://Dialogue/stealth_stages.dialogue"
const BALLOON := "res://ui/dialogue_balloon.tscn"
const STAGES := ["res://stages/stealth_1.tscn", "res://stages/stealth_2.tscn", "res://stages/stealth_3.tscn", "res://stages/stealth_4.tscn",
	"res://stages/stealth_5.tscn", "res://stages/stealth_6.tscn", "res://stages/stealth_7.tscn"]

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
	get_tree().create_timer(360.0, true, false, true).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


func run_test():
	log_line("======== the title screen lists every stage ========")
	var on_title: Array = MainMenu.STEALTH_STAGES.map(func(s): return s.map)
	ok(on_title == STAGES, "all seven, in order", "%s" % [on_title])
	for stage in MainMenu.STEALTH_STAGES:
		ok(ResourceLoader.exists(stage.map) and stage.name != "" and stage.description != "", "%s is there, and says what it is" % stage.name)
	var listed: Array = load(MENU.replace(".tscn", ".gd")).stages().map(func(s): return s.map)
	ok(listed == STAGES + ["res://scenes/stealth_demo.tscn"], "and the editor's own list has them, and the lab demo", "%s" % [listed])
	await from_the_title_screen()
	var talk = load(TALK)
	var script_text = FileAccess.get_file_as_string(TALK)
	for n in STAGES.size():
		await check_stage(n + 1, talk, script_text)
	await bag_kept_after_a_fight()
	await back_to_the_list()
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func visible_panel(menu: MainMenu) -> String:
	for key in menu._panels:
		if menu._panels[key].visible:
			return key
	return ""


func button_on(panel: Control, text: String) -> Button:
	for node in panel.find_children("*", "Button", true, false):
		if node.text == text:
			return node
	return null


## Stealth Stages on the front door, a button a stage, and Back.
func from_the_title_screen():
	log_line("======== Stealth Stages, from the title screen ========")
	var menu: MainMenu = load("res://main_menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	await settle()
	var door = button_on(menu._panels["root"], "Stealth Stages")
	ok(door != null, "the front door has a Stealth Stages button")
	door.pressed.emit()
	await settle()
	var panel = menu._panels[MainMenu.STEALTH_PANEL]
	ok(visible_panel(menu) == MainMenu.STEALTH_PANEL, "which opens the list", visible_panel(menu))
	ok(not menu._stealth_note.visible, "with nothing to say about a last stage yet")
	var labels = panel.find_children("*", "Label", true, false).map(func(l): return l.text)
	ok(labels.has(MainMenu.STEALTH_HELP), "how to play, above the stages")
	for i in MainMenu.STEALTH_STAGES.size():
		var stage = MainMenu.STEALTH_STAGES[i]
		ok(button_on(panel, "%d   %s" % [i + 1, stage.name]) != null and labels.has(stage.description),
			"a button for %s, and what it is about" % stage.name)
	# Set up without the scene change, which would carry on under the test.
	Campaign.set_flag("left_over")
	menu._set_up_stage(MainMenu.STEALTH_STAGES[1])
	ok(Campaign.current_map == STAGES[1] and not Campaign.flag("left_over"), "a stage starts afresh, on its own map")
	ok(MainMenu._last_stage == "The Watch", "and the menu remembers which, to name it when he is back")
	button_on(panel, "Back").pressed.emit()
	await settle()
	ok(visible_panel(menu) == "root", "Back returns to the front door", visible_panel(menu))
	menu.queue_free()
	await settle()
	log_line("")


## A stage empties the bag and hands out its kit on arrival - and not again on
## the way back from a fight, which would take whatever was picked up since.
func bag_kept_after_a_fight():
	log_line("======== back from a fight, the bag is as it was ========")
	Campaign.reset()
	Campaign.current_map = STAGES[0]
	var scene: ExplorationScene = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(scene)
	await settle(4)
	ok(Campaign.count_of("cyrus", "pebble") == 3, "arriving, he is handed the stage's three pebbles")
	var stood_at = scene.party_position()
	Campaign.take_item("cyrus", "pebble")
	Campaign.give_item("cyrus", "priest_robes")
	scene.queue_free()
	await settle()
	# As a fight sends him back: to where he was, rather than arriving afresh.
	Campaign.return_position = stood_at
	Campaign.return_to_position = true
	scene = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(scene)
	await settle(4)
	ok(Campaign.count_of("cyrus", "pebble") == 2 and Campaign.count_of("cyrus", "priest_robes") == 1,
		"back from a fight, he has what he left with - not the kit again, and not an emptied bag",
		"%d pebbles, %d robes" % [Campaign.count_of("cyrus", "pebble"), Campaign.count_of("cyrus", "priest_robes")])
	scene.queue_free()
	await settle()
	log_line("")


## Reaching a stage's way out goes back to the list, saying how it went. Last,
## because it changes the scene for real.
func back_to_the_list():
	log_line("======== the way out goes back to the list ========")
	var menu: MainMenu = load("res://main_menu.tscn").instantiate()
	menu._set_up_stage(MainMenu.STEALTH_STAGES[0])
	menu.free()
	var scene: ExplorationScene = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(scene)
	await settle(4)
	var goal: StealthGoal = scene.get_node("Map").find_children("*", "StealthGoal", true, false)[0]
	ok(goal.ends_at_menu, "the stage's way out is one that goes back to the title screen")
	# Straight through, rather than waiting on somebody to read the last words.
	goal.dialogue = null
	goal.interact(scene)
	await settle()
	var card = scene.get_node_or_null("StealthScorecard")
	ok(card != null and card.continue_button != null, "the card that says how it went comes up first")
	ok(scene.is_holding(), "and holds everything while it is up")
	if card != null:
		card.continue_button.pressed.emit()
	var back = await until(func(): return get_tree().current_scene is MainMenu, 4.0)
	ok(back, "reaching it goes to the title screen")
	if back:
		var title: MainMenu = get_tree().current_scene
		await settle()
		ok(visible_panel(title) == MainMenu.STEALTH_PANEL, "open at the stages", visible_panel(title))
		ok(title._stealth_note.visible and title._stealth_note.text == "The Tools: Ghost - nobody so much as noticed.",
			"saying which, and how it went", title._stealth_note.text)
		ok(Campaign.menu_opens_at == "" and Campaign.menu_note == "", "said once - the next visit to the title screen is an ordinary one")
		button_on(title._panels[MainMenu.STEALTH_PANEL], "Back").pressed.emit()
		await settle()
		ok(visible_panel(title) == "root", "and Back from there is the front door", visible_panel(title))
	scene.queue_free()
	await settle()
	log_line("")


## Waits up to `seconds` for `condition` to hold. True if it did.
func until(condition: Callable, seconds: float) -> bool:
	var waited := 0.0
	while waited < seconds:
		if condition.call():
			return true
		await get_tree().process_frame
		waited += get_process_delta_time()
	return condition.call()


## Every tile `guard` could see from where they stand, over the whole of their
## look about if they do.
func ever_seen(sight: StealthSight, tile: Vector2i, facing: float, looks_around: bool) -> Dictionary:
	var seen := {}
	var spread = int(Guard.LOOK_AROUND_DEGREES) if looks_around else 0
	for d in range(-spread, spread + 1, 2):
		seen.merge(sight.seen_from(tile, Vector2.RIGHT.rotated(deg_to_rad(facing + d)), Guard.HALF_CONE))
	return seen


## The escort can be done without a single "?": the warden's beat never looks
## into the cell, and from behind him there is a way to the exit the door guard
## never sees.
func escort_can_be_ghosted(watch: StealthWatch, sight: StealthSight, tile_map: TileMap, scene: ExplorationScene, goal):
	var warden: Guard = null
	var door: Guard = null
	for guard in watch.guards:
		if not guard.patrol.is_empty():
			warden = guard
		else:
			door = guard
	ok(warden != null and door != null and goal != null, "(a warden walking the corridor, and a guard at the door)")
	if warden == null or door == null or goal == null:
		return
	var tile_of = func(node: Node2D) -> Vector2i: return tile_map.local_to_map(tile_map.to_local(node.global_position))
	var on_floor = func(at: Vector2i) -> bool: return scene.is_walkable(tile_map.to_global(tile_map.map_to_local(at)))
	# Everywhere along his beat, looking west and about: never into the cell.
	var start: Vector2i = tile_map.local_to_map(scene.party_position())
	var beat := {}
	var west = tile_map.local_to_map(tile_map.to_local(Actors.waypoint_position(warden.patrol[1])))
	var east = tile_map.local_to_map(tile_map.to_local(Actors.waypoint_position(warden.patrol[0])))
	for x in range(west.x, east.x + 1):
		for y in [west.y, east.y]:
			beat.merge(ever_seen(sight, Vector2i(x, y), 180.0, true))
	var cell_seen := []
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			if beat.has(start + Vector2i(dx, dy)) and on_floor.call(start + Vector2i(dx, dy)):
				cell_seen.append(start + Vector2i(dx, dy))
	ok(cell_seen.is_empty(), "the warden's beat never looks into the cell", "%s" % [cell_seen])
	# From the corridor behind him to beside the way out, never in the door
	# guard's view.
	var door_sees = ever_seen(sight, tile_of.call(door), door.facing_degrees, door.looks_around)
	var target: Vector2i = tile_of.call(goal)
	var from := Vector2i(west.x + 1, east.y)
	var frontier := [from]
	var visited := {from: true}
	var found := false
	while not frontier.is_empty():
		var t: Vector2i = frontier.pop_front()
		if door_sees.has(t):
			continue
		if absi(t.x - target.x) <= 1 and absi(t.y - target.y) <= 1:
			found = true
			break
		for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = t + d
			if not visited.has(next) and on_floor.call(next):
				visited[next] = true
				frontier.append(next)
	ok(found, "and there is a way from the corridor to the exit the door guard never sees")


func check_stage(n: int, talk, script_text: String):
	log_line("======== stage %d ========" % n)
	Campaign.reset()
	Campaign.current_map = STAGES[n - 1]
	var scene: ExplorationScene = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(scene)
	await settle(4)
	# Stage 3 opens with a word from Enfina.
	for node in get_tree().root.find_children("*", "", true, false):
		if node.scene_file_path == BALLOON:
			node.queue_free()
	scene.end_blocking_interaction()
	var tile_map: TileMap = scene._tile_map
	# The map sits under Map/Terrain here, out of the camera's own path's reach.
	ok(scene.camera.get_map_rect().size.x > 0.0, "the camera knows the map's size",
		"%s" % scene.camera.get_map_rect())
	var sight := StealthSight.new(tile_map)
	var watch: StealthWatch = scene.stealth
	ok(watch != null and watch.guards.size() >= 2, "a stealth map, watched", "%d guards" % (watch.guards.size() if watch else 0))
	if watch == null:
		scene.queue_free()
		await settle()
		return
	watch.leave_for_battle = false
	var tile_of = func(node: Node2D) -> Vector2i: return tile_map.local_to_map(tile_map.to_local(node.global_position))
	var on_floor = func(at: Vector2i) -> bool: return scene.is_walkable(tile_map.to_global(tile_map.map_to_local(at)))
	var start: Vector2i = tile_map.local_to_map(scene.party_position())
	ok(on_floor.call(start), "the party starts on floor", "%s" % start)

	# Nobody can see where the party starts - and a ward, which turns all the
	# way round, never can.
	var seen_by := []
	for guard in watch.guards:
		if watch.sees(guard, start):
			seen_by.append(guard.name)
		if guard.kind == Guard.Kind.WARD and sight.clear(tile_of.call(guard), start):
			seen_by.append("%s, when it comes round" % guard.name)
	ok(seen_by.is_empty(), "nobody is looking at the start", "%s" % [seen_by])

	log_line("  -- the map is its battle terrain")
	var blocked = watch._battle_blocking()
	var differ := []
	var region: Rect2i = tile_map.get_used_rect()
	for x in range(region.position.x, region.end.x):
		for y in range(region.position.y, region.end.y):
			var at := Vector2i(x, y)
			# A door is floor, open or shut - the fight has no doors.
			var floor_there: bool = region.has_point(at) and not scene._blocking.has(at)
			if floor_there == blocked.has(at) and differ.size() < 5:
				differ.append(at)
	ok(differ.is_empty(), "every tile walkable on the map is walkable in the fight, and no other", "%s" % [differ])

	log_line("  -- every guard can walk their beat")
	for guard in watch.guards:
		ok(CombatantDatabase.combatants.has(guard.combatant_key) and on_floor.call(tile_of.call(guard)),
			"%s is a %s, on floor" % [guard.name, guard.combatant_key], "%s" % tile_of.call(guard))
		var points := []
		for waypoint in guard.patrol:
			var at = Actors.waypoint_position(waypoint)
			ok(at != null and on_floor.call(tile_map.local_to_map(tile_map.to_local(at))), "  their waypoint '%s' is on floor" % waypoint)
			if at != null:
				points.append(at)
		for i in range(1, points.size()):
			var route: Array = Actors.route(points[i - 1], points[i])
			ok(not route.is_empty() and route.back().distance_to(points[i]) < 1.0, "  and there is a way between them")

	log_line("  -- the rest of it")
	var map = scene.get_node("Map")
	var spots = map.find_children("*", "HidingSpot", true, false)
	for spot in spots:
		ok(on_floor.call(tile_of.call(spot)), "%s is on floor" % spot.name, "%s" % tile_of.call(spot))
	var goals = map.find_children("*", "StealthGoal", true, false)
	ok(goals.size() == 1, "one way out")
	if goals.size() == 1:
		var goal: StealthGoal = goals[0]
		var path: Array = Actors.route(scene.party_position(), goal.global_position)
		ok(not path.is_empty() and path.back().distance_to(goal.global_position) < 1.0, "which can be walked to from the start",
			"%d steps" % path.size())
		ok(goal.completed_flag == "stage%d_done" % n and goal.ghost_flag == "stage%d_ghost" % n, "and sets its flags, the ghost's too")
		ok(goal.ends_at_menu and goal.goes_to_map == "", "then goes back to the title screen's list")
		ok(goal.dialogue == talk and talk.get_cues().has(goal.dialogue_title), "its conversation is there", goal.dialogue_title)
	for node in map.find_children("*", "DialogueInteractable", true, false):
		ok(node.dialogue != null and node.dialogue.get_cues().has(node.dialogue_title), "%s's conversation is there" % node.name, node.dialogue_title)
		ok(on_floor.call(tile_of.call(node)), "  and it stands on floor")
	var fight = watch.build_fight()
	var bad := []
	for spawn in fight.spawns:
		if blocked.has(spawn.position):
			bad.append(spawn.position)
	ok(bad.is_empty() and fight.spawns.size() > 1, "caught at the start, everybody in the fight is on floor", "%s" % [bad])

	log_line("  -- what it is there to show")
	ok(watch.hides_guards(), "guards are seen only when he could see them, so there is something to listen for")
	var kinds := {}
	for guard in watch.guards:
		kinds[guard.kind] = guard
	match n:
		1:
			ok(watch.throwable() == "pebble", "he has pebbles to throw")
			ok(spots.size() >= 3, "somewhere to hide", "%d spots" % spots.size())
			var holder = null
			for guard in watch.guards:
				if guard.picked_flag == "stage1_keys" and not guard.patrol.is_empty():
					holder = guard
			ok(holder != null, "a guard walking about with the keys in his pockets")
			ok(goals.size() == 1 and goals[0].requires_flag == "stage1_keys", "and the way out needs them")
			ok(watch.guards.any(func(g): return g.patrol.is_empty() and g.can_be_taken_down), "a sentry standing still, to be taken down")
		2:
			ok(kinds.has(Guard.Kind.WARD) and kinds.has(Guard.Kind.DOG) and kinds.has(Guard.Kind.CAPTAIN),
				"a ward, a dog and a captain", "%s" % [kinds.keys().map(func(k): return Guard.Kind.keys()[k])])
			ok(watch.setup.joins_within_tiles > 0.0 and watch.setup.tiles_per_late_round > 0.0, "and a fight the far ones join late")
		3:
			ok(Campaign.party_members().size() == 2, "two to get out", "%s" % [Campaign.party_members().map(func(m): return m.key)])
			var paired = spots.all(func(s): return spots.any(func(o): return o != s and tile_of.call(o).distance_to(tile_of.call(s)) <= 1.0))
			ok(spots.size() >= 2 and paired, "hiding spots side by side, one each")
			escort_can_be_ghosted(watch, sight, tile_map, scene, goals[0] if goals.size() == 1 else null)
		4:
			ok(script_text.contains('give_item("cyrus", "priest_robes")'), "the locker hands out Priest's robes")
			var by_recognising := {}
			for guard in watch.guards:
				by_recognising[guard.recognises] = guard
			ok(by_recognising.size() == 3, "a guard for every kind of recognising")
			var asks = null
			for guard in watch.guards:
				if guard.questions != null:
					asks = guard
			ok(asks != null and asks.passed_flag == "stage4_passed" and asks.questions.get_cues().has(asks.questions_title)
				and script_text.contains('set_flag("stage4_passed")'), "one asks questions that can be answered right")
		5:
			ok(watch.is_dark() and watch._lamps.size() >= 2, "dark, and lit by lamps", "%d lamps" % watch._lamps.size())
			ok(watch.lit_at(start) > 0.0, "the start lit by its torch, and shut away behind a door")
			var locked = watch._doors.filter(func(d): return d.requires_flag == "stage5_key")
			ok(watch._doors.size() >= 2 and locked.size() == 1, "doors, one locked")
			var porter = watch.guards.filter(func(g): return g.asleep and g.picked_flag == "stage5_key")
			ok(porter.size() == 1, "and the key on a guard asleep")
			var grounds := {}
			for patch in map.find_children("*", "NoisyFloor", true, false):
				grounds[patch.kind] = true
			ok(grounds.size() == 3, "gravel, puddles and glass underfoot")
			var roster = map.find_children("*", "ExamineInteractable", true, false).filter(func(n): return n.sets_flag == "stage5_roster")
			ok(roster.size() == 1 and watch.guards.filter(func(g): return g.route_known_flag == "stage5_roster").size() >= 2,
				"a duty roster that tells two rounds")
			ok(kinds.has(Guard.Kind.CIVILIAN), "somebody who is nobody's guard, to run and tell")
			ok(watch._pickups.any(func(p): return p.item_key == "archive_ledger") and watch.objectives().size() == 2, "a ledger to steal, and two things to do")
		6:
			var chats = map.find_children("*", "GuardChat", true, false)
			ok(chats.size() == 1 and chats[0].lines.size() >= 2 and chats[0].overheard_flag == "stage6_overheard" and chats[0].check_in,
				"two guards who meet to talk, overheard - and missed")
			ok(watch._chats.size() == 1, "(both of them there)")
			var meals = watch._edibles
			ok(meals.size() == 1 and watch._guard_named(meals[0].eater) != null, "somebody's supper, and him")
			ok(map.find_children("*", "RetchSpot", true, false).size() == 1, "somewhere to be sick")
			ok(map.find_children("*", "PlantSpot", true, false).any(func(p): return p.item_key == "forged_letter"), "a desk to leave the letter on")
			var leader_key: String = Campaign.party_members()[0].key
			ok(Campaign.food_poison_of(leader_key) != "" and not Campaign.darts_of(leader_key).is_empty() and Campaign.count_of(leader_key, "forged_letter") == 1,
				"poison for supper, darts, and the letter")
			ok(kinds.has(Guard.Kind.CIVILIAN), "a cook who runs for the guards")
			ok(watch.objectives().size() == 3, "three things to do")
		7:
			ok(watch.alert_level() == "Wary", "the camp on edge from the start", watch.alert_level())
			ok(not watch.setup.reinforcements.is_empty() and Actors.waypoint_position(watch.setup.reinforcements_arrive_at) != null,
				"and the barracks to turn out")
			ok(watch.guards.any(func(g): return g.pockets.has("small_bomb")), "bombs in somebody's pockets")
			var robes = ItemDatabase.item("priest_robes")
			ok(watch.guards.filter(func(g): return g.fights() and not g.sees_through(robes)).size() >= 2, "guards the robes fool, to have a word with")
			ok(watch.guards.any(func(g): return g.fights() and g.sees_through(robes) and g.combatant_key == "priest"), "and a priest they do not")
			ok(watch.guards.any(func(g): return not g.can_be_taken_down and g.fights()), "a gate guard who cannot be taken down")
			ok(Campaign.count_of(Campaign.party_members()[0].key, "priest_robes") == 1, "the robes to wear")
			ok(watch.objectives().size() == 2, "two things to do")
	scene.queue_free()
	await settle()
	log_line("")
