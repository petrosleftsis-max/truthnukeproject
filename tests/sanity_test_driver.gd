extends Node
## A wide sweep over every piece of content and the tables the engine reads it
## through, looking for things that are wrong rather than things that changed.
##
## Reports FLAGs rather than failures: a flag is something for a person to
## decide about, not necessarily a bug. FAILURES stays 0 so the harness reads
## this as a report.

var LOG_PATH := HarnessLog.path_for("sanity")
var _log: FileAccess
var _flags = 0

const MOVEMENT_STATS := ["movement", "accuracy", "max_hp", "initiative"]

## How far apart two damage colours have to be, as a CIE76 distance. The palette
## sits at 23 at its closest (Physical and Ice, both deliberate), so 20 leaves
## room for a judgement call while still catching a genuine collision - Metal
## against Physical measured 14 and was unreadable.
const COLOURS_MUST_DIFFER_BY := 20.0


func log_line(t): _log.store_line(t); _log.flush()


func flag(condition: bool, what: String, detail: String = ""):
	if condition:
		_flags += 1
		log_line("  FLAG  %s %s" % [what, detail])


func note(what: String, detail: String = ""):
	log_line("  note  %s %s" % [what, detail])


func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	await get_tree().process_frame
	run_audit()
	log_line("")
	log_line("FINDINGS: %d" % _flags)
	log_line("FAILURES: 0")
	get_tree().quit(0)


## How far apart two colours look, rather than how far apart their numbers are.
## Lab, so lightness and hue count the way an eye counts them.
func colour_distance(a: Color, b: Color) -> float:
	var first = to_lab(a)
	var second = to_lab(b)
	var total := 0.0
	for i in 3:
		total += pow(first[i] - second[i], 2.0)
	return sqrt(total)


func to_lab(c: Color) -> Array:
	var lin = c.srgb_to_linear()
	var x = (0.4124 * lin.r + 0.3576 * lin.g + 0.1805 * lin.b) / 0.95047
	var y = 0.2126 * lin.r + 0.7152 * lin.g + 0.0722 * lin.b
	var z = (0.0193 * lin.r + 0.1192 * lin.g + 0.9505 * lin.b) / 1.08883
	return [116.0 * pivot(y) - 16.0, 500.0 * (pivot(x) - pivot(y)),
		200.0 * (pivot(y) - pivot(z))]


func pivot(t: float) -> float:
	return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0


func known_stat(key: String) -> bool:
	return key in Stats.KEYS or key in MOVEMENT_STATS


