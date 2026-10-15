@tool
@icon("res://art/editor_icons/character.svg")
## Marked @tool so the encounter editor can ask a definition what it looks
## like. A resource whose script is not a tool script is a placeholder in the
## editor: its properties can be read but none of its methods exist, which is
## why spawn markers drew nothing the moment portraits started coming from a
## method rather than straight off a field.
extends Resource
class_name CombatantDefinition


@export var name = ""
## Who this is, for the glossary's Character intros. Freeform - write as much or
## as little as you like; a character with nothing written here simply says so.
##
## Kept next to everything else about them rather than in the glossary book, so
## there is one place a character is described.
@export_multiline var glossary_text: String = ""
@export_group("Class")
@export_enum("Melee", "Ranged", "Magic") var class_t = 0
@export_enum("Ground", "Flying", "Mounted") var class_m = 0
@export_group("Stats")
## Health at level 1.
@export_range(1, 2, 1, "or_greater") var max_hp = 1
## Health at level 20. Every level between climbs the same step from Max Hp to
## this (see hp_at). Zero means the same as level 1 all the way up, so a
## character only ever fought at one strength needs nothing here.
##
## Separate from the attribute curve on purpose: attributes are worked out from
## the level by formula, because they are how developed someone is. How much
## punishment a character can take is a design decision per character - a mage
## who never gets sturdier and a knight who doubles are both reasonable, and
## neither falls out of a formula.
@export_range(0, 2, 1, "or_greater") var max_hp_level_20 = 0
## How big they are - see Sizes. A Human is one tile; Tiny and Small share a
## tile with their own side; Large and up cover 2 x 2 tiles and more.
@export var size: Sizes.Size = Sizes.Size.HUMAN
## For a Gigantic one: how many tiles a side it covers, 16 or more.
@export_range(16, 64) var gigantic_span: int = 16
@export_range(1, 3, 1, "or_greater") var movement = 3
@export_range(1, 2, 1, "or_greater") var initiative = 1

@export_subgroup("Attributes")
## The two attributes this character is built around. A combatant's level
## decides the numbers - main stat 10 at level 1 climbing to 85 at level 20, secondary
## half that, everything else a flat 10 - so all that is set here is which two
## they are. See Stats.stats_for_level.
##
## Per character, not per AI archetype: two enemies driven by the same AI can
## be built around completely different attributes.
##
## Defense and weapon base are deliberately not here. Both are set per spawn in
## the encounter editor, so the same character can be tougher or better armed
## in one fight than another.
@export var main_stat: Stats.Type = Stats.Type.PHYSICAL
@export var secondary_stat: Stats.Type = Stats.Type.MINDFULNESS

## Gates are not set here. How many castings someone has is decided by how far
## along they are - see Stats.GATES_BY_LEVEL - and they only have any at all if
## they carry a spell to cast. A spell can be cast through a higher gate than it
## asks for but never a lower one, and combat spends the cheapest that will do.
@export_group("Visual")
@export var icon: Texture2D
## Used only if sprite_frames below is empty - a single static image on the
## map, exactly how every combatant works today.
@export var map_sprite: Texture2D
## Optional. Set this to animate this combatant on the map instead of using
## a static image - see CombatantSprite.gd for the animation names it looks
## for ("idle", "walk", "skill", "dead") and how to build one. Leave empty
## to keep using map_sprite as a plain static sprite.
@export var sprite_frames: SpriteFrames
@export_group("Skills")
@export var skills: Array[String]
## Skills this combatant can additionally use in their secondary slot, on top
## of everything already marked is_secondary. This is the per-character
## exception: Run is a main skill for everyone, but listing it here for Cyrus
## lets him also use it as a secondary - so he can Run twice in one turn.
## A skill listed here doesn't have to leave the main panel; it can appear in
## both.
##
## Prefer a passive for this (PassiveDefinition.secondary_skills): it does the
## same and the character sheet shows it under Passive Skills, where this list
## is shown nowhere. Cyrus's Light Footed is one.
@export var secondary_skills: Array[String]
## What they do without being asked - working all the time, or once their
## moment comes. Never on the action panel; the character sheet lists them
## under Passive Skills. See PassiveDefinition.
@export var passives: Array[PassiveDefinition] = []
## The paths they can choose between at level 5, by key, in the order the
## choice offers them. See SubclassDefinition.
@export var subclasses: Array[String] = []
@export_group("Resistances")
## How this combatant stands up to each kind of damage, as a percentage.
## Positive resists - 20 means a fifth of that damage is shrugged off, 100
## means immune. Negative is a vulnerability - -20 means a fifth extra gets
## through. Zero is normal.
##
## Per character, not per AI archetype: two combatants running the same AI can
## have completely different resistances, and changing one never affects how
## they behave.
@export_range(-100, 100, 1, "or_greater", "or_less") var resist_physical: int = 0
@export_range(-100, 100, 1, "or_greater", "or_less") var resist_fire: int = 0
@export_range(-100, 100, 1, "or_greater", "or_less") var resist_water: int = 0
@export_range(-100, 100, 1, "or_greater", "or_less") var resist_wind: int = 0
@export_range(-100, 100, 1, "or_greater", "or_less") var resist_earth: int = 0
@export_range(-100, 100, 1, "or_greater", "or_less") var resist_poison: int = 0
@export_range(-100, 100, 1, "or_greater", "or_less") var resist_psychic: int = 0
## The upgraded elements. An upgraded type is its own element, not a stronger
## version of the one it came from, so resisting Fire does nothing against
## Plasma unless this says so too.
@export_range(-100, 100, 1, "or_greater", "or_less") var resist_plasma: int = 0
@export_range(-100, 100, 1, "or_greater", "or_less") var resist_ice: int = 0
@export_range(-100, 100, 1, "or_greater", "or_less") var resist_lightning: int = 0
@export_range(-100, 100, 1, "or_greater", "or_less") var resist_metal: int = 0
@export_range(-100, 100, 1, "or_greater", "or_less") var resist_acid: int = 0
@export_range(-100, 100, 1, "or_greater", "or_less") var resist_idol: int = 0

