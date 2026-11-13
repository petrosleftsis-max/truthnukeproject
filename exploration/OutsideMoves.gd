extends RefCounted
class_name OutsideMoves
## What the party's moves do outside a fight (docs/outside_combat_plan.md; the
## designer, 2026-10-26). Every move somebody has is on the exploration panel
## (OutsideMovesPanel), and each does one of a few shared things out here (Use):
## the skill's Outside Use, or - Automatic - what it is read to do from its
## effects. The rest are greyed: only in a fight.
##
## On guards (a watched map), a move lands on the one the pointer is on or the
## nearest in its reach (StealthWatch.move_target): Blind, Scare and Confuse put
## him in a spellbound mood, Read finds out his round, Switch Off Magic stills a
## ward or a sensor. A damaging move, or a trap, is aimed (MapAim, "Aimed on a map"
## below): if what it covers catches a guard, or a placed fight, the fight starts and
## they take it before anybody's turn (StealthWatch.strike, ExplorationScene.open_fight_with,
## paid in the fight); a wall in it comes down (ExplorationScene.break_wall); nobody
## there and it is simply spent. Blink steps the party ahead, Fly lifts it over low things, a
## Lure draws guards to a shimmer ahead, a Hiding Spot is made where the leader
## stands. Only a spell, an item or the move of somebody
## who Breaks Walls (Enfina) knocks a wall down (breaks_walls). Damaging items
## carried are on the panel too (items_of).
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

enum Use { NONE, MEND, REVIVE, SPEED, INVISIBILITY, FAMILIAR, BLIND, SCARE, CONFUSE, READ, SWITCH_OFF_MAGIC,
	AMBUSH, BLINK, FLY, LURE, HIDING_SPOT, TRAP, COUNTER_TRAP, COMPANY, SEEMING, MISLEAD, SUGGEST, DETECT_MAGIC, ARCANE_EYE, FLARE, SHRINK,
	BECKON }

const USE_NAMES := {
	Use.NONE: "Only in a fight",
	Use.MEND: "Mends a wound",
	Use.REVIVE: "Brings somebody back",
	Use.SPEED: "Quickens the party's pace",
	Use.INVISIBILITY: "Hides the party",
	Use.FAMILIAR: "Calls a familiar, or sends it back to her shoulder",
	Use.BLIND: "Strikes a guard blind",
	Use.SCARE: "Scares a guard off",
	Use.CONFUSE: "Bewilders a guard",
	Use.READ: "Learns a guard's round",
	Use.SWITCH_OFF_MAGIC: "Stills a ward or a magic sensor",
	Use.AMBUSH: "Aimed: a hit starts a fight, and whoever it hit takes it first. Or it breaks a wall",
	Use.BLINK: "Steps the party ahead, over anything",
	Use.FLY: "Lifts the party over low things",
	Use.LURE: "Leaves a lure for the guards",
	Use.HIDING_SPOT: "Makes somewhere to hide",
	Use.TRAP: "Aimed: lays a trap there",
	Use.COUNTER_TRAP: "Hacks a magical trap's casting apart as it goes off",
	Use.COMPANY: "Hides everybody but Cyrus, who all follow him",
	Use.SEEMING: "Makes the party look like the guards here",
	Use.MISLEAD: "Hides them, and sends a double off for the guards to chase",
	Use.SUGGEST: "Sends a guard off on an errand",
	Use.DETECT_MAGIC: "Shows every ward, magic sensor and magical trap",
	Use.ARCANE_EYE: "An eye to steer that nothing notices",
	Use.FLARE: "Goes up ahead of him: lights the ground, and every guard hears it",
	Use.SHRINK: "Whoever leads gets small enough for grates and small gaps",
	Use.BECKON: "A light leads a guard off, his eyes on nothing else",
}

## SkillDefinition.outside_use, as a Use - -1 for Automatic.
const FROM_FIELD := [-1, Use.NONE, Use.MEND, Use.REVIVE, Use.SPEED, Use.BLIND, Use.SCARE, Use.CONFUSE, Use.READ,
	Use.SWITCH_OFF_MAGIC, Use.BLINK, Use.FLY, Use.LURE, Use.HIDING_SPOT, Use.TRAP, Use.COUNTER_TRAP, Use.COMPANY, Use.SEEMING, Use.MISLEAD,
	Use.SUGGEST, Use.DETECT_MAGIC, Use.ARCANE_EYE, Use.FLARE, Use.SHRINK, Use.BECKON]

## How long each lasts when the move gives no Outside Seconds - PROPOSAL test
## values, as are the rest below.
const SECONDS := {Use.BLIND: 12, Use.SCARE: 15, Use.CONFUSE: 20, Use.SWITCH_OFF_MAGIC: 60, Use.FLY: 20,
	Use.LURE: 10, Use.HIDING_SPOT: 60, Use.BECKON: 20}
## A tether out of a fight frays by this much a second (the designer, 2026-11-05), so a
## tethered move lasts its Tether Strength over this, whatever else it says. One to a
## character there too: tying another lets go of the first (StealthWatch "Tethers").
const TETHER_PER_SECOND := 5.0
## How far a Blink goes when the move's reach says nothing, and at most.
const BLINK_TILES := 3
const BLINK_MOST := 6
## How far ahead a Lure lands at most, and how far off guards hear it.
const LURE_AHEAD := 4
const LURE_TILES := 6.0
## What the Outside Spell key offers: what needs somebody to land on, so it is
## to some purpose only now and then.
const ON_G := [Use.MEND, Use.REVIVE, Use.BLIND, Use.SCARE, Use.CONFUSE, Use.READ, Use.SWITCH_OFF_MAGIC, Use.SUGGEST, Use.BECKON]
## The moods Blind, Scare and Confuse put a guard in.
const MOODS := {Use.BLIND: Guard.Mood.BLINDED, Use.SCARE: Guard.Mood.FRIGHTENED, Use.CONFUSE: Guard.Mood.BEWILDERED}

