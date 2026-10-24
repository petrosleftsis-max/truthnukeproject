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
@export_range(1, 64) var required_level: int = 1

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
## Tiles more they can walk each turn. The Spellsword's: Prometheus at 8. Cyrus's Cat Burglar.
@export var movement_bonus: int = 0
## Added to their Defense. The Guardian's.
@export var defense_bonus: int = 0
## Climbs anywhere (Combat "Heights"): onto high ground from any tile beside it,
## no climb tile needed, and up a wall or a pillar onto the floor above it - from
## open air, beside something solid with standing room over it. Cyrus's Cat
## Burglar.
@export var climbs_anywhere: bool = false
## Squeezes into room too small for them: folded a size narrower, a size
## shorter, or both - only as much as the room needs - while they are in there,
## each step in costing twice over (Combat "Squeezing"). Erysichthon's Hollow Frame.
@export var squeezes: bool = false

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
## Levels at which they gain one amplification a short rest that costs no extra gate:
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
## Their heals lift this many harmful conditions as well. Alithia's Mercy II.
@export_range(0, 5) var heals_lift: int = 0
## Their heals leave this on whoever they heal - Mercy III's Sheltered.
@export var heals_leave: ConditionDefinition
## And a shield of this share of their health (overheal), gone after Heals
## Shield Turns of theirs (0: the fight's end). Veil of Mercy III.
@export_range(0.0, 1.0, 0.05) var heals_shield: float = 0.0
@export_range(0, 10) var heals_shield_turns: int = 0
## And this much more movement, until the end of their next turn. Guiding
## Phantasm.
@export_range(0, 6) var heals_spur: int = 0

@export_subgroup("Taking less")
## They take this share less of every hit: 0.1 is a tenth. Iron Hide.
@export_range(0.0, 0.9, 0.05) var damage_reduction: float = 0.0
## And this share less while in cover (Combat.in_cover). Agile I.
@export_range(0.0, 0.9, 0.05) var damage_reduction_in_cover: float = 0.0
## While they stand, everybody on their side takes this share less. Radiant
## Guardian.
@export_range(0.0, 0.9, 0.05) var party_damage_reduction: float = 0.0

@export_subgroup("Hitting harder")
## On a turn they have not walked, their hits land this much harder. Momentum.
@export_range(0.0, 2.0, 0.05) var still_damage_bonus: float = 0.0
## On anybody weak to the hit's element (a resistance below 0). Elemental
## Affinity I.
@export_range(0.0, 2.0, 0.05) var bonus_vs_weak: float = 0.0
## On anybody taking lingering damage. Elemental Affinity II.
@export_range(0.0, 2.0, 0.05) var bonus_vs_lingering: float = 0.0
## Everybody on their side hits anybody carrying a harmful condition this much
## harder. Synergy I.
@export_range(0.0, 2.0, 0.05) var party_bonus_vs_afflicted: float = 0.0
## And this much more on anybody carrying one they put there. Synergy II.
@export_range(0.0, 2.0, 0.05) var party_bonus_vs_own: float = 0.0
## Each spell they cast in a fight makes the ones after it this much harder,
## up to Kindling Most. Kindling.
@export_range(0.0, 1.0, 0.05) var kindling_step: float = 0.0
## The most Kindling adds; every tier's adds up.
@export_range(0.0, 2.0, 0.05) var kindling_most: float = 0.0

@export_subgroup("Lingering")
## The damage their conditions do over time is this much harder. DoT Master.
@export_range(0.0, 2.0, 0.05) var dot_bonus: float = 0.0
## And lasts this many turns longer.
@export_range(0, 5) var dot_extra_turns: int = 0

@export_subgroup("Contests")
## Added to their stat in a stat contest. Contest Insight I.
@export_range(0, 50) var contest_bonus: int = 0
## And this much more against anybody carrying a harmful condition. Contest
## Insight II.
@export_range(0, 50) var contest_bonus_vs_afflicted: int = 0