## Every property a resource file writes down is one its script still has.
##
## Godot drops a property the script no longer declares, silently and on load,
## leaving the value at its default - so a rename that misses a data file does
## not fail, it quietly makes every one of them identical. Renaming flat_power
## to item_power did exactly that to fifteen of sixteen items: each loaded at
## the default 20, so all four bombs were the same bomb and all three potions
## the same potion, and nothing anywhere said so.
##
## Read as text, because by the time the resource is loaded the evidence is
## gone - the object simply has no such property and never did.
func audit_stale_properties():
	log_line("======== what the files write down, and what the scripts still read ========")
	var stranded := []
	var checked := 0
	for folder in ["res://items", "res://skills", "res://conditions"]:
		var dir = DirAccess.open(folder)
		if dir == null:
			continue
		for file in dir.get_files():
			if not file.ends_with(".tres") and not file.ends_with(".tres.remap"):
				continue
			var path = folder + "/" + file.replace(".remap", "")
			var loaded = load(path)
			if loaded == null:
				continue
			# Everything the object really has, to measure the file against.
			var known := {}
			for property in loaded.get_property_list():
				known[property.name] = true
			var text = FileAccess.get_file_as_string(path)
			if text == "":
				continue
			checked += 1
			# Only the resource's own block: a sub_resource is a different
			# object with a different script and its own set of properties.
			var own = text.split("[resource]")[-1]
			for line in own.split("
"):
				var bits = line.split(" = ")
				if bits.size() < 2:
					continue
				var key = bits[0].strip_edges()
				if key == "" or key.begins_with("[") or key.begins_with("#"):
					continue
				if key.begins_with("metadata/") or key.begins_with("script"):
					continue
				if not known.has(key):
					stranded.append("%s writes %s, which %s no longer has"
						% [file, key, loaded.get_class()])
	flag(not stranded.is_empty(),
		"a resource writes down a property its script no longer reads",
		"%s" % [stranded])
	note("resources whose written properties were checked", "%d" % checked)
	log_line("")


func run_audit():
	audit_stale_properties()
	audit_tables()
	audit_skills()
	audit_items()
	audit_conditions()
	audit_combatants()
	audit_orphans()


func audit_tables():
	log_line("======== the tables the engine reads content through ========")
	flag(Stats.NAMES.size() != Stats.KEYS.size(),
		"Stats.NAMES and Stats.KEYS are different lengths",
		"%d vs %d" % [Stats.NAMES.size(), Stats.KEYS.size()])
	flag(Damage.TYPE_NAMES.size() != Damage.Type.size(),
		"a damage type has no name",
		"%d names for %d types" % [Damage.TYPE_NAMES.size(), Damage.Type.size()])
	flag(Damage.TYPE_COLOURS.size() != Damage.Type.size(),
		"a damage type has no colour",
		"%d colours for %d types" % [Damage.TYPE_COLOURS.size(), Damage.Type.size()])
	var uncategorised := []
	for type in Damage.Type.values():
		if not Damage.CATEGORIES.has(type):
			uncategorised.append(Damage.type_name(type))
	flag(not uncategorised.is_empty(), "a damage type belongs to no category",
		"%s" % [uncategorised])
	for base in Damage.UPGRADES:
		var up = Damage.UPGRADES[base]
		flag(up == base, "a damage type upgrades to itself", Damage.type_name(base))
		flag(up < 0 or up >= Damage.Type.size(), "a damage type upgrades to nothing",
			"%s to %d" % [Damage.type_name(base), up])
	# Two damage types that look alike on a floating number are two types the
	# player cannot tell apart, which is most of what the colour is for. Counted
	# in Lab rather than by comparing hex, because "different" in a file and
	# "different" to an eye are not the same thing - Metal and Physical were
	# distinct values and the same colour to look at.
	var too_close := []
	var types = Damage.Type.values()
	for i in types.size():
		for j in range(i + 1, types.size()):
			var apart = colour_distance(Damage.type_colour(types[i]), Damage.type_colour(types[j]))
			if apart < COLOURS_MUST_DIFFER_BY:
				too_close.append("%s/%s %.0f" % [Damage.type_name(types[i]),
					Damage.type_name(types[j]), apart])
	flag(not too_close.is_empty(), "two damage types are hard to tell apart",
		"%s" % [too_close])
	var resist_keys := []
	for type in Damage.Type.values():
		var key = Damage.resistance_key(type)
		flag(key == "", "a damage type has no resistance key", Damage.type_name(type))
		flag(key in resist_keys, "two damage types share a resistance key", key)
		resist_keys.append(key)
	log_line("")


func audit_skills():
	log_line("======== every skill ========")
	for key in SkillDatabase.skills:
		var s: SkillDefinition = SkillDatabase.skills[key]
		if s == null:
			flag(true, "%s has no resource" % key)
			continue
		var who = "%s (%s)" % [s.name, key]
		flag(s.name == "", "%s has no name" % key)
		flag(s.icon == null, "%s has no icon" % who)
		flag(s.min_range > s.max_range, "%s has a minimum beyond its maximum" % who,
			"%d-%d" % [s.min_range, s.max_range])
		# max_range 0 is how a self-cast is written, so it is only wrong when
		# the skill is aimed at somebody else.
		flag(s.max_range <= 0 and not s.targets_ally and s.aoe_radius <= 0,
			"%s is aimed at enemies and reaches nowhere" % who, "%d" % s.max_range)
		flag(s.accuracy < 0 or s.accuracy > 100, "%s has an impossible accuracy" % who,
			"%d" % s.accuracy)
		flag(s.required_level < 1, "%s needs a level below one" % who, "%d" % s.required_level)
		flag(s.deals_damage and s.ability_modifier <= 0.0,
			"%s deals damage at zero strength" % who, "x%s" % s.ability_modifier)
		# slot_available_for only ever looks at levels 1 to 3.
		flag(s.spell_slot_level < 0 or s.spell_slot_level > 3,
			"%s costs a gate that can never be paid" % who, "level %d" % s.spell_slot_level)
		flag(not s.deals_damage and s.all_effects().is_empty() \
				and s.teleports == SkillDefinition.TeleportWho.NOBODY \
				and not s.suppresses_reactions and not s.kills_caster,
			"%s does nothing whatever" % who)
		# Aimed at an enemy, but everything it carries lands on the caster -
		# so it asks for a target and then ignores it.
		if not s.deals_damage and not s.targets_ally and not s.all_effects().is_empty():
			var any_on_them := false
			for effect in s.all_effects():
				if effect != null and not effect.applies_to_caster:
					any_on_them = true
			flag(not any_on_them and s.teleports == SkillDefinition.TeleportWho.NOBODY,
				"%s asks for an enemy and then does nothing to them" % who)
		if s.aoe_shape != SkillDefinition.AoEShape.DIAMOND:
			flag(s.aoe_width <= 0, "%s is a beam with no width" % who, "%d" % s.aoe_width)
			flag(s.aoe_radius <= 0, "%s is a beam with no length" % who, "%d" % s.aoe_radius)
		if s.uses_stat_contest:
			flag(s.contest_stat < 0 or s.contest_stat >= Stats.NAMES.size(),
				"%s contests a stat that does not exist" % who, "%d" % s.contest_stat)
		flag(s.scaling_stat < 0 or s.scaling_stat >= Stats.NAMES.size(),
			"%s scales off a stat that does not exist" % who, "%d" % s.scaling_stat)
		flag(s.damage_type < 0 or s.damage_type >= Damage.Type.size(),
			"%s deals a damage type that does not exist" % who, "%d" % s.damage_type)
		flag(s.is_reactive and s.max_range > 4,
			"%s reacts from a long way off" % who, "%d tiles" % s.max_range)
		flag(s.kills_caster and s.targets_ally,
			"%s kills whoever uses it and is aimed at allies" % who)
		audit_effects(who, s)
	note("skills checked", "%d" % SkillDatabase.skills.size())
	log_line("")


func audit_items():
	log_line("======== every item ========")
	for key in ItemDatabase.items:
		var i = ItemDatabase.items[key]
		if i == null:
			flag(true, "%s has no resource" % key)
			continue
		var who = "%s (%s)" % [i.name, key]
		flag(i.icon == null, "%s has no icon" % who)
		flag(i.max_range <= 0, "%s reaches nowhere" % who, "%d" % i.max_range)
		var worth_something = i.deals_damage
		for effect in i.all_effects():
			if effect != null and effect.type == EffectDefinition.EffectType.HEAL:
				worth_something = true
		flag(worth_something and i.item_power <= 0,
			"%s is worth nothing written on the bottle" % who, "%d" % i.item_power)
		flag(not i.deals_damage and i.all_effects().is_empty(),
			"%s does nothing whatever" % who)
		# A bottle beats somebody with its own power rather than the thrower's
		# stat. At zero it beats nobody, and the only sign would be that it
		# never works.
		flag(i.uses_stat_contest and i.item_power <= 0,
			"%s is contested and can never win" % who, "power %d" % i.item_power)
		audit_effects(who, i)
	note("items checked", "%d" % ItemDatabase.items.size())
	log_line("")


func audit_conditions():
	log_line("======== every condition ========")
	var dir = DirAccess.open("res://conditions")
	if dir == null:
		flag(true, "the conditions folder cannot be read")
		return
	var seen := 0
	for file in dir.get_files():
		if not file.ends_with(".tres") and not file.ends_with(".tres.remap"):
			continue
		var path = "res://conditions/" + file.replace(".remap", "")
		audit_condition(file, load(path))
		seen += 1
	note("conditions checked", "%d" % seen)
	log_line("")


func audit_condition(who: String, c):
	if c == null:
		flag(true, "%s has no resource" % who)
		return
	flag(c.display_name == "", "%s has no name" % who)
	flag(c.duration <= 0, "%s lasts no time at all" % who, "%d" % c.duration)
	flag(c.dot_modifier > 0.0 and (c.dot_type < 0 or c.dot_type >= Damage.Type.size()),
		"%s burns with a damage type that does not exist" % who, "%d" % c.dot_type)
	flag(c.dot_min > c.dot_max, "%s has a minimum tick above its maximum" % who,
		"%d-%d" % [c.dot_min, c.dot_max])
	# The glossary reads dot_strength for its wording and dot_modifier for the
	# arithmetic. One set without the other reads as a lie.
	flag(c.dot_strength != ConditionDefinition.DotStrength.NONE and c.dot_modifier <= 0.0,
		"%s says it burns but burns for nothing" % who)
	flag(c.dot_strength == ConditionDefinition.DotStrength.NONE and c.dot_modifier > 0.0,
		"%s burns without saying so in the glossary" % who, "x%s" % c.dot_modifier)


func audit_combatants():
	log_line("======== every combatant ========")
	for key in CombatantDatabase.combatants:
		var c: CombatantDefinition = CombatantDatabase.combatants[key]
		if c == null:
			flag(true, "%s has no resource" % key)
			continue
		flag(c.max_hp <= 0, "%s has no health" % key, "%d" % c.max_hp)
		flag(c.movement <= 0, "%s cannot move at all" % key, "%d" % c.movement)
		flag(c.skills.is_empty() and c.secondary_skills.is_empty(), "%s knows nothing" % key)
		for skill_key in c.skills + c.secondary_skills:
			flag(not SkillDatabase.skills.has(skill_key),
				"%s carries an unknown skill" % key, skill_key)
		for item_key in c.starting_items:
			flag(not ItemDatabase.items.has(item_key),
				"%s starts with an unknown item" % key, item_key)
		flag(c.main_stat < 0 or c.main_stat >= Stats.NAMES.size(),
			"%s has a main stat that does not exist" % key, "%d" % c.main_stat)
		flag(c.secondary_stat < 0 or c.secondary_stat >= Stats.NAMES.size(),
			"%s has a secondary stat that does not exist" % key, "%d" % c.secondary_stat)
		flag(c.main_stat == c.secondary_stat,
			"%s has the same stat twice" % key, Stats.stat_name(c.main_stat))
		var needs_gates := false
		for skill_key in c.skills + c.secondary_skills:
			var s: SkillDefinition = SkillDatabase.skills.get(skill_key)
			if s != null and s.spell_slot_level > 0:
				needs_gates = true
		if needs_gates and not c.casts_without_gates:
			var gates = c.gates_at(1)
			var total := 0
			for g in gates:
				total += g
			flag(total <= 0, "%s knows a spell but opens no gates at level one" % key,
				"%s" % [gates])
		# Anything a player can reach has to be reachable from their own panel,
		# so a secondary-only skill nobody lists as secondary never appears.
		for skill_key in c.secondary_skills:
			var s: SkillDefinition = SkillDatabase.skills.get(skill_key)
			if s != null and s.required_level > 1:
				note("%s has %s as a secondary and it needs level %d"
					% [key, s.name, s.required_level])
	note("combatants checked", "%d" % CombatantDatabase.combatants.size())
	log_line("")


func audit_orphans():
	log_line("======== content nobody can reach ========")
	var carried := {}
	var held := {}
	for key in CombatantDatabase.combatants:
		var c: CombatantDefinition = CombatantDatabase.combatants[key]
		if c == null:
			continue
		for skill_key in c.skills + c.secondary_skills:
			carried[skill_key] = true
		for item_key in c.starting_items:
			held[item_key] = true
	# And what the encounters hand out, which is where the kit actually comes
	# from now: a spawn's starting_items overrides the character's own, so
	# reading only the database called every tiered bottle unreachable.
	var encounters = DirAccess.open("res://encounters")
	if encounters != null:
		for file in encounters.get_files():
			if not file.ends_with(".tres") and not file.ends_with(".tres.remap"):
				continue
			var fight = load("res://encounters/" + file.replace(".remap", ""))
			if fight == null:
				continue
			for spawn in fight.spawns:
				if spawn == null:
					continue
				for item_key in spawn.starting_items:
					held[item_key] = true
	var orphan_skills := []
	for key in SkillDatabase.skills:
		# Items register themselves here as well, and are counted below.
		if not carried.has(key) and not ItemDatabase.is_item(key):
			orphan_skills.append(key)
	note("skills nobody carries", "%s" % [orphan_skills])
	var orphan_items := []
	for key in ItemDatabase.items:
		if not held.has(key):
			orphan_items.append(key)
	note("items nobody starts with", "%s" % [orphan_items])
	# Conditions the glossary will list but nothing in the game inflicts.
	var inflicted := {}
	for source in [SkillDatabase.skills, ItemDatabase.items]:
		for key in source:
			var s = source[key]
			if s == null:
				continue
			for effect in s.all_effects():
				if effect != null and effect.type == EffectDefinition.EffectType.CONDITION \
						and effect.condition != null:
					inflicted[effect.condition.display_name] = true
	var dir = DirAccess.open("res://conditions")
	var never := []
	if dir != null:
		for file in dir.get_files():
			if not file.ends_with(".tres") and not file.ends_with(".tres.remap"):
				continue
			var c = load("res://conditions/" + file.replace(".remap", ""))
			if c != null and not inflicted.has(c.display_name):
				never.append(c.display_name)
	note("conditions nothing inflicts", "%s" % [never])
	log_line("")


func audit_effects(who: String, s):
	var seen_conditions := {}
	for effect in s.all_effects():
		if effect == null:
			flag(true, "%s carries an empty effect" % who)
			continue
		match effect.type:
			EffectDefinition.EffectType.DAMAGE_OVER_TIME:
				flag(effect.duration <= 0, "%s burns for no turns" % who,
					"%d" % effect.duration)
				flag(effect.damage_modifier <= 0.0 and effect.max_amount <= 0,
					"%s burns for nothing at all" % who)
			EffectDefinition.EffectType.CONDITION:
				flag(effect.condition == null,
					"%s inflicts a condition that is not there" % who)
				if effect.condition != null:
					flag(seen_conditions.has(effect.condition),
						"%s inflicts the same condition twice" % who,
						effect.condition.display_name)
					seen_conditions[effect.condition] = true
			EffectDefinition.EffectType.STAT_MODIFIER:
				flag(not known_stat(effect.stat),
					"%s changes a stat nothing reads" % who, effect.stat)
				flag(effect.modifier_amount == 0,
					"%s changes a stat by nothing" % who, effect.stat)
				flag(effect.duration <= 0, "%s changes a stat for no turns" % who,
					"%s for %d" % [effect.stat, effect.duration])
			EffectDefinition.EffectType.STAT_MULTIPLIER:
				flag(not known_stat(effect.stat),
					"%s multiplies a stat nothing reads" % who, effect.stat)
				flag(effect.stat_multiplier == 1.0,
					"%s multiplies a stat by one" % who, effect.stat)
				flag(effect.duration <= 0, "%s multiplies a stat for no turns" % who,
					"%s for %d" % [effect.stat, effect.duration])
			EffectDefinition.EffectType.HEAL:
				flag(effect.heal_modifier < 0.0, "%s mends a negative amount" % who)
			EffectDefinition.EffectType.PUSH, EffectDefinition.EffectType.PULL:
				flag(effect.knockback_distance <= 0,
					"%s shoves nobody anywhere" % who, "%d" % effect.knockback_distance)
			EffectDefinition.EffectType.MOVEMENT_CLASS:
				flag(effect.movement_class < 0 or effect.movement_class > 2,
					"%s grants a way of moving that does not exist" % who,
					"%d" % effect.movement_class)
				flag(effect.duration <= 0, "%s grants it for no turns" % who,
					"%d" % effect.duration)
			EffectDefinition.EffectType.RESISTANCE:
				flag(effect.damage_type < 0 or effect.damage_type >= Damage.Type.size(),
					"%s resists a damage type that does not exist" % who)
				flag(effect.modifier_amount == 0,
					"%s changes a resistance by nothing" % who)
			EffectDefinition.EffectType.UPGRADE_ELEMENT:
				flag(effect.duration <= 0, "%s upgrades an element for no turns" % who,
					"%d" % effect.duration)
		if effect.type == EffectDefinition.EffectType.HEAL and not effect.applies_to_caster \
				and not s.targets_ally and not s.affects_both_sides:
			flag(true, "%s mends whatever it is aimed at, and it is aimed at enemies" % who)