## What Arcane Eye looks like, and who notices it (nobody).
const ARCANE_EYE_FORM := "res://data/familiars/arcane_eye.tres"
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
		if skill == null or skill is ItemDefinition or CharacterSheet.comes_in(skill) > Campaign.party_level:
			continue
		if Combat.is_spell(skill) and (not Campaign.knows_spell(key, move) or not Campaign.is_prepared(key, move)):
			continue
		found.append(move)
	return found


## The skill or item `key` names, or null.
static func definition_of(key: String) -> SkillDefinition:
	if SkillDatabase.skills.has(key):
		return SkillDatabase.skills[key]
	return ItemDatabase.item(key)


## The damaging things `key` carries, by item key, each once: bombs and the
## like, to spring an ambush with or knock a wall down.
static func items_of(key: String) -> Array:
	var found := []
	for item_key in Campaign.combat_items_of(key):
		var item: ItemDefinition = ItemDatabase.item(item_key)
		if item != null and item.deals_damage and not found.has(item_key):
			found.append(item_key)
	return found


## Whether `key` using `skill` knocks down a breakable wall: a spell, an item,
## or anything damaging of somebody who Breaks Walls.
static func breaks_walls(key: String, skill: SkillDefinition) -> bool:
	if skill == null or not skill.deals_damage:
		return false
	if skill is ItemDefinition or Combat.is_spell(skill):
		return true
	var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
	return definition != null and definition.breaks_walls


## What `skill` does outside a fight.
static func use_of(skill: SkillDefinition) -> int:
	if skill == null:
		return Use.NONE
	# What it says first: a gate of its own is no reason to take it for Invisibility (Seeming).
	if skill.outside_use > 0 and skill.outside_use < FROM_FIELD.size():
		return FROM_FIELD[skill.outside_use]
	if _has(skill, EffectDefinition.EffectType.FAMILIAR):
		return Use.FAMILIAR
	if skill.outside_gate > 0 and _has(skill, EffectDefinition.EffectType.INVISIBLE):
		return Use.INVISIBILITY
	if skill.deals_damage:
		return Use.AMBUSH
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
	# Heard from where it went up, not from whoever sent it (Use.FLARE).
	if use_of(skill) == Use.FLARE:
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
	if skill == null or skill.deals_damage or skill.spell_slot_level <= 0:
		return 0
	# The one written on it, or else the shallowest that matches, for one marked Out Of Combat.
	if skill.outside_gate > 0:
		return skill.outside_gate
	if not skill.out_of_combat:
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


## Why `key` could not open a fight with `skill`, or "": a spell with no casting
## of its gate or deeper left for that fight, which spends one as it does any
## casting there (Combat._pay_for_cast) - the Gates of Iris are for outside a
## fight, not for that (the designer, 2026-10-31: "if it is a spell that costs a
## gate, then the gate is used like normal").
static func cannot_open_with(key: String, skill: SkillDefinition) -> String:
	if not Combat.is_spell(skill) or skill.spell_slot_level <= 0:
		return ""
	var left := Campaign.gates_left_outside(key)
	for gate in range(skill.spell_slot_level, left.size()):
		if left[gate] > 0:
			return ""
	return "%s has no castings of %s%s left" % [Campaign.display_name_of(key), Stats.short_gate_name(skill.spell_slot_level),
		"" if skill.spell_slot_level >= Stats.GATE_NAMES.size() - 1 else " or deeper"]


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


## How long what `skill` does out here lasts, as `kind`.
static func seconds_of(skill: SkillDefinition, kind: int) -> int:
	if skill.tethered:
		return ceili(float(skill.tether_strength) / TETHER_PER_SECOND)
	return skill.outside_seconds if skill.outside_seconds > 0 else SECONDS.get(kind, HURRY_SECONDS)


## The guard `skill` would land on as `kind`, on `watch`'s map, or null.
static func guard_for(watch, skill: SkillDefinition, kind: int) -> Guard:
	if watch == null:
		return null
	match kind:
		Use.BLIND, Use.SCARE, Use.CONFUSE, Use.SUGGEST, Use.BECKON:
			return watch.move_target(skill, watch.can_spellbind)
		Use.READ:
			return watch.move_target(skill, func(guard): return not guard.patrol_points().is_empty() and not watch.route_known(guard))
		Use.SWITCH_OFF_MAGIC:
			return watch.move_target(skill, func(guard): return (guard.kind == Guard.Kind.WARD or guard.kind == Guard.Kind.SENSOR) and not guard.switched_off())
		Use.AMBUSH:
			return watch.move_target(skill, watch.can_open_on)
	return null


