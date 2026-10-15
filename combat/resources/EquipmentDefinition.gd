@tool
@icon("res://art/editor_icons/equipment.svg")
extends Resource
class_name EquipmentDefinition
## Something worn or wielded: a weapon, a piece of armour or a charm, one of
## each per character (Campaign.equip). Kept apart from the items in the bags -
## those are spent, this is kept.
##
## In the story's fights what is equipped stands in for the fight's own numbers
## (Combat.wear_gear): a weapon's Weapon Base for the tile's, armour's Defense
## for the tile's, and a charm adds its passive. An empty slot leaves the
## fight's own number as it was, so nothing changes until gear is handed out.
##
## Saved in res://data/equipment/, keyed by file name (see DataFolder). Marked
## @tool only so the inspector shows the fields of the slot chosen.

enum Slot { WEAPON, ARMOUR, CHARM }
## Light and heavy are kinds of armour to tell apart; for now they wear the same.
enum ArmourCategory { LIGHT, HEAVY }

## The keys the slots are stored under (Campaign.equipped), in Slot order.
const SLOT_KEYS := ["weapon", "armour", "charm"]
const SLOT_NAMES := ["Weapon", "Armour", "Charm"]
const CATEGORY_NAMES := ["Light", "Heavy"]

@export var name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var slot: Slot = Slot.WEAPON : set = _set_slot
## Who can use it, by key - empty for anybody.
@export var for_characters: Array[String] = []
## What it costs in a store (StoreDefinition). Selling gets half back.
@export_range(0, 9999) var price: int = 0

@export_group("Weapon")
## Used when slot is WEAPON: what every attack starts from before any stat, in
## place of the fight's own (Stats.WEAPON_BASE is the bare-handed 6).
@export_range(0, 100) var weapon_base: int = 6

@export_group("Armour")
## Used when slot is ARMOUR: how much damage the wearer soaks, in place of the
## fight's own. Damage is multiplied by 40/(40 + this).
@export_range(0, 100) var defense: int = 10
## Used when slot is ARMOUR.
@export var armour_category: ArmourCategory = ArmourCategory.LIGHT

@export_group("Charm")
## Used when slot is CHARM: what wearing it does, as a passive - its Required
## Level and Active When hold here too.
@export var passive: PassiveDefinition


static var _all: Dictionary = {}
static var _read := false


## Every piece there is, by key.
static func all() -> Dictionary:
	if not _read:
		_read = true
		_all = DataFolder.equipment()
	return _all


## The piece called `key`, or null.
static func named(key: String) -> EquipmentDefinition:
	return all().get(key) if key != "" else null


## The key its slot is stored under: "weapon", "armour" or "charm".
func slot_key() -> String:
	return SLOT_KEYS[slot]


## Whether `character_key` can use it.
func fits(character_key: String) -> bool:
	return for_characters.is_empty() or for_characters.has(character_key)


## What it does, in a line - for a tooltip, a store, the sheet.
func summary() -> String:
	match slot:
		Slot.WEAPON:
			return "Weapon - weapon base %d" % weapon_base
		Slot.ARMOUR:
			return "%s armour - defence %d" % [CATEGORY_NAMES[armour_category], defense]
	return "Charm - %s" % (passive.name if passive != null else "does nothing yet")


func _set_slot(value: Slot):
	slot = value
	notify_property_list_changed()


const _FIELDS_BY_SLOT := {
	Slot.WEAPON: ["weapon_base"],
	Slot.ARMOUR: ["defense", "armour_category"],
	Slot.CHARM: ["passive"],
}


## Shows only the fields the chosen slot uses.
func _validate_property(property: Dictionary) -> void:
	var owned := false
	for fields in _FIELDS_BY_SLOT.values():
		if property.name in fields:
			owned = true
	if owned and not property.name in _FIELDS_BY_SLOT[slot]:
		property.usage = PROPERTY_USAGE_STORAGE
