@icon("res://art/editor_icons/condition.svg")
extends Resource
class_name ConditionDefinition
## A named condition a combatant can be suffering from - Poisoned, Stunned,
## Burned and so on.
##
## Conditions differ from a plain STAT_MODIFIER in that they bundle several
## things under one name: damage over time, stat changes, and rules about what
## the afflicted may do on their turn. One resource describes all of it, so
## "Poisoned" is a single thing to apply, display and dispel rather than a
## handful of separate effects that happen to arrive together.
##
## Apply one with an EffectDefinition of type CONDITION pointing at it. The
## ones the game ships with live in res://data/conditions/.


## How hard the tick reads in the glossary. Kept as a word rather than a number
## because a condition's real damage depends on who inflicted it - the book is
## read long before any of that is known.
##
## Stored by number in every .tres, so a new strength goes on the END.
enum DotStrength { NONE, WEAK, MEDIUM, STRONG, POWERFUL }

const DOT_STRENGTH_NAMES := {
	DotStrength.WEAK: "Weak",
	DotStrength.MEDIUM: "Medium",
	DotStrength.STRONG: "Strong",
	DotStrength.POWERFUL: "Powerful",
}


@export var display_name: String = ""
## The two letters on its mark beside a portrait. Empty, the first two of its
## name - set it only when those are some other condition's already (Staggered
## and Stunned).
@export var tag: String = ""
## Freeform text for the tooltip. Optional - one is generated from the settings
## below when this is empty.
@export_multiline var description: String = ""
## How many of the afflicted's own turns it lasts: 3 is three of their turns,
## Stunned 2 is two lost, a Burn of 3 three ticks. Landing on whoever is acting,
## they have the rest of this turn as well. Wears Off At Start below picks
## whether it goes as the turn after the last starts, or as the last ends (see
## Combat.turns_stored).
@export var duration: int = 3
## Off: holds through the last of its turns and wears off as that turn ends, so
## whatever is on somebody is still on them while they act.
## On: wears off as the turn after its last starts, the moment before they could
## act under it - lasting through everybody else's turns in between. The danger
## view knows these go before the enemy acts.
@export var wears_off_at_start: bool = false

@export_group("Damage over time")
## What each tick sounds like. Empty: the sound of the move that put it on.
@export var tick_sound: AudioStream
## Rolled fresh at the start of each of the afflicted's turns. Leave at 0 for a
## condition that doesn't burn away at them.
## What kind of damage the tick deals - Burn is fire, Poisoned is poison - so
## resistances apply to conditions the same as to a direct hit.
@export var dot_type: Damage.Type = Damage.Type.PHYSICAL
## How hard this hits, in the one word the glossary prints. Purely descriptive -
## nothing reads it but the book.
@export var dot_strength: DotStrength = DotStrength.NONE
## How hard the tick is when a SKILL inflicts this, as a fraction of a direct
## hit from whoever cast it: the same WeaponBase + 0.7 x Stat, times this, times
## the target's defence soak. So a Burn from a stronger caster genuinely burns
## harder, without a number here to maintain per level.
@export_range(0.0, 5.0, 0.05, "or_greater") var dot_modifier: float = 0.0
## What the tick is worth when an ITEM inflicts this instead, rolled fresh each
## turn.
##
## A bomb is a bomb whoever throws it - the rule a consumable's direct damage
## already follows - so an item's version of a condition is the number written
## on the tin rather than a multiple of the thrower's attributes. A skill never
## reads these.
@export var dot_min: int = 0
@export var dot_max: int = 0

@export_group("Light")
## Whoever has this on them gives light, this many tiles out, the nearer half of it Bright (Burn).
@export var light_tiles: float = 0.0

@export_group("Stat changes")
## Added to movement while this is active - negative slows, positive hurries.
@export var movement_change: int = 0
## Added to every hit-chance roll the afflicted makes. Fear's -20 lives here.
@export var accuracy_change: int = 0
## Damage taken changes by this share while it is on them: -0.1 takes a tenth
## less (Bulwark's, Mercy III's Sheltered), 0.2 a fifth more.
@export_range(-0.9, 2.0, 0.05) var damage_taken_change: float = 0.0
## Mends this share of their health as each of their turns starts (Aura II).
@export_range(0.0, 1.0, 0.05) var mends_share: float = 0.0
## Their Defense changes by this share while it is on them: -0.1 is a tenth less
## (Corroded). It lasts exactly as long as the condition, refreshes with it
## rather than stacking, and goes when it is cleansed. Anybody immune to being
## weakened keeps their Defense.
@export_range(-0.9, 2.0, 0.05) var defense_change: float = 0.0

