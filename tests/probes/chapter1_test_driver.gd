extends Node
## Probe: the verified current-value inventory for Chapter I (levels 1-18) and
## the level-64 regression fight, read from the repository and worked out with
## the game's own arithmetic - not from any snapshot. Every value names where it
## comes from. Statuses: ImplementationState (PRESENT / ABSENT / VERIFY) and
## DecisionStatus (EXISTING_BASELINE / APPROVED_TRIAL / PROPOSAL / OPEN /
## APPROVED_DESIGN); blank means unknown, never zero.
## Writes chapter1_inventory.csv beside the test logs (tests/run.sh chapter1).

const PARTY_LEVELS := [1, 4, 8, 11, 14, 16, 18, 64]
const LAST_LEVEL := 18
const PARTY := ["enfina", "cyrus", "prometheus", "alithia"]
## The four Cyrus skills of the approved trial (handoff 0.1).
const TRIAL := {"poison_dart": "APPROVED_TRIAL", "burning_shot": "APPROVED_TRIAL", "venom_fan": "APPROVED_TRIAL"}
const SIXTY_FOUR := "res://data/encounters/level_64_showdown.tres"

var combat = null
var game: Node = null
var rows: PackedStringArray = []


func _ready():
	get_tree().create_timer(600.0, true, false, true).timeout.connect(func(): get_tree().quit(2))
	await get_tree().process_frame
	var booted = get_tree().current_scene
	if booted != null:
		booted.queue_free()
		await settle()
	Campaign.reset()
	Campaign.current_encounter = load("res://data/encounters/encounter_01_ambush.tres")
	game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(6)
	combat = game.get_node("VisualCombat")
	rows.append("Section,Subject,Level,Variable,CurrentValue,ImplementationState,DecisionStatus,Source,Dependencies,Notes")
	party()
	enemies()
	condition_sources()
	fights()
	bosses()
	lethality()
	var path: String = HarnessLog.path_for("chapter1").get_base_dir().path_join("chapter1_inventory.csv")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\n".join(rows) + "\n")
	file.close()
	var report := FileAccess.open(HarnessLog.path_for("chapter1"), FileAccess.WRITE)
	report.store_line("wrote %d rows to %s" % [rows.size() - 1, path])
	report.store_line("FAILURES: 0")
	report.close()
	get_tree().quit(0)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


func cell(value) -> String:
	var text := str(value)
	if text.contains(",") or text.contains("\"") or text.contains("\n"):
		return "\"%s\"" % text.replace("\"", "\"\"").replace("\n", " ")
	return text


func row(section: String, subject: String, level, variable: String, current, decision: String, source: String,
		dependencies: String = "", notes: String = "", state: String = "PRESENT"):
	rows.append(",".join([cell(section), cell(subject), cell(level), cell(variable), cell(current), cell(state),
		cell(decision), cell(source), cell(dependencies), cell(notes)]))


func definition(key: String) -> CombatantDefinition:
	return CombatantDatabase.combatants[key]


func file_of(key: String) -> String:
	return definition(key).resource_path.trim_prefix("res://")


func skill_file(skill: SkillDefinition) -> String:
	return skill.resource_path.trim_prefix("res://") if skill.resource_path != "" else "(made in the game)"


## Somebody as a fight would make them, on nobody's path unless given one.
func made(key: String, level: int, weapon_base: int = Stats.WEAPON_BASE, path: String = "") -> Dictionary:
	var spawn := SpawnDefinition.new()
	spawn.combatant_key = key
	spawn.level = level
	spawn.weapon_base = weapon_base
	spawn.subclass = path
	var comb: Dictionary = combat.create_combatant(definition(key), key, "", spawn)
	comb["side"] = 0 if key in PARTY else 1
	comb["alive"] = true
	return comb


func gates_text(gates: Array) -> String:
	var parts := []
	for i in range(1, gates.size()):
		if gates[i] > 0:
			parts.append("%s %d" % [Stats.gate_name(i).replace("Gates of ", ""), gates[i]])
	return " / ".join(parts) if not parts.is_empty() else "none"


func resistances_text(comb: Dictionary) -> String:
	var parts := []
	for type in comb.get("resistances", {}):
		if int(comb.resistances[type]) != 0:
			parts.append("%s %+d" % [Damage.type_name(type), comb.resistances[type]])
	return ", ".join(parts) if not parts.is_empty() else "none"


