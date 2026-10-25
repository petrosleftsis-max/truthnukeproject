extends Node
## Probe: every heal in the game as it stands, worked out with the game's own
## arithmetic (Combat.predict_hit, heal_amount, heal_share_on) at levels 1, 8,
## 14, 18, 24, 41, 54 and 64; the designer's proposed hybrid heals beside them
## and the proposed level-scaled cap on them (PROPOSAL test values, not
## implemented) - where the cap would trim, on whom, and on the bosses; the
## enemies' blows in the real fights; the proposed short rest; and the gates
## Meditate would bring back; and the designer's revision (mostly flat heals with
## modest Mindfulness and weapon shares) beside the current heals, the blows, the
## enemy healers and the bosses.
## Writes healing_inventory.csv beside the test logs (tests/run.sh healing).

const LEVELS := [1, 8, 14, 18, 24, 41, 54, 64]
## Whoever heals, for the cap: Alithia, the enemy healers, and the Mimic copying
## one of Alithia's heals with its own stats. The Summoner's Mend the Bound has
## no hybrid value of its own yet, so it is modelled as Heal's.
const CAP_HEALERS := {"alithia": ["light_heal", "heal", "communion", "restoration"], "priest": ["heal", "communion"],
	"ranger": ["heal"], "summoner": ["heal"], "mimic": ["light_heal", "heal", "communion", "restoration"]}
## The bosses and giants, whose health the cap is for.
const BIG := ["ash_warden", "bellkeeper", "glutton", "behemoth", "colossus"]
## The party's own summons, which are not enemies.
const NOT_ENEMIES := ["kindled_hound", "illusory_dragon"]
const GATE_LEVELS := [1, 8, 14, 18, 24, 33, 45, 55, 64]
const PARTY := ["enfina", "cyrus", "prometheus", "alithia"]
## A weapon Alithia could carry (the Votive Mace): a heal's power has the weapon in it.
const MACE_BASE := 10
const ALITHIA_SPELLS := ["light_heal", "heal", "communion", "purification", "restoration", "grace"]
const ITEMS := ["cure_potion", "mediocre_cure_potion", "potent_cure_potion", "medicine", "heal_gate_nade", "communion_gate_nade"]
## Enemy heals, and whom they would mend: an average and a tanky enemy.
const ENEMY_HEALS := {"priest": ["heal", "communion"], "ranger": ["heal"], "summoner": ["mend_the_bound"]}
const ENEMY_PATIENTS := ["sellsword", "ogre"]
## The designer's hybrid (2026-10-24), PROPOSAL test values: a share of the
## missing health (or of the most, for Restoration), plus a share of Mindfulness.
const HYBRID := {
	"light_heal": {"missing": 0.10, "mind": 0.3},
	"heal": {"missing": 0.20, "mind": 0.5},
	"communion": {"missing": 0.10, "mind": 0.3},
	"restoration": {"of_most": 0.50, "mind": 0.5},
	"grace": {"full": true},
}
## How hurt the patient is in the comparison: half their health gone, or nine tenths.
const SCENARIOS := {"half down": 0.5, "nearly down": 0.9}
## The real fights at each level (the party made at that level against them).
const FIGHTS := {
	1: ["res://data/encounters/encounter_01_ambush.tres"],
	8: ["res://data/encounters/encounter_02_sappers.tres", "res://data/encounters/encounter_hired_blades.tres"],
	14: ["res://data/encounters/encounter_03_watcher.tres", "res://data/encounters/dungeon_demo/dungeon_1_sewer.tres",
		"res://data/encounters/dungeon_demo/dungeon_2_lab.tres", "res://data/encounters/dungeon_demo/dungeon_3_city.tres"],
	18: ["res://data/encounters/lab/lab_a_city.tres", "res://data/encounters/lab/lab_b_hired_blades.tres",
		"res://data/encounters/lab/lab_c_erysichthon.tres"],
	64: ["res://data/encounters/level_64_showdown.tres"],
}
## The short rest's share of the missing health (PROPOSAL, first test).
const SHORT_REST := 0.5

var combat = null
var game: Node = null
var rows: PackedStringArray = []
## The enemies' blows by "level/name": [typical, hardest], for the revised heals.
var blows := {}

