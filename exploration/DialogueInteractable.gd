@tool
extends Interactable
class_name DialogueInteractable
## An NPC (or anything else) that starts a Dialogue Manager conversation.
##
## Assign a .dialogue resource and the title to start from. While the balloon
## is up the ExplorationScene freezes the party, so you can't walk away
## mid-sentence, and control returns when the conversation ends.


## The .dialogue file this conversation lives in.
## The balloon this game talks through - ui/dialogue_balloon.tscn, a copy of
## Dialogue Manager's example with a portrait added, so updating the addon
## cannot overwrite it.
const BALLOON_SCENE = "res://ui/dialogue_balloon.tscn"

@export var dialogue: Resource
## Which title inside that file to start at. Dialogue Manager's own convention
## is "start" when you don't say otherwise.
@export var dialogue_title: String = "start"


func _init():
	prompt = "Talk"


func interact(scene: Node):
	if dialogue == null:
		push_warning("DialogueInteractable '%s' has no dialogue resource assigned." % name)
		return
	if not Engine.has_singleton("DialogueManager") and not _has_autoload():
		push_warning("Dialogue Manager isn't available - is the addon enabled in Project Settings?")
		return
	scene.begin_blocking_interaction()
	var manager = scene.get_node("/root/DialogueManager")
	# dialogue_ended fires whichever way the conversation finishes, including
	# the player closing it early, so it is the one signal that reliably hands
	# control back.
	if not manager.dialogue_ended.is_connected(scene.end_blocking_interaction):
		manager.dialogue_ended.connect(scene.end_blocking_interaction, CONNECT_ONE_SHOT)
	# Our own balloon rather than the addon's, because it carries the portrait.
	# It began as a copy of the addon's example and lives in ui/ so that
	# updating Dialogue Manager cannot overwrite it.
	manager.show_dialogue_balloon_scene(BALLOON_SCENE, dialogue, dialogue_title)


func _has_autoload() -> bool:
	var tree = Engine.get_main_loop() as SceneTree
	return tree != null and tree.root.has_node("DialogueManager")
