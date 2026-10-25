extends Node
## Cyrus's shots and loads against docs/cyrus_damage_adjustments.csv: every
## multiplier, condition dial and duration the sheet gives, read off the sheet;
## Warning Shot's and Frost Round's slows lasting the turns they say; Frost Round
## meeting Ice resistance, not Water; Corrosive Round's worse armour lasting
## exactly as long as Corroded, refreshing rather than stacking and going with
## it; and Combined Load firing two loads as one shot - the first's hit, both
## loads' conditions, one action, and no multiplier of its own on top.

var LOG_PATH := HarnessLog.path_for("ammo")
const WATCHER := "res://data/encounters/encounter_03_watcher.tres"
const SHEET := "res://docs/cyrus_damage_adjustments.csv"
## The sheet's names, as the game keys them.
const KEYS := {"Gun": "gun", "Poison Dart": "poison_dart", "Burning Shot": "burning_shot",
	"Burning Shot rank: Strong Burn": "burning_shot", "Venom Fan": "venom_fan", "Warning Shot": "warning_shot",
	"Frost Round": "frost_round", "Corrosive Round": "corrosive_round", "Combined Load": "combined_load"}

var _log: FileAccess = null
var _fail = 0
var game: Node = null
var combat = null
var heard := []


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
	get_tree().create_timer(300.0, true, false, true).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	var booted = get_tree().current_scene
	if booted != null:
		booted.queue_free()
		await settle()
	await open_fight()
	the_sheet()
	the_trial()
	the_rules()
	slows()
	frost_and_ice()
	corrosion()
	await combined_load()
	await catalyst_rule()
	if game != null and is_instance_valid(game):
		game.queue_free()
		await settle(3)
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func settle(frames: int = 3):
	for i in frames:
		await get_tree().process_frame


## The watcher fight, the party at 64 and Cyrus a Saboteur.
func open_fight():
	Campaign.reset()
	Campaign.set_party(["cyrus", "enfina", "prometheus", "alithia"], 64)
	Campaign.choose_subclass("cyrus", "saboteur")
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
	combat.reaction_prompt = null
	combat.update_information.connect(func(text): heard.append(text))
	for comb in combat.combatants:
		comb.max_hp = 9999
		comb.hp = 9999


func who(key: String) -> Dictionary:
	for comb in combat.combatants:
		if comb.get("combatant_key", "") == key and not comb.get("illusion", false):
			return comb
	return {}


## A fresh enemy to shoot: the first of the other side, cleared of everything.
func a_foe() -> Dictionary:
	for comb in combat.combatants:
		if comb.side == 1 and comb.alive and not comb.has("object"):
			comb.status_effects.clear()
			return comb
	return {}


func has_condition(comb: Dictionary, name: String) -> bool:
	return combat.conditions_of(comb).any(func(c): return c.resource_path.get_file().get_basename() == name)


func entries_of(comb: Dictionary, name: String) -> Array:
	return comb.status_effects.filter(func(e): return e.get("stat", "") == "condition" and e.get("condition") != null \
		and e.condition.resource_path.get_file().get_basename() == name)


## Cyrus at `level`, on the Saboteur's path, to read a skill's numbers through.
func cyrus_at(level: int) -> Dictionary:
	var comb: Dictionary = combat.create_combatant(CombatantDatabase.combatants.cyrus, "cyrus", "", null, level, "saboteur")
	comb["side"] = 0
	return comb


