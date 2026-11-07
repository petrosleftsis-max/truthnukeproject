extends "res://StealthHarness.gd"
## The board without its squares (CController, SoftAreas, GridOverlay) and the interface picks of 2026-11-07 (combat_ui, GateTag,
## ConditionStrip, UiScalePicker). What things look like cannot be told from here; what they decide to show can.


func suite() -> String:
	return "hudlook"


func time_limit() -> float:
	return 220.0


var game = null
var combat: Combat = null
var controller = null
var hud = null


func run_sections():
	masks()
	MoveFeel.plays_headless = true
	LightView.plays_headless = true
	await open_fight()
	await the_grid()
	await open_fight()
	await walking()
	await open_fight()
	await the_queue_and_the_log()
	await open_fight()
	await the_buttons()
	await open_fight()
	await the_marks()
	await open_fight()
	await a_wall_in_one_line()
	await open_fight()
	await the_size_of_it()
	await close_fight()
	MoveFeel.plays_headless = false
	LightView.plays_headless = false
	CombatantSprite.forget_the_light()


func open_fight():
	await close_fight()
	Campaign.reset()
	Campaign.set_party(["enfina", "cyrus", "prometheus", "alithia"], 64)
	Campaign.choose_subclass("alithia", "illusory_shepherd")
	Campaign.current_map = "res://maps/crossroads_explore.tscn"
	Campaign.return_to_position = true
	var encounter: EncounterDefinition = load("res://data/encounters/encounter_03_watcher.tres").duplicate()
	Campaign.current_encounter = encounter
	game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(6)
	combat = game.get_node("VisualCombat")
	controller = game.get_node("Controller")
	hud = combat.game_ui
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(2)
	for comb in combat.combatants:
		comb.reaction_used = true
		comb["accuracy"] = 200
		if comb.has("stats"):
			comb.hp = 900
			comb.max_hp = 900
	await settle()


func close_fight():
	if game != null and is_instance_valid(game):
		game.queue_free()
		await settle(3)
	game = null
	combat = null


func who(key: String) -> Dictionary:
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == key and not comb.get("illusion", false):
			return comb
	return {}


func foes() -> Array:
	return combat.combatants.filter(func(comb): return comb.side == 1 and comb.alive and not comb.has("object") and not comb.get("illusion", false))


func their_turn(comb: Dictionary):
	combat.current_combatant = combat.combatants.find(comb)
	comb.skill_used_this_turn = false
	comb.secondary_used_this_turn = false
	controller.set_controlled_combatant(comb)
	await settle()


func masks():
	log_line("======== soft areas ========")
	var tiles := [Vector2i(2, 3), Vector2i(3, 3)]
	var made: Dictionary = SoftAreas.mask_of(tiles, SoftAreas.Pattern.STRIPES, 8.0)
	ok(made.corner == Vector2i(1, 2), "a tile's margin all round", "%s" % made.corner)
	ok(made.size == Vector2i(4, 3), "and no bigger", "%s" % made.size)
	var image: Image = made.texture.get_image()
	ok(image.get_pixel(1, 1).a > 0.99 and image.get_pixel(2, 1).a > 0.99, "a pixel a tile, in where the tile is")
	ok(image.get_pixel(0, 0).a < 0.01 and image.get_pixel(3, 1).a < 0.01, "and out everywhere else")
	ok(is_equal_approx(snappedf(image.get_pixel(1, 1).r, 0.01), 0.25), "the pattern goes with it", "%.2f" % image.get_pixel(1, 1).r)
	ok(SoftAreas.mask_of(tiles, SoftAreas.Pattern.STRIPES, 8.0).texture == made.texture, "and it is kept, for all the redrawing")
	ok(SoftAreas.mask_of(tiles, SoftAreas.Pattern.PLAIN, 8.0).texture != made.texture, "another pattern is another mask")
	log_line("")


