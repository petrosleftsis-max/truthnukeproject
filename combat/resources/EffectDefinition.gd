@icon("res://art/editor_icons/effect.svg")
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
	CONDITION,         ## Inflicts a named ConditionDefinition - Poisoned, Stunned, Burned and so on.
	REVEAL,            ## Lays the target open to inspection - what Study does.
	MOVEMENT_CLASS,    ## Changes how the target gets about - on foot, flying, mounted - for a duration.
	HIDE,              ## Takes the target out of sight, until somebody sees them again.
	RESISTANCE,        ## Raises or lowers how much of one damage type gets through, for a duration.
	UPGRADE_ELEMENT,   ## The target's next damaging skill is cast with the upgraded form of its element.
	REVIVE,            ## Brings back an ally who has fallen - and they come back weaker, until a long rest.
	STEAL,             ## Takes what the target has to hand in this fight and gives it to the thief.
	SUMMON_DECOY,      ## An image of the ally it lands on, beside them: no turns, gone at the first touch.
	INTERACT,          ## Uses the thing on the battlefield it lands on (BattleObjectDefinition) - rings the bell.
	HACK,              ## Hacks apart the declared skill the one it lands on is winding up - Prometheus's Hack.
	READ_INTENT,       ## Reads what the one it lands on means to do next turn, and holds them to it - Alithia's Intuition.
	SHAKE,             ## Shakes their nerve by Min Amount to Max Amount, toward breaking (fleeing or surrendering).
	CLIMB,             ## Climbs onto the one it lands on, to fight from on top of them - Enfina's Climb.
	BRIBE,             ## Pays the one it lands on their price (CombatantDefinition.bribe_price) to leave the fight.
	BREAK_FREE,        ## Tries to break the grip of the one it lands on, who is holding the user (Grappled) - Break Free.
	INVISIBLE,         ## Out of sight even in plain view, until they do something to an enemy - Invisibility.
	CANCEL_CASTING,    ## Cancels the spell the one it lands on is casting, as they cast it - Prometheus's InstaHack.
	SWALLOW,           ## Swallows whole the one it lands on, if the user has hold of them - the glutton's Devour.
	GROW,              ## Makes the one it lands on a size bigger, for a duration - Growth.
	SUMMON,            ## Calls Summons into the fight on the tile aimed at, to fight for its user (Combat "Summons").
	COMMAND,           ## Gives a summon of the user's its moment: its move and its action, now (Combat "Summons").
	LOOT,              ## Takes everything a fallen enemy carried and wore (Combat "Loot").
	DRAW,              ## Takes something from its user's pouch and puts it on their baldric, ready to use (Combat "Drawing").
	TRAP,              ## Sets a hidden trap on the tile aimed at - Snare, Tripwire, Minefield (Combat "Traps").
	CATALYST,          ## Every lingering condition of its user's on every enemy goes off at once, then starts again (Combat "Catalyst").
	ZONE,              ## Leaves a lasting zone on the ground the skill covers: whoever stands in it has Zone Condition (Combat "Zones").
	DISPEL_MAGIC,      ## Ends what spells cast through gates no deeper than its own did to the one it lands on - or a zone, aimed at its ground (Combat "Dispelling").
	FAMILIAR,          ## Outside a fight only: calls a familiar in the map's animal form, to be steered and seen through - Alithia's Find Familiar (StealthWatch "Familiar").
	UNVEIL,            ## The invisible and the hidden it lands on are seen again - Unveil, Votive Flame.
	MOVE_ZONE,         ## Moves the zone its user laid that can be moved, up to its reach from where that is - the Storm Cloud (Combat "Zones").
	MOVE_IMAGE,        ## Moves the double its user made (Effect's Image Moves), up to its reach from where that is - Move Double.
	DISGUISE,          ## Its user slips into a disguise they carry that fits those they fight, while hidden - Put On Disguise (Combat "Disguises").
}

enum DispelScope {
	BOTH,
	BUFFS_ONLY,   ## Only removes effects with a positive amount. Never touches DoTs.
	DEBUFFS_ONLY  ## Removes effects with a negative amount, and all damage-over-time effects.
}

