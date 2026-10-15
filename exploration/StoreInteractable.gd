@tool
@icon("res://art/editor_icons/store.svg")
extends Interactable
class_name StoreInteractable
## A counter, a stall, a pedlar's pack on a map: walk up, press E, and the
## store opens (StoreDefinition, Campaign.open_store).

## Which store, by key - a file in res://data/stores/.
@export var store: String = ""


func _init():
	prompt = "Browse"


func interact(_scene: Node):
	if store == "":
		push_warning("StoreInteractable '%s' has no store set." % name)
		return
	Campaign.open_store(store)
