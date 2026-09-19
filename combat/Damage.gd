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


## Every type in the game. The numbers are stored in resources, so new ones go
## on the END - inserting one in the middle turns every existing skill's damage
## into a different element. See CATEGORIES below for what each one is.
enum Type {
	PHYSICAL,
	FIRE,
	WATER,
	WIND,
	EARTH,
	POISON,
	PSYCHIC,
	PLASMA,
	ICE,
	LIGHTNING,
	METAL,
	ACID,
	IDOL,
}


## What kind of thing a type is.
##
## BASE are the five elements. Each has an UPGRADED form it can be raised into -
## Prometheus upgrading his Fireball makes it deal Plasma rather than Fire - and
## an upgraded type is its own element for resistance, not a stronger version of
## the one it came from. SPECIAL are the three that are nobody's element and
## cannot be upgraded into or out of.
enum Category {
	BASE,
	UPGRADED,
	SPECIAL,
	## Nothing is this. Kept as what category_of answers for a number that is
	## not a damage type at all, rather than having it guess at one.
	UNCATEGORISED,
}


const CATEGORIES := {
	Type.FIRE: Category.BASE,
	Type.WATER: Category.BASE,
	Type.WIND: Category.BASE,
	Type.EARTH: Category.BASE,
	Type.POISON: Category.BASE,

	Type.PLASMA: Category.UPGRADED,
	Type.ICE: Category.UPGRADED,
	Type.LIGHTNING: Category.UPGRADED,
	Type.METAL: Category.UPGRADED,
	Type.ACID: Category.UPGRADED,

	Type.PHYSICAL: Category.SPECIAL,
	Type.PSYCHIC: Category.SPECIAL,
	Type.IDOL: Category.SPECIAL,
}


## Which base element becomes which upgraded one.
const UPGRADES := {
	Type.FIRE: Type.PLASMA,
	Type.WATER: Type.ICE,
	Type.WIND: Type.LIGHTNING,
	Type.EARTH: Type.METAL,
	Type.POISON: Type.ACID,
}


static func category_of(type: int) -> Category:
	return CATEGORIES.get(type, Category.UNCATEGORISED)


## The upgraded form of `type`, or `type` itself when it has none. Safe to call
## on anything - an already-upgraded type comes back unchanged rather than
## climbing a second rung that does not exist.
static func upgraded_form(type: int) -> int:
	return UPGRADES.get(type, type)


## The base element an upgraded type came from, or `type` itself when it is not
## an upgrade of anything.
static func base_form(type: int) -> int:
	for base in UPGRADES:
		if UPGRADES[base] == type:
			return base
	return type


static func can_upgrade(type: int) -> bool:
	return UPGRADES.has(type)


static func is_upgraded(type: int) -> bool:
	return category_of(type) == Category.UPGRADED


## Every type in one category, in enum order - for a glossary page, or an
## editor hint that wants to offer only the elements.
static func types_in(category: Category) -> Array:
	var found := []
	for type in Type.values():
		if category_of(type) == category:
			found.append(type)
	return found

## Order matters: these line up with Type, and are what @export_enum hints and
## the combat log use.
const TYPE_NAMES := ["Physical", "Fire", "Water", "Wind", "Earth", "Poison", "Psychic",
	"Plasma", "Ice", "Lightning", "Metal", "Acid", "Idol"]


## What a combatant's resistance to `type` is called on their definition, and
## in any timed effect that changes it.
static func resistance_key(type: int) -> String:
	return "resist_" + type_name(type).to_lower().replace(" ", "_")


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
	Color("ff9de6"), # Plasma - fire raised past burning
	Color("a8e6ff"), # Ice
	Color("b39dff"), # Lightning
	Color("b9c4cf"), # Metal
	Color("d4ff4a"), # Acid
	Color("ffb35c"), # Idol
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