@export var type: EffectType = EffectType.DAMAGE : set = _set_type
## Who it is for, on something that catches both sides (Calm). Stored by number.
@export_enum("Whoever It Catches", "Its Own Side", "The Other Side") var lands_on: int = 0
## Lands on whoever used the skill rather than on what it was aimed at.
##
## So one skill can hurt an enemy and do something to its own caster - a swing
## that cuts and steadies the arm that swung it. Without this, a skill aimed at
## an enemy could only ever do things to that enemy, and a buff for the caster
## needed a second skill and a second action to go with it.
##
## Applied once however many it hit, not once per victim, and only when the
## skill actually lands.
@export var applies_to_caster: bool = false
## What this condition is called in the combat log - "Poisoning", "Slowed",
## "Blessed". Used for STAT_MODIFIER, STAT_MULTIPLIER and DAMAGE_OVER_TIME, so
## a message can read "Cyrus inflicted Poisoning on Ranger" rather than
## describing the raw stat change. Leave empty to fall back to a generated
## description of what the effect actually does.
@export var display_name: String = ""

@export_group("Movement class")
## Used when type is MOVEMENT_CLASS. What the target moves as while this lasts,
## on top of whatever it was born as - and back to that when the duration runs
## out.
##
## The three are not decoration: each has its own set of tiles it can cross and
## its own terrain costs (see CController.is_tile_blocking and
## get_tile_cost_for_class). Flying is the generous one - it ignores rough
## ground, crosses what stops a walker, and passes over other combatants.
## Ground is the default deliberately. Godot leaves a property out of a saved
## resource when it equals its default, so a default of Flying meant Hover
## saved with no movement class written in it at all and flew only because the
## default happened to say so. Ground is the ordinary case, the same as
## CombatantDefinition.class_m, so anything that lifts somebody has to say it.
@export_enum("Ground", "Flying", "Mounted") var movement_class: int = 0

@export_group("Condition")
## Used when type is CONDITION. The condition to inflict - see
## ConditionDefinition, and res://data/conditions/ for the ones already written.
@export var condition: ConditionDefinition
## How many of the target's own turns the condition lasts when THIS skill is
## what inflicted it, counted as every duration is - which end of a turn it goes
## at is the condition's own Wears Off At Start (see Combat.turns_stored).
##
## 0 means "however long the condition itself says", which is what every skill
## did before this existed - so Blind is its own 3 turns unless a skill
## deliberately says otherwise. Set it when one skill should land a longer or
## shorter version of a condition another skill also inflicts, rather than
## writing a second near-identical ConditionDefinition just to hold one number.
@export_range(0, 20) var condition_duration: int = 0
## On a Tethered skill: no count of turns - it stays on them for as long as the tether
## holds, however long that turns out to be (Combat "Tethers"). The tether's size is
## how long it lasts.
@export var held_by_tether: bool = false
## It comes off them the moment they are hurt, this once, whatever the condition does
## otherwise. Mesmerise's stun.
@export var comes_off_when_hurt: bool = false
## At the start of each of their turns, before anything else, they go as far from
## whoever put it on them as they can, and then carry on with the turn (Terror).
@export var flees_from_caster: bool = false
## As their next turn starts they walk towards where this was aimed, as far as they can, and then
## carry on with their turn. Phantom Noise.
@export var drawn_to_aim: bool = false
## How hard the condition burns when THIS skill is what inflicted it, in place
## of the condition's own dot_modifier.
##
## 0 means "however hard the condition itself says", the same way
## condition_duration works just above. Set it when two skills should inflict
## the same named condition at different strengths - a Burn from a searing bolt
## and a Burn caught walking through a fire are one condition with one glossary
## entry, and need not hurt the same.
##
## The whole of what a tick is worth, against the caster's stat: the skill's own
## ability_modifier sizes the blow and stays out of this, so turning one down
## leaves the other where it was.
##
## Only a skill's version scales. An item's condition rolls the flat dot_min to
## dot_max range written on the condition whoever throws it, so this does
## nothing on a consumable.
@export_range(0.0, 5.0, 0.05, "or_greater") var condition_dot_modifier: float = 0.0

