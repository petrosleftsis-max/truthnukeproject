extends Node
## Twenty levels reached at milestones, and the path each of the party takes at
## level 5: what a level hands out, how the party gets one, that the story's
## fights field the party at its own level, and choosing a path - on the map,
## on the sheet, and what it puts on them in a fight.

var LOG_PATH := HarnessLog.path_for("progression")
const AMBUSH := "res://data/encounters/encounter_01_ambush.tres"
const LAB_MAP := "res://maps/laboratory_explore.tscn"
const STAGE_MAP := "res://maps/stealth_stages/stealth_1.tscn"

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
	get_tree().create_timer(240.0, true, false, true).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	var booted = get_tree().current_scene
	if booted != null:
		booted.queue_free()
		await settle()
	await milestones()
	await story_fights()
	await choosing()
	await on_the_path()
	await on_the_map()
	await on_the_sheet()
	Campaign.asks_for_paths = false
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


func open_fight(encounter: EncounterDefinition) -> Node:
	Campaign.current_encounter = encounter
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(6)
	var combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(2)
	return game


func fighter(combat, key: String) -> Dictionary:
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == key:
			return comb
	return {}


## A copy of the ambush to change, so the one everything else loads is not.
func ambush_copy() -> EncounterDefinition:
	var encounter: EncounterDefinition = load(AMBUSH).duplicate()
	var spawns: Array[SpawnDefinition] = []
	for spawn in encounter.spawns:
		spawns.append(spawn.duplicate())
	encounter.spawns = spawns
	return encounter


func milestones():
	log_line("======== milestones ========")
	Campaign.reset()
	Campaign.set_party(["cyrus", "alithia"], 1)
	var cyrus: CombatantDefinition = CombatantDatabase.combatants.cyrus
	Campaign.party_state["cyrus"] = {"hp": 40, "max_hp": cyrus.hp_at(1), "alive": true}
	var heard := []
	var listening = func(level): heard.append(level)
	Campaign.party_leveled.connect(listening)
	ok(Campaign.reach_level(5), "the party can be taken to a level")
	ok(Campaign.party_level == 5 and heard == [5], "it is there, and says so", "%d %s" % [Campaign.party_level, heard])
	var gained := cyrus.hp_at(5) - cyrus.hp_at(1)
	ok(Campaign.party_state.cyrus.max_hp == cyrus.hp_at(5) and Campaign.party_state.cyrus.hp == 40 + gained,
		"health grows by what the level adds, wounds and all", "%d/%d" % [Campaign.party_state.cyrus.hp, Campaign.party_state.cyrus.max_hp])
	ok(not Campaign.reach_level(3) and Campaign.party_level == 5, "a milestone behind them changes nothing")
	Campaign.set_party(["cyrus", "alithia"], 2)
	ok(Campaign.party_level == 5, "and nor does walking onto a map written for earlier")
	Campaign.set_party(["cyrus", "alithia"], 8)
	ok(Campaign.party_level == 8 and heard == [5, 8], "a map written for later takes them there, as a milestone",
		"%d %s" % [Campaign.party_level, heard])
	Campaign.party_leveled.disconnect(listening)
	ok(not Campaign.reach_level(99) or Campaign.party_level == Stats.MAX_LEVEL, "and never past level 20", "%d" % Campaign.party_level)
	log_line("")

	log_line("======== a milestone fight ========")
	Campaign.reset()
	Campaign.set_party(["cyrus"], 1)
	Campaign.current_map = "res://maps/crossroads_explore.tscn"
	Campaign.return_to_position = true
	var encounter := ambush_copy()
	encounter.party_reaches_level = 4
	var game = await open_fight(encounter)
	var combat = game.get_node("VisualCombat")
	for comb in combat.combatants:
		if comb.side == 1 and comb.alive:
			comb.hp = 0
			combat.combatant_die(comb)
	await combat.combat_finish()
	await settle(3)
	ok(Campaign.party_level == 4, "winning it in the story takes the party to its level", "%d" % Campaign.party_level)
	game.queue_free()
	await settle(3)
	from_the_menu()
	game = await open_fight(encounter)
	combat = game.get_node("VisualCombat")
	for comb in combat.combatants:
		if comb.side == 1 and comb.alive:
			comb.hp = 0
			combat.combatant_die(comb)
	await combat.combat_finish()
	await settle(3)
	ok(Campaign.party_level == 1, "won from Battle Select, it changes nobody", "%d" % Campaign.party_level)
	game.queue_free()
	await settle(3)
	log_line("")