## Why `key` could not use `move` on `scene`'s map right now, or "" when they
## could.
static func refusal(scene: Node, key: String, move: String) -> String:
	var skill: SkillDefinition = definition_of(move)
	if skill is ItemDefinition and Campaign.count_of(key, move) <= 0:
		return "%s has none left" % Campaign.display_name_of(key)
	var kind := use_of(skill)
	if kind == Use.NONE:
		return "Only in a fight"
	if kind == Use.COUNTER_TRAP:
		return "Only as a magical trap goes off"
	var watch = scene.get("stealth") if scene != null else null
	if watch != null and not is_instance_valid(watch):
		watch = null
	match kind:
		Use.FAMILIAR:
			var keeper = scene.get("familiar_keeper") if scene != null else null
			if keeper != null and keeper.familiar != null:
				return "On %s's shoulder already" % Campaign.display_name_of(keeper.caster) if keeper.perched() else ""
			return scene.familiar_refusal() if scene != null and scene.has_method("familiar_refusal") else "Only on a map"
		Use.INVISIBILITY:
			if watch == null:
				return "Only on a watched map"
			# Somebody to hide and a casting for them: who, its picker asks.
			var could: Array = watch.could_go_invisible()
			return watch.invisibility_refusal(could.slice(0, 1) if not could.is_empty() else [])
		Use.ARCANE_EYE:
			var keeper = scene.get("familiar_keeper") if scene != null else null
			if keeper == null:
				return "Only on a map"
			if keeper.familiar != null:
				return "A familiar is out already"
	if not Campaign.is_alive(key):
		return "%s is down" % Campaign.display_name_of(key)
	if scene != null and scene.has_method("is_holding") and scene.is_holding():
		return "Not now"
	if watch != null and watch.spotted_by != null:
		return "Too late for that"
	var party = scene.get("party") if scene != null else null
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
		Use.BLIND, Use.SCARE, Use.CONFUSE, Use.SUGGEST, Use.BECKON:
			if watch == null:
				return "Only where guards watch"
			if guard_for(watch, skill, kind) == null:
				return "Nobody in reach it could take hold of"
		Use.DETECT_MAGIC:
			if watch == null:
				return "Only where guards watch"
		Use.READ:
			if watch == null:
				return "Only where guards watch"
			if guard_for(watch, skill, kind) == null:
				return "Nobody in reach with a round still to learn"
		Use.SWITCH_OFF_MAGIC:
			if watch == null:
				return "Only where guards watch"
			if guard_for(watch, skill, kind) == null:
				return "No ward or magic sensor in reach"
		Use.AMBUSH:
			# What it lands on is chosen as it is aimed (MapAim), and the fight pays for
			# its opening blow - an ambush's, or a placed fight's.
			if skill.shoots_out_lights and _any_light_to_shoot(scene):
				return ""
			return cannot_open_with(key, skill) if _something_to_strike(scene) else "Nothing on this map to strike"
		Use.COMPANY:
			if watch == null:
				return "Only where guards watch"
			var refused: String = watch.company_refusal()
			if refused != "":
				return refused
		Use.BLINK, Use.FLY:
			if party != null and party.rooted:
				return "Not while standing still for something"
			if kind == Use.FLY and scene != null and scene.has_method("flying") and scene.flying():
				return "Already flying"
		Use.LURE, Use.TRAP, Use.SEEMING, Use.MISLEAD:
			if watch == null:
				return "Only where guards watch"
		Use.HIDING_SPOT:
			if watch == null:
				return "Only where guards watch"
			if watch.leader_hiding():
				return "Hidden already"
	return cannot_pay(key, skill)


