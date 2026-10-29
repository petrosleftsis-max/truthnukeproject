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
## ward or a sensor. A damaging move springs an ambush on an unaware guard in
## reach with itself as the opening blow (StealthWatch.ambush_with; paid in the
## fight), or else knocks down a breakable wall in reach (ExplorationScene
## .break_wall). Blink steps the party ahead, Fly lifts it over low things, a
## Lure draws guards to a shimmer ahead, a Hiding Spot is made where the leader
## stands, a Trap is laid there. Only a spell, an item or the move of somebody
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
	AMBUSH, BLINK, FLY, LURE, HIDING_SPOT, TRAP, COUNTER_TRAP }

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
	Use.AMBUSH: "Springs an ambush with it, or breaks a wall",
	Use.BLINK: "Steps the party ahead, over anything",
	Use.FLY: "Lifts the party over low things",
	Use.LURE: "Leaves a lure for the guards",
	Use.HIDING_SPOT: "Makes somewhere to hide",
	Use.TRAP: "Lays a trap",
	Use.COUNTER_TRAP: "Hacks a magical trap's casting apart as it goes off",
}

## SkillDefinition.outside_use, as a Use - -1 for Automatic.
const FROM_FIELD := [-1, Use.NONE, Use.MEND, Use.REVIVE, Use.SPEED, Use.BLIND, Use.SCARE, Use.CONFUSE, Use.READ,
	Use.SWITCH_OFF_MAGIC, Use.BLINK, Use.FLY, Use.LURE, Use.HIDING_SPOT, Use.TRAP, Use.COUNTER_TRAP]

## How long each lasts when the move gives no Outside Seconds - PROPOSAL test
## values, as are the rest below.
const SECONDS := {Use.BLIND: 12, Use.SCARE: 15, Use.CONFUSE: 20, Use.SWITCH_OFF_MAGIC: 60, Use.FLY: 20,
	Use.LURE: 10, Use.HIDING_SPOT: 60}
## How far a Blink goes when the move's reach says nothing, and at most.
const BLINK_TILES := 3
const BLINK_MOST := 6
## How far ahead a Lure lands at most, and how far off guards hear it.
const LURE_AHEAD := 4
const LURE_TILES := 6.0
## What the Outside Spell key offers: what needs somebody to land on, so it is
## to some purpose only now and then.
const ON_G := [Use.MEND, Use.REVIVE, Use.BLIND, Use.SCARE, Use.CONFUSE, Use.READ, Use.SWITCH_OFF_MAGIC]
## The moods Blind, Scare and Confuse put a guard in.
const MOODS := {Use.BLIND: Guard.Mood.BLINDED, Use.SCARE: Guard.Mood.FRIGHTENED, Use.CONFUSE: Guard.Mood.BEWILDERED}

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
	if skill.outside_only():
		return Use.FAMILIAR
	if skill.outside_gate > 0 and _has(skill, EffectDefinition.EffectType.INVISIBLE):
		return Use.INVISIBILITY
	if skill.outside_use > 0 and skill.outside_use < FROM_FIELD.size():
		return FROM_FIELD[skill.outside_use]
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


## How long what `skill` does out here lasts, as `kind`.
static func seconds_of(skill: SkillDefinition, kind: int) -> int:
	return skill.outside_seconds if skill.outside_seconds > 0 else SECONDS.get(kind, HURRY_SECONDS)


