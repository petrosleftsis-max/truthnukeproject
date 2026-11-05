extends "res://StealthHarness.gd"
## How a fight looks and what it shows (the designer, 2026-11-04): the view eased
## onto whoever's turn it is; a blow - whoever strikes, where it goes, what flies -
## kept in view and the view going back; what flies leaning the view; those who
## arrive late seen coming one at a time; a moment before End Turn; a blink's
## tile lit under the pointer; a blow's blast shown; Interact as Cyrus's secondary.


func suite() -> String:
	return "combatview"


func time_limit() -> float:
	return 180.0


func run_sections():
	CameraController.moves_headless = true
	Campaign.reset()
	Campaign.set_party(["enfina", "cyrus"], 8)
	Campaign.current_encounter = load("res://data/encounters/encounter_01_ambush.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(3)
	var combat: Combat = game.get_node("VisualCombat")
	combat.finish_deployment()
	await settle(3)
	var hero: Dictionary = {}
	var foe: Dictionary = {}
	for comb in combat.combatants:
		if comb.side == 0 and hero.is_empty() and comb.get("combatant_key", "") == "enfina":
			hero = comb
		elif comb.side == 1 and foe.is_empty():
			foe = comb
	ok(not hero.is_empty() and not foe.is_empty(), "a fight, with Enfina in it and somebody to hit")
	if hero.is_empty() or foe.is_empty():
		CameraController.moves_headless = false
		return
	# Nobody's turn gets in the way of looking at it all.
	combat.camera.release()
	await a_turn(combat, hero, foe)
	await a_blow(combat, hero, foe)
	await what_flies(combat, hero, foe)
	await coming_late(combat, foe)
	await end_turn_held(combat, hero)
	await the_board(combat, hero, foe)
	interact_as_secondary(combat)
	CameraController.moves_headless = false
	game.queue_free()
	await settle(2)


func settled(camera: CameraController) -> bool:
	return await until(func(): return not camera.is_gliding(), 5.0)


func a_turn(combat: Combat, hero: Dictionary, foe: Dictionary):
	log_line("======== a turn begins ========")
	var camera: CameraController = combat.camera
	var there: Vector2 = combat.sprite_point(hero) + combat.drawing_offset(hero)
	camera.position = there + Vector2(Grid.tiles(6.0), Grid.tiles(3.0))
	camera.clamp_to_map()
	var from := camera.position
	combat._glide_to_turn(hero)
	ok(camera.is_gliding() and camera.position == from, "one of the party's: the view sets off for them - no cut")
	await settle(3)
	ok(camera.position.distance_to(from) > 0.0 and camera.position.distance_to(there) > Grid.tiles(0.5), "  easing there", "%s" % camera.position)
	await settled(camera)
	var map_rect := camera.get_map_rect()
	ok(camera.position.distance_to(there.clamp(map_rect.position, map_rect.end)) < 4.0, "  and arrives", "%s, they %s" % [camera.position, there])
	combat._glide_to_turn(foe)
	ok(not camera.is_gliding(), "the other side's: not this")
	# The player's hand takes it back.
	camera.glide_to(there + Vector2(Grid.tiles(4.0), 0.0))
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	camera._unhandled_input(wheel)
	ok(not camera.is_gliding(), "the wheel turned meanwhile: the view is the player's")
	log_line("")


## Whether `world` is in the part of the screen the HUD leaves the map.
func in_room(camera: CameraController, room: Rect2, world: Vector2) -> bool:
	var screen: Vector2 = (world - camera.position) * camera.zoom.x + camera.get_viewport_rect().size * 0.5
	return room.grow(2.0).has_point(screen)


func a_blow(combat: Combat, hero: Dictionary, foe: Dictionary):
	log_line("======== a blow in view ========")
	var camera: CameraController = combat.camera
	var skill: SkillDefinition = SkillDatabase.skills["greatsword_attack"]
	var room: Rect2 = combat.game_ui.map_view_rect()
	var mine: Vector2 = combat.sprite_point(hero) + combat.drawing_offset(hero)
	var theirs: Vector2 = Grid.tile_to_world(foe.position)
	# Close in on somebody else altogether, so neither is in view.
	camera.zoom = Vector2.ONE * camera.max_zoom
	camera.position = (mine + theirs) * 0.5 + (mine - theirs).orthogonal().normalized() * Grid.tiles(10.0)
	camera.clamp_to_map()
	var was := camera.position
	var was_zoom := camera.zoom.x
	await combat._frame_the_blow(hero, skill, foe.position)
	await settled(camera)
	ok(in_room(camera, room, mine) and in_room(camera, room, theirs), "whoever strikes and where it goes, both in the part of the screen the HUD leaves",
		"zoom %.2f at %s" % [camera.zoom.x, camera.position])
	ok(camera.zoom.x <= was_zoom, "  pulled back as far as it had to", "%.2f -> %.2f" % [was_zoom, camera.zoom.x])
	combat._end_the_frame()
	await until(func(): return not camera._framing and not camera.is_gliding(), 5.0)
	ok(camera.position.distance_to(was) < 4.0 and absf(camera.zoom.x - was_zoom) < 0.01, "and once it is over, back where it was", "%s %.2f" % [camera.position, camera.zoom.x])
	# All there already: nothing moves.
	camera.zoom = Vector2.ONE * camera.min_zoom
	camera.position = (mine + theirs) * 0.5
	var still := camera.position
	await combat._frame_the_blow(hero, skill, foe.position)
	ok(not camera.is_gliding() and camera.position == still, "with everything in view already, it stays where it is")
	combat._end_the_frame()
	await until(func(): return not camera._framing, 3.0)
	log_line("")


func what_flies(combat: Combat, hero: Dictionary, foe: Dictionary):
	log_line("======== the view goes with what flies ========")
	var camera: CameraController = combat.camera
	camera.lean_after(camera.position + Vector2(Grid.tiles(20.0), 0.0), 0.5)
	await settle(10)
	ok(camera.offset.x > 0.0, "it leans after it", "%s" % camera.offset)
	ok(camera._lean_aim.length() * camera.zoom.x <= CameraController.LEAN_MOST_PIXELS + 0.01, "  a slight lean, however far it is", "%.1f px" % (camera._lean_aim.length() * camera.zoom.x))
	camera.lean_off()
	await until(func(): return camera.offset == Vector2.ZERO, 3.0)
	ok(camera.offset == Vector2.ZERO, "  and comes back to the middle")
	camera.kick(Vector2.RIGHT, 20.0)
	await settle(1)
	ok(camera.offset.x > 0.0, "landing, a shove the way it went")
	await until(func(): return camera.offset == Vector2.ZERO, 3.0)
	ok(camera.offset == Vector2.ZERO, "  which comes back by itself")
	# A real one, flown: leaning while it flies, off once it has landed.
	Projectile.plays_headless = true
	var skill: SkillDefinition = SkillDatabase.skills["fire_blast"]
	var leaned := [false]
	var watching := func():
		if camera._lean_aim != Vector2.ZERO:
			leaned[0] = true
	get_tree().process_frame.connect(watching)
	await Projectile.fly(combat, hero, skill, foe.position, [], foe)
	get_tree().process_frame.disconnect(watching)
	Projectile.settle()
	await settle(30)
	Projectile.plays_headless = false
	ok(leaned[0], "a real bolt, flown: the view leans after it")
	ok(camera._lean_aim == Vector2.ZERO, "  and not once it has landed")
	ok(Projectile.LEAN_SHARES.has(SkillDefinition.ProjectileStyle.ARC) and Projectile.LEAN_SHARES[SkillDefinition.ProjectileStyle.ARC] != Projectile.LEAN_SHARE_BOLT,
		"  each way of going by its own share")
	log_line("")


func coming_late(combat: Combat, foe: Dictionary):
	log_line("======== those who come late ========")
	var camera: CameraController = combat.camera
	var there: Vector2 = combat.sprite_point(foe) + combat.drawing_offset(foe)
	camera.position = there + Vector2(Grid.tiles(8.0), 0.0)
	camera.clamp_to_map()
	combat._keep_for_showing(foe)
	ok(foe.sprite.modulate.a == 0.0 and combat._to_show_coming.has(foe), "come, but not seen yet")
	var seen := [false]
	var on_them := func():
		if camera.position.distance_to(there) < Grid.tiles(1.0) and foe.sprite.modulate.a < 1.0:
			seen[0] = true
	get_tree().process_frame.connect(on_them)
	await combat._show_arrivals()
	get_tree().process_frame.disconnect(on_them)
	ok(seen[0], "the view on them before they come in")
	ok(is_equal_approx(foe.sprite.modulate.a, 1.0) and combat._to_show_coming.is_empty(), "  and there they are", "%.2f" % foe.sprite.modulate.a)
	ok(not combat.controller.action_locked, "  the board let go again")
	await settled(camera)
	log_line("")


func end_turn_held(combat: Combat, hero: Dictionary):
	log_line("======== a moment before End Turn ========")
	var ui = combat.game_ui
	var button: Button = ui.get_node("Actions/EndTurnButton")
	ui._hold_end_turn(hero)
	ok(not ui.end_turn_held(), "with nobody to see it, it holds nothing: the suites play on")
	var turn: int = combat.current_combatant
	combat.controller.player_turn = true
	ui.holds_headless = true
	ui._hold_end_turn(hero)
	ok(ui.end_turn_held(), "a turn of the party's: held")
	ui._process(0.01)
	ok(button.disabled and button.text.contains("(%d)" % ceili(ui.END_TURN_HOLD_SECONDS)), "  greyed, counting down", button.text)
	ui._on_end_turn_button_pressed()
	ok(combat.current_combatant == turn, "  and pressing it ends nothing")
	ui._process(ui.END_TURN_HOLD_SECONDS)
	ok(not ui.end_turn_held() and not button.text.contains("("), "the moment over: End Turn again", button.text)
	ui.holds_headless = false
	log_line("")


func the_board(combat: Combat, hero: Dictionary, foe: Dictionary):
	log_line("======== what the board shows ========")
	var controller: CController = combat.controller
	var ui = combat.game_ui
	var greatsword: SkillDefinition = SkillDatabase.skills["greatsword_attack"]
	# A blow that spreads from whoever it lands on: Titanfall, at 64.
	var level: int = hero.level
	ok(combat.splash_reach_of(hero, greatsword) == 0, "Enfina's blow at level %d spreads from nobody" % level)
	hero.level = 64
	ok(combat.splash_reach_of(hero, greatsword) == 2, "at 64 it is Titanfall: two tiles round whoever it lands on", "%d" % combat.splash_reach_of(hero, greatsword))
	var blast: Array = combat.splash_tiles_of(hero, greatsword, foe)
	ok(blast.has(foe.position + Vector2i(2, 0)) or blast.has(foe.position + Vector2i(-2, 0)) or blast.has(foe.position + Vector2i(0, 2)),
		"  and so many tiles are what aiming shows", "%d tiles" % blast.size())
	ok(not blast.has(foe.position + Vector2i(3, 0)), "  no further")
	controller._preview_blast(hero, greatsword, foe)
	ok(controller._aoe_preview_positions == blast and not controller._aoe_preview_is_ally, "  shown as a blast")
	controller._aoe_preview_positions = []
	ok(ui.build_skill_tooltip(greatsword, hero).contains("Blast: Radius 2"), "  and said on its tooltip")
	hero.level = level
	# A blink's landing tile, lit under the pointer.
	combat.current_combatant = combat.combatants.find(hero)
	controller.set_controlled_combatant(hero)
	controller._selected_skill = "mist_step"
	controller.begin_target_selection()
	var tile = null
	for each in controller._range_preview_positions:
		if controller.refusal_at(each, {}) == "":
			tile = each
			break
	ok(tile != null, "Mist Step has somewhere to land")
	if tile != null:
		controller._fresh_view()
		Pad.using_pad = true
		Pad._point = controller._screen_of_tile(tile)
		var motion := InputEventMouseMotion.new()
		controller._unhandled_input(motion)
		Pad.using_pad = false
		ok(controller._ally_target_position == controller.tile_map.map_to_local(tile), "  the tile under the pointer lights up", "%s" % [controller._ally_target_position])
	controller.cancel_skill_selection()
	log_line("")


func interact_as_secondary(combat: Combat):
	log_line("======== Interact, as Cyrus's secondary ========")
	var cyrus: Dictionary = {}
	var enfina: Dictionary = {}
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == "cyrus":
			cyrus = comb
		elif comb.get("combatant_key", "") == "enfina":
			enfina = comb
	ok(not cyrus.is_empty(), "Cyrus is in the fight")
	if cyrus.is_empty():
		return
	ok(not combat.secondary_skills_of(cyrus).has("use"), "with nothing on the map to use, it is not on his panel")
	cyrus.skill_list.append("use")
	enfina.skill_list.append("use")
	ok(combat.secondary_skills_of(cyrus).has("use"), "with something: Quick Hands has it as a secondary action")
	ok(combat.main_skills_of(cyrus).has("use"), "  and as a main one, as ever")
	ok(not combat.secondary_skills_of(enfina).has("use"), "  and it is his: Enfina's is a main action only")
	log_line("")