func the_sheet():
	log_line("======== the numbers are the sheet's ========")
	var file := FileAccess.open(SHEET, FileAccess.READ)
	ok(file != null, "docs/cyrus_damage_adjustments.csv is there")
	if file == null:
		return
	var header := file.get_csv_line()
	var column := {}
	for i in header.size():
		column[header[i]] = i
	while not file.eof_reached():
		var row := file.get_csv_line()
		# Some rows leave out a note at the end; the numbers are all in the first nine.
		if row.size() <= column.DoTDurationTurns:
			continue
		var name: String = row[column.Skill]
		if not KEYS.has(name):
			ok(false, "the sheet's %s is a skill of Cyrus's" % name)
			continue
		var skill: SkillDefinition = SkillDatabase.skills.get(KEYS[name])
		var level := int(row[column.Level])
		var comb := cyrus_at(maxi(level, 1))
		var wanted: String = row[column.ProposedDirectMultiplier]
		if wanted == "":
			wanted = row[column.CurrentDirectMultiplier]
		ok(is_equal_approx(Combat.modifier_of(comb, skill), float(wanted)), "%s hits x%s" % [name, wanted],
			"x%.2f" % Combat.modifier_of(comb, skill))
		var dot: String = row[column.ProposedDoTModifier]
		if dot != "":
			var lingering: EffectDefinition = null
			for effect in skill.effects:
				if effect.type == EffectDefinition.EffectType.CONDITION and effect.condition_dot_modifier > 0.0:
					lingering = effect
			ok(lingering != null and is_equal_approx(Combat.dot_strength_of(comb, skill, lingering), float(dot)),
				"  and leaves %s a turn" % dot, "%.2f" % (Combat.dot_strength_of(comb, skill, lingering) if lingering != null else -1.0))
			var turns := int(row[column.DoTDurationTurns])
			ok(lingering != null and Combat.rank_duration(comb, skill) in [0, turns] and lingering.condition_duration == turns,
				"  for %d turns, as written" % turns, "%d" % (lingering.condition_duration if lingering != null else -1))
	log_line("")


## docs/handoff_0.1/cyrus_damage_adjustments.csv, the approved trial: each skill's
## hit modifier at its rank level is the trial value - and nothing else of the
## skill moved: its conditions' dials and turns are what the first sheet says.
func the_trial():
	log_line("======== the approved trial (handoff 0.1) ========")
	var file := FileAccess.open("res://docs/handoff_0.1/cyrus_damage_adjustments.csv", FileAccess.READ)
	ok(file != null, "docs/handoff_0.1/cyrus_damage_adjustments.csv is there")
	if file == null:
		return
	var header := file.get_csv_line()
	var column := {}
	for i in header.size():
		column[header[i]] = i
	var rows := 0
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() <= column.TrialValue:
			continue
		# The sheet writes keys without underscores (poisondart).
		var key := ""
		for each in SkillDatabase.skills:
			if String(each).replace("_", "") == row[column.SkillID]:
				key = each
		var skill: SkillDefinition = SkillDatabase.skills.get(key)
		ok(skill != null, "%s is a skill" % row[column.SkillID], key)
		if skill == null:
			continue
		rows += 1
		var level := int(row[column.RankLevel])
		ok(is_equal_approx(Combat.modifier_of(cyrus_at(level), skill), float(row[column.TrialValue])),
			"%s at %d hits x%s (was %s)" % [skill.name, level, row[column.TrialValue], row[column.SnapshotOldValue]],
			"x%.2f" % Combat.modifier_of(cyrus_at(level), skill))
		var carriers := []
		for who in CombatantDatabase.combatants:
			if who != "cyrus" and CombatantDatabase.combatants[who].skills.has(key):
				carriers.append(who)
		ok(carriers.is_empty(), "  and nobody but Cyrus carries it", "%s" % [carriers])
	ok(rows == 4, "the four trial edits, no more", "%d" % rows)
	log_line("")


## Whether `skill` leaves something on whoever it hits: a condition, or a
## change to a stat.
func leaves_something(skill: SkillDefinition) -> bool:
	return skill.effects.any(func(effect): return effect != null and not effect.applies_to_caster and effect.type in [
		EffectDefinition.EffectType.CONDITION, EffectDefinition.EffectType.STAT_MODIFIER, EffectDefinition.EffectType.STAT_MULTIPLIER])


