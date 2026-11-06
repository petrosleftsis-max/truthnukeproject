extends Node
## Letting go of a tether (Combat "Letting go of a tether"; the designer, 2026-11-07): a right click on
## what it holds, at any point, for nothing; another player's only if they agree. In `net` over two
## machines; on a map below too.

const LOG_NAME := "letgo"
const WATCHER := "res://data/encounters/encounter_03_watcher.tres"
const PARTY := ["enfina", "cyrus", "prometheus", "alithia"]

var LOG_PATH := HarnessLog.path_for(LOG_NAME)
var _log: FileAccess = null
var _fail := 0
var game = null
var combat: Combat = null
var controller = null
var prompt = null


func log_line(text: String):
	if _log:
		_log.store_line(text)
		_log.flush()


func ok(condition: bool, label: String, detail: String = ""):
	if condition:
		log_line("  PASS  %s %s" % [label, detail])
	else:
		_fail += 1
		log_line("  FAIL  %s %s" % [label, detail])


func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(240.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await settle()
	var booted = get_tree().current_scene
	if booted != null:
		booted.queue_free()
		await settle()
	await open_fight()
	await what_is_held_where()
	await open_fight()
	await on_your_own_turn()
	await open_fight()
	await on_somebody_elses_turn()
	await open_fight()
	await another_players()
	await close_fight()
	log_line("FAILURES: %d" % _fail)
	_log.close()
	get_tree().quit(0 if _fail == 0 else 1)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


func open_fight():
	await close_fight()
	Coop.reset()
	Campaign.reset()
	Campaign.set_party(PARTY, 64)
	Campaign.choose_subclass("alithia", "illusory_shepherd")
	Campaign.current_map = "res://maps/crossroads_explore.tscn"
	Campaign.return_to_position = true
	Campaign.current_encounter = load(WATCHER)
	game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(6)
	combat = game.get_node("VisualCombat")
	controller = game.get_node("Controller")
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(2)
	prompt = combat.reaction_prompt
	for comb in combat.combatants:
		comb.reaction_used = true
		if comb.has("stats"):
			comb.hp = 900
			comb.max_hp = 900
		if comb.side == 1 and comb.has("stats"):
			comb.stats["mindfulness"] = 1
	var alithia := who("alithia")
	for gate in alithia.spell_slots.size():
		alithia.spell_slots[gate] = 5
	var foe: Dictionary = foes()[0]
	combat.teleport_to(foe, tile_away(alithia.position, 4, foe))
	await settle()


func close_fight():
	if game != null and is_instance_valid(game):
		game.queue_free()
		await settle(3)
	game = null
	combat = null


func who(key: String) -> Dictionary:
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == key and not comb.get("illusion", false):
			return comb
	return {}


func foes() -> Array:
	return combat.combatants.filter(func(comb): return comb.side == 1 and comb.alive and not comb.has("object") and not comb.get("illusion", false))


func their_turn(comb: Dictionary):
	combat.current_combatant = combat.combatants.find(comb)
	comb.skill_used_this_turn = false
	comb.secondary_used_this_turn = false
	controller.set_controlled_combatant(comb)
	await settle()


func tile_away(from: Vector2i, gap: int, walker: Dictionary) -> Vector2i:
	for tile in controller.get_reachable_tiles(from, walker.movement_class, 40, walker):
		if combat.get_position_distance(tile, from) == gap and combat.can_land_on(walker, tile) and combat.get_combatant_at(tile).is_empty():
			return tile
	return from


func what_is_held_where():
	log_line("======== what a tether holds, on the map ========")
	var alithia := who("alithia")
	var foe: Dictionary = foes()[0]
	await their_turn(alithia)
	ok(combat.tethers_at(foe.position).is_empty(), "nothing held yet")
	await combat.use_skill("mesmerise", alithia, foe.position, false)
	await settle()
	ok(combat.holds_tether(alithia), "she holds Mesmerise")
	ok(combat.tethers_at(foe.position) == [alithia], "whoever it lies on: right click there asks about it", "%s" % [combat.tethers_at(foe.position).size()])
	ok(combat.tethers_at(alithia.position) == [alithia], "and on her, holding it")
	ok(combat.offer_letting_go(foe.position, 0), "the little menu goes up")
	await settle()
	var choice = combat.get_children().filter(func(node): return node is TetherChoice)
	ok(choice.size() == 1 and choice[0].entries == ["End Mesmerise"], "and says what", "%s" % [choice[0].entries if not choice.is_empty() else "none"])
	ok(not choice.is_empty() and choice[0].get_node("Panel").find_child("Sure", true, false).text == "Are you sure?", "it asks if they are sure")
	ok(combat.holds_tether(alithia), "and nothing has ended yet")
	if not choice.is_empty():
		choice[0].close()
	await settle()
	ok(combat.holds_tether(alithia), "Keep keeps it")
	ok(not combat.offer_letting_go(tile_away(alithia.position, 7, alithia), 0), "and there is nothing to end on bare ground")
	# The ground it covers, and what it called up.
	combat.snap_tether(alithia, "test")
	await their_turn(alithia)
	var at := tile_away(alithia.position, 5, alithia)
	await combat.use_skill("false_ground", alithia, at, false)
	await settle()
	ok(combat.tethers_at(at) == [alithia], "ground it lies on", "%s" % [combat.tethers_at(at).size()])
	combat.snap_tether(alithia, "test")
	await their_turn(alithia)
	var wall_at := tile_away(alithia.position, 4, alithia)
	await combat.use_skill("phantom_wall", alithia, wall_at, false)
	await settle()
	ok(not combat.tethers_at(wall_at).is_empty(), "what it called up")
	log_line("")


func on_your_own_turn():
	log_line("======== on her own turn ========")
	var alithia := who("alithia")
	var foe: Dictionary = foes()[0]
	await their_turn(alithia)
	await combat.use_skill("mesmerise", alithia, foe.position, false)
	await settle()
	ok(combat.has_restriction(foe, "skips_turn"), "they stand and stare")
	# Her turn goes on: controller idle, so it goes at once, free.
	await their_turn(alithia)
	alithia.skill_used_this_turn = false
	var before: Array = alithia.spell_slots.duplicate()
	combat.ask_to_let_go(alithia, 0)
	await settle()
	ok(not combat.holds_tether(alithia), "ended")
	ok(not combat.has_restriction(foe, "skips_turn"), "and they wake")
	ok(alithia.spell_slots == before and not alithia.skill_used_this_turn, "for nothing")
	log_line("")


func on_somebody_elses_turn():
	log_line("======== in the middle of somebody else's turn ========")
	var alithia := who("alithia")
	var foe: Dictionary = foes()[0]
	await their_turn(alithia)
	await combat.use_skill("mesmerise", alithia, foe.position, false)
	await settle()
	# While something is going on, it waits.
	controller.player_turn = false
	combat.ask_to_let_go(alithia, 0)
	await settle()
	ok(combat.holds_tether(alithia), "with the other side acting, it waits for the moment")
	ok(combat._let_goes_due.size() == 1, "and is remembered")
	# As a turn begins, with nobody else playing this fight.
	combat._let_go_as_a_turn_begins()
	ok(not combat.holds_tether(alithia), "it goes as the next turn begins")
	ok(combat._let_goes_due.is_empty(), "and that is the end of it")
	controller.player_turn = true
	log_line("")


func another_players():
	log_line("======== somebody else's ========")
	# Two on one screen.
	Coop.join(0, "One")
	Coop.join(1, "Two")
	Campaign.controllers = {"alithia": 1}
	var alithia := who("alithia")
	var foe: Dictionary = foes()[0]
	await their_turn(alithia)
	await combat.use_skill("mesmerise", alithia, foe.position, false)
	await settle()
	ok(Coop.on() and combat.player_of(alithia) == 1, "she is the second player's", "%d" % combat.player_of(alithia))
	ok(combat.offer_letting_go(foe.position, 0), "the first player right clicks it")
	await settle()
	var choice = combat.get_children().filter(func(node): return node is TetherChoice)
	ok(not choice.is_empty() and choice[0].entries[0].begins_with("Ask Two"), "and may only ask", "%s" % [choice[0].entries if not choice.is_empty() else "none"])
	if not choice.is_empty():
		choice[0]._choose(0)
	await settle()
	var request = combat.get_children().filter(func(node): return node is TetherRequest)
	ok(request.size() == 1 and request[0].asked == 1 and request[0].asker == 0, "the second player is asked")
	ok(combat.holds_tether(alithia), "and until they say, it holds")
	if not request.is_empty():
		request[0].answer(false)
	await settle()
	ok(combat.holds_tether(alithia), "Refuse keeps it")
	# Agreeing.
	combat.ask_to_let_go(alithia, 0)
	await settle()
	request = combat.get_children().filter(func(node): return node is TetherRequest)
	if not request.is_empty():
		request[0].answer(true)
	await settle(4)
	ok(not combat.holds_tether(alithia), "Agree ends it")
	ok(not combat.has_restriction(foe, "skips_turn"), "and they wake")
	# Their own needs no asking.
	await their_turn(alithia)
	await combat.use_skill("mesmerise", alithia, foe.position, false)
	await settle()
	combat.ask_to_let_go(alithia, 1)
	await settle(4)
	ok(not combat.holds_tether(alithia), "the player who holds it just ends it")
	Coop.reset()
	Campaign.controllers = {}
	log_line("")
