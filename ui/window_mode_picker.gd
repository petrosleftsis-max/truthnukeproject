extends VBoxContainer
class_name WindowModePicker
## Fullscreen, fake fullscreen or a window, as a row of buttons - above the
## sizes on the title screen's Resolution and the pause menu's Options alike,
## and saved between runs (see GameSettings). The line above them names the
## one in use.

const MUTED := Color("8296a9")

var buttons: Array[Button] = []
var _heading: Label = null


func _init():
	add_theme_constant_override("separation", 6)
	_heading = Label.new()
	_heading.add_theme_color_override("font_color", MUTED)
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_heading)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(row)
	var group := ButtonGroup.new()
	for i in GameSettings.WINDOW_MODE_NAMES.size():
		var button := Button.new()
		button.text = GameSettings.WINDOW_MODE_NAMES[i]
		button.toggle_mode = true
		button.button_group = group
		button.tooltip_text = GameSettings.WINDOW_MODE_TIPS[i]
		button.pressed.connect(_choose.bind(i))
		row.add_child(button)
		buttons.append(button)
	# Picking a size goes back to a window, so whatever was lit may not be by
	# the next time the menu is open.
	visibility_changed.connect(func(): if is_visible_in_tree(): refresh())
	refresh()


## What the line above the buttons says, for the tests and the curious.
func heading() -> String:
	return _heading.text


## Lights up the one in use.
func refresh():
	var chosen := GameSettings.window_mode()
	for i in buttons.size():
		buttons[i].set_pressed_no_signal(i == chosen)
	_heading.text = "Display: %s" % GameSettings.WINDOW_MODE_NAMES[chosen]


func _choose(index: int):
	GameSettings.set_window_mode(index)
	refresh()
