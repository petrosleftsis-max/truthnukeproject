extends Node
## Declared moves: called on one turn for nothing, marking where they will come
## down, and landing on exactly those tiles at the start of the caller's next
## turn - spending that turn's action. Lost to a stun or to confusion. The AI
## calls them too, and still takes the rest of its turn.

var LOG_PATH := HarnessLog.path_for("declared")
const MIXED := "res://data/encounters/sizes_big_and_small.tres"

var _log: FileAccess = null
var _fail = 0
var game: Node = null
var combat = null
var heard: Array = []


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
	await open_fight()
	await calling_it()
	await landing_it()
	await losing_it()
	await the_ai()
	await close_fight()
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


func open_fight():
	Campaign.reset()
	Campaign.current_encounter = load(MIXED)
	game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(6)
	combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(2)
	combat.update_information.connect(func(text): heard.append(text))


func close_fight():
	if game != null and is_instance_valid(game):
		game.queue_free()
		await settle(3)
	game = null


func who(key: String) -> Dictionary:
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == key and comb.alive:
			return comb
	return {}


func all_of(key: String) -> Array:
	return combat.combatants.filter(func(c): return c.get("combatant_key", "") == key and c.alive)


## Never misses, so what is measured is where things land, not the dice.
func sure_of_hand(comb: Dictionary):
	comb.status_effects.append({"stat": "accuracy", "amount": 100, "duration": 99, "source_name": "test"})


func sturdy(comb: Dictionary, hp: int = 900):
	comb.max_hp = hp
	comb.hp = hp


## Put on during their own turn, so it gets one more to outlast that turn's end -
## as if somebody had done it to them between turns.
func afflict(comb: Dictionary, name: String):
	var def: ConditionDefinition = load("res://data/conditions/%s.tres" % name)
	comb.status_effects.append({"stat": "condition", "condition": def, "duration": def.duration + 1, "source_name": "test"})


## A tile `comb` has room on, passing `test`, nearest their own.
func a_tile(comb: Dictionary, test: Callable) -> Vector2i:
	var best := Vector2i(-99999, -99999)
	var best_gap := 99999
	var region: Rect2i = combat.controller._astargrid.region
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var tile := Vector2i(x, y)
			if tile != comb.position and combat.room_for(comb, tile) and test.call(tile):
				var gap: int = combat.get_position_distance(comb.position, tile)
				if gap < best_gap:
					best_gap = gap
					best = tile
	return best


func heard_since(mark: int, words: String) -> bool:
	for i in range(mark, heard.size()):
		if words in heard[i]:
			return true
	return false


## `comb`'s next turn, and nobody else's: the queue is only them.
func own_turn(comb: Dictionary):
	var me: int = combat.combatants.find(comb)
	combat.turn_queue = [me, me, me]
	combat.turn = 0
	combat.current_combatant = me
	await combat.advance_turn()
	await settle(2)


## `enemy`'s turn, handed back to `player` after it.
func enemy_turn(enemy: Dictionary, player: Dictionary):
	for comb in combat.combatants:
		if comb.side == 0 and comb.alive:
			# A reaction would stop and ask a player who is not there.
			comb.reaction_used = true
	var p: int = combat.combatants.find(player)
	var e: int = combat.combatants.find(enemy)
	combat.turn_queue = [p, e, p]
	combat.turn = 0
	combat.current_combatant = p
	await combat.advance_turn()
	await settle(2)


