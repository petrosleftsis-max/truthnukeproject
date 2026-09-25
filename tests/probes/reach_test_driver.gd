extends Node
## Walking into something, and something that only happens once.
##
## An automatic interactable is reached by walking into it; a manual one by
## standing near it and pressing the key. Both are supposed to measure the same
## ring - the one drawn around it in the editor - and a once-only thing is
## supposed to be spent whichever way it was reached.

var LOG_PATH := HarnessLog.path_for("reach")
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


## The automatic things on a map, and the ones you press.
func sort_out(scene) -> Dictionary:
	var found := {"automatic": [], "manual": []}
	for item in scene._interactables:
		if item.get("automatic"):
			found["automatic"].append(item)
		else:
			found["manual"].append(item)
	return found


func run_test():
	log_line("======== every map's automatic triggers measure their own ring ========")
	# The old scene-wide radius, which every automatic trigger used no matter
	# how large a ring was drawn around it.
	var old_contact_radius = Grid.TILE_SIZE * 0.5625
	log_line("  (the old one-size radius was %.0f px; a tile is %d)" % [old_contact_radius, Grid.TILE_SIZE])
	for map in ["res://church.tscn", "res://scenes/laboratory_terrain_explore.tscn",
			"res://scenes/explore_crossroads.tscn"]:
		Campaign.reset()
		Campaign.current_map = map
		var scene = load("res://scenes/exploration.tscn").instantiate()
		get_tree().root.add_child(scene)
		for i in 5:
			await get_tree().process_frame
		var sorted = sort_out(scene)
		for item in sorted["automatic"]:
			log_line("  %s / %s: ring %.0f px (%.2f tiles)" % [
				map.get_file(), item.name, item.interaction_radius,
				item.interaction_radius / Grid.TILE_SIZE])
			# Just inside its own ring, but outside the radius the game used to
			# measure. This is the gap the player was falling through.
			var edge = item.global_position + Vector2(item.interaction_radius * 0.9, 0)
			var reached_before = old_contact_radius >= item.global_position.distance_to(edge)
			scene._blocking_interaction = false
			item.contact_spent = false
			scene._check_contact_triggers(edge)
			ok(item.contact_spent, "%s fires at %.0f px" % [item.name, item.interaction_radius * 0.9],
				"the old radius would %s have reached" % ("also" if reached_before else "not"))
			# And genuinely outside it, nothing happens.
			scene._blocking_interaction = false
			item.contact_spent = false
			scene._check_contact_triggers(item.global_position + Vector2(item.interaction_radius + 40.0, 0))
			ok(not item.contact_spent, "  and not a step beyond it")
		scene.queue_free()
		await get_tree().process_frame
	log_line("")

	log_line("======== once means once ========")
	Campaign.reset()
	Campaign.current_map = "res://church.tscn"
	var church = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(church)
	for i in 5:
		await get_tree().process_frame
	var once_only = null
	for item in church._interactables:
		if item.get("automatic") and item.get("only_once"):
			once_only = item
			break
	ok(once_only != null, "the church opens with a scene that plays once")
	if once_only != null:
		# It fires as the map comes up - the party spawns standing in it, which
		# is what an arrival scene is for.
		ok(once_only.contact_spent, "it plays as the party arrives, without being asked")
		ok(not once_only.is_available(),
			"and it is spent - not waiting to happen again")
		# Walk away, walk back.
		church._blocking_interaction = false
		church._check_contact_triggers(once_only.global_position + Vector2(2000, 2000))
		church._check_contact_triggers(once_only.global_position)
		ok(once_only.contact_spent, "retracing your steps does not replay it")
		# And the interact key cannot reach it either, standing right on it.
		ok(church._nearest_interactable() != once_only,
			"nor can the interact key, standing on the spot",
			"%s" % [church._nearest_interactable()])
	log_line("")

	log_line("======== an automatic thing is never something to press ========")
	var pressable := []
	for item in church._interactables:
		if not item.get("automatic"):
			continue
		item.contact_spent = false
		# Standing exactly on it, with nothing spent.
		for candidate in church._interactables:
			pass
		if church._nearest_interactable() == item:
			pressable.append(item.name)
	ok(pressable.is_empty(), "nothing automatic is offered to the key", "%s" % [pressable])
	# The things that are meant to be pressed still are.
	var manual = sort_out(church)["manual"]
	if not manual.is_empty():
		var target = manual[0]
		church.party.leader.global_position = target.global_position
		await get_tree().process_frame
		ok(church._nearest_interactable() == target,
			"and %s still is" % target.name,
			"%s" % [church._nearest_interactable()])
	church.queue_free()
	await get_tree().process_frame
	log_line("")

	log_line("======== the glossary's Back button ========")
	var menu = load("res://main_menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	await get_tree().process_frame
	var panel = menu._panels["glossary"]
	panel.show_contents()
	await get_tree().process_frame
	# The real button, pressed the way a player presses it - not _go_back()
	# called directly, which is how this bug got past its own test.
	var back: Button = null
	for child in panel.get_children():
		if child is Button and child.text == "Back":
			back = child
	ok(back != null, "there is a Back button to press")
	var listed := []
	for child in panel._list.get_children():
		if child is Button:
			listed.append(child.text)
	ok("Conditions" in listed, "the contents are showing", "%s" % [listed])
	for child in panel._list.get_children():
		if child is Button and child.text == "Conditions":
			child.pressed.emit()
	await get_tree().process_frame
	var conditions := []
	for child in panel._list.get_children():
		if child is Button:
			conditions.append(child.text)
	ok(conditions.size() > 4 and not ("Conditions" in conditions),
		"opening Conditions shows the conditions", "%s" % [conditions.slice(0, 3)])
	if back != null:
		back.pressed.emit()
		await get_tree().process_frame
		var after := []
		for child in panel._list.get_children():
			if child is Button:
				after.append(child.text)
		ok("Conditions" in after, "and Back really goes back", "%s" % [after])
		# Out of the front door.
		var let_go = [false]
		panel.closed.connect(func(): let_go[0] = true)
		back.pressed.emit()
		await get_tree().process_frame
		ok(let_go[0], "and from the contents it hands the menu back")
	menu.queue_free()
	await get_tree().process_frame
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
