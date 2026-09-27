@tool
extends Interactable
class_name StealthGoal
## The end of a stealth map: walking into it (or pressing E, with Automatic
## off) finishes the sneaking. It sets Completed Flag, and - if no guard ever so
## much as began to notice anybody - Ghost Flag too, which the story can
## reward. Then it plays its conversation, if it has one, and sends the party
## on to Goes To Map, if that is set.

## Set when the party reaches here.
@export var completed_flag: String = ""
## Set as well when nobody was ever noticed on the way - not one "?".
@export var ghost_flag: String = ""
## Optional: a conversation to play on arrival.
@export var dialogue: Resource
@export var dialogue_title: String = "start"
## Optional: where the party goes next, arriving at the named entry point.
@export_file("*.tscn") var goes_to_map: String = ""
@export var arrives_at: String = ""
## For a stage played on its own from the main menu's Stealth Stages: arriving
## here goes back to that list, which says how it went. Goes To Map wins if
## both are set.
@export var ends_at_menu: bool = false

const BALLOON_SCENE := "res://ui/dialogue_balloon.tscn"

## How it went, for the stage list: set on arrival.
var _how_it_went := ""


func _init():
	prompt = "Slip out"
	automatic = true
	only_once = true


func interact(scene: Node):
	var ghost := false
	var watch = scene.get("stealth")
	if watch != null and watch.has_method("never_noticed"):
		ghost = watch.never_noticed()
	if completed_flag != "":
		Campaign.set_flag(completed_flag)
	if ghost and ghost_flag != "":
		Campaign.set_flag(ghost_flag)
	_how_it_went = "Made it out, and nobody so much as noticed - a ghost." if ghost else "Made it out."
	if scene.has_method("log_message"):
		scene.log_message("[color=lightgreen]Ghost - nobody so much as noticed.[/color]\n" if ghost
			else "[color=lightgreen]Made it out.[/color]\n")
	var manager = get_node_or_null("/root/DialogueManager")
	if dialogue != null and manager != null:
		scene.begin_blocking_interaction()
		manager.dialogue_ended.connect(_after_the_talking.bind(scene), CONNECT_ONE_SHOT)
		manager.show_dialogue_balloon_scene(BALLOON_SCENE, dialogue, dialogue_title)
		return
	_move_on()


func _after_the_talking(_resource, scene: Node):
	if is_instance_valid(scene):
		scene.end_blocking_interaction()
	_move_on()


func _move_on():
	if goes_to_map == "":
		if ends_at_menu:
			Campaign.to_main_menu(MainMenu.STEALTH_PANEL, _how_it_went)
		return
	Campaign.travel_to_map(goes_to_map, arrives_at)
	SceneTransition.change_scene("res://scenes/exploration.tscn")
