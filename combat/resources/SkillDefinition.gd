extends Resource
class_name SkillDefinition

enum AoEShape {
	DIAMOND, ## Centred on the clicked tile - the shape you already know.
	LINE,    ## A straight beam from the caster, in the direction of the click.
	CONE     ## A widening wedge from the caster, in the direction of the click.
}

@export var name: String
## Freeform flavour/explanation text, shown under the name in the tooltip
## when hovering the skill's action button. Write and edit this yourself -
## nothing here is auto-generated.
@export_multiline var description: String = ""
@export var min_range: int
@export var max_range: int
## Chance to hit, as a percentage - the same no matter the distance, as long
## as the target is within range at all (being out of range is rejected
## before this ever matters). Ignored entirely when uses_stat_contest is on.
@export_range(0, 100) var accuracy: int = 90
@export var icon: Texture2D
## The level a combatant has to have reached before this appears in their
## skill panel at all. 1 means everybody has it from the start.
##
## Filtered out rather than shown greyed out: a level 1 character's panel is
## what they can do, not a preview of what they will be able to do later.
@export_range(1, 3) var required_level: int = 1
## If true, valid targets are the caster's own side (heals/buffs).
## If false (default), valid targets are the opposing side (attacks/debuffs).
@export var targets_ally: bool = false
## If true, this skill doesn't care whose side anyone is on: an area hits every
## living combatant inside it, friend and foe alike, and a single-target one can
## be aimed at either side. Use it for a shockwave that knocks back whoever it
## catches, or a blast you have to be careful where you put.
## targets_ally still decides how the aiming preview is coloured, and which side
## the AI considers the point of using it.
@export var affects_both_sides: bool = false
## If true, this skill needs a clear path from the caster: any tile that
## blocks the caster's own movement class (the same "Blocks" tile data
## movement already respects) blocks this skill too, and hides anything
## behind it. If false (default), the skill ignores blocking tiles entirely -
## useful for something that arcs over obstacles (a lobbed fireball) versus
## something that needs a clear shot (a straight arrow).
@export var respects_blocking: bool = false
## If true, anyone with this skill in their skill_list can use it as a
## reaction: if a valid target (per targets_ally) moves during their OWN
## turn and leaves this skill's range - whether they started inside and
## walked out, or walked in and back out again - the owner automatically
## uses it on them, once, resolved as a single-target hit against whoever
## triggered it regardless of the skill's normal area shape. Each combatant
## can use at most one reactive skill between their own turns; it resets
## when their own turn starts.
@export var is_reactive: bool = false
## If true, using this skill kills the caster outright once it resolves,
## regardless of whether it hit anyone else - for a kamikaze-style skill
## like a self-destruct. This is unconditional: it still happens even if
## the skill's own hit roll against others missed.
@export var kills_caster: bool = false
## Which of a combatant's two action slots this uses. Main and secondary are
## spent separately, so a turn can use one of each.
##
## This is the skill's default classification, used by everyone who has it. To
## let one particular combatant also use it in the other slot, list it in their
## CombatantDefinition.secondary_skills - Cyrus has Run there, so Run is a main
## skill for everyone and additionally a secondary one for him.
@export var is_secondary: bool = false
## Which animation the caster plays when using this. A combatant whose
## SpriteFrames has no animation by this name falls back to "skill", and one
## with no animations at all just resolves the skill instantly - so naming an
## animation here is never a requirement, only an option.
@export var animation: String = "skill"

## Everything this skill does on a successful hit. Add as many as you like -
## e.g. one DAMAGE effect plus one STAT_MODIFIER effect for a slowing attack.
##
## Each entry only shows the fields its own type actually uses, so pick the
## effect's type first and the rest of it follows.
@export var effects: Array[EffectDefinition] = []

@export_group("Damage")
## Whether this skill hits for damage by itself.
##
## On for an attack. Off for a heal, a buff, a shove, or a skill that only
## inflicts a condition - and off is not the same as harmless: a skill that
## deals no direct damage can still leave a poison burning, since a tick takes
## its strength from AbilityModifier below.
##
## Damage used to be an entry in Effects instead. It is here because everything
## that decides how hard a skill hits - the stat, the modifier, the contest -
## was already here, and the effect only carried the damage type.
@export var deals_damage: bool = true : set = _set_deals_damage
## How hard this skill hits for its stat. 1.0 is an ordinary attack, 0.5 a
## glancing one, 2.0 something that should hurt. Multiplied straight into the
## damage, so this is the dial to turn when a skill feels weak or oppressive.
##
## Damage-over-time ticks scale from this too, taking a fraction of it - see
## the effect's own DamageModifier.
@export_range(0.0, 5.0, 0.05, "or_greater") var ability_modifier: float = 1.0
## Which of the caster's attributes this scales from. The whole of a skill's
## damage comes from this one stat: BaseDamage = WeaponBase + 0.7 x Stat.
##
## Also the caster's side of a stat contest, whether or not the skill damages.
@export var scaling_stat: Stats.Type = Stats.Type.PHYSICAL
## What kind of damage this deals, weighed against the target's resistances.
@export var damage_type: Damage.Type = Damage.Type.PHYSICAL : set = _set_damage_type