@export_group("Restrictions")
## Their turn is skipped entirely.
@export var skips_turn: bool = false
## Caps the range of every skill they use at this many tiles. 0 = no cap.
## Blind sets this to 1.
@export var max_range: int = 0
## They can't move at all this turn.
@export var prevents_movement: bool = false
## They can't move to a tile closer to their nearest enemy than the one they
## are standing on - they may hold position or back away, but not advance.
@export var prevents_approach: bool = false
## Their secondary action slot is unavailable.
@export var prevents_secondary: bool = false
## They can't use reactive skills while this lasts.
@export var prevents_reactions: bool = false
## Confused: their turn is not theirs to take. They go for whoever is nearest -
## friend or foe - with whatever they have that hurts, and nothing else
## (Combat.ai_confused). The party's too, played for them.
@export var confuses: bool = false
## Exposed: they take this share more from whoever put it on them - nobody
## else. Put on by nobody in particular, it does nothing.
@export_range(0.0, 2.0, 0.05) var more_from_source: float = 0.0
## Deceived: their turn goes on their own side - the nearest of them, with
## whatever hurts (Combat.ai_deceived). The party's too, played for them.
@export var turns_on_own_side: bool = false
## It comes off the moment they are hurt - talked into standing down, and
## then hit.
@export var ends_when_hit: bool = false
## Their weapon attacks - a skill that is neither a spell nor an item - deal
## this share more or less: -0.5 is half. Disarmed.
@export_range(-0.9, 2.0, 0.05) var weapon_damage_change: float = 0.0
## It comes off once they have made a weapon attack - their next one is the one
## it touches. Disarmed.
@export var ends_after_weapon_attack: bool = false
## Damage they take frays no tether of theirs while it is on them. Composure, and
## whoever somebody else is taking a share for (Shared Burden).
@export var keeps_tether_when_hurt: bool = false
## Whoever put it on them takes this share of the damage they would have taken - and
## it frays no tether of the one taking it (Combat "Shared Burden").
@export_range(0.0, 0.9, 0.05) var source_takes_share: float = 0.0
## They cast no spells while it is on them: nothing through a gate, as an action,
## a reaction or something readied. A Gate Nade is thrown, not cast. Silenced.
@export var prevents_spells: bool = false
## Their next turn is not theirs: they do what they were ordered to as it landed,
## and end it (Combat "Orders"). Compelled.
@export var obeys_order: bool = false