## `key` uses `move` on `scene`'s map. False, and nothing spent, when they
## cannot (refusal).
static func use(scene: Node, key: String, move: String) -> bool:
	if refusal(scene, key, move) != "":
		return false
	var skill: SkillDefinition = definition_of(move)
	var kind := use_of(skill)
	var watch = scene.get("stealth")
	if watch != null and not is_instance_valid(watch):
		watch = null
	# Aimed first, on this machine's own screen, whichever machine this is.
	if kind == Use.AMBUSH or kind == Use.TRAP:
		return scene.take_aim(key, move)
	# On a joiner the host's map is where it is used, as this player's - but for
	# whom it hides, chosen here (Net; the picker's choice goes there too).
	var net = scene.get_node_or_null("/root/Net")
	if net != null and net.follows() and kind != Use.INVISIBILITY:
		net.use_move(key, move)
		return true
	match kind:
		Use.FAMILIAR:
			if scene.familiar_keeper.familiar != null:
				return scene.familiar_keeper.perch()
			return scene.summon_familiar()
		Use.INVISIBILITY:
			watch.stealth_bar().open_picker()
			return true
	var who := Campaign.display_name_of(key)
	var said := ""
	var target: Guard = guard_for(watch, skill, kind)
	var party = scene.get("party")
	var at: Vector2 = scene.party_position()
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
			for one in targets:
				var amount := 0 if heal.heals_share_only else CharacterSheet.heal_on_the_map(entry, skill, heal)
				var most: int = Campaign.party_state.get(one, {}).get("max_hp", 0)
				amount += roundi(most * heal.heal_share_of_health)
				var gained := Campaign.mend(one, amount)
				mended.append("%s %d" % [Campaign.display_name_of(one), gained])
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
		Use.BLIND, Use.SCARE, Use.CONFUSE, Use.READ, Use.SWITCH_OFF_MAGIC, Use.SUGGEST, Use.BECKON:
			var paid := pay(key, skill)
			if paid.is_empty():
				return false
			said = _do_to(watch, key, skill, kind, target, paid_through(paid))
		Use.DETECT_MAGIC:
			var paid := pay(key, skill)
			if paid.is_empty():
				return false
			var seconds := seconds_of(skill, kind)
			watch.begin_detecting(seconds)
			said = "[color=yellow]%s[/color] casts %s%s: for %d seconds every ward, sensor and magical trap here shows.\n" % [who, skill.name, paid_through(paid), seconds]
		Use.ARCANE_EYE:
			var paid := pay(key, skill)
			if paid.is_empty():
				return false
			scene.familiar_keeper.summon(key, load(ARCANE_EYE_FORM))
			said = "[color=yellow]%s[/color] casts %s%s: she sees through it, and nothing sees it.\n" % [who, skill.name, paid_through(paid)]
		Use.BLINK:
			var reach := mini(skill.max_range if skill.max_range > 0 else BLINK_TILES, BLINK_MOST)
			if not scene.blink(reach):
				if scene.has_method("log_message"):
					scene.log_message("Nowhere to land.\n")
				return false
			var paid := pay(key, skill)
			said = "[color=yellow]%s[/color] uses %s%s, and the party is through.\n" % [who, skill.name, paid_through(paid)]
		Use.FLY:
			var paid := pay(key, skill)
			if paid.is_empty():
				return false
			var seconds := seconds_of(skill, kind)
			scene.fly(seconds)
			said = "[color=yellow]%s[/color] uses %s%s: the party rises over low things for %d seconds.\n" % [who, skill.name, paid_through(paid), seconds]
		Use.SHRINK:
			var paid := pay(key, skill)
			if paid.is_empty():
				return false
			var seconds := seconds_of(skill, kind)
			scene.shrink_party(seconds)
			if watch != null and skill.tethered:
				watch.tie_outside(key, skill, func(): if is_instance_valid(scene): scene.shrink_party(0.0))
			said = "[color=yellow]%s[/color] casts %s%s: for %d seconds whoever leads fits through grates and small gaps.\n" % [who, skill.name, paid_through(paid), seconds]
		Use.FLARE:
			var paid := pay(key, skill)
			if paid.is_empty():
				return false
			var way: Vector2 = party.held_direction()
			if way == Vector2.ZERO:
				way = Vector2.LEFT if party.facing_left() else Vector2.RIGHT
			var there: Vector2 = watch._ground_toward(at, way, skill.max_range) if watch != null else at
			var seconds := seconds_of(skill, kind)
			scene.flare_up(there, seconds)
			if watch != null:
				watch.make_noise(there, skill.noise_tiles, true)
			said = "[color=yellow]%s[/color] casts %s%s: it hangs over the ground ahead for %d seconds, and everybody hears it.\n" % [who, skill.name, paid_through(paid), seconds]
		Use.LURE:
			var way: Vector2 = party.held_direction()
			if way == Vector2.ZERO:
				way = Vector2.LEFT if party.facing_left() else Vector2.RIGHT
			# One with a hearing of its own (Phantom Noise) goes as far as its reach.
			var ahead: int = skill.max_range if skill.lure_tiles > 0.0 and skill.max_range > 0 else mini(skill.max_range if skill.max_range > 0 else LURE_AHEAD, LURE_AHEAD)
			var there: Vector2 = watch._ground_toward(at, way, ahead)
			var paid := pay(key, skill)
			if paid.is_empty():
				return false
			var lure := Decoy.new()
			lure.left = seconds_of(skill, kind)
			scene.add_child(lure)
			lure.global_position = there
			watch.make_noise(there, skill.lure_tiles if skill.lure_tiles > 0.0 else LURE_TILES, true)
			if skill.tethered:
				watch.tie_outside(key, skill, func(): if is_instance_valid(lure): lure.queue_free(), lure)
			said = "[color=yellow]%s[/color] uses %s%s: something stirs ahead, and the guards near it go to look.\n" % [who, skill.name, paid_through(paid)]
		Use.SEEMING:
			var paid := pay(key, skill)
			if paid.is_empty():
				return false
			var seconds := seconds_of(skill, kind)
			watch.begin_seeming(seconds)
			said = "[color=yellow]%s[/color] casts %s%s: for %d seconds the party looks like the guards here.\n" % [who, skill.name, paid_through(paid), seconds]
		Use.MISLEAD:
			var way: Vector2 = party.held_direction()
			if way == Vector2.ZERO:
				way = Vector2.LEFT if party.facing_left() else Vector2.RIGHT
			var there: Vector2 = watch._ground_toward(at, way, LURE_AHEAD)
			var paid := pay(key, skill)
			if paid.is_empty():
				return false
			var seconds := seconds_of(skill, kind)
			var double := Decoy.new()
			double.left = seconds
			scene.add_child(double)
			double.global_position = there
			watch.make_noise(there, LURE_TILES, true)
			watch.slip_unseen(key, seconds)
			said = "[color=yellow]%s[/color] casts %s%s: unseen for %d seconds, and a double of them goes on ahead.\n" % [who, skill.name, paid_through(paid), seconds]
		Use.HIDING_SPOT:
			var paid := pay(key, skill)
			if paid.is_empty():
				return false
			var seconds := seconds_of(skill, kind)
			watch.add_hiding_spot(HidingSpot.new(), _tile_centre(watch, at), seconds)
			said = "[color=yellow]%s[/color] uses %s%s: cover, where there was none, for %d seconds.\n" % [who, skill.name, paid_through(paid), seconds]
		Use.COMPANY:
			var paid := pay(key, skill)
			if paid.is_empty():
				return false
			var seconds := seconds_of(skill, kind)
			watch.begin_company(seconds)
			said = "[color=yellow]%s[/color] casts %s%s: for %d seconds everybody but Cyrus is unseen, and follows him.\n" % [who, skill.name, paid_through(paid), seconds]
	if scene.has_method("log_message"):
		scene.log_message(said)
	# The portraits down the left read health off the party: drawn again.
	if scene.has_method("_refresh_party_panel"):
		scene._refresh_party_panel()
	sound(scene, key, skill)
	return true


