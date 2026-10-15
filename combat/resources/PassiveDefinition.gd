@icon("res://art/editor_icons/passive.svg")
extends Resource
class_name PassiveDefinition
## A skill nobody presses. It is part of who somebody is: working all the time,
## or switching itself on when its moment comes, and never offered on the
## action panel because there is nothing there to choose.
##
## Kept apart from SkillDefinition rather than being a skill with a flag on it.
## Everything that walks a combatant's skill list - the three panels, the
## reactions, the AI hunting for something to swing - would otherwise have to
## be taught to step over it, and the first place that forgot would offer the
## player a button that does nothing. A combatant lists these under Passives
## instead, and the character sheet reads them out under a heading of their own.
##
## What one does is a switch below for each thing the rules know how to hand
## out. Combat only looks at the switches of a passive whose moment holds - see
## Combat.active_passives - so one waiting on its condition does nothing at all.


## When it is working.
##
## Stored by number, so a new one goes on the end. Put one in the middle and
## every passive already written with a later one quietly means something else.
enum ActiveWhen {
	ALWAYS,             ## From the first turn of a fight to the last.
	BELOW_HALF_HEALTH,  ## Only while they are down to half their health or less.
}

@export var name: String = ""
## What it does, in the words the character sheet shows. Written out in full on
## the sheet rather than left behind a tooltip, so say it plainly.
@export_multiline var description: String = ""
## Optional. The sheet names the passive either way.
@export var icon: Texture2D
@export var active_when: ActiveWhen = ActiveWhen.ALWAYS
## The level it starts working at. For a path's passives (SubclassDefinition)
## that come later than the path itself - before it, it does nothing at all.
@export_range(1, 20) var required_level: int = 1

@export_group("What it does")
## Casts without spending anything. Whatever they know they can use, however
## deep a gate the spell is cast through and however many gates they have of
## their own - which may be none. The Mimic's: its whole trick is doing what it
## just watched somebody else do, and without this it copies a spell and then
## cannot pay for it, which is a turn spent doing nothing at all.
@export var casts_without_gates: bool = false
## Skills, by key, they can also use as their secondary action - still on the
## main panel as well, so either action will do. Cyrus's Light Footed: it is why he
## can Run twice in one turn.
@export var secondary_skills: Array[String] = []
## Consumables that would cost the main action can be used as the secondary
## one instead. Cyrus's Quick Hands: it is why he can drink a potion and still
## swing in the same turn.
@export var items_as_secondary: bool = false
## Gate Nades whose spell would cost the main action are thrown with the
## secondary one instead. Cyrus's Nade Juggler.
@export var gate_nades_as_secondary: bool = false
## Any Gate Nade at all, whatever spell is in it - not only those whose spell
## they know or could learn. Cyrus's Nade Juggler.
@export var any_gate_nade: bool = false
## Can hack (HackDefinition): wards, machines, the spell a foe is winding up.
## Prometheus's Prying Mind.
@export var can_hack: bool = false
## Every hit of theirs studies whoever it lands on, the way Study does - and
## with it the edge a studier has. Enfina's Measured Eye.
@export var studies_on_hit: bool = false
## Every skill they use is worked out from this attribute instead of the one
## the skill names: its damage, its heals, what it burns for, and its side of a
## contest. "Own stat" leaves each skill to its own. The Mimic's: whatever it
## copies - a greatsword swing, a Fire Burst - comes out of its Self.
##
## The names are Stats.NAMES in order, with -1 in front for "leave it be"; a
## stat added there needs adding here too.
@export_enum("Own stat:-1", "Physical:0", "Mindfulness:1", "Intellect:2", "Self:3", "Defense:4")
var scales_every_skill_with: int = -1
## Tiles more they can walk each turn. The Spellsword's: Prometheus at 6.
@export var movement_bonus: int = 0
## Added to their Defense. The Guardian's.
@export var defense_bonus: int = 0

@export_subgroup("Reach and kit")
## Skill key -> tiles more it reaches. The Bombardier's: {"steal": 3}.
@export var range_bonuses: Dictionary = {}
## An item, by key, they have to hand in every fight on top of their bag, used
## without spending anything from it - once a fight. The Bombardier's bomb.
@export var free_item_each_fight: String = ""
## Skills, by key, after which they may step away (step_tiles, in a straight
## line, provoking nothing) - the Swashbuckler's Rapier.
@export var step_after: Array[String] = []
@export_range(0, 6) var step_tiles: int = 0

@export_subgroup("Spells")
## They can amplify a spell: cast it through a higher gate than it needs, each
## gate higher adding Amplify Bonus Per Gate to its damage. The Demolitionist's.
@export var amplifies_spells: bool = false
@export_range(0.0, 2.0, 0.05) var amplify_bonus_per_gate: float = 0.0
## Levels at which they gain one amplification a fight that costs no extra gate:
## [5, 11, 17] is one at 5, two at 11, three at 17.
@export var free_amplifies_at: Array[int] = []
## A spell of theirs landing on an ally leaves them overhealed - health on top
## of their health, taken first and gone by the fight's end (Combat.overheal) -
## by this share of the caster's power. The Abjurer's.
@export_range(0.0, 2.0, 0.05) var overheals_allies: float = 0.0

@export_subgroup("Protecting")
## When an ally - or they - is about to be hit, they may spend their reaction to
## take Ward Reduction off it, from up to Ward Range tiles away. The Abjurer's.
@export var wards_allies: bool = false
@export_range(0.0, 1.0, 0.05) var ward_reduction: float = 0.0
@export_range(0, 20) var ward_range: int = 0
## An ally within this many tiles who is hit has Guard Share of it taken by
## them instead. The Guardian's.
@export_range(0, 10) var guards_within: int = 0
@export_range(0.0, 1.0, 0.05) var guard_share: float = 0.0

