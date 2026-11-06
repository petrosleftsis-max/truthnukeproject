extends Node
## Autoload. Every skill in the game: each SkillDefinition in res://data/skills/,
## keyed by its file name - fire_blast.tres is "fire_blast". Adding a skill is
## saving one there; there is no list to add it to (see DataFolder).
##
## Items are in here too, put there by ItemDatabase.

## First, so it holds for all that follows. The designer's sounds are kept off GitHub, so a copy of the
## project may not have them: a move whose sound is missing should load silent, not fail to load.
var _missing_sounds_are_fine := _carry_on_without_them()
var skills: Dictionary = DataFolder.skills()


func _carry_on_without_them() -> bool:
	ResourceLoader.set_abort_on_missing_resources(false)
	return true
