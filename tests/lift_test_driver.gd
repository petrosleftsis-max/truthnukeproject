extends Node
## Lifting what is on somebody: cured of what held them in place (Crystallised)
## in their own turn, they can walk again - all of it, or what they had not yet
## walked; and a cleanse that lifts only so much (Medicine), or a heal that
## lifts some (Mercy II), lets the player choose which of several comes off
## (Combat "Cleansing: choosing what comes off"). The user's, 2026-10-25.

var LOG_PATH := HarnessLog.path_for("lift")
const WATCHER := "res://data/encounters/encounter_03_watcher.tres"

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
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(200.0, true, false, true).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	var booted = get_tree().current_scene
	if booted != null:
		booted.queue_free()
		await settle()
	await open_fight(18)
	walking_again()
	await choosing()
	await close_fight()
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


func open_fight(level: int):
	Campaign.reset()
	Campaign.set_party(["cyrus", "enfina", "prometheus", "alithia"], level)
	Campaign.current_map = "res://maps/crossroads_explore.tscn"
	Campaign.return_to_position = true
	Campaign.current_encounter = load(WATCHER)
	game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(6)
	combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(2)


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


func give_turn(comb: Dictionary):
	combat.current_combatant = combat.combatants.find(comb)
	combat.controller.set_controlled_combatant(comb)
	combat.controller.player_turn = comb.side == 0
	combat.controller.action_locked = false


func condition(name: String) -> ConditionDefinition:
	return load("res://data/conditions/%s.tres" % name)


func has(comb: Dictionary, name: String) -> bool:
	return combat.conditions_of(comb).any(func(c): return c.resource_path.get_file().get_basename() == name)


func wait_for(check: Callable, seconds: float = 10.0) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		if check.call():
			return true
		await get_tree().process_frame
	return check.call()


## Medicine's cleanse: one thing, the most recent unless chosen.
func medicine_cleanse() -> EffectDefinition:
	var medicine: ItemDefinition = ItemDatabase.items["medicine"]
	return medicine.all_effects().filter(func(effect): return effect != null and effect.type == EffectDefinition.EffectType.DISPEL)[0]


func walking_again():
	log_line("======== cured of Crystallised in her own turn ========")
	var alithia := who("alithia")
	var cyrus := who("cyrus")
	alithia.status_effects.clear()
	cyrus.status_effects.clear()
	give_turn(alithia)
	var full: int = combat.get_effective_stat(alithia, "movement")
	combat.put_condition(alithia, condition("crystallised"), 2, "test")
	# Her turn begins where she stands: nowhere to walk.
	combat.controller.movement = combat.get_effective_stat(alithia, "movement")
	ok(combat.controller.movement == 0, "crystallised as her turn begins: nowhere to walk")
	combat.dispel_status_effects(cyrus, alithia, medicine_cleanse())
	ok(not has(alithia, "crystallised") and combat.controller.movement == full, "cured: all of her movement back",
		"%d of %d" % [combat.controller.movement, full])

	# Crystallised after walking two tiles of it, then cured: the rest of it.
	alithia["walked_this_turn"] = 2
	combat.put_condition(alithia, condition("crystallised"), 2, "test")
	combat.dispel_status_effects(cyrus, alithia, medicine_cleanse())
	ok(combat.controller.movement == full - 2, "  crystallised after walking two, then cured: what she had not walked",
		"%d of %d" % [combat.controller.movement, full])
	alithia.erase("walked_this_turn")

	# Lifted by a heal of her own (Mercy II).
	combat.put_condition(alithia, condition("crystallised"), 2, "test")
	combat.controller.movement = 0
	combat._after_heal(alithia, alithia)
	ok(not has(alithia, "crystallised") and combat.controller.movement == full, "lifted by her own heal (Mercy II): all of it back",
		"%d of %d" % [combat.controller.movement, full])

	# Curing somebody else leaves the one acting as they were.
	combat.put_condition(cyrus, condition("crystallised"), 2, "test")
	combat.controller.movement = 3
	combat.dispel_status_effects(alithia, cyrus, medicine_cleanse())
	ok(not has(cyrus, "crystallised") and combat.controller.movement == 3, "curing Cyrus in her turn leaves her movement alone",
		"%d" % combat.controller.movement)
	log_line("")


