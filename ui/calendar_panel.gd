extends CanvasLayer
## The calendar and the weathers (the designer, 2026-11-12: "make it easier for me to see every weather through the sundial,
## allow me to check a calendar to see dates and weather"). Opened by Campaign.open_calendar - from the light stage's sundial,
## or any conversation with `do Campaign.open_calendar()`, which waits for it to close. Two pages:
## - The month: a square a day under its weekday, its weather drawn and named and the moon beside it; today ringed in gold, the
##   days gone by dimmed, a weather a scene set marked "set". A day pressed says what its weather does, and a day to come can be
##   gone to (the clock never runs back).
## - The weathers: every one there is (Light.WEATHERS), pressed to have it now (Campaign.set_weather), the day's own again, and
##   a round of them all once this closes (tour, from Campaign.tour_the_weathers).
## Nothing here decides anything in a fight: the weather is the Campaign's, as it always is. A placeholder look: the glyphs are
## drawn in code, each with a slot for a picture of its own (GLYPH_FOLDER + "<weather>.png").

signal closed(wants_tour: bool)

const INK := Color("dce8f5")
const MUTED := Color("8ea2b8")
const GOLD := Color("e8c66a")
const GLYPH_FOLDER := "res://art/ui/weather/"
## A round of every weather: how long each shows, and how fast the sky goes from one to the next meanwhile.
const TOUR_SECONDS := 4.0
const TOUR_EASE_SECONDS := 0.8

## What each weather does, in a line (Light "What the weather does", Combat "Weather", StealthWatch "The weather").
const WEATHER_SAYS := {
	"clear": "Nothing in the way.",
	"haze": "A soft, pale light. Nothing changes in a fight.",
	"overcast": "Grey, and the shadows soft. Nothing changes in a fight.",
	"rain": "A light rain: steps are heard further on a map, prints are left in the mud, whoever starts a turn under it is Soaked, and fire on the ground burns out sooner.",
	"fog": "Thick: in a fight whoever can hide is lost past 3 tiles; on a map a guard sees only as far as his Dim sight. Close by, both see as ever.",
	"storm": "A hard rain: steps are drowned on a map, whoever starts a turn under it is Soaked, and fire on the ground burns out sooner.",
	"snow": "Snow lies and deepens through the day: deep snow costs twice to walk, Frozen lasts longer in the cold, and steps leave prints.",
	"sleet": "Rain and hail: whoever starts a turn under it is Soaked, and Frozen lasts longer in the cold.",
	"thunderstorm": "A hard rain with wind: lightning strikes in a fight out of doors, marked a round ahead; Soaked; steps drowned.",
	"wind": "A strong wind: what flies goes twice as far along it and half as far across it, and fliers are blown unless they land.",
	"sandstorm": "Wind and sand: what flies as in a wind, and thick, so whoever can hide is lost past a few tiles.",
	"blizzard": "Wind and snow: what flies as in a wind; thick; the snow lies deep; the cold.",
	"heat": "The heat of the day: Burn lasts a turn longer.",
	"ash": "Ash falling and lying. A grey sky.",
	"aurora": "Bands of light across the sky, by night.",
	"rainbow": "A rainbow, by day.",
	"eclipse": "The sun darkened.",
}

var page := "month"
## The month shown: how many after the one the story begins in.
var _month := 0
var _picked_day := -1
var _wants_tour := false

var _title: Label = null
var _now: Label = null
var _month_name: Label = null
var _body: VBoxContainer = null
var _grid: GridContainer = null
var _about: Label = null
var _go: Button = null
var _tabs := {}