## The designer's revision (2026-10-24), PROPOSAL test values, superseding HYBRID
## for ordinary heals: mostly flat, a modest share of Mindfulness, and the weapon
## in it; Restoration a share of the most; Grace full.
const REVISED := {
	"light_heal": {"flat": 8.0, "mind": 0.15, "weapon": 0.2},
	"heal": {"flat": 12.0, "mind": 0.25, "weapon": 0.3},
	"communion": {"flat": 8.0, "mind": 0.15, "weapon": 0.2},
	"restoration": {"of_most": 0.5, "mind": 0.25},
	"grace": {"full": true},
}
## Weapon bases to show: none worn (6), a mace or a staff (10), the arena's best tile (12).
const WEAPONS := [6, 10, 12]
## Patients for the enemy healers: small, average, tanky and the largest.
const REVISED_PATIENTS := ["gnawer", "sellsword", "ogre", "pit_champion"]


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
	rows.append("Section,Subject,Level,Variable,Value,ImplementationState,DecisionStatus,Source,Notes")
	formulas()
	current_heals()
	enemy_heals()
	proposed_heals()
	enemy_blows()
	short_rests()
	gates()
	max_health()
	cap_triggers()
	boss_heals()
	cap_by_level()
	revised_party()
	revised_against_blows()
	revised_enemies()
	revised_caps()
	var path: String = HarnessLog.path_for("healing").get_base_dir().path_join("healing_inventory.csv")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\n".join(rows) + "\n")
	file.close()
	var report := FileAccess.open(HarnessLog.path_for("healing"), FileAccess.WRITE)
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


func row(section: String, subject: String, level, variable: String, value, decision: String, source: String,
		notes: String = "", state: String = "PRESENT"):
	rows.append(",".join([cell(section), cell(subject), cell(level), cell(variable), cell(value), cell(state),
		cell(decision), cell(source), cell(notes)]))


func definition(key: String) -> CombatantDefinition:
	return CombatantDatabase.combatants[key]


func file_of(resource: Resource) -> String:
	return resource.resource_path.trim_prefix("res://") if resource.resource_path != "" else "(made in the game)"


func made(key: String, level: int, weapon_base: int = Stats.WEAPON_BASE) -> Dictionary:
	var spawn := SpawnDefinition.new()
	spawn.combatant_key = key
	spawn.level = level
	spawn.weapon_base = weapon_base
	var comb: Dictionary = combat.create_combatant(definition(key), key, "", spawn)
	comb["side"] = 0 if key in PARTY else 1
	comb["alive"] = true
	return comb


func mind_of(comb: Dictionary) -> int:
	return int(combat.stat_of(comb, Stats.Type.MINDFULNESS))


func most_of(comb: Dictionary) -> int:
	return int(combat.get_effective_stat(comb, "max_hp"))


func heal_effects(skill: SkillDefinition) -> Array:
	return skill.all_effects().filter(func(effect): return effect != null and effect.type == EffectDefinition.EffectType.HEAL)


## The rule Combat.heal_amount and heal_share_on follow, in words.
func formula_of(skill: SkillDefinition) -> String:
	var parts := []
	for effect in heal_effects(skill):
		var dial: float = effect.heal_modifier if effect.heal_modifier > 0.0 else skill.ability_modifier
		var power := "item power %d (flat)" % int(skill.get("item_power")) if skill is ItemDefinition else \
			"(weapon base + 0.7 x the caster's %s)" % ("spellcasting stat" if Combat.is_spell(skill) else Stats.stat_name(skill.scaling_stat))
		var text := "round(%s x %s x (1 + the healer's heal bonus))" % [power, snappedf(dial, 0.01)]
		if effect.heals_flat() and not skill is ItemDefinition:
			text = "round((%s + %s x the healer's healing stat + %s x weapon base) x (1 + the healer's heal bonus))" % [
				snappedf(effect.heal_flat, 0.01), snappedf(effect.heal_per_stat, 0.01), snappedf(effect.heal_per_weapon, 0.01)]
		if effect.heal_share_of_health > 0.0:
			text += " + round(%d%% of the target's max health)" % roundi(effect.heal_share_of_health * 100)
		# Light Swing (the handoff of 2026-10-25): a share of her own health and
		# nothing else, ranked, twice once a foe at half health.
		if effect.heals_share_only:
			var shares := ["%d%%" % roundi(effect.heal_share_of_health * 100)]
			for rank in skill.ranks:
				if rank != null and rank.heal_share_of_health > 0.0:
					shares.append("%d%% from %d" % [roundi(rank.heal_share_of_health * 100), rank.level])
			text = "round(%s of the user's max health)" % ", ".join(shares)
			if effect.share_doubled_on_wounded:
				text += ", twice the first time each foe it strikes is at half health or less"
		if effect.applies_to_caster:
			text += ", on its user"
		parts.append(text)
	return "; ".join(parts)


## The flat rule is an APPROVED_TRIAL (2026-10-24); everything else stands as it was.
func status_of(skill: SkillDefinition) -> String:
	for effect in heal_effects(skill):
		if (effect.heals_flat() or effect.heals_share_only) and not skill is ItemDefinition:
			return "APPROVED_TRIAL"
	return "EXISTING_BASELINE"


