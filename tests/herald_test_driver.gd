extends Node
## What the log says about the party rather than about the fight.
##
## An item changing hands and somebody joining or leaving are things that
## happen to a run, not to a battle, so Campaign says them - and the same HUD
## carries them whether a map or a fight is on screen.

var LOG_PATH := HarnessLog.path_for("herald")
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
	get_tree().create_timer(180.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


## Everything Campaign says while `action` runs.
func said_during(action: Callable) -> Array:
	var heard := []
	var listener = func(text): heard.append(text)
	Campaign.announced.connect(listener)
	action.call()
	Campaign.announced.disconnect(listener)
	return heard


## What the log panel is showing. Read through get_parsed_text rather than the
## text property: append_text() adds to the label's parsed content and leaves
## `text` alone, so `text` says nothing about what is on screen.
func log_text(ui) -> String:
	return ui.get_node("Actions/Information/Text").get_parsed_text()


func run_test():
	log_line("======== an item changing hands is said out loud ========")
	Campaign.reset()
	var heard = said_during(func(): Campaign.give_item("cyrus", "cure_potion"))
	ok(heard.size() == 1, "one line for one item", "%s" % [heard])
	if heard.size() == 1:
		ok(heard[0].contains(CombatantDatabase.combatants["cyrus"].name),
			"naming who got it", heard[0].strip_edges())
		ok(heard[0].contains(ItemDatabase.item("cure_potion").name),
			"and what they got")
		ok(heard[0].ends_with("\n"), "ending the line, like every other log entry")
	# Nothing to say when nothing happened.
	var refused = said_during(func(): Campaign.give_item("cyrus", "not_a_real_item"))
	ok(refused.is_empty(), "an item that does not exist is not announced", "%s" % [refused])
	var full = said_during(func(): Campaign.give_item("nobody_at_all", "cure_potion"))
	ok(full.is_empty(), "nor one handed to nobody", "%s" % [full])
	log_line("")

	log_line("======== joining and leaving ========")
	Campaign.reset()
	Campaign.set_party(["cyrus"], 1)
	var joining = said_during(func(): Campaign.add_member("enfina"))
	ok(joining.size() == 1 and joining[0].contains("joins the party"),
		"somebody joining is said", "%s" % [joining])
	ok(joining.size() == 1 and joining[0].contains(CombatantDatabase.combatants["enfina"].name),
		"by name")
	var again = said_during(func(): Campaign.add_member("enfina"))
	ok(again.is_empty(), "and not said twice for somebody already there", "%s" % [again])
	var leaving = said_during(func(): Campaign.remove_member("enfina"))
	ok(leaving.size() == 1 and leaving[0].contains("leaves the party"),
		"leaving is said too", "%s" % [leaving])
	var gone = said_during(func(): Campaign.remove_member("enfina"))
	ok(gone.is_empty(), "and not for somebody who was never there", "%s" % [gone])
	log_line("")

	log_line("======== setting up a map says nothing ========")
	# A whole roster arriving at the start of a map is not four people joining.
	var opening = said_during(func(): Campaign.set_party(["cyrus", "enfina", "prometheus"], 2))
	ok(opening.is_empty(), "the map's own party is not announced", "%s" % [opening])
	log_line("")

	log_line("======== it reaches the log on a map ========")
	Campaign.reset()
	Campaign.current_map = "res://scenes/laboratory_terrain_explore.tscn"
	var walk = load("res://scenes/exploration.tscn").instantiate()
	get_tree().root.add_child(walk)
	for i in 5:
		await get_tree().process_frame
	var walk_ui = walk.game_ui
	ok(walk_ui != null, "exploration has the HUD")
	if walk_ui != null:
		var before = log_text(walk_ui)
		Campaign.give_item("cyrus", "tiny_bomb")
		await get_tree().process_frame
		var after = log_text(walk_ui)
		ok(after.length() > before.length(), "the line lands in the exploration log")
		ok(after.contains(ItemDatabase.item("tiny_bomb").name), "naming the item", after.substr(maxi(0, after.length() - 60)))
	walk.queue_free()
	await get_tree().process_frame
	log_line("")

	log_line("======== and in a battle ========")
	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_02_sappers.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	for i in 6:
		await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await get_tree().process_frame
	var ui = combat.game_ui
	var before_fight = log_text(ui)
	Campaign.give_item("cyrus", "medicine")
	await get_tree().process_frame
	ok(log_text(ui).length() > before_fight.length(), "the battle log carries it too")
	ok(log_text(ui).contains(ItemDatabase.item("medicine").name), "naming the item")
	# One listener, not one per scene loaded.
	var heard_twice = said_during(func(): Campaign.give_item("cyrus", "cure_potion"))
	ok(heard_twice.size() == 1, "and says it once, not once per scene ever opened",
		"%d" % heard_twice.size())
	game.queue_free()
	await get_tree().process_frame
	log_line("")

	log_line("======== the Lab Fight arms its party as written ========")
	# Read off the encounter rather than copied from it. The rule is that what a
	# spawn lists is what that character turns up carrying; a second copy of the
	# list here only says whether somebody retuned the fight, and broke every
	# time they did.
	var fight: EncounterDefinition = load("res://encounters/encounter_02_sappers.tres")
	var wanted := {}
	for spawn in fight.spawns:
		if spawn != null and spawn.side == 0 and not spawn.starting_items.is_empty():
			wanted[spawn.combatant_key] = Array(spawn.starting_items).duplicate()
	ok(not wanted.is_empty(), "the Lab Fight writes a bag for somebody",
		"%d of them" % wanted.size())
	Campaign.reset()
	Campaign.current_encounter = fight
	var lab = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(lab)
	for i in 6:
		await get_tree().process_frame
	var lab_combat = lab.get_node("VisualCombat")
	if lab_combat.deployment_active:
		lab_combat.finish_deployment()
		await get_tree().process_frame
	for comb in lab_combat.combatants:
		var who = comb.get("combatant_key", "")
		if not wanted.has(who):
			continue
		var bag := []
		for slot in Campaign.inventory_of(who):
			if slot != "":
				bag.append(slot)
		ok(bag == wanted[who], "%s carries what was written for them" % who,
			"%s" % [bag])
		# Only the first four come to the fight, and none of them has five.
		ok(lab_combat.items_of(comb) == wanted[who],
			"  and the Consumables panel offers them", "%s" % [lab_combat.items_of(comb)])
	lab.queue_free()
	await get_tree().process_frame
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
