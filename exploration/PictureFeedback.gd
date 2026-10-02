extends Resource
class_name PictureFeedback
## How the pictures and the journal sound, what the cursor shows over things,
## and how much moves. One of these lives at res://pictures/feedback.tres:
## open it and drop your own sounds and cursor images into its slots.
##
## Anything left empty is filled in: a sound slot with a short generated blip
## (see PlaceholderSounds), a cursor slot with a simple drawn glyph. So the game
## always has something, and yours replaces it slot by slot as it is made.
##
## A single Hotspot can have a sound of its own as well (Click Sound), and a
## PictureLayer or Hotspot can play your own animations - see their Animation
## groups.

const PATH := "res://pictures/feedback.tres"

@export_group("Sounds")
## Moving onto something that can be clicked. Quiet by nature - it plays a lot.
@export var hover: AudioStream
## Clicking something to look at it.
@export var look: AudioStream
## Clicking something that is picked up.
@export var take: AudioStream
## Clicking somebody, or something that starts a conversation.
@export var talk: AudioStream
## Opening a closer look, or leaving for a map.
@export var go: AudioStream
## Going back a picture.
@export var back: AudioStream
## Something that will not open yet (Requires Flag).
@export var locked: AudioStream
## The right item used on something.
@export var use_right: AudioStream
## Any other item.
@export var use_wrong: AudioStream
## Two items put together that make something.
@export var combine_right: AudioStream
## Two that do not.
@export var combine_wrong: AudioStream
## A clue learned.
@export var clue: AudioStream
## Two clues connected into a deduction.
@export var deduction: AudioStream
## Two clues that connect to nothing.
@export var no_deduction: AudioStream
## Showing somebody a clue or an item in a conversation.
@export var present: AudioStream
## A dial on a lock turned a notch.
@export var dial: AudioStream
## A piece of a puzzle picked up.
@export var pick_up: AudioStream
## Put down loose.
@export var put_down: AudioStream
## Put down into a place it fits.
@export var snap: AudioStream
## A puzzle solved.
@export var solved: AudioStream
## A lens (a magnifying glass, a lamp) picked up from the bag.
@export var lens: AudioStream
## The journal opened.
@export var journal: AudioStream
## Generated blips for every sound slot above left empty. Off for silence
## there instead.
@export var placeholder_sounds: bool = true

@export_group("Cursors")
## Shown beside the pointer over something, saying what clicking it will do.
## Empty: a simple drawn glyph. Around 32 pixels square reads best.
@export var look_cursor: Texture2D
@export var take_cursor: Texture2D
@export var talk_cursor: Texture2D
@export var use_cursor: Texture2D
@export var go_cursor: Texture2D
## A dial on a lock.
@export var turn_cursor: Texture2D
## A piece that can be moved.
@export var move_cursor: Texture2D

@export_group("Animation")
## Off: nothing moves - pictures and changes to them simply appear.
@export var animate: bool = true
## How long a closer look takes to zoom up out of what was clicked.
@export_range(0.0, 2.0, 0.01) var zoom_seconds: float = 0.25
## How long something appearing or going takes to fade.
@export_range(0.0, 2.0, 0.01) var fade_seconds: float = 0.25


static var _current: PictureFeedback = null


## The one in use: res://pictures/feedback.tres, or the defaults when there is
## none.
static func current() -> PictureFeedback:
	if _current == null:
		if ResourceLoader.exists(PATH):
			_current = load(PATH)
		if _current == null:
			_current = PictureFeedback.new()
	return _current


## Swaps the one in use - for tests.
static func use(feedback: PictureFeedback):
	_current = feedback


## The sound for `event` - one of the slot names above - or null for silence.
func sound(event: String) -> AudioStream:
	var chosen = get(event) if event in self else null
	if chosen is AudioStream:
		return chosen
	if placeholder_sounds:
		return PlaceholderSounds.make(event)
	return null


## The cursor image for `verb` ("look", "take", ...), or null to draw one.
func cursor(verb: String) -> Texture2D:
	var name := verb + "_cursor"
	var chosen = get(name) if name in self else null
	return chosen if chosen is Texture2D else null
