extends Node
## Teleports, and the two church bugs.

var LOG_PATH := HarnessLog.path_for("tele")
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


## A tile nobody is on that `comb` could stand on, within `reach` of `from`.
func free_tile_near(combat, comb, from: Vector2i, reach: int) -> Vector2i:
	for radius in range(1, reach + 1):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				var tile = from + Vector2i(dx, dy)
				if combat.get_position_distance(from, tile) > reach:
					continue
				if tile == comb.position:
					continue
				if combat.can_land_on(comb, tile):
					return tile
	return Vector2i(-99999, -99999)


func run_test():
	log_line("======== the two teleport skills are whole ========")
	var step: SkillDefinition = SkillDatabase.skills.get("hermes_step")
	ok(step != null, "Hermes Step exists")
	if step != null:
		ok(step.teleports == SkillDefinition.TeleportWho.TARGET, "it moves somebody else")
		ok(step.spell_slot_level == 2, "and costs a Gate of Hermes", Stats.gate_name(step.spell_slot_level))
		ok(step.targets_ally, "aimed at an ally")
		ok(step.max_range > 0, "within a range", "%d" % step.max_range)
	var blink: SkillDefinition = SkillDatabase.skills.get("blink_strike")
	ok(blink != null, "Blink Strike exists")
	if blink != null:
		ok(blink.teleports == SkillDefinition.TeleportWho.CASTER, "it moves the user")
		ok(blink.spell_slot_level == 0, "and costs nothing")
		ok(blink.aoe_radius > 0, "hitting everything beside where they land", "radius %d" % blink.aoe_radius)
		ok(blink.deals_damage, "and it does damage")
	log_line("")

	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_02_sappers.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	for i in 6:
		await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await get_tree().process_frame

	log_line("======== landing rules ========")
	var mover = null
	for comb in combat.combatants:
		if comb.side == 0 and comb.alive:
			mover = comb
			break
	ok(mover != null, "somebody to move")
	if mover != null:
		ok(not combat.can_land_on(mover, Vector2i(-9999, -9999)), "nobody lands off the map")
		var occupied = null
		for comb in combat.combatants:
			if comb != mover and comb.alive:
				occupied = comb
				break
		if occupied != null:
			ok(not combat.can_land_on(mover, occupied.position),
				"nor on top of somebody else", "%s" % occupied.position)
		var free = free_tile_near(combat, mover, mover.position, 4)
		ok(free != Vector2i(-99999, -99999), "there is somewhere free to go", "%s" % free)
		if free != Vector2i(-99999, -99999):
			var was = mover.position
			ok(combat.teleport_to(mover, free), "and they can be put there")
			ok(mover.position == free, "they really moved", "%s -> %s" % [was, mover.position])
			ok(mover.sprite.position == Grid.tile_to_world(free), "and so did their sprite")
			ok(combat.get_combatant_at(free) == mover, "the grid agrees where they are")
			ok(combat.get_combatant_at(was).is_empty(), "and they are no longer where they were")
	log_line("")

	log_line("======== a battle opens looking at your own people ========")
	var players := []
	for comb in combat.combatants:
		if comb.side == 0 and comb.alive:
			players.append(comb)
	ok(not players.is_empty(), "there is a party to look at", "%d" % players.size())
	if not players.is_empty() and combat.camera != null:
		# Wherever the view has wandered, centring puts it back on them.
		combat.camera.position = Vector2(99999, 99999)
		combat.centre_on_party()
		var middle := Vector2.ZERO
		for comb in players:
			middle += Grid.tile_to_world(comb.position)
		middle /= players.size()
		# Clamped to the map, so compare against how far off it can legally be.
		var furthest := 0.0
		for comb in players:
			furthest = maxf(furthest, combat.camera.position.distance_to(Grid.tile_to_world(comb.position)))
		var spread := 0.0
		for comb in players:
			spread = maxf(spread, middle.distance_to(Grid.tile_to_world(comb.position)))
		ok(furthest <= spread + combat.camera.get_visible_world_size().length(),
			"and the view sits among them", "%.0f from the furthest, they span %.0f" % [furthest, spread])
		ok(not combat.camera.is_following(), "with nothing locked onto")
	log_line("")

	log_line("======== Blink Strike lands, then swings ========")
	# Whoever actually carries it - which of them knows a skill is content.
	var cyrus = null
	for comb in combat.combatants:
		if comb.side == 0 and comb.alive and "blink_strike" in comb.skill_list:
			cyrus = comb
			break
	ok(cyrus != null, "somebody in this fight knows Blink Strike",
		cyrus.name if cyrus != null else "nobody")
	if cyrus != null:
		# Put an enemy somewhere, and blink next to them.
		var victim = null
		for comb in combat.combatants:
			if comb.side == 1 and comb.alive:
				victim = comb
				break
		if victim != null:
			var beside = free_tile_near(combat, cyrus, victim.position, 1)
			if beside != Vector2i(-99999, -99999):
				# Stand Cyrus within reach of that tile.
				var launch = free_tile_near(combat, cyrus, beside, blink.max_range)
				if launch != Vector2i(-99999, -99999):
					combat.teleport_to(cyrus, launch)
					var started = cyrus.position
					var hp_before = victim.hp
					# The swing can miss - 90 accuracy, rolled once for the whole use -
					# so blink in again until one of them connects.
					var arrivals = 0
					while victim.hp == hp_before and victim.alive and arrivals < 6:
						combat.teleport_to(cyrus, launch)
						await combat.use_skill("blink_strike", cyrus, beside, false, false)
						arrivals += 1
					ok(cyrus.position == beside, "he arrives where he aimed",
						"%s -> %s" % [started, cyrus.position])
					ok(victim.hp < hp_before, "and everything beside him takes it",
						"%s %d -> %d in %d arrivals" % [victim.name, hp_before, victim.hp, arrivals])
					if victim.alive:
						# Aimed at the tile he is already on: no journey, but it still bursts.
						# It can miss - 90 accuracy - so give it a few swings.
						var standing = victim.hp
						var swings = 0
						while victim.hp == standing and victim.alive and swings < 6:
							await combat.use_skill("blink_strike", cyrus, cyrus.position, false, false)
							swings += 1
						ok(victim.hp < standing, "and cast where he stands it bursts anyway",
							"%s %d -> %d in %d swings" % [victim.name, standing, victim.hp, swings])
	log_line("")

	log_line("======== Hermes Step moves somebody else ========")
	# Cast by whoever actually has it - it costs a Gate of Hermes, and only a
	# character with gated skills has any gates to spend.
	var caster = null
	for comb in combat.combatants:
		if comb.side == 0 and comb.alive and "hermes_step" in comb.skill_list:
			caster = comb
			break
	ok(caster != null, "somebody in this fight knows Hermes Step",
		caster.name if caster != null else "nobody")
	var ally = null
	for comb in combat.combatants:
		if comb.side == 0 and comb.alive and comb != caster:
			ally = comb
			break
	if ally != null and caster != null:
		# Stand the caster within reach of them first.
		var spot = free_tile_near(combat, caster, ally.position, 2)
		if spot != Vector2i(-99999, -99999):
			combat.teleport_to(caster, spot)
		var landing = free_tile_near(combat, ally, caster.position, step.max_range)
		if landing != Vector2i(-99999, -99999):
			var was = ally.position
			# The caster is whoever is acting; the subject is the ally, the
			# destination the second click.
			var caster_was = caster.position
			await combat.use_skill("hermes_step", caster, ally.position, false, false, landing)
			ok(ally.position == landing, "the ally is moved",
				"%s -> %s" % [was, ally.position])
			ok(caster.position == caster_was, "and the caster stayed put",
				"%s" % caster.position)
	log_line("")

	log_line("======== two clicks, not one ========")
	var controller = combat.controller
	controller._selected_skill = "hermes_step"
	controller._skill_selected = true
	controller._teleport_subject = Vector2i(-99999, -99999)
	ok(not controller.waiting_for_destination(), "it starts wanting a subject")
	if ally != null:
		controller.confirm_skill_target(ally.position)
		ok(controller.waiting_for_destination(),
			"the first click holds them rather than casting", "%s" % controller._teleport_subject)
		ok(controller._skill_selected, "and aiming is still on")
		ok(controller.picking_a_landing_tile(), "and it is now asking where to put them")
		var in_the_way = null
		for comb in combat.combatants:
			if comb.alive and comb != ally:
				in_the_way = comb
				break
		if in_the_way != null:
			ok(not controller.is_valid_landing_tile(in_the_way.position),
				"which cannot be on top of somebody", "%s" % in_the_way.position)
		ok(not controller.is_valid_landing_tile(ally.position), "nor where they already are")
		controller.cancel_skill_selection()
		ok(not controller.waiting_for_destination(), "cancelling lets go of them")
	log_line("")

	log_line("======== a blink will not be aimed at a body ========")
	var actor = combat.get_current_combatant()
	controller._teleport_subject = Vector2i(-99999, -99999)
	controller.set_selected_skill("blink_strike")
	controller.begin_target_selection()
	ok(controller.picking_a_landing_tile(), "a blink asks for a tile, not a target")
	var body = null
	for comb in combat.combatants:
		if comb.alive and comb != actor:
			body = comb
			break
	if body != null:
		ok(not controller.is_valid_landing_tile(body.position),
			"aiming it at somebody is refused", "%s at %s" % [body.name, body.position])
		ok(not (body.position in controller._range_preview_positions),
			"and their tile is not even offered")
	ok(controller.is_valid_landing_tile(actor.position),
		"but standing still is allowed - it still bursts where it is")
	ok(actor.position in controller._range_preview_positions,
		"and their own tile is offered")
	var open_tile = free_tile_near(combat, actor, actor.position, 4)
	if open_tile != Vector2i(-99999, -99999):
		ok(controller.is_valid_landing_tile(open_tile), "an empty tile is fine", "%s" % open_tile)
	var standing_on := []
	for tile in controller._range_preview_positions:
		if tile != actor.position and not combat.get_combatant_at(tile).is_empty():
			standing_on.append(tile)
	ok(standing_on.is_empty(), "nobody else is standing on a marked tile", "%s" % [standing_on])
	controller.cancel_skill_selection()
	log_line("")

	game.queue_free()
	await get_tree().process_frame

	log_line("======== the church ========")
	var church = load("res://church.tscn").instantiate()
	add_child(church)
	await get_tree().process_frame
	var dialogues := {}
	var arrival = null
	for node in church.get_children():
		if node is DialogueInteractable:
			if node.dialogue != null:
				dialogues[node.dialogue.resource_path.get_file().get_basename()] = node
			if node.automatic:
				arrival = node
	ok(dialogues.has("church_after_reveal_clown"),
		"the clown is somebody you can talk to now", "%s" % [dialogues.keys()])
	if dialogues.has("church_after_reveal_clown"):
		var clown = dialogues["church_after_reveal_clown"]
		var tile = Vector2i(floori(clown.position.x / Grid.TILE_SIZE), floori(clown.position.y / Grid.TILE_SIZE))
		ok(tile.x <= 2 and tile.y <= 2, "in the upper left of the room", "%s" % tile)
	for wanted in ["church_after_reveal_cyrus", "church_after_reveal_prometheus",
			"church_after_reveal_enfina", "church_after_reveal_door_blocked"]:
		ok(dialogues.has(wanted), "%s is still reachable" % wanted)
	ok(arrival != null and arrival.only_once,
		"the opening scene plays once rather than every time you walk back")
	church.queue_free()
	await get_tree().process_frame

	# The door's first branch, which needs all four flags.
	Campaign.reset()
	var door = load("res://Dialogue/church_after_reveal_door_blocked.dialogue")
	for flag in ["after_reveal_reminisced_enfina", "after_reveal_reminisced_cyrus",
			"after_reveal_reminisced_prometheus", "after_reveal_reminisced_clown"]:
		Campaign.set_flag(flag)
	var line = await DialogueManager.get_next_dialogue_line(door, "start")
	ok(line != null and line.text.begins_with("To live"),
		"with all four remembered, the door gives the ending",
		line.text.substr(0, 24) if line != null else "nothing")
	Campaign.reset()
	var cold = await DialogueManager.get_next_dialogue_line(door, "start")
	ok(cold != null and not cold.text.begins_with("To live"),
		"and not before", cold.text.substr(0, 24) if cold != null else "nothing")
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
