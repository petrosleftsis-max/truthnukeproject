@tool
extends Interactable
class_name EncounterInteractable
## An enemy (or ambush point) on the map that starts a battle.
##
## Remembers where the party was standing, loads the encounter, and hands
## control back to this map afterwards. Winning retires the trigger so the same
## fight doesn't restart every time you walk past; losing leaves it armed so it
## can be tried again.


@export var encounter: EncounterDefinition
## Identity used to remember that this fight has been won. Defaults to the
## node's own name, which is unique within a map; set it explicitly only if you
## rename the node and want its cleared state to carry over.
@export var trigger_id: String = ""

@export_group("Asking first")
## A conversation to have before the fight, instead of walking straight into it.
##
## The conversation decides what happens when it ends: a branch that says
## `do Campaign.accept_encounter()` walks into the fight, and one that says
## `do Campaign.decline_encounter()` walks the party back out of this trigger's
## reach so they can carry on and come back later. Saying neither counts as
## declining, so closing the balloon is not a way past.
##
## Left empty, the fight starts the moment this is triggered, as it always has.
@export var dialogue: Resource
## Which title inside that file to start at, Dialogue Manager's "start" by
## default - the same convention DialogueInteractable uses.
@export var dialogue_title: String = "start"


func _init():
	prompt = "Fight"


func _ready():
	super()
	if Engine.is_editor_hint():
		# Campaign is an autoload, so it only exists in the running game -
		# nothing here should be asking it about cleared fights while the map
		# is just being laid out in the editor.
		return
	if trigger_id == "":
		trigger_id = "%s/%s" % [get_tree().current_scene.scene_file_path if get_tree() and get_tree().current_scene else "", name]
	# A fight already won leaves nothing standing here.
	visible = not Campaign.is_trigger_cleared(trigger_id)


func is_available() -> bool:
	if Engine.is_editor_hint():
		return true
	# super() first, so a once-only trigger is spent the same way anything else
	# is; then the campaign's own memory of having beaten this fight.
	return super() and not Campaign.is_trigger_cleared(trigger_id)


func interact(scene: Node):
	if encounter == null:
		push_warning("EncounterInteractable '%s' has no encounter assigned." % name)
		return
	if dialogue == null:
		_begin_the_fight(scene)
		return
	if not _dialogue_available(scene):
		push_warning("Dialogue Manager isn't available - is the addon enabled in Project Settings?")
		_begin_the_fight(scene)
		return
	# Nothing carried over from a conversation somewhere else on the map.
	Campaign.forget_encounter_answer()
	scene.begin_blocking_interaction()
	var manager = scene.get_node("/root/DialogueManager")
	# dialogue_ended fires whichever way the conversation finishes, including
	# the player closing it early, so it is the one signal that reliably hands
	# control back.
	if not manager.dialogue_ended.is_connected(scene.end_blocking_interaction):
		manager.dialogue_ended.connect(scene.end_blocking_interaction, CONNECT_ONE_SHOT)
	manager.dialogue_ended.connect(_after_the_talking.bind(scene), CONNECT_ONE_SHOT)
	# The same balloon DialogueInteractable talks through, portrait and all.
	manager.show_dialogue_balloon_scene(DialogueInteractable.BALLOON_SCENE, dialogue, dialogue_title)


func _dialogue_available(scene: Node) -> bool:
	return scene.get_node_or_null("/root/DialogueManager") != null


## Acts on what the conversation decided, once it has finished.
##
## Bound to dialogue_ended rather than run at the end of interact(), because
## interact() returns the moment the balloon is up - starting a battle or
## walking the party about underneath it would cut the conversation off
## mid-sentence.
func _after_the_talking(_resource, scene: Node):
	if not is_instance_valid(scene):
		return
	if Campaign.take_encounter_answer() == Campaign.EncounterAnswer.ACCEPTED:
		_begin_the_fight(scene)
		return
	# Turned it down, or closed without answering. Either way they do not walk
	# through: they are walked back out of reach, and walking in again asks
	# again. An automatic trigger would otherwise fire on the spot they are
	# standing on and loop the conversation for ever.
	scene.step_party_back_from(self)


func _begin_the_fight(scene: Node):
	Campaign.begin_battle_from_exploration(encounter, scene.map_path(), scene.party_position(), trigger_id)
	SceneTransition.change_scene(scene.battle_scene)
