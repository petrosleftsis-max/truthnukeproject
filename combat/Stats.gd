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


## --- Levels ---
##
## Sixty-four of them - the number of truth, ἀλήθεια, letter by letter -
## reached at milestones in the story (Campaign.reach_level) rather than
## through experience. A level decides every attribute someone has,
## their health (CombatantDefinition.hp_at), their gates and which of their
## skills they know (SkillDefinition.required_level). Battle Select and the
## like still set it per spawn, so a fight can be opened at any level.

const MAX_LEVEL := 64

## The level a character chooses their path at - see SubclassDefinition.
const SUBCLASS_LEVEL := 24

## What a combatant is at before their level does anything. Every attribute
## sits here except the two their character is built around.
const BASE_STAT := 10

## The main stat at MAX_LEVEL. It starts at BASE_STAT on level 1 and climbs the
## same step every level to here. The secondary stat is half of it, so a
## character is unmistakably better at the one thing they are for, without the
## other being an afterthought.
const MAIN_STAT_AT_MAX_LEVEL := 85


## How far from level 1 to MAX_LEVEL `level` is, 0 to 1.
static func level_progress(level: int) -> float:
	return float(clampi(level, 1, MAX_LEVEL) - 1) / float(MAX_LEVEL - 1)


## The value of a combatant's main stat at `level`.
static func main_stat_at(level: int) -> int:
	return roundi(lerpf(BASE_STAT, MAIN_STAT_AT_MAX_LEVEL, level_progress(level)))


## The value of their secondary stat: half the main one, rounded up - and never
## below BASE_STAT, which half of an early main stat would be. An attribute the
## character is built around is never worse than one they have nothing to do
## with, so level 1 is flat 10s whoever they are.
static func secondary_stat_at(level: int) -> int:
	return maxi(BASE_STAT, int(ceil(main_stat_at(level) / 2.0)))


## Every attribute for a combatant of `level` whose character is built around
## `main` and `secondary` (Stats.Type values). Everything else stays at
## BASE_STAT.
##
## Defense is deliberately absent: it comes from the spawn rather than the
## level, so the same character can be made tougher or more fragile for one
## encounter without touching what they can do.
static func stats_for_level(level: int, main: int, secondary: int) -> Dictionary:
	var table := {}
	for key in KEYS:
		table[key] = BASE_STAT
	var main_key = stat_key(main)
	var secondary_key = stat_key(secondary)
	if main_key != "":
		table[main_key] = main_stat_at(level)
	if secondary_key != "" and secondary_key != main_key:
		table[secondary_key] = secondary_stat_at(level)
	return table


static func stat_name(type: int) -> String:
	if type < 0 or type >= NAMES.size():
		return "Unknown"
	return NAMES[type]


static func stat_key(type: int) -> String:
	if type < 0 or type >= KEYS.size():
		return ""
	return KEYS[type]


## WeaponBase + 0.7 x Stat, before the skill's own modifier and the target.
##
## `weapon_base` is per combatant and set on the spawn, so the same character
## can be brought into one encounter better armed than another. Defaults to
## WEAPON_BASE for anything created without one.
static func base_damage(stat_value: int, weapon_base: int = WEAPON_BASE) -> float:
	return weapon_base + STAT_SCALING * stat_value


## The full chain: BaseDamage x AbilityModifier x 40/(40 + Defense), rounded to
## a whole point and never below one - a hit that connects always costs the
## target something, however well defended they are.
static func final_damage(base: float, ability_modifier: float, defense: int) -> int:
	var soak := DEFENSE_PIVOT / (DEFENSE_PIVOT + maxf(defense, 0.0))
	return maxi(int(round(base * ability_modifier * soak)), 1)


## --- The gates ---
##
## What each spell slot level is called. A spell does not cost "a level 2 slot",
## it is cast through the Gates of Hermes - and the game says so everywhere it
## mentions one, so the fiction and the rules use the same words.
##
## Indexed by level, with nothing at 0 because a skill that costs no gate is
## simply free.
##
## The ladder goes down before it goes up: the world and its myths (World,
## Hermes, Pandora), the underworld and its reckoning (Charon, Tartarus,
## Nemesis), the climb out toward the light (Sophia, the Ogdoad, Gnosis), and
## at the top the false god himself. When each opens is GATE_STEPS. Each starts
## with a different letter, since a spell button marks the gate it will pay
## from by its first.
const GATE_NAMES := ["", "Gates of World", "Gates of Hermes", "Gates of Pandora",
	"Gates of Charon", "Gates of Tartarus", "Gates of Nemesis", "Gates of Sophia",
	"Gates of Ogdoad", "Gates of Gnosis", "Gates of Yaldabaoth"]

## How a combatant gets about, in the order CombatantDefinition.class_m lists
## them. Kept here so a number in a resource has one place that says what it
## means.
const MOVEMENT_CLASS_NAMES := ["Ground", "Flying", "Mounted"]


static func movement_class_name(movement_class: int) -> String:
	if movement_class < 0 or movement_class >= MOVEMENT_CLASS_NAMES.size():
		return "Ground"
	return MOVEMENT_CLASS_NAMES[movement_class]


## Each gate's colour on the HUD - its shelf of spells and its counter - by
## level, like GATE_NAMES. A gate added without one gets a colour of its own
## from gate_colour rather than borrowing another's.
const GATE_COLOURS := [Color.WHITE, Color("5ec8bd"), Color("a48cf0"), Color("f0a15a")]


