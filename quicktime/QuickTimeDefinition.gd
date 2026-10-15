@icon("res://art/editor_icons/quick_time.svg")
extends Resource
class_name QuickTimeDefinition
## A quick time event: a press against the clock, over whatever is going on.
## Played by the QuickTime autoload, which answers whether it was done in time.
##
## In a fight it hangs off a skill (SkillDefinition.quick_time): for the one
## using it - a better throw - or for the party when it is used on them - a
## blow braced against. In a conversation it is started by key, from
## res://data/quick_times/ (file name = key):
##
##     do QuickTime.start("dodge_the_bolt")
##     if QuickTime.passed
##
## The four buttons are the actions qte_north, qte_south, qte_east and qte_west:
## the arrow keys, and the pad's four face buttons.

enum Kind {
	PRESS,     ## One button, shown, pressed before the time runs out. Any other is a miss.
	SEQUENCE,  ## Count buttons in a row, in order. One wrong and it is over.
	MASH,      ## One button, pressed Count times before the time runs out.
	TIMING,    ## A marker sweeps back and forth: press as it crosses the zone.
}

@export var kind: Kind = Kind.PRESS
## What it says over the buttons: "Brace!", "Dodge!".
@export var prompt: String = ""
## Seconds to do it in. For Timing, how long the marker sweeps before it is
## too late.
@export_range(0.3, 10.0, 0.1) var time: float = 1.5
## Sequence: buttons in the row. Mash: presses needed.
@export_range(1, 30, 1) var count: int = 4
@export_group("Timing")
## How wide the zone to stop in is, out of the whole bar.
@export_range(0.05, 0.6, 0.01) var zone: float = 0.18
## How many times a second the marker crosses the bar.
@export_range(0.2, 4.0, 0.05) var speed: float = 1.2