## The labels on the prompt's buttons while it is up.
func offered() -> Array:
	var buttons: Node = combat.reaction_prompt.get_node("Panel/VBox/Buttons")
	return buttons.get_children().filter(func(button): return (button is Button and button.visible
		and button.name != "UseButton" and button.name != "SkipButton" and not button.is_queued_for_deletion())).map(func(button): return button.text)


## Runs _choose_lifts, answering the prompt with whichever label starts with
## `answer` - or, if nothing is asked, with nothing.
func choose(attacker: Dictionary, target: Dictionary, skill: SkillDefinition, answer: String) -> Dictionary:
	var result := {"picks": null, "asked": []}
	var run := func():
		result.picks = await combat._choose_lifts(attacker, target, skill)
	run.call()
	await wait_for(func(): return result.picks != null or combat.reaction_prompt._waiting, 5.0)
	if result.picks == null and combat.reaction_prompt._waiting:
		result.asked = offered()
		var at := 0
		for i in result.asked.size():
			if str(result.asked[i]).begins_with(answer):
				at = i
		combat.reaction_prompt._choose(at)
		await wait_for(func(): return result.picks != null, 5.0)
	return result


func choosing():
	log_line("======== choosing what comes off ========")
	var alithia := who("alithia")
	var cyrus := who("cyrus")
	var medicine: ItemDefinition = ItemDatabase.items["medicine"]
	alithia.status_effects.clear()
	give_turn(cyrus)
	combat.put_condition(alithia, condition("burn"), 3, "test")
	combat.put_condition(alithia, condition("poisoned"), 2, "test")
	combat.put_condition(alithia, condition("crystallised"), 1, "test")
	var chosen := await choose(cyrus, alithia, medicine, "Burn")
	ok(chosen.asked.size() == 3 and str(chosen.asked[0]).begins_with("Crystallised"),
		"Medicine on somebody with three: the player is asked which, the most recent first", "%s" % [chosen.asked])
	ok(chosen.asked.has("Burn (3 turns left)"), "  each with how long it has left")
	combat._lift_picks = chosen.picks
	combat.dispel_status_effects(cyrus, alithia, medicine_cleanse())
	combat._lift_picks = []
	ok(not has(alithia, "burn") and has(alithia, "poisoned") and has(alithia, "crystallised"), "  the Burn chosen: the Burn comes off, and only it")

	alithia.status_effects.clear()
	combat.put_condition(alithia, condition("poisoned"), 2, "test")
	chosen = await choose(cyrus, alithia, medicine, "")
	ok(chosen.asked.is_empty() and chosen.picks.is_empty(), "with only one on her: nothing asked")

	# Somebody the player does not command lifts the most recent, unasked.
	var foe: Dictionary = combat.combatants.filter(func(comb): return comb.side == 1 and comb.alive and not comb.has("object"))[0]
	alithia.status_effects.clear()
	combat.put_condition(alithia, condition("burn"), 3, "test")
	combat.put_condition(alithia, condition("poisoned"), 2, "test")
	chosen = await choose(foe, alithia, medicine, "")
	ok(chosen.asked.is_empty() and chosen.picks.is_empty(), "the other side's cleanse asks nobody")
	combat.dispel_status_effects(foe, alithia, medicine_cleanse())
	ok(has(alithia, "burn") and not has(alithia, "poisoned"), "  and lifts the most recent")

	# A heal that lifts one (Mercy II), on somebody with two.
	give_turn(alithia)
	cyrus.status_effects.clear()
	combat.put_condition(cyrus, condition("burn"), 3, "test")
	combat.put_condition(cyrus, condition("poisoned"), 2, "test")
	chosen = await choose(alithia, cyrus, SkillDatabase.skills["heal"], "Burn")
	ok(chosen.asked.size() == 2, "her Heal on Cyrus, burning and poisoned: which one her Mercy lifts", "%s" % [chosen.asked])
	combat._lift_picks = chosen.picks
	combat._after_heal(alithia, cyrus)
	combat._lift_picks = []
	ok(not has(cyrus, "burn") and has(cyrus, "poisoned"), "  the Burn chosen: the Burn comes off")
	log_line("")
