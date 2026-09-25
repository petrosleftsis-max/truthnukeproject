extends Resource
class_name PassiveDefinition
## A skill nobody presses. It is part of who somebody is: working all the time,
## or switching itself on when its moment comes, and never offered on the
## action panel because there is nothing there to choose.
##
## Kept apart from SkillDefinition rather than being a skill with a flag on it.
## Everything that walks a combatant's skill list - the three panels, the
## reactions, the AI hunting for something to swing - would otherwise have to
## be taught to step over it, and the first place that forgot would offer the
## player a button that does nothing. A combatant lists these under Passives
## instead, and the character sheet reads them out under a heading of their own.
##
## What one does is a switch below for each thing the rules know how to hand
## out. Combat only looks at the switches of a passive whose moment holds - see
## Combat.active_passives - so one waiting on its condition does nothing at all.


## When it is working.
##
## Stored by number, so a new one goes on the end. Put one in the middle and
## every passive already written with a later one quietly means something else.
enum ActiveWhen {
	ALWAYS,             ## From the first turn of a fight to the last.
	BELOW_HALF_HEALTH,  ## Only while they are down to half their health or less.
}

@export var name: String = ""
## What it does, in the words the character sheet shows. Written out in full on
## the sheet rather than left behind a tooltip, so say it plainly.
@export_multiline var description: String = ""
## Optional. The sheet names the passive either way.
@export var icon: Texture2D
@export var active_when: ActiveWhen = ActiveWhen.ALWAYS

@export_group("What it does")
## Casts without spending anything. Whatever they know they can use, however
## deep a gate the spell is cast through and however many gates they have of
## their own - which may be none. The Mimic's: its whole trick is doing what it
## just watched somebody else do, and without this it copies a spell and then
## cannot pay for it, which is a turn spent doing nothing at all.
@export var casts_without_gates: bool = false


## When it works, as the character sheet says it.
func describe_when() -> String:
	match active_when:
		ActiveWhen.BELOW_HALF_HEALTH:
			return "Active at half health or below"
	return "Always active"


## What its switches do, a line each, in the words the glossary prints. Kept
## beside the switches so a new one is described where it is added.
func describe_effects() -> Array:
	var lines := []
	if casts_without_gates:
		lines.append("Casts without opening a gate, however deep a gate the spell calls for.")
	return lines
