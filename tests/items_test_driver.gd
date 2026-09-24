extends Node
## Consumables: the bags, the panels, the spending, and Slip Past.

var LOG_PATH := HarnessLog.path_for("items")
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


func run_test():
	log_line("======== every item is whole ========")
	for key in ItemDatabase.items:
		var item: ItemDefinition = ItemDatabase.items[key]
		ok(item != null, "%s has a resource" % key)
		if item == null:
			continue
		ok(item.name != "", "  it has a name", item.name)
		ok(item.description != "", "  and says what it does")
		ok(item.icon != null, "  and has an icon")
		ok(String(key) == item.name.to_lower().replace(" ", "_"),
			"  its key is its name", item.name.to_lower().replace(" ", "_"))
		ok(item.consumed_on_use, "  and goes away when used")
		ok(SkillDatabase.skills.get(key) == item,
			"  and resolves through the same lookup skills do")
	log_line("")

	log_line("======== the three named ones do what they say ========")
	var potion: ItemDefinition = ItemDatabase.item("cure_potion")
	ok(potion.targets_ally and potion.item_power > 0 and not potion.deals_damage,
		"Cure Potion heals an ally", "%d" % potion.item_power)
	var medicine: ItemDefinition = ItemDatabase.item("medicine")
	var heals = false
	var cures_one = false
	for e in medicine.all_effects():
		if e.type == EffectDefinition.EffectType.HEAL:
			heals = true
		if e.type == EffectDefinition.EffectType.DISPEL and e.dispel_count == 1:
			cures_one = true
	ok(heals and cures_one, "Medicine heals and lifts exactly one thing")
	var bomb: ItemDefinition = ItemDatabase.item("tiny_bomb")
	ok(bomb != null and bomb.deals_damage and bomb.aoe_radius > 0,
		"the Tiny Bomb bursts over an area",
		"radius %d" % (bomb.aoe_radius if bomb != null else -1))
	log_line("")

	log_line("======== a bottle for every condition ========")
	var conditions := []
	var dir = DirAccess.open("res://conditions")
	for file in dir.get_files():
		if file.ends_with(".tres"):
			conditions.append(file.get_basename())
	var bottled := {}
	for key in ItemDatabase.items:
		var item: ItemDefinition = ItemDatabase.items[key]
		for e in item.all_effects():
			if e.type == EffectDefinition.EffectType.CONDITION and e.condition != null:
				bottled[e.condition.resource_path.get_file().get_basename()] = key
	for condition in conditions:
		ok(bottled.has(condition), "something inflicts %s" % condition, bottled.get(condition, "nothing"))
	log_line("")

	log_line("======== bags ========")
	Campaign.reset()
	var bag = Campaign.inventory_of("cyrus")
	ok(bag.size() == Campaign.INVENTORY_SIZE, "a bag has %d slots" % Campaign.INVENTORY_SIZE, "%d" % bag.size())
	ok(bag[0] == "", "and starts empty - a bag is filled by something happening",
		"%s" % [bag.slice(0, 4)])
	Campaign.set_inventory("cyrus", CombatantDatabase.combatants["cyrus"].starting_items)
	bag = Campaign.inventory_of("cyrus")
	ok(bag[0] != "", "and holds what it is handed", "%s" % [bag.slice(0, 4)])
	var fighting = Campaign.combat_items_of("cyrus")
	ok(fighting.size() <= Campaign.COMBAT_SLOTS,
		"only the first %d come to a fight" % Campaign.COMBAT_SLOTS, "%s" % [fighting])
	var before = Campaign.count_of("enfina", "cure_potion")
	ok(Campaign.give_item("enfina", "cure_potion"), "a dialogue can give somebody an item")
	ok(Campaign.count_of("enfina", "cure_potion") == before + 1, "and they have one more of it")
	ok(not Campaign.give_item("enfina", "not_a_real_item"), "giving nonsense is refused")
	ok(not Campaign.give_item("nobody", "cure_potion"), "so is giving it to nobody")
	var cyrus_had = Campaign.inventory_of("cyrus")[0]
	var enfina_had = Campaign.inventory_of("enfina")[0]
	ok(Campaign.move_item("cyrus", 0, "enfina", 0), "one bag can pass to another")
	ok(Campaign.inventory_of("enfina")[0] == cyrus_had
		and Campaign.inventory_of("cyrus")[0] == enfina_had,
		"and the two swap places", "%s <-> %s" % [cyrus_had, enfina_had])
	Campaign.move_item("cyrus", 0, "enfina", 0)
	log_line("")

	log_line("======== consumables in the fight ========")
	Campaign.reset()
	# A battle opened from the menu hands out exactly what its spawns list and
	# nothing otherwise, so stock them the way a designer would before asking
	# what the fight offers.
	var stocked: EncounterDefinition = load("res://encounters/encounter_02_sappers.tres").duplicate(true)
	for spawn_definition in stocked.spawns:
		if spawn_definition.side == 0:
			spawn_definition.starting_items = ["cure_potion", "bomb", "poison_bottle", "medicine"]
	Campaign.current_encounter = stocked
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	for i in 6:
		await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await get_tree().process_frame
	var cyrus = null
	var someone_else = null
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == "cyrus":
			cyrus = comb
		elif comb.side == 0 and someone_else == null:
			someone_else = comb
	ok(cyrus != null, "Cyrus is in this fight")
	if cyrus != null:
		var main = combat.main_skills_of(cyrus)
		var secondary = combat.secondary_skills_of(cyrus)
		var carried = combat.items_of(cyrus)
		ok("cure_potion" in carried, "his potion is on the Consumables panel", "%s" % [carried])
		ok(not ("cure_potion" in main) and not ("cure_potion" in secondary),
			"and not buried in his skills", "main %s" % [main])
		ok("slip_past" in main, "Slip Past is a skill, and stays a main action", "%s" % [main])
		ok("slip_past" in secondary, "and a secondary one for him")
	if someone_else != null:
		var their_skills := []
		their_skills.append_array(combat.main_skills_of(someone_else))
		their_skills.append_array(combat.secondary_skills_of(someone_else))
		var leaked := []
		for key in combat.items_of(someone_else):
			if key in their_skills:
				leaked.append(key)
		ok(leaked.is_empty(),
			"%s's bag stays out of their skill panels" % someone_else.name, "%s" % [leaked])
	for comb in combat.combatants:
		if comb.side == 1:
			ok(combat.items_of(comb).is_empty(), "enemies carry no consumables", comb.name)
			break
	log_line("")

	log_line("======== using one spends it ========")
	if cyrus != null:
		var held = Campaign.count_of("cyrus", "cure_potion")
		ok(held > 0, "he has a potion to drink", "%d" % held)
		if held > 0:
			cyrus.hp = maxi(1, cyrus.hp - 30)
			var hurt = cyrus.hp
			await combat.use_skill("cure_potion", cyrus, cyrus.position, false, false)
			ok(cyrus.hp > hurt, "drinking it heals", "%d -> %d" % [hurt, cyrus.hp])
			ok(Campaign.count_of("cyrus", "cure_potion") == held - 1,
				"and the bottle is gone", "%d left" % Campaign.count_of("cyrus", "cure_potion"))
	log_line("")

	log_line("======== an item's power is its own ========")
	if cyrus != null and someone_else != null:
		var target = null
		for comb in combat.combatants:
			if comb.side == 1 and comb.alive:
				target = comb
				break
		if target != null:
			var from_cyrus = combat.skill_damage(cyrus, target, bomb)
			var from_other = combat.skill_damage(someone_else, target, bomb)
			ok(from_cyrus == from_other,
				"a bomb hits the same whoever throws it", "%d vs %d" % [from_cyrus, from_other])
			var soft = target.duplicate()
			soft.stats = target.stats.duplicate()
			soft.stats["defense"] = 1
			var tough = target.duplicate()
			tough.stats = target.stats.duplicate()
			tough.stats["defense"] = 100
			var soft_hit = combat.skill_damage(cyrus, soft, bomb)
			var tough_hit = combat.skill_damage(cyrus, tough, bomb)
			ok(soft_hit > tough_hit, "and armour still soaks it",
				"%d vs %d" % [soft_hit, tough_hit])
	log_line("")

	log_line("======== Slip Past ========")
	if cyrus != null:
		cyrus.reactions_suppressed = false
		ok(not cyrus.reactions_suppressed, "he starts able to be reacted to")
		await combat.use_skill("slip_past", cyrus, cyrus.position, false, true)
		ok(cyrus.reactions_suppressed, "using it makes him unreactable")
		var reacted = false
		for comb in combat.combatants:
			if comb.side == 1:
				comb.reaction_used = false
		await combat.check_reactive_skills(cyrus, cyrus.position, cyrus.position + Vector2i(5, 5))
		for comb in combat.combatants:
			if comb.side == 1 and comb.reaction_used:
				reacted = true
		ok(not reacted, "and nobody takes a free swing as he leaves")
	log_line("")

	log_line("======== the inventory screen ========")
	game.queue_free()
	await get_tree().process_frame
	Campaign.reset()
	Campaign.current_map = "res://skills/laboratory_terrain_explore.tscn"
	var scene = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(scene)
	for i in 5:
		await get_tree().process_frame
	var screen = scene.get_node_or_null("InventoryUI")
	ok(screen != null, "exploration carries an inventory screen")
	if screen != null:
		ok(not screen.is_open(), "which starts closed")
		var press = InputEventKey.new()
		press.physical_keycode = KEY_I
		press.pressed = true
		screen._unhandled_input(press)
		ok(screen.is_open(), "I opens it")
		var bags = screen._columns.get_child_count()
		ok(bags == Campaign.living_party().size(),
			"with a bag for everyone walking", "%d of %d" % [bags, Campaign.living_party().size()])
		# Moving something by clicking two slots, the way a player does.
		var first_key = Campaign.living_party()[0]
		var second_key = Campaign.living_party()[1] if Campaign.living_party().size() > 1 else first_key
		var was_first = Campaign.inventory_of(first_key)[0]
		var was_second = Campaign.inventory_of(second_key)[5]
		screen._on_slot_pressed(first_key, 0)
		screen._on_slot_pressed(second_key, 5)
		ok(Campaign.inventory_of(second_key)[5] == was_first
			and Campaign.inventory_of(first_key)[0] == was_second,
			"two clicks move an item between bags",
			"%s -> %s" % [was_first, Campaign.inventory_of(second_key)[5]])
		screen._unhandled_input(press)
		ok(not screen.is_open(), "and I closes it again")
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