@export_subgroup("Healing")
## Their heals mend this much more: 0.25 is a quarter more. The Carer's.
@export_range(0.0, 2.0, 0.05) var heal_bonus: float = 0.0
## This share of what their heals mend on somebody else comes back to them.
@export_range(0.0, 1.0, 0.05) var heal_self_share: float = 0.0
## A spell of theirs landing on an ally gives that ally this much more movement
## until the end of their next turn.
@export var ally_spell_movement: int = 0

@export_subgroup("Empowered")
## While they suffer this condition - the Berserker's Burn - they are empowered:
## Empowered Damage Bonus more to every hit, and, with Spreads It, every hit
## sets it on whoever it lands on too.
@export var empowered_by: ConditionDefinition
@export_range(0.0, 2.0, 0.05) var empowered_damage_bonus: float = 0.0
@export var spreads_it: bool = false

@export_subgroup("Aura")
## Tiles out from them that their aura reaches. 0 is no aura. Whoever starts a
## turn inside it has the condition below for that turn - a boss's presence.
@export_range(0, 10, 1) var aura_radius: int = 0
## On the other side, inside it: Frightened, Slowed.
@export var aura_on_foes: ConditionDefinition
## On their own side, inside it.
@export var aura_on_allies: ConditionDefinition


## When it works, as the character sheet says it.
func describe_when() -> String:
	var when := "Always active"
	match active_when:
		ActiveWhen.BELOW_HALF_HEALTH:
			when = "Active at half health or below"
	if required_level > 1:
		when += ", from level %d" % required_level
	return when


## What its switches do, a line each, in the words the glossary prints. Kept
## beside the switches so a new one is described where it is added.
func describe_effects() -> Array:
	var lines := []
	if casts_without_gates:
		lines.append("Casts without opening a gate, however deep a gate the spell calls for.")
	if not secondary_skills.is_empty():
		lines.append("Can use %s as a secondary action as well as a main one." % _named(secondary_skills))
	if items_as_secondary:
		lines.append("Can use items as a secondary action as well as a main one.")
	if gate_nades_as_secondary:
		lines.append("Can throw Gate Nades as a secondary action as well as a main one.")
	if any_gate_nade:
		lines.append("Can throw any Gate Nade, whatever spell is in it.")
	if can_hack:
		lines.append("Can hack wards, machines and the spells others are winding up - more tries, and cheaper ones, the higher their Intellect.")
	if studies_on_hit:
		lines.append("Every hit studies whoever it lands on, as Study does.")
	if scales_every_skill_with >= 0:
		lines.append("Every skill scales with %s, whatever stat the skill itself names."
			% Stats.stat_name(scales_every_skill_with))
	if movement_bonus != 0:
		lines.append("%+d movement." % movement_bonus)
	if defense_bonus != 0:
		lines.append("%+d Defense." % defense_bonus)
	for key in range_bonuses:
		lines.append("%s reaches %+d tiles." % [_named([key]), range_bonuses[key]])
	if free_item_each_fight != "":
		lines.append("Has a %s to hand in every fight, free, once." % _item_name(free_item_each_fight))
	if not step_after.is_empty() and step_tiles > 0:
		lines.append("After %s, can step up to %d tiles away in a straight line, provoking nothing." % [_named(step_after), step_tiles])
	if amplifies_spells:
		lines.append("Can amplify a spell, casting it through a higher gate for %d%% more damage a gate." % roundi(amplify_bonus_per_gate * 100))
	if not free_amplifies_at.is_empty():
		lines.append("Amplifies for free once a fight from level %s." % ", once more from level ".join(free_amplifies_at.map(str)))
	if overheals_allies > 0.0:
		lines.append("A spell on an ally leaves them overhealed - extra health, taken first, gone by the fight's end.")
	if wards_allies:
		lines.append("Reaction: when an ally within %d tiles is hit, takes %d%% off it." % [ward_range, roundi(ward_reduction * 100)])
	if guards_within > 0:
		lines.append("Takes %d%% of any hit on an ally within %d tiles." % [roundi(guard_share * 100), guards_within])
	if heal_bonus > 0.0:
		lines.append("Heals mend %d%% more." % roundi(heal_bonus * 100))
	if heal_self_share > 0.0:
		lines.append("%d%% of what a heal mends on somebody else comes back to them." % roundi(heal_self_share * 100))
	if ally_spell_movement != 0:
		lines.append("A spell on an ally gives them %+d movement for a turn." % ally_spell_movement)
	if empowered_by != null:
		var empowered := "While %s: %d%% more damage" % [empowered_by.display_name, roundi(empowered_damage_bonus * 100)]
		lines.append(empowered + (", and every hit spreads it." if spreads_it else "."))
	if aura_radius > 0 and aura_on_foes != null:
		lines.append("Aura: the other side within %d tiles are %s." % [aura_radius, aura_on_foes.display_name.to_lower()])
	if aura_radius > 0 and aura_on_allies != null:
		lines.append("Aura: their own side within %d tiles are %s." % [aura_radius, aura_on_allies.display_name.to_lower()])
	return lines


static func _item_name(key: String) -> String:
	var item = ItemDatabase.item(key) if not Engine.is_editor_hint() else null
	return item.name if item != null else key.capitalize()


## "Stealth, Slip Past and Run" from their keys.
static func _named(keys: Array) -> String:
	var names := []
	for key in keys:
		var skill = SkillDatabase.skills.get(key) if not Engine.is_editor_hint() else null
		names.append(skill.name if skill != null else String(key).capitalize())
	if names.size() <= 1:
		return "".join(names)
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + names[-1]
