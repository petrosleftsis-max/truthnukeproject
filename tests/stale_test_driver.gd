extends Node
## Three things the showcase turned up.

var LOG_PATH := HarnessLog.path_for("stale")
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
	get_tree().create_timer(180.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


func run_test():
	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_02_sappers.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	for i in 6:
		await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	var controller = combat.controller
	if combat.deployment_active:
		combat.finish_deployment()
		await get_tree().process_frame

	log_line("======== a route drawn for one combatant cannot move another ========")
	var first = combat.get_current_combatant()
	# Draw a route the way the cursor does, then hand the turn to someone else
	# standing somewhere else entirely.
	var target = first.position + Vector2i(2, 0)
	controller.find_path(target)
	var drawn = controller._path.size()
	ok(drawn > 0, "a route was drawn for %s" % first.name, "%d points" % drawn)

	var other = null
	for comb in combat.combatants:
		if comb != first and comb.alive and comb.position != first.position:
			other = comb
			break
	ok(other != null, "and somebody else is standing elsewhere",
		"%s at %s vs %s at %s" % [other.name if other else "?", other.position if other else "?", first.name, first.position])
	controller.set_controlled_combatant(other)
	ok(controller._path.size() == 0,
		"handing over the turn throws the old route away", "%d points left" % controller._path.size())

	# And if one ever survived, moving on it is refused rather than walked.
	controller._path = PackedVector2Array()
	controller.find_path(first.position)          # a route starting at FIRST
	controller.controlled_node = other.sprite     # while OTHER is the one acting
	var stood = other.position
	var before = other.sprite.position
	controller.move_player()
	await get_tree().process_frame
	ok(other.position == stood and other.sprite.position == before,
		"a route starting on somebody else's tile is refused", "%s -> %s" % [stood, other.position])
	log_line("")

	log_line("======== shoving strike hurts when it slams somebody ========")
	var shove: SkillDefinition = SkillDatabase.skills["shoving_strike"]
	var push = null
	for effect in shove.all_effects():
		if effect.type == EffectDefinition.EffectType.PUSH:
			push = effect
	ok(push != null, "it pushes")
	ok(push != null and push.max_amount > 0,
		"and deals collision damage when stopped", "%d-%d" % [push.min_amount, push.max_amount])
	ok(push != null and push.knockback_distance > 0,
		"over %d tiles" % (push.knockback_distance if push else 0))

	# Drive the real thing: shove somebody straight into the map edge.
	var victim = null
	for comb in combat.combatants:
		if comb.alive and comb.side == 1:
			victim = comb
	if victim != null and push != null:
		var edge = Vector2i(controller._astargrid.region.position.x, victim.position.y)
		var shover = {
			"name": "Test Shover", "position": edge + Vector2i(1, 0), "side": 0,
			"alive": true, "hp": 50, "max_hp": 50,
		}
		# Stand the victim against the wall with the shover inside them, so the
		# push has nowhere to go and has to slam.
		var was = victim.position
		victim.position = edge
		victim.sprite.position = Grid.tile_to_world(edge)
		shover.position = edge + Vector2i(1, 0)
		var hp_before = victim.hp
		combat.apply_knockback(shover, victim, push, false)
		ok(victim.hp < hp_before, "a shove into the edge of the map hurts",
			"%d -> %d" % [hp_before, victim.hp])
		victim.position = was
	log_line("")

	log_line("======== study reports what an enemy can do now ========")
	var sheet = game.get_node_or_null("CharacterSheet")
	ok(sheet != null, "the battle has a character sheet")
	if sheet != null:
		# Find an enemy carrying a skill they have not unlocked yet.
		var gated = null
		var gated_key = ""
		for comb in combat.combatants:
			if comb.side != 1 or not comb.alive:
				continue
			for key in comb.skill_list:
				var s: SkillDefinition = SkillDatabase.skills.get(key)
				if s != null and s.required_level > comb.get("level", 1):
					gated = comb
					gated_key = key
					break
			if gated != null:
				break
		if gated == null:
			log_line("  NOTE  no enemy here carries a skill above their level, so nothing to hide")
			ok(true, "which is not a failure")
		else:
			gated.studied = true
			var listed = sheet._skills_they_actually_have(gated)
			ok(not (gated_key in listed),
				"a level %d %s does not advertise '%s'" % [gated.get("level", 1), gated.name, gated_key],
				"%s" % [listed])
			ok(listed.size() < gated.skill_list.size(),
				"the list really is shorter than everything they will ever learn",
				"%d of %d" % [listed.size(), gated.skill_list.size()])
		# The player's own sheet still shows what is coming.
		for comb in combat.combatants:
			if comb.side == 0:
				ok(sheet._skills_they_actually_have(comb).size() == comb.skill_list.size(),
					"the player's own list is untouched", comb.name)
				break
	log_line("")

	log_line("======== a portrait is a portrait, however many there are ========")
	var icon_scene = load("res://ui/status_icon.tscn").instantiate()
	add_child(icon_scene)
	await get_tree().process_frame
	ok(icon_scene.custom_minimum_size.y > 0,
		"a portrait has a size of its own", "%s" % icon_scene.custom_minimum_size)
	ok(not (icon_scene.size_flags_vertical & Control.SIZE_EXPAND),
		"and does not stretch to fill the column",
		"flags=%d" % icon_scene.size_flags_vertical)
	icon_scene.queue_free()
	# And in the real HUD: one member and four members get the same height.
	var ui = game.get_node_or_null("CanvasLayer/UI")
	if ui != null and ui.has_method("show_exploration_party"):
		var one = [{"key": "cyrus", "name": "Cyrus", "icon": null, "hp": 10, "max_hp": 10, "is_leader": true}]
		var four = []
		for key in ["cyrus", "enfina", "prometheus", "alithia"]:
			four.append({"key": key, "name": key, "icon": null, "hp": 10, "max_hp": 10,
				"is_leader": key == "cyrus"})
		ui.show_exploration_party(one)
		await get_tree().process_frame
		await get_tree().process_frame
		var alone = ui.get_node("Status").get_child(0).size.y
		ui.show_exploration_party(four)
		await get_tree().process_frame
		await get_tree().process_frame
		var crowded = ui.get_node("Status").get_child(0).size.y
		ok(absf(alone - crowded) < 1.0,
			"one portrait is the same height as one of four",
			"alone %.0f, in a party of four %.0f" % [alone, crowded])
	log_line("")

	log_line("======== the combat log has room to read ========")
	if ui != null:
		var info = ui.get_node_or_null("Actions/Information")
		ok(info != null, "the log panel is there")
		if info != null:
			# It was 248 x 85, which fits about three lines.
			ok(info.size.x >= 380 and info.size.y >= 170,
				"and is big enough to read a few exchanges in",
				"%.0f x %.0f" % [info.size.x, info.size.y])
			var text = info.get_node_or_null("Text")
			ok(text != null and not text.has_theme_font_size_override("normal_font_size"),
				"with the same font size as before - only the box grew",
				"%d pt" % text.get_theme_font_size("normal_font_size"))
	log_line("")

	log_line("======== the view rides along with an enemy's turn ========")
	var cam = combat.camera
	ok(cam != null, "the battle has a camera")
	if cam != null:
		var enemy = null
		for comb in combat.combatants:
			if comb.side == 1 and comb.alive:
				enemy = comb
				break
		ok(enemy != null, "and there is an enemy to watch")
		if enemy != null:
			cam.release()
			ok(not cam.is_following(), "it starts unlocked")
			# Park the camera somewhere else entirely, then watch them.
			cam.position = enemy.sprite.global_position + Vector2(2000, 2000)
			var started = cam.position.distance_to(enemy.sprite.global_position)
			combat.watch_combatant(enemy)
			ok(cam.is_following(), "watching an enemy locks it on")
			for i in 30:
				await get_tree().process_frame
			var ended = cam.position.distance_to(enemy.sprite.global_position)
			ok(ended < started, "and it travels towards them",
				"%.0f -> %.0f away" % [started, ended])
			# Locked means locked: dragging does nothing while it is.
			var parked = cam.position
			var drag = InputEventMouseMotion.new()
			drag.relative = Vector2(300, 300)
			cam._dragging = true
			cam._unhandled_input(drag)
			ok(cam.position == parked, "and the player cannot drag it away meanwhile")
			cam._dragging = false
			combat.stop_watching()
			ok(not cam.is_following(), "and it is handed back when the turn ends")
	log_line("")

	log_line("======== shoving somebody into somebody hurts them both ========")
	var bodies := []
	for comb in combat.combatants:
		if comb.alive:
			bodies.append(comb)
	ok(bodies.size() >= 3, "there are enough people to stack up", "%d" % bodies.size())
	if bodies.size() >= 3 and push != null:
		var shover2 = bodies[0]
		var shoved = bodies[1]
		var wall_of_meat = bodies[2]
		# Three tiles in a row that all three can genuinely stand on. Forcing
		# them onto arbitrary coordinates puts somebody on terrain their
		# movement class cannot enter, and the shove then reads as hitting a
		# wall rather than hitting a person - which is a broken test, not a
		# broken rule.
		var spots := []
		var region = controller._astargrid.region
		for y in range(region.position.y, region.end.y):
			for x in range(region.position.x, region.end.x - 2):
				var run := [Vector2i(x, y), Vector2i(x + 1, y), Vector2i(x + 2, y)]
				var all_open = true
				for tile in run:
					for who in [shover2, shoved, wall_of_meat]:
						if controller.is_tile_blocking(tile, who.movement_class):
							all_open = false
					var sitting = combat.get_combatant_at(tile)
					if not sitting.is_empty() and not sitting in [shover2, shoved, wall_of_meat]:
						all_open = false
				if all_open:
					spots = run
					break
			if not spots.is_empty():
				break
		ok(not spots.is_empty(), "found a clear run of three tiles", "%s" % [spots])
		if not spots.is_empty():
			for i in 3:
				var who = [shover2, shoved, wall_of_meat][i]
				who.position = spots[i]
				who.sprite.position = Grid.tile_to_world(spots[i])
			# Measure the mechanic, not somebody's resistance table.
			shoved.resistances = {}
			wall_of_meat.resistances = {}
			var shoved_before = shoved.hp
			var bumped_before = wall_of_meat.hp
			var stood_at = shoved.position
			combat.apply_knockback(shover2, shoved, push, false)
			ok(shoved.hp < shoved_before, "the one shoved takes it",
				"%s %d -> %d" % [shoved.name, shoved_before, shoved.hp])
			ok(wall_of_meat.hp < bumped_before, "and so does the one they hit",
				"%s %d -> %d" % [wall_of_meat.name, bumped_before, wall_of_meat.hp])
			ok(shoved.position == stood_at,
				"and nobody moved through anybody", "%s" % shoved.position)
	log_line("")
	log_line("======== passing the lead mid-stride keeps everyone walking ========")
	game.queue_free()
	await get_tree().process_frame
	Campaign.reset()
	Campaign.current_map = "res://scenes/laboratory_terrain_explore.tscn"
	var scene = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(scene)
	for i in 4:
		await get_tree().process_frame
	var party = scene.party
	ok(party != null and party.leader != null, "the line is on the map")
	# Hold a key down, the way a player walking west does, and let the line get
	# under way. Faked through Input so _process reads it exactly as it would
	# from a real keyboard - setting _walking by hand would be undone on the
	# very next frame, which is the whole reason this bug was invisible.
	var held = InputEventKey.new()
	held.physical_keycode = KEY_A
	held.pressed = true
	Input.parse_input_event(held)
	for i in 4:
		await get_tree().process_frame
	ok(party._walking, "the line is walking with A held")
	var animation_of = func(sprite):
		return sprite._animated.animation if sprite._animated != null else ""
	ok(animation_of.call(party.leader) == "walk", "the leader is in their walk",
		animation_of.call(party.leader))

	# Pass the lead WITHOUT letting go of the key - which is what Tab does
	# mid-walk, and where the line used to go idle.
	Campaign.cycle_leader()
	await get_tree().process_frame
	await get_tree().process_frame
	ok(party.leader != null, "there is still a leader after the swap")
	ok(party._walking, "and the line still believes it is walking")
	ok(animation_of.call(party.leader) == "walk",
		"the new leader is walking, not sliding along idle", animation_of.call(party.leader))
	for follower in party.followers:
		ok(animation_of.call(follower) == "walk",
			"and so is everyone behind them", animation_of.call(follower))
	ok(party._facing_left, "the line still knows which way it faces")
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
