extends Node
## Steal: Cyrus lifts everything an enemy has to hand and keeps it. And enemies
## handed things to carry by their encounter - which is what there is to steal.

var LOG_PATH := HarnessLog.path_for("steal")
const WATCHER := "res://data/encounters/encounter_03_watcher.tres"

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
	await the_skill()
	await in_a_fight()
	await handed_out_by_the_encounter()
	await the_editor()
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


## Hands `who` the turn, with nothing in the way of acting.
func give_turn(combat, who: Dictionary):
	combat.current_combatant = combat.combatants.find(who)
	combat.controller.set_controlled_combatant(who)
	combat.controller.player_turn = true
	combat.controller.action_locked = false
	who.skill_used_this_turn = false
	who.secondary_used_this_turn = false


## Moves `who` to `tile` on the board.
func put(combat, who: Dictionary, tile: Vector2i):
	var from: Vector2i = who.position
	who.position = tile
	who.sprite.position = combat.controller.tile_map.map_to_local(tile)
	combat.controller.reposition_combatant(from, tile)


## A free tile beside `tile` that anybody can stand on.
func free_beside(combat, tile: Vector2i, movement_class: int) -> Vector2i:
	for way in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var there: Vector2i = tile + way
		if combat.controller.is_in_bounds(there) and combat.get_combatant_at(there).is_empty() \
				and not combat.controller.is_tile_blocking(there, movement_class):
			return there
	return Vector2i(-1, -1)


## Everything said in the combat log while `work` runs.
func heard_during(combat, work: Callable) -> String:
	var heard: Array = []
	var listening = func(text): heard.append(text)
	combat.update_information.connect(listening)
	await work.call()
	await settle(3)
	combat.update_information.disconnect(listening)
	return "".join(heard)


func the_skill():
	log_line("======== the skill ========")
	var skill: SkillDefinition = SkillDatabase.skills.get("steal")
	ok(skill != null and skill.name == "Steal", "there is a Steal")
	ok(skill != null and Combat.steals(skill) and not skill.targets_ally, "it takes things off an enemy")
	ok(skill != null and skill.spell_slot_level == 0 and skill.required_level == 1 and not skill.is_secondary,
		"a main action, through no gate, from the start")
	ok(skill != null and skill.min_range == 1 and skill.max_range == 1, "from right beside them")
	ok(skill != null and not skill.can_be_copied, "and the Mimic cannot copy it")
	ok(CombatantDatabase.combatants.cyrus.skills.has("steal"), "and it is Cyrus's")
	log_line("")


