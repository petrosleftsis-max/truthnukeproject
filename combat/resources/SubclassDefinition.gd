@icon("res://art/editor_icons/subclass.svg")
extends Resource
class_name SubclassDefinition
## A path a character takes once they reach level 5 (Stats.SUBCLASS_LEVEL):
## one of their three, chosen once, for good. Cyrus's Swashbuckler, Gunner and
## Bombardier are three of these. Whose paths are whose is the character's to
## say - their Subclasses list (CombatantDefinition.subclasses), in order.
##
## A path teaches skills and gives passives on top of the character's own. Each
## skill is learned at its own Required Level and each passive works from its
## own, so a path can hand one thing out at 5 and another at 12 without anything
## here saying when.
##
## Saved in res://data/subclasses/, keyed by file name like everything else
## there (see DataFolder): swashbuckler.tres is "swashbuckler".

@export var name: String = ""
## What the path is, in the words the choice shows.
@export_multiline var description: String = ""
## Optional. Shown on the choice and the character sheet.
@export var icon: Texture2D
## The skills it teaches, by key - each learned at its own Required Level.
@export var skills: Array[String] = []
## What it does without being asked - each working from its own Required Level.
@export var passives: Array[PassiveDefinition] = []


static var _all: Dictionary = {}
static var _read := false


## Every path there is, by key.
static func all() -> Dictionary:
	if not _read:
		_read = true
		_all = DataFolder.subclasses()
	return _all


## The path called `key`, or null.
static func named(key: String) -> SubclassDefinition:
	return all().get(key)


## The keys of `character_key`'s paths, in the order their file lists them,
## leaving out any that do not exist.
static func for_character(character_key: String) -> Array:
	var definition: CombatantDefinition = CombatantDatabase.combatants.get(character_key)
	if definition == null:
		return []
	return Array(definition.subclasses).filter(func(key): return all().has(key))