## Effective movement: the definition's, with every passive active at that level.
func movement_text(comb: Dictionary) -> String:
	var plain: int = combat.get_effective_stat(comb, "movement")
	var in_cover := 0
	for passive in combat.active_passives(comb):
		in_cover += passive.movement_in_cover
	return "%d%s" % [plain, (" (%d on a turn started in cover)" % (plain + in_cover)) if in_cover > 0 else ""]


func party():
	for key in PARTY:
		var who := definition(key)
		var source := file_of(key)
		for level in PARTY_LEVELS:
			var comb := made(key, level)
			var section := "Party" if level <= LAST_LEVEL else "Party (level-64 regression)"
			row(section, who.name, level, "HP", who.hp_at(level), "EXISTING_BASELINE", source + ": max_hp / max_hp_level_20 (linear)",
				"", "player_hp_defense_progression.csv repeats it")
			row(section, who.name, level, "Defense (no armour worn)", who.defense_at(level), "APPROVED_TRIAL", source + ": defense_by_level",
				"armour worn in the story replaces it", "from player_hp_defense_progression.csv (applied 2026-10-24)")
			row(section, who.name, level, "Initiative", who.initiative, "EXISTING_BASELINE", source + ": initiative")
			row(section, who.name, level, "Movement", movement_text(comb), "EXISTING_BASELINE", source + ": movement + passives (movement_bonus, movement_in_cover)",
				"passives by level")
			row(section, who.name, level, "Resistances", resistances_text(comb), "EXISTING_BASELINE", source + ": resist_*")
			row(section, who.name, level, "Main / secondary stat", "%s %d / %s %d" % [Stats.stat_name(who.main_stat), comb.stats[Stats.stat_key(who.main_stat)],
				Stats.stat_name(who.secondary_stat), comb.stats[Stats.stat_key(who.secondary_stat)]], "EXISTING_BASELINE", "combat/Stats.gd: main_stat_at / secondary_stat_at")
			if who.casts_spells():
				row(section, who.name, level, "Gates", gates_text(who.gates_at(level)), "EXISTING_BASELINE", "combat/Stats.gd: GATE_STEPS")
			var known := []
			var spells := []
			for skill_key in comb.skill_list:
				var skill: SkillDefinition = SkillDatabase.skills.get(skill_key)
				if skill == null or not combat.meets_level_for(comb, skill):
					continue
				if Combat.is_spell(skill):
					spells.append(skill.name)
				else:
					known.append("%s x%s" % [skill.name, snappedf(Combat.modifier_of(comb, skill), 0.01)] if skill.deals_damage else skill.name)
			row(section, who.name, level, "Skills (not spells)", "; ".join(known), "EXISTING_BASELINE", source + ": skills, required_level, ranks")
			if not spells.is_empty():
				var story := spells
				if who.learns_spells:
					story = spells.filter(func(name): return who.starting_spells.any(func(k): return SkillDatabase.skills.has(k) and SkillDatabase.skills[k].name == name))
				row(section, who.name, level, "Spells - Arena Mode", "; ".join(spells), "EXISTING_BASELINE", source + ": skills (Arena knows everything)")
				row(section, who.name, level, "Spells - story, before any book", "; ".join(story), "EXISTING_BASELINE",
					source + (": starting_spells; the rest from spellbooks" if who.learns_spells else ": grows into them by level"),
					"spellbooks found or bought" if who.learns_spells else "")
			var passives := []
			for passive in combat.active_passives(comb):
				passives.append(passive.name)
			row(section, who.name, level, "Passives active", "; ".join(passives), "EXISTING_BASELINE", source + ": passives, required_level")


