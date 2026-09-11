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
@export var interaction_radius: float = Grid.tiles(1.25):
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


@export_group("Flags")
## Set on Campaign when this is used - the whole of what a button has to say to
## open a door somewhere else. Left empty for anything that changes nothing.
##
## Set even when the thing itself does nothing else, so an invisible trigger in
## a doorway can record that the party came this way.
@export var sets_flag: String = ""
## What to store under it. Left empty stores true, which is what "this
## happened" needs. Type a number for a count and it is stored as a number, so
## a condition can compare it; anything else is stored as the text you wrote.
@export var flag_value: String = ""
## Refuses to work until this flag is set on Campaign. The door asks for the
## flag the button sets, and that is the whole puzzle.
@export var requires_flag: String = ""
## What the message log says when it refuses. The prompt still appears either
## way: a locked door that gives no sign it is a door is indistinguishable from
## a wall, and the player needs to know there is something here to come back to.
@export var locked_message: String = "It won't budge."


## Whether this can be used right now. An encounter trigger already beaten says
## no, and stops offering its prompt.
##
## Deliberately not where requires_flag is checked: something locked should
## still say what it is.
func is_available() -> bool:
	return true


## Whether the flag this waits on has been set. Anything with no requires_flag
## is always unlocked.
func is_unlocked() -> bool:
	return requires_flag == "" or Campaign.flag(requires_flag)


## What the player actually presses the key on: the lock first, then the thing
## itself, then the flag it leaves behind.
##
## Separate from interact() so that every kind of interactable - and every kind
## added later - is gated and records itself without knowing any of this exists.
func use(scene: Node):
	if not is_unlocked():
		if locked_message != "" and scene != null and scene.has_method("log_message"):
			scene.log_message(locked_message)
		return
	interact(scene)
	if sets_flag != "":
		Campaign.set_flag(sets_flag, _flag_value_to_store())


## Do the thing. `scene` is the ExplorationScene, passed in so subclasses can
## reach the party, the map path and the message log without hunting up the
## tree for them.
func interact(_scene: Node):
	pass


## The inspector can only offer text here, but a flag holding "3" and a flag
## holding 3 are not the same thing the moment a condition tries to count with
## it - so a value that is written as a number is stored as one.
func _flag_value_to_store():
	if flag_value == "":
		return true
	if flag_value.is_valid_int():
		return flag_value.to_int()
	if flag_value.is_valid_float():
		return flag_value.to_float()
	match flag_value.to_lower():
		"true":
			return true
		"false":
			return false
	return flag_value
