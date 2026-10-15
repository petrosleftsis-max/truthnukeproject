class_name CodexPage
## What the enemy codex says about somebody (Campaign "The enemy codex"), page
## by page, worked out from their CombatantDefinition so it never disagrees with
## what they are: the first page for everybody, the second for a boss.


## Whether `definition` has a second page: a boss does.
static func has_second_page(definition: CombatantDefinition) -> bool:
	return definition != null and definition.boss != null


## How many pages `definition` has.
static func pages_of(definition: CombatantDefinition) -> int:
	return 2 if has_second_page(definition) else 1


## The first page: who they are, how they fight, and what can be done to them.
static func first_page(definition: CombatantDefinition) -> String:
	var lines: Array[String] = []
	if definition.glossary_text != "":
		lines.append(definition.glossary_text)
		lines.append("")
	var health := "%d" % definition.max_hp
	if definition.max_hp_level_20 > 0:
		health = "%d at level 1, %d at level 20" % [definition.max_hp, definition.max_hp_level_20]
	lines.append("%s. Health %s. Movement %d, initiative %d." % [Sizes.name_of(definition.size), health, definition.movement, definition.initiative])
	lines.append("Built around %s, then %s." % [Stats.stat_name(definition.main_stat), Stats.stat_name(definition.secondary_stat)])
	var resists: Array[String] = []
	var weak: Array[String] = []
	var table := definition.resistance_table()
	for type in table:
		if table[type] > 0:
			resists.append("%s %d%%" % [Damage.type_name(type), table[type]])
		elif table[type] < 0:
			weak.append("%s %d%%" % [Damage.type_name(type), -table[type]])
	if not resists.is_empty():
		lines.append("Resists %s." % ", ".join(resists))
	if not weak.is_empty():
		lines.append("Weak to %s." % ", ".join(weak))
	var immune: Array[String] = []
	for condition in definition.immune_to_conditions:
		if condition != null:
			immune.append(condition.display_name.to_lower())
	for kind in definition.immune_to:
		immune.append(Immunity.name_of(kind))
	if not immune.is_empty():
		lines.append("Immune to %s." % ", ".join(immune))
	var skills: Array[String] = []
	for key in definition.skills:
		var skill: SkillDefinition = SkillDatabase.skills.get(key)
		skills.append(skill.name if skill != null else key.capitalize())
	if not skills.is_empty():
		lines.append("Uses %s." % ", ".join(skills))
	for passive in definition.passives:
		if passive != null:
			lines.append("%s: %s" % [passive.name, passive.description])
	if definition.turns_per_round > 1:
		lines.append("Takes %d turns a round." % definition.turns_per_round)
	if definition.immune_to.has(Immunity.Kind.BREAKING):
		lines.append("Never breaks.")
	else:
		lines.append("Breaks at nerve %d, and then %s." % [definition.nerve, "surrenders" if definition.when_broken == 1 else "runs"])
		if definition.when_broken == 0 and definition.when_fled == 1:
			lines.append("If it gets away, it comes back %d rounds later%s." % [definition.back_after_rounds,
				" - and not alone" if not definition.brings_back.is_empty() else ""])
		elif definition.when_broken == 0 and definition.when_fled == 2:
			lines.append("It must not get away: if it does, the fight is lost.")
	if definition.immune_to.has(Immunity.Kind.TAKEN_ALIVE):
		lines.append("Can never be taken alive.")
	if definition.leads:
		lines.append("Leads their side: when they fall, the rest lose heart.")
	if definition.bribe_price > 0:
		lines.append("Fights for money - %d gold buys them out of a fight." % definition.bribe_price)
	if definition.bound_to != "":
		lines.append("Bound to %s - a binding that can be rewritten." % definition.bound_to)
	var parts: Array[String] = []
	for part in definition.parts:
		if part != null:
			parts.append("%s (broken, it %s)" % [part.name, part.describe_broken()])
	if not parts.is_empty():
		lines.append("Can be broken: %s." % ", ".join(parts))
	return "\n".join(lines)


## The second page, for a boss: its notes, its phases and its stagger bar.
static func second_page(definition: CombatantDefinition) -> String:
	if not has_second_page(definition):
		return ""
	var boss: BossDefinition = definition.boss
	var lines: Array[String] = []
	if boss.title != "":
		lines.append(boss.title)
	if boss.codex_second_page != "":
		lines.append(boss.codex_second_page)
	if lines.size() > 0:
		lines.append("")
	var phases: Array = boss.phases_in_order()
	if phases.is_empty():
		lines.append("It fights the same way to the end.")
	for phase in phases:
		var said := "At %d%% health: %s." % [roundi(phase.at_health * 100.0), phase.name if phase.name != "" else "it changes"]
		var changes: Array[String] = []
		for key in phase.skills_added:
			var skill: SkillDefinition = SkillDatabase.skills.get(key)
			changes.append("takes up %s" % (skill.name if skill != null else key))
		if phase.turns_per_round > 0:
			changes.append("%d turns a round" % phase.turns_per_round)
		if not phase.summons.is_empty():
			changes.append("calls for help")
		if not phase.hazards.is_empty():
			changes.append("the arena turns on you")
		if not changes.is_empty():
			said += " It %s." % ", ".join(changes)
		lines.append(said)
	if boss.stagger != null:
		lines.append("")
		lines.append("Stagger: " + boss.stagger.describe().replace("\n", " "))
	return "\n".join(lines)
