extends Node
## docs/progression.csv, the progression the user planned (docs/progression_plan.md
## says how each row went in): every Base row checked against the game's data -
## its level, its multiplier, its lingering damage and how long - and the
## switches its passives needed, played in a fight at level 64.

var LOG_PATH := HarnessLog.path_for("csv")
var _log: FileAccess
var _fail = 0
var combat = null

## CSV feature -> [character, skill or passive key, rank level (0 for the skill
## itself), "skill" or "passive"]. Glass Cannon is Kindling (no passive with a
## downside), Taunting Shout is Battle Cry (no taunts), Double
## Strike is Follow Up Attack, and a "stronger version" is a rank.
const MAP := {
	"Enfina|Basic Strike": ["greatsword_attack", 0, "skill"],
	"Enfina|Heavy Swing": ["greatsword_attack", 8, "skill"],
	"Enfina|Guard": ["guard", 0, "skill"],
	"Enfina|Iron Hide I": ["iron_hide", 0, "passive"],
	"Enfina|Bulwark I": ["bulwark", 0, "passive"],
	"Enfina|Taunting Shout": ["battle_cry", 0, "skill"],
	"Enfina|Iron Hide II": ["iron_hide_ii", 0, "passive"],
	"Enfina|Armor Shred": ["armor_shred", 0, "skill"],
	"Enfina|Double Strike": ["follow_up_attack", 0, "skill"],
	"Enfina|Momentum I": ["momentum", 0, "passive"],
	"Enfina|Short Stun": ["stunning_blow", 0, "skill"],
	"Enfina|Iron Hide III": ["iron_hide_iii", 0, "passive"],
	"Enfina|AOE Sweep": ["sweep_strike", 0, "skill"],
	"Enfina|Bulwark III": ["bulwark_iii", 0, "passive"],
	"Enfina|Ultimate Smash": ["greatsword_attack", 64, "skill"],
	"Enfina|Momentum II": ["momentum_ii", 0, "passive"],
	"Cyrus|Basic Shot": ["gun", 0, "skill"],
	"Cyrus|Light Cover Leap": ["cover_leap", 0, "skill"],
	"Cyrus|Cover Runner I": ["cat_burglar_i", 0, "passive"],
	"Cyrus|Poison Strike": ["poison_dart", 0, "skill"],
	"Cyrus|Agile I": ["agile", 0, "passive"],
	"Cyrus|Burn Bomb": ["burning_shot", 0, "skill"],
	"Cyrus|DoT Master I": ["dot_master", 0, "passive"],
	"Cyrus|Wide Poison": ["venom_fan", 0, "skill"],
	"Cyrus|Cover Runner II": ["cat_burglar", 0, "passive"],
	"Cyrus|Strong Burn": ["burning_shot", 32, "skill"],
	"Cyrus|Minor Slow Shot": ["warning_shot", 0, "skill"],
	"Cyrus|Agile II": ["agile_ii", 0, "passive"],
	"Cyrus|Armor Weakness": ["exposing_shot", 0, "skill"],
	"Cyrus|DoT Master II": ["dot_master_ii", 0, "passive"],
	"Cyrus|Synergy I": ["synergy", 0, "passive"],
	"Cyrus|Synergy II": ["synergy_ii", 0, "passive"],
	"Prometheus|Cantrip": ["fire_burst", 0, "skill"],
	"Prometheus|Small Firebolt": ["fire_blast", 0, "skill"],
	"Prometheus|Early Windswept": ["wind_swoon", 0, "skill"],
	"Prometheus|Small Burn": ["burner", 0, "skill"],
	"Prometheus|Elemental Affinity I": ["elemental_affinity", 0, "passive"],
	"Prometheus|Strong Burn": ["wildfire", 0, "skill"],
	"Prometheus|Crystallize I": ["crystalise", 0, "skill"],
	"Prometheus|Mid Windswept": ["gust_blast", 0, "skill"],
	"Prometheus|Contest Insight I": ["contest_insight", 0, "passive"],
	"Prometheus|Big Nuke (Lvl-5)": ["tartarus_flame", 0, "skill"],
	"Prometheus|Elemental Affinity II": ["elemental_affinity_ii", 0, "passive"],
	"Prometheus|High-tier Nukes (Lvl-7)": ["ire_of_sophia", 0, "skill"],
	"Prometheus|Contest Insight II": ["contest_insight_ii", 0, "passive"],
	"Prometheus|Level-9 Spell": ["gnostic_tempest", 0, "skill"],
	"Prometheus|Level-10 Spell": ["stolen_sun", 0, "skill"],
	"Prometheus|Elemental Mastery": ["elemental_mastery", 0, "passive"],
	"Prometheus|Glass Cannon I": ["kindling", 0, "passive"],
	"Prometheus|Glass Cannon II": ["kindling_ii", 0, "passive"],
	"Prometheus|Glass Cannon III": ["kindling_iii", 0, "passive"],
	"Alithia|Cantrip": ["votive_flame", 0, "skill"],
	"Alithia|Small Heal": ["heal", 0, "skill"],
	"Alithia|Mercy I": ["mercy", 0, "passive"],
	"Alithia|Holy Splash": ["holy_splash", 0, "skill"],
	"Alithia|Frozen I": ["river_flow", 0, "skill"],
	"Alithia|Aura I": ["aura", 0, "passive"],
	"Alithia|Group Heal": ["communion", 0, "skill"],
	"Alithia|Frozen II": ["frozen_river", 0, "skill"],
	"Alithia|Mercy II": ["mercy_ii", 0, "passive"],
	"Alithia|Holy Lance (Pen 25%)": ["piercing_light", 0, "skill"],
	"Alithia|Aura II": ["aura_ii", 0, "passive"],
	"Alithia|Judgment (Pen 50%)": ["judgment", 0, "skill"],
	"Alithia|Reserved Power I": ["reserved_power", 0, "passive"],
	"Alithia|Frozen AOE": ["glacial_tide", 0, "skill"],
	"Alithia|Advanced Cleanse": ["purification", 0, "skill"],
	"Alithia|Mercy III": ["mercy_iii", 0, "passive"],
	"Alithia|Level-9 Penetration Spell": ["divine_verdict", 0, "skill"],
	"Alithia|Elite Heal": ["restoration", 0, "skill"],
	"Alithia|Reserved Power II": ["reserved_power_ii", 0, "passive"],
	"Alithia|Level-10 Penetration Spell": ["revelation", 0, "skill"],
	"Alithia|Capstone Heal": ["grace", 0, "skill"],
	"Alithia|Radiant Guardian": ["radiant_guardian", 0, "passive"],
}
## Rows left out by the user's decision.
const LEFT_OUT := []
## Numbers the user changed from the CSV's: Titanfall (Ultimate Smash) is Greatsword
## Attack's rank at 64, x3.0 with a x1.5 splash (2026-10-23); and Cyrus's direct
## hits, by docs/cyrus_damage_adjustments.csv (2026-10-23, confirmed by
## docs/handoff_0.1/finisher_removal_momentum_synergy.md) - his ammunition trades
## burst for what it leaves behind.
const CHANGED := {"Enfina|Ultimate Smash": 3.0, "Cyrus|Poison Strike": 0.9, "Cyrus|Burn Bomb": 0.8,
	"Cyrus|Wide Poison": 0.7, "Cyrus|Strong Burn": 0.95}


