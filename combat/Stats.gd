class_name Stats
## The four attributes a combatant acts with, the one they defend with, and
## the arithmetic that turns them into damage.
##
## Everything a skill does scales off exactly one of these, chosen per skill
## (see SkillDefinition.scaling_stat), so the same Fireball hits harder in the
## hands of a better mind without any per-character numbers to maintain.


enum Type {
	PHYSICAL,     ## Force and conditioning - swings, shoves, endurance.
	MINDFULNESS,  ## Attention and presence - reading a fight as it happens.
	INTELLECT,    ## Learned knowledge - the stat most magic is built on.
	SELF,         ## Conviction and identity - what resists being changed.
	DEFENSE,      ## Soaks incoming damage. Not an attacking stat.
}

const NAMES := ["Physical", "Mindfulness", "Intellect", "Self", "Defense"]

## The keys these are stored under on a combatant dictionary, in Type order.
## "self" is a GDScript keyword, so the Self stat is carried as "self_stat"
## everywhere in code and only ever called "Self" in front of a player.
const KEYS := ["physical", "mindfulness", "intellect", "self_stat", "defense"]

## What every attack starts from before any stat is added. Stands in for the
## weapon the attacker is holding, which nobody holds yet - when equipment
## exists this is what it will replace.
const WEAPON_BASE := 6

## How much of the scaling stat carries into the hit.
const STAT_SCALING := 0.7

## The defense value at which damage is halved. Damage is multiplied by
## DEFENSE_PIVOT / (DEFENSE_PIVOT + defense), so defense gives diminishing
## returns and can never reduce a hit to nothing however high it goes.
const DEFENSE_PIVOT := 40.0


static func stat_name(type: int) -> String:
	if type < 0 or type >= NAMES.size():
		return "Unknown"
	return NAMES[type]


static func stat_key(type: int) -> String:
	if type < 0 or type >= KEYS.size():
		return ""
	return KEYS[type]


## WeaponBase + 0.7 x Stat, before the skill's own modifier and the target.
static func base_damage(stat_value: int) -> float:
	return WEAPON_BASE + STAT_SCALING * stat_value


## The full chain: BaseDamage x AbilityModifier x 40/(40 + Defense), rounded to
## a whole point and never below one - a hit that connects always costs the
## target something, however well defended they are.
static func final_damage(base: float, ability_modifier: float, defense: int) -> int:
	var soak := DEFENSE_PIVOT / (DEFENSE_PIVOT + maxf(defense, 0.0))
	return maxi(int(round(base * ability_modifier * soak)), 1)
