@icon("res://art/editor_icons/hazard.svg")
extends Resource
class_name HazardDefinition
## Something the arena does by itself: rocks coming down, a floor catching
## fire. An encounter's Hazards run from the start; a boss's phase can start
## more (BossPhase.hazards) or stop them.
##
## Falling marks its tiles at the top of a round and lands on them at the top of
## the next, so everybody has had a turn to get clear - the same marks a declared
## skill leaves. Ground marks its tiles and hurts whoever starts a turn on one,
## for as long as it lasts.
##
## A boss caught in it can be staggered by it (Stagger) - which makes luring the
## boss under the rocks a way to win.

enum Kind {
	FALLING,  ## Marked a round ahead, then lands once.
	GROUND,   ## Bad ground for a while: hurts whoever starts a turn on it.
}

enum Aim {
	ANYWHERE,      ## Open tiles anywhere on the map.
	AT_THE_PARTY,  ## Where the party is standing.
	AT_EVERYONE,   ## Where anybody is standing, either side.
	THESE_TILES,   ## Exactly the Tiles below.
}

enum Hits {
	EVERYONE,
	THE_PARTY,
	THE_ENEMIES,
}

@export var display_name: String = "Falling rocks"
@export_multiline var description: String = ""
@export var kind: Kind = Kind.FALLING

@export_group("When")
## The round it first happens in.
@export_range(1, 20, 1, "or_greater") var first_round: int = 1
## And then every this many rounds.
@export_range(1, 10, 1, "or_greater") var every_rounds: int = 1
## Ground only: how many rounds the bad ground stays.
@export_range(1, 20, 1, "or_greater") var lasts_rounds: int = 2

@export_group("Where")
@export var aim: Aim = Aim.AT_THE_PARTY
## How many places each time.
@export_range(1, 20, 1, "or_greater") var count: int = 1
## Tiles out from each place, as a diamond. 0 is the one tile.
@export_range(0, 6, 1) var radius: int = 1
## For These Tiles.
@export var tiles: Array[Vector2i] = []

@export_group("What it does")
@export var hits: Hits = Hits.EVERYONE
## Before defence and resistance, the way an item's power is.
@export_range(0, 999, 1, "or_greater") var damage: int = 0
@export var damage_type: Damage.Type = Damage.Type.PHYSICAL
@export var condition: ConditionDefinition
## 0 for the condition's own.
@export_range(0, 10, 1) var condition_duration: int = 0
## Added to the stagger bar of a boss it catches.
@export_range(0.0, 500.0, 1.0, "or_greater") var stagger: float = 0.0


## Whether it happens in `round`.
func due_in(round: int) -> bool:
	return round >= first_round and (round - first_round) % maxi(every_rounds, 1) == 0


## Whether it catches somebody of `side`.
func catches(side: int) -> bool:
	match hits:
		Hits.THE_PARTY:
			return side == 0
		Hits.THE_ENEMIES:
			return side == 1
	return true
