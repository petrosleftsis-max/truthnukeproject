@icon("res://art/editor_icons/store.svg")
extends Resource
class_name StoreDefinition
## Somewhere to spend gold (Campaign.gold): what it sells, and whether it buys
## back. Opened by a StoreInteractable on a map, a conversation
## (`do Campaign.open_store("travelling_merchant")`), or a dungeon's rest
## (DungeonDefinition.store).
##
## It never runs out. Prices are the goods' own - ItemDefinition.price and
## EquipmentDefinition.price - so one item costs the same everywhere.
##
## Saved in res://data/stores/, keyed by file name (see DataFolder).

@export var name: String = ""
## Said at the top of the store.
@export_multiline var greeting: String = ""
## What it sells, by key - items (data/items) and gear (data/equipment) alike.
@export var stock: Array[String] = []
## Whether the party can sell to it, for Sell Rate of the price.
@export var buys_back: bool = true
## How much of something's price selling it gets back.
@export_range(0.0, 1.0, 0.05) var sell_rate: float = 0.5


static var _all: Dictionary = {}
static var _read := false


## Every store there is, by key.
static func all() -> Dictionary:
	if not _read:
		_read = true
		_all = DataFolder.stores()
	return _all


## The store called `key`, or null.
static func named(key: String) -> StoreDefinition:
	return all().get(key) if key != "" else null
