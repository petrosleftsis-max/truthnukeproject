@icon("res://art/editor_icons/skill.svg")
extends Resource
class_name SkillRank
## A skill grown stronger with its user's level (SkillDefinition.ranks): from
## Level on, the figures set here stand in for the skill's own. A stronger
## version of a move is the move itself - Greatsword Attack at 1.0 from level 1
## and 1.5 from level 8 - not a second move beside it that differs by a number.
##
## A figure left at 0 keeps whatever the skill (or the rank before) says.

## The user's level this rank comes in at.
@export_range(1, 64) var level: int = 8
## What the move is called from here, if it is known by another name - "" keeps
## the skill's. Said on the Levels page.
@export var title: String = ""
## The skill's Ability Modifier from here.
@export_range(0.0, 10.0, 0.05, "or_greater") var ability_modifier: float = 0.0
## How hard the conditions it inflicts burn from here (EffectDefinition's
## Condition Dot Modifier).
@export_range(0.0, 5.0, 0.05, "or_greater") var condition_dot_modifier: float = 0.0
## How long the conditions it inflicts last from here, in turns.
@export_range(0, 20) var condition_duration: int = 0

@export_group("Splash")
## From here a hit that lands also catches everybody of the other side within
## this many tiles of whoever it landed on (Combat._splash) - Titanfall. 0 is
## none.
@export_range(0, 6) var splash_radius: int = 0
## What it hits them for, as an Ability Modifier.
@export_range(0.0, 10.0, 0.05, "or_greater") var splash_modifier: float = 0.0
## And how many tiles it shoves them, away from the one who struck.
@export_range(0, 6) var splash_shove: int = 0
