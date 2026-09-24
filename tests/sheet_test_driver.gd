extends Node
## The character sheet: what C opens, who it opens on, and stepping through
## the rest of the party.

var LOG_PATH := HarnessLog.path_for("sheet")

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


## Sends a key the way the window would, so the toggle is exercised through
## the same path a player uses rather than by calling toggle() directly.
func press(keycode: int):
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	await get_tree().process_frame


func run_test():
	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_01_ambush.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	var sheet = game.get_node("CharacterSheet")
	combat.finish_deployment()
	await get_tree().process_frame

	log_line("======== it is wired into the battle ========")
	ok(sheet != null, "the battle scene has a character sheet")
	ok(sheet.combat == combat, "and it can see Combat")
	ok(not sheet.is_open(), "closed to begin with")
	ok(not sheet._root.visible, "and nothing is drawn")
	log_line("")

	log_line("======== C opens and closes it ========")
	await press(KEY_C)
	ok(sheet.is_open(), "C opens it")
	ok(sheet._root.visible, "and it is drawn")
	await press(KEY_C)
	ok(not sheet.is_open(), "C again closes it")
	ok(not sheet._root.visible, "and it is gone")
	await press(KEY_C)
	ok(sheet.is_open(), "reopened for the rest of these")
	await press(KEY_ESCAPE)
	ok(not sheet.is_open(), "Escape closes it too")
	log_line("")

	log_line("======== it opens on whoever is acting ========")
	var players = []
	for comb in combat.combatants:
		if comb.side == 0 and comb.alive:
			players.append(comb)
	ok(players.size() > 0, "the encounter has player combatants", "%d" % players.size())
	# Force the turn onto the last of them and check the sheet follows.
	var last = players[players.size() - 1]
	combat.current_combatant = combat.combatants.find(last)
	sheet.open()
	ok(sheet._title.text == last.name, "opens on the combatant whose turn it is",
		"'%s' vs '%s'" % [sheet._title.text, last.name])
	log_line("")

	log_line("======== everyone on the player's side is listed ========")
	ok(sheet._entries.size() == players.size(), "one entry per living ally",
		"%d entries, %d allies" % [sheet._entries.size(), players.size()])
	var enemies_listed = false
	for entry in sheet._entries:
		for comb in combat.combatants:
			if comb.name == entry.name and comb.side == 1:
				enemies_listed = true
	ok(not enemies_listed, "and no enemies among them")
	log_line("")

	log_line("======== the buttons step between them ========")
	if players.size() > 1:
		ok(sheet._members.visible, "a button row is shown when there is company")
		ok(sheet._members.get_child_count() == players.size(), "one button each",
			"%d" % sheet._members.get_child_count())
		var other = 0 if sheet._index != 0 else 1
		var other_name = sheet._entries[other].name
		sheet._on_member_pressed(other)
		ok(sheet._title.text == other_name, "pressing one shows that character",
			"'%s'" % sheet._title.text)
	else:
		ok(not sheet._members.visible, "no button row for a party of one")
	log_line("")

	log_line("======== the numbers shown are theirs ========")
	var shown = sheet._entries[sheet._index]
	var source = null
	for comb in combat.combatants:
		if comb.name == shown.name:
			source = comb
	ok(source != null, "the entry maps back to a real combatant")
	if source != null:
		ok(shown.level == source.get("level", 1), "level matches", "%d" % shown.level)
		ok(shown.hp == source.hp, "health matches", "%d" % shown.hp)
		ok(shown.stats == source.stats, "and every attribute matches", "%s" % [shown.stats])
	# The five attributes, the weapon base, and what Study adds for anyone it
	# has opened up - movement, resistances, skills.
	ok(sheet._stat_rows.get_child_count() >= 6, "a row per number it knows",
		"%d" % sheet._stat_rows.get_child_count())
	log_line("")

	log_line("======== the portrait shows something ========")
	ok(sheet._animated.visible or sheet._still.visible, "either the animation or the still is up")
	if sheet._animated.visible:
		ok(sheet._animated.sprite_frames != null, "the animation has frames")
		ok(sheet._animated.animation == "idle", "and it is the idle one", sheet._animated.animation)
	log_line("")

	log_line("======== the sheet Study opens holds the game too ========")
	# Study costs an action and its whole payoff is the reading, so the reading
	# gets the same quiet pressing C gets. It used to arrive unpaused on the
	# grounds that the skill was still resolving.
	sheet.close()
	MenuPause.clear(get_tree())
	await get_tree().process_frame
	ok(not get_tree().paused, "the game is running before anybody studies anything")
	var studied = ""
	for comb in combat.combatants:
		if comb.alive:
			studied = comb.name
			break
	sheet.open_on(studied)
	await get_tree().process_frame
	ok(sheet._open, "the sheet is up", studied)
	ok(get_tree().paused, "and the game is held while it is read")
	# It has to be closable while the tree is paused, or the hold is a deadlock.
	ok(sheet.process_mode == Node.PROCESS_MODE_ALWAYS,
		"the panel itself still runs, so it can be closed again",
		"%d" % sheet.process_mode)
	sheet.close()
	await get_tree().process_frame
	ok(not get_tree().paused, "and closing it lets the game carry on")
	log_line("")

	log_line("======== a contest that carries no damage does not promise half of it ========")
	# A graze keeps the damage at half and drops everything else, so a skill
	# with no damage in it does nothing at all to whoever shrugs it off.
	var ui = game.get_node("CanvasLayer/UI")
	var harmless: SkillDefinition = null
	var harmful: SkillDefinition = null
	for key in SkillDatabase.skills:
		var skill: SkillDefinition = SkillDatabase.skills[key]
		if not skill.uses_stat_contest:
			continue
		var hurts := false
		for effect in skill.all_effects():
			if effect != null and effect.type == EffectDefinition.EffectType.DAMAGE:
				hurts = true
		if hurts and harmful == null:
			harmful = skill
		elif not hurts and harmless == null:
			harmless = skill
	if harmless == null:
		log_line("  NOTE  every contested skill in the game deals damage, so there is nothing to check here")
	else:
		var said = ui.build_skill_tooltip(harmless, combat.combatants[0])
		ok(not said.contains("half damage"),
			"%s does not mention half damage" % harmless.name,
			"%s" % [said.split("
")])
		ok(said.contains("shrugs it off"), "and says what really happens instead")
	if harmful != null:
		var said = ui.build_skill_tooltip(harmful, combat.combatants[0])
		ok(said.contains("half damage"),
			"while %s, which does deal damage, still says so" % harmful.name)
	log_line("")

	log_line("======== exploration falls back to the roster ========")
	sheet.close()
	game.queue_free()
	await get_tree().process_frame
	var loose = CharacterSheet.new()
	get_tree().root.add_child(loose)
	await get_tree().process_frame
	Campaign.seed_party(["cyrus", "enfina", "prometheus"])
	loose.open()
	ok(loose.is_open(), "it opens with no Combat node at all")
	ok(loose._entries.size() == Campaign.party_members().size(), "one entry per party member",
		"%d" % loose._entries.size())
	if not loose._entries.is_empty():
		ok(loose._title.text == Campaign.party_members()[0].name, "opening on the leader",
			"'%s'" % loose._title.text)
		ok(loose._entries[0].stats.size() == 5, "with a full set of attributes",
			"%s" % [loose._entries[0].stats])
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
