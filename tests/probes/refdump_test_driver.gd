extends Node
## Probe: writes every skill, path, passive, condition, item, piece of gear, enemy and
## object in the game as Markdown, for the combat reference.
## Writes refdump_data.md next to the test logs (tests/run.sh refdump).

const SKIP := ["icon", "sound", "sound_volume_db", "sprite_frames", "animation", "portrait_texture",
	"map_texture", "tint", "script", "resource_local_to_scene", "resource_path", "resource_name",
	"resource_scene_unique_id", "quick_time", "hack", "future_changed_lines", "music", "frames_override",
	"menu_picture", "voice", "bark_lines", "hit_sound", "death_sound", "attack_sound", "texture"]

var _defaults := {}
var _out: PackedStringArray = []
var _owners := {}


func _ready():
	for i in 3:
		await get_tree().process_frame
	var path: String = HarnessLog.path_for("refdump").get_base_dir().path_join("refdump_data.md")
	_build()
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(_out))
	f.close()
	var report := FileAccess.open(HarnessLog.path_for("refdump"), FileAccess.WRITE)
	report.store_line("wrote %d lines to %s" % [_out.size(), path])
	report.store_line("FAILURES: 0")
	report.close()
	get_tree().quit(0)


func w(line: String = ""):
	_out.append(line)


func _default_of(obj: Object) -> Object:
	var script = obj.get_script()
	if script == null:
		return null
	if not _defaults.has(script):
		_defaults[script] = script.new()
	return _defaults[script]


func _same(a, b) -> bool:
	if typeof(a) != typeof(b):
		return false
	if a is Array or a is Dictionary:
		return str(a) == str(b)
	if a is Object or b is Object:
		return a == b
	return a == b


