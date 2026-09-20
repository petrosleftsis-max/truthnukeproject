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


## Whether walking into this is enough, or the player has to press the interact
## key. Off by default: something that happens to you without asking is a
## decision, not a default - an open doorway, an ambush, a scene that starts the
## moment you round the corner.
##
## The prompt is not shown for one of these, since there is nothing to press.
@export var automatic: bool = false
## Whether an automatic one fires only on arrival, rather than every time the
## party walks back into it. For the conversation that opens a map: walking
## out of the room and back in is not arriving again, and a scene that replays
## whenever you retrace your steps stops being a scene.
##
## Scoped to this visit rather than the whole campaign - the node is rebuilt
## when the map loads, so coming back to the map later does play it again.
@export var only_once: bool = false
## Finishes the banner shown above the party when they're close enough: "Press
## E to talk", "Press E to interact". One verb, lowercased when it is shown, so
## it reads as a sentence whatever case it is written in here. Ignored when
## Automatic is on.
##
## "Talk" belongs to a conversation and nothing else. Anything the party opens,
## searches, fights or walks into is an interaction, and says so.
@export var prompt: String = "Interact"
## How close the party leader has to be, in pixels. One tile is 32. Drawn as a
## ring in the editor so you can see the reach while placing it.
@export var interaction_radius: float = Grid.tiles(1.25):
	set(value):
		interaction_radius = value
		queue_redraw()
## Optional sprite so the thing is visible on the map. Leave empty for an
## invisible trigger - a doorway painted into the tiles, say.
##
## Ignored when SpriteFrames below is set: a thing that moves does not also need
## a still of itself.
@export var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()

@export_group("Animation")
## An animation set, for anything that should move where it stands - a torch, a
## portal, a machine with something turning in it. Made the same way a
## combatant's is: right-click in the FileSystem dock -> New Resource ->
## SpriteFrames, then drag the frames in.
##
## It plays in the editor too, so what you are placing is what you will see.
@export var sprite_frames: SpriteFrames:
	set(value):
		sprite_frames = value
		_rebuild_animation()
## Which animation to play. SpriteFrames calls its first one "default" unless
## you rename it, so that is what this starts as.
@export var animation: String = "default":
	set(value):
		animation = value
		_rebuild_animation()
## How fast, as a multiple of the speed set on the animation itself. A row of
## torches all playing at 1.0 flicker in lockstep, which reads as machinery;
## give each a slightly different number and they stop looking synchronised.
@export_range(0.1, 4.0, 0.05, "or_greater") var animation_speed: float = 1.0:
	set(value):
		animation_speed = value
		if _animated != null:
			_animated.speed_scale = value

## The node doing the animating, made only for interactables that have frames.
var _animated: AnimatedSprite2D = null

## Whether an automatic one has already gone off where the party is standing.
##
## Without it, anything automatic that leaves the party on the map - a
## conversation, an examine - starts again the instant it ends, because they are
## still inside it. Cleared by walking out of range, which is what "again" ought
## to mean.
var contact_spent := false


func _ready():
	_rebuild_animation()
	queue_redraw()


## Puts an AnimatedSprite2D underneath this when there are frames to play, and
## takes it away again when there are not.
##
## Not owned by the scene: it is made from the SpriteFrames every time, so
## saving it into the scene file would be storing the same thing twice and
## leaving a stale copy behind the moment the frames change.
func _rebuild_animation():
	if _animated != null and is_instance_valid(_animated):
		_animated.queue_free()
		_animated = null
	if sprite_frames == null:
		queue_redraw()
		return
	_animated = AnimatedSprite2D.new()
	_animated.sprite_frames = sprite_frames
	_animated.speed_scale = animation_speed
	# Whatever the author named it, falling back to whatever the set actually
	# has - a resource with one animation called something else should still
	# show rather than sit there blank.
	var wanted = animation
	if not sprite_frames.has_animation(wanted):
		var names = sprite_frames.get_animation_names()
		wanted = names[0] if names.size() > 0 else ""
	if wanted != "":
		_animated.animation = wanted
		_animated.play()
	add_child(_animated)
	queue_redraw()


## Drawn rather than given a Sprite2D child, so this is a @tool script that
## shows the real artwork in the editor while you position it - placing an
## invisible dot and guessing is no way to lay out a map - without adding a
## child node the scene would then have to carry around.
func _draw():
	# The animation draws itself; the still is only for anything without one.
	if sprite_frames == null and texture != null:
		draw_texture(texture, -texture.get_size() * 0.5)
	if not Engine.is_editor_hint():
		return
	# Reach, shown only in the editor: how close the party has to get before
	# this offers its prompt.
	draw_arc(Vector2.ZERO, interaction_radius, 0.0, TAU, 32, Color(1.0, 0.85, 0.3, 0.5), 1.0)
	if texture == null and sprite_frames == null:
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
	# Once means once, whichever way it is reached. Enforced here rather than
	# only in the walk-into check, because an automatic thing was also being
	# offered to the interact key: the party could stand on a scene that had
	# already played and press E to watch it again.
	return not (only_once and contact_spent)


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
	# Once means once however it was reached. Walking into an automatic one
	# marks it before getting here, but pressing the key marked nothing at all -
	# so Only Once did nothing whatever for everything that is not automatic,
	# which is every signpost and every conversation on the map. Marked after
	# interact() rather than before, so a locked one that did nothing is not
	# spent by having been tried.
	contact_spent = true
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