## The gate at `level`, or "" for a skill that costs nothing. A gate beyond the
## names written so far is still called something.
static func gate_name(level: int) -> String:
	if level < 1:
		return ""
	if level >= GATE_NAMES.size():
		return "Gate %d" % level
	return GATE_NAMES[level]


static func gate_colour(level: int) -> Color:
	if level >= 1 and level < GATE_COLOURS.size():
		return GATE_COLOURS[level]
	# Round the colour wheel by the golden angle, so gates added later never
	# land on top of each other's colour.
	return Color.from_hsv(fmod(0.12 + 0.381966 * float(level), 1.0), 0.45, 0.95)


## Just the name of it - "Hermes" rather than "Gates of Hermes".
##
## For the battle HUD, where the full name is said three times over in a row of
## slots too narrow to hold it, and where anybody reading it already knows what
## the gates are. Derived from the full name rather than written out a second
## time, so renaming a gate renames it everywhere. The glossary keeps saying it
## in full, because that is where the fiction is explained rather than counted.
static func short_gate_name(level: int) -> String:
	return gate_name(level).trim_prefix("Gates of ")


## --- Gates outside a fight ---
##
## Gates opened only outside a fight, each as strong as one on the ladder
## (`matches`). Their castings are their own: sneaking past a guard never costs
## the next fight's gates. In a fight a spell of one is paid through the ladder
## gate it says (SkillDefinition.spell_slot_level), like any other.
##
## Indexed like SkillDefinition.outside_gate, with nothing at 0. Mnemosyne is to
## come, matching the fifth or sixth gate.
const OUTSIDE_GATES := [
	{},
	{"name": "Gates of Iris", "matches": 2, "colour": Color("f2a7d8")},
]


static func outside_gate_name(gate: int) -> String:
	if gate < 1 or gate >= OUTSIDE_GATES.size():
		return ""
	return OUTSIDE_GATES[gate].name


static func short_outside_gate_name(gate: int) -> String:
	return outside_gate_name(gate).trim_prefix("Gates of ")


static func outside_gate_colour(gate: int) -> Color:
	if gate < 1 or gate >= OUTSIDE_GATES.size():
		return Color.WHITE
	return OUTSIDE_GATES[gate].colour


## How many castings each outside gate has at `level`, indexed like
## OUTSIDE_GATES: as many as the ladder gate it matches, until they have a
## table of their own.
static func outside_gates_for_level(level: int) -> Array:
	var ladder := gates_for_level(level)
	var counts := [0]
	for gate in range(1, OUTSIDE_GATES.size()):
		var matches: int = OUTSIDE_GATES[gate].matches
		counts.append(ladder[matches] if matches < ladder.size() else 0)
	return counts


## How many castings through each gate a combatant has, by level: D&D's full
## casters stretched so that its level 20 is our 64 - each of its levels about
## 3.3 of ours. A new gate every six or seven levels, opening with one or two
## castings and gaining one a few levels later; the low gates stop growing
## early (World at 4 by level 8, Hermes at 3 by 11), and from about 34 on the
## growth is new gates at one casting each - the price of each being so much
## stronger than the last. D&D stops at nine; the tenth follows its rhythm, at
## 61.
##
## A rule of how far along someone is rather than a number set per character:
## nobody is a special case. Only combatants who actually carry a spell get any
## of it - a swordsman is not walking around with unused castings.
##
## Each entry is the level a change comes at and what everybody has from then
## on, World first; a level between two entries has the earlier one's.
const GATE_STEPS := [
	[1, [2]],
	[4, [3]],
	[8, [4, 2]],                          ## Hermes opens.
	[11, [4, 3]],
	[14, [4, 3, 2]],                      ## Pandora opens - twice already.
	[18, [4, 3, 3]],
	[21, [4, 3, 3, 1]],                   ## Charon.
	[24, [4, 3, 3, 2]],
	[28, [4, 3, 3, 3, 1]],                ## Tartarus.
	[31, [4, 3, 3, 3, 2]],
	[34, [4, 3, 3, 3, 2, 1]],             ## Nemesis.
	[41, [4, 3, 3, 3, 2, 1, 1]],          ## Sophia.
	[47, [4, 3, 3, 3, 2, 1, 1, 1]],       ## Ogdoad.
	[54, [4, 3, 3, 3, 2, 1, 1, 1, 1]],    ## Gnosis.
	[57, [4, 3, 3, 3, 3, 1, 1, 1, 1]],
	[61, [4, 3, 3, 3, 3, 2, 1, 1, 1, 1]], ## Yaldabaoth.
	[64, [4, 3, 3, 3, 3, 2, 2, 1, 1, 1]],
]


## No castings through any gate, as wide as the ladder.
static func no_gates() -> Array:
	var none := []
	none.resize(GATE_NAMES.size())
	none.fill(0)
	return none


## A half caster's allowance at `level` (CombatantDefinition.half_caster): a
## full caster's at half the level, rounded up, as a D&D paladin's spell slots
## are a full caster's at half the paladin's level - at 16 the gates of 8
## (World 4, Hermes 2), at 64 those of 32. The designer, 2026-10-25.
static func half_caster_gates(level: int) -> Array:
	return gates_for_level(ceili(level / 2.0))


## The allowance at `level`, indexed by gate with nothing at 0, as wide as the
## ladder - a fresh array, since it is spent down over a fight.
static func gates_for_level(level: int) -> Array:
	var row := no_gates()
	for step in GATE_STEPS:
		if step[0] > level:
			break
		var counts: Array = step[1]
		for gate in counts.size():
			if gate + 1 < row.size():
				row[gate + 1] = counts[gate]
	return row