## Why the effect's own numbers do nothing, when it has any.
func unused_of(skill: SkillDefinition) -> String:
	var unused := []
	for effect in heal_effects(skill):
		if effect.min_amount != 0 or effect.max_amount != 0:
			unused.append("its effect's %d-%d is unused (only a heal with no skill behind it reads it)" % [effect.min_amount, effect.max_amount])
		if effect.damage_modifier != 1.0 and effect.damage_modifier != 0.0:
			unused.append("its effect's damage_modifier %s does nothing to a heal" % snappedf(effect.damage_modifier, 0.01))
	return "; ".join(unused)


func availability(comb: Dictionary, skill: SkillDefinition) -> String:
	if not combat.meets_level_for(comb, skill):
		return "not yet: learned at %d" % skill.required_level
	var gate := skill.spell_slot_level
	if gate > 0:
		var gates: Array = comb.get("max_spell_slots", [])
		if gate >= gates.size() or int(gates[gate]) <= 0:
			return "not yet: %s not open" % Stats.gate_name(gate)
		return "%s, %d a rest" % [Stats.gate_name(gate).replace("Gates of ", ""), int(gates[gate])]
	return "no gate"


func formulas():
	for key in ALITHIA_SPELLS + ["light_swing", "revitalizer", "mend_the_bound"]:
		var skill: SkillDefinition = SkillDatabase.skills.get(key)
		if skill == null:
			continue
		var stat := "Mindfulness (Alithia's spellcasting stat)" if Combat.is_spell(skill) else Stats.stat_name(skill.scaling_stat)
		if key == "mend_the_bound":
			stat = "Mindfulness (the Summoner's %s)" % Stats.stat_name(skill.scaling_stat)
		var notes := unused_of(skill)
		if key == "revitalizer":
			notes = "UNUSED (data/skills/unused): replaced by Communion (designer, 2026-10-24). " + notes
		row("Formula", skill.name, "", "Heal", formula_of(skill), status_of(skill), file_of(skill),
			"scales from %s; level %d; %s%s" % [stat, skill.required_level,
			("gate %s" % Stats.gate_name(skill.spell_slot_level)) if skill.spell_slot_level > 0 else "no gate",
			("; " + notes) if notes != "" else ""])
	for key in ITEMS:
		var item: ItemDefinition = ItemDatabase.items.get(key)
		if item == null:
			continue
		var notes := unused_of(item)
		if item is GateNadeDefinition:
			notes = "a Gate Nade copies %s's dial; its power is its own, flat. " % str(item.get("spell")) + notes
		row("Formula", item.name, "", "Heal", formula_of(item), "EXISTING_BASELINE", file_of(item),
			"scales from nothing (flat item power or a share of the target's health); price %d; %s" % [item.price, notes])
	row("Formula", "Revitalizer Gate Nade", "", "Heal", "-", "", "-", "Replaced by the Communion Gate Nade (designer, 2026-10-24)", "ABSENT")
	row("Formula", "Mercy I (Alithia)", "", "Heal bonus", "+10% on every heal of hers (heal_bonus 0.1, from level 1)", "EXISTING_BASELINE",
		"data/passives/mercy.tres", "multiplies the heal before the share of health is added")
	row("Formula", "Mercy II / III (Alithia)", "", "With every heal", "II (16): lifts one harmful condition; III (41): Sheltered, a fifth less damage until their turn",
		"EXISTING_BASELINE", "data/passives/mercy_ii.tres; mercy_iii.tres", "")
	row("Formula", "Aura II (Alithia) - Soothed", "", "Mends at turn start", "5% of max health a turn (Soothed, mends_share 0.05)", "EXISTING_BASELINE",
		"data/passives/aura_ii.tres; data/conditions/soothed.tres", "allies near her; a share of health, so it scales already")
	row("Formula", "Elemental Tactician (Prometheus, 24+)", "", "Overheal", "0.4 x his power on an ally a spell of his lands on", "EXISTING_BASELINE",
		"data/subclasses/elemental_tactician.tres", "extra health on top, gone by the fight's end; not a heal")
	row("Formula", "Erysichthon - a meal", "", "Heal", "6% of its max health a meal (meal_heals 0.06)", "EXISTING_BASELINE",
		"data/enemies/glutton.tres", "a share of health")


