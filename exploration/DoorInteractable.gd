@tool
extends Interactable
class_name DoorInteractable
## A way through to another exploration map.
##
## Set the target map and, optionally, the name of an EntryPoint inside it to
## arrive at. Leave the entry name empty to arrive at that map's default entry
## point (the first one it has).


@export_file("*.tscn") var target_map: String = ""
## The EntryPoint node in the target map to arrive at, by its entry_name.
@export var target_entry: String = ""


func interact(scene: Node):
	if target_map == "":
		push_warning("DoorInteractable '%s' has no target map." % name)
		return
	Campaign.travel_to_map(target_map, target_entry)
	scene.reload_map()
