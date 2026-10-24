extends Node
## Prometheus's hacking: the three minigames (Rewrite the Rule, Node
## Infiltration, Tuning the Resonance) played to the end both ways; tries and
## retry costs from his Intellect; gates for hints and for making it simpler,
## outside a fight carried into the next; the clock; walking away; what failing
## leaves (set off, locked for good); and every place one starts - an
## interactable, a conversation, a foe's wind-up in a fight, a thing on the map.

var LOG_PATH := HarnessLog.path_for("hacking")
const MIXED := "res://data/encounters/sizes_big_and_small.tres"

var _log: FileAccess = null
var _fail = 0
var game: Node = null
var combat = null


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
	process_mode = Node.PROCESS_MODE_ALWAYS
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(300.0, true, false, true).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	var booted = get_tree().current_scene
	if booted != null:
		booted.queue_free()
		await settle()
	Campaign.reset()
	Campaign.set_party(["cyrus", "enfina", "prometheus", "alithia"], 10)
	the_numbers()
	await rewrite_the_rule()
	await the_binding_circle()
	every_sheet_can_be_done()
	await node_infiltration()
	await tuning_the_resonance()
	await the_clock_and_walking_away()
	await where_they_start()
	await in_a_fight()
	await close_fight()
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


func until(check: Callable, seconds: float = 5.0) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		if check.call():
			return true
		await get_tree().process_frame
	return check.call()


func hack(key: String) -> HackDefinition:
	return load("res://data/hacks/%s.tres" % key)


## Starts `what` without waiting on it, so the board can be played; `into`
## takes the outcome when it comes.
func begin(what: HackDefinition, id: String, into: Array):
	var running := func():
		into.append(await Hacking.run(what, id))
	running.call()
	await until(func(): return Hacking.running() and Hacking.board() != null)
	await settle(2)


## Plays a Rewrite board to its solution - locked lines once what they wait on
## has moved.
func solve_rewrite(board: RewriteBoard):
	if board.per_step():
		for move in board.solve_moves(board.values, board.budget - board.spent):
			board.change(move[0], move[1])
		board.commit()
		return
	var solution := board.solve()
	for round in 4:
		for i in board.values.size():
			while board.values[i] != solution[i] and board.change(i, signi(solution[i] - board.values[i])):
				pass
	board.commit()


func the_numbers():
	log_line("======== tries and costs from his Intellect ========")
	var ward := hack("archive_ward")
	ok(Hacking.tries_for(ward, Hacking.INTELLECT_PIVOT) == ward.tries, "at the pivot, the tries written")
	ok(Hacking.tries_for(ward, Hacking.INTELLECT_PIVOT * 2.0) == ward.tries * 2, "twice the Intellect, twice the tries")
	ok(is_equal_approx(Hacking.retry_cost_for(ward, Hacking.INTELLECT_PIVOT * 2.0), ward.retry_cost_amount / 2.0),
		"and each retry half the cost")
	ok(Hacking.tries_for(ward, 5.0) == 1, "never fewer than one")
	ok(Hacking.hacker_key() == "prometheus", "Prometheus is the one who hacks")
	var intellect := Hacking.intellect_of_member("prometheus")
	log_line("  NOTE  Prometheus at level 10: Intellect %d, %d tries at the ward, a retry %.1f health" % [
		intellect, Hacking.tries_for(ward, intellect), Hacking.retry_cost_for(ward, intellect)])
	log_line("")