func current_heals():
	for level in LEVELS:
		var alithia := made("alithia", level)
		var armed := made("alithia", level, MACE_BASE)
		var patients := PARTY.map(func(key): return made(key, level))
		row("Current", "Alithia", level, "Mindfulness", mind_of(alithia), "EXISTING_BASELINE", "combat/Stats.gd: main_stat_at", "her main stat")
		for patient in patients:
			row("Current", patient.name, level, "Max health", most_of(patient), "EXISTING_BASELINE", file_of(definition(patient.combatant_key)), "")
		for key in ALITHIA_SPELLS:
			var skill: SkillDefinition = SkillDatabase.skills[key]
			for patient in patients:
				var amount: int = combat.predict_hit(alithia, patient, skill).heal
				var with_mace: int = combat.predict_hit(armed, patient, skill).heal
				row("Current", skill.name, level, "on %s" % patient.name, amount, status_of(skill), file_of(skill),
					"%d%% of their max; %d with a weapon base of %d; %s" % [roundi(100.0 * amount / most_of(patient)), with_mace, MACE_BASE,
					availability(alithia, skill)])
		var enfina := made("enfina", level)
		var swing: SkillDefinition = SkillDatabase.skills["light_swing"]
		for effect in heal_effects(swing):
			var amount: int = combat.heal_share_from(enfina, enfina, swing, effect) if effect.heals_share_only else combat.heal_amount(enfina, swing, effect)
			row("Current", swing.name, level, "on Enfina (herself)", amount, status_of(swing), file_of(swing),
				"%d%% of her max; with the blow" % roundi(100.0 * amount / most_of(enfina)))
		var cyrus := made("cyrus", level)
		for key in ITEMS:
			var item: ItemDefinition = ItemDatabase.items[key]
			for patient in patients:
				var amount: int = combat.predict_hit(alithia, patient, item).heal
				var anybody: int = combat.predict_hit(cyrus, patient, item).heal
				row("Current", item.name, level, "on %s" % patient.name, amount, "EXISTING_BASELINE", file_of(item),
					"%d%% of their max; used by Alithia (Mercy I adds a tenth to the flat part); %d used by anybody else" % [
					roundi(100.0 * amount / most_of(patient)), anybody])


func enemy_heals():
	for level in LEVELS:
		var patients := ENEMY_PATIENTS.map(func(key): return made(key, level))
		for patient in patients:
			row("Enemy heals", patient.name, level, "Max health", most_of(patient), "EXISTING_BASELINE", file_of(definition(patient.combatant_key)), "")
		for healer_key in ENEMY_HEALS:
			var healer := made(healer_key, level)
			row("Enemy heals", healer.name, level, "Mindfulness", mind_of(healer), "EXISTING_BASELINE", file_of(definition(healer_key)),
				"weapon base %d here (set per fight: 6-12)" % int(healer.weapon_base))
			for key in ENEMY_HEALS[healer_key]:
				var skill: SkillDefinition = SkillDatabase.skills[key]
				for patient in patients:
					var amount: int = combat.predict_hit(healer, patient, skill).heal
					var notes := "%d%% of their max" % roundi(100.0 * amount / most_of(patient))
					if not combat.meets_level_for(healer, skill):
						notes += "; not yet: learned at %d" % skill.required_level
					row("Enemy heals", "%s's %s" % [healer.name, skill.name], level, "on %s" % patient.name, amount, status_of(skill), file_of(skill), notes)
					if HYBRID.has(key):
						for scenario in SCENARIOS:
							var missing := roundi(most_of(patient) * SCENARIOS[scenario])
							var proposed := hybrid(key, mind_of(healer), most_of(patient), missing)
							row("Enemy heals (PROPOSAL)", "%s's %s" % [healer.name, skill.name], level, "on %s, %s (%d missing)" % [patient.name, scenario, missing],
								proposed.amount, "PROPOSAL", "designer's hybrid, 2026-10-24", proposed.notes, "ABSENT")


## What the hybrid heal `key` would mend, capped at the missing health.
func hybrid(key: String, mind: int, most: int, missing: int) -> Dictionary:
	var rule: Dictionary = HYBRID[key]
	if rule.get("full", false):
		return {"amount": missing, "notes": "full health"}
	var raw := roundi(rule.get("missing", 0.0) * missing + rule.get("of_most", 0.0) * most + rule.mind * mind)
	var mercy := roundi(raw * 1.1)
	var amount := mini(raw, missing)
	var notes := "%s of the missing%s + %s x Mindfulness %d = %d" % [str(rule.get("missing", 0.0)),
		(" + %s of the most" % str(rule.of_most)) if rule.has("of_most") else "", str(rule.mind), mind, raw]
	if raw > missing:
		notes += "; capped at the missing %d" % missing
	notes += "; %d with Mercy I's +10%% if it still multiplies" % mini(mercy, missing)
	return {"amount": amount, "notes": notes}


func proposed_heals():
	for level in LEVELS:
		var alithia := made("alithia", level)
		var patients := PARTY.map(func(key): return made(key, level))
		for key in HYBRID:
			var skill: SkillDefinition = SkillDatabase.skills[key]
			for patient in patients:
				for scenario in SCENARIOS:
					var missing := roundi(most_of(patient) * SCENARIOS[scenario])
					var proposed := hybrid(key, mind_of(alithia), most_of(patient), missing)
					var now: int = mini(combat.predict_hit(alithia, patient, skill).heal, missing)
					row("Proposed (PROPOSAL)", skill.name, level, "on %s, %s (%d missing)" % [patient.name, scenario, missing], proposed.amount,
						"PROPOSAL", "designer's hybrid, 2026-10-24", "now %d; %s; %s" % [now, proposed.notes, availability(alithia, skill)], "ABSENT")


