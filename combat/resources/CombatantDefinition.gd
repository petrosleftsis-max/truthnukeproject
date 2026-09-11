extends Resource
class_name CombatantDefinition


@export var name = ""
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

@export_subgroup("Gates")
## How many casts through each gate this combatant starts a battle with. A spell
## cast through the Gates of World can be paid for with Hermes or Yaldabaoth
## instead, and a Hermes spell with Yaldabaoth - never the other way round.
## Leave at zero for anyone who casts nothing.
@export_range(0, 9) var gates_of_world: int = 0
@export_range(0, 9) var gates_of_hermes: int = 0
@export_range(0, 9) var gates_of_yaldabaoth: int = 0
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
@export var secondary_skills: Array[String]
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
@export_range(-100, 100, 1, "or_greater", "or_less") var resist_pure_energy: int = 0

@export_group("Party")
## Whether this one actually fights. Turn it off for someone who travels with
## the party but takes no part in battles - a guide, a prisoner, a child - and
## they'll walk in the line on the map and appear in the portrait column, but
## be left out when an encounter deploys the party.
@export var can_fight: bool = true
@export_group("AI (enemies only - ignored for player-controlled units)")
## Which Combat.gd function drives this enemy's turn. Built-in options:
## "ai_melee_rush" (default - rushes the nearest enemy and melees it),
## "ai_hit_and_explode", "ai_ranger", "ai_healer", "ai_caster",
## "ai_copycat". To add your own, write a new "func ai_my_type(comb:
## Dictionary):" in Combat.gd (following the pattern of the existing ones -
## it ends by either using a skill or calling advance_turn() itself) and
## type its name here. An unrecognised name falls back to ai_melee_rush.
@export var ai_function: String = "ai_melee_rush"


## Starting spell slots, indexed by level - [0] is unused so the level number
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


func spell_slot_table() -> Array:
	return [0, gates_of_world, gates_of_hermes, gates_of_yaldabaoth]


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
		Damage.Type.PURE_ENERGY: resist_pure_energy,
	}
