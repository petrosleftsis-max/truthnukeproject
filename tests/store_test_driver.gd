extends Node
## Gold and stores: a purse the party fills by winning fights and spends in a
## store, buying items into the bags and gear into the stash, selling back at
## the store's rate - on a map, and at a dungeon's rest.

var LOG_PATH := HarnessLog.path_for("store")
const AMBUSH := "res://data/encounters/encounter_01_ambush.tres"
const STORE := "travelling_merchant"

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
	get_tree().create_timer(180.0, true, false, true).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	var booted = get_tree().current_scene
	if booted != null:
		booted.queue_free()
		await settle()
	await the_purse()
	await buying_and_selling()
	await paid_for_a_win()
	await on_the_map()
	await at_a_rest()
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


func the_purse():
	log_line("======== the purse ========")
	Campaign.reset()
	ok(Campaign.gold == 0, "a new run starts with none")
	Campaign.give_gold(50)
	ok(Campaign.gold == 50, "gold given goes in", "%d" % Campaign.gold)
	ok(not Campaign.spend_gold(80) and Campaign.gold == 50, "more than there is cannot be spent")
	ok(Campaign.spend_gold(20) and Campaign.gold == 30, "what there is can", "%d" % Campaign.gold)
	Campaign.reset()
	ok(Campaign.gold == 0, "and starting over empties it")
	log_line("")


func buying_and_selling():
	log_line("======== the store ========")
	var store := StoreDefinition.named(STORE)
	ok(store != null and not store.stock.is_empty(), "there is a store, with things for sale")
	ok(Campaign.price_of("cure_potion") > 0 and Campaign.price_of("brigandine") > 0, "items and gear have prices")
	ok(Campaign.price_of("pebble") == 0, "a pebble is worth nothing")
	Campaign.reset()
	Campaign.set_party(["cyrus", "alithia"], 1)
	ok(Campaign.cannot_buy(store, "cure_potion") == "Not enough gold", "with no gold, nothing can be bought")
	Campaign.give_gold(500)
	var price := Campaign.price_of("cure_potion")
	ok(Campaign.buy(store, "cure_potion") == "" and Campaign.gold == 500 - price, "a potion bought costs its price")
	ok(Campaign.count_of("cyrus", "cure_potion") == 1, "and goes into the leader's bag")
	ok(Campaign.buy(store, "pebble") != "", "what the store does not sell cannot be bought from it")
	var full: Array = []
	full.resize(Campaign.INVENTORY_SIZE)
	full.fill("medicine")
	Campaign.set_inventory("cyrus", full)
	Campaign.buy(store, "medicine")
	ok(Campaign.count_of("alithia", "medicine") == 1, "a full bag passes it to the next with room")
	Campaign.set_inventory("alithia", full)
	ok(Campaign.cannot_buy(store, "medicine") == "Nobody has room for it", "and with nobody's room, it says so")
	var gold_before := Campaign.gold
	ok(Campaign.buy(store, "brigandine") == "" and Campaign.gear == ["brigandine"]
		and Campaign.gold == gold_before - Campaign.price_of("brigandine"), "gear bought goes to the stash, whoever's bags are full")
	gold_before = Campaign.gold
	ok(Campaign.sell_item(store, "cyrus", "medicine") and Campaign.gold == gold_before + Campaign.price_of("medicine") / 2
		and Campaign.count_of("cyrus", "medicine") == Campaign.INVENTORY_SIZE - 1, "an item sold back fetches half its price")
	gold_before = Campaign.gold
	ok(Campaign.sell_gear(store, "brigandine") and Campaign.gear.is_empty() and Campaign.gold == gold_before + Campaign.price_of("brigandine") / 2,
		"and so does gear from the stash")
	Campaign.give_gear("padded_jacket")
	Campaign.equip("cyrus", "padded_jacket")
	ok(not Campaign.sell_gear(store, "padded_jacket"), "what somebody is wearing is not for sale")
	ok(not Campaign.sell_item(store, "cyrus", "pebble"), "and nothing worthless sells")
	Campaign.reset()
	log_line("")