## --- Aimed on a map ---
##
## A damaging move, or a trap, needs somewhere to go (the designer, 2026-11-07; MapAim shows it). What
## it covers, by the fight's count from whoever uses it, is what struck_at says: guards who would fight,
## a placed fight's marker, walls. If it catches anybody who fights the fight starts, and in it the
## move lands where it was aimed before anybody's turn (Combat "An ambush's opening blow"), paid there
## as any casting is. Otherwise it is spent out here, and no fight comes of it (the designer, 2026-11-07:
## "if a damaging spell hits a wall, no need to start a combat, except if its enough for the guards to
## notice the party"): a wall in it comes down if it can, and the noise brings guards to look, who may
## then notice the party as they notice anybody. With nobody there it lands where it lands, heard
## from there. Only something that covers an area can be let go at nobody; a blow at one somebody
## needs that somebody.

const NOWHERE := Vector2i(-99999, -99999)


## Whether anything on `scene`'s map could ever be struck.
static func _something_to_strike(scene: Node) -> bool:
	if scene == null:
		return false
	var watch = scene.get("stealth")
	if watch != null and is_instance_valid(watch) and watch.guards.any(func(guard): return watch.can_be_struck(guard)):
		return true
	if scene.has_method("placed_fights") and not scene.placed_fights().is_empty():
		return true
	return scene.has_method("walls") and scene.walls().any(func(wall): return is_instance_valid(wall) and not wall.broken)


## The tile `key` stands on, on `scene`'s map.
static func member_tile(scene: Node, key: String) -> Vector2i:
	var tile_map: TileMap = scene.get("_tile_map")
	var party = scene.get("party")
	var sprite = party.sprite_for(key) if party != null else null
	var at: Vector2 = sprite.global_position if sprite != null else scene.party_position()
	return tile_map.local_to_map(tile_map.to_local(at))


## Whether `skill` bursts round whoever uses it, with nowhere to aim it.
static func bursts_round_them(skill: SkillDefinition) -> bool:
	return skill.max_range <= 0 and skill.aoe_radius > 0


## Where it actually goes, pointed at `pointed` from `from`.
static func aim_from(skill: SkillDefinition, from: Vector2i, pointed: Vector2i) -> Vector2i:
	return from if bursts_round_them(skill) else pointed


## The trap's burst of `skill`, in tiles, for one that has one.
static func trap_effect_of(skill: SkillDefinition) -> EffectDefinition:
	for effect in skill.all_effects():
		if effect != null and effect.type == EffectDefinition.EffectType.TRAP:
			return effect
	return null


## Whether `aim` is in `key`'s reach with `skill`: the fight's count, and a clear line if it needs one.
static func in_reach(scene: Node, key: String, skill: SkillDefinition, aim: Vector2i) -> bool:
	var from := member_tile(scene, key)
	if bursts_round_them(skill):
		return aim == from
	var gap := absi(aim.x - from.x) + absi(aim.y - from.y)
	if gap > maxi(skill.max_range, 1) or gap < skill.min_range:
		return false
	return not skill.respects_blocking or gap <= 1 or scene.map_sight().clear(from, aim)


## Every tile `key` could aim `skill` at from where they stand.
static func reach_tiles(scene: Node, key: String, skill: SkillDefinition) -> Array:
	var from := member_tile(scene, key)
	var found := []
	var reach: int = 0 if bursts_round_them(skill) else maxi(skill.max_range, 1)
	var sight = scene.map_sight()
	for dx in range(-reach, reach + 1):
		var left: int = reach - absi(dx)
		for dy in range(-left, left + 1):
			var tile := from + Vector2i(dx, dy)
			if not sight.stops_sight(tile) and in_reach(scene, key, skill, tile):
				found.append(tile)
	return found


## What `skill` used by `key` covers, aimed at `aim`: as in a fight (Combat.get_impact_tiles), and a
## trap's burst for a trap.
static func strike_tiles(scene: Node, key: String, skill: SkillDefinition, aim: Vector2i) -> Array:
	var from := member_tile(scene, key)
	var tiles := _strike_shape(from, skill, aim)
	var trap := trap_effect_of(skill)
	if trap == null and not skill.respects_blocking:
		return tiles
	var sight = scene.map_sight()
	var round_the_aim: bool = trap != null or skill.aoe_radius <= 0 or skill.aoe_shape == SkillDefinition.AoEShape.DIAMOND
	var seen_from: Vector2i = aim if round_the_aim else from
	return tiles.filter(func(tile): return tile == seen_from or (not sight.stops_sight(tile) and sight.clear(seen_from, tile)))


## The shape of it, whatever is in the way.
static func _strike_shape(from: Vector2i, skill: SkillDefinition, aim: Vector2i) -> Array:
	var radius: int = skill.aoe_radius
	var shape: int = skill.aoe_shape
	var trap := trap_effect_of(skill)
	if trap != null:
		radius = trap.trap_burst_radius
		shape = SkillDefinition.AoEShape.DIAMOND
	if radius <= 0:
		return [aim]
	match shape:
		SkillDefinition.AoEShape.LINE:
			return Combat.get_line_tiles(from, aim, radius, skill.aoe_width)
		SkillDefinition.AoEShape.CONE:
			return Combat.get_cone_tiles(from, aim, radius)
	return Combat.get_diamond_tiles(aim, radius)


## What `skill` used by `key` and aimed at `aim` catches: {"tiles", "guards", "placed", "walls"}.
static func struck_at(scene: Node, key: String, skill: SkillDefinition, aim: Vector2i) -> Dictionary:
	var tiles := strike_tiles(scene, key, skill, aim)
	var found := {"tiles": tiles, "guards": [], "placed": null, "walls": []}
	var watch = scene.get("stealth")
	if watch != null and is_instance_valid(watch):
		for guard in watch.guards:
			if watch.can_be_struck(guard) and watch.tile_of(guard.global_position) in tiles:
				found.guards.append(guard)
	if scene.has_method("placed_fight_on"):
		found.placed = scene.placed_fight_on(tiles)
	# A wall is what stops the rest: whatever the shape of it touches is hit.
	if scene.has_method("walls_on"):
		found.walls = scene.walls_on(_strike_shape(member_tile(scene, key), skill, aim))
	return found


