extends Resource
class_name CombatantDefinition


@export var name = ""
@export_group("Class")
@export_enum("Melee", "Ranged", "Magic") var class_t = 0
@export_enum("Ground", "Flying", "Mounted") var class_m = 0
@export_group("Stats")
@export_range(1, 2, 1, "or_greater") var max_hp = 1
@export_range(1, 3, 1, "or_greater") var movement = 3
@export_range(1, 2, 1, "or_greater") var initiative = 1

@export_subgroup("Attributes")
## The four attributes every skill scales from, plus the one that soaks
## incoming damage. See Stats.gd for how they turn into a damage number.
##
## Named self_stat rather than self because "self" is a GDScript keyword; it is
## the Self attribute everywhere it is shown to a player.
@export_range(1, 100) var physical: int = 10
@export_range(1, 100) var mindfulness: int = 10
@export_range(1, 100) var intellect: int = 10
@export_range(1, 100) var self_stat: int = 10
## Damage is multiplied by 40/(40 + this), so 40 halves an incoming hit and 120
## quarters it. Diminishing returns, so no amount of it makes anyone immune.
@export_range(1, 100) var defense: int = 10

@export_subgroup("Spell Slots")
## How many casts of each level this combatant starts a battle with. A skill
## costing a level 1 slot can be paid for with a level 2 or 3 instead, and a
## level 2 skill with a level 3 - never the other way round. Leave at zero for
## anyone who casts nothing.
@export_range(0, 9) var spell_slots_1: int = 0
@export_range(0, 9) var spell_slots_2: int = 0
@export_range(0, 9) var spell_slots_3: int = 0
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


## The attributes above, keyed the way a combatant dictionary carries them.
func stat_table() -> Dictionary:
	return {
		"physical": physical,
		"mindfulness": mindfulness,
		"intellect": intellect,
		"self_stat": self_stat,
		"defense": defense,
	}


## Starting spell slots, indexed by level - [0] is unused so the level number
## reads straight into the array.
func spell_slot_table() -> Array:
	return [0, spell_slots_1, spell_slots_2, spell_slots_3]


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