@export_group("Damage / Heal / Damage over Time")
## What kind of damage this deals. Used by DAMAGE, DAMAGE_OVER_TIME and the
## collision damage a PUSH deals, and checked against the target's resistances
## (see CombatantDefinition). Ignored by HEAL.
@export var damage_type: Damage.Type = Damage.Type.PHYSICAL
## The flat fallback, used only when there is no skill behind the effect - a
## shove into a wall, something applied by hand. A skill's damage and healing
## both come from its caster's stat and its own AbilityModifier instead.
## Randomised between these each time it is rolled.
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
@export_range(0.0, 5.0, 0.05, "or_greater") var damage_modifier: float = 1.0 : set = _set_damage_modifier
## How much this heal mends, in place of the skill's own AbilityModifier.
##
## 0 means "whatever the skill is worth", the same way condition_dot_modifier
## works. Set it when one skill both hurts and mends and the two should not be
## the same size - Light Swing cuts at full strength and gives a third of it
## back, which with one dial for the lot was impossible to say.
@export_range(0.0, 5.0, 0.05, "or_greater") var heal_modifier: float = 0.0
## Used by HEAL: mends this share of the target's health on top - 0.5 is half
## of it back, 1.0 all of it (Restoration, Grace).
@export_range(0.0, 1.0, 0.05) var heal_share_of_health: float = 0.0
## Used by HEAL: mends only its share of health, nothing from the healer's
## power - Light Swing, a share of Enfina's own health (ranked by SkillRank).
@export var heals_share_only: bool = false
## Used by HEAL with a share: twice the share when the skill strikes somebody at
## half their health or less - once for each of them in a fight (Light Swing's
## finishing mend, Combat._wounded_bonus).
@export var share_doubled_on_wounded: bool = false
## Used by HEAL, the flat rule (APPROVED_TRIAL, 2026-10-24): Heal Flat + Heal Per
## Stat x the healer's healing stat + Heal Per Weapon x their weapon base, in
## place of power x the dial. Any of the three set switches it on for a skill;
## an item (a Gate Nade copying the spell) keeps its own flat item power. The
## healing stat is the one the skill scales with for them (Combat.scaling_stat_of
## - Mindfulness for Alithia and the enemy healers, Self for the Mimic).
## Heal 12 / 0.25 / 0.3; Light Heal and Communion 8 / 0.15 / 0.2; Restoration
## 0 / 0.25 / 0 with half the target's health on top.
@export_range(0.0, 100.0, 0.5, "or_greater") var heal_flat: float = 0.0
@export_range(0.0, 2.0, 0.05, "or_greater") var heal_per_stat: float = 0.0
@export_range(0.0, 2.0, 0.05, "or_greater") var heal_per_weapon: float = 0.0
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
## How many of the affected combatant's own turns this lasts for: 2 is two of
## their turns. Landing on whoever is acting, they have the rest of this turn as
## well - Run at 1, going at the end: this turn and the next. Wears Off At Start
## below picks whether it goes as the turn after the last starts, or as the
## last ends (see Combat.turns_stored).
@export var duration: int = 2
## Off: holds through the last of its turns and wears off as that turn ends, so
## it is still on while its bearer acts - Run, a Blind, anything that should
## never look as if it holds when it is about to go.
## On: wears off as that turn starts, the moment before its bearer could use it
## - Guard, which is for the enemies' turns in between and has nothing to do on
## its bearer's own. The danger view knows these go before the enemy acts.
@export var wears_off_at_start: bool = false

@export_group("Dispel")
## Used when type is DISPEL. Empty = matches any status effect regardless of
## stat. Otherwise only removes status effects on this exact stat (e.g.
## "movement" to cure a slow specifically). Use "dot" to target only
## damage-over-time effects.
## Conditions that come off whoever it lands on, as it lands (Calm).
@export var lifts: Array[ConditionDefinition] = []
@export var dispel_stat: String = ""
@export var dispel_scope: DispelScope = DispelScope.BOTH

## How many to take off, newest first. Zero means all of them, which is what
## a cleanse does. One is a remedy rather than a cure: it lifts whatever went
## wrong most recently and leaves the rest.
@export_range(0, 10, 1, "or_greater") var dispel_count: int = 0

@export_group("Push / Pull")
## Used when type is PUSH or PULL. How many tiles to try to move the target,
## straight along the line from the caster through them. Stops early if it
## hits the map edge, a blocking tile, another combatant, or - for PULL -
## the caster's own tile.
@export var knockback_distance: int = 1