## Why `key` could not let `skill` go at `aim`, or "". Nothing spent by asking.
static func aim_refusal(scene: Node, key: String, skill: SkillDefinition, aim: Vector2i) -> String:
	if not in_reach(scene, key, skill, aim):
		return "Out of reach"
	if use_of(skill) == Use.TRAP:
		return "" if not scene.map_sight().stops_sight(aim) else "Not there"
	var struck := struck_at(scene, key, skill, aim)
	if not struck.guards.is_empty() or struck.placed != null:
		return ""
	if skill.shoots_out_lights and _light_to_shoot(scene, aim) != null:
		return ""
	if not struck.walls.is_empty():
		return "" if breaks_walls(key, skill) else "Only a spell, an item or Enfina's strength knocks a wall down"
	return "" if skill.aoe_radius > 0 else "Nobody there to hit"


## Whether there is a light anywhere on the map that a shot could put out.
static func _any_light_to_shoot(scene: Node) -> bool:
	var map = scene.get_node_or_null(ExplorationScene.MAP_NODE) if scene != null else null
	if map == null:
		return false
	for node in map.find_children("*", "Lamp", true, false):
		if node.lit and node.can_be_put_out:
			return true
	for node in map.find_children("*", "LightSource", true, false):
		if node.lit and not node.opening:
			return true
	return false


## The lamp or other light on `aim` that a shot could put out on a map, or null (SkillDefinition.shoots_out_lights).
static func _light_to_shoot(scene: Node, aim: Vector2i):
	var watch = scene.get("stealth")
	if watch != null and is_instance_valid(watch):
		for lamp in watch._lamps:
			if is_instance_valid(lamp) and lamp.lit and lamp.can_be_put_out and watch.tile_of(lamp.global_position) == aim:
				return lamp
	var map = scene.get_node_or_null(ExplorationScene.MAP_NODE)
	var tile_map = scene.get("_tile_map")
	if map == null or tile_map == null:
		return null
	for node in map.find_children("*", "LightSource", true, false):
		if node.lit and not node.opening and tile_map.local_to_map(tile_map.to_local(node.global_position)) == aim:
			return node
	return null


## `key` lets `move` go at `aim`. False, and nothing spent, when they cannot.
static func fire_at(scene: Node, key: String, move: String, aim: Vector2i) -> bool:
	if refusal(scene, key, move) != "":
		return false
	var skill: SkillDefinition = definition_of(move)
	if skill == null or aim_refusal(scene, key, skill, aim) != "":
		return false
	var kind := use_of(skill)
	var watch = scene.get("stealth")
	if watch != null and not is_instance_valid(watch):
		watch = null
	if kind == Use.TRAP:
		return _lay_trap(scene, watch, key, move, skill, aim)
	if kind != Use.AMBUSH:
		return false
	var struck := struck_at(scene, key, skill, aim)
	# A guard carrying a light, and a move that puts carried lights out (the dart): out it goes, from afar and silently,
	# and nobody fights.
	if skill.snuffs_carried_lights and watch != null:
		for guard in struck.guards:
			if is_instance_valid(guard) and not guard.knocked_out and guard.carries_light_tiles > 0.0 and not guard.torch_out:
				if pay(key, skill).is_empty():
					return false
				if skill is ItemDefinition:
					Campaign.take_item(key, move)
				watch.snuff_torch(guard, key)
				if scene.has_method("log_message"):
					scene.log_message("[color=yellow]%s[/color] puts out [color=yellow]%s[/color]'s light with %s, from afar.\n" % [Campaign.display_name_of(key), watch._name_of(guard), skill.name])
				if scene.has_method("_refresh_party_panel"):
					scene._refresh_party_panel()
				return true
	if not struck.guards.is_empty():
		return watch.strike(struck.guards, key, move, aim)
	if struck.placed != null:
		return scene.open_fight_with(struck.placed, key, move)
	# Nobody caught: spent out here.
	var paid := pay(key, skill)
	if paid.is_empty():
		return false
	if skill is ItemDefinition:
		Campaign.take_item(key, move)
	var who := Campaign.display_name_of(key)
	# A shot at a lamp: out it goes, quietly. A guard who sees it goes to light it again, as for any lamp.
	var light = _light_to_shoot(scene, aim) if skill.shoots_out_lights else null
	if light != null:
		if light is Lamp:
			watch.put_out(light, true)
		else:
			light.lit = false
			light.queue_redraw()
			if watch != null:
				watch._relight()
			else:
				scene.relight_map()
		if scene.has_method("log_message"):
			scene.log_message("[color=yellow]%s[/color] shoots out the light.\n" % who)
		return true
	var broke := 0
	if breaks_walls(key, skill):
		for wall in struck.walls:
			scene.break_wall(wall)
			broke += 1
	if scene.has_method("show_burst"):
		scene.show_burst(struck.tiles, Damage.type_colour(skill.damage_type))
	if scene.has_method("log_message"):
		scene.log_message(("[color=yellow]%s[/color] uses %s%s: the wall comes down.\n" if broke > 0 else "[color=yellow]%s[/color] uses %s%s, and it lands on nobody.\n") % [who, skill.name, paid_through(paid)])
	# Heard from where it lands, not from whoever let it go.
	if watch != null:
		if skill.noise_tiles > 0.0 and (skill.noise == SkillDefinition.Loudness.QUIET or skill.noise == SkillDefinition.Loudness.LOUD):
			watch.make_noise(watch._tile_centre_of(aim), skill.noise_tiles, skill.noise == SkillDefinition.Loudness.LOUD)
	if scene.has_method("_refresh_party_panel"):
		scene._refresh_party_panel()
	return true


