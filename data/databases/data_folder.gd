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
## Bells, pillars and the like to place in a fight (BattleObjectDefinition).
const OBJECTS := "res://data/objects/"
const SUBCLASSES := "res://data/subclasses/"
const FACTIONS := "res://data/factions/"
const EQUIPMENT := "res://data/equipment/"
const STORES := "res://data/stores/"


## Every resource in `folder` that is a `kind` (a class: SkillDefinition, ...),
## by file name, in alphabetical order. Anything else there is warned about and
## left out.
##
## Its subfolders are read too, however deep - a folder of skills sorted into
## data/skills/enfina/, .../spells/ and so on - and a resource is still keyed by
## its file name alone, so a name has to be one of a kind across all of them:
## a second one is warned about and left out. The order stays alphabetical by
## key, whichever folder each is in.
static func read(folder: String, kind) -> Dictionary:
	var found := {}
	if not DirAccess.dir_exists_absolute(folder):
		push_warning("DataFolder: there is no %s." % folder)
		return found
	_read_into(found, folder, kind)
	var keys := found.keys()
	keys.sort()
	var ordered := {}
	for key: String in keys:
		ordered[key] = found[key]
	return ordered


static func _read_into(found: Dictionary, folder: String, kind):
	# list_directory knows an exported game's files by their original names; a
	# plain DirAccess listing there sees "x.tres.remap". A folder ends in "/".
	var names := Array(ResourceLoader.list_directory(folder))
	names.sort()
	for file: String in names:
		if file.ends_with("/"):
			_read_into(found, folder.path_join(file.trim_suffix("/")), kind)
			continue
		if not (file.ends_with(".tres") or file.ends_with(".res")):
			continue
		var path := folder.path_join(file)
		var loaded = load(path)
		if loaded == null or not is_instance_of(loaded, kind):
			push_warning("DataFolder: %s is not the kind of thing %s holds." % [path, folder])
			continue
		var key := file.get_basename()
		if found.has(key):
			push_warning("DataFolder: %s has the name of another (%s); the first is kept." % [path, found[key].resource_path])
			continue
		found[key] = loaded


static func skills() -> Dictionary:
	return read(SKILLS, SkillDefinition)


static func items() -> Dictionary:
	return read(ITEMS, ItemDefinition)


## The paths a character can take at level 24 - see SubclassDefinition.
static func subclasses() -> Dictionary:
	return read(SUBCLASSES, SubclassDefinition)


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
	# Things on the battlefield (BattleObjectDefinition), placed the same way.
	var objects := read(OBJECTS, CombatantDefinition)
	for key in objects:
		if everybody.has(key):
			push_warning("DataFolder: '%s' is both a combatant and an object; the combatant is kept." % key)
			continue
		everybody[key] = objects[key]
	return everybody


## The sides enemies belong to - see FactionDefinition.
static func factions() -> Dictionary:
	return read(FACTIONS, FactionDefinition)


## Weapons, armour and charms - see EquipmentDefinition.
static func equipment() -> Dictionary:
	return read(EQUIPMENT, EquipmentDefinition)


## Places that sell things - see StoreDefinition.
static func stores() -> Dictionary:
	return read(STORES, StoreDefinition)