@export_subgroup("Gates")
## Castings more through the deepest gate open to them. Reserved Power,
## Elemental Mastery.
@export_range(0, 5) var extra_deepest_castings: int = 0

@export_subgroup("Cover")
## More movement on a turn they start in cover (Combat.in_cover). Cat Burglar I.
@export_range(0, 6) var movement_in_cover: int = 0
## Stepping into cover sets off nothing as they leave somebody's reach. Agile II.
@export var slips_into_cover: bool = false

@export_subgroup("Holding attention")
## Tiles within this many of them cost the other side twice the movement. 0 is
## none. The Pit Champion's Hemmed In (Combat "Hemmed In and Exposed").
@export_range(0, 10) var hems_in: int = 0
## Anybody of the other side who ends a turn within this many tiles of them
## without having hurt them that turn gets Exposes With - the Pit Champion's
## Exposed. 0 is none.
@export_range(0, 10) var exposes_within: int = 0
@export var exposes_with: ConditionDefinition

@export_subgroup("Paths")
## Immune to these, while it works - as a creature's own Immune To.
## Juggernaut's Immovable (shoved).
@export var immune_to: Array[Immunity.Kind] = []
## And to these conditions. Vanguard's Unstoppable (Grappled).
@export var immune_to_conditions: Array[ConditionDefinition] = []
## Nothing lowers their movement or stops them walking: whatever would, leaves
## them their own. Vanguard's Unstoppable.
@export var unstoppable: bool = false
## Having walked Charge Tiles or more this turn, their next hit lands this much
## harder. Vanguard's Leading Charge.
@export_range(0.0, 2.0, 0.05) var charge_bonus: float = 0.0
@export_range(0, 12) var charge_tiles: int = 0
## Felling somebody of the other side on their own turn gives their main action
## back, and this much more movement. Vanguard's Rampage.
@export var felling_refreshes: bool = false
@export_range(0, 12) var felling_movement: int = 0
## Every hit of theirs also hits everybody beside whoever it lands on for this
## share of it - or a rank's splash there, whichever is harder, never both - and
## shoves them all a tile, the one struck too; anybody they shove into something
## solid gets Tremor Impact Condition. Juggernaut's Tremor: Dazed since the
## designer's change of 2026-10-24 (APPROVED_TRIAL), Stunned before it.
@export_range(0.0, 2.0, 0.05) var tremor_share: float = 0.0
@export var tremor_impact_condition: ConditionDefinition
## After a hit of theirs that set off Tremor, in their own turn, they may step a
## tile toward whoever it landed on - for a tile of movement, onto free and safe
## ground, provoking nothing (Combat.tremor_steps) - so Tremor never shoves
## anybody out of their reach for good. Juggernaut's Tremor.
@export var tremor_follow: bool = false
## Their Guard covers allies within this many tiles too. Warden's Covering Stance.
@export_range(0, 6) var guard_covers: int = 0
## Allies inside their aura cannot be shoved or pulled. Warden's Hold the Line.
@export var holds_the_line: bool = false
## While they stand, allies within this many tiles cannot be felled by a blow:
## it stops at 1 health and the rest lands on them. Warden's Last Wall.
@export_range(0, 6) var last_wall: int = 0
## Their hits on anybody standing beside one of their allies land this much
## harder - only Flanking Skills', when any are listed. Skirmisher's Flanker.
@export_range(0.0, 2.0, 0.05) var flanking_bonus: float = 0.0
@export var flanking_skills: Array[String] = []
## The first hit of theirs on each of the other side in a fight lands this much
## harder: 1.0 is double. Skirmisher's Ambush Strike.
@export_range(0.0, 3.0, 0.05) var opener_bonus: float = 0.0
## While they are in cover, the first attack at them each round misses.
## Skirmisher's Afterimage.
@export var afterimage: bool = false
## Each hit with one of Repeat Skills after the first in a turn lands this much
## harder. Skirmisher's Thousand Cuts.
@export_range(0.0, 2.0, 0.05) var repeat_bonus: float = 0.0
@export var repeat_skills: Array[String] = []
## A Gun hit of theirs - any load - makes each of their own lingering
## conditions on the target tick once more, there and then. Saboteur's Overload.
@export var overload: bool = false
## At the start of each of their turns, the conditions they put on somebody
## spread to everybody of that one's side beside them. Saboteur's Contagion.
@export var contagion: bool = false
## Traps (EffectType.TRAP) more they can have set at once. Trapper's Field of
## Traps - which makes setting one a secondary action through Secondary Skills.
@export_range(0, 5) var extra_traps: int = 0
## Anybody held by one of their traps takes this much more from them. Trapper's
## Grand Snare.
@export_range(0.0, 2.0, 0.05) var bonus_vs_trapped: float = 0.0
## A hit with one of Spellstrike Skills that lands also hits again, at this
## Ability Modifier, free - the cantrip of its element. Elemental Vanguard's.
@export_range(0.0, 3.0, 0.05) var spellstrike: float = 0.0
@export var spellstrike_skills: Array[String] = []
## They take this share less of the element they last used. Elemental Armour.
@export_range(0.0, 0.9, 0.05) var elemental_armour: float = 0.0
## Skill key -> how much harder it hits: {"flame_edge": 0.5}. Avatar.
@export var skill_bonuses: Dictionary = {}
## Their roots and slows last this many turns longer, and their shoves
## go Push Extra tiles further. Elemental Tactician's Battlefield Control.
@export_range(0, 5) var control_extra_turns: int = 0
@export_range(0, 5) var push_extra: int = 0
## How many times a round they can Ward (wards_allies). Shared Ward: 2.
@export_range(0, 5) var wards_per_round: int = 0
## Their spells of Chain Elements leap from whoever they hit to one more of the
## other side within Chain Reach, at Chain Share of the damage. Conductor's Chain.
@export_range(0.0, 2.0, 0.05) var chain_share: float = 0.0
@export_range(0, 10) var chain_reach: int = 0
@export var chain_elements: Array[Damage.Type] = []
## A spell of another element than their last one hits this much harder.
## Conductor's Resonance.
@export_range(0.0, 2.0, 0.05) var resonance: float = 0.0
## Once a short rest, a spell through the deepest gate open to them is cast twice.
## Conductor's Conduit.
@export var conduit: bool = false
## Their damaging spells heal the most hurt of their side within Righteous
## Reach of them for this share of the damage. Battle Chaplain's Righteous.
@export_range(0.0, 2.0, 0.05) var righteous_share: float = 0.0
@export_range(0, 10) var righteous_reach: int = 0
## Allies within Crusade Reach of them hit this much harder. Crusade.
@export_range(0.0, 2.0, 0.05) var crusade_bonus: float = 0.0
@export_range(0, 10) var crusade_reach: int = 0
## While they stand, each of their side's first blow taken in a fight misses.
## Illusory Shepherd's Illusory Guardian.
@export var guards_first_blow: bool = false
## Their hits on anybody they have read land this much harder. Sentence.
@export_range(0.0, 2.0, 0.05) var bonus_vs_read: float = 0.0
## These skills of theirs go through all defence on anybody they have read.
## Final Judgment.
@export var pierce_read_with: Array[String] = []

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
## Contested: it takes hold only of whoever loses - the holder's Aura Contest With
## against their own Aura Resisted By, no dice, weighed as a contested skill is
## (the holder's has to be the higher). The Illusory Dragon's Dread Presence: its
## caster's Intellect against their Mindfulness.
@export var aura_contested: bool = false
@export var aura_contest_with: Stats.Type = Stats.Type.INTELLECT
@export var aura_resisted_by: Stats.Type = Stats.Type.MINDFULNESS