func the_grid():
	log_line("======== the grid ========")
	ok(controller._soft_fills != null and controller._soft_edges != null, "areas go through the soft patches")
	ok(controller._soft_fills.show_behind_parent, "under the marks")
	var grid: GridOverlay = controller._grid
	ok(grid != null and grid.fades, "the map's grid fades")
	if grid == null:
		return
	GameSettings.set_grid_always(false)
	var enfina := who("enfina")
	await their_turn(enfina)
	controller.player_turn = false
	controller._hover_tile = controller.NO_HOVER
	controller._fade_the_grid(10.0)
	ok(grid.whole < 0.01 and grid.near < 0.01, "with nothing to decide, no lines", "%.2f %.2f" % [grid.whole, grid.near])
	controller.player_turn = true
	controller._hover_tile = enfina.position
	controller._fade_the_grid(10.0)
	ok(grid.near > grid.whole and grid.near > 0.2, "moving, near the pointer", "%.2f %.2f" % [grid.whole, grid.near])
	controller.grid_pointer_at = Vector2(123, 456)
	controller._fade_the_grid(10.0)
	ok(grid.pointer == Vector2(123, 456), "which it follows")
	controller.grid_pointer_at = Vector2.INF
	controller._skill_selected = true
	controller._fade_the_grid(10.0)
	ok(grid.whole > 0.05, "aiming, faintly everywhere", "%.2f" % grid.whole)
	controller._skill_selected = false
	controller.player_turn = false
	GameSettings.set_grid_always(true)
	controller._fade_the_grid(10.0)
	ok(grid.whole > 0.2, "and for whoever likes to count, always", "%.2f" % grid.whole)
	GameSettings.set_grid_always(false)
	ok(not GameSettings.grid_always(), "kept in the settings")
	hud._build_grid_button() if hud._grid_button == null else null
	hud._grid_button.button_pressed = true
	ok(GameSettings.grid_always(), "the button beside the clock sets it")
	hud._grid_button.button_pressed = false
	log_line("")


func walking():
	log_line("======== walking on a curve ========")
	var tile := float(Grid.TILE_SIZE)
	var a := Vector2(0.0, 0.0)
	var b := Vector2(tile, 0.0)
	var c := Vector2(tile, tile)
	controller._path = PackedVector2Array([a, b, c])
	ok(controller._walk_curve(0, 0.0).distance_to(a) < 0.01, "from the first tile")
	ok(controller._walk_curve(0, 1.0).distance_to(b) < 0.01, "through the corner's tile")
	ok(controller._walk_curve(1, 1.0).distance_to(c) < 0.01, "to the last")
	var halfway: Vector2 = controller._walk_curve(0, 0.5)
	ok(absf(halfway.y) > 1.0, "not along the straight line", "%s" % halfway)
	controller._path = PackedVector2Array([a, b, b + Vector2(tile * 5.0, 0.0)])
	ok(controller._walk_curve(1, 0.5).distance_to(b + Vector2(tile * 2.5, 0.0)) < 0.01, "and a jump between floors goes straight")
	# A real walk still ends on its tile, with its steps counted.
	var enfina := who("enfina")
	await their_turn(enfina)
	controller.movement = 6
	var reach: Array = controller._walk_reach_now(enfina)
	ok(not reach.is_empty(), "how far she can walk", "%d tiles" % reach.size())
	ok(controller._walk_reach_now(enfina) == reach, "worked out once")
	var to: Vector2i = enfina.position
	for tile_there in reach:
		if combat.get_position_distance(tile_there, enfina.position) == 3 and tile_there.x != enfina.position.x and tile_there.y != enfina.position.y:
			to = tile_there
			break
	ok(to != enfina.position, "a corner to go round", "%s" % to)
	controller.find_path(to)
	var path_size: int = controller._path.size()
	controller.move_on_path(controller.tile_map.local_to_map(controller.controlled_node.position))
	for i in 400:
		if controller._arrived:
			break
		await get_tree().process_frame
	ok(controller._arrived and enfina.position == to, "and she stands on it", "%s, %d steps" % [enfina.position, path_size])
	ok(enfina.sprite.position.distance_to(controller.tile_map.map_to_local(to)) < 1.0 or enfina.sprite.position.distance_to(combat.sprite_point(enfina)) < 1.0, "exactly")
	var less: int = controller.movement
	ok(less < 6, "having paid for it", "%d" % less)
	var after: Array = controller._walk_reach_now(enfina)
	ok(after.size() < reach.size(), "with less reach for it", "%d" % after.size())
	log_line("")


func the_queue_and_the_log():
	log_line("======== the queue and the log ========")
	var enfina := who("enfina")
	var foe: Dictionary = foes()[0]
	hud._refresh_round_mark()
	ok(hud._round_mark != null and hud._round_mark.text == "Round %d" % combat.round_number, "a round marker over the queue", hud._round_mark.text)
	var faces: Array = hud._queue_faces_for(enfina)
	ok(not faces.is_empty(), "she has a face")
	controller._note_hover(enfina.position)
	ok(faces[0].is_hovered(), "the pointer on her lights it")
	controller._note_hover(foe.position)
	ok(not faces[0].is_hovered() and hud._queue_faces_for(foe)[0].is_hovered(), "and it goes when it moves on")
	var nobody: Vector2i = Vector2i(-50, -50)
	controller._note_hover(nobody)
	ok(not hud._queue_faces_for(foe)[0].is_hovered(), "on nobody, none")
	# Colours go by side, wherever the name falls.
	var line: String = hud._by_side("[color=yellow]%s[/color] is blessed by [color=red]%s[/color]'s presence.\n" % [enfina.name, who("alithia").name])
	ok(line.count("[color=yellow]") == 2 and not "[color=red]" in line, "both of the party are yellow", line.strip_edges())
	line = hud._by_side("[color=yellow]%s[/color] hits [color=red]%s[/color].\n" % [foe.name, enfina.name])
	ok(line == "[color=red]%s[/color] hits [color=yellow]%s[/color].\n" % [foe.name, enfina.name], "and the other side is red, whoever is doing what", line.strip_edges())
	ok(hud._by_side("[color=red]12[/color] damage.\n") == "[color=red]12[/color] damage.\n", "what isn't anybody stays as it was")
	log_line("")