func enemy_blows():
	for level in LEVELS:
		if not FIGHTS.has(level):
			continue
		var party := PARTY.map(func(key): return made(key, level))
		var foes := []
		var names := []
		for path in FIGHTS[level]:
			var fight: EncounterDefinition = load(path)
			names.append(fight.display_name)
			for spawn in fight.spawns:
				if spawn.side == 0 or not CombatantDatabase.combatants.has(spawn.combatant_key) or definition(spawn.combatant_key) is BattleObjectDefinition:
					continue
				var foe: Dictionary = combat.create_combatant(definition(spawn.combatant_key), spawn.combatant_key, spawn.display_name, spawn)
				foe["alive"] = true
				foe["side"] = 1
				foes.append(foe)
		for friend in party:
			var bests := []
			var worst := {"damage": 0, "text": "nobody"}
			var seen := {}
			for foe in foes:
				var id := "%s/%d/%d" % [foe.combatant_key, foe.level, int(foe.weapon_base)]
				if seen.has(id):
					continue
				seen[id] = true
				var best := 0
				var best_skill := ""
				for skill_key in foe.skill_list:
					var skill: SkillDefinition = SkillDatabase.skills.get(skill_key)
					if skill == null or not skill.deals_damage or skill.targets_ally or not combat.meets_level_for(foe, skill):
						continue
					var damage: int = combat.predict_hit(foe, friend, skill).damage
					if damage > best:
						best = damage
						best_skill = skill.name
				if best <= 0:
					continue
				bests.append(best)
				if best > worst.damage:
					worst = {"damage": best, "text": "%s's %s (L%d)" % [foe.name, best_skill, foe.level]}
			bests.sort()
			var median: int = bests[int(bests.size() / 2.0)] if not bests.is_empty() else 0
			row("Enemy blows", friend.name, level, "Hardest single blow", worst.damage, "EXISTING_BASELINE", "worked out with Combat.predict_hit",
				"%s; %d%% of their max %d; fights: %s" % [worst.text, roundi(100.0 * worst.damage / most_of(friend)), most_of(friend), ", ".join(names)])
			blows["%d/%s" % [level, friend.name]] = [median, int(worst.damage)]
			row("Enemy blows", friend.name, level, "Typical blow (median of each enemy's best)", median, "EXISTING_BASELINE", "worked out with Combat.predict_hit",
				"%d%% of their max; over %d kinds of enemy" % [roundi(100.0 * median / most_of(friend)), bests.size()])


func short_rests():
	for level in LEVELS:
		for key in PARTY:
			var patient := made(key, level)
			var most := most_of(patient)
			for start in [0.5, 0.1]:
				var hp := roundi(most * start)
				var after := []
				for rest in 3:
					hp += roundi((most - hp) * SHORT_REST)
					after.append(hp)
				row("Short rest (PROPOSAL)", patient.name, level, "from %d%% (%d of %d)" % [roundi(start * 100), roundi(most * start), most],
					" / ".join(after.map(func(h): return str(h))), "PROPOSAL", "designer's short rest, 2026-10-24",
					"health after 1, 2 and 3 short rests (50% of the missing each)", "ABSENT")


func gates():
	for level in GATE_LEVELS:
		for key in ["prometheus", "alithia"]:
			var comb := made(key, level)
			var gates: Array = comb.get("max_spell_slots", [])
			var castings := 0
			var points := 0
			var counts := []
			for gate in range(1, gates.size()):
				castings += int(gates[gate])
				points += gate * int(gates[gate])
				if int(gates[gate]) > 0:
					counts.append("%s %d" % [Stats.gate_name(gate).replace("Gates of ", ""), int(gates[gate])])
			row("Gates", comb.name, level, "Castings by gate", " / ".join(counts), "EXISTING_BASELINE", "combat/Stats.gd: GATE_STEPS (+ passives)",
				"%d castings; %d points at a point per gate of depth" % [castings, points])


## The proposed cap on a heal at `level` (PROPOSAL bands, 2026-10-24): 25 to 7, 50
## from 8 to 18, 100 from 24 to 45, 175-225 from 54 (`high` is the top of that
## range). Levels 19-23 and 46-53 have no band yet; they take the band below.
func cap_at(level: int, high: bool = false) -> int:
	if level <= 7:
		return 25
	if level <= 23:
		return 50
	if level <= 53:
		return 100
	return 225 if high else 175


