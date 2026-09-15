extends Node
class_name StoryScreen
## A conversation with nothing behind it: black screen, dialogue, then wherever
## the story goes next.
##
## Used for the openings that are not a place yet - Cyrus talking us into the
## world before the crossroads exists around him. The scene itself is nothing
## but a black rectangle; Dialogue Manager's balloon draws over it, and when the
## conversation ends this moves on.
##
## What to play and where to go afterwards are set on Campaign before changing
## to this scene, because a scene change cannot carry arguments. See
## Campaign.begin_story.

const BALLOON_SCENE = "res://ui/dialogue_balloon.tscn"
const PAUSE_UI = "res://ui/pause_ui.tscn"

## Where to go when the conversation ends and Campaign names nothing - the menu,
## so a story that has nowhere to be yet still leads somewhere.
const FALLBACK_SCENE = "res://main_menu.tscn"


func _ready():
	_paint_black()
	# The pause menu, so an opening is not somewhere you are stuck. There is no
	# map here for Escape to belong to, and a conversation over black is exactly
	# where somebody wants the volume, or the way out to the title screen.
	add_child(load(PAUSE_UI).instantiate())
	var path = Campaign.story_dialogue
	if path == "" or not ResourceLoader.exists(path):
		push_warning("StoryScreen: no dialogue at '%s' - going straight on." % path)
		_move_on()
		return
	var manager = get_node_or_null("/root/DialogueManager")
	if manager == null:
		push_warning("StoryScreen: Dialogue Manager is not available.")
		_move_on()
		return
	manager.dialogue_ended.connect(_on_dialogue_ended, CONNECT_ONE_SHOT)
	manager.show_dialogue_balloon_scene(BALLOON_SCENE, load(path), Campaign.story_title)


## Black, and nothing else. A ColorRect rather than a clear colour so it covers
## whatever the previous scene left on screen regardless of what that was.
func _paint_black():
	var layer := CanvasLayer.new()
	# Under the balloon, which sits higher, and over anything else.
	layer.layer = 1
	add_child(layer)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(black)


func _on_dialogue_ended(_resource = null):
	_move_on()


func _move_on():
	var next = Campaign.story_next_scene
	Campaign.clear_story()
	SceneTransition.change_scene(next if next != "" else FALLBACK_SCENE)