@export_group("Illusions and favours")
## The next attack that would hit them misses - an image takes it - and this
## comes off. Phantom Body.
@export var evades_next_hit: bool = false
## Each attack at them has this chance in a hundred to miss outright - a copy
## takes it. Sanctified, Mirage.
@export_range(0, 100) var miss_chance: int = 0
## They take this share less from attacks made from more than a tile away.
## Blurred (Veil of Mercy II).
@export_range(0.0, 0.9, 0.05) var less_from_afar: float = 0.0
## Their spells cost no gate while it lasts, and a spell can be their secondary
## action too. Grand Design.
@export var casts_freely: bool = false
## While they have it, they are invisible (Combat "Invisibility") - from a zone
## (Combat "Zones"), again as each of their turns starts if they gave themselves
## away, and seen again once they step out. Reflected (Reality's Reflection).
@export var makes_invisible: bool = false
## They look dead: invisible for as long as they have it, lying where they are, and anything they do
## gives it away - a step or a move (Combat "Unnoticed until they act"). Looks Dead (Fallen Friend).
@export var looks_dead: bool = false
## They cannot hide or go invisible, and the dark does not take them (Votive Flame's mark).
@export var cannot_hide: bool = false
## Their whole other side can see them, for as long as this lasts, whatever hides them (Calling Out).
@export var called_out: bool = false
## Dispel Magic takes it off through any gate, though no spell of a gate put it on (a cantrip's).
@export var dispellable: bool = false
## Put on them once they have walked to what drew them (an effect's Drawn To Aim): Beckoning Light's Off Guard.
@export var on_arrival: ConditionDefinition
## A thing believed in, weighed again: as each of their turns starts they contest the spell that put
## it on them once more, their stat counting this much more for every time they have, and winning
## shakes it off before it ticks. 0, never. Phantom Wound (Phantom Killer).
@export_range(0, 20) var doubt_each_turn: int = 0
## Grappled: held by whoever put it on, for as long as that one keeps hold.
## It lasts until they break free (Break Free, their main action), whoever
## holds them is not beside them or is down, or either of them is teleported,
## shoved or thrown (Combat "Holding on"). One held at a time each.
@export var holds: bool = false
## The next this many blows at one tile that would hit them each strike an image of
## them instead, and one image goes. It comes off with the last (Four Reflections).
## An area finds them all the same.
@export_range(0, 9) var evades_hits: int = 0
## This is darkness (a zone's): anybody standing in it is invisible to whoever cannot
## see in the dark, as Makes Invisible is, and acting against the other side gives them
## away until their next turn (Combat "In the dark").
@export var is_darkness: bool = false
## They see in the dark: anybody in darkness is in plain sight to them. Clear Sight.
@export var sees_in_darkness: bool = false
## They see whoever is invisible or hidden as if they were not. Clear Sight.
@export var sees_the_unseen: bool = false
## They climb anywhere while it is on them, as Cat Burglar does. Cling.
@export var climbs_anywhere: bool = false
## They cannot be given these while it is on them, and any of them they have now
## comes off as it lands. Unafraid (Steady Heart).
@export var immune_to_conditions: Array[ConditionDefinition] = []
## Whoever has it shows the whole party the other side's unseen ground and unseen traps (Detect Magic).
@export var sees_magic: bool = false

@export_group("Weather")
## Damage of these kinds taken changes by Damage Taken Of Change while it is on them (Soaked: ice and lightning).
@export var damage_taken_of: Array[Damage.Type] = []
@export_range(-0.9, 2.0, 0.05) var damage_taken_of_change: float = 0.0
## These put on whoever has this last Lengthens By turns longer (Soaked: Frozen).
@export var lengthens: Array[ConditionDefinition] = []
@export_range(0, 5) var lengthens_by: int = 0
## Turns longer when put on in the heat of the day, or in the cold (the designer, 2026-11-07: "Burns last longer in heat, Frozen
## longer in cold").
@export_range(0, 5) var longer_in_heat: int = 0
@export_range(0, 5) var longer_in_cold: int = 0

@export_group("On The Figure")
## How it shows on whoever has it (ConditionLook), one at a time: the highest Figure Priority, those equal taking turns.
## A colour over them, breathing, as strong as its alpha. No alpha: none.
@export var figure_tint: Color = Color(0, 0, 0, 0)
## What goes round their head, or their feet. Stored by number: append.
enum RoundThem { NONE, STARS, SPIRAL, BAND_OVER_EYES, SWEAT, CHAIN, GAG, STRINGS, ARROW, EXCLAIM }
@export var round_them: RoundThem = RoundThem.NONE
## How much less they are mended by anything: -0.5 half, -1 not at all (Withering Touch, Blight).
@export_range(-1.0, 1.0, 0.05) var healing_taken_change: float = 0.0
## What it does each turn lands on whoever put it on them, not on them (Share the Fire).
@export var dot_lands_on_source: bool = false
## The picture on this condition's mark on the portraits and the turn queue, in place of the placeholder with its two letters.
@export var mark_picture: Texture2D = null
## A picture to go there in place of the placeholder, circling slowly.
@export var round_them_picture: Texture2D = null
## What comes off them. Stored by number: append.
enum OffThem { NONE, EMBERS, DRIPS, FROST, SOFT_LIGHT, SPARKS, WIND }
@export var off_them: OffThem = OffThem.NONE
## A picture for each of those particles, in place of the placeholder's dot.
@export var off_them_picture: Texture2D = null
## No ring under their feet for this one, which a condition otherwise gets: green for what helps, red for what hurts.
@export var figure_no_ring: bool = false
## The animation they play in place of idle while it is on them (stunned, afraid, frozen). They stand idle if they have none by that name.
@export var figure_pose: StringName = &""
@export var figure_priority: int = 1
## The word that pops up over them as it lands. Empty: its name.
@export var arrival_word: String = ""

