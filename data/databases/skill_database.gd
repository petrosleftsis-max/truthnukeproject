extends Node
## Autoload. Every skill in the game: each SkillDefinition in res://data/skills/,
## keyed by its file name - fire_blast.tres is "fire_blast". Adding a skill is
## saving one there; there is no list to add it to (see DataFolder).
##
## Items are in here too, put there by ItemDatabase.

var skills: Dictionary = DataFolder.skills()
