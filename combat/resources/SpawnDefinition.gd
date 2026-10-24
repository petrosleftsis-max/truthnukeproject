@tool
@icon("res://art/editor_icons/spawn.svg")
extends Resource
class_name SpawnDefinition
## One combatant placed on the map at the start of an encounter. A list of
## these is what an EncounterDefinition is mostly made of.
##
## Marked @tool only so the inspector can offer Starting Items as a dropdown of
## the items there are (see _validate_property).


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
## 1 to 64. A combatant's level decides every attribute they have (see
## Stats.stats_for_level) and which of their skills are unlocked, so this is
## the one dial that says how developed they are in this particular fight.
##
## Set per spawn rather than per character on purpose: the same Cyrus can be
## brought into an early encounter at level 1 and a later one at level 15, and
## an enemy can be scaled up without a second database entry.
@export_range(1, 64) var level: int = 1
## The path they are on, by key (SubclassDefinition) - from level 24, and only
## one of their own. Empty for none. In the story the party's own choices are
## used instead; this is for a fight opened from Battle Select.
@export var subclass: String = ""
## What this combatant's attacks start from before any stat is added - the
## weapon in their hands, until equipment exists to put one there. Per spawn so
## the same character can be better armed in one encounter than another.
@export_range(0, 100) var weapon_base: int = 6
## How much incoming damage this combatant soaks. Damage is multiplied by
## 40/(40 + this), so 40 halves a hit and 120 quarters it. Per spawn for the
## same reason weapon_base is: it is the other half of how tough somebody is in
## this fight specifically.
##
## 0, the default, is their own Defense at this level (CombatantDefinition
## defense_at) - for an enemy, what docs/enemy_progression.csv says for its kind.
## Set it only to make this one tougher or frailer than its kind.
@export_range(0, 100) var defense: int = 0
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
##
## On an enemy it is what they have to hand in this fight, and use: a potion
## drunk when badly hurt, a bomb thrown like any skill. Only as many as their
## Pocket Size they could use in a fight count (four, for most); it is also what
## a Steal takes off them. The rest - and anything of no use in a fight, a
## spellbook say - is carried, for whoever loots them once they are down. A
## guard caught on a stealth map fights with whatever is still in his pockets -
## anything lifted from them is not here.
@export var starting_items: Array[String] = []
## What they wear, by key (EquipmentDefinition): a weapon's base, an armour's
## defence and a charm's passive take the place of what is set above. Theirs
## to fight with, and the party's to loot off them once they are down.
@export var equipment: Array[String] = []

@export_group("Arriving late")
## The round an enemy joins the fight on - 1, the default, is from the start.
## A later round brings them in at the top of it, on this tile or the nearest
## free one beside it: reinforcements, or a guard on a stealth map who was too
## far off to be there when the shouting started. Enemies only; the party's
## tiles are filled from the roster before the first turn.
@export_range(1, 20) var arrives_on_round: int = 1
## Arrives once this many of the enemy side have fallen - died, fled or given
## up. 0: no waiting on it.
@export_range(0, 20) var arrives_after_deaths: int = 0
## Arrives once this happens in the fight (Combat.cue), by name:
##   "phase:<phase name>" - a boss's phase begins ("phase:Gorge")
##   "broke:<part name>" - a part breaks ("broke:Jaws")
##   "swallowed" - somebody is swallowed; "digested" - somebody dies inside
##   "ate:<what>" - something eats something ("ate:Carrion Heap")
##   "used:<object>" - an object on the map is Used or set off
##   "staggered:<name>" - a boss is staggered
##   "fell:<name>" - somebody falls, by the name they fight under
## Empty: no waiting on it. Whatever is set has all to have happened: round 3
## and "broke:Jaws" is the Jaws broken, and not before round 3. Late arrivals
## come in at the end of the turn they are due in.
@export var arrives_on_cue: String = ""

@export_group("Opening")
## Caught off guard: loses their first turn. A guard ambushed on a stealth map
## before he knew anybody was there.
@export var surprised: bool = false
## Starts the fight invisible (see Invisibility in Combat.gd): the other side
## can't see them until they do something to it. A party member still invisible
## on the stealth map they were caught on; or anybody, written in. With nobody
## else on their side in sight, the first of them is left visible.
@export var invisible: bool = false


## Whether they come later than the start of the fight (Arriving late).
func arrives_late() -> bool:
	return arrives_on_round > 1 or arrives_after_deaths > 0 or arrives_on_cue != ""


## Every item there is, by key, read straight from data/items rather than
## through the ItemDatabase autoload, which an editor inspector cannot count on.
## Read once per editor session: an item added since shows after a reload.
static var _item_keys: Array = []

static func item_keys() -> Array:
	if _item_keys.is_empty():
		_item_keys = DataFolder.items().keys()
	return _item_keys


## The hint that makes an Array[String] of item keys a dropdown per entry.
static func item_list_hint() -> String:
	return "%d/%d:%s" % [TYPE_STRING, PROPERTY_HINT_ENUM, ",".join(item_keys())]


## Every equipment key there is (data/equipment), for Equipment's dropdown.
static func equipment_keys() -> Array:
	return DataFolder.equipment().keys()


## The hint that makes an Array[String] of equipment keys a dropdown per entry.
static func equipment_list_hint() -> String:
	return "%d/%d:%s" % [TYPE_STRING, PROPERTY_HINT_ENUM, ",".join(equipment_keys())]


## Starting Items as a dropdown of the items there are, and Subclass of the
## paths there are (a blank first, for none), so an encounter cannot hand
## anybody an item or a path that does not exist.
func _validate_property(property: Dictionary):
	if not Engine.is_editor_hint():
		return
	if property.name == "starting_items":
		property.hint = PROPERTY_HINT_TYPE_STRING
		property.hint_string = item_list_hint()
	elif property.name == "equipment":
		property.hint = PROPERTY_HINT_TYPE_STRING
		property.hint_string = equipment_list_hint()
	elif property.name == "subclass":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = subclass_hint()


## The hint that makes a String a dropdown of every path, blank first.
static func subclass_hint() -> String:
	return "," + ",".join(SubclassDefinition.all().keys())