## Every enemy kind: not the party, not their summons, not a thing on the map.
func enemy_keys() -> Array:
	var keys := []
	for key in CombatantDatabase.combatants:
		var def = CombatantDatabase.combatants[key]
		if key in PARTY or key in NOT_ENEMIES or def is BattleObjectDefinition or not def is CombatantDefinition:
			continue
		keys.append(key)
	keys.sort()
	return keys


func is_big(key: String) -> bool:
	return key in BIG or definition(key).boss != null


## The hybrid heal `key` on somebody of `most` health with one left, uncapped.
func nearly_down(key: String, mind: int, most: int, multiplier: float = 1.0) -> int:
	var rule: Dictionary = HYBRID[key]
	var amount: float = rule.get("missing", 0.0) * (most - 1) + rule.get("of_most", 0.0) * most + rule.mind * mind
	return roundi(amount * multiplier)


func max_health():
	for level in LEVELS:
		for key in enemy_keys():
			var def := definition(key)
			row("Max health", def.name, level, "Max health", def.hp_at(level), "EXISTING_BASELINE", file_of(def),
				"boss" if def.boss != null else ("giant" if key in BIG else "enemy"))


## Where the cap would first trim each healer's heals at each level, on whom a
## nearly-down patient would set it off, and how far it sits above the party.
func cap_triggers():
	for level in LEVELS:
		var party := PARTY.map(func(key): return made(key, level))
		var biggest: Dictionary = party[0]
		for friend in party:
			if most_of(friend) > most_of(biggest):
				biggest = friend
		var caps := [cap_at(level)]
		if cap_at(level, true) != cap_at(level):
			caps.append(cap_at(level, true))
		for cap in caps:
			for healer_key in CAP_HEALERS:
				var healer := made(healer_key, level)
				var mind := mind_of(healer)
				var multipliers := [1.0, 1.1] if healer_key == "alithia" else [1.0]
				for key in CAP_HEALERS[healer_key]:
					var rule: Dictionary = HYBRID[key]
					var spell: String = SkillDatabase.skills[key].name
					if healer_key == "summoner":
						spell = "Mend the Bound (modelled as Heal)"
					for multiplier in multipliers:
						var share: float = rule.get("missing", rule.get("of_most", 0.0))
						var threshold := roundi((cap / multiplier - rule.mind * mind) / share)
						var basis := ("max health above %d" if rule.has("of_most") else "missing health above %d") % threshold
						var friends := []
						for friend in party:
							if nearly_down(key, mind, most_of(friend), multiplier) > cap:
								friends.append(friend.name)
						var foes := []
						var bigs := []
						for other in enemy_keys():
							var most: int = definition(other).hp_at(level)
							if nearly_down(key, mind, most, multiplier) > cap:
								(bigs if is_big(other) else foes).append(definition(other).name)
						var top := nearly_down(key, mind, most_of(biggest), multiplier)
						var mind_needed := roundi((cap / multiplier - share * (most_of(biggest) - (0 if rule.has("of_most") else 1))) / rule.mind)
						row("Cap trigger (PROPOSAL)", "%s's %s%s" % [healer.name, spell, " with Mercy I" if multiplier > 1.0 else ""], level,
							"cap %d" % cap, basis, "PROPOSAL", "designer's cap bands, 2026-10-24",
							"Mindfulness %d. Trims, nearly down: party %s; enemies %s; bosses and giants %s. Biggest on the party: %d on %s (%d%% of the cap); it trims that only at Mindfulness %d (%+d on the curve)" % [
							mind, ", ".join(friends) if not friends.is_empty() else "never", ", ".join(foes) if not foes.is_empty() else "never",
							", ".join(bigs) if not bigs.is_empty() else "never", top, biggest.name, roundi(100.0 * top / cap), mind_needed, mind_needed - mind], "ABSENT")


