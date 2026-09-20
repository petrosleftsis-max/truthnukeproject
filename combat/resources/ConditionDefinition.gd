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
## ones the game ships with live in res://conditions/.


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
## Freeform text for the tooltip. Optional - one is generated from the settings
## below when this is empty.
@export_multiline var description: String = ""
## How many of the afflicted's own turns it lasts. Counted the same way every
## other duration is: landing on whoever is currently acting costs it the rest
## of that turn (see Combat.stored_duration).
@export var duration: int = 3

@export_group("Damage over time")
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

@export_group("Stat changes")
## Added to movement while this is active - negative slows, positive hurries.
@export var movement_change: int = 0
## Added to every hit-chance roll the afflicted makes. Fear's -20 lives here.
@export var accuracy_change: int = 0

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

@export_group("Forced movement")
## At the start of their turn they are blown this many tiles in a random
## direction, stopping early at a wall, the map edge or another combatant.
## This is not their own movement: it spends none of their budget and provokes
## no reactive skills, because they aren't choosing to go.
@export var drift_tiles: int = 0


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
	if prevents_movement:
		parts.append("cannot move")
	if prevents_approach:
		parts.append("cannot advance on enemies")
	if prevents_secondary:
		parts.append("no secondary action")
	if prevents_reactions:
		parts.append("no reactions")
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