func rewrite_the_rule():
	log_line("======== Rewrite the Rule ========")
	var outcome := []
	await begin(hack("archive_ward"), "test_ward", outcome)
	var board: RewriteBoard = Hacking.board()
	ok(board is RewriteBoard and board.values.size() == 5, "the ward's sheet, five lines")
	var stability := board.line_called("Stability")
	ok(board.is_locked(stability) and not board.change(stability, -1), "Stability is locked until Wakes changes")
	ok(not board.solve().is_empty(), "there is a way to rewrite it within its edits")
	var tries_before: int = Hacking.tries_left()
	var hp_before: int = Campaign.party_state.get("prometheus", {}).get("hp", 9999)
	board.commit()
	await settle(2)
	ok(Hacking.tries_left() == tries_before - 1, "committing it unchanged spends a try")
	var hp_after: int = Campaign.party_state.get("prometheus", {}).get("hp", 9999)
	ok(hp_after < hp_before, "and the retry strains him", "%d -> %d" % [hp_before, hp_after])
	# A hint, and making it simpler, from his gates - the next fight's.
	var left_before: Array = Campaign.gates_left_outside("prometheus")
	ok(Hacking.ask_hint() and not board.revealed.is_empty(), "a gate buys a hint: a line's answer shown")
	var left_after: Array = Campaign.gates_left_outside("prometheus")
	ok(left_after[1] == left_before[1] - 1, "a World gate spent", "%s -> %s" % [left_before, left_after])
	ok(Hacking.ask_simplify() and board.simplified and not board.is_locked(stability), "a Hermes gate makes it simpler: no locks")
	ok(not Hacking.ask_simplify(), "once a hack")
	var spent_comb := {"spell_slots": left_before.duplicate()}
	Campaign.take_gates_spent_outside(spent_comb, "prometheus")
	ok(spent_comb.spell_slots[1] == left_before[1] - 1 and spent_comb.spell_slots[2] == left_before[2] - 1,
		"and the next fight opens without them", "%s" % [spent_comb.spell_slots])
	solve_rewrite(board)
	await until(func(): return not outcome.is_empty())
	ok(not outcome.is_empty() and outcome[0].result == "success", "rewritten", "%s" % [outcome])
	ok(Hacking.succeeded("test_ward"), "and it stays hacked")
	log_line("")


func the_binding_circle():
	log_line("======== Rewrite the Rule, the hard way: lines that drag each other ========")
	var outcome := []
	await begin(hack("binding_circle"), "test_circle", outcome)
	var board: RewriteBoard = Hacking.board()
	ok(board.per_step(), "every step costs, its lines pushing each other")
	var moves := board.solve_moves(board.starts(), board.budget)
	var cost := 0
	for move in moves:
		cost += board.hack.lines[move[0]].cost
	ok(not moves.is_empty() and cost == board.budget, "there is a way, and it takes every edit there is",
		"%d steps, %d of %d edits" % [moves.size(), cost, board.budget])
	ok(board.solve_moves(board.starts(), board.budget - 1).is_empty(), "with one edit fewer, there is none")
	var targets := board.line_called("Targets")
	var strength := board.line_called("Strength")
	var reach := board.line_called("Reach")
	board.change(targets, 1)
	board.change(targets, 1)
	var pushed: bool = board.change(strength, 1) and board.change(strength, 1)
	ok(pushed and not board.change(strength, 1), "the straight way fails: Owners and two steps of Strength leave Stability at nothing, and the third step is refused",
		"Stability %d" % board.values[board.line_called("Stability")])
	board.start_over()
	ok(board.spent == 0 and board.values == board.starts(), "Start Over gives every edit back")
	board.change(reach, 1)
	board.change(reach, -1)
	ok(board.spent == 2 and board.values == board.starts(), "a step there and back costs two")
	board.start_over()
	ok(Hacking.ask_hint() and board.revealed.size() == 1 and String(board.revealed.values()[0]).begins_with("next:"),
		"a hint shows the next step to take", "%s" % [board.revealed])
	var gates_before: Array = Hacking.gates_left()
	ok(not board.hint_available() and not Hacking.ask_hint(), "asked again before a step is taken, there is nothing new")
	ok(Hacking.gates_left() == gates_before, "and nothing is paid for it", "%s" % [Hacking.gates_left()])
	var next_step: Array = board.solve_moves(board.values, board.budget - board.spent)[0]
	board.change(next_step[0], next_step[1])
	ok(board.hint_available(), "a step taken, there is a new one to show")
	ok(Hacking._gates_row != null and Hacking._gates_row.get_child_count() > 1, "and the hacker's gates are on show")
	# Two edits wasted on a step there and back, and the budget no longer goes
	# round: a hint says so, for nothing.
	board.change(reach, 1)
	board.change(reach, -1)
	gates_before = Hacking.gates_left()
	ok(board.dead_end() and not Hacking.ask_hint(), "with no way through left this try, a hint is no hint")
	ok(Hacking.gates_left() == gates_before and "no way through" in Hacking._message.text, "and it says so for nothing",
		Hacking._message.text)
	ok(not board.hint_available(), "once")
	board.start_over()
	solve_rewrite(board)
	await until(func(): return not outcome.is_empty())
	ok(not outcome.is_empty() and outcome[0].result == "success", "and the cheapest way through rewrites it")
	log_line("")


