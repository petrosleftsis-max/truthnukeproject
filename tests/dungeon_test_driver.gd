extends Node
## The dungeon demo: three fights one after another with the whole party at
## level 14, a short rest after each (since 2026-10-25) with their unused items
## kept. And a dungeon's own rests as the demo had them before: everybody back
## to full health, and - at one rest only - some of Prometheus's gates back,
## three points' worth at World 1, Hermes 2, Pandora 3.

const DUNGEON := "res://data/dungeons/dungeon_demo.tres"
const SEWER_MAP := "res://maps/crossroads_explore.tscn"
const LAB_MAP := "res://maps/laboratory_explore.tscn"

var LOG_PATH := HarnessLog.path_for("dungeon")

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
	await the_data()
	await swapping_the_fight()
	await going_in()
	await in_a_fight()
	await resting()
	await recovering_gates()
	await the_rest_panel()
	await after_a_fight()
	await stage_to_stage()
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


## Waits for a scene change to land on `path`.
func arrived_at(path: String, seconds: float = 4.0) -> bool:
	var waited := 0.0
	while waited < seconds:
		var scene = get_tree().current_scene
		if scene != null and scene.scene_file_path == path and scene.is_node_ready() and not SceneTransition.is_changing():
			await settle(4)
			return true
		await get_tree().process_frame
		waited += get_process_delta_time()
	return false


func enemies_of(fight: EncounterDefinition) -> Array:
	return fight.spawns.filter(func(spawn): return spawn.side == 1)


func party_tiles_of(fight: EncounterDefinition) -> Array:
	return fight.spawns.filter(func(spawn): return spawn.side == 0)


## A fight of `fight` on the battle scene, deployed and ready.
func open_fight(fight: EncounterDefinition) -> Node:
	Campaign.current_encounter = fight
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(6)
	return game


func fighter(game: Node, key: String) -> Dictionary:
	for comb in game.get_node("VisualCombat").combatants:
		if comb.get("combatant_key", "") == key:
			return comb
	return {}


## --- Sections ---


func the_data():
	log_line("======== the dungeon, and its fights ========")
	var dungeon: DungeonDefinition = load(DUNGEON)
	ok(dungeon != null and dungeon.stages.size() == 3, "three stages")
	ok(dungeon.party == ["cyrus", "alithia", "prometheus"] and dungeon.level == 14, "the party at level 14 - without Enfina, whom the sewer brings in")
	ok(dungeon.stages[0].map == SEWER_MAP and dungeon.stages[1].map == LAB_MAP and dungeon.stages[2].map == "",
		"the sewer to walk, then the lab, then the city fight gone straight into")
	ok(dungeon.short_rests and not dungeon.rest_revives, "a short rest between each fight (the designer, 2026-10-25)")
	ok(dungeon.gate_recovery_for.is_empty() and dungeon.gate_recoveries == 0,
		"no gate recovery of its own any more: Prometheus's Meditate is that now (the restcycle suite)")
	var sewer: EncounterDefinition = dungeon.stages[0].encounter
	var lab: EncounterDefinition = dungeon.stages[1].encounter
	var city: EncounterDefinition = dungeon.stages[2].encounter
	var story_sewer: EncounterDefinition = load("res://data/encounters/encounter_01_ambush.tres")
	var story_city: EncounterDefinition = load("res://data/encounters/encounter_03_watcher.tres")
	ok(enemies_of(sewer).size() == enemies_of(story_sewer).size() + 2, "the sewer has two more enemies than the story's",
		"%d against %d" % [enemies_of(sewer).size(), enemies_of(story_sewer).size()])
	ok(enemies_of(city).size() == enemies_of(story_city).size() - 3, "the city three fewer",
		"%d against %d" % [enemies_of(city).size(), enemies_of(story_city).size()])
	ok(enemies_of(story_sewer).size() == 5 and enemies_of(story_city).size() == 10 and story_sewer.victory_ends_the_run,
		"(and the story's own fights are as they were)")
	for fight in [sewer, lab, city]:
		ok(enemies_of(fight).all(func(spawn): return spawn.level == 14), "%s: every enemy at level 14" % fight.display_name)
		var tiles := party_tiles_of(fight)
		ok(tiles.size() == 4 and tiles.all(func(spawn): return spawn.level == 14 and spawn.starting_items.is_empty()),
			"%s: a tile for each of the four, at level 14, with nothing handed out" % fight.display_name)
		ok(not fight.victory_ends_the_run, "%s: winning it is not the end of the run" % fight.display_name)
	ok(sewer.victory_dialogue == story_sewer.victory_dialogue, "the sewer still ends on its own conversation")
	log_line("")


