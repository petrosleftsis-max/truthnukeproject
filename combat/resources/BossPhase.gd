@icon("res://art/editor_icons/boss_phase.svg")
extends Resource
class_name BossPhase
## A turn in a boss fight (BossDefinition.phases): once the boss is down to At
## Health, its name comes up across the screen and the boss changes - new
## skills, a different way of fighting, more turns, a different stagger bar,
## help arriving, the arena turning on the party. Anything left empty stays as
## it was.

## Shown big under the boss's name: "The Ash Rises".
@export var name: String = ""
## The share of its health it begins at: 0.5 is half.
@export_range(0.0, 1.0, 0.01) var at_health: float = 0.5
## Into the log as it begins.
@export_multiline var message: String = ""

@export_group("The boss")
@export var skills_added: Array[String] = []
@export var skills_removed: Array[String] = []
@export var passives_added: Array[PassiveDefinition] = []
## A different way of fighting (an ai_ function in Combat.gd). Empty keeps it.
@export var ai_function: String = ""
## Turns a round from now on. 0 keeps it.
@export_range(0, 4, 1, "or_greater") var turns_per_round: int = 0
## A different stagger bar, started empty. Empty keeps the one it has.
@export var stagger: StaggerDefinition
## Every condition on it gone.
@export var clears_conditions: bool = false
## Track to change to. Empty keeps the music.
@export var music: String = ""
## Parts it grows (BodyPartDefinition), whole. On tiles it already has a part
## on, the new one grows over the old - the old can't be aimed at there now.
## Laid out on it as it is before Grows below makes it bigger: they stretch
## with the rest of it.
@export var parts_added: Array[BodyPartDefinition] = []
## Sizes it grows by, for good, as it begins - bigger with the parts it grows
## (Combat "Growing"). With no room it grows as soon as there is some.
@export_range(0, 3, 1) var grows: int = 0
## How many it can hold at once from now on (CombatantDefinition.holds_at_once).
## 0 keeps it.
@export_range(0, 4, 1) var holds_at_once: int = 0
## With nothing else in reach to eat as its turn begins, it eats itself: tears
## off this share of its health - a meal like any other, but one that feeds it
## nothing back. 0: it never does.
@export_range(0.0, 0.5, 0.01) var eats_itself: float = 0.0

@export_subgroup("Immunities")
@export var immunities_gained: Array[ConditionDefinition] = []
@export var immunities_lost: Array[ConditionDefinition] = []
@export var immune_to_gained: Array[Immunity.Kind] = []
@export var immune_to_lost: Array[Immunity.Kind] = []

@export_group("Help arriving")
## Combatant keys, each put as near the boss as they fit. A key twice is two.
@export var summons: Array[String] = []

@export_group("The arena")
## Hazards that start now.
@export var hazards: Array[HazardDefinition] = []
## The hazards already going stop.
@export var ends_hazards: bool = false
