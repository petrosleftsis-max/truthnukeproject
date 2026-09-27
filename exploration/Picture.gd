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

## Written above the picture while it is open. Empty for none.
@export var title: String = ""


## Whether something gated on these two flags should be showing: needs
## `shown_while` set (when there is one) and `hidden_once` not (when there is
## one). What PictureLayer and Hotspot both answer by.
static func shown_by_flags(shown_while: String, hidden_once: String) -> bool:
	if shown_while != "" and not Campaign.flag(shown_while):
		return false
	if hidden_once != "" and Campaign.flag(hidden_once):
		return false
	return true


## Brings everything in the picture up to date with the flags - after a click,
## and after a conversation that may have set some.
func refresh():
	for node in find_children("*", "", true, false):
		if node.has_method("refresh_from_flags"):
			node.refresh_from_flags()
