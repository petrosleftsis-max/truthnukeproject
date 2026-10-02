extends Node
class_name StealthObjective
## Something to do on a stealth map besides getting out: listed under the
## stealth bar, ticked off when done, and on the card at the way out. None of
## them stop anybody leaving - they are for doing it well.

## What counts. Stored by number, so a new one goes on the end.
enum Kind {
	FLAG,            ## Done once Flag is set: a conversation overheard (GuardChat), something planted (PlantSpot), anything else.
	CARRY_ITEM,      ## Done once the party has had Item Key: something stolen - lifted from a pocket, or taken from where it lay.
	NO_TAKEDOWNS,    ## Nobody knocked out, by hand or by poison. Lost the moment somebody is.
	NEVER_ALARMED,   ## The map never once Alarmed.
	NOBODY_HARMED,   ## Nobody knocked out and nobody poisoned.
	CALM_AT_THE_END, ## The map Calm on the way out - settled by a word or two (E beside a guard), say.
}
@export var kind: Kind = Kind.FLAG
## What it says on the list.
@export var description: String = ""
@export var flag: String = ""
@export var item_key: String = ""
