extends HBoxContainer
class_name ActionPips
## Whether the main and the secondary action are still there to spend, as two
## small marks by the portrait. The panel greys out a skill that cannot be
## used, but the shape of the turn - what is left of it - had to be worked out
## from which buttons were grey.

const LIVE_FILL := Color("2d5a8c")
const LIVE_EDGE := Color("7fb4ea")
const SPENT_FILL := Color("141b23")
const SPENT_EDGE := Color("2b3947")
const LIVE_INK := Color("dce8f5")
const SPENT_INK := Color("5d6b79")

var _main: PanelContainer = null
var _second: PanelContainer = null


func _init():
	name = "ActionPips"
	add_theme_constant_override("separation", 4)
	_main = _pip("Main")
	_second = _pip("Secondary")


## Shows what `comb` has left of their turn. Hidden for anybody not on the
## player's side: an enemy's turn is not the player's to plan.
func show_for(comb: Dictionary, combat: Combat):
	visible = not comb.is_empty() and comb.get("side", 1) == 0
	if not visible:
		return
	_light(_main, not comb.get("skill_used_this_turn", false),
		"Main action: %s" % ("still to use" if not comb.get("skill_used_this_turn", false) else "spent"))
	var barred = combat.has_restriction(comb, "prevents_secondary")
	var left = not comb.get("secondary_used_this_turn", false) and not barred
	var why = "still to use" if left else ("barred by a condition" if barred else "spent")
	_light(_second, left, "Secondary action: %s" % why)


## Whether each mark reads as there to spend, for the tests and the curious.
func state() -> Array:
	return [_main.get_meta("live", false), _second.get_meta("live", false)]


func _pip(text: String) -> PanelContainer:
	var pip := PanelContainer.new()
	pip.mouse_filter = Control.MOUSE_FILTER_STOP
	var label := Label.new()
	label.name = "Text"
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pip.add_child(label)
	add_child(pip)
	return pip


func _light(pip: PanelContainer, live: bool, tip: String):
	var box := StyleBoxFlat.new()
	box.bg_color = LIVE_FILL if live else SPENT_FILL
	box.border_color = LIVE_EDGE if live else SPENT_EDGE
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 1
	box.content_margin_bottom = 1
	pip.add_theme_stylebox_override("panel", box)
	pip.get_node("Text").add_theme_color_override("font_color", LIVE_INK if live else SPENT_INK)
	pip.tooltip_text = tip
	pip.set_meta("live", live)
