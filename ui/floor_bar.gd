extends VBoxContainer
## The floor buttons, on a map with more than one floor (Combat "Heights"): one
## per floor, top floor first, the one on the screen lit. Pressing one puts that
## floor on the screen over the same place (CController.show_floor); Page Up and
## Page Down, and a pad's L3, step through them as well.

const LIT := Color("f2d27a")
const UNLIT := Color("c8ccd4")

var _combat = null
var _buttons: Array[Button] = []


## Built for `combat`'s floors.
func setup(combat):
	_combat = combat
	name = "FloorBar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 4)
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -360
	offset_right = -135
	offset_top = 32
	var heading := Label.new()
	heading.text = Pad.hint("Floors", &"floor_up")
	heading.add_theme_font_size_override("font_size", 14)
	heading.add_theme_color_override("font_color", UNLIT)
	add_child(heading)
	var order: Array = range(combat.floors.size())
	order.sort_custom(func(a, b): return combat.floors[a].level > combat.floors[b].level)
	for i in order:
		var floor_def: FloorDefinition = combat.floors[i]
		var button := Button.new()
		button.name = "Floor%d" % i
		button.text = floor_def.name if floor_def.name != "" else "Floor %d" % floor_def.level
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = "Show this floor"
		button.pressed.connect(func(): _combat.controller.show_floor(i))
		button.set_meta(&"floor", i)
		add_child(button)
		_buttons.append(button)


## The button for floor `index`, or null.
func button_for(index: int) -> Button:
	for button in _buttons:
		if button.get_meta(&"floor") == index:
			return button
	return null


func _process(_delta):
	if _combat == null or _combat.controller == null:
		return
	var shown: int = _combat.controller.shown_floor()
	for button in _buttons:
		var lit: bool = button.get_meta(&"floor") == shown
		button.add_theme_color_override("font_color", LIT if lit else UNLIT)
		button.text = button.text.trim_prefix("> ")
		if lit:
			button.text = "> " + button.text
