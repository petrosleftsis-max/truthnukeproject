extends Node
## Autoload. Plays a quick time event (QuickTimeDefinition) over whatever is on
## screen, and answers whether it was done in time:
##
##     var done_in_time: bool = await QuickTime.run(definition)
##
## In a fight Combat asks it (Combat "Quick time"); a conversation starts one by
## key and reads the answer back:
##
##     do QuickTime.start("dodge_the_bolt")
##     if QuickTime.passed
##
## which also leaves the flag qte:<key> set to how it went.
##
## The world waits while it is up - the tree is paused, unless something else
## already paused it - and it takes every key and button pressed meanwhile, so
## nothing underneath hears them.
##
## With nobody to press anything - the headless test harness - it answers at
## once: `answer` if a test has set one, and otherwise false. False is what the
## game did before there were quick time events (a blow taken in full, a throw
## thrown as written), so no suite has to know they exist. A test that wants
## the real thing sets `play_headless` and presses with press().

signal finished(done_in_time: bool)

## Over Hacking's (35), which a quick time event never starts from; under the
## journal (40).
const LAYER := 36
const BUTTONS: Array[StringName] = [&"qte_north", &"qte_east", &"qte_south", &"qte_west"]
const FOLDER := "res://data/quick_times/"
## How long "Done!" or "Too late" stays up.
const RESULT_HOLD := 0.45

const BACK := Color("141019")
const EDGE := Color("f0d060")
const TEXT := Color("f4ecd8")
const DIM := Color("8a8070")
const GOOD := Color("8fe0a0")
const BAD := Color("ff7070")

## Whether the last one start() played was done in time.
var passed := false
## For tests: 1 passes every one, 0 fails every one, -1 plays it.
var answer := -1
## For tests: play it for real even headless, pressed with press().
var play_headless := false

var _def: QuickTimeDefinition = null
var _running := false
var _done := false
var _wanted: Array[StringName] = []
var _at := 0
var _presses := 0
var _elapsed := 0.0
var _zone_centre := 0.5
var _paused_here := false
var _rng := RandomNumberGenerator.new()

var _layer: CanvasLayer = null
var _prompt: Label = null
var _row: HBoxContainer = null
var _clock: ProgressBar = null
var _mash: ProgressBar = null
var _track: Control = null
var _zone: ColorRect = null
var _marker: ColorRect = null
var _verdict: Label = null


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS


func running() -> bool:
	return _running


## Plays the quick time event saved as `key` in res://data/quick_times/, for a
## conversation: sets `passed`, and the flag qte:<key>.
func start(key: String) -> bool:
	var definition: QuickTimeDefinition = load(FOLDER + key + ".tres") if ResourceLoader.exists(FOLDER + key + ".tres") else null
	if definition == null:
		push_warning("QuickTime.start('%s'): there is no such quick time event in %s." % [key, FOLDER])
		passed = false
		return false
	passed = await run(definition)
	Campaign.set_flag("qte:" + key, passed)
	return passed


## Plays `definition`, and answers whether it was done in time.
func run(definition: QuickTimeDefinition) -> bool:
	if definition == null or _running:
		return false
	if answer != -1 or (DisplayServer.get_name() == "headless" and not play_headless):
		await get_tree().process_frame
		return answer == 1
	_def = definition
	_running = true
	_done = false
	_rng.randomize()
	_at = 0
	_presses = 0
	_elapsed = 0.0
	_wanted = []
	match _def.kind:
		QuickTimeDefinition.Kind.SEQUENCE:
			for i in maxi(_def.count, 1):
				_wanted.append(BUTTONS[_rng.randi() % BUTTONS.size()])
		QuickTimeDefinition.Kind.TIMING:
			_wanted.append(&"qte_south")
			var half := _def.zone * 0.5
			_zone_centre = _rng.randf_range(0.15 + half, 0.85 - half)
		_:
			_wanted.append(BUTTONS[_rng.randi() % BUTTONS.size()])
	if not get_tree().paused:
		get_tree().paused = true
		_paused_here = true
	_build()
	var done_in_time: bool = await finished
	_close()
	if _paused_here:
		get_tree().paused = false
	_paused_here = false
	_running = false
	return done_in_time


## What has to be pressed now - for a test, and the screen.
func wanted() -> StringName:
	return _wanted[mini(_at, _wanted.size() - 1)] if not _wanted.is_empty() else &""


## Where the Timing marker is, 0 to 1 along the bar.
func marker() -> float:
	if _def == null:
		return 0.0
	var sweep := fmod(_elapsed * _def.speed, 2.0)
	return sweep if sweep <= 1.0 else 2.0 - sweep


## Whether the Timing marker is in the zone now.
func in_zone() -> bool:
	return absf(marker() - _zone_centre) <= _def.zone * 0.5


## The zone's middle, 0 to 1 along the bar - for a test to wait for.
func zone_centre() -> float:
	return _zone_centre


## Presses `action`, as the player would.
func press(action: StringName):
	if not _running or _done:
		return
	match _def.kind:
		QuickTimeDefinition.Kind.PRESS:
			_end(action == _wanted[0])
		QuickTimeDefinition.Kind.SEQUENCE:
			if action != _wanted[_at]:
				_end(false)
				return
			_at += 1
			_refresh()
			if _at >= _wanted.size():
				_end(true)
		QuickTimeDefinition.Kind.MASH:
			if action != _wanted[0]:
				return
			_presses += 1
			_refresh()
			if _presses >= _def.count:
				_end(true)
		QuickTimeDefinition.Kind.TIMING:
			_end(in_zone())


