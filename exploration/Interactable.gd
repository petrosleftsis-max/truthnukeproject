extends Node2D
class_name Interactable
## Base for anything the party can walk up to and use in an exploration map.
##
## Drop one into a map scene and position it like any other node. The
## ExplorationScene finds every Interactable in the map automatically - there
## is no list to register with - picks the nearest one in range, shows its
## prompt, and calls interact() when the player presses the interact key.
##
## Subclasses: DialogueInteractable, DoorInteractable, EncounterInteractable,
## ExamineInteractable. To add a kind of your own, extend this and override
## interact(); everything else is handled for you.


## Shown above the party when they're close enough, e.g. "Talk", "Enter",
## "Examine". Keep it to a word or two.
@export var prompt: String = "Interact"
## How close the party leader has to be, in pixels. One tile is 32.
@export var interaction_radius: float = 40.0
## Optional sprite so the thing is visible on the map. Leave empty for an
## invisible trigger - a doorway painted into the tiles, say.
@export var texture: Texture2D:
	set(value):
		texture = value
		_refresh_sprite()

var _sprite: Sprite2D = null


func _ready():
	_refresh_sprite()


func _refresh_sprite():
	if texture == null:
		if _sprite != null:
			_sprite.queue_free()
			_sprite = null
		return
	if _sprite == null:
		_sprite = Sprite2D.new()
		add_child(_sprite)
	_sprite.texture = texture


## Whether this can be used right now. An encounter trigger already beaten
## says no, and stops offering its prompt.
func is_available() -> bool:
	return true


## Do the thing. `scene` is the ExplorationScene, passed in so subclasses can
## reach the party, the map path and the message log without hunting up the
## tree for them.
func interact(_scene: Node):
	pass