@export_group("Revive")
## Used when type is REVIVE: how much of their full health somebody brought
## back stands up with - 0.5 is half.
@export_range(0.0, 1.0, 0.05) var revive_health: float = 0.0
## Used when type is REVIVE: how much less of everything they are made of -
## their attributes, their health, their weapon, how quick they are - they are
## left with until a long rest (Campaign.long_rest): 0.1 takes a tenth off.
## Everything but how far they can walk. It compounds, a second time taking a
## tenth off what the first left, and it goes with them out of the fight (see
## Combat.weaken).
@export_range(0.0, 1.0, 0.01) var revive_weakening: float = 0.0

@export_group("Steal")
## Used when type is STEAL: how many of the target's items it takes, from the
## front of what they have to hand. Zero means all of them - everything they
## brought to the fight. What the thief has no room for stays where it was.
@export_range(0, 4, 1, "or_greater") var steal_count: int = 0

@export_group("Summon")
## Used when type is SUMMON: who it calls, by key (a file in data/enemies or
## data/characters), at its user's level. It fights for its user - on their
## turn, not one of its own (Combat "Summons").
@export var summons: String = ""
## It is as strong as whoever called it: their five attributes rather than its
## own. For something made of its caster's mind - Prometheus's Illusory Dragon.
@export var with_summoners_attributes: bool = false
## How many it calls up, each on the nearest free tile to where it was aimed. Phantom Company.
@export_range(1, 12) var summon_count: int = 1
## Called up as a wall: this many tiles to each side of where it was aimed, across the line from
## the caster. A tile with no room is left out. Phantom Wall.
@export_range(0, 10) var summon_across: int = 0
## What it calls up are images, not creatures: one hit shatters each, nothing to command and no turns,
## and the other side takes them for the real thing (Combat "Images"). Phantom Company.
@export var summon_as_images: bool = false
## Everybody of the other side within sight of it is this much shaken as they arrive (Combat "Nerve").
@export_range(0, 100) var summon_shakes: int = 0
## Used when type is SUMMON_DECOY: the one who made it can send it about with a secondary action
## (Move Double), and it stays until it is hit or dispelled. Mislead.
@export var image_moves: bool = false
## Used when type is INVISIBLE: anything at all they do gives them away, not only what they do to
## the other side (a step does not). Seeming.
@export var unnoticed_until_acting: bool = false

@export_group("Trap")
## Used when type is TRAP. What whoever of the other side steps onto it is held
## by - Snared - for its own duration.
@export var trap_holds_with: ConditionDefinition
## It bursts as it is sprung, hitting everybody of the other side within Trap
## Burst Radius at Trap Burst Modifier (the setter's power behind it). Tripwire.
@export_range(0.0, 5.0, 0.05) var trap_burst_modifier: float = 0.0
@export_range(0, 4) var trap_burst_radius: int = 0
## Set on every free tile within this many of the one aimed at, at once, past
## the setter's usual limit. Minefield.
@export_range(0, 4) var trap_field_radius: int = 0

@export_group("Catalyst")
## Used when type is CATALYST. Every lingering condition of its user's, on every
## enemy - not only the one it is aimed at - goes off at once: one tick's damage
## times the ticks it had left times this, resisted once; then each starts again
## from the top. Bare damage-over-time wounds (not conditions) are left alone,
## and so is whatever anybody else put on: it is its user's own condition
## payoff, on purpose. Team-wide synergy would be a separate mechanic.
## Scope and arithmetic approved as they are (designer, 2026-10-24).
@export_range(0.0, 5.0, 0.05) var catalyst_times: float = 2.0