func _input(event: InputEvent):
	if not _running:
		return
	# Nothing underneath hears anything while it is up.
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
	if _done:
		return
	for action in BUTTONS:
		if event.is_action_pressed(action, false, true):
			press(action)
			return


func _process(delta: float):
	if not _running or _done:
		return
	_elapsed += delta
	if _clock != null:
		_clock.value = maxf(_def.time - _elapsed, 0.0)
	if _marker != null and _track != null:
		_marker.position.x = marker() * (_track.size.x - _marker.size.x)
	if _elapsed >= _def.time:
		_end(false)


func _end(done_in_time: bool):
	if _done:
		return
	_done = true
	if _verdict != null:
		_verdict.text = "Done!" if done_in_time else "Too late!" if _elapsed >= _def.time else "Missed!"
		_verdict.add_theme_color_override("font_color", GOOD if done_in_time else BAD)
	if DisplayServer.get_name() != "headless":
		await get_tree().create_timer(RESULT_HOLD, true, false, true).timeout
	finished.emit(done_in_time)


## --- The screen ---

func _build():
	_layer = CanvasLayer.new()
	_layer.layer = LAYER
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(root)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.35)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(centre)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = BACK
	style.border_color = EDGE
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size.x = 460
	centre.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(column)
	_prompt = Label.new()
	_prompt.text = _def.prompt if _def.prompt != "" else _default_prompt()
	_prompt.theme_type_variation = GameFonts.HEADER
	_prompt.add_theme_font_size_override("font_size", 34)
	_prompt.add_theme_color_override("font_color", EDGE)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_prompt)
	var how := Label.new()
	how.text = _how_text()
	how.add_theme_color_override("font_color", DIM)
	how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(how)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 10)
	column.add_child(_row)
	if _def.kind == QuickTimeDefinition.Kind.TIMING:
		_track = Control.new()
		_track.custom_minimum_size = Vector2(420, 28)
		column.add_child(_track)
		var bar := ColorRect.new()
		bar.color = Color(1, 1, 1, 0.12)
		bar.set_anchors_preset(Control.PRESET_FULL_RECT)
		_track.add_child(bar)
		_zone = ColorRect.new()
		_zone.color = Color(GOOD, 0.55)
		_zone.position = Vector2((_zone_centre - _def.zone * 0.5) * 420.0, 0)
		_zone.size = Vector2(_def.zone * 420.0, 28)
		_track.add_child(_zone)
		_marker = ColorRect.new()
		_marker.color = TEXT
		_marker.size = Vector2(6, 28)
		_track.add_child(_marker)
	if _def.kind == QuickTimeDefinition.Kind.MASH:
		_mash = ProgressBar.new()
		_mash.max_value = _def.count
		_mash.show_percentage = false
		_mash.custom_minimum_size = Vector2(420, 14)
		column.add_child(_mash)
	_clock = ProgressBar.new()
	_clock.max_value = _def.time
	_clock.value = _def.time
	_clock.show_percentage = false
	_clock.custom_minimum_size = Vector2(420, 8)
	column.add_child(_clock)
	_verdict = Label.new()
	_verdict.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_verdict.add_theme_font_size_override("font_size", 22)
	column.add_child(_verdict)
	_refresh()


func _refresh():
	if _row == null:
		return
	for child in _row.get_children():
		child.queue_free()
	for i in _wanted.size():
		var face := PanelContainer.new()
		var look := StyleBoxFlat.new()
		var current := i == _at or _def.kind != QuickTimeDefinition.Kind.SEQUENCE
		look.bg_color = Color(EDGE, 0.25) if current else (Color(GOOD, 0.2) if i < _at else Color(1, 1, 1, 0.06))
		look.border_color = EDGE if current else DIM
		look.set_border_width_all(2)
		look.set_corner_radius_all(6)
		look.set_content_margin_all(10)
		face.add_theme_stylebox_override("panel", look)
		var label := Label.new()
		label.text = _button_name(_wanted[i])
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_color", TEXT if current else DIM)
		face.add_child(label)
		_row.add_child(face)
	if _mash != null:
		_mash.value = _presses


func _close():
	if _layer != null and is_instance_valid(_layer):
		_layer.queue_free()
	_layer = null
	_row = null
	_clock = null
	_mash = null
	_track = null
	_zone = null
	_marker = null
	_verdict = null
	_prompt = null


## The button as whatever was used last names it - the arrow key, or the pad's.
func _button_name(action: StringName) -> String:
	var pad = get_node_or_null("/root/Pad")
	var named: String = pad.key(action) if pad != null else ""
	return named if named != "" else String(action).trim_prefix("qte_").capitalize()


func _default_prompt() -> String:
	match _def.kind:
		QuickTimeDefinition.Kind.MASH:
			return "Keep pressing!"
		QuickTimeDefinition.Kind.TIMING:
			return "Now!"
	return "Quick!"


func _how_text() -> String:
	match _def.kind:
		QuickTimeDefinition.Kind.SEQUENCE:
			return "Press these in order"
		QuickTimeDefinition.Kind.MASH:
			return "Press it %d times" % _def.count
		QuickTimeDefinition.Kind.TIMING:
			return "Press %s as the marker crosses the green" % _button_name(&"qte_south")
	return "Press it"