func _ready():
	name = "CalendarPanel"
	layer = 42
	process_mode = Node.PROCESS_MODE_ALWAYS
	var calendar := Campaign.calendar()
	_month = _month_of(Campaign.day_number(), calendar)
	var back := ColorRect.new()
	back.color = Color(0.0, 0.0, 0.0, 0.45)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var middle := CenterContainer.new()
	middle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(middle)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(960, 0)
	middle.add_child(frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	frame.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	_title = Label.new()
	_title.text = "The Calendar"
	_title.theme_type_variation = GameFonts.HEADER
	_title.add_theme_font_size_override("font_size", 30)
	_title.add_theme_color_override("font_color", GOLD)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title)
	for tab in [["month", "The month"], ["weathers", "The weathers"]]:
		var button := Button.new()
		button.text = tab[1]
		button.toggle_mode = true
		button.pressed.connect(_show.bind(tab[0]))
		top.add_child(button)
		_tabs[tab[0]] = button
	var shut := Button.new()
	shut.text = "Close"
	shut.pressed.connect(_close)
	top.add_child(shut)
	_now = Label.new()
	_now.add_theme_color_override("font_color", INK)
	_now.add_theme_font_size_override("font_size", 18)
	column.add_child(_now)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	column.add_child(_body)
	_about = Label.new()
	_about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_about.custom_minimum_size = Vector2(940, 40)
	_about.add_theme_color_override("font_color", INK)
	_about.add_theme_font_size_override("font_size", 17)
	column.add_child(_about)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(foot)
	_go = Button.new()
	_go.visible = false
	_go.pressed.connect(_go_to_picked)
	foot.add_child(_go)
	Campaign.clock_moved.connect(_on_clock_moved)
	_show(page)


func _exit_tree():
	if Campaign.clock_moved.is_connected(_on_clock_moved):
		Campaign.clock_moved.disconnect(_on_clock_moved)


## The clock moved: the line along the top says so, and the rest is drawn again only when the day or the weather has changed.
var _drawn_for := []


func _on_clock_moved():
	var now := [Campaign.day_number(), Campaign.weather_fixed.duplicate()]
	if now != _drawn_for:
		_freshen()
	elif _now != null:
		_now.text = _now_text()


func _now_text() -> String:
	return "Day %d: %s, %s. %s, %s; %s." % [Campaign.day_number(), Campaign.date_text(), Campaign.clock_text(), Campaign.season_now().capitalize(),
		Campaign.weather_today().capitalize(), Light.moon_name(Campaign.moon_now())]


func _input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _close():
	if is_queued_for_deletion():
		return
	closed.emit(_wants_tour)
	queue_free()


func _show(which: String):
	page = which
	for key in _tabs:
		_tabs[key].set_pressed_no_signal(key == page)
	_picked_day = -1
	_freshen()


## Everything drawn again from the clock and the weather as they are.
func _freshen():
	if not is_inside_tree():
		return
	_drawn_for = [Campaign.day_number(), Campaign.weather_fixed.duplicate()]
	_now.text = _now_text()
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	if page == "weathers":
		_fill_weathers()
	else:
		_fill_month()
	_say_about()


## --- The month ---


## The month `day` falls in, counted from the one the story begins in.
static func _month_of(day: int, calendar: CalendarDefinition) -> int:
	var since := day - 1 + calendar.first_day - 1
	return floori(float(since) / float(maxi(calendar.days_in_a_month, 1)))


## The day number of the `day_in_month`th day of the month `month` (counted as _month_of does): 1 is the story's first.
static func _day_number_of(month: int, day_in_month: int, calendar: CalendarDefinition) -> int:
	return month * calendar.days_in_a_month + day_in_month - (calendar.first_day - 1)


func _fill_month():
	var calendar := Campaign.calendar()
	var row := HBoxContainer.new()
	_body.add_child(row)
	var earlier := Button.new()
	earlier.text = "<"
	earlier.pressed.connect(func():
		_month -= 1
		_picked_day = -1
		_freshen())
	row.add_child(earlier)
	_month_name = Label.new()
	_month_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_month_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_month_name.theme_type_variation = GameFonts.HEADER
	_month_name.add_theme_font_size_override("font_size", 22)
	_month_name.add_theme_color_override("font_color", INK)
	var months := maxi(calendar.months.size(), 1)
	var month_index := posmod(calendar.first_month + _month, months)
	var year := calendar.first_year + floori(float(calendar.first_month + _month) / float(months))
	_month_name.text = "%s, year %d" % [calendar.months[month_index] if month_index < calendar.months.size() else "", year]
	row.add_child(_month_name)
	var later := Button.new()
	later.text = ">"
	later.pressed.connect(func():
		_month += 1
		_picked_day = -1
		_freshen())
	row.add_child(later)
	var weekdays := maxi(calendar.weekdays.size(), 1)
	_grid = GridContainer.new()
	_grid.columns = weekdays
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	_body.add_child(_grid)
	for name_of_day in calendar.weekdays:
		var head := Label.new()
		head.text = name_of_day
		head.custom_minimum_size = Vector2(130, 0)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head.add_theme_font_size_override("font_size", 14)
		head.add_theme_color_override("font_color", MUTED)
		_grid.add_child(head)
	var first := _day_number_of(_month, 1, calendar)
	var starts_on := posmod(calendar.first_weekday + first - 1, weekdays)
	for i in starts_on:
		_grid.add_child(Control.new())
	for day_in_month in range(1, calendar.days_in_a_month + 1):
		_grid.add_child(_day_square(_day_number_of(_month, day_in_month, calendar), day_in_month))


