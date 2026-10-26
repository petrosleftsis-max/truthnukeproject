extends RefCounted
class_name OutsideMoves
## What the party's moves do outside a fight (docs/outside_combat_plan.md, Phase
## 1; the designer, 2026-10-26). Every move somebody has is on the exploration
## panel (OutsideMovesPanel), but only some do anything out here, each by one of
## a few shared uses (Use) read off what it does in a fight. The rest are greyed:
## only in a fight, for now - a damaging move will start an ambush or break a
## wall (Phase 2).
##
## Paying: a spell cast out here spends a real casting (Campaign.spend_gate_outside:
## off the next fight's gates, or straight off a dungeon's), through its own gate
## or a deeper one, as in a fight. A spell the designer marked Out Of Combat is
## paid through the Gates of Iris first, while it has castings there and is no
## deeper than the gate Iris matches (Stats.OUTSIDE_GATES; the order is a
## PROPOSAL). Find Familiar pays its own gate exactly; Invisibility pays through
## Iris alone, as it always has.
##
## Noise: a move's Noise is heard on a watched map from whoever used it (sound) -
## Quiet turns the guards within its Noise Tiles to it, Loud sends them to look.
## Unmarked plays as Silent.

enum Use { NONE, MEND, REVIVE, SPEED, INVISIBILITY, FAMILIAR }

const USE_NAMES := {
	Use.NONE: "Only in a fight",
	Use.MEND: "Mends a wound",
	Use.REVIVE: "Brings somebody back",
	Use.SPEED: "Quickens the party's pace",
	Use.INVISIBILITY: "Hides the party",
	Use.FAMILIAR: "Calls a familiar",
}

## How much faster the party walks while hurried (Use.SPEED), and for how long
## when the move gives no Outside Seconds - PROPOSAL test values.
const HURRY := 1.5
const HURRY_SECONDS := 20


## Every move `key` has on a map, by key: their own skills and secondary actions
## and their path's, reached at the party's level - spells only once known
## (Campaign.knows_spell).
static func moves_of(key: String) -> Array:
	var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
	if definition == null:
		return []
	var known: Array = Array(definition.skills)
	for move in definition.secondary_skills:
		if not known.has(move):
			known.append(move)
	var path := SubclassDefinition.named(Campaign.subclass_of(key))
	if path != null and Campaign.party_level >= Stats.SUBCLASS_LEVEL:
		for move in path.skills:
			if not known.has(move):
				known.append(move)
	var found := []
	for move in known:
		var skill: SkillDefinition = SkillDatabase.skills.get(move)
		if skill == null or skill is ItemDefinition or skill.required_level > Campaign.party_level:
			continue
		if Combat.is_spell(skill) and not Campaign.knows_spell(key, move):
			continue
		found.append(move)
	return found


## What `skill` does outside a fight.
static func use_of(skill: SkillDefinition) -> int:
	if skill == null:
		return Use.NONE
	if skill.outside_only():
		return Use.FAMILIAR
	if skill.outside_gate > 0 and _has(skill, EffectDefinition.EffectType.INVISIBLE):
		return Use.INVISIBILITY
	if skill.deals_damage:
		return Use.NONE
	if _has(skill, EffectDefinition.EffectType.REVIVE):
		return Use.REVIVE
	if _has(skill, EffectDefinition.EffectType.HEAL):
		return Use.MEND
	if skill.targets_ally and skill.all_effects().any(func(effect): return _quickens(effect)):
		return Use.SPEED
	return Use.NONE


static func _has(skill: SkillDefinition, type: int) -> bool:
	return skill.all_effects().any(func(effect): return effect != null and effect.type == type)


## A boost to how far somebody walks: Run's doubling, Quicken's extra.
static func _quickens(effect: EffectDefinition) -> bool:
	if effect == null or effect.stat != "movement":
		return false
	if effect.type == EffectDefinition.EffectType.STAT_MULTIPLIER:
		return true
	return effect.type == EffectDefinition.EffectType.STAT_MODIFIER and effect.modifier_amount > 0


## Whether the panel's Out Of Combat Only shows `skill`: marked so, or cast only
## out here by its nature (Find Familiar, Invisibility's Iris).
static func shown_out_of_combat(skill: SkillDefinition) -> bool:
	return skill != null and (skill.out_of_combat or skill.outside_only() or skill.outside_gate > 0)


## --- Noise ---


## How loud `skill` is out here, in a few words: "Silent", "Quiet: 4 tiles",
## "Loud: 6 tiles" - and "Noise unmarked" until the designer says.
static func noise_fact(skill: SkillDefinition) -> String:
	match skill.noise:
		SkillDefinition.Loudness.SILENT:
			return "Silent"
		SkillDefinition.Loudness.QUIET:
			return "Quiet: %s tiles" % CharacterSheet._figure(skill.noise_tiles)
		SkillDefinition.Loudness.LOUD:
			return "Loud: %s tiles" % CharacterSheet._figure(skill.noise_tiles)
	return "Noise unmarked"