func swapping_the_fight():
	log_line("======== a map's fight, and the dungeon's ========")
	var dungeon: DungeonDefinition = load(DUNGEON)
	var story_sewer: EncounterDefinition = load("res://data/encounters/encounter_01_ambush.tres")
	var story_lab: EncounterDefinition = load("res://data/encounters/encounter_02_sappers.tres")
	Campaign.reset()
	Campaign.begin_battle_from_exploration(story_sewer, SEWER_MAP, Vector2.ZERO, "t")
	ok(Campaign.current_encounter == story_sewer, "outside a dungeon, the sewer's fight is the story's")
	Campaign.dungeon = dungeon
	Campaign.begin_battle_from_exploration(story_sewer, SEWER_MAP, Vector2.ZERO, "t")
	ok(Campaign.current_encounter == dungeon.stages[0].encounter, "in the dungeon, it is the dungeon's")
	Campaign.begin_battle_from_exploration(story_lab, LAB_MAP, Vector2.ZERO, "t")
	ok(Campaign.current_encounter == dungeon.stages[1].encounter, "and the lab's")
	Campaign.begin_battle_from_exploration(story_lab, SEWER_MAP, Vector2.ZERO, "t")
	ok(Campaign.current_encounter == story_lab, "a fight a stage does not stand in for is left alone")
	Campaign.reset()
	ok(not Campaign.in_dungeon(), "starting over ends it")
	log_line("")


func going_in():
	log_line("======== going in ========")
	Campaign.reset()
	Campaign.give_item("cyrus", "cure_potion")
	Campaign.start_dungeon(load(DUNGEON))
	ok(Campaign.in_dungeon() and Campaign.dungeon_stage == 0, "the dungeon is on, at its first stage")
	ok(Campaign.party_order == ["cyrus", "alithia", "prometheus"] and Campaign.party_level == 14,
		"Cyrus, Alithia and Prometheus, at level 14", "%s at %d" % [Campaign.party_order, Campaign.party_level])
	ok(Campaign.party_order.all(func(key): return Campaign.inventory_of(key).all(func(item): return item == "")),
		"carrying nothing")
	ok(Campaign.current_map == SEWER_MAP, "off to the sewer")
	ok(await arrived_at("res://scenes/exploration.tscn"), "walking it")
	var scene = get_tree().current_scene
	ok(Campaign.party_order.size() == 3 and Campaign.party_level == 14,
		"the sewer's own party - Cyrus alone, at level 1 - is not who walks it", "%s" % [Campaign.party_order])
	ok(Campaign.party_order.all(func(key): return Campaign.inventory_of(key).all(func(item): return item == "")),
		"and nobody has been handed anything")
	ok(scene.party != null and scene.party.followers.size() == 2, "the three of them on the map")
	var before_the_fight: String = FileAccess.get_file_as_string("res://dialogue/intro_sewer_before_encounter.dialogue")
	ok(before_the_fight.contains("do Campaign.add_member(\"enfina\")"), "Enfina joins in the conversation right before the fight")
	Campaign.add_member("enfina")
	ok(Campaign.party_order == ["cyrus", "alithia", "prometheus", "enfina"] and Campaign.party_level == 14,
		"walking fourth, at the party's level 14", "%s" % [Campaign.party_order])
	ok(Campaign.inventory_of("enfina").all(func(item): return item == ""), "carrying nothing either")
	scene.queue_free()
	await settle()
	log_line("")


