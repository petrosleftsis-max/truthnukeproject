@tool
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
## Health at level 1, and what every level inherits unless it says otherwise.
@export_range(1, 2, 1, "or_greater") var max_hp = 1
## Health at levels 2 and 3. Zero means "same as the level below", so a
## character who is only ever fought at one strength needs nothing here, and
## setting only level 3 gives a jump at 3 with level 2 still matching level 1.
##
## Separate from the attribute curve on purpose: attributes are worked out from
## the level by formula, because they are how developed someone is. How much
## punishment a character can take is a design decision per character - a mage
## who never gets sturdier and a knight who doubles are both reasonable, and
## neither falls out of a formula.
@export_range(0, 2, 1, "or_greater") var max_hp_level_2 = 0
@export_range(0, 2, 1, "or_greater") var max_hp_level_3 = 0
@export_range(1, 3, 1, "or_greater") var movement = 3
@export_range(1, 2, 1, "or_greater") var initiative = 1

@export_subgroup("Attributes")
## The two attributes this character is built around. A combatant's level
## decides the numbers - main stat 47 at level 2 and 85 at level 3, secondary
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

@export_group("Party")
## Whether this one actually fights. Turn it off for someone who travels with
## the party but takes no part in battles - a guide, a prisoner, a child - and
## they'll walk in the line on the map and appear in the portrait column, but
## be left out when an encounter deploys the party.
@export var can_fight: bool = true

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
@export_group("AI (enemies only - ignored for player-controlled units)")
## Which Combat.gd function drives this enemy's turn. Built-in options:
## "ai_melee_rush" (default - rushes the nearest enemy and melees it),
## "ai_hit_and_explode", "ai_ranger", "ai_healer", "ai_caster",
## "ai_copycat". To add your own, write a new "func ai_my_type(comb:
## Dictionary):" in Combat.gd (following the pattern of the existing ones -
## it ends by either using a skill or calling advance_turn() itself) and
## type its name here. An unrecognised name falls back to ai_melee_rush.
@export var ai_function: String = "ai_melee_rush"


## Starting gates, indexed by level - [0] is unused so the level number
## reads straight into the array.
## Health at `level`, following the "same as the level below" rule: a level 3
## with nothing set of its own takes level 2's, which takes level 1's.
func hp_at(level: int) -> int:
	var health = max_hp
	if level >= 2 and max_hp_level_2 > 0:
		health = max_hp_level_2
	if level >= 3 and max_hp_level_3 > 0:
		health = max_hp_level_3
	return health


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
