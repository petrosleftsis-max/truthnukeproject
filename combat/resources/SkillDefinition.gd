@icon("res://art/editor_icons/skill.svg")
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
## A melee move - struck with the body, or what it holds - rather than a ranged
## one, sent across the room. Not the same as its range: a lance, a chain or a
## lunge is melee and still reaches past the tile beside you. For whatever
## favours or hinders melee to ask (Combat.is_melee). So far: a rider's melee
## blows do not shove or drag what they are riding.
@export var melee: bool = false
## Chance to hit, as a percentage - the same no matter the distance, as long
## as the target is within range at all (being out of range is rejected
## before this ever matters). Ignored entirely when uses_stat_contest is on.
@export_range(0, 100) var accuracy: int = 100
@export var icon: Texture2D
## The level a combatant has to have reached before this appears in their
## skill panel at all. 1 means everybody has it from the start.
##
## Filtered out rather than shown greyed out: a level 1 character's panel is
## what they can do, not a preview of what they will be able to do later.
@export_range(1, 64) var required_level: int = 1
## How it grows stronger with its user's level (SkillRank), lowest level first:
## from each one's level, its figures stand in for these. Read through
## Combat.rank_of - never this skill's own figures straight - wherever the user
## is known.
@export var ranks: Array[SkillRank] = []
## If true, valid targets are the caster's own side (heals/buffs).
## If false (default), valid targets are the opposing side (attacks/debuffs).
@export var targets_ally: bool = false
## Aimed at one of the caster's side who has fallen, where they lie - and only
## at somebody fallen: Resuscitate. With this on, nobody standing can be aimed
## at, and the skill's effects land on the fallen (see EffectType.REVIVE).
@export var targets_fallen: bool = false
## Aimed twice: first at anybody of the caster's own side, wherever they are -
## in reach or not, on the map or by their face - and then at any tile in reach,
## where what it makes of them is put down. For an illusion (EffectType
## SUMMON_DECOY - Alithia's Mirror Image): an image of whoever was chosen, set
## down where she likes. Off, an image goes on a tile beside them.
@export var placed_in_reach: bool = false
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
## What sets it off, when Is Reactive is on - any of these, ticked (Combat
## "Reactions"). Who it lands on: a skill aimed at allies lands on whoever it
## is protecting (themselves when it is them under attack, the ally who set it
## off or is under attack); anything else lands on the enemy who set it off.
##   Leaves Reach - somebody walks out of its range (what every reaction did,
##     and so the default).
##   Enters Reach - somebody walks into its range: an ally coming close, say.
##   Targeted - an enemy's skill is about to land on them: before it does.
##   Struck - an enemy's skill has just hit them: after it does.
##   Ally Attacked - an enemy's skill is about to land on one of theirs.
##   Casts - somebody they can see casts through a gate: before it lands.
##   Declares - somebody calls a declared move.
##   Foreseen Blow - the move Intuition read comes, as foreseen: before it lands.
## Who the "somebody" may be is Set Off By.
@export_flags("Leaves Reach", "Enters Reach", "Targeted", "Struck", "Ally Attacked", "Casts",
	"Declares", "Foreseen Blow") var reacts_when: int = 1
## Who sets it off, for the triggers somebody of either side can (Leaves and
## Enters Reach, Casts, Declares, and Ready's area): an enemy, an ally, or
## either. The rest are an enemy's doing whatever this says. A skill aimed at
## allies set off by an ally lands on them - a ward as they come close; a skill
## that hurts never lands on an ally, whoever set it off.
@export_enum("Enemies", "Allies", "Either") var set_off_by: int = 0
## Whether it can ONLY go off as a reaction, when Is Reactive is on: it is not
## there to be picked on its user's own turn (Combat.refusal_for), nor readied,
## and the AI never plans it - InstaHack, which only answers a spell being cast.
@export var reaction_only: bool = false

## Set Off By's choices.
enum SetOffBy { ENEMIES, ALLIES, EITHER }

## The bits of reacts_when, and Ready's own (Combat "Ready"): somebody stepping
## into a marked area.
enum Trigger {
	LEAVES_REACH = 1,
	ENTERS_REACH = 2,
	TARGETED = 4,
	STRUCK = 8,
	ALLY_ATTACKED = 16,
	CASTS = 32,
	DECLARES = 64,
	FORESEEN_BLOW = 128,
	ENTERS_AREA = 256,
}

## The triggers somebody of either side can set off (set_off_by); the rest are
## always an enemy's doing.
const EITHER_SIDE := [Trigger.LEAVES_REACH, Trigger.ENTERS_REACH, Trigger.CASTS, Trigger.DECLARES, Trigger.ENTERS_AREA]