func in_a_fight():
	log_line("======== a fight in the dungeon ========")
	var dungeon: DungeonDefinition = load(DUNGEON)
	Campaign.reset()
	Campaign.dungeon = dungeon
	Campaign.set_party(dungeon.party + ["enfina"], 14)
	Campaign.give_item("cyrus", "cure_potion")
	# A defence of their own on each of their tiles - the sewer's early numbers
	# are all the same - so whose tile each stood on shows.
	var sewer: EncounterDefinition = dungeon.stages[0].encounter.duplicate(true)
	var own := {"enfina": 32, "prometheus": 8, "cyrus": 21, "alithia": 19}
	for spawn in sewer.spawns:
		if spawn.side == 0 and own.has(spawn.combatant_key):
			spawn.defense = own[spawn.combatant_key]
	var game = await open_fight(sewer)
	var combat = game.get_node("VisualCombat")
	var heroes: Array = combat.combatants.filter(func(c): return c.side == 0)
	var foes: Array = combat.combatants.filter(func(c): return c.side == 1)
	ok(heroes.size() == 4 and heroes.all(func(c): return c.level == 14), "all four fight, at level 14", "%d" % heroes.size())
	var defences := {}
	for comb in heroes:
		defences[comb.combatant_key] = comb.stats.get("defense", -1)
	ok(defences == own, "each standing on the tile with their own numbers", "%s" % [defences])
	ok(foes.size() == 7 and foes.all(func(c): return c.level == 14), "against seven, at level 14", "%d" % foes.size())
	ok(Campaign.inventory_of("cyrus").has("cure_potion"), "with what they carried in")
	var prometheus := fighter(game, "prometheus")
	ok(not prometheus.is_empty() and prometheus.spell_slots.slice(0, 4) == [0, 4, 3, 2], "Prometheus with every gate to start",
		"%s" % [prometheus.get("spell_slots")])
	# The demo hands him every spell of his (Knows Every Spell), where the story
	# has him learn them from books.
	ok(dungeon.knows_every_spell and not prometheus.is_empty() and prometheus.skill_list.has("fireball")
		and prometheus.skill_list.has("kindled_hound") and prometheus.skill_list.has("illusory_dragon"),
		"and every spell of his, none of them learned from a book", "%s" % [prometheus.get("skill_list")])
	ok(Campaign.learned_spells.is_empty(), "knowing them without having learned them")
	prometheus.spell_slots = [0, 1, 0, 2]
	Campaign.record_party(combat.combatants)
	ok(Campaign.party_state.prometheus.spell_slots == [0, 1, 0, 2], "the gates he spent are remembered")
	game.queue_free()
	await settle(3)
	game = await open_fight(dungeon.stages[2].encounter)
	prometheus = fighter(game, "prometheus")
	ok(prometheus.get("spell_slots", []).slice(0, 4) == [0, 1, 0, 2], "and stay spent in the next fight",
		"%s" % [prometheus.get("spell_slots")])
	ok(Campaign.inventory_of("cyrus").has("cure_potion"), "the last fight, gone straight into, keeps their bags too")
	game.queue_free()
	await settle(3)
	Campaign.dungeon = null
	game = await open_fight(load("res://data/encounters/encounter_03_watcher.tres"))
	prometheus = fighter(game, "prometheus")
	ok(prometheus.get("spell_slots", []).slice(0, 4) == [0, 4, 3, 2], "outside a dungeon, every fight opens them all as ever",
		"%s" % [prometheus.get("spell_slots")])
	game.queue_free()
	await settle(3)
	Campaign.reset()
	log_line("")


## The demo as it was before its short rests (2026-10-25): a full rest that
## brings the fallen back, and one recovery of Prometheus's gates a run, three
## points, World 1, Hermes 2, Pandora 3 - kept to test the dungeon's own
## recovery, which any dungeon may still have.
func dungeon_with_spent(gates: Array) -> DungeonDefinition:
	var dungeon: DungeonDefinition = load(DUNGEON).duplicate()
	dungeon.short_rests = false
	dungeon.rest_revives = true
	dungeon.gate_recovery_for = ["prometheus"]
	dungeon.gate_recoveries = 1
	dungeon.gate_recovery_points = 3
	dungeon.gate_costs = [0, 1, 2, 3]
	Campaign.reset()
	Campaign.dungeon = dungeon
	Campaign.gate_recoveries_left = dungeon.gate_recoveries
	Campaign.set_party(dungeon.party + ["enfina"], 14)
	for key in Campaign.party_order:
		Campaign.party_state[key] = {"hp": 10, "max_hp": 80, "alive": true}
	Campaign.party_state.prometheus["spell_slots"] = gates.duplicate()
	Campaign.party_state.prometheus["max_spell_slots"] = [0, 3, 3, 2]
	return dungeon


func resting():
	log_line("======== the rest ========")
	dungeon_with_spent([0, 0, 0, 0])
	Campaign.party_state.enfina = {"hp": 0, "max_hp": 160, "alive": false}
	Campaign.give_item("alithia", "medicine")
	Campaign.rest_party()
	ok(Campaign.party_state.cyrus.hp == 80 and Campaign.party_state.prometheus.hp == 80, "everybody back to full health")
	ok(Campaign.party_state.enfina.alive and Campaign.party_state.enfina.hp == 160, "the fallen up again, at full")
	ok(Campaign.inventory_of("alithia").has("medicine"), "and what nobody used still carried")
	ok(Campaign.party_state.prometheus.spell_slots == [0, 0, 0, 0], "resting does not bring gates back")
	Campaign.reset()
	log_line("")