func log_line(t): _log.store_line(t); _log.flush()

func ok(condition: bool, label: String, detail: String = ""):
	if condition:
		log_line("  PASS  %s %s" % [label, detail])
	else:
		_fail += 1
		log_line("  FAIL  %s %s" % [label, detail])


func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(150.0, true, false, true).timeout.connect(func():
		log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	the_rows()
	the_party_sheet()
	the_enemy_sheet()
	await the_switches()
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


## docs/player_hp_defense_progression.csv: every one of the party's health and
## Defense, level by level.
func the_party_sheet():
	log_line("======== the party's health and Defense are the sheet's ========")
	var file := FileAccess.open("res://docs/player_hp_defense_progression.csv", FileAccess.READ)
	ok(file != null, "docs/player_hp_defense_progression.csv is there")
	if file == null:
		return
	file.get_csv_line()
	var rows := 0
	var off := []
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < 5:
			continue
		var definition: CombatantDefinition = CombatantDatabase.combatants.get(row[0].to_lower())
		if definition == null:
			off.append("%s: nobody" % row[0])
			continue
		var level := int(row[1])
		rows += 1
		if definition.hp_at(level) != int(row[3]) or definition.defense_at(level) != int(row[4]):
			off.append("%s %d: %d/%d, sheet %s/%s" % [row[0], level, definition.hp_at(level), definition.defense_at(level), row[3], row[4]])
	ok(rows == 256 and off.is_empty(), "all %d rows: health and Defense at every level" % rows, "%s" % [off.slice(0, 8)])
	log_line("")


## docs/enemy_progression.csv: each enemy the sheet covers has health and Defense
## inside its kind's band at the middle of every tier.
const ENEMY_KINDS := {
	"Frail": ["rat", "gnawer", "imp", "summoner", "sorcerer", "bomber", "alchemist"],
	"Average": ["hired_bow", "priest", "ranger", "mimic", "bound_beast", "sellsword"],
	"Tanky": ["ogre", "barbarian", "golem", "pit_champion"],
}
func the_enemy_sheet():
	log_line("======== the enemies' health and Defense sit in their kind's band ========")
	var file := FileAccess.open("res://docs/enemy_progression.csv", FileAccess.READ)
	ok(file != null, "docs/enemy_progression.csv is there")
	if file == null:
		return
	file.get_csv_line()
	var off := []
	var checked := 0
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < 8:
			continue
		var middle := (int(row[1]) + int(row[2])) / 2
		for key in ENEMY_KINDS.get(row[3], []):
			var definition: CombatantDefinition = CombatantDatabase.combatants[key]
			var hp := definition.hp_at(middle)
			var defense := definition.defense_at(middle)
			checked += 1
			if hp < int(row[4]) or hp > int(row[5]) or defense < int(row[6]) or defense > int(row[7]):
				off.append("%s at %d: %d hp, %d def; %s %s-%s hp, %s-%s def" % [key, middle, hp, defense, row[3], row[4], row[5], row[6], row[7]])
	ok(checked == 68 and off.is_empty(), "%d checks, every one in its band" % checked, "%s" % [off.slice(0, 8)])
	log_line("")


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


## One CSV line split on commas outside quotes.
static func fields(line: String) -> Array:
	var out := []
	var cell := ""
	var quoted := false
	for c in line:
		if c == "\"":
			quoted = not quoted
		elif c == "," and not quoted:
			out.append(cell)
			cell = ""
		else:
			cell += c
	out.append(cell)
	return out


func the_rows():
	log_line("======== Every Base row of docs/progression.csv ========")
	var file := FileAccess.open("res://docs/progression.csv", FileAccess.READ)
	ok(file != null, "the CSV is there")
	if file == null:
		return
	var header := fields(file.get_line())
	var col := {}
	for i in header.size():
		col[header[i]] = i
	var checked := 0
	var wrong := []
	var unmapped := []
	while not file.eof_reached():
		var line := file.get_line()
		if line.strip_edges() == "":
			continue
		var row := fields(line)
		if row[col["Subclass"]] != "Base":
			continue
		var who: String = row[col["Character"]]
		var feature: String = row[col["FeatureName"]]
		var id := "%s|%s" % [who, feature]
		if id in LEFT_OUT:
			continue
		if not MAP.has(id):
			unmapped.append(id)
			continue
		checked += 1
		var target: Array = MAP[id]
		var level := int(row[col["Level"]])
		var definition: CombatantDefinition = CombatantDatabase.combatants.get(who.to_lower())
		if target[2] == "passive":
			var passive: PassiveDefinition = load("res://data/passives/%s.tres" % target[0])
			var theirs: bool = definition != null and definition.passives.any(func(p): return p != null and p.resource_path == passive.resource_path)
			if passive == null or passive.required_level != level or not theirs:
				wrong.append("%s: passive %s at %d, theirs %s" % [id, target[0], passive.required_level if passive != null else -1, theirs])
			continue
		var skill: SkillDefinition = SkillDatabase.skills.get(target[0])
		if skill == null or definition == null or not definition.skills.has(target[0]):
			wrong.append("%s: no skill %s in their kit" % [id, target[0]])
			continue
		var hit := float(row[col["SkillMod_Hit"]]) if row[col["SkillMod_Hit"]] != "" else -1.0
		hit = CHANGED.get(id, hit)
		var dot := float(row[col["SkillMod_Dot"]]) if row[col["SkillMod_Dot"]] != "" else -1.0
		var turns := int(row[col["Duration"]]) if row[col["Duration"]] != "" else -1
		var at: int = skill.required_level
		var modifier: float = skill.ability_modifier
		var strength := -1.0
		var lasts := -1
		for effect in skill.effects:
			if effect != null and effect.type == EffectDefinition.EffectType.CONDITION:
				strength = effect.condition_dot_strength()
				lasts = effect.condition_duration if effect.condition_duration > 0 else effect.condition.duration
				break
		if target[1] > 0:
			var rank: SkillRank = null
			for each in skill.ranks:
				if each != null and each.level == target[1]:
					rank = each
			if rank == null:
				wrong.append("%s: %s has no rank at %d" % [id, target[0], target[1]])
				continue
			at = rank.level
			modifier = rank.ability_modifier if rank.ability_modifier > 0.0 else modifier
			strength = rank.condition_dot_modifier if rank.condition_dot_modifier > 0.0 else strength
			lasts = rank.condition_duration if rank.condition_duration > 0 else lasts
		if at != level:
			wrong.append("%s: level %d, the CSV's %d" % [id, at, level])
		# Not before its gate opens, either.
		if skill.spell_slot_level > 0 and CharacterSheet.gate_opens_at(skill.spell_slot_level) > level:
			wrong.append("%s: its gate opens after level %d" % [id, level])
		if hit >= 0.0 and not is_equal_approx(modifier, hit):
			wrong.append("%s: x%s, the CSV's x%s" % [id, modifier, hit])
		if dot >= 0.0 and not is_equal_approx(strength, dot):
			wrong.append("%s: lingering %s, the CSV's %s" % [id, strength, dot])
		if turns >= 0 and lasts >= 0 and lasts != turns:
			wrong.append("%s: %d turns, the CSV's %d" % [id, lasts, turns])
		var pen: String = row[col["DefenseChange"]]
		if pen.begins_with("Pen "):
			var percent := int(pen.trim_prefix("Pen ").trim_suffix("%"))
			if skill.ignores_defense != percent:
				wrong.append("%s: ignores %d%% of defence, the CSV's %d%%" % [id, skill.ignores_defense, percent])
	ok(unmapped.is_empty(), "every Base row has its place in the game", "%s" % [unmapped])
	ok(wrong.is_empty(), "%d rows match their level, multiplier, lingering damage and length" % checked, "%s" % [wrong])


func who(key: String) -> Dictionary:
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == key and comb.alive:
			return comb
	return {}


func the_switches():
	log_line("")
	log_line("======== The switches, at level 64 ========")
	Campaign.reset()
	var den: EncounterDefinition = load("res://data/encounters/alchemist_den.tres").duplicate(true)
	for spawn in den.spawns:
		spawn.level = 64
	Campaign.current_encounter = den
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle(8)
	combat = game.get_node("VisualCombat")
	if combat.deployment_active:
		combat.finish_deployment()
		await settle(2)
	combat.reaction_prompt = null
	var enfina := who("enfina")
	var cyrus := who("cyrus")
	var alithia := who("alithia")
	var prometheus := who("prometheus")
	var foe: Dictionary = combat.combatants.filter(func(comb): return comb.alive and comb.side == 1 and not comb.has("object"))[0]
	var sword: SkillDefinition = SkillDatabase.skills["greatsword_attack"]

	# Ranks.
	ok(is_equal_approx(Combat.modifier_of({"level": 8}, sword), 1.5) and is_equal_approx(Combat.modifier_of({"level": 1}, sword), 1.0),
		"Greatsword Attack: x1.0 at level 1, x1.5 from 8 (Heavy Swing)")
	ok(is_equal_approx(Combat.modifier_of(enfina, sword), 3.0), "and x3.0 at 64 (Titanfall)")
	# Titanfall's splash: x1.5 to everybody of the other side within 2 of whoever
	# it lands on - shoving nobody since the designer's change of 2026-10-24
	# (APPROVED_TRIAL): Titanfall is the damage, Tremor the control.
	var foes: Array = combat.combatants.filter(func(comb): return comb.alive and comb.side == 1 and not comb.has("object"))
	if foes.size() >= 2:
		var struck: Dictionary = foes[0]
		var near: Dictionary = foes[1]
		var spot := Vector2i(-99999, -99999)
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				var tile: Vector2i = struck.position + Vector2i(dx, dy)
				if spot.x == -99999 and tile != struck.position and combat.distance_to(struck, tile) == 2 \
						and not combat.controller.is_tile_blocking(tile, 0) and combat.get_combatant_at(tile).is_empty():
					spot = tile
		if spot.x != -99999 and combat.teleport_to(near, spot):
			near.max_hp = 9999
			near.hp = 9999
			struck.max_hp = 9999
			struck.hp = 9999
			for other in foes.slice(2):
				if combat.distance_to(struck, other.position) <= 2:
					combat.teleport_to(other, other.position + Vector2i(12, 12))
			var expected: int = combat.resisted_damage(near, sword.damage_type, combat.skill_damage(enfina, near, sword, 1.5 / 3.0))
			combat._splash(enfina, struck, sword)
			await settle(4)
			ok(near.hp < 9999 and near.position == spot, "the shock catches the one 2 tiles off, and leaves them where they stand",
				"%d (about %d), %s -> %s" % [9999 - near.hp, expected, spot, near.position])
			ok(SkillDatabase.skills["greatsword_attack"].ranks.all(func(rank): return rank.splash_shove == 0), "  Titanfall shoves nobody")
			ok(struck.hp == 9999, "and not the one struck again")
		else:
			log_line("  NOTE  no room 2 tiles from %s to test the splash" % struck.name)
	ok(not SkillDatabase.skills.has("titanfall") and not SkillDatabase.skills.has("earthsplitter") and not SkillDatabase.skills.has("meteor"),
		"Titanfall is no move of its own any more; Earthsplitter and Meteor are gone")
	# A spell does not rank up: its stronger version is a spell of its own.
	ok(is_equal_approx(Combat.modifier_of(prometheus, SkillDatabase.skills["burner"]), 1.7)
		and SkillDatabase.skills["burner"].ranks.is_empty() and SkillDatabase.skills["river_flow"].ranks.is_empty()
		and prometheus.skill_list.has("wildfire") and alithia.skill_list.has("frozen_river"),
		"Burner stays Burner at 64; Wildfire and Frozen River are spells of their own")
	var ranked: Array = SkillDatabase.skills.keys().filter(func(key): return Combat.is_spell(SkillDatabase.skills[key]) and not SkillDatabase.skills[key].ranks.is_empty())
	ok(ranked.is_empty(), "no spell ranks up", "%s" % [ranked])

	# Taking less.
	enfina.status_effects.clear()
	alithia.status_effects.clear()
	var radiant: bool = combat.active_passives(alithia).any(func(p): return p.party_damage_reduction > 0.0)
	ok(radiant and is_equal_approx(combat.damage_reduction_of(enfina), 0.3),
		"Enfina takes a fifth less (Iron Hide I and II) and a tenth more less while Alithia stands (Radiant Guardian)", "%.2f" % combat.damage_reduction_of(enfina))

	# Momentum.
	enfina.erase("moved_this_turn")
	foe.status_effects.clear()
	ok(is_equal_approx(combat.progression_damage_bonus(enfina, foe, sword), 1.15), "planted, she hits fifteen hundredths harder (Momentum II upgrading I)",
		"%.2f" % combat.progression_damage_bonus(enfina, foe, sword))
	enfina["moved_this_turn"] = true
	ok(is_equal_approx(combat.progression_damage_bonus(enfina, foe, sword), 1.0), "and not after a walk")
	# Sweep Strike too (docs/handoff_0.1/finisher_removal_momentum_synergy.md):
	# Momentum is on every blow of a turn not walked, the whole sweep included.
	var sweep: SkillDefinition = SkillDatabase.skills["sweep_strike"]
	enfina.erase("moved_this_turn")
	enfina.level = 54
	ok(is_equal_approx(Combat.modifier_of(enfina, sweep) * combat.progression_damage_bonus(enfina, foe, sweep), 1.54),
		"at 54, planted, Sweep Strike lands x1.54 (Momentum I)", "x%.2f" % (Combat.modifier_of(enfina, sweep) * combat.progression_damage_bonus(enfina, foe, sweep)))
	enfina.level = 64
	ok(is_equal_approx(Combat.modifier_of(enfina, sweep) * combat.progression_damage_bonus(enfina, foe, sweep), 1.61),
		"at 64, x1.61: Momentum II's fifteen hundredths in place of I's tenth", "x%.2f" % (Combat.modifier_of(enfina, sweep) * combat.progression_damage_bonus(enfina, foe, sweep)))
	enfina["moved_this_turn"] = true
	ok(is_equal_approx(combat.progression_damage_bonus(enfina, foe, sweep), 1.0), "  and nothing more after a walk")

	# Ranks of a passive (the designer, 2026-10-25): a higher rank's numbers replace
	# the lower's, every effect stays, and a reach goes to every rank.
	var momentum: PassiveDefinition = load("res://data/passives/momentum.tres")
	var momentum_ii: PassiveDefinition = load("res://data/passives/momentum_ii.tres")
	ok(Combat.passive_family(momentum) == "Momentum" and Combat.passive_family(momentum_ii) == "Momentum"
		and Combat.passive_rank(momentum_ii) == 2, "Momentum I and II are one passive in two ranks")
	var upgraded: Array = Combat.with_ranks([momentum, momentum_ii])
	ok(upgraded[0].still_damage_bonus == 0.0 and upgraded[1].still_damage_bonus == 0.15 and momentum.still_damage_bonus == 0.1,
		"  II's number in place of I's - and Momentum I itself untouched", "%s, %s" % [upgraded[0].still_damage_bonus, upgraded[1].still_damage_bonus])
	var bulwark: PassiveDefinition = load("res://data/passives/bulwark.tres")
	var bulwark_iii: PassiveDefinition = load("res://data/passives/bulwark_iii.tres")
	upgraded = Combat.with_ranks([bulwark, bulwark_iii])
	ok(upgraded[0].aura_radius == 2 and upgraded[0].aura_on_allies == bulwark.aura_on_allies and upgraded[1].aura_on_allies == bulwark_iii.aura_on_allies,
		"Bulwark III: both auras stay, and Bulwark I's reaches two tiles", "radius %d" % upgraded[0].aura_radius)
	var aura: PassiveDefinition = load("res://data/passives/aura.tres")
	var aura_ii: PassiveDefinition = load("res://data/passives/aura_ii.tres")
	upgraded = Combat.with_ranks([aura, aura_ii])
	ok(upgraded[0].aura_on_allies != null and upgraded[1].aura_on_allies != null and upgraded[0].aura_on_allies != upgraded[1].aura_on_allies,
		"Aura II: Blessed and Soothed both")
	var iron: Array = [load("res://data/passives/iron_hide.tres"), load("res://data/passives/iron_hide_ii.tres"), load("res://data/passives/iron_hide_iii.tres")]
	upgraded = Combat.with_ranks(iron)
	ok(is_equal_approx(upgraded.reduce(func(total, rank): return total + rank.damage_reduction, 0.0), 0.2) and upgraded[2].guards_within == 1,
		"Iron Hide: a fifth less damage, II's in place of I's, and III's guard as well")
	var kindling: Array = [load("res://data/passives/kindling.tres"), load("res://data/passives/kindling_ii.tres"), load("res://data/passives/kindling_iii.tres")]
	upgraded = Combat.with_ranks(kindling)
	ok(is_equal_approx(upgraded.reduce(func(total, rank): return total + rank.kindling_most, 0.0), 0.45) and upgraded[0].kindling_step == 0.05,
		"Kindling: up to 45%, III's in place of the others', at I's 5% a spell")
	var families := CharacterSheet.passive_families([momentum, bulwark, momentum_ii])
	ok(families.size() == 2 and families[0] == [momentum, momentum_ii], "the sheet shows Momentum as one passive")

	# Lingering, Synergy.
	var burning: SkillDefinition = SkillDatabase.skills["burning_shot"]
	combat.apply_effect(cyrus, foe, burning.effects[0], burning, false)
	var burn: Dictionary = foe.status_effects.filter(func(e): return e.get("stat", "") == "condition")[0]
	var plain: float = combat.dot_base_damage(cyrus, burning, Combat.dot_strength_of(cyrus, burning, burning.effects[0]))
	ok(is_equal_approx(burn.dot_base, plain * 1.2) and burn.duration == Combat.turns_stored(3 + 1, false),
		"Cyrus's burn: a fifth harder and a turn longer (DoT Master II upgrading I)", "%.1f vs %.1f, %d" % [burn.dot_base, plain, burn.duration])
	ok(is_equal_approx(combat.progression_damage_bonus(alithia, foe, SkillDatabase.skills["votive_flame"]), 1.2),
		"the party hits it a fifth harder: afflicted, and by him (Synergy I and II)", "%.2f" % combat.progression_damage_bonus(alithia, foe, SkillDatabase.skills["votive_flame"]))

	# Kindling, in place of Glass Cannon.
	var blast: SkillDefinition = SkillDatabase.skills["fire_blast"]
	prometheus["spells_cast"] = 0
	var cold: float = combat.progression_damage_bonus(prometheus, foe, blast)
	prometheus["spells_cast"] = 3
	var warm: float = combat.progression_damage_bonus(prometheus, foe, blast)
	prometheus["spells_cast"] = 20
	var hot: float = combat.progression_damage_bonus(prometheus, foe, blast)
	ok(is_equal_approx(warm - cold, 0.15) and is_equal_approx(hot - cold, 0.45),
		"three spells in, his next is 15% hotter; it tops out at 45% (Kindling I, II and III)", "%.2f, %.2f" % [warm - cold, hot - cold])
	var cantrip: SkillDefinition = SkillDatabase.skills["fire_burst"]
	var stoked: float = combat.progression_damage_bonus(prometheus, foe, cantrip)
	prometheus["spells_cast"] = 0
	ok(is_equal_approx(stoked, combat.progression_damage_bonus(prometheus, foe, cantrip)),
		"a cantrip takes no gate, and is not stoked")

	# Contests.
	ok(combat.contest_bonus_of(prometheus, foe) == 20, "Prometheus +10 in a contest, +10 more on the afflicted (Contest Insight I and II)")

	# Gates.
	var spare: int = prometheus.get("deepest_castings_added", 0)
	var deepest := 0
	for gate in range(prometheus.max_spell_slots.size() - 1, 0, -1):
		if prometheus.max_spell_slots[gate] > 0:
			deepest = gate
			break
	ok(spare == 1 and prometheus.max_spell_slots[deepest] == Stats.gates_for_level(64)[deepest] + 1,
		"Prometheus has one more casting through his deepest gate (Elemental Mastery)", "%s" % [prometheus.max_spell_slots])
	ok(alithia.get("deepest_castings_added", 0) == 2, "Alithia two (Reserved Power I and II)")

	# Mercy.
	alithia.status_effects.clear()
	enfina.status_effects.clear()
	enfina.hp = 10
	combat.put_condition(enfina, load("res://data/conditions/poisoned.tres"), 3, "test", true)
	var heal: SkillDefinition = SkillDatabase.skills["heal"]
	combat.apply_effect(alithia, enfina, heal.effects[0], heal, false)
	ok(not combat.conditions_of(enfina).any(func(c): return c.display_name == "Poisoned"), "her heal lifts the poison (Mercy II)")
	ok(combat.conditions_of(enfina).any(func(c): return c.display_name == "Sheltered") and combat.damage_reduction_of(enfina) > 0.45,
		"and leaves her sheltered (Mercy III)", "%.2f" % combat.damage_reduction_of(enfina))
	enfina.hp = 10
	var restoration: SkillDefinition = SkillDatabase.skills["restoration"]
	combat.apply_effect(alithia, enfina, restoration.effects[0], restoration, false)
	ok(enfina.hp >= 10 + combat.get_effective_stat(enfina, "max_hp") / 2, "Restoration: half her health back, and more", "%d" % enfina.hp)

	# Aura II mending.
	enfina.hp = 10
	combat.put_condition(enfina, load("res://data/conditions/soothed.tres"), 2, "test", true)
	combat._mend_at_turn_start(enfina)
	ok(enfina.hp == 10 + roundi(combat.get_effective_stat(enfina, "max_hp") * 0.05), "soothed, she mends a twentieth as her turn starts", "%d" % enfina.hp)

	# Finisher is gone (docs/handoff_0.1/finisher_removal_momentum_synergy.md).
	ok(not SkillDatabase.skills.has("finisher") and not CombatantDatabase.combatants.values().any(func(who): return who.skills.has("finisher")),
		"no Finisher, in anybody's kit or anywhere else")

	# Cover.
	var region: Rect2i = combat.controller._astargrid.region
	var covered := Vector2i(-99999, -99999)
	var open := Vector2i(-99999, -99999)
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var tile := Vector2i(x, y)
			if combat.controller.is_tile_blocking(tile, 0) or not combat.get_combatant_at(tile).is_empty():
				continue
			if covered.x == -99999 and combat.in_cover(cyrus, tile):
				covered = tile
			if open.x == -99999 and not combat.in_cover(cyrus, tile):
				open = tile
	ok(covered.x != -99999 and open.x != -99999, "somewhere in cover, and somewhere not", "%s %s" % [covered, open])
	var was_at: Vector2i = cyrus.position
	cyrus.position = covered
	cyrus["started_in_cover"] = true
	var in_cover_moves: int = combat.get_effective_stat(cyrus, "movement")
	cyrus["started_in_cover"] = false
	ok(in_cover_moves == combat.get_effective_stat(cyrus, "movement") + 2, "starting in cover, Cyrus has two more tiles (Cat Burglar I)")
	ok(combat.damage_reduction_of(cyrus) >= 0.05 + 0.1 - 0.001, "and takes a twentieth less there (Agile I)", "%.2f" % combat.damage_reduction_of(cyrus))
	cyrus.position = was_at
	ok(combat.refusal_for(cyrus, SkillDatabase.skills["cover_leap"], open) != "", "Cover Leap will not land in the open")

	game.queue_free()
	await settle(2)