func story_fights():
	log_line("======== the story fields the party at its own level ========")
	Campaign.reset()
	Campaign.set_party(["cyrus"], 7)
	Campaign.current_map = "res://maps/crossroads_explore.tscn"
	Campaign.return_to_position = true
	var game = await open_fight(load(AMBUSH))
	var combat = game.get_node("VisualCombat")
	var cyrus := fighter(combat, "cyrus")
	ok(cyrus.level == 7 and cyrus.stats.self_stat == Stats.main_stat_at(7), "walked into from a map: the party's level, not the tile's",
		"level %d" % cyrus.level)
	ok(combat.combatants.filter(func(c): return c.side == 1).all(func(c): return c.level == 1),
		"the enemies are still the fight's own")
	game.queue_free()
	await settle(3)
	from_the_menu()
	game = await open_fight(load(AMBUSH))
	combat = game.get_node("VisualCombat")
	ok(fighter(combat, "cyrus").level == 1, "opened from Battle Select: the tile's level", "%d" % fighter(combat, "cyrus").level)
	game.queue_free()
	await settle(3)
	log_line("")


func choosing():
	log_line("======== the paths ========")
	var expected := {
		"cyrus": ["swashbuckler", "gunner", "bombardier"],
		"prometheus": ["spellsword", "demolitionist", "abjurer"],
		"alithia": ["punisher", "carer", "illusionist"],
		"enfina": ["berserker", "guardian", "controller"],
	}
	for key in expected:
		ok(SubclassDefinition.for_character(key) == expected[key], "%s's three, in order" % key,
			"%s" % [SubclassDefinition.for_character(key)])
	ok(SubclassDefinition.named("swashbuckler").description.contains("rapier"), "each with its description")
	log_line("")

	log_line("======== choosing one ========")
	Campaign.reset()
	Campaign.set_party(["cyrus", "alithia"], 4)
	ok(not Campaign.needs_path("cyrus") and Campaign.choosing_paths().is_empty(), "before level 5 nobody has one to choose")
	ok(not Campaign.choose_subclass("cyrus", "gunner"), "and cannot")
	Campaign.reach_level(5)
	ok(Campaign.choosing_paths() == ["cyrus", "alithia"], "at 5, everybody does, leader first", "%s" % [Campaign.choosing_paths()])
	ok(not Campaign.choose_subclass("cyrus", "carer"), "nobody takes somebody else's")
	ok(not Campaign.choose_subclass("cyrus", "nonsense"), "or one that does not exist")
	ok(Campaign.choose_subclass("cyrus", "gunner") and Campaign.subclass_of("cyrus") == "gunner", "Cyrus takes the Gunner's")
	ok(not Campaign.choose_subclass("cyrus", "swashbuckler") and Campaign.subclass_of("cyrus") == "gunner", "for good")
	ok(Campaign.choosing_paths() == ["alithia"], "which leaves Alithia")
	Campaign.reset()
	ok(Campaign.subclass_of("cyrus") == "", "until the party is started over")
	log_line("")


func on_the_path():
	log_line("======== on the path in a fight ========")
	# Something to see: a skill and two passives put on the Gunner's path for
	# the length of this, one passive coming in later than the other.
	var path := SubclassDefinition.named("gunner")
	var skills_were: Array[String] = path.skills.duplicate()
	var passives_were: Array[PassiveDefinition] = path.passives.duplicate()
	var spell := "fire_blast"
	var early := PassiveDefinition.new()
	early.name = "Early"
	var late := PassiveDefinition.new()
	late.name = "Late"
	late.required_level = 9
	path.skills.append(spell)
	path.passives.append(early)
	path.passives.append(late)

	Campaign.reset()
	Campaign.set_party(["cyrus"], 6)
	Campaign.choose_subclass("cyrus", "gunner")
	Campaign.current_map = "res://maps/crossroads_explore.tscn"
	Campaign.return_to_position = true
	var game = await open_fight(load(AMBUSH))
	var combat = game.get_node("VisualCombat")
	var cyrus := fighter(combat, "cyrus")
	ok(cyrus.get("subclass", "") == "gunner", "the story's Cyrus fights as a Gunner")
	ok(cyrus.skill_list.has(spell), "knowing what the path teaches")
	ok(cyrus.max_spell_slots != [0, 0, 0, 0], "and given gates, since the path taught him a spell", "%s" % [cyrus.max_spell_slots])
	ok(combat.active_passives(cyrus).has(early) and not combat.active_passives(cyrus).has(late),
		"with the path's passive for his level, and not the one for later")
	cyrus.level = 9
	ok(combat.active_passives(cyrus).has(late), "which comes in at its own level")
	game.queue_free()
	await settle(3)

	log_line("")
	log_line("======== from a spawn ========")
	from_the_menu()
	var encounter := ambush_copy()
	for spawn in encounter.spawns:
		if spawn.combatant_key == "cyrus":
			spawn.level = 6
			spawn.subclass = "gunner"
	game = await open_fight(encounter)
	combat = game.get_node("VisualCombat")
	cyrus = fighter(combat, "cyrus")
	ok(cyrus.get("subclass", "") == "gunner" and cyrus.skill_list.has(spell), "Battle Select puts him on the spawn's path")
	game.queue_free()
	await settle(3)
	for spawn in encounter.spawns:
		if spawn.combatant_key == "cyrus":
			spawn.level = 4
	game = await open_fight(encounter)
	combat = game.get_node("VisualCombat")
	ok(not fighter(combat, "cyrus").has("subclass") and not fighter(combat, "cyrus").skill_list.has(spell),
		"but not below level 5")
	game.queue_free()
	await settle(3)
	path.skills = skills_were
	path.passives = passives_were
	Campaign.reset()
	log_line("")


