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
## before this ever matters).
@export_range(0, 100) var accuracy: int = 90
@export var icon: Texture2D
## If true, valid targets are the caster's own side (heals/buffs).
## If false (default), valid targets are the opposing side (attacks/debuffs).
@export var targets_ally: bool = false
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

@export_group("Area of Effect")
## 0 = single tile only (classic single-target). Any higher number gives this
## skill an area: for DIAMOND it's the radius around the clicked tile; for
## LINE and CONE it's how many tiles the shape reaches out from the caster.
@export var aoe_radius: int = 0
## Only used when aoe_shape is LINE. How many tiles wide the beam is,
## centred on the line (e.g. 3 = one tile either side of the centre).
@export var aoe_width: int = 1
@export var aoe_shape: AoEShape = AoEShape.DIAMOND

## Everything this skill does on a successful hit. Add as many as you like -
## e.g. one DAMAGE effect plus one STAT_MODIFIER effect for a slowing attack.
@export var effects: Array[EffectDefinition] = []
