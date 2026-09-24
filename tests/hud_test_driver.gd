extends Node
## The HUD's health bars and the three skill panel tabs.

var LOG_PATH := HarnessLog.path_for("hud")

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


func run_test():
	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_01_ambush.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	var ui = game.get_node("CanvasLayer/UI")
	combat.finish_deployment()
	await get_tree().process_frame
	await get_tree().process_frame

	log_line("======== the turn queue has health bars ========")
	var queue = ui.get_node("TurnQueue/Queue")
	ok(queue.get_child_count() > 0, "there are faces in the queue", "%d" % queue.get_child_count())
	var icon = queue.get_child(0)
	var bar = icon.get_node_or_null("Health")
	ok(bar != null, "each face carries a Health bar")
	ok(bar is ProgressBar, "which is a real bar")
	ok(bar.visible, "and it is shown")
	ok(bar.max_value > 1, "scaled to that combatant's health", "max %s" % bar.max_value)
	ok(bar.value == bar.max_value, "starting full", "%s / %s" % [bar.value, bar.max_value])
	log_line("")

	log_line("======== the bar follows the damage ========")
	var shown = null
	for comb in combat.combatants:
		if comb.get("id", -1) == icon.get_meta("combatant_id", -2):
			shown = comb
	ok(shown != null, "the face maps back to a combatant", icon.name)
	if shown != null:
		var full = combat.get_effective_stat(shown, "max_hp")
		shown.hp = maxi(int(full * 0.2), 1)
		ui.update_combatants(combat.combatants)
		await get_tree().process_frame
		ok(bar.value < bar.max_value, "hurting them shortens it", "%s / %s" % [bar.value, bar.max_value])
		var fill = bar.get_theme_stylebox("fill") as StyleBoxFlat
		ok(fill != null, "the bar has a fill style")
		if fill != null:
			ok(fill.bg_color.is_equal_approx(icon.HEALTH_HURT), "and turns amber when low",
				"%s" % fill.bg_color)
		shown.hp = full
		ui.update_combatants(combat.combatants)
		await get_tree().process_frame
		ok(bar.value == bar.max_value, "healing fills it again", "%s" % bar.value)
	log_line("")

	log_line("======== each face keeps its own colour ========")
	# One shared style would have the last one to update recolour the whole row.
	if queue.get_child_count() > 1:
		var other = queue.get_child(1)
		var a = icon.get_node("Health").get_theme_stylebox("fill")
		var b = other.get_node("Health").get_theme_stylebox("fill")
		ok(a != b, "two faces have two fill styles")
	else:
		log_line("  (only one face in the queue - skipped)")
	log_line("")

	log_line("======== the party portraits have bars too ========")
	var status = ui.get_node("Status")
	ok(status.get_child_count() > 0, "the portrait column is populated", "%d" % status.get_child_count())
	var portrait = status.get_child(0)
	var portrait_bar = portrait.get_node_or_null("Icon/Health")
	ok(portrait_bar != null, "a portrait carries a Health bar")
	ok(portrait_bar is ProgressBar, "which is a real bar")
	ok(portrait.get_node_or_null("Icon/HealthText") != null, "with the numbers still there")
	portrait.set_health(3, 20)
	ok(portrait_bar.value == 3 and portrait_bar.max_value == 20, "and it tracks what it is told",
		"%s / %s" % [portrait_bar.value, portrait_bar.max_value])
	ok(portrait.get_node("Icon/HealthText").text == "3/20", "so does the label",
		portrait.get_node("Icon/HealthText").text)
	log_line("")

	log_line("======== a tab per action slot, and a switch for spells ========")
	var tabs = ui.get_node("Actions/SkillPanelTabs")
	ok(tabs != null, "there is a tab row")
	ok(ui.get_node_or_null("Actions/SkillPanelToggle") == null, "and no cycling button left")
	# Spells stopped being a fourth tab: it is a switch that changes what the
	# tab you are on is showing, so the two questions - which slot, and skills
	# or spells - are asked separately.
	for name in ["MainTab", "SecondaryTab", "ItemsTab"]:
		ok(tabs.get_node_or_null(name) != null, "%s exists" % name)
	ok(tabs.get_node_or_null("SpellsTab") == null, "and Spells is no longer one of them")
	ok(ui.get_node_or_null("Actions/SpellsToggle") != null, "it is a switch of its own")
	ok(ui.get_node_or_null("Actions/SkillPanelLabel") == null,
		"with no label repeating what the selected tab already says")
	log_line("")

	log_line("======== pressing one goes straight there ========")
	ui.set_skill_panel(ui.SkillPanel.MAIN)
	ok(ui.showing_panel == ui.SkillPanel.MAIN, "starting on Main")
	tabs.get_node("SecondaryTab").pressed.emit()
	ok(ui.showing_panel == ui.SkillPanel.SECONDARY, "Secondary goes to Secondary")
	ok(tabs.get_node("SecondaryTab").button_pressed, "and that tab reads as the selected one")
	tabs.get_node("MainTab").pressed.emit()
	ok(ui.showing_panel == ui.SkillPanel.MAIN, "Main goes straight back, in one press")
	log_line("")

	log_line("======== the tab you are on reads as selected ========")
	ui.set_skill_panel(ui.SkillPanel.SECONDARY)
	var on = tabs.get_node("SecondaryTab").get_theme_color("font_color")
	var off = tabs.get_node("MainTab").get_theme_color("font_color")
	ok(on != off, "the selected one is a different colour", "%s vs %s" % [on, off])
	ok(tabs.get_node("SecondaryTab").button_pressed, "and reads as pressed")
	ok(not tabs.get_node("MainTab").button_pressed, "while the others do not")
	log_line("")

	log_line("======== Spells only for someone who casts ========")
	var caster = null
	var swordsman = null
	for comb in combat.combatants:
		if comb.side != 0:
			continue
		if not combat.spell_skills_of(comb).is_empty():
			caster = comb
		else:
			swordsman = comb
	if swordsman != null:
		combat.current_combatant = combat.combatants.find(swordsman)
		ui.show_combatant_status_main(swordsman)
		await get_tree().process_frame
		ok(not ui.get_node("Actions/SpellsToggle").visible,
			"the switch is hidden for someone with no spells", swordsman.name)
	else:
		log_line("  (everyone here casts - skipped)")
	if caster != null:
		combat.current_combatant = combat.combatants.find(caster)
		ui.show_combatant_status_main(caster)
		await get_tree().process_frame
		ok(ui.get_node("Actions/SpellsToggle").visible, "and shown for someone who does", caster.name)
	else:
		log_line("  (nobody here casts - skipped)")
	log_line("")

	log_line("======== the switch changes what the tab is showing ========")
	# Which slot, and skills or spells, are two separate questions now. Main and
	# Spells together are the spells cast from the main action; Secondary and
	# Spells the ones cast from the secondary.
	# Anybody who casts, from either side - the earlier search only looked at
	# the party, and on this map the party is a swordsman.
	var conjurer = caster
	if conjurer == null:
		for comb in combat.combatants:
			if comb.alive and not combat.spells_in_slot(comb, false).is_empty():
				conjurer = comb
				break
	if conjurer != null:
		combat.current_combatant = combat.combatants.find(conjurer)
		ui.show_combatant_status_main(conjurer)
		await get_tree().process_frame
		var switch = ui.get_node("Actions/SpellsToggle")
		ok(not ui.showing_spells, "a turn opens on skills")
		ok(switch.text == "Spells", "and the switch offers spells", switch.text)

		ui.set_skill_panel(ui.SkillPanel.MAIN)
		var main_skills = combat.main_skills_of(conjurer)
		switch.pressed.emit()
		await get_tree().process_frame
		ok(ui.showing_spells, "pressing it shows spells")
		ok(switch.text == "Skills", "and it now offers skills back", switch.text)
		# What is listed is the main-action spells, not every spell they know.
		var main_spells = combat.spells_in_slot(conjurer, false)
		var all_spells = combat.spell_skills_of(conjurer)
		log_line("  NOTE  %s knows %d spell(s): %d from the main action, %d from the secondary"
			% [conjurer.name, all_spells.size(), main_spells.size(),
				combat.spells_in_slot(conjurer, true).size()])
		var listed := []
		for key in main_spells:
			listed.append(key)
		for key in listed:
			ok(SkillDatabase.skills[key].spell_slot_level > 0 and not SkillDatabase.skills[key].is_secondary,
				"%s costs a gate and is a main action" % key)
		for key in main_skills:
			ok(not key in main_spells, "%s, which costs no gate, is not among them" % key)

		# The other tab asks the same question of the other slot.
		ui.set_skill_panel(ui.SkillPanel.SECONDARY)
		await get_tree().process_frame
		ok(ui.showing_spells, "moving tab keeps you looking at spells")
		for key in combat.spells_in_slot(conjurer, true):
			ok(SkillDatabase.skills[key].is_secondary, "%s is a secondary spell" % key)

		# And back.
		switch.pressed.emit()
		await get_tree().process_frame
		ok(not ui.showing_spells, "pressing it again goes back to skills")
		ok(switch.text == "Spells", "with the switch offering spells once more")

		# Items are neither, so there is nothing to swap while looking at them.
		# Only checkable on somebody actually carrying something: an empty bag
		# hides the tab and bounces you back to Main, so the switch is rightly
		# still there.
		if not combat.items_of(conjurer).is_empty():
			ui.set_skill_panel(ui.SkillPanel.ITEMS)
			await get_tree().process_frame
			ok(not switch.visible, "and it is out of the way on the Items tab")
		else:
			log_line("  NOTE  %s carries nothing, so there is no Items tab to stand on" % conjurer.name)
	else:
		log_line("  (nobody here casts - skipped)")
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
