extends Node
## The seeded fight RNG (docs/multiplayer_plan.md Step 1; the designer,
## 2026-10-29). Every roll in a fight comes out of Combat.rng, seeded from the
## encounter's "seed" meta - a networked fight's - or at random, so a fight
## begun from one seed and played with the same moves comes out the same
## wherever it is played, and a network has only the moves to send.
##
## - one seed rolls the same numbers and shuffles the same way, another not
## - a fight rolls from its encounter's seed, and from a random one without
## - Combat.gd and CController.gd call no global randf, randi or shuffle (but
##   where a fight with no seed picks its own) - read as text, since a roll
##   that only breaks a replay shows nowhere else
## - one fight played twice from one seed with the same moves - the global
##   generator seeded otherwise and the enemies' turns played at another speed
##   the second time - is the same after every turn of the party's
##   (Combat.fight_state), and says the same; from another seed it is not the
##   same fight, so the check can bite. Everybody's aim is made worse for it
##   (UNSURE_AIM): at full accuracy every blow lands and no roll matters

var LOG_PATH := HarnessLog.path_for("rolls")

var _log: FileAccess = null
var _fail = 0
var _game: Node = null
## What the fight has said since it began, line by line.
var _heard: Array = []

## The fight: two of the party against a rusher, a ranger and a healer, at
## level 8 on the Sappers' map - few enough to play out inside the suite's time.
const SOURCE := "res://data/encounters/encounter_02_sappers.tres"
const CAST := [["enfina", 0], ["cyrus", 0], ["barbarian", 1], ["ranger", 1], ["priest", 1]]
## How many of the party's turns a fight is played for, at most.
const PARTY_TURNS := 14
const SEED := 424242
const OTHER_SEED := 777
## Taken off everybody's accuracy in the fights played, so that about four
## blows in ten miss.
const UNSURE_AIM := 40
## The calls that roll through the global generator. Combat.rng's own are
## allowed; Array.shuffle and pick_random always use the global one.
const GLOBAL_ROLLS := ["randi(", "randf(", "randi_range(", "randf_range(", "randfn(", "randomize(", "seed("]
const GLOBAL_METHODS := [".shuffle(", ".pick_random("]


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
	get_tree().create_timer(280.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


func run_test():
	rolls_and_shuffles()
	await the_fights_seed()
	no_global_rolls()
	await a_fight_replayed()
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


## --- Rolls ---


func rolls_and_shuffles():
	log_line("======== one seed, the same rolls ========")
	var combat := Combat.new()
	var first := draws(combat, 7)
	ok(first == draws(combat, 7), "seeded the same, it rolls the same", "%s" % [first.slice(0, 6)])
	ok(first != draws(combat, 8), "seeded otherwise, it does not")
	ok(combat.fight_seed == 8, "and it keeps the seed it rolls from", "%d" % combat.fight_seed)
	var order := shuffled(combat, 7)
	ok(order == shuffled(combat, 7), "seeded the same, it shuffles the same", "%s" % [order])
	ok(order != shuffled(combat, 8), "seeded otherwise, it does not")
	var each := order.duplicate()
	each.sort()
	ok(each == range(20), "and a shuffle keeps everything, once each")
	combat.free()
	log_line("")


## What `combat` rolls first from `value`: hit rolls, ranges and fractions.
func draws(combat: Combat, value: int) -> Array:
	combat.seed_rolls(value)
	var drawn := []
	for i in 8:
		drawn.append(combat.rng.randi() % 100)
		drawn.append(combat.rng.randi_range(3, 12))
		drawn.append(snappedf(combat.rng.randf(), 0.0001))
	return drawn


func shuffled(combat: Combat, value: int) -> Array:
	combat.seed_rolls(value)
	var order := range(20)
	combat._shuffle(order)
	return order


## --- The fight's seed ---


func the_fights_seed():
	log_line("======== a fight rolls from its encounter's seed ========")
	var combat := await start_fight(true, SEED)
	ok(combat.fight_seed == SEED, "an encounter's seed is the one its fight rolls from", "%d" % combat.fight_seed)
	await end_fight()
	combat = await start_fight(false)
	var one: int = combat.fight_seed
	await end_fight()
	combat = await start_fight(false)
	var two: int = combat.fight_seed
	await end_fight()
	ok(one != two, "with none, each fight rolls from a seed of its own", "%d, %d" % [one, two])
	log_line("")


## --- Nothing rolls by itself ---


func no_global_rolls():
	log_line("======== nothing in the fight rolls by itself ========")
	for path in ["res://combat/Combat.gd", "res://control/CController.gd"]:
		var text := FileAccess.get_file_as_string(path)
		var found := []
		var lines := text.split("\n")
		var function := ""
		for i in lines.size():
			if lines[i].begins_with("func ") or lines[i].begins_with("static func "):
				function = lines[i].get_slice("func ", 1).get_slice("(", 0)
			# Where a fight with no seed given picks its own - the one roll that
			# is meant to come out different everywhere.
			if function == "_seed_wanted":
				continue
			var code := code_of(lines[i])
			if global_roll_in(code):
				found.append("%d: %s" % [i + 1, code.strip_edges()])
		ok(text != "" and found.is_empty(), "%s rolls only through rng" % path.get_file(),
			"%d lines read %s" % [lines.size(), found])
	# The check itself, on lines that do and do not roll by themselves.
	ok(global_roll_in("if randi() % 100 < chance:") and global_roll_in("open.shuffle()")
		and global_roll_in("var x = lines.pick_random()") and global_roll_in("\trandomize()"),
		"  and it sees a roll through the global generator")
	ok(not global_roll_in("if rng.randi() % 100 < chance:") and not global_roll_in("_shuffle(open)")
		and not global_roll_in("seed_rolls(_seed_wanted())") and not global_roll_in("rng.seed = value"),
		"  and passes one through the fight's own")
	log_line("")


## `line` without its comment.
func code_of(line: String) -> String:
	var quote := ""
	var escaped := false
	for i in line.length():
		var c := line[i]
		if quote != "":
			if escaped:
				escaped = false
			elif c == "\\":
				escaped = true
			elif c == quote:
				quote = ""
		elif c == "\"" or c == "'":
			quote = c
		elif c == "#":
			return line.substr(0, i)
	return line


## Whether `code` calls the global generator.
func global_roll_in(code: String) -> bool:
	for call in GLOBAL_ROLLS:
		var at := code.find(call)
		while at != -1:
			var before := code[at - 1] if at > 0 else " "
			# A call of its own, not a word ending in it (rng.randi, seed_rolls).
			if before != "." and not (before == "_" or before.is_valid_identifier() or before.is_valid_int()):
				return true
			at = code.find(call, at + 1)
	for call in GLOBAL_METHODS:
		if code.contains(call):
			return true
	return false


## --- A fight replayed ---


func a_fight_replayed():
	log_line("======== one seed and the same moves, the same fight ========")
	var first := await play_fight(SEED, 1, GameSettings.ENEMY_SPEEDS.size() - 1)
	var again := await play_fight(SEED, 99991, GameSettings.ENEMY_SPEEDS.size() - 2)
	var other := await play_fight(OTHER_SEED, 1, GameSettings.ENEMY_SPEEDS.size() - 1)
	ok(first.size() > 4, "the fight was played for a while", "%d of the party's turns" % (first.size() - 2))
	var said: String = first.back()
	ok(said.count(" missed ") > 0 and said.count(", dealing ") > 0, "and the rolls decided it: blows landed and blows missed",
		"%d landed, %d missed" % [said.count(", dealing "), said.count(" missed ")])
	var parted := first_difference(first, again)
	ok(parted == -1, "played twice from one seed - the global generator seeded otherwise, the enemies faster or slower - it is the same after every turn and says the same",
		"" if parted == -1 else "they part at %d of %d:\n%s\n  ---\n%s" % [parted, first.size(), first[parted], again[parted]])
	ok(first_difference(first, other) != -1, "and played from another seed it is another fight",
		"they part at %d" % first_difference(first, other))
	log_line("  where the first ended:")
	for line in String(first[first.size() - 2]).split("\n"):
		log_line("    " + line)
	log_line("  what it said:")
	for line in String(first.back()).split("\n"):
		if line.strip_edges() != "":
			log_line("    " + line)
	log_line("")


## Plays the fight from `fight_seed` - the global generator seeded with
## `global_seed` first, and the enemies' turns at ENEMY_SPEEDS[`speed`] - for
## PARTY_TURNS of the party's turns. Its state as the party's first turn begins
## and after each of them (Combat.fight_state), and last all it said.
func play_fight(fight_seed: int, global_seed: int, speed: int) -> Array:
	seed(global_seed)
	GameSettings._enemy_speed = speed
	var combat := await start_fight(true, fight_seed)
	# At level 8 every blow here lands, whatever is rolled, and nothing else in
	# the fight is left to chance - so everybody's aim is made worse, and the
	# rolls decide what hits.
	for comb in combat.combatants:
		comb["accuracy"] = comb.get("accuracy", 0) - UNSURE_AIM
	combat.finish_deployment()
	var states := []
	await party_turn(combat)
	states.append(combat.fight_state())
	var turns := 0
	while not combat.combat_over and turns < PARTY_TURNS:
		await party_move(combat, combat.get_current_combatant())
		await party_turn(combat)
		states.append(combat.fight_state())
		turns += 1
	states.append("".join(_heard))
	await end_fight()
	return states


## Where two lists of states first differ, or -1.
func first_difference(a: Array, b: Array) -> int:
	for i in mini(a.size(), b.size()):
		if a[i] != b[i]:
			return i
	return -1 if a.size() == b.size() else mini(a.size(), b.size())


## A fight of CAST on SOURCE's map, everybody on their spawn's tile, rolling
## from `value` when `seeded` (the encounter's "seed" meta). Nobody is here to
## answer a reaction's question, so reactions fire by themselves, as they do in
## a fight with no prompt.
func start_fight(seeded: bool, value: int = 0) -> Combat:
	var source: EncounterDefinition = load(SOURCE)
	var encounter := EncounterDefinition.new()
	encounter.display_name = "Rolls"
	encounter.terrain_scene = source.terrain_scene
	var spawns: Array[SpawnDefinition] = []
	var used := []
	for wanted in CAST:
		for spawn in source.spawns:
			if spawn.combatant_key == wanted[0] and spawn.side == wanted[1] and not used.has(spawn):
				used.append(spawn)
				spawns.append(spawn.duplicate())
				break
	encounter.spawns = spawns
	if seeded:
		encounter.set_meta("seed", value)
	Campaign.reset()
	Campaign.current_encounter = encounter
	_heard.clear()
	_game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(_game)
	for i in 4:
		await get_tree().process_frame
	var combat: Combat = _game.get_node("VisualCombat")
	combat.update_information.connect(func(text: String): _heard.append(text))
	combat.reaction_prompt = null
	return combat


func end_fight():
	if _game != null:
		_game.queue_free()
		_game = null
	await get_tree().process_frame
	await get_tree().process_frame


## Until it is one of the party's turns with nothing still playing out - or the
## fight is over.
func party_turn(combat: Combat):
	while not combat.combat_over and not (combat.controller.player_turn and combat.plays_for_party(combat.get_current_combatant())):
		await get_tree().process_frame


## The move made for `comb`: their first attack that reaches the nearest of the
## other side from where they stand, at them - else nothing - and the turn
## over. Worked out from where everybody is and nothing else, so the same fight
## gets the same moves, as two machines replaying one would.
func party_move(combat: Combat, comb: Dictionary):
	var foe := nearest_foe(combat, comb)
	if not foe.is_empty():
		var aim: Vector2i = combat.nearest_tile_of(foe, comb.position)
		var gap: int = combat.distance_to(comb, aim)
		for key in combat._ai_main_keys(comb):
			var skill: SkillDefinition = SkillDatabase.skills.get(key)
			if skill == null or not combat._hostile(skill) or combat.wasted_on(comb, skill) != "":
				continue
			if gap < skill.min_range or gap > combat.effective_max_range(comb, skill):
				continue
			if skill.respects_blocking and not combat.sees_tile(comb, aim, foe):
				continue
			if combat.refusal_for(comb, skill, aim) != "":
				continue
			await combat.use_skill(key, comb, aim)
			break
	if not combat.combat_over and is_same(combat.get_current_combatant(), comb):
		await combat.advance_turn()


## The nearest of the other side standing - the first of them in the fight's
## own order, of those as near.
func nearest_foe(combat: Combat, comb: Dictionary) -> Dictionary:
	var best := {}
	var best_gap := 1 << 30
	for other in combat.combatants:
		if not other.get("alive", false) or other.get("side", 0) == comb.side \
				or other.has("object") or other.get("illusion", false):
			continue
		var gap: int = combat.distance_to(comb, combat.nearest_tile_of(other, comb.position))
		if gap < best_gap:
			best_gap = gap
			best = other
	return best
