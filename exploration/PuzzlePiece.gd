@tool
extends Control
class_name PuzzlePiece
## Something to pick up and put in its place, under a Puzzle: a strip of a torn
## letter, a jar for the shelf. Drag it; let go near a free PuzzleSlot and it
## snaps in. Right when it sits in its own Slot.
##
## Put its art under it (a TextureRect). Without any, it is drawn as a plain
## card with its Placeholder Text on.

## What hovering it says.
@export var display_name: String = "Piece"
## The PuzzleSlot it belongs in.
@export var slot: NodePath
## How near its middle has to be to a slot's for it to snap in, in the
## picture's pixels.
@export var snap_distance: float = 60.0
## Written on the card drawn when it has no art.
@export_multiline var placeholder_text: String = ""

const CARD := Color(0.88, 0.82, 0.66)
const CARD_EDGE := Color(0.55, 0.45, 0.3)
const INK := Color(0.2, 0.15, 0.1)

## The slot it sits in now, or null.
var sits_in: PuzzleSlot = null
var _dragging := false
var _grab := Vector2.ZERO


func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_MOVE
	pivot_offset = size / 2.0
	if Engine.is_editor_hint():
		return
	mouse_entered.connect(_hover.bind(true))
	mouse_exited.connect(_hover.bind(false))


func right_slot() -> PuzzleSlot:
	return get_node_or_null(slot) as PuzzleSlot if not slot.is_empty() else null


func is_right() -> bool:
	return sits_in != null and sits_in == right_slot()


func puzzle() -> Puzzle:
	var at = get_parent()
	while at != null and not (at is Puzzle):
		at = at.get_parent()
	return at


func verb_name() -> String:
	return "move"


func is_dragging() -> bool:
	return _dragging


## Puts it in `target`, centred. `noisy` for a drop the player made, which
## clicks and settles; false for one put back without anybody's hand.
func place_in(target: PuzzleSlot, noisy: bool = true):
	if target == null:
		return
	position = target.position + (target.size - size) / 2.0
	sits_in = target
	if noisy:
		var viewer = _viewer()
		if viewer != null:
			viewer.play("snap")
			viewer.nudge(self)


## Lets go of it at `at` (in its parent's space, where its middle should be):
## into the nearest free slot within reach, or left lying there.
func drop_at(at: Vector2):
	position = at - size / 2.0
	_keep_inside()
	var best: PuzzleSlot = null
	var best_gap := snap_distance
	var owner_puzzle = puzzle()
	for candidate in (owner_puzzle.slots() if owner_puzzle != null else []):
		if candidate.get_parent() != get_parent() or _taken(candidate):
			continue
		var gap = (position + size / 2.0).distance_to(candidate.centre())
		if gap <= best_gap:
			best_gap = gap
			best = candidate
	if best != null:
		place_in(best)
	else:
		sits_in = null
		var viewer = _viewer()
		if viewer != null:
			viewer.play("put_down")
	if owner_puzzle != null:
		owner_puzzle.check()


## Whether another piece already sits in `candidate`.
func _taken(candidate: PuzzleSlot) -> bool:
	var owner_puzzle = puzzle()
	if owner_puzzle == null:
		return false
	for other in owner_puzzle.pieces():
		if other != self and other.sits_in == candidate:
			return true
	return false


func _keep_inside():
	var room = get_parent() as Control
	if room == null:
		return
	position = position.clamp(Vector2.ZERO, (room.size - size).max(Vector2.ZERO))


func _hover(on: bool):
	if _dragging:
		return
	var viewer = _viewer()
	if viewer != null:
		viewer.hover(self if on else null)


func _gui_input(event):
	if Engine.is_editor_hint():
		return
	var owner_puzzle = puzzle()
	if owner_puzzle != null and owner_puzzle.is_solved():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if event.pressed:
			_dragging = true
			_grab = get_parent().get_local_mouse_position() - position
			sits_in = null
			move_to_front()
			var viewer = _viewer()
			if viewer != null:
				viewer.play("pick_up")
		elif _dragging:
			_dragging = false
			drop_at(get_parent().get_local_mouse_position() - _grab + size / 2.0)
	elif event is InputEventMouseMotion and _dragging:
		accept_event()
		position = get_parent().get_local_mouse_position() - _grab
		_keep_inside()


func _viewer() -> Node:
	if Engine.is_editor_hint() or not is_inside_tree():
		return null
	return get_node_or_null("/root/Pictures")


func _draw():
	for child in get_children():
		if child is CanvasItem and child.visible:
			return
	var box := Rect2(Vector2.ZERO, size)
	draw_rect(box, CARD)
	draw_rect(box, CARD_EDGE, false, 2.0)
	if placeholder_text == "":
		return
	var font := get_theme_default_font()
	draw_multiline_string(font, Vector2(8, 24), placeholder_text, HORIZONTAL_ALIGNMENT_LEFT,
		size.x - 16, 18, -1, INK)