## Every enemy of the chapter's fights, at each level it is fought at there.
func enemies():
	var seen := {}
	for fight in chapter_fights():
		for spawn in fight.spawns:
			if spawn.side != 1 or not CombatantDatabase.combatants.has(spawn.combatant_key) or definition(spawn.combatant_key) is BattleObjectDefinition:
				continue
			var id: String = "%s@%d@%d" % [spawn.combatant_key, spawn.level, spawn.weapon_base]
			if seen.has(id):
				continue
			seen[id] = true
			var who := definition(spawn.combatant_key)
			var comb: Dictionary = combat.create_combatant(who, spawn.combatant_key, "", spawn)
			comb["alive"] = true
			comb["side"] = 1
			var source := file_of(spawn.combatant_key)
			var subject: String = "%s (weapon base %d)" % [who.name, spawn.weapon_base]
			var decision := "EXISTING_BASELINE"
			row("Enemies", subject, spawn.level, "HP", comb.max_hp, decision, source + ": max_hp / max_hp_level_20", "", "curve set from enemy_progression.csv")
			row("Enemies", subject, spawn.level, "Defense", combat.stat_of(comb, Stats.Type.DEFENSE),
				decision, (fight.resource_path.trim_prefix("res://") + ": spawn defense") if spawn.defense > 0 else (source + ": defense / defense_level_64"))
			row("Enemies", subject, spawn.level, "Initiative / movement", "%d / %s" % [who.initiative, movement_text(comb)], decision, source + ": initiative, movement")
			row("Enemies", subject, spawn.level, "Resistances", resistances_text(comb), decision, source + ": resist_*")
			for skill_key in comb.skill_list:
				var skill: SkillDefinition = SkillDatabase.skills.get(skill_key)
				if skill == null or not combat.meets_level_for(comb, skill) or not skill.deals_damage:
					continue
				var shape := "single target"
				if skill.aoe_radius > 0:
					shape = "%s %d" % [["diamond", "line", "cone", "square"][skill.aoe_shape], skill.aoe_radius]
				var conditions := []
				for effect in skill.effects:
					if effect != null and effect.type == EffectDefinition.EffectType.CONDITION and effect.condition != null:
						var turns: int = effect.condition_duration if effect.condition_duration > 0 else effect.condition.duration
						conditions.append("%s %d turns%s" % [effect.condition.display_name, turns,
							(" dial %s" % effect.condition_dot_modifier) if effect.condition_dot_modifier > 0.0 else ""])
				var aim: String = ("contest %s vs %s" % [Stats.stat_name(combat.scaling_stat_of(comb, skill)), Stats.stat_name(skill.contest_stat)]) \
					if skill.uses_stat_contest else ("accuracy %d" % combat.hit_chance(comb, skill))
				row("Enemy attacks", subject, spawn.level, skill.name,
					"x%s %s, scales with %s; %s; %s%s%s" % [snappedf(Combat.modifier_of(comb, skill), 0.01), Damage.type_name(skill.damage_type),
						Stats.stat_name(combat.scaling_stat_of(comb, skill)), aim, shape,
						"; hits its own side too" if skill.affects_both_sides else "",
						("; " + ", ".join(conditions)) if not conditions.is_empty() else ""],
					decision, skill_file(skill) + (" (shared with the party)" if PARTY.any(func(k): return definition(k).skills.has(skill_key)) else ""),
					"weapon base %d" % spawn.weapon_base, ("level from %s: skill_levels" % source) if who.skill_levels.has(skill_key) else "")


## Each skill that puts a condition on, with the condition's own defaults and
## what the skill overrides.
func condition_sources():
	for skill_key in SkillDatabase.skills:
		var skill: SkillDefinition = SkillDatabase.skills[skill_key]
		if skill == null or skill is ItemDefinition:
			continue
		for effect in skill.effects:
			if effect == null or effect.type != EffectDefinition.EffectType.CONDITION or effect.condition == null:
				continue
			var condition: ConditionDefinition = effect.condition
			var duration: String = "%d (own %d)" % [effect.condition_duration, condition.duration] if effect.condition_duration > 0 else "%d (its own)" % condition.duration
			var dial: String = ""
			if effect.condition_dot_modifier > 0.0 or condition.dot_modifier > 0.0:
				dial = "dial %s" % (("%s (own %s)" % [effect.condition_dot_modifier, condition.dot_modifier]) if effect.condition_dot_modifier > 0.0 else ("%s (its own)" % condition.dot_modifier))
			var ranks := []
			for rank in skill.ranks:
				if rank.condition_duration > 0 or rank.condition_dot_modifier > 0.0:
					ranks.append("from %d: %s turns, dial %s" % [rank.level, rank.condition_duration, rank.condition_dot_modifier])
			row("Conditions by source", "%s -> %s" % [skill.name, condition.display_name], "", "Turns; damage dial",
				"%s%s%s" % [duration, ("; " + dial) if dial != "" else "", ("; ranks: " + "; ".join(ranks)) if not ranks.is_empty() else ""],
				TRIAL.get(skill_key, "EXISTING_BASELINE"), "%s + %s" % [skill_file(skill), condition.resource_path.trim_prefix("res://")],
				"wears off %s; a second one replaces the first (refreshes, never stacks)" % ("as a turn starts" if condition.wears_off_at_start else "as its last turn ends"),
				"N turns = N of the target's turns; on whoever is acting, the rest of that turn too")


