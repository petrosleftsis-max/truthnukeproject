extends Node
## Autoload. Every consumable in the game, keyed the way skills are.
##
## Items are SkillDefinitions (see ItemDefinition), and on load they are also
## registered in SkillDatabase.skills. That is not a shortcut: it means every
## place that already turns a key into something usable - aiming, previewing,
## the damage numbers, the turn queue, the character sheet - handles an item
## without a single special case. What makes an item an item is that it lives
## in somebody's bag and goes away when used, and that is the inventory's
## business rather than this lookup's.
##
## Loaded after SkillDatabase (see the autoload order in project.godot), so
## there is something to register into.

@export var items: Dictionary


func _ready():
	for key in items:
		var item: ItemDefinition = items[key]
		if item == null:
			push_error("Item '%s' has no resource." % key)
			continue
		if SkillDatabase.skills.has(key):
			push_error("Item '%s' has the same key as a skill. Keys are shared, so one would shadow the other." % key)
			continue
		SkillDatabase.skills[key] = item


## Whether this key names a consumable rather than a skill.
func is_item(key: String) -> bool:
	return items.has(key)


## The item for a key, or null if it names a skill (or nothing).
func item(key: String) -> ItemDefinition:
	return items.get(key)
