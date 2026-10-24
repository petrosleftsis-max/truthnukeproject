extends Node
## The character sheet's other pages - Moves, every skill and the spells on a
## shelf per gate, and Levels, what every level brings, veiled past ΛΗΘΗ until
## Chapter V - and the spellbooks Prometheus learns his spells from.

var LOG_PATH := HarnessLog.path_for("pages")
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
	get_tree().create_timer(150.0, true, false, true).timeout.connect(func():
		log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


## Every piece of text drawn under `node`, labels and rich text alike.
func texts_under(node: Node) -> Array:
	var found = []
	if node is Label:
		found.append(node.text)
	elif node is RichTextLabel:
		found.append(node.get_parsed_text())
	for child in node.get_children():
		found.append_array(texts_under(child))
	return found


## The headings down a page, top to bottom: the first label of each row that
## is a heading line (an HBox) rather than a move or a level.
func headings_of(sheet: CharacterSheet) -> Array:
	var found = []
	for row in sheet._stat_rows.get_children():
		if row is HBoxContainer and not row.name.begins_with("Move_") and row.get_child_count() > 0 and row.get_child(0) is Label:
			found.append(row.get_child(0).text)
	return found


func row_named(sheet: CharacterSheet, row_name: String) -> Node:
	for row in sheet._stat_rows.get_children():
		if row.name == row_name:
			return row
	return null


## Opens `sheet` on `key`, at page `page`.
func turn_to(sheet: CharacterSheet, key: String, page: int):
	sheet._entries = sheet._gather()
	for i in sheet._entries.size():
		if sheet._entries[i].get("key", "") == key:
			sheet._index = i
	sheet._show_page(page)
	await settle(2)


func run_test():
	Campaign.reset()
	Campaign.seed_party(["alithia", "cyrus", "enfina", "prometheus"])
	Campaign.party_level = 14
	var sheet := CharacterSheet.new()
	get_tree().root.add_child(sheet)
	await settle(2)
	sheet.open()
	await settle(2)
	ok(sheet.is_open(), "the sheet opens on the map")
	ok(sheet._tabs.get_child_count() == 3 and sheet._tabs.get_children().map(func(tab): return tab.text) == ["Sheet", "Moves", "Levels"],
		"three pages: Sheet, Moves, Levels")

	log_line("======== Moves: Alithia's spells, a shelf a gate ========")
	await turn_to(sheet, "alithia", 1)
	var headings := headings_of(sheet)
	ok(headings.has("Skills") and headings.has("Gates of World"), "her skills, and her spells under the gate they are cast through", "%s" % [headings])
	var gates: Array = headings.filter(func(text): return text.begins_with("Gates of"))
	var order: Array = gates.map(func(text): return Stats.GATE_NAMES.find(text))
	var sorted := order.duplicate()
	sorted.sort()
	ok(order == sorted and not order.has(-1), "the gates in their order, World first", "%s" % [gates])
	ok(row_named(sheet, "Move_heal") != null, "Heal among them")
	ok(not sheet._portrait.visible, "the portrait out of the way, for the width")

	log_line("======== Moves: Prometheus learns his ========")
	await turn_to(sheet, "prometheus", 1)
	var fireball := row_named(sheet, "Move_fireball")
	ok(fireball != null and texts_under(fireball).any(func(text): return "not learned" in text), "Fireball is his, not learned yet",
		"%s" % [texts_under(fireball) if fireball != null else "no row"])
	ok(fireball != null and fireball.find_child("Learn_fireball", true, false) == null, "and with nothing to learn it from, no Learn button")
	var fire_blast := row_named(sheet, "Move_fire_blast")
	ok(fire_blast != null and texts_under(fire_blast).any(func(text): return "known" in text and not "not" in text), "Fire Blast he starts with")
	ok(Campaign.cannot_learn("prometheus", "communion") != "", "Communion no book can teach him", Campaign.cannot_learn("prometheus", "communion"))
	ok(Campaign.cannot_learn("alithia", "heal") != "", "and Alithia learns nothing from books - she grows into hers")
	Campaign.give_item("cyrus", "fireball_spellbook")
	await turn_to(sheet, "prometheus", 1)
	fireball = row_named(sheet, "Move_fireball")
	var learn: Button = fireball.find_child("Learn_fireball", true, false) if fireball != null else null
	ok(learn != null and "Fireball Spellbook" in learn.text, "with the book in Cyrus's bag, a Learn button names it",
		learn.text if learn != null else "none")
	if learn != null:
		learn.pressed.emit()
		await settle(2)
	ok(Campaign.knows_spell("prometheus", "fireball") and Campaign.count_of("cyrus", "fireball_spellbook") == 0,
		"pressed, he knows Fireball and the book is used up")
	fireball = row_named(sheet, "Move_fireball")
	ok(fireball != null and texts_under(fireball).any(func(text): return text.ends_with("known") or ", known" in text), "and the page says so",
		"%s" % [texts_under(fireball) if fireball != null else "no row"])
	Campaign.give_item("enfina", "crystalise_gate_nade")
	ok(Campaign.teachers_of("crystalise").size() == 1 and Campaign.learn_spell("prometheus", "crystalise") == ""
		and Campaign.knows_spell("prometheus", "crystalise") and Campaign.count_of("enfina", "crystalise_gate_nade") == 0,
		"a Gate Nade taken apart teaches its spell too")
	var played := {"skill_list": ["fire_blast", "fireball", "kindled_hound", "hack"]}
	Campaign.forget_unlearned(played, "prometheus")
	ok(played.skill_list == ["fire_blast", "fireball", "hack"], "fielded from the map, he has only what he has learned", "%s" % [played.skill_list])

	log_line("======== Levels: veiled past ΛΗΘΗ ========")
	await turn_to(sheet, "cyrus", 2)
	ok(row_named(sheet, "Level_1") != null and row_named(sheet, "Level_55") != null and row_named(sheet, "Level_56") == null,
		"levels 1 to 55, and nothing past them")
	var lethe := row_named(sheet, "Level_55")
	ok(lethe != null and texts_under(lethe).has("ΛΗΘΗ"), "ΛΗΘΗ beside 55")
	ok(row_named(sheet, "Veil") != null, "and a veil after it")
	var chapters: Array = headings_of(sheet).filter(func(text): return text.begins_with("Chapter"))
	ok(chapters == ["Chapter I", "Chapter II", "Chapter III", "Chapter IV"], "under the chapters they are reached in", "%s" % [chapters])
	var twenty_four := row_named(sheet, "Level_24")
	ok(twenty_four != null and texts_under(twenty_four).any(func(text): return "Cat Burglar II" in text)
		and row_named(sheet, "Level_1") != null and texts_under(row_named(sheet, "Level_1")).any(func(text): return "Cat Burglar I" in text),
		"Cat Burglar I at 1, Cat Burglar II at 24")
	ok(twenty_four != null and texts_under(twenty_four).any(func(text): return "Chooses a path" in text), "at 24, the path")
	var now := row_named(sheet, "Level_14")
	ok(now != null and is_equal_approx(now.modulate.a, 1.0) and row_named(sheet, "Level_20").modulate.a < 1.0,
		"the level they are at in full, what is to come dimmed")
	var grants := CharacterSheet.levels_of("prometheus")
	ok(grants.get(8, []).any(func(text): return "Hermes open" in text), "Prometheus: at 8 the Gates of Hermes open", "%s" % [grants.get(8, [])])
	# Under half a point a level, so not every level adds one.
	var adding: Array = grants.keys().filter(func(level): return level > 1 and grants[level].any(func(text): return text.begins_with("[color") and "+" in text and "health" in text))
	ok(grants.get(1, []).any(func(text): return "health" in text) and adding.size() == CombatantDatabase.combatants["prometheus"].hp_at(64) - CombatantDatabase.combatants["prometheus"].hp_at(1),
		"his health, and each level that adds to it - a point at a time", "%d levels" % adding.size())
	ok(not CharacterSheet.levels_of("enfina").values().any(func(lines): return lines.any(func(text): return "casting" in text))
		or CombatantDatabase.combatants["enfina"].casts_spells(), "nobody who casts nothing is told of castings")

	log_line("======== Chapter V: the rest uncovered ========")
	Campaign.begin_chapter(5)
	ok(Campaign.chapter == 5 and Campaign.levels_in_view() == Stats.MAX_LEVEL, "Chapter V shows every level")
	await turn_to(sheet, "cyrus", 2)
	var sixty_four := row_named(sheet, "Level_64")
	ok(sixty_four != null and texts_under(sixty_four).has("ΑΛΗΘΕΙΑ"), "ΑΛΗΘΕΙΑ beside 64")
	ok(Campaign.levels_unveiled, "the unveiling is played once, and remembered")
	ok(sixty_four != null and sixty_four.modulate.a < 0.05, "64 starts hidden", "%.2f" % (sixty_four.modulate.a if sixty_four != null else -1.0))
	# By the clock, not by frames: headless, a frame is over in no time at all.
	var waited := 0.0
	while sixty_four != null and sixty_four.modulate.a < 0.6 and waited < 10.0:
		await get_tree().create_timer(0.1, true, false, true).timeout
		waited += 0.1
	ok(sixty_four != null and sixty_four.modulate.a >= 0.6, "and comes out from under ΛΗΘΗ", "after %.1f seconds" % waited)
	await turn_to(sheet, "enfina", 2)
	ok(row_named(sheet, "Level_64") != null and row_named(sheet, "Level_64").modulate.a > 0.5, "the next time, it is simply there")

	log_line("======== Tab turns the page ========")
	await turn_to(sheet, "enfina", 0)
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.physical_keycode = KEY_TAB
	tab.pressed = true
	Input.parse_input_event(tab)
	await settle(2)
	ok(sheet._page == 1, "Tab: from the sheet to the moves", "%d" % sheet._page)
	sheet.close()
	sheet.queue_free()
	await settle(1)