func chapter_fights() -> Array:
	var found := []
	for path in ["res://data/encounters", "res://data/encounters/dungeon_demo", "res://data/encounters/lab"]:
		var dir := DirAccess.open(path)
		if dir == null:
			continue
		for file in dir.get_files():
			var f := file.replace(".remap", "")
			if not f.ends_with(".tres"):
				continue
			var fight: EncounterDefinition = load(path.path_join(f))
			var level := 0
			for spawn in fight.spawns:
				if spawn.side == 0:
					level = maxi(level, spawn.level)
			if level >= 1 and level <= LAST_LEVEL:
				found.append(fight)
	return found


func best_hit(attacker: Dictionary, target: Dictionary) -> Array:
	var best := [0, "-", 0]
	for key in attacker.get("skill_list", []):
		var skill: SkillDefinition = SkillDatabase.skills.get(key)
		if skill == null or not skill.deals_damage or skill.targets_ally or not combat.meets_level_for(attacker, skill):
			continue
		var slots: Array = attacker.get("max_spell_slots", [])
		if skill.spell_slot_level > 0 and (slots.size() <= skill.spell_slot_level or slots[skill.spell_slot_level] <= 0):
			continue
		var hit: Dictionary = combat.predict_hit(attacker, target, skill)
		if int(hit.damage) > int(best[0]):
			best = [int(hit.damage), skill.name, int(hit.hit_chance)]
	return best


func blows(damage: int, hp: int) -> String:
	return "never" if damage <= 0 else str(int(ceil(float(hp) / float(damage))))


func fights():
	var all := chapter_fights()
	all.append(load(SIXTY_FOUR))
	for fight in all:
		var party := []
		var foes := []
		var level := 0
		for spawn in fight.spawns:
			if not CombatantDatabase.combatants.has(spawn.combatant_key):
				continue
			var comb: Dictionary = combat.create_combatant(definition(spawn.combatant_key), spawn.combatant_key, spawn.display_name, spawn)
			comb["alive"] = true
			comb["side"] = spawn.side
			if spawn.side == 0:
				party.append(comb)
				level = maxi(level, spawn.level)
			elif not definition(spawn.combatant_key) is BattleObjectDefinition:
				foes.append(comb)
		var name: String = fight.display_name
		var source: String = fight.resource_path.trim_prefix("res://")
		var section := "Fights" if level <= LAST_LEVEL else "Fights (level-64 regression)"
		row(section, name, level, "Enemies", "%d: %s" % [foes.size(), ", ".join(foes.map(func(c): return "%s L%d" % [c.name, c.level]))], "EXISTING_BASELINE", source + ": spawns")
		row(section, name, level, "Party tiles", "%d: %s" % [party.size(), ", ".join(party.map(func(c): return c.name))], "EXISTING_BASELINE", source + ": spawns (side 0)",
			"in the story the roster fills them; Arena Mode seeds the roster from them")
		row(section, name, level, "Gold reward", fight.gold_reward, "APPROVED_TRIAL" if fight.gold_reward > 0 else "EXISTING_BASELINE", source + ": gold_reward",
			"paid in the story or a dungeon, not Arena Mode", "from gold_economy_gear.csv (applied 2026-10-23)" if fight.gold_reward > 0 else "")
		var quickest := 999
		for foe in foes:
			for friend in party:
				var blow := best_hit(foe, friend)
				var count := blows(int(blow[0]), int(friend.max_hp))
				row(section, name, level, "%s's best blow on %s" % [foe.name, friend.name], "%d (%s, %d%% to hit) - downs in %s" % [blow[0], blow[1], blow[2], count],
					"EXISTING_BASELINE", "worked out with Combat.predict_hit", "%s: %d HP, %d Def" % [friend.name, friend.max_hp, combat.stat_of(friend, Stats.Type.DEFENSE)],
					"ignores reach, cover and passives that act in play (Illusory Guardian)")
				if count != "never":
					quickest = mini(quickest, int(count))
		for friend in party:
			for foe in foes:
				var blow := best_hit(friend, foe)
				row(section, name, level, "%s's best blow on %s" % [friend.name, foe.name], "%d (%s, %d%% to hit) - downs in %s" % [blow[0], blow[1], blow[2], blows(int(blow[0]), int(foe.max_hp))],
					"EXISTING_BASELINE", "worked out with Combat.predict_hit", "%s: %d HP, %d Def" % [foe.name, foe.max_hp, combat.stat_of(foe, Stats.Type.DEFENSE)],
					"weapon base %d (the tile's); Arena knows every spell" % friend.weapon_base)
		row(section, name, level, "Fewest enemy blows to down one of the party", quickest if quickest < 999 else "never", "OPEN", "derived", "", "no target agreed yet")