## The designer's rules for Cyrus's shots (working instructions, 2026-10-24): the
## Gun is the baseline for an immediate single-target hit; ammunition that
## leaves a condition hits less hard than the Gun; and a condition skill with an
## area hits each target less hard than his single-target condition ammunition.
func the_rules():
	log_line("======== the Gun is the baseline ========")
	var gun: SkillDefinition = SkillDatabase.skills.gun
	for level in [8, 16, 24, 32, 41, 54, 64]:
		var comb := cyrus_at(level)
		var baseline: float = Combat.modifier_of(comb, gun)
		var ammo_lowest := 99.0
		for key in comb.skill_list:
			var skill: SkillDefinition = SkillDatabase.skills.get(key)
			if skill == null or not skill.is_ammo or not skill.deals_damage or not combat.meets_level_for(comb, skill) or not leaves_something(skill):
				continue
			var mod: float = Combat.modifier_of(comb, skill)
			ammo_lowest = minf(ammo_lowest, mod)
			ok(mod < baseline, "  level %d: %s x%.2f, under the Gun's x%.2f" % [level, skill.name, mod, baseline])
		for key in comb.skill_list:
			var skill: SkillDefinition = SkillDatabase.skills.get(key)
			if skill == null or skill.aoe_radius <= 0 or not skill.deals_damage or not combat.meets_level_for(comb, skill) or not leaves_something(skill):
				continue
			var mod: float = Combat.modifier_of(comb, skill)
			ok(ammo_lowest == 99.0 or mod < ammo_lowest, "  level %d: %s x%.2f a target, under his single-target condition ammunition's lowest x%.2f" % [level, skill.name, mod, ammo_lowest])
	# OPEN against these rules (docs/balance_register.csv), noted rather than failed.
	var exposing: SkillDefinition = SkillDatabase.skills.exposing_shot
	var fan: SkillDefinition = SkillDatabase.skills.venom_fan
	log_line("  NOTE  Exposing Shot (single target, a debuff, not ammunition) x%.2f; Venom Fan (area) x%.2f" % [exposing.ability_modifier, fan.ability_modifier])
	for key in ["tripwire", "minefield"]:
		var trap: SkillDefinition = SkillDatabase.skills[key]
		log_line("  NOTE  %s bursts for x%.2f on everybody within %d, and holds them" % [trap.name, trap.effects[0].trap_burst_modifier, trap.effects[0].trap_burst_radius])
	log_line("")


## How many of `foe`'s turns `stat` stays down after `skill` lands on it, and how
## many the tooltip says.
func turns_down(foe: Dictionary, skill: SkillDefinition, stat: String) -> Array:
	var cyrus := who("cyrus")
	foe.status_effects.clear()
	var plain: int = combat.get_effective_stat(foe, stat)
	for effect in skill.effects:
		if effect.type == EffectDefinition.EffectType.STAT_MODIFIER:
			combat.apply_effect(cyrus, foe, effect, skill, false)
	var said: int = Combat.turns_stored(skill.effects[0].duration, skill.effects[0].wears_off_at_start)
	var turns := 0
	for i in 10:
		combat.start_of_turn_effects(foe)
		if combat.get_effective_stat(foe, stat) >= plain:
			break
		turns += 1
		combat.end_of_turn_effects(foe)
	return [turns, said, plain]


func slows():
	log_line("======== Warning Shot and Frost Round slow for the turns they say ========")
	var foe := a_foe()
	var warning: SkillDefinition = SkillDatabase.skills.warning_shot
	var counted := turns_down(foe, warning, "movement")
	ok(counted[0] == warning.effects[0].duration and counted[0] == counted[1], "Warning Shot: -1 movement for 2 of their turns, as written, and as it says", "%d of their turns (written %d)" % [counted[0], warning.effects[0].duration])
	foe.status_effects.clear()
	combat.apply_effect(who("cyrus"), foe, warning.effects[0], warning, false)
	ok(combat.get_effective_stat(foe, "movement") == counted[2] - 1, "  one tile less", "%d -> %d" % [counted[2], combat.get_effective_stat(foe, "movement")])
	var frost: SkillDefinition = SkillDatabase.skills.frost_round
	counted = turns_down(foe, frost, "movement")
	ok(counted[0] == frost.effects[0].duration and counted[0] == counted[1], "Frost Round: -2 movement for 1 of their turns, as written, and as it says", "%d of their turns (written %d)" % [counted[0], frost.effects[0].duration])
	foe.status_effects.clear()
	log_line("")