func in_a_fight():
	Campaign.reset()
	var game = await open_fight(load(WATCHER))
	var combat = game.get_node("VisualCombat")
	var controller = combat.controller
	var ui = combat.game_ui
	var skill: SkillDefinition = SkillDatabase.skills.steal
	var cyrus := fighter(combat, "cyrus")
	var enemies: Array = combat.combatants.filter(func(c): return c.side == 1 and c.alive)
	var mark: Dictionary = enemies[0]
	var empty_handed: Dictionary = enemies[1]
	for foe in enemies:
		foe["pocket"] = []
	Campaign.set_inventory("cyrus", ["cure_potion"])

	log_line("======== nobody carrying anything ========")
	ok(combat.wasted_on(cyrus, skill) != "", "with no enemy carrying anything, it would do nothing, and says so",
		combat.wasted_on(cyrus, skill))
	mark["pocket"] = ["mediocre_cure_potion", "medium_bomb", "medicine"]
	ok(combat.wasted_on(cyrus, skill) == "", "one enemy with something on them is enough")

	log_line("")
	log_line("======== aiming ========")
	put(combat, mark, free_beside(combat, cyrus.position, mark.movement_class))
	put(combat, empty_handed, free_beside(combat, cyrus.position, empty_handed.movement_class))
	await settle(2)
	give_turn(combat, cyrus)
	controller.set_selected_skill("steal")
	controller.begin_target_selection()
	await settle(2)
	ok(controller.refusal_at(mark.position, mark) == "", "aimed at the enemy with something on them, it can go",
		controller.refusal_at(mark.position, mark))
	var refusal: String = controller.refusal_at(empty_handed.position, empty_handed)
	ok(refusal.contains("nothing on them to steal"), "an enemy with nothing on them cannot be picked", refusal)
	ok(controller.pad_tiles() == [mark.position], "a pad goes straight to the one worth robbing", "%s" % [controller.pad_tiles()])
	ok(ui.describe_effect(skill.effects[0]).contains("every item"), "its tooltip says it takes everything",
		ui.describe_effect(skill.effects[0]))
	controller._preview_hits(mark.position)
	var said_over := texts_in(ui._hit_preview)
	ok(ui._hit_preview.visible and said_over.contains("Medium Bomb") and said_over.contains("Medicine"),
		"hovering the enemy with something on them shows what they carry", said_over)
	controller._preview_hits(empty_handed.position)
	said_over = texts_in(ui._hit_preview)
	ok(ui._hit_preview.visible and said_over.contains("Carries nothing") and said_over.contains("nothing on them to steal"),
		"and the empty-handed one says so, and why it cannot go", said_over)
	var far_foe: Dictionary = enemies[2] if enemies.size() > 2 else {}
	if not far_foe.is_empty():
		far_foe["pocket"] = ["frost_bottle"]
		controller._preview_hits(far_foe.position)
		said_over = texts_in(ui._hit_preview)
		ok(ui._hit_preview.visible and said_over.contains("Frost Bottle"), "somebody out of reach can still be looked over", said_over)
		far_foe["pocket"] = []
	controller.cancel_skill_selection()

	log_line("")
	log_line("======== lifted ========")
	var said := await heard_during(combat, func(): await combat.use_skill("steal", cyrus, mark.position, false))
	ok(mark.pocket.is_empty(), "the enemy has nothing left", "%s" % [mark.pocket])
	ok(combat.items_of(cyrus) == ["cure_potion", "mediocre_cure_potion", "medium_bomb", "medicine"],
		"and Cyrus has all of it to hand, after what he had", "%s" % [combat.items_of(cyrus)])
	ok(said.contains("Medium Bomb") and said.contains(mark.name), "the log says what he took and from whom", said.strip_edges())
	ok(combat.wasted_on(cyrus, skill) != "", "and now there is nothing left anywhere to steal")

	log_line("")
	log_line("======== what was stolen is his ========")
	give_turn(combat, cyrus)
	cyrus.hp = maxi(1, cyrus.max_hp / 2)
	var hp_before: int = cyrus.hp
	await combat.use_skill("mediocre_cure_potion", cyrus, cyrus.position, false)
	await settle(3)
	ok(cyrus.hp > hp_before and Campaign.count_of("cyrus", "mediocre_cure_potion") == 0,
		"a stolen potion drinks like his own", "%d -> %d" % [hp_before, cyrus.hp])

	log_line("")
	log_line("======== hands full ========")
	Campaign.set_inventory("cyrus", ["cure_potion", "tiny_bomb", "medicine", "poison_bottle"])
	mark["pocket"] = ["medium_bomb", "frost_bottle"]
	give_turn(combat, cyrus)
	said = await heard_during(combat, func(): await combat.use_skill("steal", cyrus, mark.position, false))
	var bag: Array = Campaign.inventory_of("cyrus")
	ok(mark.pocket.is_empty() and bag[4] == "medium_bomb" and bag[5] == "frost_bottle",
		"with his front slots full, what he lifts goes in the bag", "%s" % [bag])
	ok(not combat.items_of(cyrus).has("medium_bomb"), "not to hand in this fight")
	ok(said.contains("into the bag"), "and the log says so", said.strip_edges())

	log_line("")
	log_line("======== nowhere to put it ========")
	var full: Array = []
	full.resize(Campaign.INVENTORY_SIZE)
	full.fill("medicine")
	Campaign.set_inventory("cyrus", full)
	mark["pocket"] = ["medium_bomb"]
	give_turn(combat, cyrus)
	said = await heard_during(combat, func(): await combat.use_skill("steal", cyrus, mark.position, false))
	ok(mark.pocket == ["medium_bomb"] and Campaign.count_of("cyrus", "medium_bomb") == 0,
		"with his bag full, the enemy keeps it", "%s" % [mark.pocket])
	ok(said.contains("no room"), "and the log says why", said.strip_edges())

	log_line("")
	log_line("======== a Steal that takes one ========")
	var just_one := EffectDefinition.new()
	just_one.type = EffectDefinition.EffectType.STEAL
	just_one.steal_count = 1
	Campaign.set_inventory("cyrus", [])
	mark["pocket"] = ["medium_bomb", "medicine"]
	combat.steal(cyrus, mark, just_one, skill)
	ok(mark.pocket == ["medicine"] and combat.items_of(cyrus) == ["medium_bomb"], "Steal Count 1 takes the first thing only",
		"%s, %s" % [mark.pocket, combat.items_of(cyrus)])
	ok(ui.describe_effect(just_one).contains("up to 1"), "and its tooltip says so", ui.describe_effect(just_one))

	log_line("")
	log_line("======== the other way round ========")
	var alithia := fighter(combat, "alithia")
	empty_handed["pocket"] = ["medicine", "tiny_bomb"]
	Campaign.set_inventory("alithia", ["cure_potion", "big_bomb", "frost_bottle", "", "medium_bomb"])
	combat.steal(empty_handed, alithia, skill.effects[0], skill)
	ok(empty_handed.pocket == ["medicine", "tiny_bomb", "cure_potion", "big_bomb"],
		"an enemy given a Steal fills their pocket from a hero's front slots, up to four", "%s" % [empty_handed.pocket])
	ok(combat.items_of(alithia) == ["frost_bottle"] and Campaign.count_of("alithia", "medium_bomb") == 1,
		"leaving what did not fit, and nothing deeper in the bag is touched", "%s" % [Campaign.inventory_of("alithia")])

	game.queue_free()
	await settle(3)
	ok(Campaign.count_of("cyrus", "medium_bomb") == 1, "what he stole is still his once the fight is over")
	Campaign.reset()
	log_line("")


