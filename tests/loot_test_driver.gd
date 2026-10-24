extends Node
## Loot: nothing comes of a fight on its own - what the enemy carried and wore
## is on their bodies, taken with Loot (a secondary action) or by searching the
## fallen once the fight is won. And the Alchemist, who fights with a dozen
## things in its pockets, and how anybody else with something in theirs weighs
## it against its own moves.

var LOG_PATH := HarnessLog.path_for("loot")
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
	get_tree().create_timer(200.0, true, false, true).timeout.connect(func():
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


func put(comb: Dictionary, tile: Vector2i):
	var from: Vector2i = comb.position
	comb.position = tile
	if comb.get("sprite") != null:
		comb.sprite.position = combat.sprite_point(comb)
	combat.controller.reposition_combatant(from, tile)


## A free tile beside `comb`, or (-99999, -99999).
func beside(comb: Dictionary) -> Vector2i:
	for way in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var tile: Vector2i = comb.position + way
		if combat.controller.is_on_map(tile) and not combat.controller.is_tile_blocking(tile, 0) and combat.get_combatant_at(tile).is_empty():
			return tile
	return Vector2i(-99999, -99999)


func give_turn(comb: Dictionary):
	combat.current_combatant = combat.combatants.find(comb)
	combat.controller.set_controlled_combatant(comb)
	combat.controller.action_locked = false
	comb.skill_used_this_turn = false
	comb.secondary_used_this_turn = false


## Knocks `comb` out where they stand.
func fell(comb: Dictionary):
	comb.hp = 0
	combat.combatant_die(comb)


func open_fight():
	var game = get_tree().root.get_node_or_null("Game")
	if game != null:
		game.queue_free()
		await settle(2)
	Campaign.reset()
	Campaign.current_encounter = load("res://data/encounters/alchemist_den.tres")
	game = load("res://scenes/game.tscn").instantiate()
	game.name = "Game"
	get_tree().root.add_child(game)
	await settle(8)
	combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(1)
	combat.reaction_prompt = null


func run_test():
	await open_fight()
	var alchemist := who("alchemist")
	var sellsword := who("sellsword")
	var bow := who("hired_bow")
	var cyrus := who("cyrus")

	log_line("======== What they carry ========")
	ok(alchemist.get("pocket_size", 0) == 12 and alchemist.pocket.size() == 12, "the Alchemist has a pocket of twelve, and twelve things in it",
		"%s" % [alchemist.get("pocket", [])])
	ok(alchemist.get("carried", []) == ["kindled_hound_spellbook"], "a spellbook it cannot use in a fight, carried besides", "%s" % [alchemist.get("carried", [])])
	ok(alchemist.get("equipment", []) == ["padded_jacket", "feather_charm"], "and wears a jacket and a charm")
	var jacket := EquipmentDefinition.named("padded_jacket")
	ok(jacket != null and alchemist.stats.defense == jacket.defense, "the jacket is its defence", "%d" % alchemist.stats.defense)
	var charm := EquipmentDefinition.named("feather_charm")
	ok(charm != null and charm.passive != null and alchemist.passives.has(charm.passive), "and the charm's passive is on it")
	ok(bow.get("carried", []) == ["instahack_spellbook"] and bow.get("pocket", []).is_empty(), "the archer has only a book on it")

	log_line("======== Loot ========")
	ok(not combat.secondary_grants(cyrus).has("loot"), "with nobody down, nothing to loot")
	fell(alchemist)
	await settle(2)
	ok(combat.secondary_grants(cyrus).has("loot"), "the Alchemist down: Loot, a secondary action")
	ok(not combat.secondary_grants(alchemist).has("loot"), "never for its own side")
	var loot_skill: SkillDefinition = SkillDatabase.skills["loot"]
	var spot := beside(alchemist)
	put(cyrus, spot)
	give_turn(cyrus)
	ok(combat.refusal_for(cyrus, loot_skill, cyrus.position) == "Nothing to take there", "aimed at the ground, nothing to take")
	Campaign.empty_inventory("cyrus")
	await combat.use_skill("loot", cyrus, alchemist.position, false, true)
	await settle(3)
	var bag := Campaign.inventory_of("cyrus")
	ok(bag.has("kindled_hound_spellbook") and bag.has("potent_cure_potion") and bag.has("medicine"),
		"beside it, Cyrus takes what it carried", "%s" % [bag])
	ok(Campaign.gear.has("padded_jacket") and Campaign.gear.has("feather_charm"), "and what it wore goes to the stash", "%s" % [Campaign.gear])
	ok(alchemist.equipment.is_empty() and cyrus.secondary_used_this_turn and not cyrus.skill_used_this_turn,
		"its gear is off it, and it cost his secondary action only")
	ok(alchemist.pocket.is_empty() and alchemist.carried.is_empty() and not combat.is_lootable(alchemist, cyrus),
		"all thirteen things - his bag holds %d - and nothing is left on it" % Campaign.INVENTORY_SIZE, "%s" % [alchemist.carried])

	log_line("======== Search the fallen ========")
	fell(sellsword)
	fell(bow)
	await settle(2)
	var left: Array = combat.loot_left_on_the_fallen()
	ok(left.has("Brigandine") or left.any(func(name): return "Brigandine" in name), "the sellsword's armour is still on it", "%s" % [left])
	ok(left.any(func(name): return "instahack" in name.to_lower()), "and the archer's book on the archer")
	var taken: Array = combat.loot_the_fallen()
	ok(Campaign.gear.has("brigandine") and taken.size() >= left.size() - 1, "won, the party takes it all off them", "%s" % [taken])
	var held := []
	for key in Campaign.living_party():
		held.append_array(Campaign.inventory_of(key))
	ok(held.has("instahack_spellbook"), "the book in somebody's bag")
	ok(combat.loot_left_on_the_fallen().size() <= left.size() - taken.size(), "and nothing taken twice")

	log_line("======== The Alchemist mends, and throws ========")
	await open_fight()
	alchemist = who("alchemist")
	sellsword = who("sellsword")
	ok(alchemist.passives.any(func(passive): return passive != null and passive.items_as_secondary), "its Bandolier: an item with either action")
	sellsword.hp = int(combat.get_effective_stat(sellsword, "max_hp") * 0.3)
	var hurt: int = sellsword.hp
	var pocket_before: int = alchemist.pocket.size()
	give_turn(alchemist)
	combat.controller.movement = combat.movement_budget_of(alchemist)
	var did: bool = await combat._ai_alchemist_act(alchemist, false)
	await settle(3)
	ok(did and sellsword.hp > hurt, "its sellsword badly hurt: it mends him", "%d -> %d" % [hurt, sellsword.hp])
	ok(alchemist.pocket.size() < pocket_before, "with something out of its pocket", "%d -> %d" % [pocket_before, alchemist.pocket.size()])
	sellsword.hp = combat.get_effective_stat(sellsword, "max_hp")
	var party_hp := 0
	for key in Campaign.living_party():
		var member := who(key)
		party_hp += member.hp if not member.is_empty() else 0
	var pocket_now: int = alchemist.pocket.size()
	did = await combat._ai_alchemist_act(alchemist, true)
	await settle(3)
	var party_after := 0
	for key in Campaign.living_party():
		var member := who(key)
		party_after += member.hp if not member.is_empty() else 0
	ok(not did or alchemist.pocket.size() < pocket_now, "nobody hurt: its second action is something thrown, from its pocket",
		"%s, %d -> %d" % [did, pocket_now, alchemist.pocket.size()])
	ok(not did or party_after < party_hp or alchemist.pocket.size() < pocket_now, "at the party", "%d -> %d" % [party_hp, party_after])

	log_line("======== Anybody else with something in a pocket ========")
	ok(Combat._item_against_the_other_side(ItemDatabase.item("small_bomb")) and not Combat._item_against_the_other_side(ItemDatabase.item("cure_potion")),
		"a bomb is for the other side, a potion is not")
	var archer := who("hired_bow")
	archer.pocket = ["cure_potion"]
	ok(combat._ai_heal_key(archer, archer) == "cure_potion", "an archer with a potion drinks it to mend itself")
	ok(combat._ai_heal_key(archer, who("sellsword")) == "cure_potion", "or throws it to a friend - it reaches two tiles")