@export_group("Zone")
## Used when type is ZONE. The ground the skill covers (its area, where it is
## aimed) stays: whoever of Zone For stands in it has this, for as long as they
## stand there - stepping in puts it on, stepping out takes it off.
@export var zone_condition: ConditionDefinition
## Whose it is for: its caster's side, the other side, or anybody in it.
@export_enum("Their side", "The other side", "Everybody") var zone_for: int = 0
## How many of its caster's turns it lasts: 1 is until their next turn begins.
@export_range(1, 20) var zone_turns: int = 2
## The other side does not know it is there: the board draws it only for its
## own side. Reality's Reflection.
@export var zone_unseen: bool = false
## Every step onto it costs twice its movement (Crystalise's stones, Ravenous Dark).
@export var zone_costly: bool = false
## ...but not for anybody flying over it.
@export var zone_cost_spares_fliers: bool = false
## Anybody of the other side who starts their turn in it is hurt, at this many times
## its caster's power behind the skill, of this effect's Damage Type (Ravenous Dark,
## the Storm Cloud). 0: not at all.
@export_range(0.0, 5.0, 0.05) var zone_turn_damage: float = 0.0
## Anybody of their own side who starts their turn in it is mended, by the Heal fields
## here (Heal Flat, Heal Per Stat, Heal Per Weapon, Heal Modifier). Restorative Aura.
@export var zone_heals: bool = false
## It goes where its caster goes, the same size round them. Restorative Aura.
@export var zone_follows_caster: bool = false
## Its caster can move it, by the Move Cloud secondary action, while it lasts.
@export var zone_moves: bool = false
## What it hurts hurts its caster's own side as well: Burner's fire is anybody's.
@export var zone_hurts_everybody: bool = false
## Every step onto it hurts as starting a turn in it does, each tile again (Burner).
@export var zone_hurts_each_step: bool = false
## What hurts them there leaves on them what the skill's own effects leave: Burner's Burn.
@export var zone_leaves_conditions: bool = false
## Anybody a melee blow lands on while standing in it is carried to its edge, the way the
## blow came - further by whatever the blow or a passive would have shoved them (River Flow).
@export var zone_melee_sweeps: bool = false
## Anybody who starts or ends a turn in it is blown out of it (Wind Swoon).
@export var zone_blows_out: bool = false
## How the board tints it. Left clear, by whose it is. A placeholder until there is art.
## A zone that gives light from its middle, this many tiles out, the nearer half Bright (Burner's ground).
@export var zone_light_tiles: float = 0.0
@export var zone_colour: Color = Color(0, 0, 0, 0)
## Ground the other side takes for deadly: whoever the AI plays will not step on it, and whoever
## already stands there leaves it. It does nothing at all. If anybody of the other side ends up on it
## by any other way (shoved, thrown), they see it for what it is and it is gone (Combat "False Ground").
@export var zone_false_ground: bool = false

@export_group("Resistance")
## On a RESISTANCE effect: which base element is asked as it lands, in place of Damage
## Type - the caster's to choose (Elemental Ward).
@export var chooses_element: bool = false