func _day_square(day: int, day_in_month: int) -> Control:
	var today := Campaign.day_number()
	var square := Button.new()
	square.custom_minimum_size = Vector2(130, 60)
	square.name = "Day%d" % day_in_month
	var before_the_story := day < 1
	square.disabled = before_the_story
	if not before_the_story:
		square.pressed.connect(func():
			_picked_day = day
			_say_about())
	if day < today:
		square.modulate = Color(1.0, 1.0, 1.0, 0.55)
	var weather := "" if before_the_story else Campaign.weather_on(day)
	var number := Label.new()
	number.text = str(day_in_month)
	number.position = Vector2(8, 2)
	number.add_theme_font_size_override("font_size", 16)
	number.add_theme_color_override("font_color", GOLD if day == today else INK)
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	square.add_child(number)
	if weather != "":
		var glyph := _Glyph.new()
		glyph.weather = weather
		glyph.position = Vector2(80, 4)
		glyph.size = Vector2(40, 32)
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		square.add_child(glyph)
		var said := Label.new()
		said.text = weather.capitalize() + (" (set)" if _set_on(day) else "")
		said.position = Vector2(8, 38)
		said.add_theme_font_size_override("font_size", 12)
		said.add_theme_color_override("font_color", GOLD if _set_on(day) else MUTED)
		said.mouse_filter = Control.MOUSE_FILTER_IGNORE
		square.add_child(said)
		var moon := _Moon.new()
		moon.phase = Light.moon_phase(day)
		moon.position = Vector2(48, 8)
		moon.size = Vector2(14, 14)
		moon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		square.add_child(moon)
	if day == today:
		var ring := _Ring.new()
		ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		square.add_child(ring)
	return square


## Whether a scene set the weather on `day`.
static func _set_on(day: int) -> bool:
	var fixed: Dictionary = Campaign.weather_fixed
	return not fixed.is_empty() and day >= int(fixed.get("from_day", 0)) and day <= int(fixed.get("until_day", -1))


## What the day pressed, or today, has: its date, its weather and what that does, its moon; and whether it can be gone to.
func _say_about():
	if _about == null:
		return
	var calendar := Campaign.calendar()
	var today := Campaign.day_number()
	_go.visible = false
	if page == "weathers":
		var weather := Campaign.weather_today()
		_about.text = "Now: %s. %s" % [weather.capitalize(), WEATHER_SAYS.get(weather, "")]
		return
	var day := _picked_day if _picked_day >= 1 else today
	var weather := Campaign.weather_on(day)
	_about.text = "%s (day %d): %s%s. %s The moon: %s." % [calendar.date_text(day), day, weather.capitalize(),
		", set by a scene" if _set_on(day) else "", WEATHER_SAYS.get(weather, ""), Light.moon_name(Light.moon_phase(day))]
	if _picked_day >= 1 and _picked_day != today:
		_go.visible = true
		_go.disabled = _picked_day < today
		_go.text = "Go to this day" if _picked_day > today else "The clock never runs back"


func _go_to_picked():
	var today := Campaign.day_number()
	if _picked_day > today:
		Campaign.advance_clock(0.0, _picked_day - today)
	_picked_day = -1
	_freshen()


## --- The weathers ---


