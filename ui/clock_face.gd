extends PanelContainer
class_name ClockFace
## The clock and the day on the HUD (Campaign "The clock and the calendar"; the designer, 2026-11-07),
## with the date on hovering it: a sun or a moon, the time, and which day this is. A placeholder look.

const INK := Color("dce8f5")
const SUN := Color(1.0, 0.82, 0.35)
const LOW_SUN := Color(1.0, 0.55, 0.28)
const MOON := Color(0.72, 0.8, 1.0)
const SIZE := Vector2(120, 26)
const TOP_GAP := 6.0

var _label: Label = null
var _dial: Control = null


func _ready():
	name = "ClockFace"
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = SIZE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	_dial = Control.new()
	_dial.custom_minimum_size = Vector2(16, 16)
	_dial.draw.connect(_draw_dial)
	row.add_child(_dial)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", INK)
	row.add_child(_label)
	Campaign.clock_moved.connect(_show)
	_show()


func _exit_tree():
	if Campaign.clock_moved.is_connected(_show):
		Campaign.clock_moved.disconnect(_show)


## Under a stealth map's bar, where there is one.
func _process(_delta):
	var bar = get_tree().get_first_node_in_group(&"stealth_bar")
	offset_top = bar.position.y + bar.size.y + TOP_GAP if bar != null and bar.visible else TOP_GAP


func _show():
	_label.text = "Day %d  %s" % [Campaign.day_number(), Campaign.clock_text()]
	var moon: String = Light.moon_name(Campaign.moon_now())
	tooltip_text = "%s\n%s, %s\n%s, %s" % [Campaign.date_text(), Campaign.clock_text(), Light.TIME_NAMES[Campaign.time_of_day], Campaign.weather_today(), moon]
	_dial.queue_redraw()


func _draw_dial():
	var middle := _dial.size / 2.0
	var hour: int = Campaign.time_of_day
	match hour:
		Light.Hour.NIGHT:
			# As much of it as there is tonight.
			var phase: float = Campaign.moon_now()
			_dial.draw_circle(middle, 6.0, MOON)
			if Light.moon_light(phase) < 0.9:
				_dial.draw_circle(middle + Vector2((phase - 0.5) * 16.0, 0.0), 5.6, Color(0.1, 0.12, 0.2))
		Light.Hour.DAY:
			_dial.draw_circle(middle, 6.0, SUN)
		_:
			_dial.draw_circle(middle + Vector2(0.0, 2.0), 6.0, LOW_SUN)
			_dial.draw_rect(Rect2(0.0, middle.y + 4.0, _dial.size.x, 4.0), Color(0.1, 0.12, 0.2))
	# A cloud in front of it, on a day with a sky to speak of.
	if ["overcast", "rain", "storm", "fog"].has(Campaign.weather_today()):
		for puff in [Vector2(-3.0, 3.0), Vector2(1.0, 2.0), Vector2(4.0, 4.0)]:
			_dial.draw_circle(middle + puff, 3.2, Color(0.72, 0.75, 0.8))
