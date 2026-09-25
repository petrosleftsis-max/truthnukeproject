extends Node
## Every tooltip that carries written text fits on the screen.
##
## Godot's tooltip is a Label that never wraps, and Study's description - one
## long sentence - came out wider than the screen. Each tooltip here is measured
## the way it is really drawn: the text in a label styled as a tooltip's, inside
## a panel styled as a tooltip's, and the panel's size compared with the screen.

var LOG_PATH := HarnessLog.path_for("tooltips")

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


## How big `text` is drawn as a tooltip: the panel, with its margins, around the
## label - both dressed the way Godot dresses its own.
func drawn_size(text: String) -> Vector2:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"TooltipPanel"
	var label := Label.new()
	label.theme_type_variation = &"TooltipLabel"
	label.text = text
	panel.add_child(label)
	get_tree().root.add_child(panel)
	var measured = panel.get_combined_minimum_size()
	panel.free()
	return measured


## The words of `text`, whatever lines they fall on.
func words_of(text: String) -> PackedStringArray:
	return text.replace("\n", " ").split(" ", false)


## Checks one tooltip, and returns how wide it would have been unwrapped.
func check(what: String, text: String, screen: Vector2, oversize: Array) -> float:
	var shown = TooltipText.wrap(text)
	var size = drawn_size(shown)
	if size.x > screen.x or size.y > screen.y:
		oversize.append("%s %dx%d" % [what, size.x, size.y])
	if words_of(shown) != words_of(text):
		oversize.append("%s lost or changed words in wrapping" % what)
	return drawn_size(text).x


func run_test():
	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_02_sappers.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	for i in 4:
		await get_tree().process_frame
	var combat: Combat = game.get_node("VisualCombat")
	var ui = game.get_node("CanvasLayer/UI")
	combat.finish_deployment()
	await get_tree().process_frame
	var screen = get_viewport().get_visible_rect().size
	var holder = combat.get_current_combatant()

	log_line("======== what went wrong ========")
	var study = ui.build_skill_tooltip(SkillDatabase.skills["study"], holder)
	var unwrapped = drawn_size(study)
	ok(unwrapped.x > screen.x, "unwrapped, Study's preview is wider than the screen",
		"%d of %d" % [unwrapped.x, screen.x])
	var wrapped = drawn_size(TooltipText.wrap(study))
	ok(wrapped.x <= screen.x and wrapped.y <= screen.y, "wrapped, it fits",
		"%dx%d in %dx%d" % [wrapped.x, wrapped.y, screen.x, screen.y])
	ok(TooltipText.wrap("Short enough.") == "Short enough.", "a short line is left exactly as it was")
	ok(TooltipText.wrap("One\n\nTwo") == "One\n\nTwo", "and so are blank lines between paragraphs")
	var effect_line = "- " + "word ".repeat(40).strip_edges()
	var bullet = TooltipText.wrap(effect_line).split("\n")
	ok(bullet.size() > 1 and bullet[1].begins_with(TooltipText.HANGING_INDENT),
		"a long effect carries on indented under itself", "%s" % [bullet.slice(0, 2)])
	log_line("")

	log_line("======== every skill and item preview fits ========")
	var oversize := []
	var were_too_wide := []
	for key in SkillDatabase.skills:
		var skill: SkillDefinition = SkillDatabase.skills[key]
		if check(skill.name, ui.build_skill_tooltip(skill, holder), screen, oversize) > screen.x:
			were_too_wide.append(skill.name)
	ok(oversize.is_empty(), "all %d of them" % SkillDatabase.skills.size(), "%s" % [oversize])
	log_line("  NOTE  wider than the screen before wrapping: %s" % [were_too_wide])
	# Every effect a skill carries says what it does. Study, Stealth, Run and
	# Guard each ended their preview on a bare "-", their kind of effect having
	# no words at all.
	var blank := []
	for key in SkillDatabase.skills:
		var skill: SkillDefinition = SkillDatabase.skills[key]
		for line in ui.build_skill_tooltip(skill, holder).split("\n"):
			if line.replace("(on yourself)", "").strip_edges() == "-":
				blank.append(skill.name)
	ok(blank.is_empty(), "and every effect on them is described", "%s" % [blank])
	for key in ["run", "guard", "stealth", "study"]:
		for line in ui.build_skill_tooltip(SkillDatabase.skills[key], holder).split("\n"):
			if line.begins_with("- "):
				log_line("  NOTE  %s: %s" % [SkillDatabase.skills[key].name, line])
	log_line("")

	log_line("======== every condition's mark fits ========")
	oversize = []
	var reader := ConditionStrip.new()
	var subject = combat.combatants[0]
	var had = subject.status_effects.duplicate()
	subject.status_effects.clear()
	for condition in GlossaryPanel.conditions():
		subject.status_effects.append({"stat": "condition", "condition": condition,
			"dot_base": 5.0, "duration": 3, "source_name": "the test"})
	var marks = reader.states_of(subject, combat)
	reader.free()
	for mark in marks:
		check(mark.text.split("\n")[0], mark.text, screen, oversize)
	ok(not marks.is_empty() and oversize.is_empty(), "all %d of them" % marks.size(), "%s" % [oversize])
	subject.status_effects = had
	log_line("")

	log_line("======== the other written tooltips fit ========")
	oversize = []
	for key in ItemDatabase.items:
		var item: ItemDefinition = ItemDatabase.items[key]
		check("bag: " + item.name, "%s\n%s" % [item.name, item.description], screen, oversize)
	for path in ["res://encounters/encounter_01_ambush.tres", "res://encounters/encounter_02_sappers.tres",
			"res://encounters/encounter_03_watcher.tres"]:
		var encounter: EncounterDefinition = load(path)
		check("battle: " + encounter.display_name, encounter.description, screen, oversize)
	for way in load("res://ui/main_menu.gd").WAYS_IN:
		check("way in: " + way.name, way.description, screen, oversize)
	ok(oversize.is_empty(), "bags, the battle selector and the ways in", "%s" % [oversize])
	log_line("")

	log_line("======== what is on screen is the wrapped text ========")
	var buttons = ui.get_node("Actions/ActionsPanel/ActionsGrid").get_children()
	var shown_any := false
	var all_wrapped := true
	for button in buttons:
		if button.tooltip_text == "":
			continue
		shown_any = true
		if drawn_size(button.tooltip_text).x > TooltipText.MAX_WIDTH + 40:
			all_wrapped = false
	ok(shown_any, "the action panel has previews to show")
	ok(all_wrapped, "and every one of them is drawn at the wrapped width")
	log_line("")

	game.queue_free()
	await get_tree().process_frame
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
