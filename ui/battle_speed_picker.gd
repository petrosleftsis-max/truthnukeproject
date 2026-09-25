extends VBoxContainer
class_name BattleSpeedPicker
## How fast enemy turns play, as a row of buttons - on the title screen's
## Options and the pause menu's alike, and saved between runs (see
## GameSettings). The buttons say the multiplier, which five of fit in the
## pause menu; the line above them names the one chosen.

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
	for i in GameSettings.ENEMY_SPEEDS.size():
		var button := Button.new()
		button.text = "%s×" % _number(GameSettings.ENEMY_SPEEDS[i])
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = i == GameSettings.enemy_speed_index()
		button.tooltip_text = "%s - enemy turns play at %s× speed" % [
			GameSettings.ENEMY_SPEED_NAMES[i], _number(GameSettings.ENEMY_SPEEDS[i])]
		button.pressed.connect(_choose.bind(i))
		row.add_child(button)
		buttons.append(button)
	_name_choice()


## What the line above the buttons says, for the tests and the curious.
func heading() -> String:
	return _heading.text


func _choose(index: int):
	GameSettings.set_enemy_speed_index(index)
	_name_choice()


func _name_choice():
	_heading.text = "Enemy turns: %s" % GameSettings.ENEMY_SPEED_NAMES[GameSettings.enemy_speed_index()]


## 0.5 rather than 0.500000, 2 rather than 2.0.
static func _number(value: float) -> String:
	return str(value).trim_suffix(".0")