func frost_and_ice():
	log_line("======== Frost Round is Ice: Ice resistance counts, Water's does not ========")
	var frost: SkillDefinition = SkillDatabase.skills.frost_round
	ok(frost.damage_type == Damage.Type.ICE, "Frost Round deals Ice")
	var foe := a_foe()
	var was: Dictionary = foe.resistances.duplicate()
	foe.resistances[Damage.Type.ICE] = 50
	foe.resistances[Damage.Type.WATER] = 0
	ok(combat.resisted_damage(foe, frost.damage_type, 100) == 50, "half from a target resisting Ice by half", "%d" % combat.resisted_damage(foe, frost.damage_type, 100))
	foe.resistances[Damage.Type.ICE] = 0
	foe.resistances[Damage.Type.WATER] = 50
	ok(combat.resisted_damage(foe, frost.damage_type, 100) == 100, "and all of it from one resisting only Water", "%d" % combat.resisted_damage(foe, frost.damage_type, 100))
	foe.resistances[Damage.Type.ICE] = -50
	ok(combat.resisted_damage(foe, frost.damage_type, 100) == 150, "half again from one weak to Ice", "%d" % combat.resisted_damage(foe, frost.damage_type, 100))
	foe.resistances = was
	log_line("")


func corrosion():
	log_line("======== Corrosive Round: a tenth less Defense while Corroded, and only then ========")
	var cyrus := who("cyrus")
	var round: SkillDefinition = SkillDatabase.skills.corrosive_round
	ok(round.effects.size() == 1 and round.effects[0].condition != null, "one effect: Corroded, nothing beside it")
	var foe := a_foe()
	var plain: int = combat.stat_of(foe, Stats.Type.DEFENSE)
	combat.apply_effect(cyrus, foe, round.effects[0], round, false)
	ok(has_condition(foe, "corroded"), "it lands Corroded")
	ok(combat.stat_of(foe, Stats.Type.DEFENSE) == roundi(plain * 0.9), "a tenth less Defense", "%d -> %d" % [plain, combat.stat_of(foe, Stats.Type.DEFENSE)])
	combat.apply_effect(cyrus, foe, round.effects[0], round, false)
	ok(entries_of(foe, "corroded").size() == 1 and combat.stat_of(foe, Stats.Type.DEFENSE) == roundi(plain * 0.9),
		"a second round refreshes it - one Corroded, still a tenth", "%d of it, %d Defense" % [entries_of(foe, "corroded").size(), combat.stat_of(foe, Stats.Type.DEFENSE)])
	var lasts: int = entries_of(foe, "corroded")[0].duration
	ok(lasts == 5 + combat.lingering_turns(cyrus), "Corroded lasts its 5 turns (the condition proposal of 2026-10-25), and DoT Master's one more",
		"%d (DoT Master adds %d)" % [lasts, combat.lingering_turns(cyrus)])
	var down := 0
	for i in 10:
		combat.start_of_turn_effects(foe)
		if not has_condition(foe, "corroded"):
			break
		ok(combat.stat_of(foe, Stats.Type.DEFENSE) == roundi(plain * 0.9), "  turn %d: Corroded, and a tenth down" % (i + 1))
		down += 1
		combat.end_of_turn_effects(foe)
	ok(combat.stat_of(foe, Stats.Type.DEFENSE) == plain, "gone with it, Defense is whole again", "%d" % combat.stat_of(foe, Stats.Type.DEFENSE))
	combat.apply_effect(cyrus, foe, round.effects[0], round, false)
	var cleanse: SkillDefinition = SkillDatabase.skills.cleanse
	combat.dispel_status_effects(foe, foe, cleanse.effects[0])
	ok(not has_condition(foe, "corroded") and combat.stat_of(foe, Stats.Type.DEFENSE) == plain, "cleansed of it, Defense is whole again too")
	var own_immunities: Array = foe.get("immune_to", []).duplicate()
	foe["immune_to"] = own_immunities + [Immunity.Kind.WEAKENED]
	combat.apply_effect(cyrus, foe, round.effects[0], round, false)
	ok(has_condition(foe, "corroded") and combat.stat_of(foe, Stats.Type.DEFENSE) == plain,
		"immune to being weakened, it burns but the armour holds", "%d of %d" % [combat.stat_of(foe, Stats.Type.DEFENSE), plain])
	foe["immune_to"] = own_immunities
	foe.status_effects.clear()
	log_line("")