## Every Rewrite sheet there is: a way through within its edits - and for one
## paid step by step, none with an edit fewer, so the budget is the puzzle.
func every_sheet_can_be_done():
	log_line("======== every Rewrite sheet can be done ========")
	for file in DirAccess.get_files_at("res://data/hacks"):
		var listed: String = file.trim_suffix(".remap")
		if not listed.ends_with(".tres"):
			continue
		var sheet: HackDefinition = load("res://data/hacks/" + listed)
		if sheet.kind != HackDefinition.Kind.REWRITE:
			continue
		var board := RewriteBoard.new()
		board.hack = sheet
		board.budget = sheet.edits
		var done := not board.solve().is_empty()
		var tight := true
		var steps := 0
		if board.per_step():
			var moves := board.solve_moves(board.starts(), sheet.edits)
			steps = moves.size()
			tight = board.solve_moves(board.starts(), sheet.edits - 1).is_empty()
		ok(done and tight, "%s can be done within its %d edits%s" % [sheet.title, sheet.edits, ", and no fewer" if board.per_step() else ""],
			"%d steps" % steps if steps > 0 else "")
		board.free()
	log_line("")


func node_infiltration():
	log_line("======== Node Infiltration ========")
	var outcome := []
	await begin(hack("vault_terminal"), "test_vault", outcome)
	var board: InfiltrateBoard = Hacking.board()
	ok(board is InfiltrateBoard and board.sentinels.size() == 2, "a grid, two sentinels")
	ok(board.moves == 0 and board.player == board.start, "a fresh board: at the login node, no moves made", "%d moves" % board.moves)
	# A first step no sentinel catches, so the try is not over before it counts.
	var first_step: Vector2i = board.links[board.player][0]
	for step in board.links[board.player]:
		if not board.caught(board.player, step, 1):
			first_step = step
			break
	board.move_to(first_step)
	ok(board.moves == 1, "one move is one move", "%d" % board.moves)
	# Back to a fresh try for the rest.
	board.reset_try(RandomNumberGenerator.new())
	var way := board._way_through(0)
	ok(not way.is_empty() and way.size() - 1 <= board.move_limit, "with a way through in the moves it allows",
		"%d moves of %d" % [way.size() - 1, board.move_limit])
	ok(not board.move_to(board.core) or board.core in board.links[board.start], "it cannot jump to the core")
	# Waiting out every move is running out of them.
	var tries_before: int = Hacking.tries_left()
	for i in board.move_limit:
		board.move_to(board.player)
	await settle(2)
	ok(Hacking.tries_left() == tries_before - 1, "out of moves, the try is spent")
	ok(Hacking.ask_hint() and not board.shown_way.is_empty(), "a hint shows the way, and where the sentinels go next")
	var sentinels_before: int = board.sentinels.size()
	Hacking.ask_simplify()
	ok(board.sentinels.size() == sentinels_before - 1, "simpler, a sentinel is taken off")
	way = board._way_through(board.moves)
	for step in way.slice(1):
		board.move_to(step)
	await until(func(): return not outcome.is_empty())
	ok(not outcome.is_empty() and outcome[0].result == "success", "in", "%s" % [outcome])
	log_line("")
	log_line("======== failing it ========")
	outcome = []
	Campaign.clear_flag("hacked:test_vault")
	await begin(hack("vault_terminal"), "test_vault_2", outcome)
	board = Hacking.board()
	for i in board.move_limit:
		board.move_to(board.player)
	await settle(2)
	Hacking.walk_away()
	await until(func(): return not outcome.is_empty())
	ok(not outcome.is_empty() and outcome[0].result == "failed", "walking away after a failed try is failing")
	ok(Hacking.set_off_by("test_vault_2") and not Hacking.locked("test_vault_2"), "the terminal is set off, and can be tried again")
	log_line("")