@export_subgroup("Intuition")
## When they read an enemy's next turn (Intuition), these land on the enemy
## read - a fright, or a false future to act on (Deceived, Confused).
@export var on_read_effects: Array[EffectDefinition] = []
## And these on each of their own side the foreseen blow is aimed at - a shield
## or a heal, ahead of it.
@export var forewarn_effects: Array[EffectDefinition] = []
## Their hits land this much harder on an enemy whose foreseen turn the party
## changed, until that enemy's next turn begins (0.25 is a quarter more).
@export_range(0.0, 2.0, 0.05) var thwarted_damage_bonus: float = 0.0


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
	if climbs_anywhere:
		lines.append("Climbs onto high ground from anywhere, and up a wall or pillar to the floor above it.")
	if squeezes:
		lines.append("Folds itself a size narrower or shorter, or both, to fit where it is too big, at twice the movement a step.")
	for key in range_bonuses:
		lines.append("%s reaches %+d tiles." % [_named([key]), range_bonuses[key]])
	if free_item_each_fight != "":
		lines.append("Has a %s to hand in every fight, free, once." % _item_name(free_item_each_fight))
	if not step_after.is_empty() and step_tiles > 0:
		lines.append("After %s, can step up to %d tiles away in a straight line, provoking nothing." % [_named(step_after), step_tiles])
	if amplifies_spells:
		lines.append("Can amplify a spell, casting it through a higher gate for %d%% more damage a gate." % roundi(amplify_bonus_per_gate * 100))
	if not free_amplifies_at.is_empty():
		lines.append("Amplifies for free once a short rest from level %s." % ", once more from level ".join(free_amplifies_at.map(str)))
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
	var unless := ""
	if aura_contested:
		unless = ", unless their %s beats its %s" % [Stats.stat_name(aura_resisted_by), Stats.stat_name(aura_contest_with)]
	if aura_radius > 0 and aura_on_foes != null:
		lines.append("Aura: the other side within %d tiles are %s%s." % [aura_radius, aura_on_foes.display_name.to_lower(), unless])
	if aura_radius > 0 and aura_on_allies != null:
		lines.append("Aura: their own side within %d tiles are %s%s." % [aura_radius, aura_on_allies.display_name.to_lower(), unless])
	if not on_read_effects.is_empty():
		lines.append("Reading an enemy's next turn also does something to them: %s." % _effects_named(on_read_effects))
	if not forewarn_effects.is_empty():
		lines.append("Whoever a read blow is aimed at is forewarned: %s." % _effects_named(forewarn_effects))
	if thwarted_damage_bonus > 0.0:
		lines.append("%d%% more damage to an enemy whose foreseen turn the party changed, until its next turn." % roundi(thwarted_damage_bonus * 100))
	if heals_lift > 0:
		lines.append("Heals lift %s harmful condition%s too." % ["one" if heals_lift == 1 else str(heals_lift), "" if heals_lift == 1 else "s"])
	if heals_leave != null:
		lines.append("Whoever they heal is %s." % heals_leave.display_name.to_lower())
	if heals_spur > 0:
		lines.append("Whoever they heal moves %d tiles further until the end of their next turn." % heals_spur)
	if heals_shield > 0.0:
		lines.append("Their heals leave a shield of %d%% of health%s." % [roundi(heals_shield * 100), (" for %d turns" % heals_shield_turns) if heals_shield_turns > 0 else ""])
	if damage_reduction > 0.0:
		lines.append("Takes %d%% less damage." % roundi(damage_reduction * 100))
	if damage_reduction_in_cover > 0.0:
		lines.append("Takes %d%% less damage in cover." % roundi(damage_reduction_in_cover * 100))
	if party_damage_reduction > 0.0:
		lines.append("While they stand, their side takes %d%% less damage." % roundi(party_damage_reduction * 100))
	if still_damage_bonus > 0.0:
		lines.append("%d%% more damage on a turn they have not walked." % roundi(still_damage_bonus * 100))
	if bonus_vs_weak > 0.0:
		lines.append("%d%% more damage on anybody weak to the hit's element." % roundi(bonus_vs_weak * 100))
	if bonus_vs_lingering > 0.0:
		lines.append("%d%% more damage on anybody taking lingering damage." % roundi(bonus_vs_lingering * 100))
	if party_bonus_vs_afflicted > 0.0:
		lines.append("Their side hits anybody carrying a harmful condition %d%% harder." % roundi(party_bonus_vs_afflicted * 100))
	if party_bonus_vs_own > 0.0:
		lines.append("And %d%% harder again on anybody carrying one of theirs." % roundi(party_bonus_vs_own * 100))
	if kindling_step > 0.0:
		lines.append("Each spell they cast in a fight makes the ones after it %d%% harder, up to %d%%." % [roundi(kindling_step * 100), roundi(kindling_most * 100)])
	elif kindling_most > 0.0:
		lines.append("Kindling builds up to %d%% further." % roundi(kindling_most * 100))
	if dot_bonus > 0.0:
		lines.append("Their lingering damage is %d%% harder." % roundi(dot_bonus * 100))
	if dot_extra_turns > 0:
		lines.append("Their lingering damage lasts %d turn%s longer." % [dot_extra_turns, "" if dot_extra_turns == 1 else "s"])
	if contest_bonus > 0:
		lines.append("+%d to their stat in a stat contest." % contest_bonus)
	if contest_bonus_vs_afflicted > 0:
		lines.append("+%d more in a contest with anybody carrying a harmful condition." % contest_bonus_vs_afflicted)
	if extra_deepest_castings > 0:
		lines.append("%d more casting%s through the deepest gate open to them." % [extra_deepest_castings, "" if extra_deepest_castings == 1 else "s"])
	if movement_in_cover != 0:
		lines.append("%+d movement on a turn they start in cover." % movement_in_cover)
	if slips_into_cover:
		lines.append("Stepping into cover sets off nothing.")
	if hems_in > 0:
		lines.append("Tiles within %d of them cost the other side twice the movement." % hems_in)
	if exposes_within > 0 and exposes_with != null:
		lines.append("Anybody of the other side ending a turn within %d of them without hurting them is %s." % [exposes_within, exposes_with.display_name.to_lower()])
	lines.append_array(_describe_paths())
	return lines


