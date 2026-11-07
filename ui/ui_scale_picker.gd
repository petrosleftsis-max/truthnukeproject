extends VBoxContainer
class_name UiScalePicker
## How big the HUD is, as a row of buttons - on the title screen's Options and the pause menu's alike, and saved between runs (see
## GameSettings). The line above them names the one chosen. Any HUD on the screen follows at once (group `ui_scaled`).

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
	for i in GameSettings.UI_SCALES.size():
		var button := Button.new()
		button.text = GameSettings.UI_SCALE_NAMES[i]
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = i == GameSettings.ui_scale_index()
		button.tooltip_text = "The buttons, portraits and log of a fight and a map, at %d%%" % roundi(GameSettings.UI_SCALES[i] * 100.0)
		button.pressed.connect(_choose.bind(i))
		row.add_child(button)
		buttons.append(button)
	_name_choice()


## What the line above the buttons says, for the tests and the curious.
func heading() -> String:
	return _heading.text


func _choose(index: int):
	GameSettings.set_ui_scale_index(index)
	_name_choice()
	if is_inside_tree():
		get_tree().call_group(&"ui_scaled", &"apply_ui_scale")


func _name_choice():
	_heading.text = "Interface size: %s" % GameSettings.UI_SCALE_NAMES[GameSettings.ui_scale_index()]
