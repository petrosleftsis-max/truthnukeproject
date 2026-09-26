extends PanelContainer
class_name GateTag
## A gate's name and how many castings through it are left, as dots, on a
## chip in the gate's colour (Stats.gate_colour). Beside the skill tabs as the
## gate counters, and at the start of each shelf of spells.
##
## Dots rather than "2/3": how much is left reads at a glance, and a gate
## running dry reads as the dots going hollow. A gate with more castings than
## there is room for dots says the numbers instead.

const MOST_DOTS := 6
const DOT := 7.0
const DOT_GAP := 3.0

var level := 0
var _name: Label = null
var _dots: Control = null
var _left := 0
var _most := 0


## `stacked` puts the dots under the name, for the start of a shelf; otherwise
## they sit beside it, for the row of counters.
func _init(stacked: bool = false):
	mouse_filter = Control.MOUSE_FILTER_STOP
	var box: BoxContainer = VBoxContainer.new() if stacked else HBoxContainer.new()
	box.add_theme_constant_override("separation", 3 if stacked else 6)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 12 if stacked else 13)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_name)
	_dots = Control.new()
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dots.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dots.draw.connect(_draw_dots)
	box.add_child(_dots)


## Shows gate `gate` with `left` of `most` castings still to use.
func show_gate(gate: int, left: int, most: int):
	level = gate
	_left = left
	_most = most
	var colour := Stats.gate_colour(gate)
	_name.text = Stats.short_gate_name(gate)
	_name.add_theme_color_override("font_color", colour)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.09, 0.12, 0.92)
	box.border_color = Color(colour, 0.75)
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.content_margin_left = 7
	box.content_margin_right = 7
	box.content_margin_top = 3
	box.content_margin_bottom = 4
	add_theme_stylebox_override("panel", box)
	if most > MOST_DOTS:
		_dots.custom_minimum_size = Vector2(0, 0)
		_name.text += "  %d/%d" % [left, most]
	else:
		_dots.custom_minimum_size = Vector2(most * DOT + maxi(most - 1, 0) * DOT_GAP, DOT)
	_dots.queue_redraw()
	tooltip_text = "%s: %d of %d left" % [Stats.gate_name(gate), left, most]


## How many castings the tag says are left, for the tests and the curious.
func uses() -> Vector2i:
	return Vector2i(_left, _most)


func _draw_dots():
	if _most > MOST_DOTS:
		return
	var colour := Stats.gate_colour(level)
	var radius := DOT * 0.5
	for i in _most:
		var centre := Vector2(radius + i * (DOT + DOT_GAP), radius)
		if i < _left:
			_dots.draw_circle(centre, radius, colour)
		else:
			_dots.draw_arc(centre, radius - 0.5, 0.0, TAU, 16, Color(colour, 0.7), 1.0, true)