func calling_it():
	log_line("======== calling it ========")
	var rockfall: SkillDefinition = SkillDatabase.skills.rockfall
	ok(rockfall.declared and SkillDatabase.skills.ground_pound.declared and SkillDatabase.skills.meteor.declared
		and SkillDatabase.skills.earthsplitter.declared, "the four declared moves are marked so")
	var cyrus := who("cyrus")
	var imps := all_of("imp")
	var spot: Vector2i = imps[0].position
	for imp in imps:
		sturdy(imp)
	sturdy(cyrus)
	sure_of_hand(cyrus)
	var stand := a_tile(cyrus, func(tile):
		var gap: int = combat.get_position_distance(tile, spot)
		return gap >= 3 and gap <= 5 and combat.has_line_of_sight(tile, spot, 0))
	ok(stand.x != -99999 and combat.teleport_to(cyrus, stand), "somewhere in reach of the imps", "%s" % [stand])
	await settle(1)
	combat.current_combatant = combat.combatants.find(cyrus)
	cyrus.skill_used_this_turn = false
	var mark := heard.size()
	await combat.use_skill("rockfall", cyrus, spot, true)
	await settle(1)
	ok(cyrus.has("declared") and cyrus.declared.skill == "rockfall", "Rockfall is called")
	ok(cyrus.get("declared", {}).get("tiles", []).has(spot) and cyrus.declared.tiles.size() > 1,
		"marking the tiles it will come down on", "%d tiles" % cyrus.get("declared", {}).get("tiles", []).size())
	ok(heard_since(mark, "readies"), "and saying so")
	ok(not cyrus.skill_used_this_turn and not cyrus.secondary_used_this_turn, "calling it costs nothing - the action is still there")
	ok(imps.all(func(imp): return imp.hp == 900), "and nothing has landed yet")
	ok(combat.current_combatant == combat.combatants.find(cyrus), "and the turn goes on")
	var queue_tip: String = combat.game_ui._queue_tip(cyrus)
	ok("Readying Rockfall" in queue_tip, "the turn queue says what is coming", queue_tip.replace("\n", " | "))
	ok("Declared:" in combat.game_ui._build_skill_tooltip(rockfall), "and the skill's own tip says how it works")
	var first_aim: Vector2i = cyrus.declared.aim
	await combat.use_skill("rockfall", cyrus, spot + Vector2i.RIGHT, true)
	ok(cyrus.declared.aim == first_aim, "one at a time - calling another is refused")
	log_line("")


func landing_it():
	log_line("======== landing it ========")
	var cyrus := who("cyrus")
	var imps := all_of("imp")
	var marked: Array = cyrus.declared.tiles
	# One imp gets off the marked tiles; the other stays.
	var away := a_tile(imps[1], func(tile): return not marked.has(tile) and combat.get_position_distance(tile, imps[1].position) <= 4)
	ok(away.x != -99999 and combat.teleport_to(imps[1], away), "one imp steps off the marked ground", "%s" % [away])
	# And whoever called it walks off out of its reach - it comes down anyway.
	var far := a_tile(cyrus, func(tile): return combat.get_position_distance(tile, cyrus.declared.aim) > SkillDatabase.skills.rockfall.max_range)
	ok(far.x != -99999 and combat.teleport_to(cyrus, far), "Cyrus walks out of its reach", "%s" % [far])
	await settle(1)
	# His next turn comes round before any of the other side has had one.
	await own_turn(cyrus)
	ok(cyrus.has("declared") and imps.all(func(imp): return imp.hp == 900),
		"not while the other side has yet to have a turn to get clear")
	ok(not cyrus.skill_used_this_turn, "and that turn is his own to use")
	# Every one of them has had their turn now.
	for foe in combat.combatants:
		if foe.alive and foe.side == 1:
			combat._turn_begins_for(foe)
	var mark := heard.size()
	await own_turn(cyrus)
	ok(not cyrus.has("declared"), "once they all have, at the start of his next turn it comes down")
	ok(heard_since(mark, "comes down"), "and says so")
	ok(imps[0].hp < 900, "on the imp who stayed", "%d" % imps[0].hp)
	ok(imps[1].hp == 900, "and not the one who moved")
	ok(cyrus.skill_used_this_turn, "spending this turn's action")
	ok(not cyrus.secondary_used_this_turn and combat.controller.movement > 0, "leaving the secondary and his feet")
	ok(combat.current_combatant == combat.combatants.find(cyrus), "and the turn still his")
	log_line("")


