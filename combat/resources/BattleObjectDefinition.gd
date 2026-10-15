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