## `key` used `skill` on `scene`'s map: heard, if it makes a sound and guards
## are listening.
static func sound(scene: Node, key: String, skill: SkillDefinition):
	if scene == null or skill == null or skill.noise_tiles <= 0.0:
		return
	if skill.noise != SkillDefinition.Loudness.QUIET and skill.noise != SkillDefinition.Loudness.LOUD:
		return
	var watch = scene.get("stealth")
	if watch == null or not is_instance_valid(watch):
		return
	var party = scene.get("party")
	var sprite = party.sprite_for(key) if party != null else null
	var at: Vector2 = sprite.global_position if sprite != null else scene.party_position()
	watch.make_noise(at, skill.noise_tiles, skill.noise == SkillDefinition.Loudness.LOUD)


## --- Paying ---


## The Iris gate a marked `skill` may be paid through, or 0: the shallowest one
## matching a gate at least as deep as the spell's.
static func iris_gate_for(skill: SkillDefinition) -> int:
	if skill == null or not skill.out_of_combat or skill.deals_damage or skill.spell_slot_level <= 0:
		return 0
	for gate in range(1, Stats.OUTSIDE_GATES.size()):
		if skill.spell_slot_level <= Stats.OUTSIDE_GATES[gate].matches:
			return gate
	return 0


## How `key` would pay for `skill` now: {"free": true} for something with no
## gate, {"iris": gate} or {"gate": gate}, or {} when they cannot. `exact`
## pays only the spell's own gate (Find Familiar).
static func payment(key: String, skill: SkillDefinition, exact: bool = false) -> Dictionary:
	if skill.spell_slot_level <= 0:
		return {"free": true}
	var iris := iris_gate_for(skill)
	if iris > 0:
		var outside := Campaign.outside_gates_left(key)
		if iris < outside.size() and outside[iris] > 0:
			return {"iris": iris}
	var left := Campaign.gates_left_outside(key)
	var deepest := skill.spell_slot_level if exact else left.size() - 1
	for gate in range(skill.spell_slot_level, mini(deepest, left.size() - 1) + 1):
		if left[gate] > 0:
			return {"gate": gate}
	return {}


## Pays for `skill` as payment says. What was paid, or {} and nothing spent.
static func pay(key: String, skill: SkillDefinition, exact: bool = false) -> Dictionary:
	var paid := payment(key, skill, exact)
	if paid.has("iris") and not Campaign.spend_outside_gate(key, paid.iris):
		return {}
	if paid.has("gate") and not Campaign.spend_gate_outside(key, paid.gate):
		return {}
	return paid


## What paying `paid` reads as in the log: " through the Gates of World".
static func paid_through(paid: Dictionary) -> String:
	if paid.has("iris"):
		return " through the %s" % Stats.outside_gate_name(paid.iris)
	if paid.has("gate"):
		return " through the %s" % Stats.gate_name(paid.gate)
	return ""


## Why `key` could not pay for `skill` now, or "".
static func cannot_pay(key: String, skill: SkillDefinition, exact: bool = false) -> String:
	if not payment(key, skill, exact).is_empty():
		return ""
	return "%s has no castings of %s%s left" % [Campaign.display_name_of(key), Stats.short_gate_name(skill.spell_slot_level),
		"" if exact or skill.spell_slot_level >= Stats.GATE_NAMES.size() - 1 else " or deeper"]


## --- Using them ---


## Who a mend from `skill` would land on: everybody hurt for an area heal, or
## the worst hurt - by the share of their health gone - for one aimed at
## somebody. Standing members only.
static func mend_targets(skill: SkillDefinition) -> Array:
	var hurt := []
	for member in Campaign.party_members():
		if member.hp < member.max_hp:
			hurt.append(member)
	if hurt.is_empty():
		return []
	if skill.aoe_radius > 0:
		return hurt.map(func(member): return member.key)
	hurt.sort_custom(func(a, b): return float(a.hp) / a.max_hp < float(b.hp) / b.max_hp)
	return [hurt[0].key]


