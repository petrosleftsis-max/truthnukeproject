extends Node
## Clicking a party portrait shows that character's side of the HUD, as though
## it were their turn, with every action greyed out - and it goes back to the one
## acting as soon as there is a reason to.

var LOG_PATH := HarnessLog.path_for("portraits")

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
	get_tree().create_timer(120.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


## Clicks `comb`'s portrait in the party column the way the mouse would.
func click_portrait(ui, comb: Dictionary):
	for status in ui.get_node("Status").get_children():
		if status.get_meta("combatant_id", -1) == comb.id:
			var press := InputEventMouseButton.new()
			press.button_index = MOUSE_BUTTON_LEFT
			press.pressed = true
			status.gui_input.emit(press)
			await get_tree().process_frame
			return
	ok(false, "%s has a portrait to click" % comb.name)


func buttons(ui) -> Array:
	return ui.get_node("Actions/ActionsPanel/ActionsGrid").get_children()


## The skills the action panel is showing, by the name each preview starts with.
func shown_names(ui) -> Array:
	var names = []
	for button in buttons(ui):
		if button.tooltip_text != "":
			names.append(button.tooltip_text.split("\n")[0])
	return names


func names_of(keys: Array) -> Array:
	var names = []
	for key in keys:
		names.append(SkillDatabase.skills[key].name)
	return names


func run_test():
	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_02_sappers.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	for i in 4:
		await get_tree().process_frame
	var combat: Combat = game.get_node("VisualCombat")
	var ui = game.get_node("CanvasLayer/UI")
	var controller = game.get_node("Controller")
	combat.finish_deployment()
	await get_tree().process_frame

	var actor = combat.get_current_combatant()
	ok(actor.side == 0, "the fight opens on a player's turn", actor.name)
	var other = {}
	for comb in combat.combatants:
		if comb.side == 0 and comb.alive and comb != actor and other.is_empty():
			other = comb
	ok(not other.is_empty(), "with somebody else in the party to look at", other.get("name", "nobody"))

	log_line("======== clicking a teammate's portrait ========")
	var actor_skills = names_of(combat.main_skills_of(actor))
	await click_portrait(ui, other)
	ok(ui.is_viewing_other() and ui.shown_combatant() == other, "shows their side of the HUD", other.name)
	ok(ui.get_node("Actions/StatusIcon/Layout/Icon").texture == other.icon, "their face in the big portrait")
	ok(ui.get_node("Actions/Movement").text == "Move %d" % combat.get_effective_stat(other, "movement"),
		"the movement they would have on their turn", ui.get_node("Actions/Movement").text)
	ok(shown_names(ui) == names_of(combat.main_skills_of(other)), "their skills on the panel",
		"%s" % [shown_names(ui)])
	ok(shown_names(ui) != actor_skills, "rather than the one acting")
	var enabled = []
	for button in buttons(ui):
		if not button.disabled:
			enabled.append(button.tooltip_text.split("\n")[0])
	ok(enabled.is_empty(), "every one of them greyed out, since it is not their turn", "%s" % [enabled])
	var wired = 0
	for button in buttons(ui):
		wired += button.pressed.get_connections().size()
	ok(wired == 0, "and none of them wired to anything, so no route can use one", "%d" % wired)
	for button in buttons(ui):
		button.pressed.emit()
	ok(not controller.is_skill_selected(), "pressing them anyway selects nothing")
	ok(ui.get_node("Actions/EndTurnButton").disabled, "End Turn greys out too - the turn on show is not the one it would end")
	# The previews are in their hands, not the actor's.
	var first = combat.main_skills_of(other)[0] if not combat.main_skills_of(other).is_empty() else ""
	if first != "":
		ok(buttons(ui)[0].tooltip_text == TooltipText.wrap(ui.build_skill_tooltip(SkillDatabase.skills[first], other)),
			"and their previews are worked out for them", SkillDatabase.skills[first].name)
	# The other tabs follow them too.
	ui.set_skill_panel(ui.SkillPanel.SECONDARY)
	await get_tree().process_frame
	ok(shown_names(ui) == names_of(combat.secondary_skills_of(other)), "the Secondary tab is theirs",
		"%s" % [shown_names(ui)])
	ok(ui.is_viewing_other(), "and changing tab keeps looking at them")
	ui.set_skill_panel(ui.SkillPanel.MAIN)
	var dimmed = []
	for status in ui.get_node("Status").get_children():
		if status.modulate != Color.WHITE:
			dimmed.append(status.get_meta("combatant_id", -1))
	ok(not dimmed.has(other.id) and dimmed.size() == ui.get_node("Status").get_child_count() - 1,
		"everybody else's portrait dims", "%s" % [dimmed])
	ok(ui.get_node("Actions/SelectTargetMessage").visible
		and ui.get_node("Actions/SelectTargetMessage/MarginContainer/Label").text.contains(other.name),
		"and a banner says whose side it is", ui.get_node("Actions/SelectTargetMessage/MarginContainer/Label").text)
	log_line("")

	log_line("======== and every way back ========")
	await click_portrait(ui, actor)
	ok(not ui.is_viewing_other() and ui.shown_combatant() == actor, "clicking the one acting goes back to them")
	ok(shown_names(ui) == actor_skills, "their skills again", "%s" % [shown_names(ui)])
	var usable = false
	for button in buttons(ui):
		if not button.disabled:
			usable = true
	ok(usable, "usable again")
	ok(not ui.get_node("Actions/EndTurnButton").disabled, "End Turn too")
	ok(not ui.get_node("Actions/SelectTargetMessage").visible, "and the banner is gone")
	var all_lit = true
	for status in ui.get_node("Status").get_children():
		if status.modulate != Color.WHITE:
			all_lit = false
	ok(all_lit, "every portrait lit again")

	await click_portrait(ui, other)
	await click_portrait(ui, other)
	ok(not ui.is_viewing_other(), "clicking the same portrait again goes back as well")

	await click_portrait(ui, other)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await get_tree().process_frame
	await get_tree().process_frame
	ok(not ui.is_viewing_other(), "Escape goes back")
	var pause = game.get_node_or_null("PauseUI")
	var menu_up = get_tree().paused
	ok(not menu_up, "without opening the pause menu over the top", "paused=%s" % menu_up)
	MenuPause.clear(get_tree())

	await click_portrait(ui, other)
	# What the one acting walking or using a skill does to the HUD.
	ui.refresh_action_buttons()
	ok(not ui.is_viewing_other(), "the one acting doing something goes back to them")

	await click_portrait(ui, other)
	ui.show_combatant_status_main(actor)
	ok(not ui.is_viewing_other(), "and so does a turn starting")

	await click_portrait(ui, other)
	combat.combatant_die(other)
	await get_tree().process_frame
	ok(not ui.is_viewing_other() and ui.shown_combatant() == actor, "and the one being looked at falling")
	log_line("")

	game.queue_free()
	await get_tree().process_frame
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