func _fill_weathers():
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_body.add_child(grid)
	var now := Campaign.weather_today()
	for weather in Light.WEATHERS:
		var button := Button.new()
		button.name = "Weather_" + weather
		button.custom_minimum_size = Vector2(152, 86)
		button.tooltip_text = WEATHER_SAYS.get(weather, "")
		button.pressed.connect(func():
			Campaign.set_weather(weather))
		var glyph := _Glyph.new()
		glyph.weather = weather
		glyph.position = Vector2(54, 6)
		glyph.size = Vector2(44, 40)
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(glyph)
		var said := Label.new()
		said.text = weather.capitalize()
		said.position = Vector2(0, 52)
		said.size = Vector2(152, 24)
		said.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		said.add_theme_font_size_override("font_size", 15)
		said.add_theme_color_override("font_color", GOLD if weather == now else INK)
		said.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(said)
		if Light.SCENE_WEATHERS.has(weather):
			button.tooltip_text += "\nOnly ever by a scene: it never comes by itself."
		grid.add_child(button)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_body.add_child(row)
	var own := Button.new()
	own.text = "The day's own weather again (%s)" % Light.weather_of(Campaign.day_number(), Campaign.days_in_a_year()).capitalize()
	own.pressed.connect(func(): Campaign.set_weather())
	row.add_child(own)
	var round_them := Button.new()
	round_them.name = "Tour"
	round_them.text = "Go round every weather (%d seconds each)" % roundi(TOUR_SECONDS)
	round_them.pressed.connect(func():
		_wants_tour = true
		_close())
	row.add_child(round_them)


## --- A round of every weather ---


## Every weather in turn, TOUR_SECONDS each, its name and what it does along the top, then the sky as it was. Any press stops it.
static func tour(tree: SceneTree):
	var was: Dictionary = Campaign.weather_fixed.duplicate()
	var easing_was: float = LightView.sky_ease_seconds
	LightView.sky_ease_seconds = TOUR_EASE_SECONDS
	var caption := _Caption.new()
	tree.root.add_child(caption)
	var names: Array = Light.WEATHERS.keys()
	for i in names.size():
		if caption.stopped:
			break
		Campaign.set_weather(names[i])
		caption.say("%s   (%d of %d)" % [String(names[i]).capitalize(), i + 1, names.size()], WEATHER_SAYS.get(names[i], ""))
		var until := Time.get_ticks_msec() + roundi(TOUR_SECONDS * 1000.0)
		while Time.get_ticks_msec() < until and not caption.stopped and is_instance_valid(caption):
			await tree.process_frame
	Campaign.weather_fixed = was
	Campaign.clock_moved.emit()
	LightView.sky_ease_seconds = easing_was
	if is_instance_valid(caption):
		caption.queue_free()


## The name of the weather on show in a round of them, along the top; any press stops the round.
class _Caption extends CanvasLayer:
	var stopped := false
	var _name: Label = null
	var _what: Label = null

	func _ready():
		name = "WeatherTour"
		layer = 45
		process_mode = Node.PROCESS_MODE_ALWAYS
		var column := VBoxContainer.new()
		column.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		# Below the stealth bar and the clock.
		column.offset_top = 150
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(column)
		_name = Label.new()
		_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name.theme_type_variation = GameFonts.HEADER
		_name.add_theme_font_size_override("font_size", 34)
		_name.add_theme_color_override("font_color", GOLD)
		_name.add_theme_color_override("font_outline_color", Color.BLACK)
		_name.add_theme_constant_override("outline_size", 8)
		column.add_child(_name)
		_what = Label.new()
		_what.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_what.add_theme_font_size_override("font_size", 18)
		_what.add_theme_color_override("font_color", INK)
		_what.add_theme_color_override("font_outline_color", Color.BLACK)
		_what.add_theme_constant_override("outline_size", 6)
		column.add_child(_what)
		var hint := Label.new()
		hint.text = "Any key stops it."
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_font_size_override("font_size", 14)
		hint.add_theme_color_override("font_color", MUTED)
		hint.add_theme_color_override("font_outline_color", Color.BLACK)
		hint.add_theme_constant_override("outline_size", 4)
		column.add_child(hint)

	func say(name_said: String, what: String):
		_name.text = name_said
		_what.text = what

	func _input(event: InputEvent):
		if event.is_pressed() and not event.is_echo() and (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton):
			stopped = true
			get_viewport().set_input_as_handled()


