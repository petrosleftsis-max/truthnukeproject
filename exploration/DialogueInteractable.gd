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

@export_group("What happens after")
## A fight to walk straight into when the conversation ends - the ambush that
## the talking was leading up to. Left empty, the conversation just ends and the
## party is handed back the map.
##
## The battle remembers where the party was standing and hands the map back
## afterwards, exactly as an EncounterInteractable does, so the same scene can
## carry on once the fight is over.
@export var encounter_after: EncounterDefinition
## Identity used to remember that the fight this leads to has been won, so it
## does not happen again every time the conversation is had. Defaults to this
## node's own name.
@export var encounter_trigger_id: String = ""


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
	if encounter_after != null:
		manager.dialogue_ended.connect(_start_encounter_after.bind(scene), CONNECT_ONE_SHOT)
	# Our own balloon rather than the addon's, because it carries the portrait.
	# It began as a copy of the addon's example and lives in ui/ so that
	# updating Dialogue Manager cannot overwrite it.
	manager.show_dialogue_balloon_scene(BALLOON_SCENE, dialogue, dialogue_title)


func _has_autoload() -> bool:
	var tree = Engine.get_main_loop() as SceneTree
	return tree != null and tree.root.has_node("DialogueManager")


## Walks the party into the fight this conversation was leading up to.
##
## Bound to dialogue_ended rather than called at the end of interact(), because
## interact() returns the moment the balloon is up - the conversation is still
## being read at that point, and starting a battle underneath it would cut it
## off mid-sentence.
func _start_encounter_after(_resource, scene: Node):
	if encounter_after == null or not is_instance_valid(scene):
		return
	var trigger = encounter_trigger_id if encounter_trigger_id != "" else name
	# Already fought and won: the conversation still happens, the ambush does
	# not happen twice.
	if Campaign.is_trigger_cleared(trigger):
		return
	Campaign.begin_battle_from_exploration(encounter_after, scene.map_path(), scene.party_position(), trigger)
	SceneTransition.change_scene(scene.battle_scene)
