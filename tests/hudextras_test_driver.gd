extends Node
## The HUD's second pass: the two typefaces, End Turn in the accent, names under
## the portraits, the turn banner, the main/secondary marks, keys 1-9 and Tab,
## badges on shared icons and letters on condition marks, health bars that
## drain and show an aimed hit's damage, the turn queue's faces saying who they
## are and finding them on the map, and the card for whoever is under the
## cursor - none of which may give away anybody hidden.

var LOG_PATH := HarnessLog.path_for("hudextras")

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
	get_tree().create_timer(150.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


func press(code: Key):
	for down in [true, false]:
		var key := InputEventKey.new()
		key.keycode = code
		key.physical_keycode = code
		key.pressed = down
		Input.parse_input_event(key)
		await get_tree().process_frame
	await get_tree().process_frame


func click() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


## The first damaging skill on `comb`'s main panel, or "".
func a_strike(combat: Combat, comb: Dictionary) -> String:
	for key in combat.main_skills_of(comb):
		var skill: SkillDefinition = SkillDatabase.skills[key]
		if skill.deals_damage and not skill.targets_ally and skill.aoe_radius == 0:
			return key
	return ""


func run_test():
	log_line("======== the typefaces ========")
	var theme := ThemeDB.get_project_theme()
	ok(theme != null and theme.default_font != null and theme.default_font.resource_path == GameFonts.BODY,
		"everything is set in Alegreya Sans", theme.default_font.resource_path if theme != null and theme.default_font != null else "none")
	ok(theme.get_type_variation_base(GameFonts.HEADER) == &"Label", "headings are a kind of Label")
	var display = GameFonts.display_font()
	ok(display != null and theme.get_font(&"font", GameFonts.HEADER) == display, "set in Cinzel")
	var heading := Label.new()
	heading.theme_type_variation = GameFonts.HEADER
	add_child(heading)
	ok(heading.get_theme_font(&"font") == display, "which a heading actually draws with")
	var plain := Label.new()
	add_child(plain)
	ok(plain.get_theme_font(&"font") == theme.default_font, "while an ordinary label does not")
	heading.queue_free()
	plain.queue_free()
	var balloon = load("res://ui/dialogue_balloon.tscn").instantiate()
	add_child(balloon)
	await get_tree().process_frame
	ok(balloon.character_label.get_theme_font(&"normal_font") == display, "the speaker's name in dialogue too")
	balloon.queue_free()
	log_line("")

	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_02_sappers.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	# What starting a battle does: the title screen goes. Run from an export,
	# the game starts on it, and left behind its Play button kept the keyboard
	# - Tab moved focus between menu buttons nobody could see.
	var title_screen = get_tree().root.get_node_or_null("MainMenu")
	if title_screen != null:
		title_screen.queue_free()
	for i in 4:
		await get_tree().process_frame
	var combat: Combat = game.get_node("VisualCombat")
	var controller = game.get_node("Controller")
	var ui = game.get_node("CanvasLayer/UI")
	for title in ["PauseUI/PausePanel/VBox/Title", "PauseUI/OptionsPanel/VBox/Title"]:
		ok(game.get_node(title).theme_type_variation == GameFonts.HEADER, "%s is a heading" % title)

	log_line("======== while placing the party ========")
	ok(ui._turn_banner.showing() == "", "no turn is announced before there is one")
	combat.finish_deployment()
	await get_tree().process_frame
	var hero = combat.get_current_combatant()
	ok(hero.side == 0, "the party goes first here", hero.name)
	ok(ui._turn_banner.showing() == "%s's Turn" % hero.name, "and the banner says whose turn it is", ui._turn_banner.showing())
	var banner_box = Rect2(ui._turn_banner.global_position, ui._turn_banner.size)
	ok(Rect2(Vector2.ZERO, ui.get_viewport_rect().size).encloses(banner_box), "on the screen", "%s" % banner_box)
	await get_tree().create_timer(TurnBanner.FADE_IN + TurnBanner.HOLD + TurnBanner.FADE_OUT + 0.3).timeout
	ok(ui._turn_banner.showing() == "", "then goes")
	log_line("")

	log_line("======== the buttons ========")
	var end_turn: Button = ui.get_node("Actions/EndTurnButton")
	var box = end_turn.get_theme_stylebox("normal") as StyleBoxFlat
	ok(box != null and box.bg_color == Color("2d5a8c"), "End Turn is the accent button", "%s" % (box.bg_color if box != null else "none"))
	var undo: Button = ui.get_node("Actions/UndoMoveButton")
	ok(not undo.has_theme_stylebox_override("normal") and not undo.has_theme_color_override("font_color"),
		"Undo Move wears the theme's own look rather than End Turn's")
	ok(end_turn.tooltip_text.contains("1-9") and end_turn.tooltip_text.contains("Shift"), "End Turn's tooltip lists the keys")
	log_line("")

	log_line("======== names under the faces ========")
	var names_ok = true
	var column = ui.get_node("Status")
	for comb in combat.combatants:
		if comb.side != 0:
			continue
		var portrait = ui._icon_for(column, comb)
		if portrait == null or portrait.get_node("Layout/Name").text != comb.name or not portrait.get_node("Layout/Name").visible:
			names_ok = false
	ok(names_ok, "every portrait in the party column is named")
	var big = ui.get_node("Actions/StatusIcon")
	ok(big.get_node("Layout/Name").text == hero.name, "and the big one says who is acting", big.get_node("Layout/Name").text)
	ok(ui.get_node("Actions/Movement").text.begins_with("Move "), "the movement counter says what it counts",
		ui.get_node("Actions/Movement").text)
	log_line("")

	log_line("======== keys ========")
	var grid = ui.get_node("Actions/ActionsPanel/ActionsGrid").get_children()
	var marks_ok = true
	for i in mini(grid.size(), 9):
		var mark = grid[i].get_node_or_null(ui.HOTKEY_MARK)
		if mark == null or mark.text != str(i + 1) or mark.visible != (grid[i].icon != null):
			marks_ok = false
	ok(marks_ok, "each filled slot shows the number that picks it, and no empty one does")
	ok(grid[0].icon != null, "there is something in the first slot")
	await press(KEY_1)
	ok(controller.is_skill_selected(), "1 picks it")
	await press(KEY_TAB)
	ok(ui.showing_panel == ui.SkillPanel.MAIN, "Tab does nothing mid-aim")
	controller.cancel_skill_selection()
	await get_tree().process_frame
	var empty_slot = -1
	for i in range(mini(grid.size(), 9) - 1, -1, -1):
		if grid[i].icon == null:
			empty_slot = i
	if empty_slot >= 0:
		await press(KEY_1 + empty_slot)
		ok(not controller.is_skill_selected(), "an empty slot's number picks nothing", "%d" % (empty_slot + 1))
	var from = ui.showing_panel
	await press(KEY_TAB)
	ok(ui.showing_panel != from, "Tab moves to the next tab", "%s -> %s" % [from, ui.showing_panel])
	for i in 3:
		if ui.showing_panel == from:
			break
		await press(KEY_TAB)
	ok(ui.showing_panel == from, "and comes round again")
	log_line("")

	log_line("======== the actions left ========")
	ok(ui._pips.visible, "the marks are up on a party turn")
	ok(ui._pips.state() == [true, true], "both actions there to spend", "%s" % [ui._pips.state()])
	var mark = {}
	for comb in combat.combatants:
		if comb.side == 1 and comb.alive and mark.is_empty():
			mark = comb
	for comb in combat.combatants:
		comb.reaction_used = true
	mark.hp = 900
	mark.max_hp = 999
	var strike = a_strike(combat, hero)
	ok(strike != "", "the one acting has something to swing", strike)
	var skill: SkillDefinition = SkillDatabase.skills.get(strike)
	var near = Vector2i(-99999, -99999)
	for tile in controller.get_reachable_tiles(hero.position, hero.movement_class, 99):
		if near.x > -99999:
			break
		var gap = combat.get_position_distance(hero.position, tile)
		if gap >= maxi(skill.min_range, 1) and gap <= combat.effective_max_range(hero, skill) \
				and combat.get_combatant_at(tile).is_empty() \
				and combat.targets_if_aimed(hero, skill, tile).size() == 0:
			combat.teleport_to(mark, tile)
			if combat.targets_if_aimed(hero, skill, mark.position).has(mark):
				near = tile
	ok(near.x > -99999, "somewhere the target can be struck from where the hero stands", "%s" % near)
	combat.update_combatants.emit(combat.combatants)
	await get_tree().process_frame

	log_line("======== the hit, on the health bars ========")
	var queue = ui.get_node("TurnQueue/Queue")
	var face = ui._icon_for(queue, mark)
	ok(face != null, "the target has a face in the queue")
	controller.set_selected_skill(strike)
	controller.begin_target_selection()
	controller._preview_hits(mark.position)
	var said = combat.predict_hit(hero, mark, skill)
	var ghost = face.get_node("Health").get_node_or_null("Preview")
	ok(ghost != null, "aiming at them marks what it would take off their bar", "%d damage" % said.damage)
	if ghost != null:
		var bar = face.get_node("Health")
		var expected = bar.size.x * float(said.damage) / float(face.max_hp)
		ok(absf(ghost.size.x - maxf(expected, 1.0)) < 1.5, "as much of it as the damage is", "%.1f vs %.1f" % [ghost.size.x, expected])
	ok(not ui._unit_card.visible, "the hover card keeps out of the way while aiming")
	controller._preview_hits(hero.position + Vector2i(99, 0))
	ok(face.get_node("Health").get_node_or_null("Preview") == null, "aimed somewhere else, the mark goes")
	controller._preview_hits(mark.position)
	controller.cancel_skill_selection()
	await get_tree().process_frame
	ok(face.get_node("Health").get_node_or_null("Preview") == null, "and putting the skill away clears it")
	if combat.spell_skills_of(hero).is_empty():
		ok(not ui._spells_toggle().visible, "the HUD comes back without a Spells button for somebody who casts nothing")
	else:
		ok(ui._spells_toggle().visible, "the HUD comes back with Spells for somebody who casts")
	log_line("")

	log_line("======== health that drains ========")
	var portrait = ui._icon_for(column, hero)
	portrait.set_health(hero.hp, combat.get_effective_stat(hero, "max_hp"))
	portrait.set_health(maxi(hero.hp - 5, 1), combat.get_effective_stat(hero, "max_hp"))
	ok(portrait.get_node("Layout/Health").get_node_or_null("Drain") != null, "a portrait's lost health lingers a moment")
	face.set_hp(mark.hp - 50)
	ok(face.get_node("Health").get_node_or_null("Drain") != null, "and a queue face's")
	await get_tree().create_timer(HealthBarMarks.DRAIN_HOLD + HealthBarMarks.DRAIN_TIME + 0.3).timeout
	ok(portrait.get_node("Layout/Health").get_node_or_null("Drain") == null
		and face.get_node("Health").get_node_or_null("Drain") == null, "then drains away")
	portrait.set_health(hero.hp, combat.get_effective_stat(hero, "max_hp"))
	face.set_hp(mark.hp)
	await get_tree().process_frame
	ok(portrait.get_node("Layout/Health").get_node_or_null("Drain") == null, "health coming back does not drain")
	log_line("")

	log_line("======== the swing itself ========")
	await combat.use_skill(strike, hero, mark.position, false)
	await get_tree().process_frame
	ok(ui._pips.state() == [false, true], "once used, the main action reads as spent", "%s" % [ui._pips.state()])
	log_line("")

	log_line("======== the turn queue's faces ========")
	face = ui._icon_for(queue, mark)
	var most = combat.get_effective_stat(mark, "max_hp")
	ok(face.tooltip_text.contains(mark.name) and face.tooltip_text.contains("%d / %d HP" % [mark.hp, most]),
		"hovering a face says who and how they are", face.tooltip_text.replace("\n", " | "))
	face.mouse_entered.emit()
	ok(controller._highlight_tile == mark.position, "and rings them on the map")
	ok(face.is_hovered() and face.get_node("Border").modulate == face.HOVER_EDGE, "while the face itself lights up in the same gold")
	face.mouse_exited.emit()
	ok(controller._highlight_tile == null, "until the cursor leaves")
	ok(not face.is_hovered() and face.get_node("Border").modulate != face.HOVER_EDGE, "and the face goes back to its side's colour")
	face.set_turn_taken(true)
	var faded = face.modulate.a
	face.mouse_entered.emit()
	ok(faded < 1.0 and face.modulate.a == 1.0, "one who has already acted is at full strength while pointed at",
		"%.2f -> %.2f" % [faded, face.modulate.a])
	face.mouse_exited.emit()
	ok(face.modulate.a == faded, "and fades back after")
	face.set_turn_taken(false)
	var party_face = ui._icon_for(column, hero)
	party_face.mouse_entered.emit()
	var lit_box = party_face.get_theme_stylebox("panel") as StyleBoxFlat
	ok(party_face.is_lit() and lit_box != null and lit_box.border_color == party_face.HOVER_EDGE,
		"a party portrait lights up in gold when pointed at")
	party_face.mouse_exited.emit()
	ok(not party_face.is_lit(), "and goes back when the cursor leaves")
	var acting_portrait = ui.get_node("Actions/StatusIcon")
	acting_portrait.mouse_entered.emit()
	ok(not acting_portrait.is_lit(), "the big portrait beside the skills does not - it is not a button")
	acting_portrait.mouse_exited.emit()
	var camera = combat.camera
	ok(not camera.is_following(), "the view is the player's to move on their turn")
	camera.position = Grid.tile_to_world(hero.position)
	ui._on_queue_input(click(), mark)
	ok(camera.position.distance_to(Grid.tile_to_world(mark.position)) < 1.0, "clicking a face takes the view to them",
		"%s vs %s" % [camera.position, Grid.tile_to_world(mark.position)])
	controller._card_for(mark)
	ok(ui._unit_card.visible and ui._unit_card.shown_id == mark.id, "hovering them on the map shows their card")
	var card_text = ""
	for label in ui._unit_card.find_children("*", "Label", true, false):
		card_text += label.text + " | "
	ok(card_text.contains(mark.name) and card_text.contains("%d / %d HP" % [mark.hp, most]), "naming them and their health", card_text)
	var screen = ui.get_viewport_rect().size
	var card_box = Rect2(ui._unit_card.global_position, ui._unit_card.get_combined_minimum_size())
	ok(Rect2(Vector2.ZERO, screen).encloses(card_box), "on the screen", "%s" % card_box)
	controller._card_for(null)
	ok(not ui._unit_card.visible, "and off it with nobody under the cursor")
	log_line("")

	log_line("======== somebody hidden stays hidden ========")
	combat.set_hidden(mark, true)
	await get_tree().process_frame
	face = ui._icon_for(queue, mark)
	if face != null:
		ok(face.tooltip_text.contains("Hidden") and not face.tooltip_text.contains("HP"), "their face says only that they are hidden",
			face.tooltip_text.replace("\n", " | "))
		face.mouse_entered.emit()
		ok(controller._highlight_tile == null, "and rings nothing on the map")
		face.mouse_exited.emit()
	camera.position = Grid.tile_to_world(hero.position)
	var parked = camera.position
	ui._on_queue_input(click(), mark)
	ok(camera.position == parked, "clicking them takes the view nowhere")
	controller._card_for(mark)
	ok(not ui._unit_card.visible, "and no card is shown for the tile they stand on")
	hero.skill_used_this_turn = false
	controller.set_selected_skill(strike)
	controller.begin_target_selection()
	controller._preview_hits(mark.position)
	if face != null:
		ok(face.get_node("Health").get_node_or_null("Preview") == null, "aiming at where they stand marks nothing on their bar")
	controller.cancel_skill_selection()
	await get_tree().process_frame
	combat.set_hidden(mark, false)
	log_line("")

	log_line("======== shared icons ========")
	var uses := {}
	for key in SkillDatabase.skills:
		var some: SkillDefinition = SkillDatabase.skills[key]
		if some != null and some.icon != null:
			uses[some.icon] = uses.get(some.icon, []) + [some]
	var shared_one: SkillDefinition = null
	var own_one: SkillDefinition = null
	for icon in uses:
		for some in uses[icon]:
			if uses[icon].size() > 1 and shared_one == null and SkillLook.tint(some) != Color.WHITE:
				shared_one = some
			if uses[icon].size() == 1 and own_one == null:
				own_one = some
	ok(shared_one != null and SkillLook.is_shared(shared_one), "a picture used twice is known to be shared",
		shared_one.name if shared_one != null else "none")
	if own_one != null:
		ok(not SkillLook.is_shared(own_one), "one used once is not", own_one.name)
	ok(SkillLook.initials("Fire Blast") == "FB" and SkillLook.initials("Rapier") == "Ra", "initials from the name")
	var water_like = SkillLook.tint(shared_one)
	ok(water_like != Color.WHITE, "a shared elemental icon takes a tint", "%s" % water_like)
	var button := Button.new()
	add_child(button)
	SkillLook.decorate(button, shared_one)
	var badge = button.get_node_or_null(SkillLook.BADGE)
	ok(badge != null and badge.visible and badge.text == SkillLook.initials(shared_one.name), "and a badge with its initials",
		badge.text if badge != null else "none")
	ok(button.has_theme_color_override("icon_normal_color"), "the icon on the button is tinted")
	SkillLook.decorate(button, null)
	ok(not badge.visible and not button.has_theme_color_override("icon_normal_color"), "and both come off an empty slot")
	button.queue_free()
	ui.set_skill_panel(ui.SkillPanel.MAIN)
	if ui.showing_spells:
		ui.toggle_spells()
	var badged_right = true
	var list = combat.main_skills_of(hero)
	for i in mini(grid.size(), list.size()):
		var on_it = grid[i].get_node_or_null(SkillLook.BADGE)
		var should = SkillLook.is_shared(SkillDatabase.skills[list[i]])
		if (on_it != null and on_it.visible) != should:
			badged_right = false
	ok(badged_right and not list.is_empty(), "the action panel badges exactly its shared icons", "%s" % [list])
	log_line("")

	log_line("======== letters on condition marks ========")
	var strip := ConditionStrip.new()
	add_child(strip)
	var burn: ConditionDefinition = load("res://conditions/burn.tres")
	hero.status_effects.append({"stat": "condition", "condition": burn, "duration": 2, "dot_base": 3.0})
	strip.show_for(hero, combat)
	var letters := []
	for child in strip.get_children():
		var on_it = child.get_node_or_null(SkillLook.BADGE)
		letters.append(on_it.text if on_it != null else "")
	var burn_tag := ConditionStrip.tag_for(burn.display_name)
	ok(burn_tag == "Bu", "tags are the first two letters of the name", burn_tag)
	ok(ConditionStrip.tag_for("Blind") == "Bl" and ConditionStrip.tag_for("Fear") != ConditionStrip.tag_for("Frozen"),
		"so Burn and Blind, Fear and Frozen, no longer share one")
	ok(letters.has(burn_tag), "a burn's mark carries Bu", "%s" % [letters])
	# Every condition there is, so a new one that would share a tag with an old
	# one is noticed when it is added rather than on the battlefield.
	var tagged := {}
	var clashes := []
	for file in DirAccess.get_files_at("res://conditions"):
		# An export renames every .tres to .tres.remap; load() takes the plain name.
		var listed: String = file.trim_suffix(".remap")
		if not listed.ends_with(".tres"):
			continue
		var condition = load("res://conditions/" + listed)
		if not condition is ConditionDefinition:
			continue
		var tag = ConditionStrip.tag_for(condition.display_name)
		if tagged.has(tag):
			clashes.append("%s and %s are both %s" % [tagged[tag], condition.display_name, tag])
		tagged[tag] = condition.display_name
	ok(tagged.size() > 5 and clashes.is_empty(), "every condition's mark says something different",
		"%s" % [clashes if not clashes.is_empty() else tagged.keys()])
	var burning_mark = strip.get_child(letters.find(burn_tag))
	ok(burning_mark.self_modulate == ConditionStrip.HARMFUL and burning_mark.modulate == Color.WHITE,
		"tinted as harmful, with the letter left white")
	hero.status_effects.pop_back()
	strip.queue_free()
	log_line("")

	log_line("======== a lot of conditions stay with their own face ========")
	var piled := 7
	for who in [hero, mark]:
		for i in piled:
			who.status_effects.append({"stat": "condition", "condition": burn, "duration": 2, "dot_base": 3.0})
	combat.update_combatants.emit(combat.combatants)
	await get_tree().process_frame
	await get_tree().process_frame
	for who in [hero, mark]:
		var their_face: Control = ui._icon_for(queue, who)
		var marks_strip = their_face.get_node_or_null("Conditions")
		ok(marks_strip != null and marks_strip.get_child_count() == piled, "%s's face in the queue carries all %d" % [who.name, piled],
			"%d" % (marks_strip.get_child_count() if marks_strip != null else -1))
		if marks_strip == null:
			continue
		var face_box: Rect2 = their_face.get_global_rect()
		var inside = true
		var below = true
		var rows := {}
		for child in marks_strip.get_children():
			var mark_box: Rect2 = child.get_global_rect()
			if mark_box.position.x < face_box.position.x - 0.5 or mark_box.end.x > face_box.end.x + 0.5:
				inside = false
			if mark_box.position.y < face_box.end.y:
				below = false
			rows[roundi(mark_box.position.y)] = true
		ok(inside, "every one of %s's marks is within their own face's width" % who.name,
			"face %s, marks from %s to %s" % [face_box, marks_strip.get_child(0).get_global_rect(), marks_strip.get_child(piled - 1).get_global_rect()])
		ok(below, "and under it rather than beside it")
		ok(rows.size() == ceili(float(piled) / ui.QUEUE_MARK_COLUMNS), "wrapping onto more lines instead of running on", "%d lines" % rows.size())
		var index = queue.get_children().find(their_face)
		if index + 1 < queue.get_child_count():
			var next_face: Rect2 = queue.get_child(index + 1).get_global_rect()
			var clear = true
			for child in marks_strip.get_children():
				if child.get_global_rect().end.x > next_face.position.x:
					clear = false
			ok(clear, "so none of them reach under the next face along")
	var side_strip = ui._icon_for(column, hero).get_node("Layout/Icon/Conditions")
	var portrait_box: Rect2 = ui._icon_for(column, hero).get_node("Layout/Icon").get_global_rect()
	var beside = true
	var side_rows := {}
	for child in side_strip.get_children():
		if child.get_global_rect().position.x < portrait_box.end.x:
			beside = false
		side_rows[roundi(child.get_global_rect().position.y)] = true
	ok(beside, "beside the party portrait they sit to its right")
	ok(side_rows.size() == ceili(float(piled) / ui.PORTRAIT_MARK_COLUMNS), "four to a line", "%d lines" % side_rows.size())
	for who in [hero, mark]:
		for i in piled - 1:
			who.status_effects.pop_back()
	combat.update_combatants.emit(combat.combatants)
	await get_tree().process_frame
	await get_tree().process_frame
	var lone_face: Control = ui._icon_for(queue, mark)
	var lone = lone_face.get_node("Conditions")
	var centre_gap = absf(lone.get_child(0).get_global_rect().get_center().x - lone_face.get_global_rect().get_center().x)
	ok(lone.get_child_count() == 1 and centre_gap < 1.5, "down to one again, it sits centred under the face", "%.1f off" % centre_gap)
	for who in [hero, mark]:
		who.status_effects.pop_back()
	combat.update_combatants.emit(combat.combatants)
	log_line("")

	log_line("======== on an enemy's turn ========")
	combat.advance_turn()
	await get_tree().process_frame
	var now = combat.get_current_combatant()
	if now.side == 1:
		ok(not ui._pips.visible, "the action marks are the player's alone")
		ok(ui._turn_banner.showing() == "%s's Turn" % now.name, "and the banner names the enemy", ui._turn_banner.showing())
	else:
		log_line("  NOTE  %s is next, not an enemy" % now.name)
	log_line("")

	game.queue_free()
	await get_tree().process_frame
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