## What heals would do to each boss and giant: nearly down, uncapped and capped,
## as a share of its health - and beside it what a boss can get now: a Potent
## Cure Potion if it ever drank one, and Erysichthon's meals.
func boss_heals():
	for level in LEVELS:
		var priest := made("priest", level)
		var mind := mind_of(priest)
		for key in BIG:
			var def := definition(key)
			var most: int = def.hp_at(level)
			row("Boss healing", def.name, level, "Max health", most, "EXISTING_BASELINE", file_of(def), "")
			for spell in ["light_heal", "heal", "communion", "restoration"]:
				var raw := nearly_down(spell, mind, most)
				var low := mini(raw, cap_at(level))
				var high := mini(raw, cap_at(level, true))
				row("Boss healing (PROPOSAL)", def.name, level, "%s, nearly down, from a healer of Mindfulness %d" % [SkillDatabase.skills[spell].name, mind],
					low, "PROPOSAL", "hybrid + cap",
					"uncapped %d (%d%% of its health); capped %d (%d%%)%s; %d capped heals lift it from a tenth to full" % [raw,
					roundi(100.0 * raw / most), low, roundi(100.0 * low / most),
					("; at the top of the band %d (%d%%)" % [high, roundi(100.0 * high / most)]) if high != low else "",
					ceili(0.9 * most / float(maxi(low, 1)))], "ABSENT")
			row("Boss healing", def.name, level, "A Potent Cure Potion, if it drank one", roundi(most * 0.55), "EXISTING_BASELINE",
				"data/items/potent_cure_potion.tres", "55% of its health, uncapped; no boss carries one now")
			if def.meal_heals > 0.0:
				var meal := roundi(most * def.meal_heals)
				row("Boss healing", def.name, level, "A meal now (%d%% of its health)" % roundi(def.meal_heals * 100), meal, "EXISTING_BASELINE",
					file_of(def) + ": meal_heals", "free, at its turn's start and again after it moves; in the laboratory fight up to 7 meals (the carrion heap and six fallen Gnawers): %d, %d%% of its health" % [
					7 * meal, roundi(700.0 * meal / most)])


## The chapter bands proposed in docs/healing_cap_proposal.md (PROPOSAL).
func proposed_cap_at(level: int) -> int:
	if level <= 7:
		return 45
	if level <= 18:
		return 60
	if level <= 33:
		return 80
	if level <= 45:
		return 100
	if level <= 55:
		return 150
	return 175


## Every level, both sets of bands: whom a nearly-down heal would be trimmed on -
## Alithia's Heal and (from 54) Restoration, with and without Mercy I, and an
## enemy healer's Heal on every ordinary enemy - and what a capped Heal is worth
## to each boss and giant.
func cap_by_level():
	for level in range(1, Stats.MAX_LEVEL + 1):
		var alithia := made("alithia", level)
		var mind := mind_of(alithia)
		var foe_mind := mind_of(made("priest", level))
		var party := PARTY.map(func(key): return made(key, level))
		for bands in ["designer's bands", "proposed chapter bands"]:
			var cap: int = cap_at(level) if bands == "designer's bands" else proposed_cap_at(level)
			var trimmed := []
			var top := 0
			for friend in party:
				for multiplier in [1.0, 1.1]:
					for spell in (["heal", "restoration"] if level >= 54 else ["heal"]):
						var amount := nearly_down(spell, mind, most_of(friend), multiplier)
						top = maxi(top, amount)
						if amount > cap:
							trimmed.append("%s's %s on %s %d" % ["Alithia", SkillDatabase.skills[spell].name + (" (Mercy I)" if multiplier > 1.0 else ""), friend.name, amount])
			for other in enemy_keys():
				if is_big(other):
					continue
				var amount := nearly_down("heal", foe_mind, definition(other).hp_at(level))
				if amount > cap:
					trimmed.append("a Priest's Heal on %s %d" % [definition(other).name, amount])
			var shares := []
			for key in BIG:
				var most: int = definition(key).hp_at(level)
				var capped := mini(nearly_down("heal", foe_mind, most), cap)
				shares.append("%s %d%%" % [definition(key).name, roundi(100.0 * capped / most)])
			row("Cap by level (PROPOSAL)", bands, level, "cap %d" % cap, "trims " + ("; ".join(trimmed) if not trimmed.is_empty() else "nobody but bosses"),
				"PROPOSAL", "docs/healing_cap_proposal.md",
				"Alithia's biggest heal %d (%d%% of the cap); a capped Heal on a boss, nearly down: %s" % [top, roundi(100.0 * top / cap), ", ".join(shares)], "ABSENT")


## The revised heal `key` (REVISED) for a healer of `mind` with weapon base
## `weapon`, on somebody of `most` health; the cap of their health is the game's.
func revised(key: String, mind: int, weapon: int, most: int, multiplier: float = 1.0) -> int:
	var rule: Dictionary = REVISED[key]
	if rule.get("full", false):
		return most
	var amount: float = rule.get("flat", 0.0) + rule.get("of_most", 0.0) * most + rule.mind * mind + rule.get("weapon", 0.0) * weapon
	return roundi(amount * multiplier)


func pct(amount: int, most: int) -> int:
	return roundi(100.0 * amount / maxi(most, 1))