## Every stored setting on `obj` that differs from a fresh one, as "name: value".
func props(obj: Object, skip: Array = []) -> Array:
	var lines := []
	var base := _default_of(obj)
	for p in obj.get_property_list():
		if not (p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or not (p.usage & PROPERTY_USAGE_STORAGE):
			continue
		var n: String = p.name
		if n in SKIP or n in skip:
			continue
		var v = obj.get(n)
		if v is Texture2D or v is AudioStream or v is SpriteFrames or v is PackedScene:
			continue
		if base != null and _same(v, base.get(n)):
			continue
		if v == null or (v is String and v == "") or ((v is Array or v is Dictionary) and v.is_empty()):
			continue
		lines.append("%s: %s" % [n, fmt(v, p)])
	return lines


func fmt(v, p: Dictionary = {}) -> String:
	if v is Resource:
		var rp: String = v.resource_path
		if rp != "" and not rp.contains("::"):
			var label: String = rp.get_file().get_basename()
			if "name" in v and str(v.name) != "":
				label = "%s (%s)" % [v.name, label]
			elif "display_name" in v and str(v.display_name) != "":
				label = "%s (%s)" % [v.display_name, label]
			return label
		var inner := props(v)
		var title := ""
		if "name" in v and str(v.name) != "":
			title = str(v.name) + " "
		return "%s{%s}" % [title, "; ".join(inner)]
	if v is Array:
		var parts := []
		for item in v:
			parts.append(fmt(item))
		return "[%s]" % ", ".join(parts)
	if v is float:
		return str(snappedf(v, 0.001))
	if v is int and p.has("hint"):
		if p.hint == PROPERTY_HINT_ENUM:
			var names := _enum_names(p.hint_string)
			if names.has(v):
				return names[v]
		if p.hint == PROPERTY_HINT_FLAGS:
			var flags := []
			var i := 0
			for name in p.hint_string.split(","):
				var bit := 1 << i
				var parts2: PackedStringArray = str(name).split(":")
				if parts2.size() > 1:
					bit = int(parts2[1])
				if v & bit:
					flags.append(parts2[0])
				i += 1
			return "|".join(flags) if not flags.is_empty() else str(v)
	if v is String:
		return "\"%s\"" % v.replace("\n", " ")
	return str(v)


func _enum_names(hint: String) -> Dictionary:
	var names := {}
	var i := 0
	for entry in hint.split(","):
		var parts: PackedStringArray = str(entry).split(":")
		var value := i
		if parts.size() > 1:
			value = int(parts[1])
		names[value] = parts[0]
		i = value + 1
	return names


func _prop(obj: Object, name: String) -> Dictionary:
	for p in obj.get_property_list():
		if p.name == name:
			return p
	return {}


func enum_text(obj: Object, name: String) -> String:
	return fmt(obj.get(name), _prop(obj, name))


func _note_owner(key: String, who: String):
	if not _owners.has(key):
		_owners[key] = []
	if not _owners[key].has(who):
		_owners[key].append(who)


func _tres_under(folder: String) -> Array:
	var found := []
	var dir := DirAccess.open(folder)
	if dir == null:
		return found
	for file in dir.get_files():
		var f := file.replace(".remap", "")
		if f.ends_with(".tres"):
			found.append(folder.path_join(f))
	for sub in dir.get_directories():
		found.append_array(_tres_under(folder.path_join(sub)))
	found.sort()
	return found


func _gates_text(gates: Array) -> String:
	var parts := []
	for i in range(1, gates.size()):
		if gates[i] > 0:
			parts.append("%s %d" % [Stats.gate_name(i).replace("Gates of ", ""), gates[i]])
	return ", ".join(parts) if not parts.is_empty() else "none"


func _build():
	var skills := DataFolder.skills()
	var characters := DataFolder.read(DataFolder.CHARACTERS, CombatantDefinition)
	var enemies := DataFolder.read(DataFolder.ENEMIES, CombatantDefinition)
	var objects := DataFolder.read(DataFolder.OBJECTS, CombatantDefinition)
	var paths := DataFolder.subclasses()
	var items := DataFolder.items()
	var gear := DataFolder.equipment()
	for key in characters:
		for s in characters[key].skills + characters[key].secondary_skills:
			_note_owner(s, characters[key].name)
	for key in paths:
		for s in paths[key].skills:
			_note_owner(s, "%s path" % paths[key].name)
	for key in enemies:
		for s in enemies[key].skills + enemies[key].secondary_skills:
			_note_owner(s, enemies[key].name)

	w("# Appendix: everything in the game, from its data files")
	w("")
	w("Generated from the game's resource files (data/). Numbers are exactly what the game uses. " +
		"`x1.5` is an ability modifier: damage = (weapon base + 0.7 x stat) x modifier x 40/(40 + defence). " +
		"Only settings that differ from the default are listed under 'settings'.")
	w("")

	w("## The party")
	w("")
	for key in characters:
		var c: CombatantDefinition = characters[key]
		w("### %s (`%s`)" % [c.name, key])
		w("")
		w("- Main stat %s, secondary %s; spells scale from %s" % [Stats.stat_name(c.main_stat),
			Stats.stat_name(c.secondary_stat), Stats.stat_name(c.spellcasting_stat)])
		w("- Health: %d at level 1, %d at 24, %d at 64; movement %d; initiative %s" % [c.hp_at(1), c.hp_at(24), c.hp_at(64), c.movement, c.initiative])
		w("- Gates: level 1 %s; level 24 %s; level 64 %s" % [_gates_text(c.gates_at(1)), _gates_text(c.gates_at(24)), _gates_text(c.gates_at(64))])
		w("- Paths (chosen at 24): %s" % ", ".join(Array(c.subclasses).map(func(p): return paths[p].name if paths.has(p) else p)))
		var by_level := {}
		for s in c.skills:
			var skill: SkillDefinition = skills.get(s)
			var lvl: int = skill.required_level if skill != null else 0
			if not by_level.has(lvl):
				by_level[lvl] = []
			by_level[lvl].append(skill.name if skill != null else s)
		var levels := by_level.keys()
		levels.sort()
		w("- Skills and spells, by the level they come at:")
		for lvl in levels:
			w("  - %d: %s" % [lvl, ", ".join(by_level[lvl])])
		if not c.secondary_skills.is_empty():
			w("- Secondary-only skills: %s" % ", ".join(c.secondary_skills))
		w("- Passives:")
		for passive in c.passives:
			w("  - **%s** (%s): %s" % [passive.name, passive.describe_when(), _passive_text(passive)])
		var other := props(c, ["name", "skills", "passives", "secondary_skills", "subclasses", "main_stat",
			"secondary_stat", "spellcasting_stat", "movement", "initiative", "description", "starting_items"])
		if not other.is_empty():
			w("- Other settings: " + "; ".join(other))
		w("")

	w("## The paths (subclasses, chosen at level 24)")
	w("")
	for key in paths:
		var path: SubclassDefinition = paths[key]
		w("### %s (`%s`)" % [path.name, key])
		w("")
		if path.description != "":
			w(path.description.replace("\n", " "))
			w("")
		for s in path.skills:
			var skill: SkillDefinition = skills.get(s)
			if skill != null:
				w("- Skill, level %d: **%s** (see its entry under Skills)" % [skill.required_level, skill.name])
		for passive in path.passives:
			w("- Passive, %s: **%s** - %s" % [passive.describe_when(), passive.name, _passive_text(passive)])
		w("")

	w("## Skills and spells")
	w("")
	w("Sorted the way the game's folders sort them: common to the party, each character's own, their spells, " +
		"their paths', the enemies', and unused. A spell is anything cast through a gate.")
	w("")
	var folder_of := {}
	for key in skills:
		var folder: String = skills[key].resource_path.get_base_dir().trim_prefix("res://data/skills").trim_prefix("/")
		if not folder_of.has(folder):
			folder_of[folder] = []
		folder_of[folder].append(key)
	var folders := folder_of.keys()
	folders.sort()
	for folder in folders:
		w("### Folder: %s" % (folder if folder != "" else "(top)"))
		w("")
		for key in folder_of[folder]:
			_skill_entry(key, skills[key])
	w("")

	w("## Passives (data/passives)")
	w("")
	for file in _tres_under("res://data/passives"):
		var passive = load(file)
		if passive is PassiveDefinition:
			w("- **%s** (`%s`, %s): %s" % [passive.name, file.get_file().get_basename(), passive.describe_when(), _passive_text(passive)])
	w("")

	w("## Conditions (data/conditions)")
	w("")
	for file in _tres_under("res://data/conditions"):
		var condition = load(file)
		if condition is ConditionDefinition:
			var settings := props(condition, ["display_name", "description", "tag"])
			w("- **%s** (`%s`, tag %s): %s%s" % [condition.display_name, file.get_file().get_basename(), condition.tag, condition.describe(),
				(" | settings: " + "; ".join(settings)) if not settings.is_empty() else ""])
	w("")

	w("## Items")
	w("")
	for key in items:
		var item = items[key]
		var settings := props(item, ["name", "description"])
		var heals := _heal_text(item)
		w("- **%s** (`%s`): %s | %s%s" % [item.name, key, str(item.description).replace("\n", " "), "; ".join(settings),
			(" | " + heals) if heals != "" else ""])
	w("")

	w("## Equipment and containers")
	w("")
	for key in gear:
		var piece = gear[key]
		var settings := props(piece, ["name", "description"])
		w("- **%s** (`%s`): %s | %s" % [piece.name, key, str(piece.description).replace("\n", " "), "; ".join(settings)])
	w("")

	w("## Enemies")
	w("")
	for key in enemies:
		_combatant_entry(key, enemies[key], skills)
	w("## Things on the map (objects)")
	w("")
	for key in objects:
		_combatant_entry(key, objects[key], skills)


func _passive_text(passive: PassiveDefinition) -> String:
	var lines: Array = passive.describe_effects()
	var text := " ".join(lines)
	if passive.description != "":
		text = passive.description.replace("\n", " ") + (" [" + text + "]" if text != "" else "")
	return text


## What a heal of `skill` mends, by the rule Combat.heal_amount and heal_share_on
## follow. The effect's own min and max stand in only for a heal with no skill
## behind it, so a dump that showed them alone read Heal as 4-8.
func _heal_text(skill: SkillDefinition) -> String:
	var parts := []
	for effect in skill.all_effects():
		if effect == null or effect.type != EffectDefinition.EffectType.HEAL:
			continue
		var dial: float = effect.heal_modifier if effect.heal_modifier > 0.0 else skill.ability_modifier
		var power := "item power %d" % int(skill.get("item_power")) if skill is ItemDefinition else \
			"(weapon base + 0.7 x %s)" % ("the caster's spellcasting stat" if Combat.is_spell(skill) else Stats.stat_name(skill.scaling_stat))
		var text := "%s x %s" % [power, snappedf(dial, 0.01)]
		if effect.heals_flat() and not skill is ItemDefinition:
			# The flat rule (Combat.heal_amount): the healer's healing stat is the
			# one the skill scales with for them - Self for the Mimic.
			var terms := []
			if effect.heal_flat > 0.0:
				terms.append(str(roundi(effect.heal_flat)) if is_equal_approx(effect.heal_flat, roundf(effect.heal_flat)) else str(snappedf(effect.heal_flat, 0.01)))
			if effect.heal_per_stat > 0.0:
				terms.append("%s x the healer's healing stat" % snappedf(effect.heal_per_stat, 0.01))
			if effect.heal_per_weapon > 0.0:
				terms.append("%s x weapon base" % snappedf(effect.heal_per_weapon, 0.01))
			text = " + ".join(terms)
		if effect.heal_share_of_health > 0.0:
			text += " + %d%% of the target's max health" % roundi(effect.heal_share_of_health * 100)
		if effect.applies_to_caster:
			text += ", on its user"
		parts.append(text)
	if parts.is_empty():
		return ""
	return "heals %s (no defence, no randomness; the effect's min and max amount are unused)" % "; ".join(parts)


func _skill_entry(key: String, skill: SkillDefinition):
	var head := "**%s** (`%s`)" % [skill.name, key]
	var bits := []
	bits.append("level %d" % skill.required_level)
	if skill.spell_slot_level > 0:
		bits.append("spell, %s" % Stats.gate_name(skill.spell_slot_level))
	bits.append("secondary action" if skill.is_secondary else ("reaction" if skill.reaction_only else "main action"))
	if skill.is_reactive:
		bits.append("reacts: %s" % skill.describe_triggers())
	bits.append("range %d-%d" % [skill.min_range, skill.max_range])
	bits.append("melee" if skill.melee else "ranged")
	if skill.aoe_radius > 0:
		bits.append("area: %s %d%s" % [enum_text(skill, "aoe_shape"), skill.aoe_radius,
			(" wide %d" % skill.aoe_width) if skill.aoe_width > 1 else ""])
	else:
		bits.append("single target")
	if skill.targets_ally:
		bits.append("aimed at allies")
	if skill.deals_damage:
		bits.append("damage x%s %s%s" % [snappedf(skill.ability_modifier, 0.01), enum_text(skill, "damage_type"),
			("" if skill.spell_slot_level > 0 else ", scales with " + Stats.stat_name(skill.scaling_stat))])
	else:
		bits.append("no damage")
	var heals := _heal_text(skill)
	if heals != "":
		bits.append(heals)
	if skill.accuracy != 100:
		bits.append("accuracy %d" % skill.accuracy)
	if skill.uses_stat_contest:
		bits.append("contested against %s" % Stats.stat_name(skill.contest_stat))
	if skill.ignores_defense > 0:
		bits.append("ignores %d%% defence" % skill.ignores_defense)
	w("- %s - %s" % [head, "; ".join(bits)])
	if _owners.has(key):
		w("  - Who has it: %s" % ", ".join(_owners[key]))
	if skill.description != "":
		w("  - Says: %s" % skill.description.replace("\n", " "))
	for effect in skill.effects:
		w("  - Effect: %s" % fmt(effect))
	for rank in skill.ranks:
		w("  - Rank from level %d%s: %s" % [rank.level, (" \"%s\"" % rank.title) if rank.title != "" else "", "; ".join(props(rank, ["level", "title"]))])
	var other := props(skill, ["name", "description", "required_level", "spell_slot_level", "is_secondary",
		"reaction_only", "is_reactive", "reacts_when", "min_range", "max_range", "melee", "aoe_radius", "aoe_shape",
		"aoe_width", "targets_ally", "deals_damage", "ability_modifier", "damage_type", "scaling_stat", "accuracy",
		"uses_stat_contest", "contest_stat", "ignores_defense", "effects", "ranks"])
	if not other.is_empty():
		w("  - Settings: %s" % "; ".join(other))


func _combatant_entry(key: String, c: CombatantDefinition, skills: Dictionary):
	w("### %s (`%s`)" % [c.name, key])
	w("")
	if "description" in c and str(c.description) != "":
		w(str(c.description).replace("\n", " "))
		w("")
	if not (c is BattleObjectDefinition):
		w("- Main stat %s, secondary %s; health %d at level 1, %d at 64; movement %d" % [Stats.stat_name(c.main_stat),
			Stats.stat_name(c.secondary_stat), c.hp_at(1), c.hp_at(64), c.movement])
		var names := []
		for s in c.skills:
			names.append(skills[s].name if skills.has(s) else s)
		w("- Skills: %s" % ", ".join(names))
		for passive in c.passives:
			w("- Passive **%s**: %s" % [passive.name, _passive_text(passive)])
	var other := props(c, ["name", "description", "skills", "passives", "main_stat", "secondary_stat", "movement"])
	if not other.is_empty():
		w("- Settings: %s" % "; ".join(other))
	w("")