@export_group("Hitting")
## Off: the skill rolls against accuracy, and a miss does nothing at all.
##
## On: no roll. The skill lands in full on anyone whose contest_stat is below
## the caster's scaling_stat, and merely grazes anyone whose is equal or
## higher - half damage, and none of the skill's other effects. So a Fireball
## scaling from Intellect and contesting Physical burns everyone frailer than
## the caster is clever, and only singes the rest.
@export var uses_stat_contest: bool = false : set = _set_uses_stat_contest
## The target's attribute weighed against the caster's scaling_stat.
@export var contest_stat: Stats.Type = Stats.Type.PHYSICAL

@export_group("Sound")
## Played when this skill goes off. Left empty for a skill that makes no noise,
## which is every skill until one is given a sound - nothing here needs audio
## to exist.
##
## It fires as the skill animation ENDS rather than when the skill is chosen,
## so the noise lands with the blow instead of underneath the wind-up. A
## combatant with no animation resolves instantly and the sound plays then.
@export var sound: AudioStream
## Per-skill trim, because raw samples arrive at wildly different levels and
## the alternative is re-exporting the audio to balance a fight.
@export_range(-40.0, 12.0, 0.5) var sound_volume_db: float = 0.0

@export_group("Cost")
## Which spell slot this costs, or 0 for a skill that costs nothing.
##
## A skill can always be paid for with a higher slot than it asks for - a level
## 1 spell can burn a level 2 or 3 - but never a lower one. Combat spends the
## cheapest slot that will do, so a level 3 is never wasted on a level 1 spell
## while a level 1 is still going spare.
##
## Anything with a cost lives on its own Spells panel rather than in the main
## list, but still spends the same action: the main one, or the secondary one
## if is_secondary is also set. Casting a spell and swinging a sword in the
## same turn is one action either way, so only one of them happens.
@export_range(0, 3) var spell_slot_level: int = 0

@export_group("Area of Effect")
## 0 = single tile only (classic single-target). Any higher number gives this
## skill an area: for DIAMOND it's the radius around the clicked tile; for
## LINE and CONE it's how many tiles the shape reaches out from the caster.
@export var aoe_radius: int = 0 : set = _set_aoe_radius
@export var aoe_shape: AoEShape = AoEShape.DIAMOND : set = _set_aoe_shape
## Only used when aoe_shape is LINE. How many tiles wide the beam is,
## centred on the line (e.g. 3 = one tile either side of the centre).
@export var aoe_width: int = 1


func _set_aoe_radius(value: int):
	aoe_radius = value
	notify_property_list_changed()


func _set_aoe_shape(value: AoEShape):
	aoe_shape = value
	notify_property_list_changed()


func _set_uses_stat_contest(value: bool):
	uses_stat_contest = value
	notify_property_list_changed()


## Hides the fields that don't apply yet, so a single-target skill isn't asking
## you about beam widths and a skill that contests a stat isn't also offering
## an accuracy it will never roll. Nothing is lost by being hidden - the value
## is still stored, and reappears if the skill is set back the other way.
func _validate_property(property: Dictionary) -> void:
	var shown := true
	match property.name:
		"aoe_shape":
			# Meaningless until the skill covers more than one tile.
			shown = aoe_radius > 0
		"aoe_width":
			shown = aoe_radius > 0 and aoe_shape == AoEShape.LINE
		"accuracy":
			shown = not uses_stat_contest
		"contest_stat":
			shown = uses_stat_contest
		"damage_type":
			# Nothing to resist when the skill does no damage of its own. The stat
			# and the modifier stay: a contest reads one, a poison tick the other.
			shown = deals_damage
	if not shown:
		property.usage = PROPERTY_USAGE_STORAGE


func _set_deals_damage(value: bool):
	deals_damage = value
	notify_property_list_changed()


func _set_damage_type(value: Damage.Type):
	damage_type = value
	if _own_damage != null:
		_own_damage.damage_type = value


## The skill's own damage, expressed as the kind of effect the rest of combat
## already knows how to apply, describe, colour and estimate.
##
## Damage used to be one more entry in `effects`, which meant every attack
## carried an effect whose only real content was the damage type - the strength
## and the stat were already on the skill. Two places to look, one of which was
## mostly empty, and a per-effect modifier that quietly did nothing for a direct
## hit. Now the skill says it, and this turns it back into an effect so nothing
## downstream needs a special case for it.
##
## Kept and updated rather than rebuilt each time: it is asked for on every hit,
## and on every tooltip.
var _own_damage: EffectDefinition = null

func damage_effect() -> EffectDefinition:
	if _own_damage == null:
		_own_damage = EffectDefinition.new()
		_own_damage.type = EffectDefinition.EffectType.DAMAGE
		_own_damage.damage_type = damage_type
	return _own_damage


## Everything this skill does to what it lands on: its own damage first, then
## whatever else it carries. This is what combat resolves and what the tooltip
## lists - `effects` alone is only the extras.
func all_effects() -> Array[EffectDefinition]:
	if not deals_damage:
		return effects
	var everything: Array[EffectDefinition] = [damage_effect()]
	everything.append_array(effects)
	return everything
