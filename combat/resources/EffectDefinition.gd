extends Resource
class_name EffectDefinition
## One effect a skill applies to its target on a successful hit.
## A single skill can carry several of these (e.g. Damage + a movement-slowing
## STAT_MODIFIER) - Combat.gd applies each of them in order.

enum EffectType {
	DAMAGE,
	HEAL,
	STAT_MODIFIER,     ## A timed buff/debuff on any stat, e.g. -2 movement for 2 turns.
	DAMAGE_OVER_TIME,  ## Ticks damage at the start of the target's own turns, for a duration.
	DISPEL,            ## Removes existing STAT_MODIFIER/STAT_MULTIPLIER/DAMAGE_OVER_TIME effects from the target.
	PUSH,              ## Shoves the target directly away from the caster.
	PULL,              ## Drags the target directly towards the caster.
	STAT_MULTIPLIER,   ## Multiplies a stat instead of adding to it, e.g. doubling movement for a turn.
	CONDITION          ## Inflicts a named ConditionDefinition - Poisoned, Stunned, Burned and so on.
}

enum DispelScope {
	BOTH,
	BUFFS_ONLY,   ## Only removes effects with a positive amount. Never touches DoTs.
	DEBUFFS_ONLY  ## Removes effects with a negative amount, and all damage-over-time effects.
}

@export var type: EffectType = EffectType.DAMAGE : set = _set_type
## What this condition is called in the combat log - "Poisoning", "Slowed",
## "Blessed". Used for STAT_MODIFIER, STAT_MULTIPLIER and DAMAGE_OVER_TIME, so
## a message can read "Cyrus inflicted Poisoning on Goblin 1" rather than
## describing the raw stat change. Leave empty to fall back to a generated
## description of what the effect actually does.
@export var display_name: String = ""

@export_group("Condition")
## Used when type is CONDITION. The condition to inflict - see
## ConditionDefinition, and res://conditions/ for the ones already written.
@export var condition: ConditionDefinition
## How many of the target's own turns the condition lasts when THIS skill is
## what inflicted it.
##
## 0 means "however long the condition itself says", which is what every skill
## did before this existed - so Blind is its own 3 turns unless a skill
## deliberately says otherwise. Set it when one skill should land a longer or
## shorter version of a condition another skill also inflicts, rather than
## writing a second near-identical ConditionDefinition just to hold one number.
@export_range(0, 20) var condition_duration: int = 0

@export_group("Damage / Heal / Damage over Time")
## What kind of damage this deals. Used by DAMAGE, DAMAGE_OVER_TIME and the
## collision damage a PUSH deals, and checked against the target's resistances
## (see CombatantDefinition). Ignored by HEAL.
@export var damage_type: Damage.Type = Damage.Type.PHYSICAL
## Used when type is DAMAGE, HEAL, or DAMAGE_OVER_TIME (as the per-tick
## amount). Actual amount is randomised between these each time it's rolled.
## Also used by PUSH: if the push gets stopped short by a wall or the map
## edge (not by bumping another combatant), it deals this much collision
## damage. Leave both at 0 for a push with no collision damage.
## How hard this particular effect hits, multiplied on top of the skill's own
## AbilityModifier. One skill often carries a direct hit and a lingering one -
## Poison Dart does - and they should not be forced to the same strength just
## because they came from the same skill.
##
## Used by DAMAGE_OVER_TIME, where a tick usually wants a fraction of a direct
## hit, since it lands once per turn for several turns. A direct hit has no use
## for it: a skill's own damage carries its strength on the skill itself.
@export_range(0.0, 5.0, 0.05, "or_greater") var damage_modifier: float = 1.0
## Only consulted when there is no skill behind the damage at all - a shove
## into a wall, something applied by hand. A skill's damage comes from its
## caster's stat and the modifiers above.
@export var min_amount: int = 0
@export var max_amount: int = 0

@export_group("Stat Modifier")
## Used when type is STAT_MODIFIER or STAT_MULTIPLIER. Which stat to change.
## "movement", "initiative" and "max_hp" are real stats on the combatant;
## "accuracy" isn't a stored stat but is added to every hit-chance roll the
## combatant makes. Any other name works too, but only actually does
## something once it's read somewhere via Combat.get_effective_stat().
@export var stat: String = "movement"
## Used when type is STAT_MODIFIER. Added to the stat each turn it's active.
## Negative = debuff, positive = buff.
@export var modifier_amount: int = -1
## Used when type is STAT_MULTIPLIER. The stat is multiplied by this each
## turn it's active - 2.0 doubles it, 0.5 halves it. Effective stat is
## (base + all additive modifiers) * (product of all multipliers).
@export var stat_multiplier: float = 2.0

@export_group("Duration")
## Used when type is STAT_MODIFIER, STAT_MULTIPLIER, or DAMAGE_OVER_TIME.
## How many of the affected combatant's own turns this lasts for.
@export var duration: int = 2

@export_group("Dispel")
## Used when type is DISPEL. Empty = matches any status effect regardless of
## stat. Otherwise only removes status effects on this exact stat (e.g.
## "movement" to cure a slow specifically). Use "dot" to target only
## damage-over-time effects.
@export var dispel_stat: String = ""
@export var dispel_scope: DispelScope = DispelScope.BOTH

@export_group("Push / Pull")
## Used when type is PUSH or PULL. How many tiles to try to move the target,
## straight along the line from the caster through them. Stops early if it
## hits the map edge, a blocking tile, another combatant, or - for PULL -
## the caster's own tile.
@export var knockback_distance: int = 1


## Which fields each effect type actually reads. Everything not listed for a
## type is hidden while that type is selected - see _validate_property.
const FIELDS_BY_TYPE := {
	EffectType.DAMAGE: ["damage_type", "min_amount", "max_amount"],
	EffectType.HEAL: ["min_amount", "max_amount"],
	EffectType.STAT_MODIFIER: ["display_name", "stat", "modifier_amount", "duration"],
	EffectType.DAMAGE_OVER_TIME: ["display_name", "damage_type", "damage_modifier", "min_amount", "max_amount", "duration"],
	EffectType.DISPEL: ["dispel_stat", "dispel_scope"],
	EffectType.PUSH: ["knockback_distance", "damage_type", "min_amount", "max_amount"],
	EffectType.PULL: ["knockback_distance"],
	EffectType.STAT_MULTIPLIER: ["display_name", "stat", "stat_multiplier", "duration"],
	EffectType.CONDITION: ["condition", "condition_duration"],
}


func _set_type(value: EffectType):
	type = value
	# The inspector caches the property list, so it has to be told the answer
	# to _validate_property just changed.
	notify_property_list_changed()


## Shows only the fields the selected effect type actually uses. Every type
## used to present all six groups - Condition, Damage, Stat Modifier,
## Duration, Dispel, Push/Pull - and the only way to know which of them mattered
## was to read each field's comment. Now picking the type answers that.
##
## Hidden is not cleared: the value stays stored and comes back if the type is
## switched back, so trying DAMAGE_OVER_TIME and changing your mind doesn't
## lose the numbers you typed.
func _validate_property(property: Dictionary) -> void:
	if not (property.usage & PROPERTY_USAGE_EDITOR):
		return
	if property.name == "type" or not FIELDS_BY_TYPE.has(type):
		return
	if property.name in FIELDS_BY_TYPE[type]:
		return
	if property.name in ["resource_local_to_scene", "resource_path", "resource_name", "script"]:
		return
	property.usage = PROPERTY_USAGE_STORAGE
