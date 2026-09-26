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
## "Striker 1" / "Striker 2" / "Caster" are. Leave empty to use the
## definition's own name.
@export var display_name: String = ""

@export_group("Level and gear")
## 1 to 3. A combatant's level decides every attribute they have (see
## Stats.stats_for_level) and which of their skills are unlocked, so this is
## the one dial that says how developed they are in this particular fight.
##
## Set per spawn rather than per character on purpose: the same Cyrus can be
## brought into an early encounter at level 1 and a later one at level 3, and
## an enemy can be scaled up without a second database entry.
@export_range(1, 3) var level: int = 1
## What this combatant's attacks start from before any stat is added - the
## weapon in their hands, until equipment exists to put one there. Per spawn so
## the same character can be better armed in one encounter than another.
@export_range(0, 100) var weapon_base: int = 6
## How much incoming damage this combatant soaks. Damage is multiplied by
## 40/(40 + this), so 40 halves a hit and 120 quarters it. Per spawn for the
## same reason weapon_base is: it is the other half of how tough somebody is in
## this fight specifically.
@export_range(1, 100) var defense: int = 10
## What this character has in their bag for this fight, by item key -
## "cure_potion", "bomb", "medicine" and so on, from ItemDatabase.
##
## Per spawn, for the same reason the level is: the same Cyrus can walk into
## one encounter with a full satchel and the next with nothing. Only the first
## four come to the fight itself (Campaign.COMBAT_SLOTS); the rest ride along
## to be swapped in between battles.
##
## This is what a battle opened from Arena Mode hands out, and an empty list
## means empty-handed - a character's own starting_items are their kit for a
## story run, not a standing supply for every fight in the arena. A battle
## walked into from a map ignores this and keeps whatever the party carried in.
@export var starting_items: Array[String] = []
