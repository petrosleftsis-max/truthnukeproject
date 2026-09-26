extends Node
## The Spells panel: a shelf per gate in the action panel's own space,
## scrolling rather than growing; the gate counters as tags with dots; the mark
## on a spell that would be cast through a higher gate; and badges that grow a
## letter only where two on show would otherwise match.

var LOG_PATH := HarnessLog.path_for("shelves")

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


func settle():
	for i in 3:
		await get_tree().process_frame


func badge_on(button: Button) -> String:
	var badge = button.get_node_or_null(SkillLook.BADGE)
	return badge.text if badge != null and badge.visible else ""


func run_test():
	log_line("======== badges ========")
	var named := func(text: String) -> SkillDefinition:
		var skill := SkillDefinition.new()
		skill.name = text
		skill.icon = load("res://imagese/skills/fire_icon.png")
		return skill
	var tags = SkillLook.tags_for([named.call("Wind Shot"), named.call("Wind Swoon"), named.call("Rapier")])
	ok(tags == ["WSh", "WSw", "Ra"], "two that would both be WS grow a letter each, and nothing else does", "%s" % [tags])
	tags = SkillLook.tags_for([named.call("Big Bomb"), named.call("Blinding Bomb"), named.call("Burn Bottle")])
	ok(tags == ["BiB", "BlB", "BuB"], "and grow from the first word when the second would still match", "%s" % [tags])
	tags = SkillLook.tags_for([named.call("Tiny Bomb"), named.call("Tiny Bomb")])
	ok(tags == ["TB", "TB"], "two of the same thing are no clash", "%s" % [tags])
	tags = SkillLook.tags_for([named.call("Guard"), named.call("Gun")])
	ok(tags[0] != tags[1] and tags[0].length() == 3, "one-word names grow too", "%s" % [tags])
	log_line("")

	log_line("======== gates yet to come ========")
	ok(Stats.gate_name(5) == "Gate 5", "a gate with no name yet is still called something", Stats.gate_name(5))
	var colours := {}
	for level in range(1, 10):
		colours[Stats.gate_colour(level).to_html()] = true
	ok(colours.size() == 9, "nine gates, nine colours", "%d" % colours.size())
	log_line("")

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
	await get_tree().process_frame

	log_line("======== a gate beyond the third is spent like any other ========")
	var probe := {"spell_slots": [0, 0, 0, 0, 1]}
	ok(combat.slot_available_for(probe, 1) == 4, "a World spell can be cast through a fourth gate", "%d" % combat.slot_available_for(probe, 1))
	log_line("")

	var caster = {}
	for comb in combat.combatants:
		if comb.name == "Prometheus":
			caster = comb
	ok(not caster.is_empty(), "Prometheus is here to cast")
	combat.current_combatant = combat.combatants.find(caster)
	controller.set_controlled_combatant(caster)
	ui.show_combatant_status_main(caster)
	ui.set_skill_panel(ui.SkillPanel.MAIN)
	await settle()
	var panel: Control = ui.get_node("Actions/ActionsPanel")
	var grid: Control = ui.get_node("Actions/ActionsPanel/ActionsGrid")
	var counters: Control = ui.get_node("Actions/SpellSlots")
	var skills_size = panel.size

	log_line("======== the gate counters ========")
	ok(counters.visible, "on skills, the counters are up")
	var have := []
	for tag in counters.get_children():
		if tag is GateTag:
			have.append(tag.level)
			ok(tag.uses() == Vector2i(caster.spell_slots[tag.level], caster.max_spell_slots[tag.level]),
				"%s says how many are left" % Stats.short_gate_name(tag.level), "%s" % tag.uses())
	ok(have == [1, 2, 3], "one for each gate they can cast through", "%s" % [have])
	log_line("")

	log_line("======== the shelves ========")
	ui.toggle_spells()
	await settle()
	var shelves: SpellShelves = ui._shelves
	ok(ui.showing_shelves() and not grid.visible, "Spells swaps the grid for the shelves")
	ok(not counters.visible, "and the counters step aside - each shelf carries its own")
	ok(panel.size == skills_size, "the panel stays the size it was", "%s vs %s" % [panel.size, skills_size])
	var spells = combat.spells_in_slot(caster, false)
	ok(shelves.keys().size() == spells.size(), "a button for every spell", "%d of %d" % [shelves.keys().size(), spells.size()])
	var in_order = true
	var last_gate = 0
	for key in shelves.keys():
		var gate = SkillDatabase.skills[key].spell_slot_level
		if gate < last_gate:
			in_order = false
		last_gate = gate
	ok(in_order, "lowest gate first")
	var right_shelf = true
	for gate in [1, 2, 3]:
		var shelf = shelves.shelf(gate)
		if shelf == null:
			right_shelf = false
			continue
		ok(shelf.get_node("Tag").uses() == Vector2i(caster.spell_slots[gate], caster.max_spell_slots[gate]),
			"the %s shelf starts with its castings left" % Stats.short_gate_name(gate), "%s" % shelf.get_node("Tag").uses())
		for button in shelf.get_node("Spells").get_children():
			if SkillDatabase.skills[String(button.name)].spell_slot_level != gate:
				right_shelf = false
	ok(right_shelf, "every spell on the shelf of the gate it costs")
	ok(shelves.get_v_scroll_bar().max_value > shelves.size.y, "more than fits, so it scrolls rather than growing",
		"%s tall in %s" % [shelves.get_v_scroll_bar().max_value, shelves.size.y])
	var first_tag: Control = shelves.shelf(2).get_node("Tag")
	ok(first_tag.position.y == 0.0 and first_tag.size.y <= shelves.buttons()[0].size.y + 0.5,
		"a gate's tag sits at the top of its shelf, one line tall", "%s, %s" % [first_tag.position, first_tag.size])
	var by_key := {}
	for i in shelves.keys().size():
		by_key[shelves.keys()[i]] = shelves.buttons()[i]
	if by_key.has("wind_shot") and by_key.has("wind_swoon"):
		ok(badge_on(by_key["wind_shot"]) == "WSh" and badge_on(by_key["wind_swoon"]) == "WSw",
			"Wind Shot and Wind Swoon are told apart", "%s / %s" % [badge_on(by_key["wind_shot"]), badge_on(by_key["wind_swoon"])])
	await press(KEY_1)
	ok(controller.is_skill_selected() and controller._selected_skill == shelves.keys()[0], "1 picks the first spell on the shelves",
		"%s" % controller._selected_skill)
	controller.cancel_skill_selection()
	await settle()
	log_line("")

	log_line("======== keeping its place ========")
	shelves.scroll_vertical = 40
	await settle()
	var was = shelves.scroll_vertical
	ui.refresh_action_buttons()
	await settle()
	ok(shelves.scroll_vertical == was and was > 0, "a refresh leaves it scrolled where it was", "%d, was %d" % [shelves.scroll_vertical, was])
	log_line("")

	log_line("======== casting through a higher gate ========")
	var world_spell: Button = null
	var hermes_spell: Button = null
	for i in shelves.keys().size():
		var level = SkillDatabase.skills[shelves.keys()[i]].spell_slot_level
		if level == 1 and world_spell == null:
			world_spell = shelves.buttons()[i]
		if level == 2 and hermes_spell == null:
			hermes_spell = shelves.buttons()[i]
	var world_key := String(world_spell.name)
	var hermes_key := String(hermes_spell.name)
	var world_mark = world_spell.get_node_or_null(ui.GATE_UP)
	ok(world_mark == null or not world_mark.visible, "while World lasts, a World spell carries no mark")
	caster.spell_slots[1] = 0
	ui.refresh_action_buttons()
	await settle()
	world_spell = shelves.buttons()[shelves.keys().find(world_key)]
	hermes_spell = shelves.buttons()[shelves.keys().find(hermes_key)]
	world_mark = world_spell.get_node_or_null(ui.GATE_UP)
	ok(world_mark != null and world_mark.visible and world_mark.text == "↑H", "with World spent, a World spell says it will take Hermes",
		world_mark.text if world_mark != null else "no mark")
	ok(not world_spell.disabled, "and can still be cast")
	ok(world_spell.tooltip_text.contains("will use Gates of Hermes"), "its preview says so too")
	var hermes_mark = hermes_spell.get_node_or_null(ui.GATE_UP)
	ok(hermes_mark == null or not hermes_mark.visible, "a Hermes spell, paid from its own gate, does not")
	ok(shelves.shelf(1).get_node("Tag").uses().x == 0, "and World's dots have gone hollow")
	caster.spell_slots[2] = 0
	ui.refresh_action_buttons()
	await settle()
	world_spell = shelves.buttons()[shelves.keys().find(world_key)]
	hermes_spell = shelves.buttons()[shelves.keys().find(hermes_key)]
	ok(world_spell.get_node(ui.GATE_UP).text == "↑Y" and hermes_spell.get_node(ui.GATE_UP).text == "↑Y",
		"with Hermes gone as well, both reach for Yaldabaoth")
	caster.spell_slots[3] = 0
	ui.refresh_action_buttons()
	await settle()
	world_spell = shelves.buttons()[shelves.keys().find(world_key)]
	ok(world_spell.disabled, "and with every gate spent, nothing can be cast")
	var mark_now = world_spell.get_node_or_null(ui.GATE_UP)
	ok(mark_now == null or not mark_now.visible, "nor is anything marked as reaching higher")
	caster.spell_slots = caster.max_spell_slots.duplicate()
	log_line("")

	log_line("======== back to skills ========")
	ui.toggle_spells()
	await settle()
	ok(grid.visible and not ui.showing_shelves(), "the grid comes back")
	ok(counters.visible, "with the counters")
	ok(panel.size == skills_size, "at the same size")
	log_line("")

	game.queue_free()
	await get_tree().process_frame
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