func tuning_the_resonance():
	log_line("======== Tuning the Resonance ========")
	var outcome := []
	await begin(hack("sealed_resonance"), "test_seal", outcome)
	var board: ResonanceBoard = Hacking.board()
	ok(board is ResonanceBoard and board.targets.size() == 3, "three dials, a wave to match")
	ok(Hacking.ask_hint() and board.revealed.size() == 1, "a hint marks where one dial has to be")
	var tolerance: int = board.tolerance
	Hacking.ask_simplify()
	ok(board.tolerance == tolerance * 2, "simpler, twice the room either side")
	for i in board.targets.size():
		board.set_dial(i, board.targets[i])
	ok(is_equal_approx(board.nearness(), 1.0), "matched, the wave is all the way there")
	board.lock()
	await until(func(): return not outcome.is_empty())
	ok(not outcome.is_empty() and outcome[0].result == "success", "locked in")
	log_line("")
	log_line("======== locked for good ========")
	outcome = []
	await begin(hack("sealed_resonance"), "test_seal_2", outcome)
	board = Hacking.board()
	var tries: int = Hacking.tries_left()
	for attempt in tries:
		for i in board.targets.size():
			board.set_dial(i, (board.targets[i] + 50) % 100)
		board.lock()
		await settle(2)
	await until(func(): return not outcome.is_empty())
	ok(not outcome.is_empty() and outcome[0].result == "failed", "every try off, it fails")
	ok(Hacking.locked("test_seal_2"), "and the seal is locked for good")
	var again: Dictionary = await Hacking.run(hack("sealed_resonance"), "test_seal_2")
	ok(again.result == "locked", "never to be tried again")
	log_line("")


func the_clock_and_walking_away():
	log_line("======== the clock ========")
	var quick := HackDefinition.new()
	quick.kind = HackDefinition.Kind.RESONANCE
	quick.tries = 1
	quick.time_limit = 1
	quick.dials = 1
	var outcome := []
	await begin(quick, "", outcome)
	var timed_out := await until(func(): return not outcome.is_empty(), 4.0)
	ok(timed_out and outcome[0].result == "failed", "out of time is a try spent - the only one")
	log_line("")
	log_line("======== walking away ========")
	outcome = []
	await begin(hack("archive_ward"), "test_walk", outcome)
	Hacking.walk_away()
	await until(func(): return not outcome.is_empty())
	ok(outcome[0].result == "walked_away" and not Hacking.set_off_by("test_walk") and not Hacking.locked("test_walk"),
		"walking away before a try has failed costs nothing")
	log_line("")
	log_line("======== nobody to hack it ========")
	Campaign.remove_member("prometheus", true)
	var nobody: Dictionary = await Hacking.run(hack("archive_ward"), "test_nobody")
	ok(nobody.result == "nobody", "without Prometheus in the party, nobody can")
	Campaign.add_member("prometheus")
	log_line("")


