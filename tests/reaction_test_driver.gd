extends Node
## Tests the interactive reaction prompt: players are asked, enemies aren't,
## and passing leaves the reaction unspent.

var LOG_PATH := HarnessLog.path_for("reaction")

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
	get_tree().create_timer(120.0).timeout.connect(func(): log_line("TIMED OUT"); get_tree().quit(2))
	await get_tree().process_frame
	await get_tree().process_frame
	await run_test()


## Answers the prompt as soon as it appears, as a player would. Returned as a
## Callable so it can be started alongside the await that's waiting on it -
## a named coroutine can only be called with await, which would deadlock.
func answerer(prompt, use_it: bool) -> Callable:
	return func():
		while not prompt._waiting:
			await get_tree().process_frame
		prompt._answer_with(use_it)


func run_test():
	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_01_ambush.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	var controller = game.get_node("Controller")
	var prompt = game.get_node_or_null("ReactionPrompt")
	combat.finish_deployment()
	await get_tree().process_frame

	log_line("======== the prompt is wired up ========")
	ok(prompt != null, "ReactionPrompt is in the battle scene")
	ok(combat.reaction_prompt == prompt, "Combat has it")
	ok(not prompt.get_node("Panel").visible, "and it starts hidden")
	log_line("")

	# The hero has to actually own a reactive skill for the trigger tests.
	var hero = null
	var foe = null
	for comb in combat.combatants:
		if comb.side == 0 and hero == null:
			for key in comb.skill_list:
				if SkillDatabase.skills[key].is_reactive:
					hero = comb
					break
		elif comb.side == 1 and foe == null:
			foe = comb
	ok(hero != null, "found a player combatant with a reactive skill")
	ok(foe != null, "and an enemy to react to")
	if hero == null or foe == null:
		log_line("FAILURES: %d" % _fail)
		get_tree().quit(1)
		return
	log_line("hero=%s foe=%s" % [hero.name, foe.name])
	# Nobody else gets to interfere with the counts below.
	for comb in combat.combatants:
		if comb != hero:
			comb.reaction_used = true

	var adjacent = hero.position + Vector2i(1, 0)
	var far_away = hero.position + Vector2i(6, 0)
	foe.position = adjacent
	var melee: SkillDefinition = SkillDatabase.skills["greatsword_attack"]

	log_line("======== an enemy is never asked ========")
	foe.reaction_used = false
	var enemy_says = await combat.confirm_reaction(foe, hero, melee)
	ok(enemy_says == true, "an enemy reaction is taken automatically")
	ok(not prompt.get_node("Panel").visible, "no prompt was shown for it")
	foe.reaction_used = true
	log_line("")

	log_line("======== the player is asked, and can use it ========")
	hero.reaction_used = false
	answerer(prompt, true).call()
	var answered_use = await combat.confirm_reaction(hero, foe, melee)
	ok(answered_use == true, "answering Use returns true")
	ok(not prompt.get_node("Panel").visible, "the panel closes afterwards")
	log_line("")

	log_line("======== ...or pass, leaving the reaction unspent ========")
	hero.reaction_used = false
	answerer(prompt, false).call()
	var answered_skip = await combat.confirm_reaction(hero, foe, melee)
	ok(answered_skip == false, "answering Skip returns false")
	ok(hero.reaction_used == false, "the reaction is still available afterwards")
	log_line("")

	log_line("======== passing really does stop the skill resolving ========")
	hero.reaction_used = false
	foe.position = adjacent
	foe.hp = foe.max_hp
	var hp_before = foe.hp
	answerer(prompt, false).call()
	await combat.check_reactive_skills(foe, adjacent, far_away)
	ok(foe.hp == hp_before, "the mover takes no damage when the player passes", "hp=%d" % foe.hp)
	ok(hero.reaction_used == false, "and can still react to the next one", "used=%s" % hero.reaction_used)
	log_line("")

	log_line("======== ...and saying yes does resolve it ========")
	foe.position = adjacent
	foe.hp = foe.max_hp
	hp_before = foe.hp
	# Attack (Melee) is a 90% skill, so one run in ten would otherwise miss
	# here and report a working reaction as broken. What is being tested is
	# that saying yes resolves the skill, not whether the dice were kind.
	var accuracy_was = melee.accuracy
	melee.accuracy = 100
	answerer(prompt, true).call()
	await combat.check_reactive_skills(foe, adjacent, far_away)
	melee.accuracy = accuracy_was
	ok(hero.reaction_used == true, "using it spends the reaction", "used=%s" % hero.reaction_used)
	ok(foe.hp < hp_before or not foe.alive, "and the mover was actually hit", "hp=%d/%d" % [foe.hp, hp_before])
	log_line("")

	log_line("======== the movement timeouts don't count while asking ========")
	ok(controller.has_method("waiting_on_player"), "the controller can tell when a question is up")
	ok(not controller.waiting_on_player(), "nothing is being asked right now")
	hero.reaction_used = false
	var seen_set = [false]
	var slow = func():
		while not prompt._waiting:
			await get_tree().process_frame
		seen_set[0] = controller.waiting_on_player()
		prompt._answer_with(false)
	slow.call()
	await combat.confirm_reaction(hero, foe, melee)
	ok(seen_set[0], "it reports true while the question is up")
	ok(not controller.waiting_on_player(), "and false once answered")
	# Derived from the prompt, not a flag Combat sets: an ask() that never
	# returned used to leave the timeouts switched off for good.
	prompt._waiting = true
	ok(controller.waiting_on_player(), "it follows the prompt's own state")
	prompt._waiting = false
	ok(not controller.waiting_on_player(), "in both directions")
	log_line("")

	log_line("======== a walk step always lands on its waypoint ========")
	# 60fps, 576 px/s, so 9.6px a frame. A straight tile divides evenly; a
	# diagonal leaves a remainder that used to overshoot and oscillate forever.
	var step = (1.0 / 60.0) * controller.move_speed
	for target in [Vector2(192, 0), Vector2(192, 192), Vector2(-192, 192), Vector2(577, 131)]:
		var at = Vector2.ZERO
		var frames = 0
		while at.distance_to(target) >= 1 and frames < 2000:
			at = CController.advance_towards(at, target, step)
			frames += 1
		ok(at.distance_to(target) < 1, "reaches %s" % target, "in %d frames" % frames)
	ok(CController.advance_towards(Vector2(10, 0), Vector2(12, 0), 50.0) == Vector2(12, 0),
		"a step longer than the gap lands exactly, not past it")
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
