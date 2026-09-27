@tool
extends Interactable
class_name PictureInteractable
## Something on a map to take a closer look at: walk up, press E, and its
## point-and-click Picture opens over the map (see Pictures). The party waits
## where it stands until the pictures are closed again.

## The Picture scene to open.
@export_file("*.tscn") var picture: String = ""


func _init():
	prompt = "Look closer"


func interact(scene: Node):
	if picture == "":
		push_warning("PictureInteractable '%s' has no picture set." % name)
		return
	# Looked up rather than named: this is a tool script, and an editor that has
	# not reloaded since the autoload was added refuses it over the name.
	var viewer = get_node_or_null("/root/Pictures")
	if viewer == null:
		push_warning("There is no Pictures autoload to open '%s' with." % picture)
		return
	scene.begin_blocking_interaction()
	await viewer.open(picture)
	if is_instance_valid(scene) and scene.is_inside_tree():
		scene.end_blocking_interaction()