func where_they_start():
	log_line("======== a hack-locked interactable ========")
	var thing := Interactable.new()
	thing.name = "TestTerminal"
	thing.hack = hack("sealed_resonance")
	thing.sets_flag = "test_terminal_used"
	add_child(thing)
	var used := func(): await thing.use(null)
	used.call()
	await until(func(): return Hacking.running() and Hacking.board() != null)
	await settle(2)
	ok(not Campaign.flag("test_terminal_used"), "it does nothing until hacked")
	var board: ResonanceBoard = Hacking.board()
	for i in board.targets.size():
		board.set_dial(i, board.targets[i])
	board.lock()
	await until(func(): return Campaign.flag("test_terminal_used"))
	ok(Campaign.flag("test_terminal_used"), "hacked, it is used")
	ok(Hacking.succeeded(thing.hack_id()), "and stays hacked", thing.hack_id())
	thing.queue_free()
	log_line("")
	log_line("======== from a conversation ========")
	var result := []
	var talked := func(): result.append(await Hacking.start("archive_ward"))
	talked.call()
	await until(func(): return Hacking.running() and Hacking.board() != null)
	await settle(2)
	solve_rewrite(Hacking.board())
	await until(func(): return not result.is_empty())
	ok(result == [true] and Hacking.succeeded("archive_ward"), "do Hacking.start(\"archive_ward\") plays it, and says how it went")
	log_line("")
	log_line("======== a hack-locked spot in a picture ========")
	Pictures.open("res://pictures/lab_workbench.tscn")
	await settle(4)
	var strongbox: Hotspot = Pictures.current().get_node("StrongboxSpot")
	ok(strongbox != null and strongbox.hack != null, "the workbench's strongbox has a hack")
	Pictures.click(strongbox)
	await until(func(): return Hacking.running() and Hacking.board() != null)
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	Hacking._input(escape)
	Pictures._input(escape)
	await until(func(): return not Hacking.running())
	ok(not Hacking.running() and Pictures.is_open() and not Campaign.flag("strongbox_open"),
		"Escape walks away from the hack, and leaves the picture open")
	Pictures.click(strongbox)
	await until(func(): return Hacking.running() and Hacking.board() != null)
	await settle(2)
	ok(not Campaign.flag("strongbox_open") and Campaign.carrier_of("fireball_gate_nade") == "", "nothing until it is hacked")
	var box_board: ResonanceBoard = Hacking.board()
	for i in box_board.targets.size():
		box_board.set_dial(i, box_board.targets[i])
	box_board.lock()
	await until(func(): return Campaign.flag("strongbox_open"))
	ok(Campaign.flag("strongbox_open") and Campaign.carrier_of("fireball_gate_nade") != "", "hacked, it opens - and the Gate Nade inside is taken")
	ok(Hacking.succeeded(strongbox.examined_id()), "and stays hacked", strongbox.examined_id())
	Pictures.close()
	await settle(3)
	log_line("")


func open_fight():
	Campaign.reset()
	Campaign.current_encounter = load(MIXED)
	game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(6)
	combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(3)


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


func give_turn(comb: Dictionary):
	combat.current_combatant = combat.combatants.find(comb)
	combat.controller.set_controlled_combatant(comb)
	combat.controller.player_turn = true
	combat.controller.action_locked = false
	comb.skill_used_this_turn = false
	comb.secondary_used_this_turn = false


## Uses `key` without waiting on it, and returns once its hack is up.
func hack_with(key: String, user: Dictionary, at: Vector2i, done: Array):
	var using := func():
		await combat.use_skill(key, user, at, false)
		done.append(true)
	using.call()
	await until(func(): return (Hacking.running() and Hacking.board() != null) or not done.is_empty())
	await settle(2)


