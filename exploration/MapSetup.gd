@tool
extends Node
class_name MapSetup
## How an exploration map starts: who is walking it, how far along they are,
## and what is playing.
##
## Drop one into a map scene, the same way a map carries its EntryPoint. The map
## is the thing that knows its own opening: the crossroads is Cyrus alone at the
## start of everything, the laboratory is the whole party mid-way through, the
## church is Alithia by herself much later, and each of them sounds different.
##
## Every field is optional, and each is ignored when left empty - a map that
## only wants to set its music says nothing about the party, and keeps whatever
## roster walked in.


@export_group("Party")
## The party, in marching order - the first one leads and is the one you steer.
## Keys index CombatantDatabase, the same way encounter spawns do.
##
## Left empty, whoever is already travelling carries on, which is what running a
## map straight from the editor needs.
@export var members: Array[String] = []

## How far along they are here, 1 to 3. Decides the health they walk around
## with, and the attributes, gates and level the character sheet shows.
##
## Battles are not covered by this: an encounter's spawns carry their own
## levels, so a fight started from this map fields whatever that encounter
## says. This is who the party is on the map itself.
@export_range(1, 3) var level: int = 1

@export_group("Sound")
## What plays while the party is here. Named rather than a path - the file's own
## name without its extension, so "Scott Buckley - Filaments" finds
## audio/music/Scott Buckley - Filaments.mp3. These are the same names dialogue
## uses in `do Music.play(...)`.
##
## Left empty means "leave the music alone", exactly as an encounter's does, so
## a map with nothing set keeps whatever was already playing rather than
## dropping into silence. Arriving on a map already playing its track does not
## restart it.
@export var music: String = ""

## Whether the party arrives carrying nothing, whatever their database entry
## says they start with. For a map that opens before the story has handed
## anybody anything.
@export var empty_handed: bool = false

@export_group("Kit")
## One of each of these for every member of the party, handed out on arrival.
##
## Added to what they are already carrying, so a map that wants a party to hold
## exactly this and nothing else sets Empty Handed as well - the two compose,
## rather than this quietly meaning "and throw the rest away".
@export var everyone_carries: Array[String] = []

## Extra items for particular people, keyed by combatant key, e.g.
## {"cyrus": ["bomb"]}. Handed out on top of Everyone Carries.
@export var also_carries: Dictionary = {}


## What `key` should be given on arrival - the common kit plus anything named
## for them in particular.
func kit_for(key: String) -> Array:
	var kit: Array = []
	kit.append_array(everyone_carries)
	var theirs = also_carries.get(key, [])
	if theirs is Array:
		kit.append_array(theirs)
	elif theirs is String and theirs != "":
		# One item written without the brackets, which is the easy mistake to
		# make in the inspector and harmless to allow.
		kit.append(theirs)
	return kit


## Whether this map hands anything out at all.
func hands_kit_out() -> bool:
	return not everyone_carries.is_empty() or not also_carries.is_empty()


## Whether a party is actually named here. An empty list is "not set" rather
## than "nobody", because a map that meant nobody would have no exploration.
func is_set() -> bool:
	return not members.is_empty()