func handed_out_by_the_encounter():
	log_line("======== an enemy given things by their encounter ========")
	# Copied spawn by spawn, so the encounter everything else loads is untouched.
	var encounter: EncounterDefinition = load(WATCHER).duplicate()
	var spawn: SpawnDefinition = null
	var spawns: Array[SpawnDefinition] = []
	for each in encounter.spawns:
		var copy: SpawnDefinition = each.duplicate()
		spawns.append(copy)
		if spawn == null and copy.side == 1:
			spawn = copy
	encounter.spawns = spawns
	# A pebble is for throwing on a stealth map, so it never comes to a fight,
	# and only four do.
	spawn.starting_items.assign(["medium_bomb", "pebble", "medicine", "frost_bottle", "big_bomb", "cure_potion"])
	Campaign.reset()
	var game = await open_fight(encounter)
	var combat = game.get_node("VisualCombat")
	var carrier := {}
	for comb in combat.combatants:
		if comb.side == 1 and comb.position == spawn.position:
			carrier = comb
	ok(combat.items_of(carrier) == ["medium_bomb", "medicine", "frost_bottle", "big_bomb"],
		"they come to the fight with the first four they can use there", "%s" % [combat.items_of(carrier)])
	var cyrus := fighter(combat, "cyrus")
	# His own spawn fills his front slots; emptied, so all of it can be to hand.
	Campaign.set_inventory("cyrus", [])
	put(combat, carrier, free_beside(combat, cyrus.position, carrier.movement_class))
	await settle(2)
	give_turn(combat, cyrus)
	await combat.use_skill("steal", cyrus, carrier.position, false)
	await settle(3)
	ok(combat.items_of(carrier).is_empty() and combat.items_of(cyrus) == ["medium_bomb", "medicine", "frost_bottle", "big_bomb"],
		"and Cyrus can take every one of them", "%s" % [combat.items_of(cyrus)])
	game.queue_free()
	await settle(3)
	Campaign.reset()
	log_line("")


func the_editor():
	log_line("======== picking what they carry in the editor ========")
	var hint := SpawnDefinition.item_list_hint()
	var prefix := "%d/%d:" % [TYPE_STRING, PROPERTY_HINT_ENUM]
	ok(hint.begins_with(prefix) and hint.trim_prefix(prefix).split(",").has("medium_bomb"),
		"a spawn's Starting Items are picked from a list of the items there are")
	var editor = EncounterEditor.new()
	get_tree().root.add_child(editor)
	await settle(1)
	editor.encounter = load(WATCHER)
	editor.rebuild()
	var marker: SpawnMarker = null
	for each in editor.markers():
		if each.side == 1:
			marker = each
			break
	var listed := {}
	for property in marker.get_property_list():
		if property.name == "starting_items":
			listed = property
	ok(listed.get("hint", -1) == PROPERTY_HINT_TYPE_STRING and listed.get("hint_string", "") == hint,
		"and on an enemy's marker in the encounter editor too")
	marker.starting_items = ["medium_bomb", "no_such_thing"]
	var problems: String = "\n".join(editor._problems_with_layout())
	ok(problems.contains("no_such_thing"), "a typed key that is no item stops a save, and says which", problems.replace("\n", " / "))
	marker.starting_items = ["medium_bomb"]
	problems = "\n".join(editor._problems_with_layout())
	ok(not problems.contains("not an item"), "a real one does not")
	editor.free()
	log_line("")


## Every label's text under `node`, joined - what a prompt is saying.
func texts_in(node: Node) -> String:
	if node == null:
		return ""
	var found := []
	for label in node.find_children("*", "Label", true, false):
		found.append(label.text)
	return " | ".join(found)
