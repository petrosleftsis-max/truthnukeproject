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
