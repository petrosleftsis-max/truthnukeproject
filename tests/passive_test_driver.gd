extends Node
## Passive skills: what somebody does without being asked. The Mimic's trick is
## one, it is what actually lets the Mimic cast, it never turns up on a panel,
## and the character sheet reads it out.

var LOG_PATH := HarnessLog.path_for("passive")

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


## Every piece of text drawn under `node`, so a row can be read the way a player
## would read it.
func texts_under(node: Node) -> Array:
	var found = []
	if node is Label:
		found.append(node.text)
	for child in node.get_children():
		found.append_array(texts_under(child))
	return found


## Every tooltip on something under `node`: what hovering it would say.
func tooltips_under(node: Node) -> Array:
	var found = []
	if node is Control and node.tooltip_text != "":
		found.append(node.tooltip_text)
	for child in node.get_children():
		found.append_array(tooltips_under(child))
	return found


## The sheet's row headed `heading`, or null when it has none.
func row_headed(sheet: CharacterSheet, heading: String) -> Node:
	for row in sheet._stat_rows.get_children():
		if row.get_child_count() > 0 and row.get_child(0) is Label and row.get_child(0).text == heading:
			return row
	return null


func run_test():
	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_01_ambush.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	var combat: Combat = game.get_node("VisualCombat")
	var sheet: CharacterSheet = game.get_node("CharacterSheet")
	combat.finish_deployment()
	await get_tree().process_frame

	log_line("======== the Mimic's trick is a passive ========")
	var definition: CombatantDefinition = CombatantDatabase.combatants["mimic"]
	ok(definition.passives.size() == 1, "the Mimic has one passive", "%d" % definition.passives.size())
	var mimicry: PassiveDefinition = definition.passives[0] if definition.passives.size() > 0 else null
	ok(mimicry != null and mimicry.name == "Mimicry", "called Mimicry", mimicry.name if mimicry else "none")
	if mimicry == null:
		log_line("FAILURES: %d" % _fail)
		get_tree().quit(1)
		return
	ok(mimicry.description != "", "which says what it does")
	ok(mimicry.active_when == PassiveDefinition.ActiveWhen.ALWAYS, "and is always working")
	ok(mimicry.casts_without_gates, "and is what lets it cast without gates")
	# The switch used to sit on the character. Two places saying the same thing
	# is how they come to disagree, so it lives on the passive alone.
	var still_on_character = false
	for property in definition.get_property_list():
		if property.name == "casts_without_gates":
			still_on_character = true
	ok(not still_on_character, "the old switch on the character itself is gone")
	log_line("")

	log_line("======== it is what actually lets the Mimic cast ========")
	var mimic: Dictionary = {}
	var player: Dictionary = {}
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == "mimic" and mimic.is_empty():
			mimic = comb
		elif comb.side == 0 and player.is_empty():
			player = comb
	ok(not mimic.is_empty(), "the encounter fields a Mimic")
	ok(not player.is_empty(), "and somebody on the player's side")
	var spell: SkillDefinition = SkillDatabase.skills["fireball"]
	ok(spell.spell_slot_level == 3, "Fireball is cast through the deepest gate", "%d" % spell.spell_slot_level)
	ok(mimic.get("passives", []).has(mimicry), "the Mimic in the fight carries it")
	mimic.spell_slots = [0, 0, 0, 0]
	ok(combat.can_afford_skill(mimic, spell), "with no gates at all it can still pay for Fireball")
	ok(combat.spend_slot_for(mimic, spell) == 0, "and pays nothing", "%s" % [mimic.spell_slots])
	var player_slots = player.spell_slots.duplicate()
	player.spell_slots = [0, 0, 0, 0]
	ok(player.get("passives", []).is_empty(), "%s has no passive" % player.name)
	ok(not combat.can_afford_skill(player, spell), "so with no gates %s cannot" % player.name)
	player.spell_slots = player_slots
	log_line("")

	log_line("======== a passive is never something to press ========")
	ok(combat.main_skills_of(mimic).is_empty() and combat.secondary_skills_of(mimic).is_empty()
		and combat.spell_skills_of(mimic).is_empty(), "the Mimic's panels are empty")
	# Given to somebody who does have a kit, it adds nothing to any of it.
	var before = [combat.main_skills_of(player), combat.secondary_skills_of(player), combat.spell_skills_of(player)]
	player["passives"] = [mimicry]
	var after = [combat.main_skills_of(player), combat.secondary_skills_of(player), combat.spell_skills_of(player)]
	ok(before == after, "handing %s a passive leaves every panel as it was" % player.name)
	player["passives"] = []
	log_line("")

	log_line("======== one that waits works only while its moment holds ========")
	var guarded := PassiveDefinition.new()
	guarded.name = "Last Stand"
	guarded.description = "Opens every gate once they are badly hurt."
	guarded.active_when = PassiveDefinition.ActiveWhen.BELOW_HALF_HEALTH
	guarded.casts_without_gates = true
	var full_hp = combat.get_effective_stat(player, "max_hp")
	var hp_was = player.hp
	player["passives"] = [guarded]
	player.spell_slots = [0, 0, 0, 0]
	player.hp = full_hp
	ok(not combat.passive_is_active(player, guarded), "at full health it is not working", "%d/%d" % [player.hp, full_hp])
	ok(not combat.can_afford_skill(player, spell), "so what it grants is not granted")
	player.hp = full_hp / 2 + 1
	ok(not combat.passive_is_active(player, guarded), "nor just above half", "%d/%d" % [player.hp, full_hp])
	player.hp = full_hp / 2
	ok(combat.passive_is_active(player, guarded), "at half it is", "%d/%d" % [player.hp, full_hp])
	ok(combat.can_afford_skill(player, spell), "and what it grants is")
	log_line("")

	log_line("======== the sheet reads it out ========")
	sheet.open_on(player.name)
	await get_tree().process_frame
	var row = row_headed(sheet, "Passive Skills")
	ok(row != null, "a player's passive gets a row of its own", player.name)
	if row != null:
		var said = " / ".join(texts_under(row))
		ok(said.contains("Last Stand"), "naming it", said)
		ok(said.contains("Active now"), "and saying it is working at half health")
		var hovered = " / ".join(tooltips_under(row)).replace("\n", " ")
		ok(hovered.contains(guarded.describe_when()), "with what it waits on in its tooltip", hovered)
	sheet.close()
	player.hp = full_hp
	sheet.open_on(player.name)
	await get_tree().process_frame
	row = row_headed(sheet, "Passive Skills")
	if row != null:
		ok(" / ".join(texts_under(row)).contains("Not active"), "and that it is not, at full health")
	sheet.close()
	player.hp = hp_was
	player.spell_slots = player_slots
	player["passives"] = []

	sheet.open_on(player.name)
	await get_tree().process_frame
	ok(row_headed(sheet, "Passive Skills") == null, "nobody without one gets an empty row", player.name)
	sheet.close()

	# An enemy's sheet is only there once somebody has studied them.
	mimic["studied"] = true
	sheet.open_on(mimic.name)
	await get_tree().process_frame
	ok(sheet._title.text == mimic.name, "the studied Mimic's sheet is open", sheet._title.text)
	row = row_headed(sheet, "Passive Skills")
	ok(row != null, "with a Passive Skills row")
	if row != null:
		var said = " / ".join(texts_under(row))
		ok(said.contains("Mimicry"), "naming Mimicry", said)
		ok(said.contains("Always active"), "saying it is always working")
		ok(not said.contains("Active now"), "without saying twice that it is on")
		# What it does is a hover away rather than written out: a paragraph per
		# passive swamps the sheet once a character has a few.
		ok(not said.contains(mimicry.description), "what it does is not written out on the sheet")
		var hovered = " / ".join(tooltips_under(row)).replace("\n", " ")
		ok(hovered.contains(mimicry.description), "but hovering it says, in full", hovered)
	ok(row_headed(sheet, "Skills") == null, "and no Skills row, since it has nothing to press")
	sheet.close()
	MenuPause.clear(get_tree())
	log_line("")

	log_line("======== the map's sheet reads them off the database ========")
	game.queue_free()
	await get_tree().process_frame
	var loose = CharacterSheet.new()
	get_tree().root.add_child(loose)
	await get_tree().process_frame
	Campaign.reset()
	Campaign.seed_party(["mimic"])
	loose.open()
	row = row_headed(loose, "Passive Skills")
	ok(row != null, "opened with no battle running, the row is still there")
	if row != null:
		var said = " / ".join(texts_under(row))
		ok(said.contains("Mimicry") and said.contains("Always active"), "with the passive and when it works", said)
	loose.close()
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
