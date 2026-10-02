@tool
extends Control
class_name Picture
## The root of a point-and-click picture: a close look at a desk, a room, a
## mural. Build one as its own scene - this node, a background image under it
## (a TextureRect), and a Hotspot over each thing that can be clicked - then
## open it from a PictureInteractable on a map, or from a conversation with
## `do Pictures.open("res://pictures/desk.tscn")`.
##
## Size this node to the background image in the editor. The viewer scales the
## whole picture to fit the screen, keeping its shape, so hotspots stay over
## what they were drawn over whatever the window is.
##
## Anything in it can come and go with the story: a PictureLayer (an image) or
## a Hotspot shows only while a flag is set, or disappears once one is - the
## drawer drawn open after the key is used, the letter gone once it is taken.
## A Puzzle is something to work out by hand: dials, or pieces to put in place.

enum HoverHints {
	OUTLINE_AND_NAME, ## Things light up under the cursor and say what they are.
	NAME_ONLY,        ## They say what they are, but nothing is drawn round them.
	NONE,             ## Nothing at all until clicked: the cursor stays an arrow. For a picture that is meant to be searched.
}

## Written above the picture while it is open. Empty for none.
@export var title: String = ""
## How much the picture gives away about where its hotspots are.
@export var hover_hints: HoverHints = HoverHints.OUTLINE_AND_NAME
## "Noticed 3 of 7" under the title: how much of it has been gone over. A
## hidden detail counts before it is found, which is a hint that there is one.
@export var show_progress: bool = true


## Whether something gated on these two flags should be showing: needs
## `shown_while` set (when there is one) and `hidden_once` not (when there is
## one). What PictureLayer and Hotspot both answer by.
static func shown_by_flags(shown_while: String, hidden_once: String) -> bool:
	if shown_while != "" and not Campaign.flag(shown_while):
		return false
	if hidden_once != "" and Campaign.flag(hidden_once):
		return false
	return true


## What anything in it is recorded under: the scene it was saved as, or its
## name for one built in code.
func picture_id() -> String:
	return scene_file_path if scene_file_path != "" else String(name)


## Brings everything in the picture up to date with the flags - after a click,
## and after a conversation that may have set some.
func refresh():
	for node in find_children("*", "", true, false):
		if node.has_method("refresh_from_flags"):
			node.refresh_from_flags()


## Every Hotspot in it, there or not.
func hotspots() -> Array:
	return find_children("*", "Hotspot", true, false)


## Every Puzzle in it.
func puzzles() -> Array:
	return find_children("*", "Puzzle", true, false)


## [noticed, out of]: hotspots gone over and puzzles solved, against everything
## there to notice - what is showing now, and anything taken away after it was
## looked at, so picking a letter up does not make the count go down.
func progress() -> Vector2i:
	var noticed := 0
	var total := 0
	for spot in hotspots():
		var seen: bool = spot.was_examined()
		if Picture.shown_by_flags(spot.shown_while_flag, spot.hidden_once_flag) or seen:
			total += 1
			if seen:
				noticed += 1
	for puzzle in puzzles():
		var done: bool = puzzle.is_solved()
		if Picture.shown_by_flags(puzzle.shown_while_flag, puzzle.hidden_once_flag) or done:
			total += 1
			if done:
				noticed += 1
	return Vector2i(noticed, total)