## A ring round today's square.
class _Ring extends Control:
	func _draw():
		draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), GOLD, false, 3.0)


## The moon on a day, as it shows: waxing lit from the right, waning from the left (Light.moon_phase: 0 new, 0.5 full).
class _Moon extends Control:
	var phase := 0.5

	func _draw():
		var middle := size / 2.0
		var r := minf(size.x, size.y) * 0.45
		draw_circle(middle, r, Color(0.2, 0.22, 0.3, 0.9))
		# The lit part: from the bright edge to where the shadow's edge has got (an ellipse's half, `edge` of the way across).
		var edge := cos(TAU * phase)
		var side := 1.0 if phase < 0.5 else -1.0
		var lit := PackedVector2Array()
		var steps := 14
		for i in steps + 1:
			var a := PI * float(i) / float(steps) - PI / 2.0
			lit.append(middle + Vector2(side * cos(a) * r, sin(a) * r))
		for i in range(steps, -1, -1):
			var a := PI * float(i) / float(steps) - PI / 2.0
			lit.append(middle + Vector2(side * edge * cos(a) * r, sin(a) * r))
		if absf(1.0 - edge) > 0.02:
			draw_colored_polygon(lit, Color(0.96, 0.95, 0.85))
		draw_arc(middle, r, 0.0, TAU, 20, Color(0.95, 0.95, 0.85, 0.7), 1.0)


