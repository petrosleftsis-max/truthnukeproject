@tool
extends Node
class_name PartySetup
## Who is walking this map, and how far along they are.
##
## Drop one into an exploration map scene, the same way a map carries its
## EntryPoint. The map is the thing that knows its own cast: the crossroads is
## Cyrus alone at the start of everything, the laboratory is the whole party
## mid-way through, the church is Alithia by herself much later. Without this
## every map opened with whoever the exploration scene's Starting Party listed,
## which could only ever be right for one of them.
##
## Optional. A map with no PartySetup falls back to that Starting Party list,
## which is what running a map straight from the editor does.


## The party, in marching order - the first one leads and is the one you steer.
## Keys index CombatantDatabase, the same way encounter spawns do.
@export var members: Array[String] = []

## How far along they are here, 1 to 3. Decides the health they walk around
## with, and the attributes, gates and level the character sheet shows.
##
## Battles are not covered by this: an encounter's spawns carry their own
## levels, so a fight started from this map fields whatever that encounter
## says. This is who the party is on the map itself.
@export_range(1, 3) var level: int = 1


## Whether this actually says anything. An empty list is treated as "not set"
## rather than as "nobody", because a map that meant nobody would have no
## exploration to do.
func is_set() -> bool:
	return not members.is_empty()