func on_the_map():
	log_line("======== asked on the map ========")
	Campaign.asks_for_paths = true
	Campaign.reset()
	Campaign.current_map = LAB_MAP
	var scene = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(scene)
	await settle(6)
	var picker: SubclassPicker = scene.picker
	ok(picker != null and picker.key == "cyrus", "arriving at level 10, the leader is asked first",
		picker.key if picker != null else "nobody asked")
	ok(get_tree().paused, "with the game held")
	if picker != null:
		var cards := picker.find_children("*", "PanelContainer", true, false).map(func(card): return String(card.name))
		ok(cards == ["swashbuckler", "gunner", "bombardier"], "his three side by side", "%s" % [cards])
		picker._on_choose("bombardier")
		ok(Campaign.subclass_of("cyrus") == "", "choosing asks once more before it is done")
		picker._on_take()
		await settle(4)
		ok(Campaign.subclass_of("cyrus") == "bombardier", "taken: Cyrus is a Bombardier")
		ok(scene.picker != null and scene.picker != picker and scene.picker.key == Campaign.party_order[1],
			"and the next of the party is asked", scene.picker.key if scene.picker != null else "nobody")
		for key in Campaign.choosing_paths():
			Campaign.choose_subclass(key, SubclassDefinition.for_character(key)[0])
		scene._on_path_chosen("", "")
		await settle(3)
	ok(not get_tree().paused, "everybody chosen, the game goes on")
	scene.queue_free()
	await settle(3)

	Campaign.reset()
	Campaign.current_map = STAGE_MAP
	scene = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(scene)
	await settle(6)
	ok(scene.picker == null and Campaign.party_level >= Stats.SUBCLASS_LEVEL, "a stealth stage, played on its own, asks nothing")
	scene.queue_free()
	await settle(3)
	Campaign.asks_for_paths = false
	log_line("")


func on_the_sheet():
	log_line("======== on the character sheet ========")
	Campaign.reset()
	Campaign.set_party(["cyrus", "alithia"], 6)
	Campaign.choose_subclass("alithia", "carer")
	var sheet: CharacterSheet = load("res://ui/character_sheet.gd").new()
	get_tree().root.add_child(sheet)
	await settle(2)
	sheet.open(false)
	await settle(2)
	ok(sheet._subtitle.text.contains("Level 6"), "it says the level", sheet._subtitle.text)
	ok(sheet._path_button.visible, "Cyrus has a path to choose, and a button for it")
	sheet._choose_path()
	await settle(2)
	ok(sheet.path_picker != null and sheet.path_picker.key == "cyrus", "which puts the choice up for him")
	sheet.path_picker.put_away.emit()
	await settle(2)
	ok(sheet.path_picker == null and Campaign.subclass_of("cyrus") == "", "and can be put away for later")
	sheet._index = 1
	sheet._show_entry()
	ok(sheet._subtitle.text.contains("Carer") and not sheet._path_button.visible, "Alithia's says her path", sheet._subtitle.text)
	sheet.close()
	sheet.queue_free()
	await settle(2)
	Campaign.reset()
	log_line("")


## A clean run with no map behind it - what the title screen leaves for Battle
## Select (Campaign.to_main_menu).
func from_the_menu():
	Campaign.reset()
	Campaign.current_map = ""
	Campaign.return_to_position = false
