@tool
extends Control
class_name PuzzleDial
## A dial on a lock, under a Puzzle: click it (or roll the wheel over it) to
## turn it on a notch, shift-click or roll the other way to turn it back. Right
## when it shows its Answer.
##
## Drawn as a plain numbered tumbler until it has art of its own: give Value
## Textures one image per value, in the same order as Values.

## What hovering it says.
@export var display_name: String = "Dial"
## What it turns through, in order. Numbers, letters, symbols' names.
@export var values: PackedStringArray = PackedStringArray(["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"])
## The value it has to show.
@export var answer: String = "0"
## The value it starts on. Empty: the first.
@export var starts_at: String = ""
## Your own art, one per value. Empty: drawn.
@export var value_textures: Array[Texture2D] = []
@export var font_size: int = 40

const METAL := Color(0.16, 0.17, 0.2)
const RIM := Color(0.62, 0.58, 0.48)
const FIGURE := Color(0.93, 0.88, 0.74)

var index := 0


func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pivot_offset = size / 2.0
	if Engine.is_editor_hint():
		return
	index = maxi(values.find(starts_at), 0) if starts_at != "" else 0
	mouse_entered.connect(_hover.bind(true))
	mouse_exited.connect(_hover.bind(false))


func value() -> String:
	return values[index] if index < values.size() else ""


func is_right() -> bool:
	return value() == answer


## Shows `wanted` without anybody turning it - a lock opened before.
func show_value(wanted: String):
	var at = values.find(wanted)
	if at >= 0:
		index = at
		queue_redraw()


func puzzle() -> Puzzle:
	var at = get_parent()
	while at != null and not (at is Puzzle):
		at = at.get_parent()
	return at


## Turns it `step` notches: on with a positive step, back with a negative.
func turn(step: int = 1):
	var owner_puzzle = puzzle()
	if values.is_empty() or (owner_puzzle != null and owner_puzzle.is_solved()):
		return
	index = posmod(index + step, values.size())
	queue_redraw()
	var viewer = _viewer()
	if viewer != null:
		viewer.play("dial")
		viewer.nudge(self)
	if owner_puzzle != null:
		owner_puzzle.check()


func verb_name() -> String:
	return "turn"


func _hover(on: bool):
	var viewer = _viewer()
	if viewer != null:
		viewer.hover(self if on else null)


func _gui_input(event):
	if Engine.is_editor_hint() or not (event is InputEventMouseButton) or not event.pressed:
		return
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			turn(-1 if event.shift_pressed else 1)
			accept_event()
		MOUSE_BUTTON_WHEEL_UP:
			turn(1)
			accept_event()
		MOUSE_BUTTON_WHEEL_DOWN:
			turn(-1)
			accept_event()


func _viewer() -> Node:
	if Engine.is_editor_hint() or not is_inside_tree():
		return null
	return get_node_or_null("/root/Pictures")


func _draw():
	var box := Rect2(Vector2.ZERO, size)
	var art: Texture2D = value_textures[index] if index < value_textures.size() else null
	if art != null:
		draw_texture_rect(art, box, false)
		return
	draw_rect(box, METAL)
	draw_rect(box, RIM, false, 3.0)
	# Notches above and below: the neighbours on the drum, half seen.
	draw_line(Vector2(6, 10), Vector2(size.x - 6, 10), Color(RIM, 0.4), 2.0)
	draw_line(Vector2(6, size.y - 10), Vector2(size.x - 6, size.y - 10), Color(RIM, 0.4), 2.0)
	var font := get_theme_default_font()
	var shown := value() if not values.is_empty() else "?"
	var text_size := font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, Vector2((size.x - text_size.x) / 2.0, (size.y + font_size * 0.7) / 2.0), shown,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, FIGURE)
