extends Node
## Reproduces the reported Run bug: Cyrus starting later turns already doubled.

var LOG_PATH := HarnessLog.path_for("run")

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
	get_tree().create_timer(90.0).timeout.connect(func(): get_tree().quit(2))
	await get_tree().process_frame
	await get_tree().process_frame
	await run_test()


func run_test():
	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_01_ambush.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	var controller = game.get_node("Controller")
	combat.finish_deployment()
	await get_tree().process_frame

	var cyrus = null
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == "cyrus":
			cyrus = comb
	ok(cyrus != null, "Cyrus is in the battle")
	var base_movement = cyrus.movement
	log_line("Cyrus's base movement: %d" % base_movement)
	log_line("")

	# Make it his turn.
	combat.current_combatant = combat.combatants.find(cyrus)
	controller.set_controlled_combatant(cyrus)
	log_line("======== turn 1 ========")
	ok(controller.movement == base_movement, "starts on base movement", "%d" % controller.movement)

	var run_skill: SkillDefinition = SkillDatabase.skills["run"]
	for effect in run_skill.effects:
		combat.apply_effect(cyrus, cyrus, effect, run_skill, true)
	ok(controller.movement == base_movement * 2, "Run doubles it", "%d" % controller.movement)

	# Second Run, from the secondary slot, same turn.
	for effect in run_skill.effects:
		combat.apply_effect(cyrus, cyrus, effect, run_skill, false)
	ok(controller.movement == base_movement * 4, "a second Run compounds to 4x", "%d (was 18 before the fix)" % controller.movement)
	log_line("")

	log_line("======== turn 2: the reported bug ========")
	# Whatever else happens in between, his next turn starts by processing his
	# statuses and re-reading the effective stat - exactly what advance_turn does.
	combat.process_status_effects(cyrus)
	controller.set_controlled_combatant(cyrus)
	ok(cyrus.status_effects.is_empty(), "Run has expired", "%d effects left" % cyrus.status_effects.size())
	ok(controller.movement == base_movement,
		"turn 2 starts on base movement again", "%d (was 12 before the fix)" % controller.movement)
	log_line("")

	log_line("======== Run again on turn 2 ========")
	for effect in run_skill.effects:
		combat.apply_effect(cyrus, cyrus, effect, run_skill, true)
	ok(controller.movement == base_movement * 2, "still doubles, not triples", "%d (was 18 before the fix)" % controller.movement)
	log_line("")

	log_line("======== movement already spent is respected ========")
	combat.process_status_effects(cyrus)
	controller.set_controlled_combatant(cyrus)
	controller.movement = base_movement - 2   # walked two tiles
	for effect in run_skill.effects:
		combat.apply_effect(cyrus, cyrus, effect, run_skill, true)
	ok(controller.movement == base_movement * 2 - 2,
		"doubling after walking keeps the two tiles spent", "%d" % controller.movement)
	log_line("")

	log_line("======== a debuff on someone else still lasts its full count ========")
	var victim = null
	for comb in combat.combatants:
		if comb.side == 1:
			victim = comb
	var slow := EffectDefinition.new()
	slow.type = EffectDefinition.EffectType.STAT_MODIFIER
	slow.stat = "movement"
	slow.modifier_amount = -2
	slow.duration = 2
	combat.apply_effect(cyrus, victim, slow, null, false)
	ok(victim.status_effects[0].duration == 2,
		"a debuff on a combatant who hasn't acted keeps its full duration", "%d" % victim.status_effects[0].duration)
	var active = 0
	for turn in range(0, 6):
		combat.process_status_effects(victim)
		if victim.status_effects.is_empty():
			break
		active += 1
	ok(active == 2, "and lasts exactly 2 of their turns", "measured %d" % active)
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
