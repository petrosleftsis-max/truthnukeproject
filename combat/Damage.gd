extends RefCounted
class_name Damage
## The kinds of damage in the game, and the one place that knows how a
## combatant's resistance to each changes what actually lands.
##
## A skill's DAMAGE effect, a damage-over-time effect and a condition that
## burns all carry a type. A combatant carries a percentage per type, set on
## their CombatantDefinition - positive resists, negative is a vulnerability -
## so resistances are per-character data rather than anything to do with which
## AI drives them.


enum Type {
	PHYSICAL,
	FIRE,
	WATER,
	WIND,
	EARTH,
	POISON,
	PSYCHIC,
	PURE_ENERGY,
}

## Order matters: these line up with Type, and are what @export_enum hints and
## the combat log use.
const TYPE_NAMES := ["Physical", "Fire", "Water", "Wind", "Earth", "Poison", "Psychic", "Pure Energy"]


## The colour each type reads as when it lands - the brief tint on a struck
## combatant, and the colour its damage number floats up in. Lines up with
## Type, same as TYPE_NAMES.
##
## Physical is deliberately near-white: it is the default and by far the most
## common, and giving it a hue of its own would make every ordinary sword
## swing look elemental.
const TYPE_COLOURS := [
	Color("e4e4e4"), # Physical
	Color("ff6a30"), # Fire
	Color("4aa8ff"), # Water
	Color("9fe8cd"), # Wind
	Color("c08a4a"), # Earth
	Color("8fd14a"), # Poison
	Color("cc72e0"), # Psychic
	Color("ffe066"), # Pure Energy
]


static func type_colour(type: int) -> Color:
	return TYPE_COLOURS[type] if type >= 0 and type < TYPE_COLOURS.size() else Color.WHITE


static func type_name(type: int) -> String:
	return TYPE_NAMES[type] if type >= 0 and type < TYPE_NAMES.size() else "Unknown"


## What `amount` of `type` damage becomes after `resistance` percent is applied.
##
## 20 means a fifth is shrugged off; -20 means a fifth extra gets through; 100
## means immune. Rounded, and never negative - a resistance above 100 heals
## nobody, it just stops at zero.
static func after_resistance(amount: int, resistance: int) -> int:
	if resistance == 0:
		return amount
	return maxi(int(round(amount * (1.0 - resistance / 100.0))), 0)


## A short note for the combat log saying the damage was changed, or "" when it
## landed as written.
static func describe_resistance(resistance: int) -> String:
	if resistance > 0:
		return " (resisted)"
	if resistance < 0:
		return " (vulnerable)"
	return ""
