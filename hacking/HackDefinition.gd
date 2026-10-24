@icon("res://art/editor_icons/hack.svg")
extends Resource
class_name HackDefinition
## Something Prometheus can hack, and how: which of the three minigames, how
## hard, how many tries and what each retry costs, whether there is a clock,
## what the gates can buy, and what failing does. Saved in res://data/hacks/
## (a conversation starts one by its file name: do Hacking.start("archive_ward"))
## or set straight onto the thing being hacked: an Interactable's or a
## Hotspot's Hack, a BattleObjectDefinition's, or a declared skill's.
##
## Who can hack is a passive's Can Hack (Prometheus's Prying Mind). How many
## tries they get is Tries at an Intellect of Hacking.INTELLECT_PIVOT, more with
## more and fewer with less - and each retry costs less in the same proportion,
## so twice the tries is half the cost a try.

enum Kind {
	REWRITE,     ## Rewrite the Rule: change the lines of a spell's sheet to what they have to be, within a budget of edits.
	INFILTRATE,  ## Node Infiltration: cross a graph of nodes to the core without a sentinel catching him.
	RESONANCE,   ## Tuning the Resonance: turn the dials until the wave matches, then lock it.
}

enum Look {
	RUNES,     ## Magic: a page of runes.
	TERMINAL,  ## A machine: a screen of text.
}

enum RetryCost {
	STRAIN,  ## Health off the hacker - never the last point of it.
	ALERT,   ## The stealth map's alert, raised. Nothing anywhere else.
	NOTHING,
}

## On top of the screen: "The Archive Ward".
@export var title: String = ""
## What he is doing, under it.
@export_multiline var description: String = ""
@export var kind: Kind = Kind.REWRITE
@export var look: Look = Look.RUNES

@export_group("Tries")
## Tries at an Intellect of Hacking.INTELLECT_PIVOT; never fewer than one.
@export_range(1, 10, 1) var tries: int = 3
@export var retry_cost: RetryCost = RetryCost.STRAIN
## Health for Strain; points of alert out of a hundred for Alert. At the
## pivot's Intellect - less with more.
@export_range(0, 100, 1) var retry_cost_amount: int = 8

@export_group("Time")
## Seconds each try has. 0 for no clock - for a barricaded room where nothing
## is coming.
@export_range(0, 300, 1) var time_limit: int = 0
## On a stealth map, the guards carry on while he works. Off, everything waits.
@export var world_keeps_moving: bool = false

@export_group("Gates")
## The gate a hint costs (or any deeper one). None for no hints.
@export_enum("None", "Gates of World", "Gates of Hermes", "Gates of Pandora", "Gates of Charon", "Gates of Tartarus", "Gates of Nemesis", "Gates of Sophia", "Gates of Ogdoad", "Gates of Gnosis", "Gates of Yaldabaoth") var hint_gate: int = 1
## The gate making it simpler costs (or any deeper one), once a hack.
@export_enum("None", "Gates of World", "Gates of Hermes", "Gates of Pandora", "Gates of Charon", "Gates of Tartarus", "Gates of Nemesis", "Gates of Sophia", "Gates of Ogdoad", "Gates of Gnosis", "Gates of Yaldabaoth") var simplify_gate: int = 2

@export_group("When it fails")
## Out of tries - or walking away after a try has failed.
## The stealth map's alert goes up a level.
@export var raises_alert: bool = false
## The thing goes off on him: a map object's blast, a declared skill landing
## early; on a map, the flag hack_set_off:<id> for a conversation to act on.
@export var sets_off: bool = false
## It can never be tried again.
@export var locks_for_good: bool = false
## Said when it fails.
@export var failure_line: String = ""
## In a fight: added to the stagger bar of a boss whose spell is hacked apart.
@export_range(0.0, 200.0, 1.0) var stagger_on_success: float = 0.0

@export_group("Rewrite the Rule")
@export var lines: Array[HackLine] = []
## Edits there are to spend: each step a line moves from where it started costs
## its Cost, and moving it back gives them back.
@export_range(1, 60, 1) var edits: int = 8
## The watched lines' sum has to end where it started.
@export var balanced: bool = false
## Every step taken costs its edits, back again included - only Start Over
## gives them back - so the order of the steps is the puzzle. Always so on a
## sheet whose lines push each other (HackLine.pushes). Off, a line costs only
## how far it ends from where it started.
@export var every_step_costs: bool = false

@export_group("Node Infiltration")
@export_range(3, 9, 1) var width: int = 5
@export_range(2, 6, 1) var height: int = 4
@export_range(0, 4, 1) var sentinels: int = 1
## Moves beyond the fewest the way through needs.
@export_range(0, 10, 1) var spare_moves: int = 2
## The share of links between neighbouring nodes cut away.
@export_range(0.0, 0.6, 0.05) var cut_links: float = 0.25

@export_group("Tuning the Resonance")
@export_range(1, 3, 1) var dials: int = 3
## How near each dial has to be to its mark, out of a hundred.
@export_range(1, 30, 1) var tolerance: int = 6


## The kind, as the screen names it.
func kind_name() -> String:
	return ["Rewrite the Rule", "Node Infiltration", "Tuning the Resonance"][kind]
