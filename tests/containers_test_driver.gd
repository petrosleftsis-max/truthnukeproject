extends Node
## Containers (Campaign "Containers"): a backpack for everybody, a pouch and a
## belt besides - the belt what comes into a fight - each with so many slots,
## swapped between the party, put on from the stash; bombs two to a slot in a
## Grenadier's Pack; Steal emptying the container the thief picks; Rummage
## taking something out of the pouch and onto the belt in a fight.

var LOG_PATH := HarnessLog.path_for("containers")
var _log: FileAccess
var _fail = 0
var combat = null


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


func who(key: String) -> Dictionary:
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == key and comb.alive:
			return comb
	return {}


func filled(key: String, kind: String) -> Array:
	return Campaign.contents_of(key, kind)


func run_test():
	Campaign.reset()
	Campaign.seed_party(["cyrus", "alithia", "enfina"])

	log_line("======== What everybody wears ========")
	ok(Campaign.container_in("cyrus", "belt") == Campaign.STARTING_BELT and Campaign.container_in("cyrus", "backpack") == Campaign.STARTING_BACKPACK
		and Campaign.container_in("cyrus", "pouch") == "", "a belt and a backpack, and no pouch")
	ok(Campaign.bag_size("cyrus") == Campaign.INVENTORY_SIZE and Campaign.inventory_of("cyrus").size() == Campaign.INVENTORY_SIZE,
		"%d slots between them" % Campaign.INVENTORY_SIZE, "%d" % Campaign.bag_size("cyrus"))
	ok(Campaign.combat_slots_of("cyrus") == Campaign.COMBAT_SLOTS, "the belt's four are what comes into a fight")
	Campaign.empty_inventory("cyrus")
	Campaign.give_item("cyrus", "cure_potion")
	ok(filled("cyrus", "belt") == ["cure_potion"], "something given goes on the belt first")
	for i in 4:
		Campaign.give_item("cyrus", "medicine")
	ok(filled("cyrus", "belt").size() == 4 and filled("cyrus", "backpack") == ["medicine"], "and into the backpack once the belt is full")
	ok(Campaign.combat_items_of("cyrus").size() == 4 and not Campaign.combat_items_of("cyrus").has("") , "only the belt comes to a fight")

	log_line("======== A pouch from the stash ========")
	Campaign.give_gear("belt_pouch")
	ok(Campaign.wear_container("cyrus", "belt_pouch") == "" and Campaign.container_in("cyrus", "pouch") == "belt_pouch",
		"Cyrus puts on a Belt Pouch")
	ok(Campaign.bag_size("cyrus") == 28 and Campaign.container_start("cyrus", "pouch") == 4 and Campaign.container_start("cyrus", "backpack") == 8,
		"four more slots, between the belt and the backpack", "%d" % Campaign.bag_size("cyrus"))
	ok(filled("cyrus", "belt").size() == 4 and filled("cyrus", "backpack") == ["medicine"], "what he carried stays where it was")
	ok(not Campaign.gear.has("belt_pouch"), "and it is out of the stash")
	Campaign.stow_item("cyrus", "small_bomb", "pouch")
	Campaign.stow_item("cyrus", "tiny_bomb", "pouch")
	ok(filled("cyrus", "pouch") == ["small_bomb", "tiny_bomb"], "two bombs in it")

	log_line("======== Bigger, smaller ========")
	Campaign.give_gear("utility_belt")
	ok(Campaign.wear_container("cyrus", "utility_belt") == "" and Campaign.combat_slots_of("cyrus") == 6
		and filled("cyrus", "belt").size() == 4 and Campaign.gear.has(Campaign.STARTING_BELT),
		"a Utility Baldric in place of his: six to hand, what was on the old one moved over, the old one in the stash")
	Campaign.give_gear("coin_pouch")
	for i in 2:
		Campaign.stow_item("cyrus", "medicine", "pouch")
	var refused := Campaign.wear_container("cyrus", "coin_pouch")
	ok(refused != "" and Campaign.container_in("cyrus", "pouch") == "belt_pouch" and filled("cyrus", "pouch").size() == 4,
		"four things will not go in a Coin Pouch's two: refused, nothing moved", refused)
	ok(Campaign.take_off_container("cyrus", "backpack") != "" and Campaign.container_in("cyrus", "backpack") == Campaign.STARTING_BACKPACK,
		"a backpack only changes for another")

	log_line("======== Between the party ========")
	ok(Campaign.container_in("alithia", "pouch") == "", "Alithia has no pouch")
	var cyrus_pouch := filled("cyrus", "pouch")
	ok(Campaign.swap_containers("cyrus", "alithia", "pouch") == "" and Campaign.container_in("alithia", "pouch") == "belt_pouch"
		and Campaign.container_in("cyrus", "pouch") == "" and filled("alithia", "pouch") == cyrus_pouch,
		"Cyrus hands her his, with what is in it", "%s" % [filled("alithia", "pouch")])
	ok(Campaign.bag_size("cyrus") == 26 and Campaign.bag_size("alithia") == 28, "his bag smaller by it, hers bigger")
	var backpacks := [Campaign.container_in("cyrus", "backpack"), Campaign.container_in("alithia", "backpack")]
	Campaign.stow_item("alithia", "cure_potion", "backpack")
	ok(Campaign.swap_containers("cyrus", "alithia", "backpack") == "" and filled("cyrus", "backpack").has("cure_potion")
		and filled("alithia", "backpack") == ["medicine"], "backpacks swap, contents and all")
	Campaign.swap_containers("cyrus", "alithia", "backpack")

	log_line("======== Taking one off ========")
	var held := filled("alithia", "pouch").size()
	var in_pack := filled("alithia", "backpack").size()
	ok(Campaign.take_off_container("alithia", "pouch") == "" and Campaign.container_in("alithia", "pouch") == ""
		and filled("alithia", "backpack").size() == in_pack + held and Campaign.gear.has("belt_pouch"),
		"Alithia takes the pouch off: what was in it into her backpack, the pouch into the stash")

	log_line("======== Bombs two to a slot ========")
	Campaign.empty_inventory("enfina")
	for i in 4:
		Campaign.stow_item("enfina", "cure_potion", "belt")
	Campaign.give_gear("grenadiers_pack")
	ok(Campaign.wear_container("enfina", "grenadiers_pack") == "" and Campaign.slots_in("enfina", "backpack") == 16,
		"Enfina wears a Grenadier's Pack")
	for i in 5:
		Campaign.give_item("enfina", "small_bomb")
	var start := Campaign.container_start("enfina", "backpack")
	ok(Campaign.count_of("enfina", "small_bomb") == 5 and Campaign.count_in("enfina", start) == 2
		and Campaign.count_in("enfina", start + 1) == 2 and Campaign.count_in("enfina", start + 2) == 1,
		"five small bombs in three slots: two, two and one")
	ok(Campaign.take_item("enfina", "small_bomb") and Campaign.count_in("enfina", start) == 1 and Campaign.count_of("enfina", "small_bomb") == 4,
		"one taken comes off a stack")
	Campaign.take_item("enfina", "cure_potion", "belt")
	ok(Campaign.move_item("enfina", start + 1, "enfina", 0) and Campaign.inventory_of("enfina")[0] == "small_bomb"
		and Campaign.count_in("enfina", 0) == 1 and Campaign.count_in("enfina", start + 1) == 1,
		"a pair moved onto the belt - one to a slot there - moves one, and one stays")
	ok(Campaign.combat_items_of("enfina").count("small_bomb") == 1, "the one on the belt comes to a fight")
	Campaign.give_gear("satchel")
	ok(Campaign.wear_container("enfina", "satchel") == "" and Campaign.count_of("enfina", "small_bomb") == 4,
		"changed for a Satchel, the bombs are one to a slot again and none lost")

	log_line("======== Steal empties the container chosen ========")
	Campaign.empty_inventory("cyrus")
	Campaign.give_gear("hunters_pouch")
	Campaign.wear_container("cyrus", "hunters_pouch")
	Campaign.stow_item("cyrus", "cure_potion", "belt")
	Campaign.stow_item("cyrus", "medicine", "pouch")
	Campaign.stow_item("cyrus", "small_bomb", "pouch")
	Campaign.current_encounter = load("res://data/encounters/encounter_01_ambush.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(8)
	combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(2)
	combat.reaction_prompt = null
	var cyrus := who("cyrus")
	# The ambush hands the party its own bags; Cyrus's again, as packed above.
	Campaign.empty_inventory("cyrus")
	Campaign.stow_item("cyrus", "cure_potion", "belt")
	Campaign.stow_item("cyrus", "medicine", "pouch")
	Campaign.stow_item("cyrus", "small_bomb", "pouch")
	var thief: Dictionary = combat.combatants.filter(func(comb): return comb.alive and comb.side == 1 and not comb.has("object"))[0]
	thief.pocket = []
	thief.erase("carried")
	var choices: Array = combat.steal_choices(cyrus)
	ok(choices.map(func(choice): return choice.kind) == ["belt", "pouch"], "Cyrus has things in his belt and his pouch to steal", "%s" % [choices])
	ok(await combat._choose_container(thief, cyrus) == "pouch", "an enemy thief goes for the fullest - his pouch")
	var steal_effect: EffectDefinition = SkillDatabase.skills["steal"].effects[0]
	combat._steal_from = "pouch"
	combat.steal(thief, cyrus, steal_effect, SkillDatabase.skills["steal"])
	combat._steal_from = ""
	ok(filled("cyrus", "pouch").is_empty() and filled("cyrus", "belt") == ["cure_potion"] and thief.pocket.has("medicine") and thief.pocket.has("small_bomb"),
		"stealing his pouch empties it into the thief's pocket, and leaves his belt be", "%s" % [thief.pocket])
	thief["carried"] = ["kindled_hound_spellbook"]
	choices = combat.steal_choices(thief)
	ok(choices.map(func(choice): return choice.kind) == ["pocket", "carried"], "an enemy has what it fights with and what it carries besides")
	combat._steal_from = "carried"
	combat.steal(cyrus, thief, steal_effect, SkillDatabase.skills["steal"])
	combat._steal_from = ""
	ok(thief.carried.is_empty() and thief.pocket.size() == 2 and Campaign.count_of("cyrus", "kindled_hound_spellbook") == 1,
		"Cyrus steals what it carries, and leaves its pocket")

	log_line("======== Rummage ========")
	Campaign.stow_item("cyrus", "medicine", "pouch")
	combat.current_combatant = combat.combatants.find(cyrus)
	combat.controller.set_controlled_combatant(cyrus)
	cyrus.skill_used_this_turn = false
	cyrus.secondary_used_this_turn = false
	ok(combat.main_skills_of(cyrus).has("rummage"), "something in his pouch and room on his belt: Rummage")
	ok(combat.items_as_secondary(cyrus) and combat.secondary_skills_of(cyrus).has("rummage"), "and with Quick Hands, as a secondary action too")
	await combat.use_skill("rummage", cyrus, cyrus.position, false, true)
	await settle(2)
	ok(filled("cyrus", "belt").has("medicine") and filled("cyrus", "pouch").is_empty() and cyrus.secondary_used_this_turn
		and not cyrus.skill_used_this_turn, "the Medicine out of the pouch and onto his belt, for his secondary action")
	ok(not combat.main_skills_of(cyrus).has("rummage") and combat.refusal_for(cyrus, SkillDatabase.skills["rummage"], cyrus.position) != "",
		"with the pouch empty, nothing to rummage for")
	var enfina := who("enfina")
	if not enfina.is_empty():
		Campaign.give_gear("coin_pouch")
		Campaign.wear_container("enfina", "coin_pouch")
		Campaign.stow_item("enfina", "cure_potion", "pouch")
		while not Campaign.has_room_in("enfina", "belt"):
			Campaign.take_item("enfina", Campaign.contents_of("enfina", "belt")[0], "belt")
		ok(combat.main_skills_of(enfina).has("rummage") and not combat.secondary_skills_of(enfina).has("rummage"),
			"Enfina, without Quick Hands, rummages with her main action only")
	game.queue_free()
	await settle(2)

	log_line("======== The inventory screen ========")
	Campaign.give_gear("belt_pouch")
	var screen := InventoryUI.new()
	get_tree().root.add_child(screen)
	await settle(2)
	screen.open()
	await settle(2)
	var cyrus_bag: Node = screen._columns.find_child("Bag_cyrus", true, false)
	ok(cyrus_bag != null and cyrus_bag.find_child("Header_belt", true, false) != null and cyrus_bag.find_child("Header_pouch", true, false) != null
		and cyrus_bag.find_child("Header_backpack", true, false) != null, "a header for each of Cyrus's containers")
	var baldric_header: Button = cyrus_bag.find_child("Header_belt", true, false) if cyrus_bag != null else null
	ok(baldric_header != null and baldric_header.text.begins_with("Baldric: "), "the one that comes to a fight is the Baldric",
		baldric_header.text if baldric_header != null else "")
	var stash_pouch: Button = screen._stash_row.find_child("Stash_belt_pouch", true, false)
	ok(stash_pouch != null, "the Belt Pouch in the stash")
	var alithia_bag: Node = screen._columns.find_child("Bag_alithia", true, false)
	(alithia_bag.find_child("Header_pouch", true, false) as Button).pressed.emit()
	stash_pouch.pressed.emit()
	await settle(1)
	ok(Campaign.container_in("alithia", "pouch") == "belt_pouch", "pressing her pouch, then the stash's: she puts it on")
	cyrus_bag = screen._columns.find_child("Bag_cyrus", true, false)
	alithia_bag = screen._columns.find_child("Bag_alithia", true, false)
	(cyrus_bag.find_child("Header_pouch", true, false) as Button).pressed.emit()
	(alithia_bag.find_child("Header_pouch", true, false) as Button).pressed.emit()
	await settle(1)
	ok(Campaign.container_in("cyrus", "pouch") == "belt_pouch" and Campaign.container_in("alithia", "pouch") == "hunters_pouch",
		"his pouch, then hers: they swap")
	screen.close()
	screen.queue_free()
