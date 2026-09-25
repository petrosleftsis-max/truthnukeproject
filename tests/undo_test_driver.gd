extends Node
## Taking a walk back: allowed for as long as the walking changed nothing but
## where the walker stands. Once something else has happened - a skill, a
## reaction on the way - it cannot be walked back past, but the walking after it
## can be taken back to just after it.

var LOG_PATH := HarnessLog.path_for("undo")

var _log: FileAccess = null
var _fail = 0
var _game: Node = null


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
	get_tree().create_timer(200.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


## A fresh fight, on a player's turn, with the party placed.
func start() -> Array:
	if _game != null:
		_game.queue_free()
		await get_tree().process_frame
	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_02_sappers.tres")
	_game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(_game)
	for i in 4:
		await get_tree().process_frame
	var combat: Combat = _game.get_node("VisualCombat")
	combat.finish_deployment()
	await get_tree().process_frame
	return [combat, _game.get_node("Controller"), _game.get_node("CanvasLayer/UI")]


## Somewhere the one acting can walk to this turn, at least `least` tiles away,
## as far from every enemy as can be had - so nothing reacts on the way unless a
## scenario puts something there.
func safe_tile(combat: Combat, controller, least: int = 2) -> Vector2i:
	var walker = combat.get_current_combatant()
	var best = walker.position
	var best_room = -1
	for tile in controller.get_reachable_tiles(walker.position, walker.movement_class, controller.movement):
		if combat.get_position_distance(walker.position, tile) < least:
			continue
		var room = 999
		for comb in combat.combatants:
			if comb.side == 1 and comb.alive:
				room = mini(room, combat.get_position_distance(tile, comb.position))
		if room > best_room:
			best_room = room
			best = tile
	return best


## Walks the one acting to `tile` through the same calls a click makes, and
## waits for them to get there.
func walk_to(combat: Combat, controller, tile: Vector2i):
	controller.find_path(tile)
	controller.move_player()
	var frames = 0
	await get_tree().process_frame
	while not controller.is_idle() and frames < 3000:
		await get_tree().process_frame
		frames += 1
	await get_tree().process_frame


func press_backspace():
	var key := InputEventKey.new()
	key.keycode = KEY_BACKSPACE
	key.physical_keycode = KEY_BACKSPACE
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().process_frame
	await get_tree().process_frame


func run_test():
	log_line("======== nothing to take back before anybody has walked ========")
	var parts = await start()
	var combat: Combat = parts[0]
	var controller = parts[1]
	var ui = parts[2]
	var walker = combat.get_current_combatant()
	ok(walker.side == 0, "a player's turn", walker.name)
	ok(not controller.has_walked(), "placing the party is not walking")
	ok(not ui._undo_button.visible, "so there is no Undo Move to press")
	ok(not controller.undo_move(), "and asking for one does nothing")
	log_line("")

	log_line("======== a walk that changed nothing else ========")
	var start_tile = walker.position
	var full = controller.movement
	var dest = safe_tile(combat, controller)
	await walk_to(combat, controller, dest)
	ok(walker.position == dest, "they walked", "%s -> %s" % [start_tile, walker.position])
	ok(controller.movement < full, "spending movement", "%d of %d" % [controller.movement, full])
	ok(controller.can_undo_move(), "and it can be taken back")
	ok(ui._undo_button.visible and not ui._undo_button.disabled, "with Undo Move there to press")
	await press_backspace()
	ok(walker.position == start_tile, "Backspace puts them back where the turn began", "%s" % walker.position)
	ok(controller.movement == full, "with all their movement", "%d of %d" % [controller.movement, full])
	ok(ui.get_node("Actions/Movement").text == "Move %d" % full, "and the counter says so", ui.get_node("Actions/Movement").text)
	ok(combat.get_combatant_at(dest).is_empty() and controller._occupied_spaces.has(start_tile)
		and not controller._occupied_spaces.has(dest), "the tile they walked to is free again, and theirs is taken")
	ok(not controller.has_walked() and not ui._undo_button.visible, "and there is nothing left to take back")
	# And the button does the same as the key.
	await walk_to(combat, controller, dest)
	ui._undo_button.pressed.emit()
	await get_tree().process_frame
	ok(walker.position == start_tile, "the button walks them back too")
	log_line("")

	log_line("======== a skill is where a walk back stops ========")
	# Walk, use a skill, walk again: the second walk can be taken back, to just
	# after the skill - never past it.
	await walk_to(combat, controller, dest)
	await combat.use_skill("run", walker, walker.position, false)
	await get_tree().process_frame
	var stood = walker.position
	var left = controller.movement
	ok(not controller.can_undo_move(), "straight after using a skill there is nothing to take back")
	ok(not ui._undo_button.visible, "so Undo Move is not offered")
	await press_backspace()
	ok(walker.position == stood, "and Backspace leaves them where they are", "%s" % walker.position)
	var onward = walker.position
	for tile in controller.get_reachable_tiles(walker.position, walker.movement_class, controller.movement):
		if tile != stood and tile != start_tile and combat.get_combatant_at(tile).is_empty() \
				and combat.get_position_distance(tile, stood) >= 2 and onward == stood:
			onward = tile
	ok(onward != stood, "somewhere left to walk to after it", "%s" % onward)
	await walk_to(combat, controller, onward)
	ok(walker.position == onward and controller.movement < left, "they walk on", "%s, %d of %d" % [walker.position, controller.movement, left])
	ok(controller.can_undo_move(), "and that walk can be taken back")
	ok(ui._undo_button.visible and not ui._undo_button.disabled, "with Undo Move there to press")
	await press_backspace()
	ok(walker.position == stood, "back to where they used the skill", "%s, not %s" % [walker.position, start_tile])
	ok(controller.movement == left, "with the movement they had left after it", "%d of %d" % [controller.movement, left])
	ok(walker.skill_used_this_turn or walker.secondary_used_this_turn, "and the skill still spent")
	await press_backspace()
	ok(walker.position == stood, "a second Backspace goes no further back")
	await walk_to(combat, controller, onward)
	ui._undo_button.pressed.emit()
	await get_tree().process_frame
	ok(walker.position == stood, "and it stops there every time")
	log_line("")

	log_line("======== too late once anybody else's state has changed ========")
	parts = await start()
	combat = parts[0]
	controller = parts[1]
	ui = parts[2]
	walker = combat.get_current_combatant()
	await walk_to(combat, controller, safe_tile(combat, controller))
	ok(controller.can_undo_move(), "a plain walk can be taken back")
	var someone = {}
	for comb in combat.combatants:
		if comb.side == 1 and comb.alive and someone.is_empty():
			someone = comb
	someone.hp -= 1
	ok(not controller.can_undo_move(), "but not once somebody's health has changed")
	someone.hp += 1
	someone.reaction_used = true
	ok(not controller.can_undo_move(), "nor once somebody's reaction is spent")
	someone.reaction_used = false
	combat.set_hidden(someone, true)
	ok(not controller.can_undo_move(), "nor once somebody's hiding has changed")
	ui.refresh_action_buttons()
	ok(ui._undo_button.visible and ui._undo_button.disabled, "Undo Move stays in sight, greyed out")
	ok(ui._undo_button.tooltip_text == ui.UNDO_TOO_LATE, "saying why")
	combat.set_hidden(someone, false)
	ok(controller.can_undo_move(), "and with all of it put back as it was, it can again")
	log_line("")

	log_line("======== a reaction on the way is where a walk back stops ========")
	parts = await start()
	combat = parts[0]
	controller = parts[1]
	ui = parts[2]
	walker = combat.get_current_combatant()
	var guard = {}
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == "barbarian" and comb.alive and guard.is_empty():
			guard = comb
	ok(SkillDatabase.skills["greatsword_attack"].is_reactive, "the Barbarian's greatsword swings at anybody leaving its reach")
	# Stood right beside the walker, so walking off provokes it.
	for step in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
		if combat.teleport_to(guard, walker.position + step):
			break
	ok(combat.get_distance(walker, guard) == 1, "the Barbarian stands beside the walker", "%s / %s" % [walker.position, guard.position])
	var away = walker.position
	var far = -1
	for tile in controller.get_reachable_tiles(walker.position, walker.movement_class, controller.movement):
		var gap = combat.get_position_distance(tile, guard.position)
		if gap > far:
			far = gap
			away = tile
	var hp_before = walker.hp
	var began = walker.position
	await walk_to(combat, controller, away)
	ok(guard.reaction_used or walker.hp < hp_before, "walking off set the greatsword off",
		"reaction_used=%s hp %d -> %d" % [guard.reaction_used, hp_before, walker.hp])
	var hp_after = walker.hp
	var stop = controller._turn_start_position
	ok(stop != began, "so a walk back no longer reaches where they began", "%s" % stop)
	ok(combat.get_distance(walker, guard) > 1 and combat.get_position_distance(stop, guard.position) > 1,
		"it stops at the first tile past the Barbarian's reach", "%s, guard at %s" % [stop, guard.position])
	ok(controller.can_undo_move(), "but the walking after the swing can still be taken back")
	await press_backspace()
	ok(walker.position == stop, "to just after the swing", "%s" % walker.position)
	ok(walker.hp == hp_after and guard.reaction_used, "which stays swung")
	ok(controller.movement == controller._turn_start_movement and controller.movement > 0,
		"with the movement they had there", "%d" % controller.movement)
	log_line("")

	log_line("======== a new turn has nothing to take back ========")
	parts = await start()
	combat = parts[0]
	controller = parts[1]
	ui = parts[2]
	walker = combat.get_current_combatant()
	await walk_to(combat, controller, safe_tile(combat, controller))
	var next = {}
	for comb in combat.combatants:
		if comb.side == 0 and comb.alive and comb != walker and next.is_empty():
			next = comb
	combat.current_combatant = combat.combatants.find(next)
	controller.set_controlled_combatant(next)
	ui.show_combatant_status_main(next)
	ok(not controller.has_walked() and not ui._undo_button.visible, "the next one starts with no walk to undo", next.name)
	log_line("")

	_game.queue_free()
	await get_tree().process_frame
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
