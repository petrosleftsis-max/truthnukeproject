@tool
extends Control
class_name Puzzle
## Something in a Picture to work out by hand: a lock's dials to turn to the
## right numbers, a torn letter's pieces to put back where they go, things on a
## shelf to set in the right order.
##
## Put PuzzleDials under it - or PuzzlePieces and the PuzzleSlots they belong
## in, each piece told its slot - or both. It is solved the moment every dial
## shows its Answer and every piece sits in its Slot; after that it holds still,
## and opening the picture again shows it solved.
##
## Size it over the area its parts sit in. It does not answer the mouse itself,
## so hotspots under or around it still work.

signal solved

## What it is called in the journal of things noticed - "The lock".
@export var display_name: String = ""

@export_group("When solved")
## Set when solved - what a PictureLayer can show the open cabinet by.
@export var solved_flag: String = ""
## Said under the picture when solved.
@export_multiline var solved_text: String = ""
## A clue, by key, put in the journal - the letter, read once mended.
@export var gives_clue: String = ""
## An item, by key, handed to the party.
@export var gives_item: String = ""

@export_group("Flags")
## Only there while this flag is set. Empty: there from the start.
@export var shown_while_flag: String = ""
## Gone for good once this flag is set - the lock, once the door is open.
@export var hidden_once_flag: String = ""

var _solved := false


func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not Engine.is_editor_hint():
		refresh_from_flags()


func refresh_from_flags():
	visible = Picture.shown_by_flags(shown_while_flag, hidden_once_flag)
	if is_solved() and not _solved:
		_settle()


func is_solved() -> bool:
	return _solved or (solved_flag != "" and Campaign.flag(solved_flag))


func dials() -> Array:
	return find_children("*", "PuzzleDial", true, false)


func pieces() -> Array:
	return find_children("*", "PuzzlePiece", true, false)


func slots() -> Array:
	return find_children("*", "PuzzleSlot", true, false)


## What it is recorded under: the picture, and where in it.
func examined_id() -> String:
	var at = get_parent()
	while at != null and not (at is Picture):
		at = at.get_parent()
	if at == null:
		return ""
	return "%s::%s" % [at.picture_id(), at.get_path_to(self)]


## Whether every part is where it should be. Called by the parts as they move.
func check():
	if _solved:
		return
	var parts := dials() + pieces()
	if parts.is_empty():
		return
	for part in parts:
		if not part.is_right():
			return
	_settle()
	if solved_flag != "":
		Campaign.set_flag(solved_flag)
	var viewer = get_node_or_null("/root/Pictures") if is_inside_tree() else null
	if viewer != null:
		viewer.puzzle_solved(self)
	solved.emit()


## Puts every part where it belongs and holds it there - past answering the
## mouse, so nothing still offers to be turned or moved.
func _settle():
	_solved = true
	for dial in dials():
		dial.show_value(dial.answer)
	for piece in pieces():
		var home = piece.right_slot()
		if home != null:
			piece.place_in(home, false)
	for part in dials() + pieces():
		part.mouse_filter = Control.MOUSE_FILTER_IGNORE
		part.mouse_default_cursor_shape = Control.CURSOR_ARROW
