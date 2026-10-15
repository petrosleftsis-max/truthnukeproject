class_name Immunity
## What a combatant can be made immune to, besides conditions
## (CombatantDefinition.immune_to_conditions) and damage (a resistance of 100):
## the things done to them that are not a condition. Anybody can have any of
## them - a boss, or a golem nobody can shove.
##
## Append new ones at the end: the list is stored by number in every file that
## uses it.

enum Kind {
	SHOVED,            ## Pushed or pulled by somebody's skill.
	TELEPORTED,        ## Sent somewhere else by somebody's teleport.
	STOLEN_FROM,       ## Nothing can be lifted from their pockets.
	WEAKENED,          ## Nobody can lower their stats or their resistances.
	LINGERING_WOUNDS,  ## No damage over time from a lingering wound.
	STUDIED,           ## Study learns nothing about them.
	GROUNDED,          ## Nobody else can change how they get about.
	BUFFS_REMOVED,     ## A dispel takes nothing good off them.
	READ,              ## Intuition reads nothing of what they mean to do.
	BREAKING,          ## Their nerve never breaks: they never flee or surrender.
	TAKEN_ALIVE,       ## A blow meant to knock them out kills them all the same.
	SWAYED,            ## Intimidate, Persuade and Deceive find nothing to work on.
	THROWN,            ## Nobody picks them up and throws them.
	CLIMBED,           ## Nobody climbs onto them.
}

## As the log and the character sheet say them: "immune to being shoved".
const NAMES := {
	Kind.SHOVED: "being shoved",
	Kind.TELEPORTED: "being teleported",
	Kind.STOLEN_FROM: "being stolen from",
	Kind.WEAKENED: "being weakened",
	Kind.LINGERING_WOUNDS: "lingering wounds",
	Kind.STUDIED: "being studied",
	Kind.GROUNDED: "having their movement changed",
	Kind.BUFFS_REMOVED: "having their boons dispelled",
	Kind.READ: "having their intent read",
	Kind.BREAKING: "breaking",
	Kind.TAKEN_ALIVE: "being taken alive",
	Kind.SWAYED: "being talked round",
	Kind.THROWN: "being thrown",
	Kind.CLIMBED: "being climbed",
}


static func name_of(kind: int) -> String:
	return NAMES.get(kind, "that")