## The guard `skill` would land on as `kind`, on `watch`'s map, or null.
static func guard_for(watch, skill: SkillDefinition, kind: int) -> Guard:
	if watch == null:
		return null
	match kind:
		Use.BLIND, Use.SCARE, Use.CONFUSE:
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
			return "Only on a watched map" if watch == null else watch.invisibility_refusal()
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
		Use.BLIND, Use.SCARE, Use.CONFUSE:
			if watch == null:
				return "Only where guards watch"
			if guard_for(watch, skill, kind) == null:
				return "Nobody in reach it could take hold of"
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
			if guard_for(watch, skill, kind) != null:
				# The fight pays for its opening blow.
				return ""
			if scene == null or not scene.has_method("wall_in_reach") or scene.wall_in_reach(skill.max_range) == null:
				return "Nobody unaware in reach to spring on, and no wall to break" if watch != null else "No wall in reach to break"
			if not breaks_walls(key, skill):
				return "Only a spell, an item or Enfina's strength knocks a wall down"
		Use.BLINK, Use.FLY:
			if party != null and party.rooted:
				return "Not while standing still for something"
			if kind == Use.FLY and scene != null and scene.has_method("flying") and scene.flying():
				return "Already flying"
		Use.LURE, Use.TRAP:
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
	match kind:
		Use.FAMILIAR:
			if scene.familiar_keeper.familiar != null:
				return scene.familiar_keeper.perch()
			return scene.summon_familiar()
		Use.INVISIBILITY:
			watch.stealth_bar().open_picker()
			return true
		Use.AMBUSH:
			var sprung := guard_for(watch, skill, kind)
			if sprung != null:
				return watch.ambush_with(sprung, key, move)
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
		Use.BLIND, Use.SCARE, Use.CONFUSE:
			var paid := pay(key, skill)
			if paid.is_empty():
				return false
			var seconds := seconds_of(skill, kind)
			watch.spellbind(target, MOODS[kind], seconds)
			said = "[color=yellow]%s[/color] uses %s%s on [color=yellow]%s[/color]: %s for %d seconds.\n" % [who, skill.name, paid_through(paid),
				watch._name_of(target), {Use.BLIND: "struck blind", Use.SCARE: "he runs", Use.CONFUSE: "bewildered"}[kind], seconds]
		Use.READ:
			var paid := pay(key, skill)
			if paid.is_empty():
				return false
			watch.learn_route(target)
			said = "[color=yellow]%s[/color] uses %s%s: [color=yellow]%s[/color]'s round is known.\n" % [who, skill.name, paid_through(paid), watch._name_of(target)]
		Use.SWITCH_OFF_MAGIC:
			var paid := pay(key, skill)
			if paid.is_empty():
				return false
			var seconds := seconds_of(skill, kind)
			watch.still(target, seconds)
			said = "[color=yellow]%s[/color] casts %s%s: [color=yellow]%s[/color] is still for %d seconds.\n" % [who, skill.name, paid_through(paid), watch._name_of(target), seconds]
		Use.AMBUSH:
			var wall: BreakableWall = scene.wall_in_reach(skill.max_range)
			var paid := pay(key, skill)
			if paid.is_empty():
				return false
			if skill is ItemDefinition:
				Campaign.take_item(key, move)
			scene.break_wall(wall)
			said = "[color=yellow]%s[/color] uses %s%s: the wall comes down.\n" % [who, skill.name, paid_through(paid)]
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
		Use.LURE:
			var way: Vector2 = party.held_direction()
			if way == Vector2.ZERO:
				way = Vector2.LEFT if party.facing_left() else Vector2.RIGHT
			var there: Vector2 = watch._ground_toward(at, way, mini(skill.max_range if skill.max_range > 0 else LURE_AHEAD, LURE_AHEAD))
			var paid := pay(key, skill)
			if paid.is_empty():
				return false
			var lure := Decoy.new()
			lure.left = seconds_of(skill, kind)
			scene.add_child(lure)
			lure.global_position = there
			watch.make_noise(there, LURE_TILES, true)
			said = "[color=yellow]%s[/color] uses %s%s: something stirs ahead, and the guards near it go to look.\n" % [who, skill.name, paid_through(paid)]
		Use.HIDING_SPOT:
			var paid := pay(key, skill)
			if paid.is_empty():
				return false
			var seconds := seconds_of(skill, kind)
			watch.add_hiding_spot(HidingSpot.new(), _tile_centre(watch, at), seconds)
			said = "[color=yellow]%s[/color] uses %s%s: cover, where there was none, for %d seconds.\n" % [who, skill.name, paid_through(paid), seconds]
		Use.TRAP:
			var paid := pay(key, skill)
			if paid.is_empty():
				return false
			var trap := Trap.new()
			trap.watch = watch
			scene.add_child(trap)
			trap.global_position = _tile_centre(watch, at)
			said = "[color=yellow]%s[/color] lays %s%s where they stand.\n" % [who, skill.name, paid_through(paid)]
	if scene.has_method("log_message"):
		scene.log_message(said)
	# The portraits down the left read health off the party: drawn again.
	if scene.has_method("_refresh_party_panel"):
		scene._refresh_party_panel()
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
## somebody to land on (ON_G) - not Invisibility and Find Familiar, which G asks
## about itself, nor what is always ready (a hurry, a blink), which would have
## it ask "which?" every time: [{"key": caster, "move": spell}], leader first.
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


## A trap laid on a map (Trap): the first guard to walk onto it is down
## (StealthWatch.caught_in_trap). It stays until then, or the party leaves.
class Trap extends Node2D:
	var watch = null

	const SPRINGS_WITHIN := 0.45
	const COLOUR := Color(0.75, 0.62, 0.35, 0.85)

	func _ready():
		z_as_relative = false
		z_index = ExplorationParty.PARTY_Z_TOP - 3

	func _process(_delta):
		if watch == null or not is_instance_valid(watch):
			queue_free()
			return
		for guard in watch.guards:
			if is_instance_valid(guard) and not guard.knocked_out and guard.moves() \
					and guard.global_position.distance_to(global_position) <= Grid.tiles(SPRINGS_WITHIN):
				if watch.caught_in_trap(guard):
					queue_free()
					return

	func _draw():
		var tile := float(Grid.TILE_SIZE)
		draw_arc(Vector2.ZERO, tile * 0.22, 0.0, TAU, 16, COLOUR, 6.0)
		for i in 8:
			var a := TAU * i / 8.0
			draw_line(Vector2.RIGHT.rotated(a) * tile * 0.22, Vector2.RIGHT.rotated(a + 0.2) * tile * 0.32, COLOUR, 5.0)