func combined_load():
	log_line("======== Combined Load: two loads, one shot ========")
	var cyrus := who("cyrus")
	ok(cyrus.skill_list.has("combined_load") and cyrus.level >= 41, "Cyrus has Combined Load at 41 and up", "level %d" % cyrus.level)
	ok(SkillDefinition.combined("gun", "poison_dart") == "" and SkillDefinition.combined("poison_dart", "poison_dart") == "",
		"only two different loads combine - not the Gun, not one twice")
	var key := SkillDefinition.combined("burning_shot", "poison_dart")
	var both: SkillDefinition = SkillDatabase.skills.get(key)
	ok(both != null and both.name == "Burning Shot + Poison Dart", "Burning Shot + Poison Dart is one skill", key)
	if both == null:
		return
	var burning: SkillDefinition = SkillDatabase.skills.burning_shot
	var dart: SkillDefinition = SkillDatabase.skills.poison_dart
	ok(is_equal_approx(Combat.modifier_of(cyrus, both), Combat.modifier_of(cyrus, burning)) and both.damage_type == burning.damage_type,
		"the first load's hit: its multiplier (rank and all) and its element", "x%.2f %s" % [Combat.modifier_of(cyrus, both), Damage.type_name(both.damage_type)])
	ok(not is_equal_approx(Combat.modifier_of(cyrus, both), Combat.modifier_of(cyrus, burning) * SkillDatabase.skills.combined_load.ability_modifier) \
		or is_equal_approx(SkillDatabase.skills.combined_load.ability_modifier, 1.0),
		"and no multiplier of Combined Load's own on top", "Combined Load x%.2f" % SkillDatabase.skills.combined_load.ability_modifier)
	var reversed: SkillDefinition = SkillDatabase.skills.get(SkillDefinition.combined("poison_dart", "burning_shot"))
	ok(reversed != null and is_equal_approx(Combat.modifier_of(cyrus, reversed), Combat.modifier_of(cyrus, dart)),
		"loaded the other way round, the dart's hit", "x%.2f" % (Combat.modifier_of(cyrus, reversed) if reversed != null else -1.0))
	var foe := a_foe()
	ok(combat.skill_damage(cyrus, foe, both) == combat.skill_damage(cyrus, foe, burning),
		"as hard as Burning Shot alone", "%d vs %d" % [combat.skill_damage(cyrus, foe, both), combat.skill_damage(cyrus, foe, burning)])
	ok(both.max_range == mini(burning.max_range, dart.max_range) and both.min_range == maxi(burning.min_range, dart.min_range),
		"reaching only as far as both do", "%d-%d" % [both.min_range, both.max_range])
	# Fired in a turn: one action, both conditions.
	combat.current_combatant = combat.combatants.find(cyrus)
	combat.controller.set_controlled_combatant(cyrus)
	combat.controller.player_turn = true
	combat.controller.action_locked = false
	cyrus.skill_used_this_turn = false
	cyrus.secondary_used_this_turn = false
	var near := Vector2i(-1, -1)
	var region: Rect2i = combat.controller._astargrid.region
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var tile := Vector2i(x, y)
			var gap: int = combat.get_position_distance(tile, foe.position)
			if near == Vector2i(-1, -1) and gap >= both.min_range + 1 and gap <= mini(both.max_range, 6) \
					and combat.controller.is_in_bounds(tile) and combat.controller.is_on_map(tile) \
					and combat.get_combatant_at(tile).is_empty() and not combat.controller.is_tile_blocking(tile, 0) \
					and combat.has_line_of_sight(tile, foe.position, 0):
				near = tile
	ok(near != Vector2i(-1, -1), "a tile in reach of it, in sight", "%s" % near)
	if near != Vector2i(-1, -1):
		var from: Vector2i = cyrus.position
		cyrus.position = near
		combat.controller.reposition_combatant(from, near)
	var hp_before: int = foe.hp
	await combat.use_skill(key, cyrus, foe.position, false)
	await settle(4)
	ok(has_condition(foe, "burn") and has_condition(foe, "poisoned"), "fired, it leaves Burn and Poisoned both",
		"%s" % [combat.conditions_of(foe).map(func(c): return c.display_name)])
	ok(foe.hp < hp_before, "and hits", "%d -> %d" % [hp_before, foe.hp])
	ok(cyrus.skill_used_this_turn and not cyrus.secondary_used_this_turn, "for one main action")
	log_line("")


