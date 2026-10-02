@tool
extends Control
class_name Hotspot
## Something in a Picture that can be clicked. Size and place it over the part
## of the picture it stands for; hovering it lights it up and names it, and
## clicking it does whatever is set below, in this order: says its line, hands
## over its item and clue, plays its conversation, sets its flag, then opens
## another picture or goes to a map.
##
## An item can be used on it too: pick one from the bag along the bottom, then
## click. The right one does what the "Using an item" group says; any other is
## met with the wrong-item line.

enum Verb {
	AUTO, ## Worked out from what it does: GO if it opens a picture or a map, TAKE if it hands over an item or hides itself once clicked, TALK if it has a conversation, LOOK otherwise.
	LOOK,
	TAKE,
	TALK,
	USE,
	GO,
}

## What hovering it says - "Drawer", "Old letter".
@export var display_name: String = ""

@export_group("When clicked")
## A line shown under the picture - a quick look, without writing a
## conversation for it.
@export_multiline var examine_text: String = ""
## An item, by key, handed to the party - the leader, or whoever has room.
## Pair it with Sets Flag and Hidden Once Flag set to the same flag so the
## thing is gone once taken.
@export var gives_item: String = ""
## A clue, by key (a file in res://clues/), put in the journal.
@export var gives_clue: String = ""
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

@export_group("Looking")
## Only to be found through a lens - a magnifying glass, a lamp (an item with
## Reveals Hidden Details): nothing here answers the mouse, lights up or says
## its name until a lens is held over it. Once clicked it has been found, and
## stays found.
@export var hidden_detail: bool = false

@export_group("Feedback")
## What the cursor shows over it. Auto works it out from what it does.
@export var verb: Verb = Verb.AUTO
## Played on a click instead of the usual sound for what it does.
@export var click_sound: AudioStream
## Your own animation for a click - a drawer sliding out, a page lifting: an
## AnimationPlayer anywhere in the picture, and the name of the animation in it
## to play.
@export var animation_player: NodePath
@export var click_animation: String = ""

## The gold the rest of the HUD lights things up in under the cursor.
const HOVER_EDGE := Color(1.0, 0.84, 0.35, 0.95)
const HOVER_FILL := Color(1.0, 0.84, 0.35, 0.12)
## Something already gone over: the same, quieter.
const SEEN_EDGE := Color(0.78, 0.74, 0.62, 0.7)
const SEEN_FILL := Color(0.78, 0.74, 0.62, 0.07)
const SEEN_TICK := Color(0.85, 0.82, 0.7, 0.55)
## A hidden detail under a lens.
const LENS_EDGE := Color(0.55, 0.85, 1.0, 0.9)
const EDITOR_EDGE := Color(0.4, 0.8, 1.0, 0.9)
const EDITOR_HIDDEN := Color(0.75, 0.55, 1.0, 0.9)

var _hovered := false
## Whether a lens is over it right now - set by Pictures each frame.
var lens_lit := false:
	set(value):
		if lens_lit != value:
			lens_lit = value
			_refresh_pointing()
			queue_redraw()


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
	_refresh_pointing()
	if not visible:
		_set_hovered(false)
	queue_redraw()


## The Picture it is in, or null.
func picture() -> Picture:
	var at = get_parent()
	while at != null and not (at is Picture):
		at = at.get_parent()
	return at


## What it is recorded under once clicked: the picture, and where in it.
func examined_id() -> String:
	var in_picture = picture()
	if in_picture == null:
		return ""
	return "%s::%s" % [in_picture.picture_id(), in_picture.get_path_to(self)]


func was_examined() -> bool:
	return Campaign.was_examined(examined_id())


## Whether the mouse can find it: there, and - for a hidden detail - found
## already or under a lens.
func can_be_pointed_at() -> bool:
	return visible and (not hidden_detail or lens_lit or was_examined())


func _refresh_pointing():
	if Engine.is_editor_hint():
		return
	mouse_filter = Control.MOUSE_FILTER_STOP if can_be_pointed_at() else Control.MOUSE_FILTER_IGNORE
	var in_picture = picture()
	var quiet = in_picture != null and in_picture.hover_hints == Picture.HoverHints.NONE
	mouse_default_cursor_shape = Control.CURSOR_ARROW if quiet else Control.CURSOR_POINTING_HAND
	if not can_be_pointed_at():
		_set_hovered(false)


## What clicking it will do, as the cursor says it: "look", "take", "talk",
## "use" or "go".
func verb_name() -> String:
	match verb:
		Verb.LOOK:
			return "look"
		Verb.TAKE:
			return "take"
		Verb.TALK:
			return "talk"
		Verb.USE:
			return "use"
		Verb.GO:
			return "go"
	if opens_picture != "" or goes_to_map != "":
		return "go"
	if gives_item != "" or (hidden_once_flag != "" and hidden_once_flag == sets_flag):
		return "take"
	if dialogue != null:
		return "talk"
	return "look"


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


## Plays its own click animation, when it has one.
func play_click_animation():
	if click_animation == "" or animation_player.is_empty():
		return
	var player = get_node_or_null(animation_player)
	if player is AnimationPlayer and player.has_animation(click_animation):
		player.play(click_animation)


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
		# Where it is, and what it is called, for laying the picture out. A
		# hidden detail in violet, so it is plain which only a lens finds.
		var edge = EDITOR_HIDDEN if hidden_detail else EDITOR_EDGE
		draw_rect(box, edge, false, 3.0)
		var font = ThemeDB.fallback_font
		var label = display_name if display_name != "" else String(name)
		draw_string(font, Vector2(6, 22), label + (" (hidden)" if hidden_detail else ""),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, edge)
		return
	var in_picture = picture()
	var hints = in_picture.hover_hints if in_picture != null else Picture.HoverHints.OUTLINE_AND_NAME
	var seen = was_examined()
	if hidden_detail and lens_lit and not seen:
		# Caught by the lens: the one thing drawn whatever the picture's hints,
		# since showing it is the whole of what a lens is for.
		draw_rect(box, Color(LENS_EDGE, 0.1))
		draw_rect(box, LENS_EDGE, false, 3.0)
	if hints != Picture.HoverHints.OUTLINE_AND_NAME:
		return
	if _hovered:
		draw_rect(box, SEEN_FILL if seen else HOVER_FILL)
		draw_rect(box, SEEN_EDGE if seen else HOVER_EDGE, false, 4.0)
	elif seen:
		# A small tick in the corner: gone over already, nothing new here.
		var corner = Vector2(size.x - 18, 8)
		draw_polyline(PackedVector2Array([corner + Vector2(0, 6), corner + Vector2(4, 10), corner + Vector2(11, 1)]),
			SEEN_TICK, 2.5)