func the_buttons():
	log_line("======== the buttons ========")
	var enfina := who("enfina")
	await their_turn(enfina)
	var grid: GridContainer = hud.get_node("Actions/ActionsPanel/ActionsGrid")
	hud.set_skill_list(["greatsword_attack", "guard"], false, false)
	var shown := grid.get_children().filter(func(slot): return slot.visible)
	ok(shown.size() == 2, "only as many slots as are full", "%d" % shown.size())
	hud.set_skill_list(["greatsword_attack", "guard", "grab"], false, false)
	shown = grid.get_children().filter(func(slot): return slot.visible)
	ok(shown.size() == 3, "and back when there are more", "%d" % shown.size())
	ok(hud._turn_block != null and hud._turn_block.get_parent() == hud.get_node("Actions"), "the turn's buttons have a block round them")
	var spells: Control = hud.get_node("Actions/SpellsToggle")
	var tabs: Control = hud.get_node("Actions/SkillPanelTabs")
	ok(is_equal_approx(spells.offset_top, tabs.offset_top), "Spells is on the tabs' line")
	# A shape for each gate, so colour isn't alone.
	var shapes := {}
	for gate in range(1, 11):
		shapes[GateTag.shape_of(gate)] = true
	ok(shapes.size() == 10, "each gate has its own shape", "%d" % shapes.size())
	# Few gates are named; many are a letter and their marks.
	var caster := who("alithia")
	caster["max_spell_slots"] = [0, 4, 3, 3]
	caster["spell_slots"] = [0, 4, 3, 3]
	hud._update_spell_slots(caster)
	await settle()
	var row: Control = hud.get_node("Actions/SpellSlots")
	var tags := row.get_children().filter(func(child): return child is GateTag)
	ok(tags.size() == 3 and tags[0]._name.text == "World", "a few gates say their names", tags[0]._name.text if not tags.is_empty() else "")
	caster["max_spell_slots"] = [0, 4, 3, 3, 3, 3, 2, 2, 1, 1, 4]
	caster["spell_slots"] = [0, 4, 3, 3, 3, 3, 2, 2, 1, 1, 4]
	hud._update_spell_slots(caster)
	await settle(3)
	tags = row.get_children().filter(func(child): return child is GateTag)
	ok(tags.size() == 10 and tags[0]._name.text == "W", "many are a letter", tags[0]._name.text if not tags.is_empty() else "")
	ok("World" in tags[0].tooltip_text, "with the name on hovering", tags[0].tooltip_text)
	ok(row.offset_right + hud.get_node("Actions").position.x <= hud.get_node("Actions").position.x + hud.get_node("Actions/Information").offset_left, "and keep clear of the log")
	ok(row.offset_bottom == hud.GATE_ROW_FOOT, "its foot stays over the tabs", "%.1f" % row.offset_bottom)
	log_line("")


func the_marks():
	log_line("======== marks ========")
	var enfina := who("enfina")
	var burn: ConditionDefinition = load("res://data/conditions/burn.tres")
	combat.put_condition(enfina, burn, 3, "test", false)
	var strip := ConditionStrip.new()
	get_tree().root.add_child(strip)
	strip.show_for(enfina, combat)
	var mark: Control = null
	for child in strip.get_children():
		if child.get_node_or_null("TurnsLeft") != null:
			mark = child
	ok(mark != null and int(mark.get_node("TurnsLeft").text) > 0, "turns left on the mark", mark.get_node("TurnsLeft").text if mark != null else "none")
	strip.mark_size = Vector2(14, 14)
	strip.show_for(enfina, combat)
	await settle()
	var small := strip.get_children().filter(func(child): return child.get_node_or_null("TurnsLeft") != null)
	ok(small.is_empty(), "none where it could not be read")
	strip.mark_size = ConditionStrip.MARK_SIZE
	var picture := PlaceholderTexture2D.new()
	burn.mark_picture = picture
	strip.show_for(enfina, combat)
	await settle()
	var pictured := strip.get_children().filter(func(child): return child is TextureRect and child.texture == picture)
	ok(pictured.size() == 1, "and a picture in the slot takes the placeholder's place")
	burn.mark_picture = null
	strip.queue_free()
	log_line("")