func losing_it():
	log_line("======== losing it ========")
	var cyrus := who("cyrus")
	var imps := all_of("imp")
	for imp in imps:
		sturdy(imp)
	var spot: Vector2i = imps[0].position
	var stand := a_tile(cyrus, func(tile):
		var gap: int = combat.get_position_distance(tile, spot)
		return gap >= 3 and gap <= 5 and combat.has_line_of_sight(tile, spot, 0))
	combat.teleport_to(cyrus, stand)
	await settle(1)
	for why in ["stunned", "confused"]:
		cyrus.skill_used_this_turn = false
		combat.current_combatant = combat.combatants.find(cyrus)
		await combat.use_skill("rockfall", cyrus, spot, true)
		ok(cyrus.has("declared"), "called again")
		afflict(cyrus, why)
		var mark := heard.size()
		await own_turn(cyrus)
		# A confused turn is played for him, and ends; the next one is his own.
		cyrus.status_effects = cyrus.status_effects.filter(func(eff): return eff.get("stat", "") != "condition")
		ok(not cyrus.has("declared") and heard_since(mark, "comes to nothing"), "%s, it comes to nothing" % why.capitalize())
		ok(imps.all(func(imp): return not imp.alive or imp.hp == 900 or why == "confused"), "and lands on nobody")
		for imp in imps:
			sturdy(imp)
	log_line("")


func the_ai():
	log_line("======== the enemy calls them too ========")
	var cyrus := who("cyrus")
	var ogre := who("ogre")
	sturdy(cyrus)
	sturdy(ogre)
	sure_of_hand(ogre)
	cyrus.status_effects = []
	# Nobody else in the party falls to whatever it does instead.
	for comb in combat.combatants:
		if comb.side == 0 and comb != cyrus and comb.alive:
			sturdy(comb, 9999)
	var beside := a_tile(cyrus, func(tile): return combat.distance_to(ogre, tile) == 1)
	ok(beside.x != -99999 and combat.teleport_to(cyrus, beside), "Cyrus stands beside the ogre", "%s" % [beside])
	await settle(1)
	var hp_before: int = cyrus.hp
	var mark := heard.size()
	await enemy_turn(ogre, cyrus)
	ok(ogre.has("declared") and ogre.declared.skill == "ground_pound", "the ogre calls a Ground Pound",
		"%s" % [ogre.get("declared", {}).get("skill", "nothing")])
	ok(ogre.get("declared", {}).get("tiles", []).has(cyrus.position), "on where Cyrus is standing")
	ok(cyrus.hp < hp_before or heard_since(mark, "missed"), "and still swings at him the same turn",
		"%d -> %d" % [hp_before, cyrus.hp])
	if not ogre.has("declared"):
		return
	var marked: Array = ogre.declared.tiles
	var off := a_tile(cyrus, func(tile): return not marked.has(tile) and combat.distance_to(ogre, tile) == 1)
	if off.x == -99999:
		off = a_tile(cyrus, func(tile): return not marked.has(tile))
	ok(off.x != -99999 and combat.teleport_to(cyrus, off), "Cyrus steps off the marked ground, still beside it", "%s" % [off])
	await settle(1)
	# The whole party has had a turn since it was called.
	for comb in combat.combatants:
		if comb.alive and comb.side == 0:
			combat._turn_begins_for(comb)
	hp_before = cyrus.hp
	mark = heard.size()
	await enemy_turn(ogre, cyrus)
	ok(heard_since(mark, "comes down") and not ogre.has("declared"), "at the start of its next turn it comes down")
	ok(cyrus.hp == hp_before, "missing him, and with its action spent on it, no swing either", "%d -> %d" % [hp_before, cyrus.hp])
	log_line("")