## A trap laid at `aim`, its gate spent. One that bursts (Tripwire, the Great Snare) starts a fight as it
## goes off, and hurts everybody in it first (StealthWatch.trap_goes_off); one that does not is a
## quiet takedown for whoever walks on to it.
static func _lay_trap(scene: Node, watch, key: String, move: String, skill: SkillDefinition, aim: Vector2i) -> bool:
	var paid := pay(key, skill)
	if paid.is_empty():
		return false
	var trap := Trap.new()
	trap.watch = watch
	trap.key = key
	trap.move = move
	var effect := trap_effect_of(skill)
	if effect != null:
		trap.burst_tiles = effect.trap_burst_radius
		trap.bursts = effect.trap_burst_modifier > 0.0
	scene.add_child(trap)
	trap.global_position = watch._tile_centre_of(aim)
	if scene.has_method("log_message"):
		scene.log_message("[color=yellow]%s[/color] lays %s%s.\n" % [Campaign.display_name_of(key), skill.name, paid_through(paid)])
	if scene.has_method("_refresh_party_panel"):
		scene._refresh_party_panel()
	sound(scene, key, skill)
	return true


## What `key`'s `skill` (as `kind`) does to `target` - paying is the caller's -
## and the line for the log. `paid_words` is how it was paid (paid_through).
static func _do_to(watch, key: String, skill: SkillDefinition, kind: int, target: Guard, paid_words: String) -> String:
	var who := Campaign.display_name_of(key)
	var said := ""
	match kind:
		Use.BLIND, Use.SCARE, Use.CONFUSE:
			var seconds := seconds_of(skill, kind)
			# Letting go of what they held first: it may be this very guard.
			if skill.tethered:
				var bound: int = MOODS[kind]
				watch.tie_outside(key, skill, func(): if is_instance_valid(target) and target.mood == bound: target.end_errand(), target)
			watch.spellbind(target, MOODS[kind], seconds, key)
			said = "[color=yellow]%s[/color] uses %s%s on [color=yellow]%s[/color]: %s for %d seconds.\n" % [who, skill.name, paid_words,
				watch._name_of(target), {Use.BLIND: "struck blind", Use.SCARE: "he runs", Use.CONFUSE: "bewildered"}[kind], seconds]
		Use.READ:
			watch.learn_route(target)
			said = "[color=yellow]%s[/color] uses %s%s: [color=yellow]%s[/color]'s round is known.\n" % [who, skill.name, paid_words, watch._name_of(target)]
		Use.BECKON:
			var seconds := seconds_of(skill, kind)
			watch.beckon(target, seconds, key)
			said = "[color=yellow]%s[/color] casts %s%s: a light beckons [color=yellow]%s[/color] away, for %d seconds.\n" % [who, skill.name, paid_words, watch._name_of(target), seconds]
		Use.SUGGEST:
			var seconds := seconds_of(skill, kind)
			watch.suggest_to(target, seconds)
			said = "[color=yellow]%s[/color] casts %s%s on [color=yellow]%s[/color]: off he goes on some errand, for %d seconds.\n" % [who, skill.name, paid_words, watch._name_of(target), seconds]
		Use.SWITCH_OFF_MAGIC:
			var seconds := seconds_of(skill, kind)
			watch.still(target, seconds)
			said = "[color=yellow]%s[/color] casts %s%s: [color=yellow]%s[/color] is still for %d seconds.\n" % [who, skill.name, paid_words, watch._name_of(target), seconds]
	# Whoever readied something for when he is hit lets it go now - after.
	watch.guard_hit(target, key)
	return said


## --- Readied, out of a fight ---
##
## A move that lands on a guard (READYABLE), held back for a trigger (the
## designer, 2026-10-29): a guard stepping into its reach, a guard stepping into
## an area marked on the map, or a guard chosen, in sight, being hit by the party
## (StealthWatch.guard_hit). Its gate is spent when it is readied. Whoever
## readied it has to keep what it waits for in sight - the marked area's middle,
## the guard watched - or it is lost (StealthWatch "Readied, out of a fight").

## What can be readied out here: what lands on a guard.
const READYABLE := [Use.BLIND, Use.SCARE, Use.CONFUSE, Use.READ, Use.SWITCH_OFF_MAGIC, Use.AMBUSH, Use.SUGGEST, Use.BECKON]
## The triggers out here.
const READY_TRIGGERS := [SkillDefinition.Trigger.ENTERS_REACH, SkillDefinition.Trigger.ENTERS_AREA, SkillDefinition.Trigger.HIT_IN_SIGHT]


## Whether `skill` could be readied out of a fight.
static func can_ready(skill: SkillDefinition) -> bool:
	return use_of(skill) in READYABLE


## Whether `guard` is somebody `skill` (as `kind`) could do something to.
static func fits(watch, skill: SkillDefinition, kind: int, guard) -> bool:
	match kind:
		Use.BLIND, Use.SCARE, Use.CONFUSE, Use.SUGGEST, Use.BECKON:
			return watch.can_spellbind(guard)
		Use.READ:
			return is_instance_valid(guard) and not guard.knocked_out and not guard.patrol_points().is_empty() and not watch.route_known(guard)
		Use.SWITCH_OFF_MAGIC:
			return is_instance_valid(guard) and (guard.kind == Guard.Kind.WARD or guard.kind == Guard.Kind.SENSOR) and not guard.switched_off()
		Use.AMBUSH:
			return watch.can_open_on(guard)
	return false