func paid_for_a_win():
	log_line("======== paid for a win ========")
	Campaign.reset()
	Campaign.set_party(["cyrus"], 1)
	Campaign.current_map = "res://maps/crossroads_explore.tscn"
	Campaign.return_to_position = true
	var encounter: EncounterDefinition = load(AMBUSH)
	ok(encounter.gold_reward > 0, "the story's fights pay", "%d" % encounter.gold_reward)
	Campaign.current_encounter = encounter
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(6)
	var combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(2)
	for comb in combat.combatants:
		if comb.side == 1 and comb.alive:
			comb.hp = 0
			combat.combatant_die(comb)
	await combat.combat_finish()
	await settle(3)
	ok(Campaign.gold == encounter.gold_reward, "won in the story, the party is paid", "%d" % Campaign.gold)
	game.queue_free()
	await settle(3)
	Campaign.reset()
	Campaign.current_map = ""
	Campaign.return_to_position = false
	log_line("")


func on_the_map():
	log_line("======== a store on a map ========")
	Campaign.reset()
	Campaign.current_map = "res://maps/crossroads_explore.tscn"
	var scene = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(scene)
	await settle(4)
	Campaign.give_gold(100)
	var counter := StoreInteractable.new()
	counter.store = STORE
	counter.interact(scene)
	await settle(3)
	var screen: StoreScreen = scene.store_screen
	ok(screen != null, "a store counter opens the store")
	ok(get_tree().paused, "with the game held")
	if screen != null:
		var buy_row = screen.find_child("Buy_cure_potion", true, false)
		ok(buy_row != null and not buy_row.get_node("Button").disabled, "a potion can be bought")
		var dear = screen.find_child("Buy_plate_harness", true, false)
		ok(dear != null and dear.get_node("Button").disabled and dear.get_node("Button").tooltip_text == "Not enough gold",
			"what costs more than the purse is greyed out, and says why")
		buy_row.get_node("Button").pressed.emit()
		await settle(2)
		ok(Campaign.count_of(Campaign.leader(), "cure_potion") >= 1 and Campaign.gold == 100 - Campaign.price_of("cure_potion"),
			"bought from the screen", "%d gold" % Campaign.gold)
		ok((screen.find_child("Gold", true, false) as Label).text == "%d gold" % Campaign.gold, "the purse on screen keeps up")
		ok(screen.find_child("Sell_%s_cure_potion" % Campaign.leader(), true, false) != null, "and what was bought can be sold back")
		screen.find_child("Leave", true, false).pressed.emit()
		await settle(2)
	ok(scene.store_screen == null and not get_tree().paused, "Leave goes back to the map")
	counter.free()
	scene.queue_free()
	await settle(3)
	Campaign.reset()
	log_line("")


func at_a_rest():
	log_line("======== at a dungeon's rest ========")
	var dungeon: DungeonDefinition = load("res://data/dungeons/dungeon_demo.tres")
	ok(dungeon.store == STORE, "the dungeon demo has a store at its rests")
	ok(dungeon.stages.all(func(stage): return stage.encounter.gold_reward > 0), "and its fights pay")
	Campaign.reset()
	Campaign.dungeon = dungeon
	Campaign.set_party(dungeon.party, dungeon.level)
	var layer := CanvasLayer.new()
	get_tree().root.add_child(layer)
	var rest := RestPanel.new()
	layer.add_child(rest)
	await settle(2)
	var visit: Button = rest.find_child("Store", true, false)
	ok(visit != null, "the rest offers a visit", visit.text if visit != null else "")
	visit.pressed.emit()
	await settle(2)
	ok(rest.store_screen != null and not rest.visible, "which opens the store in place of the rest")
	rest.store_screen.closed.emit()
	await settle(2)
	ok(rest.store_screen == null and rest.visible, "and leaving comes back to it")
	layer.queue_free()
	await settle(2)
	Campaign.reset()
	log_line("")
