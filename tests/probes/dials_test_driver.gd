extends Node
## What a bottle would tick for if it borrowed the dial of the skill that
## inflicts the same condition.
##
## Matching the dial does not match the tick: a skill's base moves with the
## caster and a bottle's does not, so the same dial lands somewhere else.

var LOG_PATH := HarnessLog.path_for("dials")
var _log: FileAccess

func log_line(t): _log.store_line(t); _log.flush()


func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(120.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_probe()


## Every skill that inflicts `condition`, with the dial it uses.
func inflicters(condition: ConditionDefinition) -> Array:
	var found := []
	for key in SkillDatabase.skills:
		var skill: SkillDefinition = SkillDatabase.skills[key]
		if skill == null or ItemDatabase.is_item(key):
			continue
		for effect in skill.all_effects():
			if effect != null and effect.type == EffectDefinition.EffectType.CONDITION \
					and effect.condition == condition:
				found.append({"skill": skill, "dial": effect.condition_dot_strength()})
	return found


func run_probe():
	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_02_sappers.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	for i in 6:
		await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await get_tree().process_frame

	var party := []
	for comb in combat.combatants:
		if comb.alive and comb.side == 0:
			party.append(comb)
	var mark = {}
	for comb in combat.combatants:
		if comb.alive and comb.side != 0:
			mark = comb
			break
	log_line("  ticks against %s, defence %d, resistances included"
		% [mark.name, combat.stat_of(mark, Stats.Type.DEFENSE)])
	log_line("")

	for key in ItemDatabase.items:
		var item = ItemDatabase.items[key]
		for effect in item.all_effects():
			if effect == null or effect.type != EffectDefinition.EffectType.CONDITION:
				continue
			var condition = effect.condition
			if condition == null or condition.dot_modifier <= 0.0:
				continue
			log_line("======== %s, which inflicts %s ========" % [item.name, condition.display_name])
			log_line("  as it stands: power %d, dial x%.2f, ticks %d   (it used to roll %d-%d)"
				% [item.item_power, effect.condition_dot_strength(),
					tick_of(combat, party[0], mark, item, effect.condition_dot_strength(), condition),
					condition.dot_min, condition.dot_max])
			for other in inflicters(condition):
				var skill: SkillDefinition = other.skill
				# The skill in the hands it suits, which is how it would be cast.
				var best = party[0]
				for comb in party:
					if combat.stat_of(comb, skill.scaling_stat) > combat.stat_of(best, skill.scaling_stat):
						best = comb
				log_line("  %-18s x%.2f  ticks %-3d in %s's hands, and would make this bottle tick %d"
					% [skill.name, other.dial,
						tick_of(combat, best, mark, skill, other.dial, condition), best.name,
						tick_of(combat, party[0], mark, item, other.dial, condition)])
			log_line("")

	game.queue_free()
	await get_tree().process_frame
	log_line("FAILURES: 0")
	get_tree().quit(0)


func tick_of(combat, caster, mark, skill, dial: float, condition) -> int:
	var base = combat.dot_base_damage(caster, skill, dial)
	return combat.resisted_damage(mark, condition.dot_type,
		combat.dot_tick(mark, base, condition.dot_min, condition.dot_max))
