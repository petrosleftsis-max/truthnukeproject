@icon("res://art/editor_icons/faction.svg")
extends Resource
class_name FactionDefinition
## A side in the story that enemies belong to - each enemy's Faction
## (CombatantDefinition.faction) names one. Learning about a faction is a clue
## (ClueDefinition.reveals_factions): from then on, every one of them the party
## fights has their sheet open from the start of the fight, as Study would leave
## it, and is hit harder for what the party knows about them.
##
## Saved in res://data/factions/, keyed by file name (see DataFolder).

@export var name: String = ""
## Who they are, in the words a sheet or the journal can show.
@export_multiline var description: String = ""
## Optional.
@export var icon: Texture2D
## How much harder the party hits a member once the faction is known: 0.15 is
## a sixth again - a seventh of the defence they would otherwise have counted
## on, near enough. Every hit worked out by Combat.skill_damage, so what the
## aim prompt promises is what lands.
@export_range(0.0, 1.0, 0.01) var known_damage_bonus: float = 0.15


static var _all: Dictionary = {}
static var _read := false


## Every faction there is, by key.
static func all() -> Dictionary:
	if not _read:
		_read = true
		_all = DataFolder.factions()
	return _all


## The faction called `key`, or null.
static func named(key: String) -> FactionDefinition:
	return all().get(key) if key != "" else null