func a_wall_in_one_line():
	log_line("======== one line for a wall ========")
	var alithia := who("alithia")
	await their_turn(alithia)
	var lines := []
	var listen := func(line): lines.append(line)
	combat.update_information.connect(listen)
	var at: Vector2i = Combat.NO_AREA
	var way := Vector2i.RIGHT
	for gap in range(2, 8):
		for dir in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var there: Vector2i = alithia.position + dir * gap
			var clear := true
			for step in 5:
				var tile: Vector2i = there + (Vector2i(dir.y, dir.x)) * step
				if not controller.is_on_map(tile) or not combat.can_land_on(alithia, tile) or not combat.get_combatant_at(tile).is_empty():
					clear = false
			if clear and at == Combat.NO_AREA:
				at = there
				way = Vector2i(dir.y, dir.x)
	ok(at != Combat.NO_AREA, "room for it", "%s" % at)
	await combat.use_skill("phantom_wall", alithia, at, false, false, at + way * 4)
	await settle()
	var calling := lines.filter(func(line): return "calls up" in line)
	ok(calling.size() == 1, "one line as it goes up", "%s" % [calling])
	ok(calling.size() == 1 and "Phantom Wall" in calling[0] and not "Phantom Wall 1" in calling[0], "with no number on it", calling[0] if calling.size() > 0 else "")
	var pieces := combat.combatants.filter(func(comb): return comb.get("alive", false) and comb.has("one_illusion"))
	ok(pieces.size() >= 4, "for all its pieces", "%d" % pieces.size())
	lines.clear()
	combat.snap_tether(alithia, "test")
	await settle()
	var going := lines.filter(func(line): return "gone with the tether" in line)
	ok(going.size() == 1, "and one as it goes", "%s" % [going])
	combat.update_information.disconnect(listen)
	log_line("")


func the_size_of_it():
	log_line("======== the size of it ========")
	var actions: Control = hud.get_node("Actions")
	var log_panel: Control = hud.get_node("Actions/Information")
	var status: Control = hud.get_node("Status")
	var at_first: Vector2 = actions.position
	var log_first := log_panel.offset_left
	var status_first: Vector2 = status.position
	ok(is_equal_approx(GameSettings.ui_scale(), 1.0), "normal to begin with")
	var picker := UiScalePicker.new()
	get_tree().root.add_child(picker)
	await settle()
	picker.buttons[3].pressed.emit()
	await settle()
	ok(is_equal_approx(actions.scale.x, 1.3), "the biggest, at once", "%.2f" % actions.scale.x)
	var screen: Vector2 = hud.get_viewport_rect().size
	var log_right: float = actions.position.x + log_panel.offset_right * actions.scale.x
	ok(log_right <= screen.x, "the log still on the screen", "%.0f of %.0f" % [log_right, screen.x])
	var bottom: float = actions.position.y + 191.0 * actions.scale.y
	ok(bottom <= screen.y, "and the action bar", "%.0f of %.0f" % [bottom, screen.y])
	var queue: Control = hud.get_node("TurnQueue")
	ok(queue.position.x + queue.size.x * queue.scale.x <= screen.x, "and the queue")
	ok(status.position.y + status.get_combined_minimum_size().y * status.scale.y <= screen.y + 1.0, "and the portraits")
	ok("Largest" in picker.heading(), "and it says so", picker.heading())
	picker.buttons[1].pressed.emit()
	await settle()
	ok(actions.position == at_first and log_panel.offset_left == log_first and status.position == status_first, "and normal puts all of it back")
	picker.queue_free()
	GameSettings.set_ui_scale_index(1)
	log_line("")
	await moves_panel_on_a_map()


func moves_panel_on_a_map():
	log_line("======== the moves panel on a map ========")
	await close_fight()
	var m := await open_map()
	var ui = m.scene.game_ui
	ok(ui != null and ui.outside_moves != null, "the map's moves panel is there")
	if ui == null or ui.outside_moves == null:
		close_map(m)
		await settle()
		return
	var was_pad: bool = Pad.using_pad
	Pad.using_pad = false
	ui.moves_held_up = true
	ui._tuck_moves_panel(1.0)
	ok(ui.outside_moves.visible, "up when the key says")
	ui.moves_held_up = false
	ok(ui.moves_panel_wanted_here(ui.get_viewport_rect().size.y - 2.0), "or the pointer is at the bottom")
	ok(not ui.moves_panel_wanted_here(10.0), "and not with it up on the map")
	Pad.using_pad = true
	ui._tuck_moves_panel(1.0)
	ok(ui.outside_moves.visible, "and always, for a pad, which has no pointer to bring it up")
	Pad.using_pad = was_pad
	close_map(m)
	await settle()
	log_line("")
