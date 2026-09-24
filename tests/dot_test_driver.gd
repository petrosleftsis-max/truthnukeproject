extends Node
## Damage over time on the same formula as a direct hit: scaled off the
## caster's stat, tunable per effect, and typed per condition.

var LOG_PATH := HarnessLog.path_for("dot")

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
	get_tree().create_timer(150.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


## A tick strong enough to kill leaves every later measurement at zero, because
## a dead combatant is skipped - and topping them up past their maximum is no
## good either, since process_status_effects clamps back down and the clamp is
## then what gets measured. Give them a ceiling nothing here can reach.
const ROOMY_HP = 9999

func revive(comb):
	comb.alive = true
	comb.max_hp = ROOMY_HP
	comb.hp = ROOMY_HP


func run_test():
	log_line("======== the five damaging conditions have the right type ========")
	var wanted = {
		"burn": Damage.Type.FIRE,
		"windswept": Damage.Type.WIND,
		"crystallised": Damage.Type.EARTH,
		"poisoned": Damage.Type.POISON,
		"frozen": Damage.Type.WATER,
	}
	for name in wanted:
		var definition: ConditionDefinition = load("res://conditions/%s.tres" % name)
		ok(definition.dot_type == wanted[name], "%s ticks %s" % [name, Damage.type_name(wanted[name])],
			"is %s" % Damage.type_name(definition.dot_type))
		ok(definition.dot_modifier > 0.0, "  and scales off the caster", "x%s" % definition.dot_modifier)
	log_line("")

	Campaign.reset()
	Campaign.current_encounter = load("res://encounters/encounter_01_ambush.tres")
	var game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	var combat = game.get_node("VisualCombat")
	combat.finish_deployment()
	await get_tree().process_frame

	var acting = combat.get_current_combatant()
	var target = null
	for comb in combat.combatants:
		if comb != acting and comb.alive:
			target = comb
			break
	target.resistances = {}

	var dart: SkillDefinition = SkillDatabase.skills["poison_dart"]
	# A plain DAMAGE_OVER_TIME effect, built here rather than borrowed from a
	# skill. It used to be Poison Dart's, until Poison Dart was corrected to
	# inflict the Poisoned condition it had been carrying a dead link to - and
	# no skill in the game is a nameless lingering wound any more. The machinery
	# still exists and is still worth proving, so the test brings its own.
	var dot_effect := EffectDefinition.new()
	dot_effect.type = EffectDefinition.EffectType.DAMAGE_OVER_TIME
	dot_effect.display_name = "Poisoning"
	dot_effect.damage_type = Damage.Type.POISON
	dot_effect.damage_modifier = 0.3
	dot_effect.min_amount = 2
	dot_effect.max_amount = 4
	dot_effect.duration = 3
	ok(dot_effect.damage_modifier > 0.0, "a lingering wound has its own modifier, apart from the skill's",
		"x%s vs the skill's x%s" % [dot_effect.damage_modifier, dart.ability_modifier])

	log_line("======== a tick is worked out from the caster's stat ========")
	acting.stats[Stats.stat_key(dart.scaling_stat)] = 10
	target.stats["defense"] = 10
	revive(target)
	target.status_effects.clear()
	combat.apply_effect(acting, target, dot_effect, dart, false)
	var hp = target.hp
	combat.process_status_effects(target)
	var weak_tick = hp - target.hp
	ok(weak_tick > 0, "it does something", "%d" % weak_tick)

	# Same effect, stronger caster.
	acting.stats[Stats.stat_key(dart.scaling_stat)] = 90
	revive(target)
	target.status_effects.clear()
	combat.apply_effect(acting, target, dot_effect, dart, false)
	hp = target.hp
	combat.process_status_effects(target)
	var strong_tick = hp - target.hp
	ok(strong_tick > weak_tick, "a stronger caster ticks harder", "%d -> %d" % [weak_tick, strong_tick])
	log_line("")

	log_line("======== the caster's side is locked in when it lands ========")
	# The poisoner weakening later must not weaken the poison already in them.
	acting.stats[Stats.stat_key(dart.scaling_stat)] = 90
	revive(target)
	target.status_effects.clear()
	combat.apply_effect(acting, target, dot_effect, dart, false)
	acting.stats[Stats.stat_key(dart.scaling_stat)] = 1
	hp = target.hp
	combat.process_status_effects(target)
	var after_weakening = hp - target.hp
	ok(after_weakening == strong_tick, "still ticks at the strength it was applied with",
		"%d vs %d" % [after_weakening, strong_tick])
	log_line("")

	log_line("======== the target's side is read live ========")
	acting.stats[Stats.stat_key(dart.scaling_stat)] = 90
	target.stats["defense"] = 10
	revive(target)
	target.status_effects.clear()
	combat.apply_effect(acting, target, dot_effect, dart, false)
	target.stats["defense"] = 90
	hp = target.hp
	combat.process_status_effects(target)
	var defended_tick = hp - target.hp
	ok(defended_tick < strong_tick, "shoring up mid-poison does help",
		"%d vs %d" % [defended_tick, strong_tick])
	log_line("")

	log_line("======== resistance still applies on top ========")
	acting.stats[Stats.stat_key(dart.scaling_stat)] = 90
	target.stats["defense"] = 10
	target.resistances = {Damage.Type.POISON: 50}
	revive(target)
	target.status_effects.clear()
	combat.apply_effect(acting, target, dot_effect, dart, false)
	hp = target.hp
	combat.process_status_effects(target)
	var resisted_tick = hp - target.hp
	ok(resisted_tick < strong_tick, "half poison resistance halves the tick",
		"%d vs %d" % [resisted_tick, strong_tick])
	target.resistances = {}
	log_line("")

	log_line("======== conditions tick the same way ========")
	var burn: ConditionDefinition = load("res://conditions/burn.tres")
	var burn_effect := EffectDefinition.new()
	burn_effect.type = EffectDefinition.EffectType.CONDITION
	burn_effect.condition = burn
	var fireball: SkillDefinition = SkillDatabase.skills["fireball"]

	acting.stats[Stats.stat_key(fireball.scaling_stat)] = 10
	target.stats["defense"] = 10
	revive(target)
	target.status_effects.clear()
	combat.apply_effect(acting, target, burn_effect, fireball, false)
	hp = target.hp
	combat.process_status_effects(target)
	var weak_burn = hp - target.hp
	acting.stats[Stats.stat_key(fireball.scaling_stat)] = 90
	revive(target)
	target.status_effects.clear()
	combat.apply_effect(acting, target, burn_effect, fireball, false)
	hp = target.hp
	combat.process_status_effects(target)
	var strong_burn = hp - target.hp
	ok(strong_burn > weak_burn, "a Burn from a stronger caster burns harder",
		"%d -> %d" % [weak_burn, strong_burn])
	ok(weak_burn >= 3, "and at stat 10 it still lands about what it used to", "%d" % weak_burn)
	log_line("")

	log_line("======== a condition with no skill behind it still works ========")
	# Applied by hand, as the condition tests do - there is no caster to scale
	# off, so it has to fall back to its own flat range.
	revive(target)
	target.status_effects.clear()
	target.status_effects.append({
		"stat": "condition", "condition": burn,
		"duration": burn.duration, "source_name": "test"
	})
	hp = target.hp
	combat.process_status_effects(target)
	var flat_burn = hp - target.hp
	ok(flat_burn >= burn.dot_min and flat_burn <= burn.dot_max, "falls back to its flat range",
		"%d, range %d-%d" % [flat_burn, burn.dot_min, burn.dot_max])
	log_line("")

	log_line("======== a bomb is a bomb whoever throws it ========")
	# The claim survived a change in how it is kept. An item used to answer this
	# by not scaling at all, rolling the flat range written on the condition;
	# now it scales like everything else, off a base of its own rather than off
	# the thrower. Either way the bottle is the same bottle in any hand - which
	# is what to check, rather than the mechanism of the month.
	var bottle: ItemDefinition = ItemDatabase.items["burn_bottle"]
	ok(bottle != null, "there is an item that inflicts a condition")
	ok(is_equal_approx(combat.power_behind(acting, bottle), float(bottle.item_power)),
		"an item is worth its own power, not its thrower's stat",
		"%.0f behind it, %d written on it"
			% [combat.power_behind(acting, bottle), bottle.item_power])

	# Thrown by a weakling and thrown by a champion, the same bottle.
	var thrown := []
	for stat_value in [10, 90]:
		acting.stats[Stats.stat_key(bottle.scaling_stat)] = stat_value
		var rolls := []
		for attempt in 12:
			revive(target)
			target.status_effects.clear()
			combat.apply_effect(acting, target, bottle.all_effects()[0], bottle, false)
			hp = target.hp
			combat.process_status_effects(target)
			rolls.append(hp - target.hp)
		thrown.append(rolls)
	# Every throw the same, whoever threw it - which is the whole claim, and is
	# now a fixed number rather than a range, since nothing about it rolls.
	var every_roll := {}
	for rolls in thrown:
		for roll in rolls:
			every_roll[roll] = true
	ok(every_roll.size() == 1, "and every burn it leaves is the same size",
		"saw %s" % [every_roll.keys()])
	var weak_throw = 0
	var strong_throw = 0
	for roll in thrown[0]:
		weak_throw += roll
	for roll in thrown[1]:
		strong_throw += roll
	ok(weak_throw == strong_throw,
		"and a strong thrower's bottle burns exactly as a weak one's",
		"%d total at stat 10, %d at stat 90 over 12 throws" % [weak_throw, strong_throw])

	# Which is the opposite of what the same condition does off a spell.
	ok(strong_burn > weak_burn,
		"while the spell version still scales, as before",
		"%d -> %d" % [weak_burn, strong_burn])
	log_line("")

	log_line("======== the glossary says how hard it hits, in words ========")
	for key in ["burn", "poisoned", "crystallised", "frozen", "windswept"]:
		var cond: ConditionDefinition = load("res://conditions/%s.tres" % key)
		ok(cond.describe_dot() != "", "%s reads as damage over time" % key, cond.describe_dot())
	for key in ["blind", "fear", "stunned"]:
		var cond: ConditionDefinition = load("res://conditions/%s.tres" % key)
		ok(cond.describe_dot() == "", "%s says nothing about damage" % key, cond.describe_dot())
	# The book must not print a number, because the number depends on who
	# inflicted it - which was the bug this replaced.
	var burn_strength = load("res://conditions/burn.tres").describe_dot()
	ok(burn_strength == "Powerful Fire Damage Over Time", "Burn is powerful and burns", burn_strength)
	for pair in [["poisoned", "Strong Poison Damage Over Time"],
		["crystallised", "Weak Earth Damage Over Time"],
		["frozen", "Weak Water Damage Over Time"],
		["windswept", "Medium Wind Damage Over Time"]]:
		var said = load("res://conditions/%s.tres" % pair[0]).describe_dot()
		ok(said == pair[1], "%s reads right" % pair[0], said)
	# The element is named as the condition holds it rather than as a word
	# written here, so retyping a condition changes the book with it.
	for key in ["burn", "poisoned", "crystallised", "frozen", "windswept"]:
		var cond: ConditionDefinition = load("res://conditions/%s.tres" % key)
		ok(cond.describe_dot().contains(Damage.type_name(cond.dot_type)),
			"%s names its own element" % key, cond.describe_dot())
	log_line("")

	log_line("======== the tooltip reads like the direct damage line ========")
	var ui = game.get_node("CanvasLayer/UI")
	var text = ui.describe_effect(dot_effect, dart)
	# The number it will take rather than the rule behind it, per turn and for
	# how long - which is the decision the player is actually making.
	ok(text.contains("a turn"), "says what it costs per turn", text)
	ok(text.contains("turn(s)"), "and how long it keeps costing it", text)
	var has_number = false
	for part in text.split(" "):
		if part.is_valid_int() or part.contains("-"):
			has_number = true
	ok(has_number, "as a number", text)
	log_line("")

	log_line("======== a condition says what it costs, not just how bad it is ========")
	# The condition describes itself as "a strong DOT", which ranks it against
	# the others but says nothing about what it takes off you here. The number
	# goes beside it, worked out from whoever is holding the skill.
	var shot: SkillDefinition = SkillDatabase.skills["burning_shot"]
	var preview = ui.build_skill_tooltip(shot, acting)
	ok(preview.contains("Inflicts Burn"), "the preview names the condition", preview)
	ok(preview.contains("damage a turn"),
		"and says what a tick of it costs", preview)
	# Specifically a figure, and specifically inside the brackets after the
	# condition's own words - which is the thing that was missing.
	# The condition's own line, and the LAST bracket on it - "turn(s)" earlier in
	# the same line is a bracket too, and taking the first one finds that.
	var bracketed = ""
	for line in preview.split("
"):
		if not line.contains("Inflicts Burn"):
			continue
		var open_at = line.rfind("(")
		if open_at != -1 and line.find(")", open_at) != -1:
			bracketed = line.substr(open_at + 1, line.find(")", open_at) - open_at - 1)
	var figure = false
	for part in bracketed.split(" "):
		if part.is_valid_int() or (part.contains("-") and part.split("-")[0].is_valid_int()):
			figure = true
	ok(figure, "as a number in brackets", "'%s'" % bracketed)
	ok(bracketed.contains(Damage.type_name(burn.dot_type).to_lower()),
		"of the element the condition burns with", "'%s'" % bracketed)

	# A stronger caster previews a worse burn, the same way the damage line does.
	var strong = combat.create_combatant(CombatantDatabase.combatants["cyrus"], "cyrus")
	strong.stats[Stats.stat_key(shot.scaling_stat)] = 90
	acting.stats[Stats.stat_key(shot.scaling_stat)] = 10
	var weak_preview = ui.build_skill_tooltip(shot, acting)
	var strong_preview = ui.build_skill_tooltip(shot, strong)
	ok(weak_preview != strong_preview,
		"and it is the caster's number, not the condition's",
		"weak: %s | strong: %s" % [weak_preview.split("
")[-1], strong_preview.split("
")[-1]])

	# A bottle previews one number rather than a range, because nothing about it
	# rolls - and the same number in any hand, which a skill's preview is not.
	# `bottle` is the same Burn Bottle the item section above already found.
	var bottle_preview = ui.build_skill_tooltip(bottle, acting)
	var bottle_tick = combat.dot_base_damage(acting, bottle, burn.dot_modifier)
	ok(bottle_preview.contains("%d" % roundi(bottle_tick)),
		"while a bottle previews its own number",
		"wanted %d, said: %s" % [roundi(bottle_tick), bottle_preview.split("Inflicts")[-1]])
	acting.stats[Stats.stat_key(bottle.scaling_stat)] = 90
	ok(ui.build_skill_tooltip(bottle, acting) == bottle_preview,
		"and previews the same whoever is holding it")
	log_line("")

	log_line("======== one skill's version of a condition can burn harder ========")
	# The same named Burn, inflicted by two skills at different strengths - so
	# a searing bolt and a fire you walked through need not hurt the same, and
	# neither needs a second near-identical ConditionDefinition to say so.
	var blank := EffectDefinition.new()
	blank.type = EffectDefinition.EffectType.CONDITION
	blank.condition = burn
	ok("condition_dot_modifier" in blank, "an effect has a strength of its own to set")
	ok(blank.condition_dot_strength() == burn.dot_modifier,
		"unset, it burns exactly as the condition says",
		"%.2f" % blank.condition_dot_strength())
	blank.condition_dot_modifier = burn.dot_modifier * 2.0
	ok(is_equal_approx(blank.condition_dot_strength(), burn.dot_modifier * 2.0),
		"set, its own figure wins", "%.2f" % blank.condition_dot_strength())

	# And it is the number the battle actually uses, not just a field.
	var gentle := EffectDefinition.new()
	gentle.type = EffectDefinition.EffectType.CONDITION
	gentle.condition = burn
	gentle.condition_dot_modifier = maxf(burn.dot_modifier * 0.25, 0.05)
	acting.stats[Stats.stat_key(fireball.scaling_stat)] = 40
	var took := {}
	for pair in [["fierce", blank], ["gentle", gentle]]:
		revive(target)
		target.status_effects.clear()
		combat.apply_effect(acting, target, pair[1], fireball, false)
		hp = target.hp
		combat.process_status_effects(target)
		took[pair[0]] = hp - target.hp
	ok(took["fierce"] > took["gentle"],
		"the fiercer version really does burn harder",
		"%d against %d" % [took["fierce"], took["gentle"]])
	# Both are still Burn: one condition, one glossary entry, one name in the log.
	ok(burn.describe_dot() != "", "and both are still the same named condition",
		burn.describe_dot())

	# The preview has to agree with the battle, or the number is a lie.
	var fierce_said = ui.describe_effect(blank, fireball)
	var gentle_said = ui.describe_effect(gentle, fireball)
	ok(fierce_said != gentle_said,
		"and the preview quotes each skill's own version",
		"%s | %s" % [fierce_said, gentle_said])
	log_line("")

	log_line("======== nothing carries a condition it never inflicts ========")
	# Only a CONDITION effect reads the condition field. A DAMAGE_OVER_TIME one
	# ignores it and lays an anonymous tick instead, so filling both in looks
	# like a skill that inflicts a condition and is not one. Burner was exactly
	# that for three commits: a fire skill leaving a physical wound called
	# "Cursed", with a live link to burn.tres that nothing ever read.
	var dead_links := []
	for source in [SkillDatabase.skills, ItemDatabase.items]:
		for source_key in source:
			var carrier: SkillDefinition = source[source_key]
			if carrier == null:
				continue
			for carried in carrier.all_effects():
				if carried == null or carried.condition == null:
					continue
				if carried.type != EffectDefinition.EffectType.CONDITION:
					dead_links.append("%s holds %s on a %s effect" % [carrier.name,
						carried.condition.display_name,
						EffectDefinition.EffectType.keys()[carried.type]])
	ok(dead_links.is_empty(),
		"every condition attached to an effect is one that actually gets inflicted",
		"%s" % [dead_links])

	# Burner in particular, since it is the one that was wrong.
	var burner: SkillDefinition = SkillDatabase.skills.get("burner")
	if burner != null:
		var inflicted: ConditionDefinition = null
		for burner_effect in burner.all_effects():
			if burner_effect.type == EffectDefinition.EffectType.CONDITION:
				inflicted = burner_effect.condition
		ok(inflicted != null, "Burner inflicts a condition",
			inflicted.display_name if inflicted else "none")
		ok(inflicted != null and inflicted.dot_type == burner.damage_type,
			"and it burns with the element the skill itself deals",
			"%s vs %s" % [Damage.type_name(inflicted.dot_type) if inflicted else "-",
				Damage.type_name(burner.damage_type)])
	log_line("")

	log_line("======== a heavier weapon leaves a worse burn ========")
	# Every other damage figure in the game reads the caster's weapon base; a
	# tick did not, so a spawn handed a heavier weapon swung harder and burned
	# exactly as before. The encounters really do hand them out - 25 spawns
	# across two fights carry 9 or 12 rather than the default 6.
	var plain_spawn := SpawnDefinition.new()
	plain_spawn.combatant_key = "cyrus"
	plain_spawn.weapon_base = Stats.WEAPON_BASE
	var armed_spawn := SpawnDefinition.new()
	armed_spawn.combatant_key = "cyrus"
	armed_spawn.weapon_base = Stats.WEAPON_BASE * 2
	var plain = combat.create_combatant(CombatantDatabase.combatants["cyrus"], "cyrus", "", plain_spawn)
	var armed = combat.create_combatant(CombatantDatabase.combatants["cyrus"], "cyrus", "", armed_spawn)
	var plain_tick = combat.dot_base_damage(plain, fireball, burn.dot_modifier)
	var armed_tick = combat.dot_base_damage(armed, fireball, burn.dot_modifier)
	ok(armed_tick > plain_tick, "the better-armed caster burns harder",
		"%.1f against %.1f" % [armed_tick, plain_tick])
	# From the same base the direct hit is built on - the caster's stat and the
	# weapon in their hand - but not the skill's own ability_modifier, which
	# sizes the blow and is deliberately kept out of what the blow leaves
	# behind, so the two can be tuned apart.
	var by_the_book = Stats.base_damage(combat.stat_of(armed, fireball.scaling_stat),
		armed.weapon_base) * burn.dot_modifier
	ok(is_equal_approx(armed_tick, by_the_book),
		"from the same base the swing is worked out from, and its own dial alone",
		"%.2f against %.2f" % [armed_tick, by_the_book])
	# The whole point of the fix: the two halves of one attack now agree about
	# what the caster is carrying.
	var plain_swing = combat.base_skill_damage(plain, fireball)
	var armed_swing = combat.base_skill_damage(armed, fireball)
	ok(armed_swing > plain_swing and armed_tick > plain_tick,
		"so a heavier weapon moves the swing and the burn together",
		"swing %d->%d, tick %.1f->%.1f" % [plain_swing, armed_swing, plain_tick, armed_tick])
	log_line("")

	log_line("======== the same affliction twice over is one affliction ========")
	# Burned by an enemy, then burning yourself with Trailblaze: the second Burn
	# replaces the first rather than ticking alongside it. Stacked, one name in
	# the panel would quietly be doing double damage.
	revive(target)
	target.status_effects.clear()
	var fresh_burn := EffectDefinition.new()
	fresh_burn.type = EffectDefinition.EffectType.CONDITION
	fresh_burn.condition = burn
	acting.stats[Stats.stat_key(fireball.scaling_stat)] = 10
	combat.apply_effect(acting, target, fresh_burn, fireball, false)
	var burns_on_them = func():
		var n = 0
		for eff in target.status_effects:
			if eff.get("stat", "") == "condition" and eff.get("condition") == burn:
				n += 1
		return n
	ok(burns_on_them.call() == 1, "one Burn after one casting", "%d" % burns_on_them.call())
	var first_strength = 0.0
	for eff in target.status_effects:
		if eff.get("condition") == burn:
			first_strength = eff.get("dot_base", 0.0)
	# A stronger caster sets the second one, so which of the two survived is
	# visible rather than a matter of trust.
	acting.stats[Stats.stat_key(fireball.scaling_stat)] = 90
	combat.apply_effect(acting, target, fresh_burn, fireball, false)
	ok(burns_on_them.call() == 1, "and still one after a second", "%d" % burns_on_them.call())
	var surviving = 0.0
	for eff in target.status_effects:
		if eff.get("condition") == burn:
			surviving = eff.get("dot_base", 0.0)
	ok(surviving > first_strength, "and it is the newer, fiercer one that stayed",
		"%.1f replaced %.1f" % [surviving, first_strength])

	# Different afflictions are different things and both stay.
	var poison_effect := EffectDefinition.new()
	poison_effect.type = EffectDefinition.EffectType.CONDITION
	poison_effect.condition = load("res://conditions/poisoned.tres")
	combat.apply_effect(acting, target, poison_effect, fireball, false)
	ok(burns_on_them.call() == 1 and combat.conditions_of(target).size() == 2,
		"while a different one lands beside it rather than replacing it",
		"%d conditions" % combat.conditions_of(target).size())

	# And the same rule for a nameless lingering wound, matched on its element.
	target.status_effects.clear()
	combat.apply_effect(acting, target, dot_effect, dart, false)
	combat.apply_effect(acting, target, dot_effect, dart, false)
	var loose_ticks = 0
	for eff in target.status_effects:
		if eff.get("stat", "") == "dot":
			loose_ticks += 1
	ok(loose_ticks == 1, "two lingering wounds of one element are one wound", "%d" % loose_ticks)
	log_line("")

	log_line("======== Cleanse lifts everything at once ========")
	# Not one affliction and not one kind of affliction: a cure is a cure.
	revive(target)
	target.status_effects.clear()
	for laid in [fresh_burn, poison_effect]:
		combat.apply_effect(acting, target, laid, fireball, false)
	var frost := EffectDefinition.new()
	frost.type = EffectDefinition.EffectType.CONDITION
	frost.condition = load("res://conditions/frozen.tres")
	combat.apply_effect(acting, target, frost, fireball, false)
	ok(combat.conditions_of(target).size() == 3, "three different afflictions on them",
		"%d" % combat.conditions_of(target).size())
	var cure: SkillDefinition = SkillDatabase.skills["cleanse"]
	var cure_effect: EffectDefinition = null
	for eff in cure.all_effects():
		if eff.type == EffectDefinition.EffectType.DISPEL:
			cure_effect = eff
	ok(cure_effect != null, "Cleanse dispels")
	ok(cure_effect != null and cure_effect.dispel_count == 0,
		"and takes off every one it can reach rather than a fixed number",
		"count %d" % (cure_effect.dispel_count if cure_effect else -1))
	combat.dispel_status_effects(acting, target, cure_effect)
	ok(combat.conditions_of(target).is_empty(), "so one casting leaves them clean",
		"%d left" % combat.conditions_of(target).size())
	log_line("")

	log_line("======== base against somebody else, the real figure against yourself ========")
	# Aimed outward the panel cannot know whose defence it will meet, so it
	# promises the base the same way the Base Damage line does. Turned on the
	# caster it knows exactly, so it says what it will cost.
	acting.stats[Stats.stat_key(fireball.scaling_stat)] = 40
	acting.stats["defense"] = 30
	var outward = ui.build_skill_tooltip(SkillDatabase.skills["burning_shot"], acting)
	var promised = 0
	for line in outward.split("
"):
		if line.contains("Inflicts Burn"):
			for word in line.replace("(", " ").split(" "):
				if word.is_valid_int():
					promised = int(word)
	var fired: SkillDefinition = SkillDatabase.skills["burning_shot"]
	var fired_strength = 0.0
	for fired_effect in fired.all_effects():
		if fired_effect.type == EffectDefinition.EffectType.CONDITION:
			fired_strength = fired_effect.condition_dot_strength()
	var expected_base = roundi(combat.dot_base_damage(acting, fired, fired_strength))
	ok(promised == expected_base, "outward, the tick quoted is the base figure",
		"panel said %d, base is %d" % [promised, expected_base])
	var burn_line = ""
	for line in outward.split("
"):
		if line.contains("Inflicts Burn"):
			burn_line = line
	ok(burn_line.contains("base "), "and says so, rather than leaving it to be guessed",
		burn_line)

	# Trailblaze sets its own caster alight, so its target is settled.
	var trail: SkillDefinition = SkillDatabase.skills.get("trailblaze")
	if trail != null:
		var inward = ui.build_skill_tooltip(trail, acting)
		var on_self = 0
		for line in inward.split("
"):
			if line.contains("Inflicts"):
				for word in line.replace("(", " ").split(" "):
					if word.is_valid_int():
						on_self = int(word)
		var trail_strength = 0.0
		for trail_effect in trail.all_effects():
			if trail_effect.type == EffectDefinition.EffectType.CONDITION:
				trail_strength = trail_effect.condition_dot_strength()
		var trail_base = combat.dot_base_damage(acting, trail, trail_strength)
		var trail_real = combat.resisted_damage(acting, load("res://conditions/burn.tres").dot_type,
			combat.dot_tick(acting, trail_base, 0, 0))
		ok(on_self == trail_real, "on yourself, it is the figure after your own defence",
			"panel said %d, you would take %d (base was %.0f)" % [on_self, trail_real, trail_base])
		ok(on_self < roundi(trail_base), "which their armour really does bring down",
			"%d taken against a base of %.0f at %d defence" % [
				on_self, trail_base, combat.get_effective_stat(acting, "defense")])
		var self_lines = []
		for line in inward.split("
"):
			if line.contains("Inflicts"):
				self_lines.append(line)
		ok(not "".join(self_lines).contains("base "),
			"and does not call it a base figure, because it is not one", "%s" % [self_lines])

	# A hit turned on its own caster reads the same way: no "Base".
	var self_hit := EffectDefinition.new()
	self_hit.type = EffectDefinition.EffectType.DAMAGE
	self_hit.applies_to_caster = true
	self_hit.damage_type = Damage.Type.FIRE
	var said_of_self = ui.describe_effect(self_hit, fireball)
	ok(said_of_self.begins_with("Damage:"), "a hit on yourself is quoted as damage, not base damage",
		said_of_self)
	var outward_hit := EffectDefinition.new()
	outward_hit.type = EffectDefinition.EffectType.DAMAGE
	outward_hit.damage_type = Damage.Type.FIRE
	ok(ui.describe_effect(outward_hit, fireball).begins_with("Base Damage:"),
		"while one aimed outward still promises the base", ui.describe_effect(outward_hit, fireball))
	log_line("")

	log_line("======== a buffed attribute reaches the arithmetic that reads it ========")
	# A skill that multiplies the swinger's Defense for a turn used to change
	# what the sheet said and nothing else: every damage figure reads an
	# attribute through stat_of, which took the raw number and ignored anything
	# buffing it.
	#
	# Found rather than named. This was written against Careful Swing, which
	# has since become Light Swing and mends instead - so the suite failed for
	# the content having moved rather than for the rule having broken.
	var careful: SkillDefinition = null
	var guard: EffectDefinition = null
	for key in SkillDatabase.skills:
		var candidate: SkillDefinition = SkillDatabase.skills[key]
		if candidate == null or guard != null:
			continue
		for effect in candidate.all_effects():
			if effect.type == EffectDefinition.EffectType.STAT_MULTIPLIER \
					and effect.stat == "defense" and effect.applies_to_caster:
				careful = candidate
				guard = effect
				break
	ok(careful != null, "somebody in the game multiplies their own defence",
		careful.name if careful != null else "nobody")
	if careful != null:
		ok(guard != null and guard.stat_multiplier != 1.0,
			"and it is a multiplier, not an addition",
			"x%s" % (guard.stat_multiplier if guard else 0))
		if guard != null:
			revive(target)
			target.status_effects.clear()
			var bare = combat.stat_of(target, Stats.Type.DEFENSE)
			combat.apply_effect(target, target, guard, careful, false)
			var guarded = combat.stat_of(target, Stats.Type.DEFENSE)
			ok(guarded == roundi(bare * guard.stat_multiplier),
				"their defence really is multiplied",
				"%d became %d at x%s" % [bare, guarded, guard.stat_multiplier])

			# And the point of it: a hit lands softer while it holds.
			var blow := EffectDefinition.new()
			blow.type = EffectDefinition.EffectType.DAMAGE
			blow.damage_type = Damage.Type.PHYSICAL
			target.hp = 500
			combat.do_damage(acting, target, blow, fireball, false)
			var took_guarded = 500 - target.hp
			target.status_effects.clear()
			target.hp = 500
			combat.do_damage(acting, target, blow, fireball, false)
			var took_bare = 500 - target.hp
			ok(took_guarded < took_bare, "and the same swing hurts less while it holds",
				"%d taken guarded, %d without" % [took_guarded, took_bare])

	# The same hole let a caster's own attribute go unbuffed.
	var sharpen := EffectDefinition.new()
	sharpen.type = EffectDefinition.EffectType.STAT_MULTIPLIER
	sharpen.stat = Stats.stat_key(fireball.scaling_stat)
	sharpen.stat_multiplier = 2.0
	sharpen.duration = 2
	acting.status_effects.clear()
	var dull_swing = combat.base_skill_damage(acting, fireball)
	combat.apply_effect(acting, acting, sharpen, fireball, false)
	var keen_swing = combat.base_skill_damage(acting, fireball)
	ok(keen_swing > dull_swing, "and doubling a caster's own stat doubles what they throw",
		"%d became %d" % [dull_swing, keen_swing])
	acting.status_effects.clear()
	log_line("")

	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