## Why `key` could not use `move` on `scene`'s map right now, or "" when they
## could.
static func refusal(scene: Node, key: String, move: String) -> String:
	var skill: SkillDefinition = SkillDatabase.skills.get(move)
	var kind := use_of(skill)
	if kind == Use.NONE:
		return "Only in a fight, for now" if skill != null and skill.deals_damage else "Only in a fight"
	var watch = scene.get("stealth") if scene != null else null
	if watch != null and not is_instance_valid(watch):
		watch = null
	match kind:
		Use.FAMILIAR:
			return "Only on a watched map" if watch == null else watch.familiar_refusal()
		Use.INVISIBILITY:
			return "Only on a watched map" if watch == null else watch.invisibility_refusal()
	if not Campaign.is_alive(key):
		return "%s is down" % Campaign.display_name_of(key)
	if scene != null and scene.has_method("is_holding") and scene.is_holding():
		return "Not now"
	if watch != null and watch.spotted_by != null:
		return "Too late for that"
	match kind:
		Use.MEND:
			if mend_targets(skill).is_empty():
				return "Nobody is hurt"
		Use.REVIVE:
			if Campaign.fallen_members().is_empty():
				return "Nobody has fallen"
		Use.SPEED:
			if scene != null and scene.has_method("hurried") and scene.hurried():
				return "Already hurrying"
	return cannot_pay(key, skill)


## `key` uses `move` on `scene`'s map. False, and nothing spent, when they
## cannot (refusal).
static func use(scene: Node, key: String, move: String) -> bool:
	if refusal(scene, key, move) != "":
		return false
	var skill: SkillDefinition = SkillDatabase.skills[move]
	var kind := use_of(skill)
	match kind:
		Use.FAMILIAR:
			return scene.stealth.summon_familiar()
		Use.INVISIBILITY:
			scene.stealth.stealth_bar().open_picker()
			return true
	var who := Campaign.display_name_of(key)
	var said := ""
	match kind:
		Use.MEND:
			var targets := mend_targets(skill)
			var paid := pay(key, skill)
			if paid.is_empty():
				return false
			var entry := _entry_of(key)
			var heal: EffectDefinition = null
			for effect in skill.all_effects():
				if effect != null and effect.type == EffectDefinition.EffectType.HEAL:
					heal = effect
					break
			var mended := []
			for target in targets:
				var amount := 0 if heal.heals_share_only else CharacterSheet.heal_on_the_map(entry, skill, heal)
				var most: int = Campaign.party_state.get(target, {}).get("max_hp", 0)
				amount += roundi(most * heal.heal_share_of_health)
				var gained := Campaign.mend(target, amount)
				mended.append("%s %d" % [Campaign.display_name_of(target), gained])
			said = "[color=yellow]%s[/color] casts %s%s: [color=lightgreen]%s[/color] health back.\n" % [
				who, skill.name, paid_through(paid), ", ".join(mended)]
		Use.REVIVE:
			var fallen: String = Campaign.fallen_members()[0]
			var revive: EffectDefinition = null
			for effect in skill.all_effects():
				if effect != null and effect.type == EffectDefinition.EffectType.REVIVE:
					revive = effect
					break
			var paid := pay(key, skill)
			if paid.is_empty() or not Campaign.revive_outside(fallen, revive):
				return false
			said = "[color=yellow]%s[/color] casts %s%s: [color=lightgreen]%s[/color] is back up, with %d health - and %d%% weaker until a long rest.\n" % [
				who, skill.name, paid_through(paid), Campaign.display_name_of(fallen), Campaign.party_state[fallen].hp, roundi(revive.revive_weakening * 100.0)]
		Use.SPEED:
			var paid := pay(key, skill)
			if paid.is_empty():
				return false
			var seconds := skill.outside_seconds if skill.outside_seconds > 0 else HURRY_SECONDS
			scene.hurry(HURRY, seconds)
			said = "[color=yellow]%s[/color] uses %s%s: the party hurries on for %d seconds.\n" % [who, skill.name, paid_through(paid), seconds]
	if scene.has_method("log_message"):
		scene.log_message(said)
	# The portraits down the left read health off the party: drawn again.
	if scene.has_method("_refresh_party_panel"):
		scene._refresh_party_panel()
	sound(scene, key, skill)
	return true


## `key` as the character sheet has them away from a fight.
static func _entry_of(key: String) -> Dictionary:
	for member in Campaign.party_members():
		if member.key == key:
			return CharacterSheet.map_entry_of(member)
	return {}


## The spells anybody standing could cast to some purpose right now, other than
## Invisibility and Find Familiar (which StealthBar.outside_spell asks about
## itself) and a hurry - always ready, it would have G ask "which?" every time:
## [{"key": caster, "move": spell}], leader first.
static func ready_spells(scene: Node) -> Array:
	var found := []
	var taken := {}
	for key in Campaign.living_party():
		for move in moves_of(key):
			var skill: SkillDefinition = SkillDatabase.skills[move]
			if not Combat.is_spell(skill) or taken.has(move):
				continue
			var kind := use_of(skill)
			if kind == Use.NONE or kind == Use.FAMILIAR or kind == Use.INVISIBILITY or kind == Use.SPEED:
				continue
			if refusal(scene, key, move) == "":
				found.append({"key": key, "move": move})
				taken[move] = true
	return found
