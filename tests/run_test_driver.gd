extends Node
## Reproduces the reported Run bug: Cyrus starting later turns already doubled.
## Durations run one turn past their number now (Combat.turns_stored), so Run 1 is
## the turn it is used in and the next - and must be gone by the one after.

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

	log_line("======== turn 2: Run 1 holds through the next turn ========")
	# Whatever else happens in between, his turn ends by taking a turn off his
	# statuses, his next starts by ticking them, and the effective stat is read
	# again - exactly what advance_turn does. A duration runs one turn past its
	# number (Combat.turns_stored): Run 1 is the turn it is used in and the next, so
	# both of turn 1's Runs are still on him.
	combat.end_of_turn_effects(cyrus)
	combat.start_of_turn_effects(cyrus)
	controller.set_controlled_combatant(cyrus)
	ok(cyrus.status_effects.size() == 2, "both Runs are still on him", "%d effects" % cyrus.status_effects.size())
	ok(controller.movement == base_movement * 4,
		"so turn 2 starts on what turn 1 ended on", "%d" % controller.movement)
	log_line("")

	log_line("======== turn 3: and no further - the reported bug ========")
	# The bug that was reported: Cyrus starting later turns already doubled. The
	# turn after next is where Run must be gone.
	combat.end_of_turn_effects(cyrus)
	combat.start_of_turn_effects(cyrus)
	controller.set_controlled_combatant(cyrus)
	ok(cyrus.status_effects.is_empty(), "Run has expired", "%d effects left" % cyrus.status_effects.size())
	ok(controller.movement == base_movement,
		"turn 3 starts on base movement again", "%d" % controller.movement)
	log_line("")

	log_line("======== Run again on turn 3 ========")
	for effect in run_skill.effects:
		combat.apply_effect(cyrus, cyrus, effect, run_skill, true)
	ok(controller.movement == base_movement * 2, "still doubles, not triples", "%d (was 18 before the fix)" % controller.movement)
	log_line("")

	log_line("======== movement already spent is respected ========")
	# A turn with nothing on him, so the arithmetic is Run's alone: the Run
	# just used would still be doubling the next one.
	cyrus.status_effects.clear()
	controller.set_controlled_combatant(cyrus)
	controller.movement = base_movement - 2   # walked two tiles
	for effect in run_skill.effects:
		combat.apply_effect(cyrus, cyrus, effect, run_skill, true)
	ok(controller.movement == base_movement * 2 - 2,
		"doubling after walking keeps the two tiles spent", "%d" % controller.movement)
	log_line("")

	log_line("======== Guard goes as his next turn starts ========")
	# Guard is for the enemies' turns, so it is set to wear off at the start of
	# a turn: on through theirs, gone the moment before his own.
	cyrus.status_effects.clear()
	var guard_skill: SkillDefinition = SkillDatabase.skills["guard"]
	for effect in guard_skill.effects:
		combat.apply_effect(cyrus, cyrus, effect, guard_skill, true)
	ok(cyrus.status_effects.size() == 1 and cyrus.status_effects[0].get("ends_at_start", false),
		"Guard is on him, set to go as a turn starts", "%s" % [cyrus.status_effects])
	combat.end_of_turn_effects(cyrus)
	ok(cyrus.status_effects.size() == 1, "still on him through everybody else's turns")
	combat.start_of_turn_effects(cyrus)
	ok(cyrus.status_effects.is_empty(), "and gone as his next turn starts", "%d left" % cyrus.status_effects.size())
	var ui = game.get_node("CanvasLayer/UI")
	var guard_says: String = ui.describe_effect(guard_skill.effects[0], guard_skill)
	var run_says: String = ui.describe_effect(run_skill.effects[0], run_skill)
	ok(guard_says.contains("gone as the next starts"), "Guard's preview says it goes as the next turn starts", guard_says)
	ok(run_says.contains("for 2 turn(s), gone as the last ends"), "Run's says it lasts this turn and the next, and goes as that ends", run_says)
	log_line("")

	log_line("======== a debuff on someone else lasts its count and the turn after ========")
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
	ok(victim.status_effects[0].duration == 3,
		"a 2-turn debuff on a combatant who hasn't acted lands as 3", "%d" % victim.status_effects[0].duration)
	var active = 0
	for turn in range(0, 6):
		combat.start_of_turn_effects(victim)
		if victim.status_effects.is_empty():
			break
		active += 1
		combat.end_of_turn_effects(victim)
	ok(active == 3, "and lasts exactly 3 of their turns", "measured %d" % active)
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