## The revision on the party at every level: now against revised, as a share of
## each member's health, at three weapon bases, with and without Mercy I.
func revised_party():
	for level in LEVELS:
		var alithia := made("alithia", level)
		var mind := mind_of(alithia)
		var patients := PARTY.map(func(key): return made(key, level))
		for key in REVISED:
			var skill: SkillDefinition = SkillDatabase.skills[key]
			for patient in patients:
				var most := most_of(patient)
				var now: int = mini(combat.predict_hit(alithia, patient, skill).heal, most)
				var amounts := WEAPONS.map(func(weapon): return revised(key, mind, weapon, most))
				var mercy := revised(key, mind, 6, most, 1.1)
				row("Revised (PROPOSAL)", skill.name, level, "on %s" % patient.name, amounts[0], "PROPOSAL", "designer's revision, 2026-10-24",
					"%d%% of their max %d; now %d (%d%%); weapon base 10: %d, 12: %d; with Mercy I %d; %s" % [pct(amounts[0], most), most, now, pct(now, most),
					amounts[1], amounts[2], mercy, availability(alithia, skill)], "ABSENT")


## The revised Heal, Light Heal and Communion against the enemies' typical and
## hardest blows in the real fights (weapon base 6, no Mercy I).
func revised_against_blows():
	for level in LEVELS:
		if not FIGHTS.has(level):
			continue
		var mind := mind_of(made("alithia", level))
		var alithia := made("alithia", level)
		for key in PARTY:
			var patient := made(key, level)
			var most := most_of(patient)
			var seen: Array = blows.get("%d/%s" % [level, patient.name], [0, 0])
			var heal := revised("heal", mind, 6, most)
			var now: int = combat.predict_hit(alithia, patient, SkillDatabase.skills["heal"]).heal
			row("Revised against blows (PROPOSAL)", patient.name, level, "Heal against the typical blow", heal, "PROPOSAL", "designer's revision, 2026-10-24",
				"typical blow %d, hardest %d; the Heal undoes %d%% of a typical blow (now %d: %d%%) and is %d%% of their max; Light Heal %d, Communion %d" % [
				int(seen[0]), int(seen[1]), pct(heal, int(seen[0])), now, pct(now, int(seen[0])), pct(heal, most),
				revised("light_heal", mind, 6, most), revised("communion", mind, 6, most)], "ABSENT")


## The enemy healers under the revision, now and revised, on small, average,
## tanky and the largest enemies and on the bosses, at weapon base 6 (every
## Chapter I fight) and 12 (Sixty-Four).
func revised_enemies():
	for level in LEVELS:
		for weapon in [6, 12]:
			for healer_key in ["priest", "ranger", "mimic"]:
				var healer := made(healer_key, level, weapon)
				var mind := mind_of(healer)
				var spells := ["heal", "communion"] if healer_key == "priest" else ["heal"]
				for key in spells:
					var skill: SkillDefinition = SkillDatabase.skills[key]
					var parts := []
					for target_key in REVISED_PATIENTS + BIG:
						var target := made(target_key, level)
						var most := most_of(target)
						var now: int = mini(combat.predict_hit(healer, target, skill).heal, most)
						var amount := revised(key, mind, weapon, most)
						parts.append("%s %d (%d%%; now %d)" % [target.name, amount, pct(amount, most), now])
					row("Revised on enemies (PROPOSAL)", "%s's %s" % [healer.name, skill.name], level, "weapon base %d, Mindfulness %d" % [weapon, mind],
						revised(key, mind, weapon, 100), "PROPOSAL", "designer's revision, 2026-10-24", "; ".join(parts), "ABSENT")


## Every level: the largest flat heal there can be (Heal, Mercy I, weapon base
## 12), against the cap proposed for the hybrid; the largest share-of-health heal
## on the party (a Potent Cure on Enfina; Restoration with Mercy I from 54); and
## what an uncapped share-of-health heal would be on each boss.
func revised_caps():
	for level in range(1, Stats.MAX_LEVEL + 1):
		var mind := mind_of(made("alithia", level))
		var enfina := made("enfina", level)
		var most := most_of(enfina)
		var flat := revised("heal", mind, 12, most, 1.1)
		var potent := roundi(most * 0.55)
		var restoration := revised("restoration", mind, 6, most, 1.1) if level >= 54 else 0
		var shares := []
		for key in BIG:
			var big_most: int = definition(key).hp_at(level)
			shares.append("%s: Potent %d (55%%)%s" % [definition(key).name, roundi(big_most * 0.55),
				(", Restoration %d" % revised("restoration", mind, 6, big_most)) if level >= 54 else ""])
		row("Revised cap check (PROPOSAL)", "Level %d" % level, level, "largest flat heal / largest share heal on the party", "%d / %d" % [flat, maxi(potent, restoration)],
			"PROPOSAL", "designer's revision, 2026-10-24",
			"flat: Heal with Mercy I at weapon base 12 = %d against the hybrid's proposed cap %d (%d%%); share: Potent Cure on Enfina %d%s; on the bosses, uncapped: %s" % [
			flat, proposed_cap_at(level), pct(flat, proposed_cap_at(level)), potent,
			(", Restoration with Mercy I on Enfina %d" % restoration) if level >= 54 else "", "; ".join(shares)], "ABSENT")