## What each trigger is called, for the HUD and the log - "%s" is who sets it
## off (WHO_NAMES), where that can be either side.
const TRIGGER_NAMES := {
	Trigger.LEAVES_REACH: "%s leaves its reach",
	Trigger.ENTERS_REACH: "%s steps into its reach",
	Trigger.TARGETED: "an enemy is about to hit them",
	Trigger.STRUCK: "an enemy hits them",
	Trigger.ALLY_ATTACKED: "an enemy is about to hit an ally",
	Trigger.CASTS: "%s casts a spell",
	Trigger.DECLARES: "%s calls a declared move",
	Trigger.FORESEEN_BLOW: "the blow Intuition foresaw comes",
	Trigger.ENTERS_AREA: "%s steps into the marked area",
}
const WHO_NAMES := ["an enemy", "an ally", "anybody"]


## What `trigger` is called, set off by `by` (SetOffBy).
static func trigger_name(trigger: int, by: int = SetOffBy.ENEMIES) -> String:
	var said: String = TRIGGER_NAMES.get(trigger, "")
	return said % WHO_NAMES[clampi(by, 0, WHO_NAMES.size() - 1)] if said.contains("%s") else said


## Whether somebody on `source_side` can set off `trigger` for somebody on
## `reactor_side` who reacts to it as `by` (SetOffBy) says.
static func sets_off(trigger: int, by: int, reactor_side: int, source_side: int) -> bool:
	var ally := reactor_side == source_side
	if not trigger in EITHER_SIDE:
		return not ally
	match by:
		SetOffBy.ALLIES:
			return ally
		SetOffBy.EITHER:
			return true
	return not ally


## Whether Hack can unpick this while it is being wound up: Hackable ticked, or
## a Hack of its own.
func can_be_hacked() -> bool:
	return hackable or hack != null


## Whether this reacts to `trigger` (Trigger), as a reactive skill.
func reacts_to(trigger: int) -> bool:
	return is_reactive and (reacts_when & trigger) != 0


## "an enemy leaves its reach, or an enemy is about to hit them" - what sets it
## off, as words.
func describe_triggers() -> String:
	var said := []
	for trigger in TRIGGER_NAMES:
		if reacts_to(trigger):
			said.append(trigger_name(trigger, set_off_by))
	return ", or ".join(said)
## If true, using this skill kills the caster outright once it resolves,
## regardless of whether it hit anyone else - for a kamikaze-style skill
## like a self-destruct. This is unconditional: it still happens even if
## the skill's own hit roll against others missed.
@export var kills_caster: bool = false

## Whether using this makes the user impossible to react to for the rest of
## their turn: they can walk out of a reactive skill's reach and nobody gets
## the free swing. Movement itself is unchanged - what changes is that leaving
## somebody's threatened space stops being an opening.
@export var suppresses_reactions: bool = false

## Whether the Mimic can copy this when a player uses it. Off for what copying
## would make no sense of - getting about, and taking somebody's measure - and
## the Mimic copies the last thing it can copy instead. See Combat.ai_copycat.
@export var can_be_copied: bool = true