func in_a_fight():
	log_line("======== hacking a foe's wind-up ========")
	await open_fight()
	var prometheus := who("prometheus")
	var cyrus := who("cyrus")
	var ogre := who("ogre")
	prometheus.max_hp = 500
	prometheus.hp = 500
	cyrus.max_hp = 500
	cyrus.hp = 500
	ok(prometheus.skill_list.has("hack") and combat.can_hack(prometheus) and not combat.can_hack(cyrus),
		"Prometheus has Hack, and Prying Mind; Cyrus neither")
	var near := Vector2i(-99999, -99999)
	var region: Rect2i = combat.controller._astargrid.region
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var tile := Vector2i(x, y)
			if near.x == -99999 and combat.room_for(prometheus, tile) and combat.distance_to(ogre, tile) >= 2 and combat.distance_to(ogre, tile) <= 4:
				near = tile
	combat.teleport_to(prometheus, near)
	var ground_pound: SkillDefinition = SkillDatabase.skills["ground_pound"]
	ground_pound.hackable = false
	combat.declare(ogre, "ground_pound", prometheus.position)
	give_turn(prometheus)
	var done := []
	ok(combat.refusal_for(prometheus, SkillDatabase.skills["hack"], ogre.position) != "",
		"a move that isn't Hackable can't be hacked", combat.refusal_for(prometheus, SkillDatabase.skills["hack"], ogre.position))
	await hack_with("hack", prometheus, ogre.position, done)
	ok(not Hacking.running() and ogre.has("declared") and not prometheus.skill_used_this_turn,
		"refused: no minigame, nothing spent, and it still comes")
	ground_pound.hackable = true
	ok(combat.refusal_for(prometheus, SkillDatabase.skills["hack"], ogre.position) == "", "ticked Hackable, it can")
	give_turn(prometheus)
	done = []
	await hack_with("hack", prometheus, ogre.position, done)
	var board: ResonanceBoard = Hacking.board()
	ok(board != null, "Hack on the ogre winding up a Ground Pound opens the minigame")
	for i in board.targets.size():
		board.set_dial(i, board.targets[i])
	board.lock()
	await until(func(): return not done.is_empty())
	ok(not ogre.has("declared"), "won, the Ground Pound comes to nothing")
	ok(prometheus.skill_used_this_turn, "and it took his action")
	log_line("")
	log_line("======== losing it ========")
	combat.declare(ogre, "ground_pound", prometheus.position)
	give_turn(prometheus)
	var hp_before: int = prometheus.hp
	done = []
	await hack_with("hack", prometheus, ogre.position, done)
	board = Hacking.board()
	var tries: int = Hacking.tries_left()
	for attempt in tries:
		for i in board.targets.size():
			board.set_dial(i, (board.targets[i] + 50) % 100)
		board.lock()
		await settle(2)
	await until(func(): return not done.is_empty(), 15.0)
	ok(not ogre.has("declared"), "lost, the Ground Pound goes off early instead")
	ok(prometheus.hp < hp_before, "on him", "%d -> %d" % [hp_before, prometheus.hp])
	log_line("")
	log_line("======== who can ========")
	combat.declare(ogre, "ground_pound", cyrus.position)
	give_turn(cyrus)
	done = []
	await hack_with("hack", cyrus, ogre.position, done)
	ok(not Hacking.running() and ogre.has("declared") and not cyrus.skill_used_this_turn, "Cyrus cannot hack: refused, nothing spent")
	combat.drop_declared(ogre, "test")
	log_line("")
	log_line("======== a thing on the map that has to be hacked ========")
	var turret := BattleObjectDefinition.new()
	turret.name = "Turret"
	turret.max_hp = 10
	turret.max_hp_level_20 = 10
	turret.hack = hack("unpick_a_spell")
	turret.blast_radius = 2
	turret.blast_damage = 30
	turret.blast_hits = HazardDefinition.Hits.THE_ENEMIES
	var thing: Dictionary = combat.create_combatant(turret, "turret_test")
	var beside := Vector2i(-99999, -99999)
	for way in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		if beside.x == -99999 and combat.room_for(thing, prometheus.position + way):
			beside = prometheus.position + way
	combat.add_mid_round(thing, 1, beside)
	await settle(2)
	ok(prometheus.skill_list.has("use"), "something to Use, so the party can")
	give_turn(cyrus)
	var cyrus_beside := Vector2i(-99999, -99999)
	for way in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		if cyrus_beside.x == -99999 and combat.room_for(cyrus, beside + way):
			cyrus_beside = beside + way
	combat.teleport_to(cyrus, cyrus_beside)
	done = []
	await hack_with("use", cyrus, beside, done)
	ok(not Hacking.running() and thing.alive and not cyrus.skill_used_this_turn, "Cyrus cannot work it")
	give_turn(prometheus)
	done = []
	await hack_with("use", prometheus, beside, done)
	board = Hacking.board()
	for i in board.targets.size():
		board.set_dial(i, board.targets[i])
	board.lock()
	await until(func(): return not done.is_empty())
	ok(thing.get("hacked", false) and not thing.alive, "hacked by Prometheus, it is Used: it goes off and is gone")
	log_line("")
