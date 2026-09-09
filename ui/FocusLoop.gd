extends RefCounted
class_name FocusLoop
## Wires a vertical list of buttons into a focus cycle, so Down past the last
## one comes round to the first and Up past the first goes to the last.
##
## Godot works out focus neighbours automatically within a container, but
## deliberately stops at the ends - it has no way to know a list is meant to be
## a loop. Used by every keyboard-navigable menu so they all behave the same.


static func link(buttons: Array):
	if buttons.size() < 2:
		return
	for i in buttons.size():
		var button: Control = buttons[i]
		var next: Control = buttons[(i + 1) % buttons.size()]
		var previous: Control = buttons[(i - 1 + buttons.size()) % buttons.size()]
		button.focus_neighbor_bottom = button.get_path_to(next)
		button.focus_neighbor_top = button.get_path_to(previous)
		button.focus_next = button.get_path_to(next)
		button.focus_previous = button.get_path_to(previous)