## A readied `move` of `key`'s going off at `guard` - paid for already.
static func fire_readied(scene: Node, key: String, move: String, guard: Guard) -> bool:
	var watch = scene.get("stealth")
	var skill: SkillDefinition = definition_of(move)
	var kind := use_of(skill)
	if watch == null or skill == null or not fits(watch, skill, kind, guard):
		return false
	# A spell's gate spent since it was readied, there is nothing to open with.
	var unpaid := cannot_open_with(key, skill) if kind == Use.AMBUSH else ""
	if unpaid != "":
		if scene.has_method("log_message"):
			scene.log_message("[color=yellow]%s[/color]'s readied %s comes to nothing - %s.\n" % [Campaign.display_name_of(key), skill.name, unpaid])
		return false
	if scene.has_method("log_message"):
		scene.log_message("[color=yellow]%s[/color]'s readied %s goes off!\n" % [Campaign.display_name_of(key), skill.name])
	if kind == Use.AMBUSH:
		var aim: Vector2i = watch.tile_of(guard.global_position)
		var struck := struck_at(scene, key, skill, aim)
		return watch.strike(struck.guards if guard in struck.guards else [guard] + struck.guards, key, move, aim)
	var said := _do_to(watch, key, skill, kind, guard, "")
	if scene.has_method("log_message"):
		scene.log_message(said)
	sound(scene, key, skill)
	return true


## The middle of the tile `at` is on.
static func _tile_centre(watch, at: Vector2) -> Vector2:
	var tile_map: TileMap = watch._tile_map
	return tile_map.to_global(tile_map.map_to_local(watch.tile_of(at)))


## `key` as the character sheet has them away from a fight.
static func _entry_of(key: String) -> Dictionary:
	for member in Campaign.party_members():
		if member.key == key:
			return CharacterSheet.map_entry_of(member)
	return {}


## The spells anybody standing could cast to some purpose right now that need
## somebody to land on (ON_G) - not Invisibility, which G asks about itself, nor
## Find Familiar, cast from the Spells tab as the other spells are (the
## designer, 2026-10-31), nor what is always ready (a hurry, a blink), which
## would have it ask "which?" every time: [{"key": caster, "move": spell}],
## leader first.
static func ready_spells(scene: Node) -> Array:
	var found := []
	var taken := {}
	for key in Campaign.living_party():
		for move in moves_of(key):
			var skill: SkillDefinition = SkillDatabase.skills[move]
			if not Combat.is_spell(skill) or taken.has(move):
				continue
			if not use_of(skill) in ON_G:
				continue
			if refusal(scene, key, move) == "":
				found.append({"key": key, "move": move})
				taken[move] = true
	return found


## A lure laid on a map (Lure): a shimmer the guards near it come to look at,
## gone after its seconds.
class Decoy extends Node2D:
	var left := 10.0

	func _ready():
		z_as_relative = false
		z_index = ExplorationParty.PARTY_Z_TOP

	func _process(delta):
		left -= delta
		queue_redraw()
		if left <= 0.0:
			queue_free()

	func _draw():
		var breath := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 3.0)
		var colour := Color(0.75, 0.85, 1.0, 0.3 + 0.2 * breath)
		var tile := float(Grid.TILE_SIZE)
		draw_circle(Vector2(0, -tile * 0.42), tile * 0.12, colour)
		draw_colored_polygon(PackedVector2Array([Vector2(-tile * 0.16, tile * 0.2), Vector2(tile * 0.16, tile * 0.2),
			Vector2(tile * 0.1, -tile * 0.28), Vector2(-tile * 0.1, -tile * 0.28)]), colour)


## A trap laid on a map (Trap): the first guard to walk onto it - or standing there as it is laid -
## sets it off. One that does not burst leaves him down, and nobody the wiser but those who hear it
## (StealthWatch.caught_in_trap). One that does starts a fight, with everybody in its burst hurt before
## anybody's turn (StealthWatch.trap_goes_off). It stays until then, or the party leaves.
class Trap extends Node2D:
	var watch = null
	## Whose it is, and which of their moves.
	var key := ""
	var move := ""
	## How far its burst reaches, in tiles, and whether it has one that hurts.
	var burst_tiles := 0
	var bursts := false

	const SPRINGS_WITHIN := 0.45
	const COLOUR := Color(0.75, 0.62, 0.35, 0.85)
	const GREAT_COLOUR := Color(0.72, 0.5, 1.0, 0.7)

	func _ready():
		z_as_relative = false
		z_index = ExplorationParty.PARTY_Z_BOTTOM - 3

	func _process(_delta):
		if watch == null or not is_instance_valid(watch):
			queue_free()
			return
		for guard in watch.guards:
			if is_instance_valid(guard) and not guard.knocked_out and guard.moves() \
					and guard.global_position.distance_to(global_position) <= Grid.tiles(SPRINGS_WITHIN):
				if watch.trap_goes_off(self, guard) if bursts else watch.caught_in_trap(guard):
					queue_free()
					return

	func _draw():
		var tile := float(Grid.TILE_SIZE)
		if burst_tiles > 0:
			draw_arc(Vector2.ZERO, tile * float(burst_tiles), 0.0, TAU, 48, GREAT_COLOUR, 4.0)
		draw_arc(Vector2.ZERO, tile * 0.22, 0.0, TAU, 16, COLOUR, 6.0)
		for i in 8:
			var a := TAU * i / 8.0
			draw_line(Vector2.RIGHT.rotated(a) * tile * 0.22, Vector2.RIGHT.rotated(a + 0.2) * tile * 0.32, COLOUR, 5.0)
