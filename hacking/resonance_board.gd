extends VBoxContainer
class_name ResonanceBoard
## Tuning the Resonance (HackDefinition.Kind.RESONANCE): the wave the thing
## hums at, faint, and Prometheus's own over it. Up to three dials - Amplitude,
## Frequency, Phase - each from 0 to 100 in steps of 5; Lock when they match.
## Every dial within the hack's Tolerance of its mark is in. Otherwise the try
## is spent. A bar says how near the whole wave is, so it is tuned rather than
## guessed. Each try hums at a new wave.
##
## A hint marks where one dial has to be; making it simpler doubles the
## Tolerance.

signal solved
signal failed_try(reason: String)

const NAMES := ["Amplitude", "Frequency", "Phase"]
const STEP := 5
const WAVE_SIZE := Vector2(560, 150)

var hack: HackDefinition = null
var colours := {}
var targets: Array = []
var values: Array = []
## Dials a hint has marked.
var revealed := {}
var tolerance := 6

var _wave: Control = null
var _rows: Array = []
var _nearness: ProgressBar = null
var _lock: Button = null


func setup(h: HackDefinition, rng: RandomNumberGenerator, palette: Dictionary):
	hack = h
	colours = palette
	tolerance = h.tolerance
	add_theme_constant_override("separation", 6)
	_wave = Control.new()
	_wave.custom_minimum_size = WAVE_SIZE
	_wave.draw.connect(_draw_wave)
	add_child(_wave)
	for i in h.dials:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		add_child(row)
		var name_label := Label.new()
		name_label.text = NAMES[i]
		name_label.custom_minimum_size.x = 120
		name_label.add_theme_color_override("font_color", colours.text)
		row.add_child(name_label)
		var minus := Button.new()
		minus.text = "-"
		minus.custom_minimum_size = Vector2(36, 30)
		row.add_child(minus)
		var value := Label.new()
		value.custom_minimum_size.x = 60
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.add_theme_color_override("font_color", colours.bright)
		row.add_child(value)
		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(36, 30)
		row.add_child(plus)
		var note := Label.new()
		note.add_theme_color_override("font_color", colours.dim)
		row.add_child(note)
		var index := i
		minus.pressed.connect(func(): turn(index, -STEP))
		plus.pressed.connect(func(): turn(index, STEP))
		_rows.append({"value": value, "note": note, "plus": plus})
	_nearness = ProgressBar.new()
	_nearness.max_value = 100
	_nearness.show_percentage = false
	_nearness.custom_minimum_size = Vector2(WAVE_SIZE.x, 10)
	add_child(_nearness)
	_lock = Button.new()
	_lock.text = "Lock the resonance"
	_lock.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_lock.pressed.connect(lock)
	add_child(_lock)
	reset_try(rng)


## A new wave to match, and the dials back in the middle.
func reset_try(rng: RandomNumberGenerator):
	targets = []
	values = []
	revealed = {}
	for i in hack.dials:
		targets.append(rng.randi_range(0, 100 / STEP) * STEP)
		values.append(50)
	_refresh()


func turn(i: int, by: int):
	values[i] = clampi(values[i] + by, 0, 100)
	_refresh()


func set_dial(i: int, to: int):
	values[i] = clampi(to, 0, 100)
	_refresh()


## How near the whole wave is, 0 to 1.
func nearness() -> float:
	var off := 0.0
	for i in values.size():
		off += absi(values[i] - targets[i])
	return clampf(1.0 - off / (100.0 * values.size()), 0.0, 1.0)


func lock():
	for i in values.size():
		if absi(values[i] - targets[i]) > tolerance:
			failed_try.emit("The %s was off - it shook loose." % NAMES[i].to_lower())
			return
	solved.emit()


## Marks where a dial has to be, one not marked yet.
## Whether a hint would show anything not on show already: a dial's mark not
## yet given away.
func hint_available() -> bool:
	return revealed.size() < values.size()


func hint() -> bool:
	for i in values.size():
		if not revealed.has(i):
			revealed[i] = true
			_refresh()
			return true
	return false


func simplify():
	tolerance *= 2
	_refresh()


func _refresh():
	for i in _rows.size():
		_rows[i].value.text = str(values[i])
		_rows[i].note.text = ("mark at %d" % targets[i]) if revealed.has(i) else ""
	_nearness.value = nearness() * 100.0
	if _wave != null:
		_wave.queue_redraw()


## y of the wave made by `dials` at x, 0 to 1 across.
func _wave_y(dials: Array, x: float) -> float:
	var amplitude: float = (10.0 + dials[0] * 0.6) if dials.size() > 0 else 40.0
	var cycles: float = (1.0 + dials[1] * 0.04) if dials.size() > 1 else 2.0
	var phase: float = (dials[2] / 100.0 * TAU) if dials.size() > 2 else 0.0
	return WAVE_SIZE.y * 0.5 - amplitude * sin(x * cycles * TAU + phase)


func _draw_wave():
	_wave.draw_rect(Rect2(Vector2.ZERO, WAVE_SIZE), Color(0, 0, 0, 0.35))
	for which in 2:
		var dials: Array = targets if which == 0 else values
		var points := PackedVector2Array()
		for step in 121:
			var x := step / 120.0
			points.append(Vector2(x * WAVE_SIZE.x, _wave_y(dials, x)))
		_wave.draw_polyline(points, Color(colours.good, 0.35) if which == 0 else colours.bright, 2.0 if which == 0 else 3.0, true)


func first_focus() -> Control:
	return _rows[0].plus if not _rows.is_empty() else _lock