@export_group("Immunities")
## Conditions that never take hold on them - a golem that cannot be poisoned, a
## boss nobody can stun. Drag the condition's file in from data/conditions/. (To
## be immune to a kind of damage, set its resistance above to 100.)
@export var immune_to_conditions: Array[ConditionDefinition] = []
## The other things that cannot be done to them (Immunity).
@export var immune_to: Array[Immunity.Kind] = []

@export_group("Turns")
## Turns they get each round, spread through it. A boss facing a whole party
## usually wants more than one.
@export_range(1, 4, 1, "or_greater") var turns_per_round: int = 1

@export_group("Boss")
## Makes them a boss, whatever their size: their name across the screen as they
## appear, their own health bar along the top, phases and a stagger bar.
@export var boss: BossDefinition

@export_group("Nerve")
## How much it takes to break them (Combat "Nerve"): what shakes them - their
## leader falling, half their side down, being badly hurt, being alone, being
## afraid, being intimidated - is added up at the start of their turns, and at
## this much or more they break. Immune to Breaking (above) never breaks.
@export_range(0, 300, 1) var nerve: int = 60
## Broken, they run for it - and are gone after a couple of turns - or throw
## down their weapons and are taken.
@export_enum("Flees", "Surrenders") var when_broken: int = 0
## Their side's leader: when they fall, the rest of their side lose heart.
@export var leads: bool = false
## Fled and got away (Combat "Getting away"), what comes of it: nothing more,
## they are gone; they come back (with whoever Brings Back names) Back After
## Rounds later, where they left; or the fight is lost - the messenger who must
## not reach the gate.
@export_enum("Gone", "Comes back", "Fight lost") var when_fled: int = 0
@export_range(1, 10, 1) var back_after_rounds: int = 2
## Coming back: who comes with them, by combatant key.
@export var brings_back: Array[String] = []
## Set when they get away, for a conversation afterwards to know.
@export var fled_flag: String = ""

@export_group("Dealing with them")
## Gold that buys them out of a fight (Bribe, or a parley before it): a
## mercenary's price. 0 for somebody who cannot be bought.
@export_range(0, 9999, 1) var bribe_price: int = 0
## Clues (by key) that give the party something on them - what Intimidate,
## Persuade and Deceive need. Knowing their faction (FactionDefinition, through a
## clue) does as well.
@export var leverage_clues: Array[String] = []
## Taken alive (surrendered or knocked out), what questioning them gives up:
## clues by key...
@export var interrogation_clues: Array[String] = []
## ...gold, from where they stashed their pay...
@export_range(0, 9999, 1) var interrogation_gold: int = 0
## ...and, optionally, a conversation of their own, played instead of the
## plain questioning.
@export var interrogation_dialogue: Resource
@export var interrogation_title: String = "start"

@export_group("Bound")
## Who they are bound to - "the sorcerer", "its master" - for a creature held
## by a binding. Prometheus can hack a bound creature's binding with Rebind
## Hack below, and it fights for the party. Empty: not bound.
@export var bound_to: String = ""
## The binding's sheet: a Rewrite the Rule whose last line is who it answers to.
@export var rebind_hack: HackDefinition
## Turns of its own it fights for the party, rebound. 0 for the rest of the fight.
@export_range(0, 20, 1) var rebind_turns: int = 0

@export_group("Body parts")
## Places on them that can be aimed at and broken (BodyPartDefinition) - legs,
## arms, an armour plate. For somebody bigger than a tile.
@export var parts: Array[BodyPartDefinition] = []

@export_group("Party")
## Whether this one actually fights. Turn it off for someone who travels with
## the party but takes no part in battles - a guide, a prisoner, a child - and
## they'll walk in the line on the map and appear in the portrait column, but
## be left out when an encounter deploys the party.
@export var can_fight: bool = true
## Whether they keep the enemy codex: every enemy they study - with Study, or
## any other way - gets its page written (Campaign "The enemy codex"). Enfina
## and Prometheus do.
@export var keeps_codex: bool = false