@export_group("Forced movement")
## At the start of their turn they are blown this many tiles in a random
## direction, stopping early at a wall, the map edge or another combatant.
## This is not their own movement: it spends none of their budget and provokes
## no reactive skills, because they aren't choosing to go.
@export var drift_tiles: int = 0

@export_group("Lying down")
## Above 0, this is somebody lying down (Combat "Prone"): they do not walk until
## they get up, which takes this share of their movement, rounded up. Nothing lifts
## it for them - no heal, cleanse or dispel - since it is no harm done.
@export_range(0.0, 1.0, 0.05) var getting_up_share: float = 0.0
## They take this share less from whatever is not melee: ranged moves and areas.
@export_range(0.0, 0.9, 0.05) var less_from_ranged: float = 0.0
## They take this share more from melee: 1 is double.
@export_range(0.0, 3.0, 0.05) var more_from_melee: float = 0.0


## One line for the tooltip and the status icon. Uses `description` when one is
## written, otherwise says what the settings actually do.
func describe() -> String:
	if description != "":
		return description
	var parts: Array[String] = []
	if skips_turn:
		parts.append("loses their turn")
	if describe_dot() != "":
		parts.append(describe_dot())
	if max_range > 0:
		parts.append("skill range capped at %d" % max_range)
	if movement_change != 0:
		parts.append("%+d movement" % movement_change)
	if accuracy_change != 0:
		parts.append("%+d accuracy" % accuracy_change)
	if defense_change != 0.0:
		parts.append("%+d%% defense" % roundi(defense_change * 100))
	if getting_up_share > 0.0:
		parts.append("getting up takes %d%% of their movement" % roundi(getting_up_share * 100))
	elif prevents_movement:
		parts.append("cannot move")
	if less_from_ranged > 0.0:
		parts.append("%d%% less from ranged moves and areas" % roundi(less_from_ranged * 100))
	if more_from_melee > 0.0:
		parts.append("%d%% more from melee" % roundi(more_from_melee * 100))
	if prevents_approach:
		parts.append("cannot advance on enemies")
	if prevents_secondary:
		parts.append("no secondary action")
	if prevents_reactions:
		parts.append("no reactions")
	if prevents_spells:
		parts.append("cannot cast spells")
	if evades_hits > 0:
		parts.append("the next %d single blows strike an image instead" % evades_hits)
	if is_darkness:
		parts.append("invisible to whoever cannot see in the dark")
	if cannot_hide:
		parts.append("cannot hide or go invisible")
	if called_out:
		parts.append("seen by everybody on the other side, whatever hides them")
	if sees_in_darkness:
		parts.append("sees in the dark")
	if sees_the_unseen:
		parts.append("sees the invisible and the hidden")
	if climbs_anywhere:
		parts.append("climbs anywhere")
	if keeps_tether_when_hurt:
		parts.append("damage frays no tether of theirs")
	if source_takes_share > 0.0:
		parts.append("whoever put this on them takes %d%% of what they would take" % roundi(source_takes_share * 100))
	if obeys_order:
		parts.append("their next turn goes as they were ordered")
	if not immune_to_conditions.is_empty():
		parts.append("immune to %s" % ", ".join(immune_to_conditions.map(func(each): return each.display_name if each != null else "?")))
	if weapon_damage_change != 0.0:
		parts.append("%s weapon attack %+d%% damage" % ["next" if ends_after_weapon_attack else "every", roundi(weapon_damage_change * 100)])
	if drift_tiles > 0:
		parts.append("blown %d tiles each turn" % drift_tiles)
	if parts.is_empty():
		return "No effect"
	return ", ".join(parts).capitalize()


## "Powerful Fire Damage Over Time", or empty for a condition that does not
## tick. Damage.type_name already comes capitalised, so the whole phrase reads
## as a title without anything being recased here.
func describe_dot() -> String:
	if not DOT_STRENGTH_NAMES.has(dot_strength):
		return ""
	return "%s %s Damage Over Time" % [
		DOT_STRENGTH_NAMES[dot_strength], Damage.type_name(dot_type)]
