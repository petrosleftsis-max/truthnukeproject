extends Resource
class_name SpawnDefinition
## One combatant placed on the map at the start of an encounter. A list of
## these is what an EncounterDefinition is mostly made of.


## Key into CombatantDatabase.combatants - "enfina", "ranger", "priest" and so
## on. The same key can appear more than once in an encounter; give each one a
## different display_name so they can be told apart.
@export var combatant_key: String = ""
@export_enum("Players", "Enemies") var side = 0
## Starting tile, in grid coordinates (not pixels).
@export var position: Vector2i = Vector2i.ZERO
## Optional name overriding the CombatantDefinition's own - this is what
## "Goblin 1" / "Goblin 2" / "Goblin 3" are. Leave empty to use the
## definition's own name.
@export var display_name: String = ""