func bosses():
	for path in ["res://data/encounters/boss_ash_warden.tres", "res://data/encounters/boss_bellkeeper.tres", "res://data/encounters/boss_glutton.tres"]:
		var fight: EncounterDefinition = load(path)
		for spawn in fight.spawns:
			var who: CombatantDefinition = CombatantDatabase.combatants.get(spawn.combatant_key)
			if who == null or who.boss == null:
				continue
			var subject: String = "%s (%s)" % [who.name, fight.display_name]
			var source := file_of(spawn.combatant_key)
			row("Bosses", subject, spawn.level, "HP", who.hp_at(spawn.level), "EXISTING_BASELINE", source + ": max_hp / max_hp_level_20")
			row("Bosses", subject, spawn.level, "Defense", spawn.defense if spawn.defense > 0 else who.defense_at(spawn.level), "EXISTING_BASELINE",
				(path.trim_prefix("res://") + ": spawn defense") if spawn.defense > 0 else source)
			row("Bosses", subject, spawn.level, "Turns per round", who.turns_per_round, "EXISTING_BASELINE", source + ": turns_per_round")
			var immune := []
			for condition in who.immune_to_conditions:
				if condition != null:
					immune.append(condition.display_name)
			for kind in who.immune_to:
				immune.append(Immunity.name_of(kind))
			row("Bosses", subject, spawn.level, "Control resistance (immunities)", "; ".join(immune) if not immune.is_empty() else "none",
				"EXISTING_BASELINE", source + ": immune_to_conditions, immune_to")
			for phase in who.boss.phases:
				var changes := []
				for condition in phase.immunities_lost:
					if condition != null:
						changes.append("loses immunity to %s" % condition.display_name)
				for condition in phase.immunities_gained:
					if condition != null:
						changes.append("gains immunity to %s" % condition.display_name)
				if phase.clears_conditions:
					changes.append("clears what is on it")
				if phase.turns_per_round > 0:
					changes.append("%d turns a round" % phase.turns_per_round)
				if not phase.summons.is_empty():
					changes.append("summons %s" % ", ".join(phase.summons))
				if phase.stagger != null:
					changes.append("new stagger bar")
				row("Bosses", subject, spawn.level, "Phase: %s" % phase.name, "at %d%% health%s" % [roundi(phase.at_health * 100.0),
					("; " + "; ".join(changes)) if not changes.is_empty() else ""], "EXISTING_BASELINE", source + ": boss.phases")
			if who.boss.stagger != null:
				row("Bosses", subject, spawn.level, "Stagger bar", "; ".join(_stagger_text(who.boss.stagger)), "EXISTING_BASELINE", source + ": boss.stagger")


## The designer's lethality rule (2026-10-24): a telegraphed attack ignored may
## down Prometheus; Cyrus and Alithia should survive ordinary telegraphed attacks
## unless especially powerful; Enfina most, but not major boss attacks. Fair
## lethality is telegraphed, avoidable, interruptible or protectable; unfair is
## an unclear warning, no viable response, or damage out of proportion to the
## counterplay. For every attack that is telegraphed, or that can down one of the
## party in one blow, what it is and how it reads against that rule - for the
## designer to judge, not a verdict.
## What the designer has already ruled on, by skill key.
const RULINGS := {
	"self_destruct": "KEPT by the designer (2026-10-24): not telegraphed, but it teaches the player to read enemy moves",
}


