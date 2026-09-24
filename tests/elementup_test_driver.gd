extends Node
## Raising the element of the next spell somebody casts.
##
## Element Up is a secondary action that hands an ally one charge. The next
## damaging spell they cast lands as the upgraded form of its element - fire as
## plasma, water as ice - and the charge is gone. A spell with nothing to raise
## leaves it alone rather than wasting it.

var LOG_PATH := HarnessLog.path_for("elementup")

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
	get_tree().create_timer(180.0, true, false, true).timeout.connect(func():
		log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


func run_test():
	log_line("======== the effect type, and where its number sits ========")
	# A .tres stores the number, so an existing effect silently becomes a
	# different one if anything is ever inserted ahead of it.
	var frozen := {
		"DAMAGE": 0, "HEAL": 1, "STAT_MODIFIER": 2, "DAMAGE_OVER_TIME": 3,
		"DISPEL": 4, "PUSH": 5, "PULL": 6, "STAT_MULTIPLIER": 7,
		"CONDITION": 8, "REVEAL": 9, "MOVEMENT_CLASS": 10, "HIDE": 11,
		"RESISTANCE": 12, "UPGRADE_ELEMENT": 13,
	}
	var moved := []
	for name in frozen:
		if not name in EffectDefinition.EffectType.keys():
			moved.append("%s is gone" % name)
		elif EffectDefinition.EffectType[name] != frozen[name]:
			moved.append("%s is now %d, was %d" % [name,
				EffectDefinition.EffectType[name], frozen[name]])
	ok(moved.is_empty(), "every effect type still means what the resources think it means",
		"%s" % [moved])
	ok(EffectDefinition.EffectType.keys().size() == frozen.size(),
		"and the new one went on the end rather than into the middle",
		"%d types" % EffectDefinition.EffectType.keys().size())
	log_line("")

	log_line("======== Element Up, as written ========")
	var raiser: SkillDefinition = SkillDatabase.skills.get("element_up")
	ok(raiser != null, "the skill is in the database")
	if raiser == null:
		log_line("FAILURES: %d" % (_fail + 1))
		get_tree().quit(1)
		return
	ok(raiser.is_secondary, "it costs the secondary action")
	ok(raiser.targets_ally, "and is cast on a friend")
	ok(not raiser.deals_damage, "without hurting the friend it lands on")
	var carried: EffectDefinition = null
	for effect in raiser.all_effects():
		if effect.type == EffectDefinition.EffectType.UPGRADE_ELEMENT:
			carried = effect
	ok(carried != null, "and it carries the effect its description promises")
	ok(carried != null and carried.duration > 0, "for a while, not for ever",
		"%d turns" % (carried.duration if carried else 0))
	log_line("")

	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_02_sappers.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	for i in 8:
		await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await get_tree().process_frame

	var caster = {}
	var victim = {}
	for comb in combat.combatants:
		if not comb.alive:
			continue
		if comb.side == 0 and caster.is_empty():
			caster = comb
		elif comb.side == 1 and victim.is_empty():
			victim = comb
	ok(not caster.is_empty() and not victim.is_empty(), "somebody to cast and somebody to burn")

	log_line("======== fire goes off as plasma, once ========")
	var fireball: SkillDefinition = SkillDatabase.skills["fireball"]
	ok(fireball.damage_type == Damage.Type.FIRE, "Fireball is written as fire",
		Damage.type_name(fireball.damage_type))
	ok(Damage.upgraded_form(Damage.Type.FIRE) == Damage.Type.PLASMA,
		"and fire raises to plasma")
	combat.apply_effect(caster, caster, carried, raiser, false)
	await get_tree().process_frame
	ok(combat.has_element_upgrade(caster), "the charge is held")

	combat.spend_element_upgrade(caster, fireball)
	ok(caster.get("element_upgraded_cast", false), "casting Fireball spends it")
	ok(not combat.has_element_upgrade(caster), "and it is gone afterwards")
	ok(combat.effective_damage_type(caster, Damage.Type.FIRE) == Damage.Type.PLASMA,
		"so the hit lands as plasma",
		Damage.type_name(combat.effective_damage_type(caster, Damage.Type.FIRE)))
	# The next spell is an ordinary one again.
	combat.spend_element_upgrade(caster, fireball)
	ok(not caster.get("element_upgraded_cast", false), "the spell after it is fire again")
	ok(combat.effective_damage_type(caster, Damage.Type.FIRE) == Damage.Type.FIRE,
		"and lands as fire")
	log_line("")

	log_line("======== a charge is not wasted on a spell with nothing to raise ========")
	# Plasma is already the raised form, and a physical swing was never an
	# element. Spending the charge on either would be throwing it away.
	for key in SkillDatabase.skills:
		var skill: SkillDefinition = SkillDatabase.skills[key]
		var raisable := false
		for type in combat.elements_of(skill):
			if Damage.can_upgrade(type):
				raisable = true
		if raisable:
			continue
		caster.status_effects.clear()
		combat.apply_effect(caster, caster, carried, raiser, false)
		combat.spend_element_upgrade(caster, skill)
		if not combat.has_element_upgrade(caster):
			ok(false, "%s should not have spent it" % skill.name)
			break
	ok(combat.has_element_upgrade(caster),
		"nothing unraisable in the whole database spends one")
	log_line("")

	log_line("======== one cast, however many it catches ========")
	# A blast that hits three people is one spell: everybody it caught should
	# take the raised element, and it should cost the one charge.
	caster.status_effects.clear()
	combat.apply_effect(caster, caster, carried, raiser, false)
	combat.spend_element_upgrade(caster, fireball)
	var raised_for_all := true
	for i in 3:
		if combat.effective_damage_type(caster, Damage.Type.FIRE) != Damage.Type.PLASMA:
			raised_for_all = false
	ok(raised_for_all, "every target of the one cast takes plasma")
	ok(not combat.has_element_upgrade(caster), "and it cost one charge, not three")
	log_line("")

	log_line("======== it really changes what gets resisted ========")
	# The point of the whole thing: somebody who shrugs off fire does not shrug
	# off plasma, because the two are unrelated as far as resistance goes.
	victim.resistances = {}
	# Keyed by the type itself, the way create_combatant builds the table - not
	# by the "resist_fire" name, which is what a timed change to it is stored as.
	victim.resistances[Damage.Type.FIRE] = 80
	var fire_through = combat.resisted_damage(victim, Damage.Type.FIRE, 100)
	var plasma_through = combat.resisted_damage(victim, Damage.Type.PLASMA, 100)
	ok(plasma_through > fire_through,
		"a fire-proof target takes more from the raised form",
		"%d gets through as fire, %d as plasma" % [fire_through, plasma_through])
	log_line("")

	log_line("======== and the panel says what it does ========")
	var ui = game.get_node("CanvasLayer/UI")
	var said = ui.build_skill_tooltip(raiser, caster)
	ok(said.contains("Fire to Plasma"), "the preview names what becomes what", said)
	ok(said.contains("Action: Secondary"), "and that it costs the secondary action")
	log_line("")

	game.queue_free()
	await get_tree().process_frame
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