@export_group("Teleport")
## Who this puts somewhere else, and whether it does at all.
##
## CASTER moves the user to the tile they aimed at, before anything resolves -
## so an area skill bursts from where they land rather than where they left.
## TARGET moves whoever is aimed at to a second tile, picked afterwards.
enum TeleportWho { NOBODY, CASTER, TARGET }
@export var teleports: TeleportWho = TeleportWho.NOBODY
## A CASTER teleport that has to end in cover (Combat.in_cover) - Cyrus's Cover
## Leap.
@export var lands_in_cover: bool = false
## A TARGET teleport that is a throw (Hurl): the landing tile may have somebody
## on it - both are hurt by the skill's damage, and the thrown one lands beside
## it. Immune to being thrown (Immunity) is never picked up.
@export var throws: bool = false
## A throw's reach: how far from its user the thrown one can be sent - one tile
## further for every THROW_RANGE_PER_PHYSICAL of the thrower's Physical (Combat).
## Min Range and Max Range are how far away they can be grabbed.
@export_range(0, 20, 1) var throw_range: int = 0
## How many sizes bigger than its user the one it moves may be: 1 is up to one
## size bigger (Enfina lifting somebody Large). -1 for any size.
@export_range(-1, 6, 1) var lifts_sizes_above: int = -1
## How big the one it is used on has to be, at least (Sizes.Size): Climb is for
## the Monstrous and up. -1 for any size.
@export_range(-1, 6, 1) var needs_size_at_least: int = -1
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
## A load of ammunition: a shot that a Combined Load (combines_ammo) can fire
## together with another - Burning Shot, Poison Dart.
@export var is_ammo: bool = false
## Picking this asks which two of the caster's ammunition to fire at once, and
## aims the two as one shot (combined) - the Gunner's Combined Load. Used
## without picking, it is the shot it is written as.
@export var combines_ammo: bool = false
## Declared: using it only announces it - free, the turn goes on - and marks
## where it will land on the board for everybody to see. It lands at the start
## of its user's next turn, at the same place, and spends that turn's action
## (Combat.declare). Lost if they lose that turn - stunned, confused, fallen.
@export var declared: bool = false
## Works on somebody only if the party has something on them - their faction
## known, one of their kind questioned, a clue that bears on them
## (Combat.has_leverage). Intimidate, Persuade and Deceive.
@export var needs_leverage: bool = false
## Works only on somebody its user has read (Intuition, EffectType.READ_INTENT)
## and whose foreseen turn has not come yet. Accusation, Recant.
@export var needs_read: bool = false
## How many times it can be used before a short rest brings it back; 0 for as
## often as you like. In a dungeon what is spent stays spent from fight to
## fight until a short or long rest (Campaign.short_rest); every fight
## elsewhere starts with all of them, as with gates. Recant, Grand Design,
## Minefield, Catalyst, Stunning Blow - per fight until the designer's change
## of 2026-10-24 (APPROVED_TRIAL).
@export_range(0, 9) var uses_per_short_rest: int = 0
## Levels at which its user has one more use a short rest: Stunning Blow's
## [54, 64], over its one, is two at 54 and three at 64.
@export var more_uses_at: Array[int] = []
## A spell its caster casts through whichever gate they choose, its own or
## deeper - asked as it is cast - and what it does reaches as deep as that
## gate. Dispel Magic.
@export var chooses_gate: bool = false
## A quick time event (QuickTimeDefinition) that pops up as it is used. For the
## Attacker, when the party uses it: done in time, it lands Quick Time Bonus
## harder. For the Defender, when it is used on the party: done in time, it
## lands Quick Time Bonus softer on them.
@export var quick_time: QuickTimeDefinition
@export_enum("Attacker", "Defender") var quick_time_for: int = 0
@export_range(0.0, 1.0, 0.05) var quick_time_bonus: float = 0.5
## On a declared skill: whether Prometheus's Hack can unpick it while it is being
## wound up. Off, Hack is refused on it (Combat.refusal_for) - unless it has a
## Hack of its own below, which makes it hackable too.
@export var hackable: bool = false
## A hack (HackDefinition). On a declared skill, what unpicking it takes while
## it is being wound up - Prometheus's Hack; left empty on one that is Hackable,
## Hack's own is played. On a skill with a Hack effect, the one it uses on
## anything Hackable without a hack of its own.
@export var hack: HackDefinition

## Everything this skill does on a successful hit. Add as many as you like -
## e.g. one DAMAGE effect plus one STAT_MODIFIER effect for a slowing attack.
##
## Each entry only shows the fields its own type actually uses, so pick the
## effect's type first and the rest of it follows.
@export var effects: Array[EffectDefinition] = []

