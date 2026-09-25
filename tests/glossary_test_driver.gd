extends Node
## The glossary: every concept reachable, and the numbers on each page read off
## the game rather than typed in beside it.

var LOG_PATH := HarnessLog.path_for("glossary")
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


## Every button currently offered, by its text.
func offered(panel) -> Array:
	var found := []
	for child in panel._list.get_children():
		if child is Button:
			found.append(child.text)
	return found


## Presses the button reading `text`.
func press(panel, text: String) -> bool:
	for child in panel._list.get_children():
		if child is Button and child.text == text:
			child.pressed.emit()
			return true
	return false


## A Combat with no battle under it, purely to ask about the rules.
func combat_of(_panel) -> Combat:
	if _combat == null:
		_combat = Combat.new()
	return _combat
var _combat: Combat = null


func run_test():
	log_line("======== there is a way in from the title screen ========")
	var menu = load("res://main_menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	await get_tree().process_frame
	var on_the_menu := []
	for child in menu._panels["root"].get_children():
		if child is VBoxContainer:
			for button in child.get_children():
				if button is Button:
					on_the_menu.append(button.text)
	ok("Glossary" in on_the_menu, "Glossary is one of the choices", "%s" % [on_the_menu])
	ok(menu._panels.has("glossary"), "and it has a panel of its own")
	log_line("")

	var panel = menu._panels["glossary"]
	panel.show_contents()
	await get_tree().process_frame

	log_line("======== the five things it explains ========")
	var contents = offered(panel)
	for wanted in ["Character intros", "Conditions", "Gates", "Skills", "Passive Skills"]:
		ok(wanted in contents, "%s is offered" % wanted)
	log_line("")

	log_line("======== the cast ========")
	press(panel, "Character intros")
	await get_tree().process_frame
	var cast = offered(panel)
	for key in ["cyrus", "enfina", "prometheus", "alithia"]:
		var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
		ok(definition != null and definition.name in cast, "%s has an entry" % key, "%s" % [cast])
	ok("glossary_text" in CombatantDatabase.combatants["cyrus"],
		"and somewhere for you to write it")
	press(panel, CombatantDatabase.combatants["cyrus"].name)
	await get_tree().process_frame
	ok(panel._body_scroll.visible, "opening one shows a page")
	ok(panel._body.text != "", "with something on it", panel._body.text.substr(0, 48))
	panel._go_back()
	await get_tree().process_frame
	ok(not panel._body_scroll.visible and offered(panel).size() == 4,
		"and Back returns to the list", "%s" % [offered(panel)])
	panel._go_back()
	await get_tree().process_frame
	log_line("")

	log_line("======== a condition page carries its real numbers ========")
	press(panel, "Conditions")
	await get_tree().process_frame
	var listed = offered(panel)
	var every := []
	for condition in GlossaryPanel.conditions():
		every.append(condition.display_name)
		if not condition.display_name in listed:
			ok(false, "%s is missing from the list" % condition.display_name)
	ok(every.size() == listed.size(), "every condition has a button",
		"%d of %d" % [listed.size(), every.size()])
	ok(not listed.is_empty(), "and there is a list at all", "%d" % listed.size())

	# The list used to be read by scanning res://conditions/ for *.tres, which
	# is a folder that does not survive an export in that shape: the files are
	# converted to binary and renamed on the way into the pack, so the page was
	# blank in the build and perfect in the editor. What a skill points at comes
	# through the conversion intact, so that is what is asked now - and this is
	# the assertion that the folder is no longer what holds it up.
	var without_the_folder := []
	for condition in GlossaryPanel.conditions():
		var inflicted := false
		for source in [SkillDatabase.skills, ItemDatabase.items]:
			for key in source:
				for effect in source[key].effects:
					if effect != null and effect.condition == condition:
						inflicted = true
		if inflicted:
			without_the_folder.append(condition.display_name)
	ok(without_the_folder.size() == every.size(),
		"every condition is reachable without listing the folder",
		"%d of %d" % [without_the_folder.size(), every.size()])
	var windswept: ConditionDefinition = load("res://conditions/windswept.tres")
	press(panel, windswept.display_name)
	await get_tree().process_frame
	var page = panel._body.text
	ok("%d" % windswept.duration in page, "its duration is on the page", "%d turns" % windswept.duration)
	ok("%+d" % windswept.movement_change in page, "and what it does to movement",
		"%+d" % windswept.movement_change)
	ok("%d" % windswept.drift_tiles in page, "and how far the wind takes them")
	ok("subject to change" in page, "and says the numbers are only the defaults")
	panel._go_back()
	await get_tree().process_frame
	panel._go_back()
	await get_tree().process_frame
	log_line("")

	log_line("======== the gates, as one written page ========")
	press(panel, "Gates")
	await get_tree().process_frame
	ok(panel._body_scroll.visible, "Gates opens a page rather than a list")
	ok(offered(panel).is_empty(), "with no buttons to pick between", "%s" % [offered(panel)])
	var gates_page = panel._body.text
	for level in [1, 2, 3]:
		ok(Stats.gate_name(level).replace("Gates", "Gate") in gates_page
			or Stats.gate_name(level) in gates_page,
			"%s is named on it" % Stats.gate_name(level))
	var book = load("res://glossary/glossary_book.tres")
	ok(book.gates != "", "the text comes out of the book, where you can edit it")
	ok(gates_page == book.gates, "and is exactly what the book says")
	# The page claims a higher gate can pay for a lower skill. The game had
	# better agree.
	ok("higher level ones" in gates_page, "it says a higher gate can pay")
	var caster = {"spell_slots": [0, 0, 0, 1]}
	ok(combat_of(panel).slot_available_for(caster, 1) == 3,
		"and a level 3 gate really does pay for a level 1 skill",
		"%d" % combat_of(panel).slot_available_for(caster, 1))
	var spent_up = {"spell_slots": [0, 0, 0, 0]}
	ok(combat_of(panel).slot_available_for(spent_up, 1) == 0,
		"while nothing left pays for nothing")
	panel._go_back()
	await get_tree().process_frame
	log_line("")

	log_line("======== the skills ========")
	press(panel, "Skills")
	await get_tree().process_frame
	var skills = offered(panel)
	ok(skills.size() > 10, "the whole list is there", "%d skills" % skills.size())
	var carried := []
	for key in ItemDatabase.items:
		if ItemDatabase.items[key].name in skills:
			carried.append(key)
	ok(carried.is_empty(), "consumables are not filed as skills", "%s" % [carried])
	var fireball: SkillDefinition = SkillDatabase.skills["fireball"]
	if press(panel, fireball.name):
		await get_tree().process_frame
		var text = panel._body.text
		ok(Stats.gate_name(fireball.spell_slot_level) in text,
			"a spell says which gate it costs", Stats.gate_name(fireball.spell_slot_level))
		ok("Reaches" in text, "and how far it goes")
		panel._go_back()
		await get_tree().process_frame
	ok(not "Mimicry" in skills, "a passive is not filed among the skills", "%s" % [skills])
	panel._go_back()
	await get_tree().process_frame
	log_line("")

	log_line("======== the passive skills ========")
	press(panel, "Passive Skills")
	await get_tree().process_frame
	var passives_listed = offered(panel)
	var every_passive = GlossaryPanel.passives()
	ok(not every_passive.is_empty(), "there are passives to list", "%d" % every_passive.size())
	ok(passives_listed.size() == every_passive.size(), "every passive has a button",
		"%s" % [passives_listed])
	# The same export trap as the conditions: reached through the characters
	# holding them, not by listing a folder the build reshapes.
	var held := 0
	for passive in every_passive:
		for key in CombatantDatabase.combatants:
			if CombatantDatabase.combatants[key].passives.has(passive):
				held += 1
				break
	ok(held == every_passive.size(), "every passive is reachable without listing the folder",
		"%d of %d" % [held, every_passive.size()])
	var mimicry: PassiveDefinition = CombatantDatabase.combatants["mimic"].passives[0]
	ok(press(panel, mimicry.name), "Mimicry is one of them", "%s" % [passives_listed])
	await get_tree().process_frame
	var passive_page = panel._body.text
	ok(passive_page.contains(mimicry.description), "its page says what it does, as written")
	ok(passive_page.contains(mimicry.describe_when()), "when it works", mimicry.describe_when())
	ok(passive_page.contains("without opening a gate"), "what its switches do, read off the passive itself")
	ok(passive_page.contains(CombatantDatabase.combatants["mimic"].name), "and who has it")
	log_line("")

	log_line("======== Back all the way out hands the menu back ========")
	var handed_back = [false]
	panel.closed.connect(func(): handed_back[0] = true)
	for i in 6:
		panel._go_back()
		await get_tree().process_frame
	ok(handed_back[0], "the glossary lets go when the reader runs out of Backs")
	log_line("")

	menu.queue_free()
	await get_tree().process_frame
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
