@tool
extends Control
class_name Hotspot
## Something in a Picture that can be clicked. Size and place it over the part
## of the picture it stands for; hovering it lights it up and names it, and
## clicking it does whatever is set below, in this order: says its line, plays
## its conversation, sets its flag, then opens another picture or goes to a map.
##
## An item can be used on it too: pick one from the bag along the bottom, then
## click. The right one does what the "Using an item" group says; any other is
## met with the wrong-item line.

## What hovering it says - "Drawer", "Old letter".
@export var display_name: String = ""

@export_group("When clicked")
## A line shown under the picture - a quick look, without writing a
## conversation for it.
@export_multiline var examine_text: String = ""
## A conversation to play. It can hand out items and set flags like any other:
## `do Campaign.give_item("cyrus", "tiny_bomb")`.
@export var dialogue: Resource
@export var dialogue_title: String = "start"
## Another picture to open - the drawer inside the desk. Back returns here.
@export_file("*.tscn") var opens_picture: String = ""
## Leaves the pictures altogether for this map, arriving at the entry point
## named below (the map's first one when empty).
@export_file("*.tscn") var goes_to_map: String = ""
@export var arrives_at: String = ""

@export_group("Using an item")
## The item, by key, that does something here. Empty: nothing is used on it.
@export var takes_item: String = ""
## Whether using it here takes it out of the bag.
@export var item_is_used_up: bool = true
## Set when the right item is used - what a PictureLayer or another Hotspot can
## wait on to show the result.
@export var item_sets_flag: String = ""
## A line shown when it works. Or, with a conversation set above, the title in
## it to play instead.
@export_multiline var item_text: String = ""
@export var item_dialogue_title: String = ""
## What trying any other item here says.
@export var wrong_item_text: String = "That doesn't work here."

@export_group("Flags")
## Set when it is clicked.
@export var sets_flag: String = ""
## Refuses until this flag is set, saying locked_text instead.
@export var requires_flag: String = ""
@export var locked_text: String = "It won't budge."
## Only there while this flag is set. Empty: there from the start.
@export var shown_while_flag: String = ""
## Gone for good once this flag is set - the letter, once taken.
@export var hidden_once_flag: String = ""

## The gold the rest of the HUD lights things up in under the cursor.
const HOVER_EDGE := Color(1.0, 0.84, 0.35, 0.95)
const HOVER_FILL := Color(1.0, 0.84, 0.35, 0.12)
const EDITOR_EDGE := Color(0.4, 0.8, 1.0, 0.9)

var _hovered := false


func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if Engine.is_editor_hint():
		return
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	refresh_from_flags()


func refresh_from_flags():
	visible = Picture.shown_by_flags(shown_while_flag, hidden_once_flag)
	if not visible:
		_set_hovered(false)


func is_hovered() -> bool:
	return _hovered


func _set_hovered(on: bool):
	if _hovered == on:
		return
	_hovered = on
	queue_redraw()
	var viewer = _viewer()
	if viewer != null:
		viewer.hover(self if on else null)


func _gui_input(event):
	if Engine.is_editor_hint():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		var viewer = _viewer()
		if viewer != null:
			viewer.click(self)


## The Pictures autoload, looked up rather than named. This runs in the editor
## too (it is a tool script, to draw itself there), and an editor that has not
## reloaded the project since the autoload was added refuses the whole script
## over a name it does not know yet.
func _viewer() -> Node:
	if Engine.is_editor_hint() or not is_inside_tree():
		return null
	return get_node_or_null("/root/Pictures")


func _draw():
	var box = Rect2(Vector2.ZERO, size)
	if Engine.is_editor_hint():
		# Where it is, and what it is called, for laying the picture out.
		draw_rect(box, EDITOR_EDGE, false, 3.0)
		var font = ThemeDB.fallback_font
		draw_string(font, Vector2(6, 22), display_name if display_name != "" else String(name),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, EDITOR_EDGE)
		return
	if _hovered:
		draw_rect(box, HOVER_FILL)
		draw_rect(box, HOVER_EDGE, false, 4.0)
