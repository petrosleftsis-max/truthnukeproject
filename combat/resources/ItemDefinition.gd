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
## What it does, as a flat number, in place of a skill's stat scaling.
##
## A bomb is a bomb whoever throws it: an item's power is what is written on
## the tin rather than a multiple of the user's attributes, so a weak character
## and a strong one get the same value out of one. Damage is still contested -
## the target's Defense soaks it exactly as it soaks a skill's - so a flat 30
## lands harder on the unarmoured. A heal is simply the number.
@export_range(0, 999, 1, "or_greater") var flat_power: int = 0

## Whether using one takes it out of the inventory. On by default, since that
## is what "consumable" means; off for anything reusable that should still live
## in a bag rather than in a skill list.
@export var consumed_on_use: bool = true


## An item's power is its own, so the stat-scaling fields a skill shows would
## only mislead. Hidden rather than removed, because they still exist on the
## parent and something that reads them should find sensible values.
func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	if property.name in ["scaling_stat", "ability_modifier"]:
		property.usage &= ~PROPERTY_USAGE_EDITOR
