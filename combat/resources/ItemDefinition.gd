extends SkillDefinition
class_name ItemDefinition
## A consumable: something carried, used once, and gone.
##
## Deliberately a SkillDefinition. Everything a skill can describe - range,
## accuracy, area, conditions inflicted, what it sounds like, whether it costs
## the main action or the secondary one - an item should be able to describe
## too, and making it the same kind of thing means every path that already
## resolves, aims, previews and resolves a skill handles items without knowing
## they exist. ItemDatabase registers these alongside the skills for that
## reason.
##
## Two things differ, and they are the two fields below.


@export_group("Item")
## What this item is worth - its own attribute, standing where a caster's stat
## stands on a skill.
##
## A bomb is a bomb whoever throws it, so nothing of the thrower goes into this.
## Everything else works exactly as it does for a skill: the damage is
## ItemPower x AbilityModifier soaked by the target's Defense, a condition ticks
## for ItemPower x the effect's ConditionDotModifier soaked the same way, and a
## heal is ItemPower x HealModifier. So one number says how strong the item is
## and the modifiers say how it is spent, which is the same pair of dials every
## skill has.
##
## It also decides a contest, for the same reason a caster's stat does: a
## stronger bottle is both harder to shrug off and worse to be hit by. That was
## the bug this replaced - the contest read the thrower's hidden scaling_stat,
## so on the laboratory Priest Enfina landed four bottles of eight and Alithia
## none, with nothing on any bottle saying why.
##
## 20 is the middle of the attribute range a character actually reaches, so a
## bottle left alone is worth about what an ordinary person is.
@export_range(0, 999, 1, "or_greater") var item_power: int = 20

## Whether using one takes it out of the inventory. On by default, since that
## is what "consumable" means; off for anything reusable that should still live
## in a bag rather than in a skill list.
@export var consumed_on_use: bool = true

@export_group("Disguise")
## Makes this a disguise rather than something to use: on a stealth map, the
## one sneaking can wear it and pass for this combatant (a key into
## CombatantDatabase - "priest" to pass for a Priest). Guards who do not see
## through it walk straight past; see Guard.recognises. Empty for every
## ordinary item. A disguise is never offered in a fight.
@export var disguise_as: String = ""

@export_group("Distraction")
## Makes this something to throw on a stealth map (T, then click where): it
## lands with a noise, and every guard within this many tiles of it goes to see
## what it was. Zero for every ordinary item. Like a disguise, never offered in
## a fight.
@export var distraction_radius: float = 0.0

## What a poison does to whoever it gets into, on a stealth map. Stored by
## number, so a new one goes on the end.
enum Poison {
	NONE,      ## Not a poison.
	EMETIC,    ## Off to be sick - wherever the map says that is (a RetchSpot) - for five minutes, seeing nothing.
	SEDATIVE,  ## Out cold where they stand: a body, to be found and brought round like any other.
	DISEASE,   ## Too unwell to move, and whoever is nearest comes to see to them - both of them watching half as wide.
}

## How soon a poison takes hold once swallowed, or once a dart lands. Stored
## by number, so a new one goes on the end.
enum Onset {
	SHORTLY,  ## A few seconds after.
	DELAYED,  ## About a quarter of a minute after - long enough to be well away.
	INSTANT,  ## The moment it is swallowed or lands.
}

@export_group("Poison")
## Makes this a poison for a stealth map, and what it does. Like a disguise,
## never offered in a fight.
@export var poison: Poison = Poison.NONE
## How soon it takes hold - see StealthWatch.POISON_SOON and POISON_DELAY.
@export var poison_onset: Onset = Onset.SHORTLY
## A dart (T, then click a guard): it takes hold where it lands. Otherwise it
## only goes into something left out to eat or drink (see Edible).
@export var poison_shootable: bool = false

@export_group("Keepsake")
## Only worth carrying: a letter, a ledger, a key - something to steal, plant
## or hand over. Carried like anything else, and never offered in a fight.
@export var keepsake: bool = false

@export_group("Combining")
## The two items, by key, this is made from by putting them together: in the
## bag under a picture (pick one up, then click the other), or in the party's
## bags (I: click one, then the other). Both are used up. Empty for anything
## that is not made.
@export var made_from: Array[String] = []
## What putting them together says, under the picture.
@export_multiline var combine_text: String = ""

@export_group("Looking")
## A lens - a magnifying glass, a lamp. Picked up from the bag under a picture,
## it shows whatever there is marked Hidden Detail (a Hotspot, a PictureLayer)
## wherever it is held over it. Never offered in a fight.
@export var reveals_hidden_details: bool = false


## Whether this is something worn rather than something used.
func is_disguise() -> bool:
	return disguise_as != ""


## Whether this is something thrown on a stealth map to draw guards off.
func is_distraction() -> bool:
	return distraction_radius > 0.0


## Whether this is a poison for a stealth map.
func is_poison() -> bool:
	return poison != Poison.NONE


## Whether this only has a use on a stealth map - worn, thrown or slipped into
## somebody's supper there - or none in a fight at all, and so is left out of
## every fight.
func stealth_only() -> bool:
	return is_disguise() or is_distraction() or is_poison() or keepsake or reveals_hidden_details


## An item scales off itself, so the attribute a skill would read would only
## mislead. AbilityModifier is not hidden with it - it means the same thing here
## as it does anywhere, and it is half of how an item is tuned.
##
## Hidden rather than removed, because it still exists on the parent and
## something reading it should find a sensible value. Nothing does read it now,
## which is the point: it used to decide contests from behind this very line.
func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	if property.name == "scaling_stat":
		property.usage &= ~PROPERTY_USAGE_EDITOR
