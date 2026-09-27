@tool
extends TextureRect
class_name PictureLayer
## An image in a Picture that comes and goes with the story - the drawer drawn
## open, the candle lit - by a flag. Place it over the background like any
## TextureRect.

@export_group("Flags")
## Only shown while this flag is set. Empty: shown from the start.
@export var shown_while_flag: String = ""
## Gone for good once this flag is set. Empty: never goes.
@export var hidden_once_flag: String = ""


func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not Engine.is_editor_hint():
		refresh_from_flags()


func refresh_from_flags():
	visible = Picture.shown_by_flags(shown_while_flag, hidden_once_flag)