func recovering_gates():
	log_line("======== Prometheus's gates ========")
	dungeon_with_spent([0, 0, 0, 0])
	ok(Campaign.can_recover_gates("prometheus"), "spent, his can be brought back")
	ok(not Campaign.can_recover_gates("alithia"), "nobody else's")
	ok(Campaign.gate_recovery_cost([0, 1, 1, 0]) == 3 and Campaign.gate_recovery_cost([0, 3, 0, 0]) == 3
		and Campaign.gate_recovery_cost([0, 0, 0, 1]) == 3, "a World and a Hermes, three Worlds, or a Pandora: three points each")
	ok(not Campaign.recover_gates("prometheus", [0, 2, 1, 0]), "four points' worth is too much")
	ok(not Campaign.recover_gates("prometheus", [0, 0, 0, 0]), "nothing is not a recovery")
	ok(Campaign.recover_gates("prometheus", [0, 1, 1, 0]), "a World and a Hermes")
	ok(Campaign.gates_left("prometheus") == [0, 1, 1, 0], "come back", "%s" % [Campaign.gates_left("prometheus")])
	ok(not Campaign.can_recover_gates("prometheus") and not Campaign.recover_gates("prometheus", [0, 1, 0, 0]),
		"and that was the one rest that could")
	dungeon_with_spent([0, 3, 3, 1])
	ok(not Campaign.recover_gates("prometheus", [0, 1, 0, 0]), "a gate not spent cannot be had back")
	ok(Campaign.recover_gates("prometheus", [0, 0, 0, 1]), "one that was can")
	dungeon_with_spent([0, 3, 3, 2])
	ok(not Campaign.can_recover_gates("prometheus"), "nothing spent, nothing is offered")
	Campaign.reset()
	log_line("")


func the_rest_panel():
	log_line("======== what the rest says ========")
	dungeon_with_spent([0, 1, 0, 2])
	var panel := RestPanel.new()
	add_child(panel)
	await settle(2)
	ok(panel.offered_to == "prometheus", "it offers Prometheus's gates")
	var question = panel.find_child("Question", true, false)
	var terms = panel.find_child("Terms", true, false)
	ok(question != null and question.text == "Recover Prometheus's gates?", "asking", question.text if question != null else "")
	ok(terms != null and terms.text.contains("3 points") and terms.text.contains("World costs 1")
		and terms.text.contains("Hermes costs 2") and terms.text.contains("Pandora costs 3"),
		"what it has to spend and what each costs", terms.text if terms != null else "")
	ok(terms != null and terms.text.contains("only one rest"), "and that it is one rest in the whole dungeon")
	panel.change(1, 1)
	panel.change(1, 1)
	panel.change(1, 1)
	ok(panel.chosen[1] == 2, "only as many Worlds as were spent", "%d" % panel.chosen[1])
	panel.change(3, 1)
	ok(panel.chosen[3] == 0, "no Pandora he did not spend")
	panel.change(1, -1)
	panel.change(2, 1)
	ok(panel.chosen == [0, 1, 1, 0] and panel.points_left() == 0, "a World and a Hermes: all three points")
	panel.change(1, 1)
	ok(panel.chosen[1] == 1, "and nothing more once they are spent")
	ok(panel.recover(), "Recover gates")
	ok(Campaign.gates_left("prometheus") == [0, 2, 1, 2], "gives them back", "%s" % [Campaign.gates_left("prometheus")])
	var done = panel.find_child("Recovered", true, false)
	ok(done != null and done.text.contains("World 2/3"), "and says so", done.text if done != null else "")
	var went := [false]
	panel.continued.connect(func(): went[0] = true)
	(panel.find_child("Continue", true, false) as Button).pressed.emit()
	ok(went[0], "Continue goes on")
	var left := [false]
	panel.left_for_menu.connect(func(): left[0] = true)
	var menu := panel.find_child("MainMenu", true, false) as Button
	if menu != null:
		menu.pressed.emit()
	ok(menu != null and left[0], "and Main Menu leaves for the title screen")
	panel.queue_free()
	await settle()
	var later := RestPanel.new()
	add_child(later)
	await settle(2)
	ok(later.offered_to == "prometheus" and later.meditating, "the next rest offers nothing of the dungeon's - only his own Meditate",
		"%s, meditating %s" % [later.offered_to, later.meditating])
	later.queue_free()
	Campaign.reset()
	await settle()
	log_line("")