## Which fields each effect type actually reads. Everything not listed for a
## type is hidden while that type is selected - see _validate_property.
const FIELDS_BY_TYPE := {
	EffectType.DAMAGE: ["damage_type", "min_amount", "max_amount"],
	EffectType.HEAL: ["heal_modifier", "heal_share_of_health", "heals_share_only", "share_doubled_on_wounded", "heal_flat", "heal_per_stat", "heal_per_weapon", "min_amount", "max_amount"],
	EffectType.STAT_MODIFIER: ["display_name", "stat", "modifier_amount", "duration", "wears_off_at_start"],
	EffectType.DAMAGE_OVER_TIME: ["display_name", "damage_type", "damage_modifier", "min_amount", "max_amount", "duration", "wears_off_at_start"],
	EffectType.DISPEL: ["dispel_stat", "dispel_scope", "dispel_count"],
	EffectType.PUSH: ["knockback_distance", "damage_type", "damage_modifier", "min_amount", "max_amount"],
	EffectType.PULL: ["knockback_distance"],
	EffectType.STAT_MULTIPLIER: ["display_name", "stat", "stat_multiplier", "duration", "wears_off_at_start"],
	EffectType.CONDITION: ["condition", "condition_duration", "held_by_tether", "comes_off_when_hurt", "flees_from_caster", "drawn_to_aim", "condition_dot_modifier", "lifts"],
	# Nothing to configure but how long they have to use it - which element it
	# becomes is the element's own business (see Damage.UPGRADES).
	EffectType.UPGRADE_ELEMENT: ["duration", "wears_off_at_start"],
	# Nothing to configure: it either lays the target open or it does not.
	EffectType.REVEAL: [],
	EffectType.MOVEMENT_CLASS: ["display_name", "movement_class", "duration", "wears_off_at_start"],
	# Nothing to configure: hiding lasts until somebody sees you, not a number
	# of turns, so there is no duration to set either.
	EffectType.HIDE: [],
	EffectType.RESISTANCE: ["display_name", "damage_type", "modifier_amount", "duration", "wears_off_at_start", "chooses_element", "held_by_tether"],
	EffectType.REVIVE: ["revive_health", "revive_weakening"],
	EffectType.STEAL: ["steal_count"],
	# Nothing to configure: an image is one point of health and no turns.
	EffectType.SUMMON_DECOY: ["image_moves"],
	# Nothing to configure: what happens is the object's own business.
	EffectType.INTERACT: [],
	# Nothing to configure: the hack is the skill's own (SkillDefinition.hack).
	EffectType.HACK: [],
	# Nothing to configure: it lasts until they act against an enemy. Outside a
	# fight it lasts the skill's own Outside Seconds.
	EffectType.INVISIBLE: ["unnoticed_until_acting"],
	# Nothing to configure: whatever they are casting comes to nothing.
	EffectType.CANCEL_CASTING: [],
	# Condition: what they suffer inside (Swallowed - a stomach eating them).
	# Duration: the swallower's own turns until they are digested, and dead.
	EffectType.SWALLOW: ["condition", "duration"],
	# One size bigger for Duration of their turns (0: the rest of the fight).
	EffectType.GROW: ["duration", "wears_off_at_start"],
	# Who, and whether it takes on its caller's attributes.
	EffectType.SUMMON: ["summons", "with_summoners_attributes", "summon_count", "summon_across", "summon_as_images", "summon_shakes"],
	# Nothing to configure: the summon it is aimed at acts, now.
	EffectType.COMMAND: [],
	# Nothing to configure: everything on the body comes off it.
	EffectType.LOOT: [],
	EffectType.DRAW: [],
	EffectType.TRAP: ["trap_holds_with", "trap_burst_modifier", "trap_burst_radius", "trap_field_radius"],
	EffectType.CATALYST: ["catalyst_times"],
	EffectType.ZONE: ["zone_condition", "zone_for", "zone_turns", "zone_unseen", "zone_costly", "zone_cost_spares_fliers", "zone_turn_damage", "damage_type",
		"zone_heals", "heal_modifier", "heal_flat", "heal_per_stat", "heal_per_weapon", "zone_follows_caster", "zone_moves",
		"zone_hurts_everybody", "zone_hurts_each_step", "zone_leaves_conditions", "zone_melee_sweeps", "zone_blows_out", "zone_colour", "zone_light_tiles", "zone_false_ground"],
	# Nothing to configure: how deep it reaches is the gate it is cast through.
	EffectType.DISPEL_MAGIC: [],
	EffectType.FAMILIAR: [],
	# Nothing to configure: whoever it lands on is seen.
	EffectType.UNVEIL: [],
	# Nothing to configure: the skill's Max Range is how far, from where it is.
	EffectType.MOVE_ZONE: [],
	EffectType.MOVE_IMAGE: [],
	# Nothing to configure: which disguise is what they carry (Combat "Disguises").
	EffectType.DISGUISE: [],
}


## How hard the condition this effect inflicts should burn: this effect's own
## figure when it sets one, and the condition's otherwise.
##
## One place decides it, so what a battle does and what the preview promises
## cannot drift apart.
func condition_dot_strength() -> float:
	if condition_dot_modifier > 0.0:
		return condition_dot_modifier
	return condition.dot_modifier if condition != null else 0.0


## Whether this heal is worked out by the flat rule (Heal Flat, Heal Per Stat,
## Heal Per Weapon) rather than as a share of the healer's power.
func heals_flat() -> bool:
	return heal_flat > 0.0 or heal_per_stat > 0.0 or heal_per_weapon > 0.0


func _set_damage_modifier(value: float):
	damage_modifier = value
	# Whether the flat fallback is worth showing has just changed.
	notify_property_list_changed()


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
	# The flat range only stands in when there is no skill behind the damage,
	# and a tick with a modifier always has one. Showing both is what made a
	# lingering wound look like it was set in two places at once.
	if type == EffectType.DAMAGE_OVER_TIME and damage_modifier > 0.0 and property.name in ["min_amount", "max_amount"]:
		property.usage = PROPERTY_USAGE_STORAGE
		return
	if property.name == "type" or not FIELDS_BY_TYPE.has(type):
		return
	if property.name in FIELDS_BY_TYPE[type]:
		return
	if property.name in ["resource_local_to_scene", "resource_path", "resource_name", "script"]:
		return
	property.usage = PROPERTY_USAGE_STORAGE