## The paths' switches (the "Paths" subgroup), a line each.
func _describe_paths() -> Array:
	var lines := []
	for kind in immune_to:
		lines.append("Immune to %s." % Immunity.name_of(kind))
	for condition in immune_to_conditions:
		if condition != null:
			lines.append("Cannot be %s." % condition.display_name.to_lower())
	if unstoppable:
		lines.append("Nothing lowers their movement or roots them.")
	if charge_bonus > 0.0:
		lines.append("Having walked %d tiles or more in a turn, their next hit lands %d%% harder." % [charge_tiles, roundi(charge_bonus * 100)])
	if felling_refreshes:
		lines.append("Felling somebody on their turn gives their main action back%s." % ((" and %d more movement" % felling_movement) if felling_movement > 0 else ""))
	if tremor_share > 0.0:
		lines.append("Their hits also hit everybody beside the target for %d%%, shoving them all a tile%s." % [roundi(tremor_share * 100),
			(" - into something solid, %s" % tremor_impact_condition.display_name.to_lower()) if tremor_impact_condition != null else ""])
	if tremor_follow:
		lines.append("After such a hit, can step a tile toward whoever they hit, for a tile of movement.")
	if guard_covers > 0:
		lines.append("Their Guard covers allies within %d too." % guard_covers)
	if holds_the_line:
		lines.append("Allies inside their aura cannot be shoved or pulled.")
	if last_wall > 0:
		lines.append("While they stand, a blow cannot fell an ally within %d: it stops at 1 health, and the rest lands on them." % last_wall)
	if flanking_bonus > 0.0:
		lines.append("%s %d%% harder on anybody standing beside one of their allies." % [
			"Their hits land" if flanking_skills.is_empty() else "%s lands" % _skill_names(flanking_skills), roundi(flanking_bonus * 100)])
	if opener_bonus > 0.0:
		lines.append("Their first hit on each enemy in a fight lands %d%% harder." % roundi(opener_bonus * 100))
	if afterimage:
		lines.append("In cover, the first attack at them each round misses.")
	if repeat_bonus > 0.0:
		lines.append("Each %s after the first in a turn lands %d%% harder." % [_skill_names(repeat_skills), roundi(repeat_bonus * 100)])
	if overload:
		lines.append("A Gun hit makes each of their lingering conditions on the target tick once more, at once.")
	if contagion:
		lines.append("Their conditions spread to everybody beside whoever has them, as each of their turns starts.")
	if extra_traps > 0:
		lines.append("%d more trap%s set at once." % [extra_traps, "" if extra_traps == 1 else "s"])
	if bonus_vs_trapped > 0.0:
		lines.append("Anybody held by their traps takes %d%% more from them." % roundi(bonus_vs_trapped * 100))
	if spellstrike > 0.0:
		lines.append("%s that lands strikes again with its element, x%s, free." % [_skill_names(spellstrike_skills), String.num(spellstrike, 2)])
	if elemental_armour > 0.0:
		lines.append("Takes %d%% less of the element they last used." % roundi(elemental_armour * 100))
	for key in skill_bonuses:
		lines.append("%s hits %d%% harder." % [_skill_names([key]), roundi(float(skill_bonuses[key]) * 100)])
	if control_extra_turns > 0:
		lines.append("Their roots and slows last %d turn%s longer." % [control_extra_turns, "" if control_extra_turns == 1 else "s"])
	if push_extra > 0:
		lines.append("Their shoves go %d tile%s further." % [push_extra, "" if push_extra == 1 else "s"])
	if wards_per_round > 1:
		lines.append("Can Ward %d times a round." % wards_per_round)
	if chain_share > 0.0:
		lines.append("Their %s spells leap to one more within %d, at %d%%." % [
			"/".join(chain_elements.map(func(element): return Damage.type_name(element).to_lower())), chain_reach, roundi(chain_share * 100)])
	if resonance > 0.0:
		lines.append("A spell of another element than their last hits %d%% harder." % roundi(resonance * 100))
	if conduit:
		lines.append("Once a short rest, a spell through their deepest gate is cast twice.")
	if righteous_share > 0.0:
		lines.append("Their damaging spells heal the most hurt ally within %d for %d%% of the damage." % [righteous_reach, roundi(righteous_share * 100)])
	if crusade_bonus > 0.0:
		lines.append("Allies within %d of them hit %d%% harder." % [crusade_reach, roundi(crusade_bonus * 100)])
	if guards_first_blow:
		lines.append("While they stand, each ally's first blow taken in a fight misses.")
	if bonus_vs_read > 0.0:
		lines.append("Their hits land %d%% harder on anybody they have read." % roundi(bonus_vs_read * 100))
	if not pierce_read_with.is_empty():
		lines.append("%s goes through all defence on anybody they have read." % _skill_names(pierce_read_with))
	return lines


## Skill keys as the player knows them: "Rapier", "Flame Edge and Frost Edge".
static func _skill_names(keys: Array) -> String:
	var names := []
	for key in keys:
		var skill = SkillDatabase.skills.get(key) if SkillDatabase.skills != null else null
		names.append(skill.name if skill != null else String(key).capitalize())
	if names.size() <= 1:
		return "" if names.is_empty() else names[0]
	return "%s and %s" % [", ".join(names.slice(0, -1)), names[-1]]


## What a list of effects does, briefly: their names, or what they inflict.
static func _effects_named(effects: Array) -> String:
	var names := []
	for effect in effects:
		if effect == null:
			continue
		if effect.display_name != "":
			names.append(effect.display_name)
		elif effect.condition != null:
			names.append(effect.condition.display_name)
		else:
			names.append(EffectDefinition.EffectType.keys()[effect.type].capitalize())
	return ", ".join(names) if not names.is_empty() else "nothing yet"


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