func after_a_fight():
	log_line("======== after a fight ========")
	var dungeon: DungeonDefinition = load(DUNGEON)
	Campaign.reset()
	Campaign.dungeon = dungeon
	Campaign.set_party(dungeon.party + ["enfina"], 14)
	var game = await open_fight(dungeon.stages[0].encounter)
	var result = game.get_node("ResultUI")
	result._won = true
	Campaign.party_state.cyrus = {"hp": 5, "max_hp": 90, "alive": true}
	result._show_panel()
	await settle(2)
	ok(result.rest != null and result.rest.is_visible_in_tree() and not result.get_node("Panel").visible,
		"won, and not the last: a rest, not the result")
	ok(Campaign.party_state.cyrus.hp == 5 + roundi(85 * Campaign.SHORT_REST_MENDS), "a short one, which has given him back half of what he lost",
		"%d of 90" % Campaign.party_state.cyrus.hp)
	result.rest.queue_free()
	game.queue_free()
	await settle(3)
	Campaign.dungeon_stage = 2
	game = await open_fight(dungeon.stages[2].encounter)
	result = game.get_node("ResultUI")
	var combat = game.get_node("VisualCombat")
	combat.groups[Combat.Group.ENEMIES].clear()
	result._on_combat_finished()
	await settle(2)
	ok(result.get_node("Panel").visible and result.rest == null, "the last won: the result")
	ok(result.get_node("Panel/VBox/Title").text == "The Dungeon Demo cleared", "saying it is over",
		result.get_node("Panel/VBox/Title").text)
	ok(result.get_node("Panel/VBox/BackButton").visible and result.get_node("Panel/VBox/BackButton").text == "Finish", "with Finish")
	game.queue_free()
	await settle(3)
	game = await open_fight(dungeon.stages[1].encounter)
	result = game.get_node("ResultUI")
	combat = game.get_node("VisualCombat")
	combat.groups[Combat.Group.PLAYERS].clear()
	result._on_combat_finished()
	await settle(2)
	ok(result.get_node("Panel/VBox/BackButton").text == "Start the dungeon again", "lost: start again from the top")
	game.queue_free()
	await settle(3)
	Campaign.reset()
	log_line("")


func stage_to_stage():
	log_line("======== one stage to the next ========")
	var dungeon: DungeonDefinition = load(DUNGEON)
	Campaign.reset()
	Campaign.dungeon = dungeon
	Campaign.set_party(dungeon.party + ["enfina"], 14)
	Campaign.give_item("enfina", "medicine")
	Campaign.next_dungeon_stage()
	ok(Campaign.dungeon_stage == 1 and Campaign.current_map == LAB_MAP and not Campaign.return_to_position,
		"after the sewer, the lab - walked in at its start")
	ok(await arrived_at("res://scenes/exploration.tscn"), "walking it")
	ok(Campaign.party_order.size() == 4 and Campaign.inventory_of("enfina").has("medicine")
		and not Campaign.inventory_of("cyrus").has("cure_potion"),
		"the dungeon's party, with what they had - not the lab's own kit")
	var pause = get_tree().current_scene.get_node("PauseUI")
	pause._show_panel(pause.get_node("PausePanel"), pause._pause_buttons)
	await settle()
	ok(not pause.get_node("PausePanel/VBox/LevelSelectButton").visible, "no Level Select from the pause menu in a dungeon")
	pause._close()
	Campaign.next_dungeon_stage()
	ok(Campaign.dungeon_stage == 2 and Campaign.current_map == "" and Campaign.current_encounter == dungeon.stages[2].encounter,
		"after the lab, straight into the city fight")
	ok(await arrived_at("res://scenes/game.tscn", 10.0), "there", "%s" % [get_tree().current_scene.scene_file_path if get_tree().current_scene != null else "nothing"])
	Campaign.next_dungeon_stage()
	ok(not Campaign.in_dungeon(), "after the last, it is over")
	ok(await arrived_at("res://scenes/main_menu.tscn"), "back at the title screen")
	var menu = get_tree().current_scene
	var note = menu.find_child("Note", true, false)
	ok(note != null and note.visible and note.text == "The Dungeon Demo cleared.", "saying so", note.text if note != null else "")
	var button: Button = null
	for found in menu.find_children("*", "Button", true, false):
		if found.text == "Dungeon Demo":
			button = found
	ok(button != null, "where Dungeon Demo starts it again")
	log_line("")