@export_group("Power")
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
## How strong this skill is, whatever it does. 1.0 is an ordinary attack, 0.5 a
## glancing one, 2.0 something that should hurt. This is the dial to turn when
## a skill feels weak or oppressive.
##
## What the skill is worth on impact: a hit or a heal works out to
## (WeaponBase + 0.7 x ScalingStat) x this, so a healer's mending grows with her
## Mindfulness exactly as an attacker's damage grows with his Physical.
##
## Not what anything it leaves behind is worth. A condition ticks for the same
## base times its own dial and never this one, so the blow and the burn can be
## tuned without either dragging the other - see EffectDefinition's
## ConditionDotModifier. A heal may also carry its own; see HealModifier.
##
## What the skill actually does is decided by DealsDamage and by the effects it
## carries, not here.
@export_range(0.0, 5.0, 0.05, "or_greater") var ability_modifier: float = 1.0
## Which of the caster's attributes this scales from. The whole of a skill's
## strength comes from this one stat: Base = WeaponBase + 0.7 x Stat.
##
## Also the caster's side of a stat contest, whether or not the skill damages.
##
## Not for a spell (anything cast through a gate): that is worked out from its
## caster's own spellcasting stat (CombatantDefinition.spellcasting_stat),
## whichever spell it is, and this is hidden for one.
@export var scaling_stat: Stats.Type = Stats.Type.PHYSICAL
## What kind of damage this deals, weighed against the target's resistances.
@export var damage_type: Damage.Type = Damage.Type.PHYSICAL : set = _set_damage_type
## How much of the target's Defense its hits go straight through, in percent:
## 0 meets all of it, 100 none. Worth more the tougher the target - Defense
## does least to a lightly armoured one to begin with. Its hits only; anything
## it leaves burning meets their Defense whole.
@export_range(0, 100, 1, "suffix:%") var ignores_defense: int = 0

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
## Which gate this spell is cast through, or None for a skill that costs
## nothing.
##
## A spell can always be paid for with a higher gate than it asks for - one cast
## through the Gates of World can burn Hermes or Pandora - but never a lower
## one. Combat spends the cheapest gate that will do, so Pandora is never
## wasted on a World spell while a World casting is still going spare.
##
## Anything with a cost lives on its own Spells panel rather than in the main
## list, but still spends the same action: the main one, or the secondary one
## if is_secondary is also set. Casting a spell and swinging a sword in the
## same turn is one action either way, so only one of them happens.
@export_enum("None", "Gates of World", "Gates of Hermes", "Gates of Pandora", "Gates of Charon", "Gates of Tartarus", "Gates of Nemesis", "Gates of Sophia", "Gates of Ogdoad", "Gates of Gnosis", "Gates of Yaldabaoth")
var spell_slot_level: int = 0 : set = _set_spell_slot_level
## The gate this spell is cast through outside a fight - on a stealth map - or
## None for one that can only be cast in a fight. Its castings are its own, so
## sneaking about never costs the next fight anything; in a fight the spell is
## still paid through the gate above. Pick one as strong as that gate
## (Stats.OUTSIDE_GATES says which each one matches).
@export_enum("None", "Gates of Iris") var outside_gate: int = 0
## Outside a fight, how long what it does lasts, in seconds - Invisibility's
## time unseen. It ends sooner if anybody does something to a guard.
@export_range(0, 3600, 1, "suffix:s") var outside_seconds: int = 0

@export_group("Tether")
## Held on a tether to its caster (Combat "Tethers"). Cast, it gives them a
## tether bar under their health, Tether Strength big, which frays - Tether Per
## Turn at the start of each of their turns, and Tether Per Damage for every
## hundredth of their health they lose - and when it snaps, everything it did
## ends: what it put on anybody comes off, and what it summoned goes. One at a
## time: tethering another such spell lets go of the first.
@export var tethered: bool = false
## How strong the tether is: the bar's size.
@export_range(1, 1000, 1) var tether_strength: int = 100
## Worn off at the start of each of the caster's turns: Tether Strength / Tether
## Per Turn of their turns is how long it lasts if nothing hits them. 0: only
## damage snaps it.
@export_range(0, 1000, 1) var tether_per_turn: int = 25
## Worn off for every hundredth of their health they lose: 1 is a quarter of the
## bar for a blow that takes a quarter of their health.
@export_range(0.0, 10.0, 0.05) var tether_per_damage: float = 1.0

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
		"scaling_stat":
			# A spell is its caster's spellcasting stat's, whichever spell it is.
			shown = spell_slot_level == 0
	if not shown:
		property.usage = PROPERTY_USAGE_STORAGE


func _set_spell_slot_level(value: int):
	spell_slot_level = value
	notify_property_list_changed()


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


## Two loads fired as one shot (combines_ammo): `first`'s hit, with everything
## `second` does besides hitting added to it - its condition, its shove - and
## the reach both of them have. Made once a pair and kept in SkillDatabase under
## "combined:first+second", so aiming, the prompt and the log all treat it as
## the one skill it is. "" if either is not ammunition.
static func combined(first: String, second: String) -> String:
	var key := "combined:%s+%s" % [first, second]
	var skills: Dictionary = SkillDatabase.skills
	if skills.has(key):
		return key
	var a: SkillDefinition = skills.get(first)
	var b: SkillDefinition = skills.get(second)
	if a == null or b == null or first == second or not a.is_ammo or not b.is_ammo:
		return ""
	var both: SkillDefinition = a.duplicate()
	both.set_meta("key", key)
	both.name = "%s + %s" % [a.name, b.name]
	both.description = "%s and %s in one shot: %s's hit, and what %s does with it." % [a.name, b.name, a.name, b.name]
	both.min_range = maxi(a.min_range, b.min_range)
	both.max_range = mini(a.max_range, b.max_range)
	both.required_level = maxi(a.required_level, b.required_level)
	both.spell_slot_level = maxi(a.spell_slot_level, b.spell_slot_level)
	both.respects_blocking = a.respects_blocking or b.respects_blocking
	both.is_ammo = false
	both.combines_ammo = false
	both.can_be_copied = false
	var effects_of_both: Array[EffectDefinition] = a.effects.duplicate()
	effects_of_both.append_array(b.effects)
	both.effects = effects_of_both
	skills[key] = both
	return key