## Catalyst's rule, exactly as documented (approved as it is, 2026-10-24): for
## every enemy, wherever it stands, each lingering condition Cyrus put on it goes
## off as one hit of one tick's damage (after its Defense) x the ticks it had
## left x Catalyst Times, rounded, resisted once by that condition's own type;
## then it starts again at the full length it landed with. Nobody else's
## conditions, and nothing that does not linger, are touched.
func catalyst_rule():
	log_line("======== Catalyst, exactly ========")
	var cyrus := who("cyrus")
	var alithia := who("alithia")
	var foes: Array = combat.combatants.filter(func(c): return c.side == 1 and c.alive and not c.has("object"))
	ok(foes.size() >= 2, "two enemies to try it on", "%d" % foes.size())
	if foes.size() < 2:
		return
	var near: Dictionary = foes[0]
	var far: Dictionary = foes[foes.size() - 1]
	var burning: SkillDefinition = SkillDatabase.skills.burning_shot
	var dart: SkillDefinition = SkillDatabase.skills.poison_dart
	var river: SkillDefinition = SkillDatabase.skills.river_flow
	var catalyst: SkillDefinition = SkillDatabase.skills.catalyst
	var times: float = catalyst.effects[0].catalyst_times
	var expected := {}
	for foe in [near, far]:
		foe.status_effects.clear()
		foe.hp = 9999
		combat.apply_effect(cyrus, foe, burning.effects[0], burning, false)
		combat.apply_effect(cyrus, foe, dart.effects[0], dart, false)
		combat.apply_effect(alithia, foe, river.effects[0], river, false)
		var total := 0
		for entry in foe.status_effects:
			var condition = entry.get("condition") if entry.get("stat", "") == "condition" else null
			if condition == null:
				continue
			if condition.resource_path.get_file() == "burn.tres":
				entry.duration = 2
			elif condition.resource_path.get_file() == "poisoned.tres":
				entry.duration = 3
			if entry.get("source_id", -2) != cyrus.id:
				continue
			var left: int = combat.ticks_left(foe, entry)
			var one_tick: int = combat.dot_tick(foe, entry.dot_base, 0, 0)
			total += combat.resisted_damage(foe, condition.dot_type, roundi(one_tick * left * times))
		expected[foe.id] = total
	near.resistances[Damage.Type.FIRE] = 50
	expected[near.id] = 0
	for entry in near.status_effects:
		var condition = entry.get("condition") if entry.get("stat", "") == "condition" else null
		if condition != null and entry.get("source_id", -2) == cyrus.id:
			var one_tick: int = combat.dot_tick(near, entry.dot_base, 0, 0)
			expected[near.id] += combat.resisted_damage(near, condition.dot_type, roundi(one_tick * combat.ticks_left(near, entry) * times))
	var frozen_before := []
	for foe in [near, far]:
		for entry in foe.status_effects:
			if entry.get("condition") != null and entry.get("source_id", -2) == alithia.id:
				frozen_before.append(entry.duration)
	var near_hp: int = near.hp
	var far_hp: int = far.hp
	combat.current_combatant = combat.combatants.find(cyrus)
	combat.controller.set_controlled_combatant(cyrus)
	combat.controller.player_turn = true
	combat.controller.action_locked = false
	cyrus.skill_used_this_turn = false
	cyrus.erase("uses")
	await combat.use_skill("catalyst", cyrus, cyrus.position, false)
	await settle(4)
	ok(near_hp - near.hp == expected[near.id], "beside him: one tick x ticks left x %s per condition, each resisted once - Burn at half by Fire resistance" % times,
		"%d, expected %d" % [near_hp - near.hp, expected[near.id]])
	ok(far_hp - far.hp == expected[far.id], "and the enemy furthest off, though it was not aimed at", "%d, expected %d" % [far_hp - far.hp, expected[far.id]])
	var restarted := true
	var frozen_after := []
	for foe in [near, far]:
		for entry in foe.status_effects:
			if entry.get("condition") == null:
				continue
			if entry.get("source_id", -2) == cyrus.id:
				restarted = restarted and entry.duration == entry.full_duration
			elif entry.get("source_id", -2) == alithia.id:
				frozen_after.append(entry.duration)
	ok(restarted, "each of his starts again at the full length it landed with")
	ok(not frozen_before.is_empty() and frozen_after == frozen_before, "Alithia's Frozen on them goes nowhere and keeps its turns", "%s -> %s" % [frozen_before, frozen_after])
	near.resistances[Damage.Type.FIRE] = 0
	for foe in [near, far]:
		foe.status_effects.clear()
	log_line("")