func lethality():
	var all := chapter_fights()
	all.append(load(SIXTY_FOUR))
	for fight in all:
		var party := []
		var foes := []
		for spawn in fight.spawns:
			if not CombatantDatabase.combatants.has(spawn.combatant_key):
				continue
			var comb: Dictionary = combat.create_combatant(definition(spawn.combatant_key), spawn.combatant_key, spawn.display_name, spawn)
			comb["alive"] = true
			comb["side"] = spawn.side
			if spawn.side == 0:
				party.append(comb)
			elif not definition(spawn.combatant_key) is BattleObjectDefinition:
				foes.append(comb)
		var seen := {}
		for foe in foes:
			for skill_key in foe.skill_list:
				var skill: SkillDefinition = SkillDatabase.skills.get(skill_key)
				if skill == null or not skill.deals_damage or skill.targets_ally or not combat.meets_level_for(foe, skill):
					continue
				var id: String = "%s/%s" % [foe.get("combatant_key", ""), skill_key]
				if seen.has(id):
					continue
				seen[id] = true
				var downed := []
				var hits := []
				for friend in party:
					var damage := int(combat.predict_hit(foe, friend, skill).damage)
					hits.append("%s %d/%d" % [friend.name, damage, friend.max_hp])
					if damage >= int(friend.max_hp):
						downed.append(str(friend.name))
				if not skill.declared and downed.is_empty():
					continue
				var warning := "declared: marked on the map, lands at the start of its user's next turn once each of the other side has had a turn" \
					if skill.declared else "NOT telegraphed: lands on its user's turn; only the danger view (Shift) warns"
				var area := "single target" if skill.aoe_radius <= 0 else "%s %d (step %d tiles out of it; the party walks 6)" % [
					["diamond", "line", "cone"][skill.aoe_shape], skill.aoe_radius, skill.aoe_radius + 1]
				var answers := []
				if skill.declared:
					answers.append("walk out of the marked tiles")
				answers.append("Hack" if skill.can_be_hacked() else "no Hack (not hackable)")
				if Combat.is_spell(skill):
					answers.append("InstaHack (a spell)")
				answers.append("interrupt: down it, or take its turn (stun, stagger, Persuade)" if skill.declared else "kill it or keep away first")
				if skill.kills_caster:
					answers.append("its user dies with it")
				var reading := ""
				var against := downed.filter(func(n): return n != "Prometheus")
				if RULINGS.has(skill_key):
					reading = RULINGS[skill_key]
				elif skill.declared and against.is_empty():
					reading = "FAIR by the rule" + (" (it can down Prometheus if ignored, as intended)" if downed.has("Prometheus") else "")
				elif skill.declared:
					reading = "REVIEW: telegraphed, but downs %s in one - against the rule unless it is especially powerful (a major boss attack for Enfina)" % ", ".join(against)
				else:
					reading = "UNFAIR candidate: no telegraph, and it downs %s in one" % ", ".join(downed)
				row("Lethality review", "%s - %s's %s" % [fight.display_name, foe.name, skill.name], foe.level, "One-blow downs",
					", ".join(downed) if not downed.is_empty() else "nobody", "OPEN", skill_file(skill),
					"%s; %s; %s" % [warning, area, "; ".join(answers)], "%s. Damage: %s" % [reading, ", ".join(hits)])


func _stagger_text(stagger: Resource) -> Array:
	var parts := []
	for p in stagger.get_property_list():
		if not (p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or not (p.usage & PROPERTY_USAGE_STORAGE):
			continue
		var value = stagger.get(p.name)
		if value is float or value is int:
			if float(value) != 0.0:
				parts.append("%s %s" % [p.name, snappedf(float(value), 0.01)])
		elif value is String and value != "":
			parts.append("%s \"%s\"" % [p.name, value])
		elif value is Array and not value.is_empty():
			parts.append("%s %s" % [p.name, str(value)])
	return parts
