@icon("res://art/editor_icons/dungeon_stage.svg")
extends Resource
class_name DungeonStage
## One step of a DungeonDefinition: a map to walk until its fight, or a fight
## gone straight into.

## The map the party walks until they reach the fight. Leave it empty to go
## straight into the fight instead.
@export_file("*.tscn") var map: String = ""
## The fight this step is. On a map, it is fought in place of the one the map
## itself would start (see Replaces) - so the map is the story's own, and only
## the fight at the end of it is the dungeon's.
@export var encounter: EncounterDefinition
## The fight the map starts on its own, which `encounter` is fought instead of.
## Leave it empty to stand in for whatever fight the map starts.
@export var replaces: EncounterDefinition
