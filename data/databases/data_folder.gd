extends RefCounted
class_name DataFolder
## Reads a folder of game data: every resource of one kind in it, keyed by its
## file name - fire_blast.tres is "fire_blast". It is how the databases are
## filled, so adding a skill, an item or a character is saving its file in the
## right folder and nothing more: there is no list anywhere to add it to.
##
## The autoloads (SkillDatabase, ItemDatabase, CombatantDatabase) are built from
## this, and an editor tool, which cannot count on the autoloads being there,
## reads it directly - SpawnMarker does.

const SKILLS := "res://data/skills/"
const ITEMS := "res://data/items/"
## The party.
const CHARACTERS := "res://data/characters/"
## Everybody they fight.
const ENEMIES := "res://data/enemies/"


## Every resource in `folder` that is a `kind` (a class: SkillDefinition, ...),
## by file name, in alphabetical order. Anything else there is warned about and
## left out.
static func read(folder: String, kind) -> Dictionary:
	var found := {}
	if not DirAccess.dir_exists_absolute(folder):
		push_warning("DataFolder: there is no %s." % folder)
		return found
	# list_directory knows an exported game's files by their original names; a
	# plain DirAccess listing there sees "x.tres.remap".
	var names := Array(ResourceLoader.list_directory(folder))
	names.sort()
	for file in names:
		if not (file.ends_with(".tres") or file.ends_with(".res")):
			continue
		var loaded = load(folder.path_join(file))
		if loaded == null or not is_instance_of(loaded, kind):
			push_warning("DataFolder: %s is not the kind of thing %s holds." % [folder.path_join(file), folder])
			continue
		found[file.get_basename()] = loaded
	return found


static func skills() -> Dictionary:
	return read(SKILLS, SkillDefinition)


static func items() -> Dictionary:
	return read(ITEMS, ItemDefinition)


## The party and everybody they fight, in one: a fight does not care which is
## which.
static func combatants() -> Dictionary:
	var everybody := read(CHARACTERS, CombatantDefinition)
	var enemies := read(ENEMIES, CombatantDefinition)
	for key in enemies:
		if everybody.has(key):
			push_warning("DataFolder: '%s' is both a character and an enemy; the character is kept." % key)
			continue
		everybody[key] = enemies[key]
	return everybody
