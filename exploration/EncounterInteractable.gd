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
## When true the battle starts on contact rather than on a key press - an
## ambush rather than a fight you choose to pick.
@export var automatic: bool = false
## Identity used to remember that this fight has been won. Defaults to the
## node's own name, which is unique within a map; set it explicitly only if you
## rename the node and want its cleared state to carry over.
@export var trigger_id: String = ""


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
	return not Campaign.is_trigger_cleared(trigger_id)


func interact(scene: Node):
	if encounter == null:
		push_warning("EncounterInteractable '%s' has no encounter assigned." % name)
		return
	Campaign.begin_battle_from_exploration(encounter, scene.map_path(), scene.party_position(), trigger_id)
	SceneTransition.change_scene(scene.battle_scene)