## A weather, drawn: a picture in GLYPH_FOLDER if there is one, else shapes in code.
class _Glyph extends Control:
	var weather := "clear"

	func _draw():
		var path := GLYPH_FOLDER + weather + ".png"
		if ResourceLoader.exists(path):
			draw_texture_rect(load(path), Rect2(Vector2.ZERO, size), false)
			return
		var middle := size / 2.0
		var r := minf(size.x, size.y) * 0.3
		var grey := Color(0.78, 0.82, 0.88)
		var dark := Color(0.45, 0.48, 0.58)
		match weather:
			"clear", "heat", "haze":
				var sun := Color(1.0, 0.84, 0.32)
				if weather == "heat":
					sun = Color(1.0, 0.52, 0.22)
				elif weather == "haze":
					sun = Color(1.0, 0.92, 0.72, 0.6)
				draw_circle(middle, r * 0.72, sun)
				for i in 8:
					var way := Vector2.RIGHT.rotated(TAU * float(i) / 8.0)
					draw_line(middle + way * r * 0.95, middle + way * r * 1.35, sun, 2.0)
			"overcast":
				_cloud(middle + Vector2(-r * 0.3, -r * 0.2), r * 0.8, dark)
				_cloud(middle + Vector2(r * 0.25, r * 0.15), r, grey)
			"rain", "storm", "sleet", "thunderstorm":
				var cloud := grey if weather == "rain" or weather == "sleet" else dark
				_cloud(middle + Vector2(0, -r * 0.45), r, cloud)
				var drops := 3 if weather == "rain" or weather == "sleet" else 5
				for i in drops:
					var x := middle.x - r + 2.0 * r * float(i) / float(maxi(drops - 1, 1))
					draw_line(Vector2(x, middle.y + r * 0.35), Vector2(x - r * 0.25, middle.y + r * 1.05), Color(0.55, 0.7, 1.0), 2.0)
				if weather == "sleet":
					draw_circle(Vector2(middle.x - r * 0.5, middle.y + r * 1.1), 2.0, Color.WHITE)
					draw_circle(Vector2(middle.x + r * 0.6, middle.y + r * 1.0), 2.0, Color.WHITE)
				if weather == "thunderstorm":
					draw_polyline(PackedVector2Array([middle + Vector2(r * 0.1, r * 0.2), middle + Vector2(-r * 0.25, r * 0.7),
						middle + Vector2(r * 0.15, r * 0.65), middle + Vector2(-r * 0.2, r * 1.25)]), Color(1.0, 0.9, 0.3), 2.5)
			"fog":
				for i in 3:
					var y := middle.y - r * 0.7 + float(i) * r * 0.7
					var line := PackedVector2Array()
					for step in 9:
						var x := middle.x - r * 1.3 + float(step) * r * 2.6 / 8.0
						line.append(Vector2(x, y + sin(float(step) * 1.1 + float(i)) * r * 0.12))
					draw_polyline(line, Color(0.88, 0.9, 0.95, 0.85), 2.5)
			"snow", "blizzard":
				_cloud(middle + Vector2(0, -r * 0.45), r, grey)
				for i in 4:
					var at := middle + Vector2(-r * 0.8 + float(i) * r * 0.55, r * (0.55 + 0.35 * float(i % 2)))
					_flake(at, r * 0.16)
				if weather == "blizzard":
					for i in 2:
						draw_arc(middle + Vector2(-r * 0.2, r * 0.2 + float(i) * r * 0.4), r * 0.9, -0.4, 0.4, 8, Color(1, 1, 1, 0.6), 1.5)
			"wind", "sandstorm":
				var gust := Color(0.85, 0.9, 1.0) if weather == "wind" else Color(0.95, 0.72, 0.4)
				for i in 3:
					var y := middle.y - r * 0.6 + float(i) * r * 0.6
					draw_line(Vector2(middle.x - r * 1.2, y), Vector2(middle.x + r * 0.7, y), gust, 2.0)
					draw_arc(Vector2(middle.x + r * 0.7, y - r * 0.22), r * 0.22, -PI / 2.0, PI / 2.0, 8, gust, 2.0)
				if weather == "sandstorm":
					for i in 4:
						draw_circle(middle + Vector2(-r + float(i) * r * 0.6, r * 1.0), 1.8, gust)
			"ash":
				_cloud(middle + Vector2(0, -r * 0.45), r, Color(0.4, 0.38, 0.38))
				for i in 5:
					draw_circle(middle + Vector2(-r + float(i) * r * 0.5, r * (0.5 + 0.3 * float(i % 2))), 2.2, Color(0.62, 0.6, 0.58))
			"aurora":
				for i in 2:
					var band := PackedVector2Array()
					for step in 10:
						var x := middle.x - r * 1.3 + float(step) * r * 2.6 / 9.0
						band.append(Vector2(x, middle.y - r * 0.2 + float(i) * r * 0.55 + sin(float(step) * 0.9 + float(i) * 2.0) * r * 0.3))
					draw_polyline(band, Color(0.3, 1.0, 0.6, 0.9) if i == 0 else Color(0.7, 0.4, 1.0, 0.9), 3.0)
			"rainbow":
				var colours := [Color(1.0, 0.3, 0.3), Color(1.0, 0.7, 0.2), Color(1.0, 1.0, 0.4), Color(0.4, 0.9, 0.4), Color(0.4, 0.6, 1.0)]
				for i in colours.size():
					draw_arc(middle + Vector2(0, r * 0.9), r * 1.4 - float(i) * 3.0, PI, TAU, 24, colours[i], 2.5)
			"eclipse":
				draw_circle(middle, r * 0.8, Color(0.08, 0.08, 0.14))
				draw_arc(middle, r * 0.85, 0.0, TAU, 28, Color(1.0, 0.9, 0.6), 2.5)
			_:
				draw_circle(middle, r * 0.5, grey)

	func _cloud(at: Vector2, r: float, colour: Color):
		draw_circle(at + Vector2(-r * 0.55, r * 0.15), r * 0.5, colour)
		draw_circle(at + Vector2(0.0, -r * 0.1), r * 0.65, colour)
		draw_circle(at + Vector2(r * 0.6, r * 0.18), r * 0.45, colour)
		draw_rect(Rect2(at + Vector2(-r * 0.55, r * 0.1), Vector2(r * 1.15, r * 0.5)), colour)

	func _flake(at: Vector2, r: float):
		for i in 3:
			var way := Vector2.RIGHT.rotated(PI * float(i) / 3.0) * r
			draw_line(at - way, at + way, Color.WHITE, 1.5)
