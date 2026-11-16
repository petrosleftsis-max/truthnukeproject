extends VBoxContainer
class_name ComfortDials
## The comfort group of Options (Comfort): a slider each for screen shake, flashes, camera sway and rumble, and slow motion on or
## off. The same thing on the title screen and in the pause menu, as the volume sliders are.

const KEY_STEP := 0.1
const INK_DIM := Color("c2ceda")
const MUTED := Color("8296a9")

var _slow: CheckButton = null


func _ready():
	add_theme_constant_override("separation", 12)
	for dial in Comfort.DIALS:
		add_child(_row(dial))
	_slow = CheckButton.new()
	_slow.name = "SlowMotion"
	_slow.text = "Slow motion"
	_slow.tooltip_text = "The world slowing for a moment at a last blow, a boss felled, a stagger"
	_slow.button_pressed = Comfort.slow_motion()
	_slow.toggled.connect(func(on: bool): Comfort.set_slow_motion(on))
	_slow.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(_slow)


func _row(dial: Dictionary) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var heading := HBoxContainer.new()
	var label := Label.new()
	label.text = dial.name
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", INK_DIM)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(label)
	var readout := Label.new()
	readout.add_theme_font_size_override("font_size", 15)
	readout.add_theme_color_override("font_color", MUTED)
	heading.add_child(readout)
	row.add_child(heading)
	var slider := HSlider.new()
	slider.name = "%sSlider" % String(dial.key).capitalize()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = Comfort.share(dial.key)
	slider.custom_minimum_size = Vector2(0, 20)
	slider.tooltip_text = dial.tip
	readout.text = _said(slider.value)
	slider.value_changed.connect(func(level):
		Comfort.set_share(dial.key, level)
		readout.text = _said(level)
		if dial.key == Comfort.RUMBLE:
			Rumble.tap(0.5, 0.18))
	slider.gui_input.connect(func(event): _nudge(slider, event))
	row.add_child(slider)
	return row


static func _said(level: float) -> String:
	return "Off" if level <= 0.004 else "%d%%" % roundi(level * 100.0)


## Left and right move a slider a tenth at a time; up and down are the menu's own (VolumeSliders has the reasons).
func _nudge(slider: HSlider, event: InputEvent):
	var direction := 0.0
	if event.is_action_pressed("ui_right", true):
		direction = 1.0
	elif event.is_action_pressed("ui_left", true):
		direction = -1.0
	else:
		return
	slider.value = clampf(slider.value + direction * KEY_STEP, slider.min_value, slider.max_value)
	slider.accept_event()


## The sliders and the switch, in order, for a menu's keyboard loop.
func controls() -> Array:
	var found: Array = []
	for child in find_children("*", "HSlider", true, false):
		found.append(child)
	found.append(_slow)
	return found
