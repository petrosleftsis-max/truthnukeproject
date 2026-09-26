extends Node
## Looking at what cannot be used: a greyed-out skill - spent, unaffordable, or
## a teammate's while viewing them - aims from its owner, shows its reach and
## what it would do, and can never actually go off.

var LOG_PATH := HarnessLog.path_for("look")

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


func settle():
	for i in 3:
		await get_tree().process_frame


func key(code: Key):
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await get_tree().process_frame
	await get_tree().process_frame


func left_release() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	return event


func prompt_text(ui) -> String:
	if ui._hit_preview == null or not ui._hit_preview.visible:
		return ""
	var bits := []
	for label in ui._hit_preview.find_children("*", "Label", true, false):
		bits.append(label.text)
	return " | ".join(bits)


func run_test():
	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_02_sappers.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	for i in 4:
		await get_tree().process_frame
	var combat: Combat = game.get_node("VisualCombat")
	var controller = game.get_node("Controller")
	var ui = game.get_node("CanvasLayer/UI")
	combat.finish_deployment()
	await settle()
	var cyrus = combat.get_current_combatant()
	var prometheus = {}
	var mark = {}
	for comb in combat.combatants:
		if comb.name == "Prometheus":
			prometheus = comb
		if comb.side == 1 and comb.alive and mark.is_empty():
			mark = comb
	for comb in combat.combatants:
		comb.reaction_used = true
	ok(cyrus.name == "Cyrus" and not prometheus.is_empty(), "Cyrus acting, Prometheus to look at", cyrus.name)
	var fireball: SkillDefinition = SkillDatabase.skills["fireball"]

	log_line("======== a teammate's spell, on Cyrus's turn ========")
	# Somewhere Prometheus could land a Fireball and Cyrus could not see to.
	var spot = Vector2i(-99999, -99999)
	for tile in controller.get_reachable_tiles(prometheus.position, prometheus.movement_class, 99):
		var gap = combat.get_position_distance(prometheus.position, tile)
		if spot.x == -99999 and gap >= 7 and gap <= 10 and combat.get_combatant_at(tile).is_empty() \
				and combat.has_line_of_sight(prometheus.position, tile, prometheus.movement_class):
			spot = tile
	ok(spot.x > -99999, "somewhere in reach of his Fireball", "%s" % spot)
	combat.teleport_to(mark, spot)
	mark.hp = 1
	ui.view_combatant(prometheus)
	await settle()
	ui.set_skill_panel(ui.SkillPanel.MAIN)
	if not ui.showing_spells:
		ui.toggle_spells()
	await settle()
	var button: Button = null
	for i in ui.action_buttons().size():
		if ui._shelves.keys()[i] == "fireball":
			button = ui.action_buttons()[i]
	ok(button != null and button.disabled, "his Fireball is on the shelves, greyed out - it is not his turn")
	var slots_before = prometheus.spell_slots.duplicate()
	var hp_before = mark.hp
	# A click, as the button itself receives it - disabled, it will not press.
	button.gui_input.emit(left_release())
	await settle()
	ok(controller.is_look_only(), "pressing it anyway starts a look")
	ok(controller.aiming_caster() == prometheus, "aimed from Prometheus, not Cyrus")
	var reach = combat.get_range_tiles(fireball, prometheus.position, prometheus.movement_class, prometheus)
	ok(controller._range_preview_positions == reach, "showing his reach", "%d tiles" % reach.size())
	ok(ui.get_node("Actions/SelectTargetMessage").visible
		and ui.get_node("Actions/SelectTargetMessage/MarginContainer/Label").text.contains("Just looking at Prometheus's Fireball"),
		"with a note saying it is only a look", ui.get_node("Actions/SelectTargetMessage/MarginContainer/Label").text)
	controller._preview_hits(mark.position)
	var said = combat.predict_hit(prometheus, mark, fireball)
	var text = prompt_text(ui)
	ok(text.contains("%d damage - lethal" % said.damage), "what it would do, in his hands - and that it would kill",
		text)
	ok(text.contains("just looking"), "and the prompt says it cannot be used now")
	controller._unhandled_input(left_release())
	await settle()
	controller.confirm_skill_target(mark.position)
	await settle()
	ok(mark.hp == hp_before and prometheus.spell_slots == slots_before and not prometheus.get("skill_used_this_turn", false),
		"clicking a target does nothing at all", "hp %d, gates %s" % [mark.hp, prometheus.spell_slots])
	ok(controller.is_look_only(), "and the look carries on")
	await key(KEY_ESCAPE)
	ok(not controller.is_skill_selected(), "Escape ends the look")
	ok(not get_tree().paused, "and only that - no menu opens on the same press")
	ok(ui.is_viewing_other(), "but not the view of Prometheus")
	ok(ui.get_node("Actions/SelectTargetMessage/MarginContainer/Label").text.contains("Looking at Prometheus"),
		"whose banner comes back")
	await key(KEY_ESCAPE)
	ok(not ui.is_viewing_other(), "a second Escape goes back to Cyrus")
	log_line("")

	log_line("======== one of Cyrus's own, spent ========")
	ui.set_skill_panel(ui.SkillPanel.MAIN)
	if ui.showing_spells:
		ui.toggle_spells()
	cyrus.skill_used_this_turn = true
	ui.refresh_action_buttons()
	await settle()
	var gun_at = combat.main_skills_of(cyrus).find("gun")
	ok(gun_at >= 0 and ui.action_buttons()[gun_at].disabled, "with his main action spent, Gun is greyed out")
	await key(KEY_1 + gun_at)
	ok(controller.is_look_only() and controller._selected_skill == "gun" and controller.aiming_caster() == cyrus,
		"its number key takes a look at it, from Cyrus", controller._selected_skill)
	controller.cancel_skill_selection()
	await settle()
	cyrus.skill_used_this_turn = false
	ui.refresh_action_buttons()
	await settle()
	await key(KEY_1 + gun_at)
	ok(controller.is_skill_selected() and not controller.is_look_only(), "while one he can use is aimed for real")
	controller.cancel_skill_selection()
	await settle()
	ok(controller.aiming_caster() == cyrus, "and once put away, aiming is his again")
	log_line("")

	log_line("======== not on anybody else's turn ========")
	controller.player_turn = false
	ok(not ui._look_at("gun"), "no look while the enemy acts")
	controller.player_turn = true
	log_line("")

	game.queue_free()
	await get_tree().process_frame
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