## Whether consumables that would normally cost the main action can be used as
## a secondary one instead. Cyrus can: quick hands are his, and it is why he
## can drink a potion and still swing in the same turn.
## Prefer a passive for this (PassiveDefinition.items_as_secondary), which the
## sheet shows; Cyrus's Quick Hands is one.
@export var items_as_secondary: bool = false

## The kit this character is written as carrying: what an encounter's spawn
## list is seeded from when you want them to turn up equipped.
##
## Nothing is handed out from here automatically. A bag is filled by something
## that happens in the game - an encounter's spawn saying what its fighter
## brings, or a dialogue giving somebody something - so walking onto a map
## starts everyone empty-handed.
@export var starting_items: Array[String] = []
@export_group("Faction")
## The side they belong to, by key (FactionDefinition) - empty for nobody's.
## Learning about it (ClueDefinition.reveals_factions) opens their sheet in every
## fight and has the party hit them harder.
@export var faction: String = ""

@export_group("AI (enemies only - ignored for player-controlled units)")
## Which Combat.gd function drives this enemy's turn. Built-in options:
## "ai_melee_rush" (default - rushes the nearest enemy and melees it),
## "ai_hit_and_explode", "ai_ranger", "ai_healer", "ai_caster",
## "ai_copycat". To add your own, write a new "func ai_my_type(comb:
## Dictionary):" in Combat.gd (following the pattern of the existing ones -
## it ends by either using a skill or calling advance_turn() itself) and
## type its name here. An unrecognised name falls back to ai_melee_rush.
@export var ai_function: String = "ai_melee_rush"


## Health at `level`: Max Hp at level 1, Max Hp Level 20 at level 20, and the
## same step every level between, rounded.
func hp_at(level: int) -> int:
	if max_hp_level_20 <= 0:
		return max_hp
	return roundi(lerpf(max_hp, max_hp_level_20, Stats.level_progress(level)))


## What this combatant may cast at `level`: their level's allowance if they have
## a spell at all, and nothing if they have not. A swordsman does not walk
## around with two unused castings of a gate he cannot open.
func gates_at(level: int) -> Array:
	if not casts_spells():
		return [0, 0, 0, 0]
	return Stats.gates_for_level(level)


## Whether anything they know is cast through a gate.
func casts_spells() -> bool:
	# SkillDatabase is an autoload, so it is not there while the editor is just
	# laying a map out. Nothing casts anything in the editor either.
	if Engine.is_editor_hint():
		return false
	for key in skills + secondary_skills:
		var skill: SkillDefinition = SkillDatabase.skills.get(key)
		if skill != null and skill.spell_slot_level > 0:
			return true
	return false


## The resistances above, keyed by Damage.Type, so combat can look one up by
## the type of damage being dealt rather than knowing the field names. Copied
## onto each combatant when they're created.
func resistance_table() -> Dictionary:
	return {
		Damage.Type.PHYSICAL: resist_physical,
		Damage.Type.FIRE: resist_fire,
		Damage.Type.WATER: resist_water,
		Damage.Type.WIND: resist_wind,
		Damage.Type.EARTH: resist_earth,
		Damage.Type.POISON: resist_poison,
		Damage.Type.PSYCHIC: resist_psychic,
		Damage.Type.PLASMA: resist_plasma,
		Damage.Type.ICE: resist_ice,
		Damage.Type.LIGHTNING: resist_lightning,
		Damage.Type.METAL: resist_metal,
		Damage.Type.ACID: resist_acid,
		Damage.Type.IDOL: resist_idol,
	}


## --- What this combatant looks like ---
##
## Icon and MapSprite are optional. Left empty they are taken from the first
## frame of the animation set, so a character with art never wears somebody
## else's face for want of a second field kept in step with the first - which is
## exactly what happened when the enemies were given their own animations and
## their portraits stayed pointing at Cyrus.


## The still that stands for them in the turn queue, the party panel and the
## battle selector.
func portrait() -> Texture2D:
	return icon if icon != null else first_frame()


## The still used on the map for anyone with no animation set at all.
func map_still() -> Texture2D:
	return map_sprite if map_sprite != null else first_frame()


## The first frame of their idle, or of whatever animation they do have. Null
## for a combatant with no animation set, which is what an empty portrait means.
func first_frame() -> Texture2D:
	if sprite_frames == null:
		return null
	var names = sprite_frames.get_animation_names()
	var wanted = "idle" if sprite_frames.has_animation("idle") else (names[0] if names.size() > 0 else "")
	if wanted == "" or sprite_frames.get_frame_count(wanted) == 0:
		return null
	return sprite_frames.get_frame_texture(wanted, 0)


## Faction as a dropdown of the factions there are, blank first for none.
func _validate_property(property: Dictionary):
	if property.name == "faction" and Engine.is_editor_hint():
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = "," + ",".join(FactionDefinition.all().keys())
