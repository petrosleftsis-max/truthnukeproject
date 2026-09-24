extends Node
## A skill can set how long the condition it inflicts lasts, instead of every
## skill landing the condition's own duration.

var LOG_PATH := HarnessLog.path_for("condur")

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
	get_tree().create_timer(120.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


## The duration actually stored on the target for the last condition applied.
func stored_turns(comb: Dictionary) -> int:
	for entry in comb.status_effects:
		if entry.get("stat", "") == "condition":
			return entry.duration
	return -1


func run_test():
	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_01_ambush.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	combat.finish_deployment()
	await get_tree().process_frame

	# Somebody who is NOT the one currently acting, so the "docked by one for
	# whoever is mid-turn" rule doesn't muddy the numbers being read here.
	var acting = combat.get_current_combatant()
	var target = null
	for comb in combat.combatants:
		if comb != acting and comb.alive:
			target = comb
			break

	var blind: ConditionDefinition = load("res://conditions/blind.tres")
	log_line("======== the condition's own duration is the default ========")
	ok(blind.duration == 3, "Blind is written as 3 turns", "%d" % blind.duration)

	var plain := EffectDefinition.new()
	plain.type = EffectDefinition.EffectType.CONDITION
	plain.condition = blind
	ok(plain.condition_duration == 0, "a fresh effect overrides nothing", "%d" % plain.condition_duration)

	target.status_effects.clear()
	combat.apply_effect(acting, target, plain, null, false)
	ok(stored_turns(target) == 3, "so it lands the condition's own 3", "%d" % stored_turns(target))
	log_line("")

	log_line("======== a skill can say otherwise ========")
	var brief := EffectDefinition.new()
	brief.type = EffectDefinition.EffectType.CONDITION
	brief.condition = blind
	brief.condition_duration = 1
	target.status_effects.clear()
	combat.apply_effect(acting, target, brief, null, false)
	ok(stored_turns(target) == 1, "a 1-turn Blind lands as 1", "%d" % stored_turns(target))

	var punishing := EffectDefinition.new()
	punishing.type = EffectDefinition.EffectType.CONDITION
	punishing.condition = blind
	punishing.condition_duration = 8
	target.status_effects.clear()
	combat.apply_effect(acting, target, punishing, null, false)
	ok(stored_turns(target) == 8, "an 8-turn Blind lands as 8", "%d" % stored_turns(target))

	ok(blind.duration == 3, "and the condition resource is untouched by either", "%d" % blind.duration)
	log_line("")

	log_line("======== it works for every condition, not just Blind ========")
	for name in ["stunned", "fear", "crystallised", "windswept", "poisoned", "burn", "frozen"]:
		var definition: ConditionDefinition = load("res://conditions/%s.tres" % name)
		var effect := EffectDefinition.new()
		effect.type = EffectDefinition.EffectType.CONDITION
		effect.condition = definition
		effect.condition_duration = 5
		target.status_effects.clear()
		combat.apply_effect(acting, target, effect, null, false)
		ok(stored_turns(target) == 5, "%s overridden to 5" % name, "own duration is %d" % definition.duration)
	log_line("")

	log_line("======== landing on whoever is acting still costs a turn ========")
	# The existing rule: a condition put on the combatant part-way through their
	# own turn shouldn't get that turn for free.
	acting.status_effects.clear()
	combat.apply_effect(acting, acting, plain, null, false)
	ok(stored_turns(acting) == 2, "the condition's 3 becomes 2 on the acting combatant", "%d" % stored_turns(acting))
	acting.status_effects.clear()
	combat.apply_effect(acting, acting, punishing, null, false)
	ok(stored_turns(acting) == 7, "and an overridden 8 becomes 7", "%d" % stored_turns(acting))
	log_line("")

	log_line("======== the tooltip says what the skill actually lands ========")
	var ui = game.get_node("CanvasLayer/UI")
	ok(ui.describe_effect(plain).contains("3 turn"), "no override reads as the condition's own",
		ui.describe_effect(plain))
	ok(ui.describe_effect(brief).contains("1 turn"), "an override reads as the override",
		ui.describe_effect(brief))
	log_line("")

	log_line("======== the inspector offers it for conditions only ========")
	var shown = []
	var effect_for_list := EffectDefinition.new()
	effect_for_list.type = EffectDefinition.EffectType.CONDITION
	for property in effect_for_list.get_property_list():
		if property.usage & PROPERTY_USAGE_EDITOR:
			shown.append(property.name)
	ok("condition_duration" in shown, "shown for a CONDITION effect")
	effect_for_list.type = EffectDefinition.EffectType.DAMAGE
	shown = []
	for property in effect_for_list.get_property_list():
		if property.usage & PROPERTY_USAGE_EDITOR:
			shown.append(property.name)
	ok(not ("condition_duration" in shown), "and hidden for a DAMAGE one")
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
