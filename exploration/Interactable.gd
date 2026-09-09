@tool
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
## How close the party leader has to be, in pixels. One tile is 32. Drawn as a
## ring in the editor so you can see the reach while placing it.
@export var interaction_radius: float = 40.0:
	set(value):
		interaction_radius = value
		queue_redraw()
## Optional sprite so the thing is visible on the map. Leave empty for an
## invisible trigger - a doorway painted into the tiles, say.
@export var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()


func _ready():
	queue_redraw()


## Drawn rather than given a Sprite2D child, so this is a @tool script that
## shows the real artwork in the editor while you position it - placing an
## invisible dot and guessing is no way to lay out a map - without adding a
## child node the scene would then have to carry around.
func _draw():
	if texture != null:
		draw_texture(texture, -texture.get_size() * 0.5)
	if not Engine.is_editor_hint():
		return
	# Reach, shown only in the editor: how close the party has to get before
	# this offers its prompt.
	draw_arc(Vector2.ZERO, interaction_radius, 0.0, TAU, 32, Color(1.0, 0.85, 0.3, 0.5), 1.0)
	if texture == null:
		# An invisible trigger still needs something to grab hold of.
		draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.85, 0.3, 0.8))


## Whether this can be used right now. An encounter trigger already beaten
## says no, and stops offering its prompt.
func is_available() -> bool:
	return true


## Do the thing. `scene` is the ExplorationScene, passed in so subclasses can
## reach the party, the map path and the message log without hunting up the
## tree for them.
func interact(_scene: Node):
	pass
