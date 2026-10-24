@tool
@icon("res://art/editor_icons/battle_object.svg")
extends CombatantDefinition
class_name BattleObjectDefinition
## Something on the battlefield that is not anybody: a bell to ring, a pillar to
## bring down on a boss, a chandelier to drop. Saved in res://data/objects/ and
## placed in a fight like any combatant, on any side - it belongs to nobody.
##
## It takes no turns and is not counted when deciding who has won. It stands in
## the way and blocks sight the way a body of its size does. The party can Use
## it from beside it (the Interact skill, offered to everybody while there is
## something to use), and can break it if it is Breakable. Either sets it off:
## what is under "Set off" happens - a boss's stagger bar filling, a blast around
## it - and once its uses are spent it is gone.
##
## Its Max Hp, Size, look (Visual) and Glossary Text are the ones above; the
## rest of what a combatant has means nothing to it.

@export_group("The object")
## The party can Use it from beside it.
@export var interactable: bool = true
## Times it can be Used before it is spent. 0 is as often as you like.
@export_range(0, 10, 1) var uses: int = 1
## Hits hurt it, and it is set off when it breaks. Otherwise they do nothing.
@export var breakable: bool = false
## Using it turns it into this instead of setting it off - a carcass that a
## Use taints. Empty: Using it sets it off, as above.
@export var used_becomes: BattleObjectDefinition
## Called up by somebody (a SUMMON effect): it fades after this many of their
## turns, never having been there - Illusory Cover. 0 for for good.
@export_range(0, 20, 1) var lasts_turns: int = 0
## It is not there at all - an illusion, as an image is (Combat "Images"): to
## the other side's mind it blocks sight and is cover, and they plan around it;
## what actually happens goes straight through it, blasts and shots alike, and
## nothing hits it. Illusory Cover.
@export var illusion: bool = false

@export_group("Food")
## Eaten by whoever eats food on the map (CombatantDefinition.eats) once they
## are near enough: gone, and it does what is below to them.
@export var edible: bool = false
## A real meal: it heals them (their Meal Heals), grows back what grows back
## when they eat, and does their Fed Effects. Off for bait.
@export var nourishing: bool = true
## Hurts whoever eats it, before defence and resistance.
@export_range(0, 999, 1, "or_greater") var eaten_damage: int = 0
@export var eaten_damage_type: Damage.Type = Damage.Type.POISON
@export var eaten_condition: ConditionDefinition
## Added to their stagger bar, if they have one.
@export_range(0.0, 500.0, 1.0, "or_greater") var eaten_stagger: float = 0.0
## A part of theirs it breaks from the inside, by name ("Belly Hole").
@export var eaten_breaks: String = ""

@export_group("Hack")
## Has to be hacked to be Used (Hacking) - by somebody who can hack. Failing,
## with Sets Off, it goes off on the party instead (Backfire Hits).
@export var hack: HackDefinition
@export var backfire_hits: HazardDefinition.Hits = HazardDefinition.Hits.THE_PARTY

@export_group("Set off")
## Into the log: "The bell tolls."
@export var set_off_line: String = ""
## Added to the stagger bar of every boss on the field.
@export_range(0.0, 500.0, 1.0, "or_greater") var stagger: float = 0.0
## Tiles out from it, as a diamond. 0 is no blast.
@export_range(0, 10, 1) var blast_radius: int = 0
## Before defence and resistance, the way an item's power is.
@export_range(0, 999, 1, "or_greater") var blast_damage: int = 0
@export var blast_damage_type: Damage.Type = Damage.Type.PHYSICAL
@export var blast_condition: ConditionDefinition
@export var blast_hits: HazardDefinition.Hits = HazardDefinition.Hits.EVERYONE
