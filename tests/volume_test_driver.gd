extends Node
## The volume sliders: fine with a mouse, quick with a keyboard, and the same
## in both menus because both build the same thing.

var LOG_PATH := HarnessLog.path_for("volume")
var _log: FileAccess
var _fail = 0

func log_line(t): _log.store_line(t); _log.flush()

func ok(condition: bool, label: String, detail: String = ""):
	if condition:
		log_line("  PASS  %s %s" % [label, detail])
	else:
		_fail += 1
		log_line("  FAIL  %s %s" % [label, detail])


func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(120.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	await run_test()


## The event a key press arrives as, for a slider that has focus.
func press(action: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func run_test():
	var panel := VolumeSliders.new()
	add_child(panel)
	await get_tree().process_frame

	log_line("======== both buses get a slider ========")
	var sliders = panel.sliders()
	ok(sliders.size() == VolumeSliders.ROWS.size(),
		"one for each bus Music knows", "%d sliders, %d buses"
			% [sliders.size(), VolumeSliders.ROWS.size()])
	if sliders.is_empty():
		finish()
		return
	log_line("")

	log_line("======== a drag moves it a percent at a time ========")
	for slider in sliders:
		ok(is_equal_approx(slider.step, 0.01), "%s steps by one percent" % slider.name,
			"%.3f" % slider.step)
		# Every level it can show has to be one it can sit on, or the readout
		# names numbers the slider cannot reach.
		var reachable = is_equal_approx(fmod(1.0, slider.step), 0.0) \
			or is_equal_approx(fmod(1.0, slider.step), slider.step)
		ok(reachable, "and the whole range divides by it")
	log_line("")

	log_line("======== a key press moves it five ========")
	var slider = sliders[0]
	slider.value = 0.5
	slider.gui_input.emit(press("ui_right"))
	ok(is_equal_approx(slider.value, 0.5 + VolumeSliders.KEY_STEP),
		"right goes up by five percent", "%.2f" % slider.value)
	slider.gui_input.emit(press("ui_left"))
	slider.gui_input.emit(press("ui_left"))
	ok(is_equal_approx(slider.value, 0.5 - VolumeSliders.KEY_STEP),
		"and left comes back down", "%.2f" % slider.value)

	# Up and down are how both menus move from one control to the next, so the
	# slider must not swallow them - or the keyboard is stuck on it.
	var before = slider.value
	slider.gui_input.emit(press("ui_up"))
	slider.gui_input.emit(press("ui_down"))
	ok(is_equal_approx(slider.value, before),
		"up and down are left for moving between controls", "%.2f" % slider.value)
	log_line("")

	log_line("======== it stops at the ends ========")
	slider.value = slider.max_value
	slider.gui_input.emit(press("ui_right"))
	ok(is_equal_approx(slider.value, slider.max_value), "full stays full",
		"%.2f" % slider.value)
	slider.value = slider.min_value
	slider.gui_input.emit(press("ui_left"))
	ok(is_equal_approx(slider.value, slider.min_value), "and silent stays silent",
		"%.2f" % slider.value)
	log_line("")

	log_line("======== moving it is what actually changes the volume ========")
	var bus = VolumeSliders.ROWS[0].bus
	slider.value = 0.5
	slider.gui_input.emit(press("ui_right"))
	ok(is_equal_approx(Music.volume(bus), slider.value),
		"Music hears what the slider says", "%.2f on the bus, %.2f on the slider"
			% [Music.volume(bus), slider.value])
	# And the number beside it, which is the only way to read a slider exactly.
	# The one in this slider's own row: searching the whole panel found the
	# other bus's readout and compared it against this bus's value.
	var readout: Label = null
	for child in slider.get_parent().find_children("*", "Label", true, false):
		if readout == null and child.text.ends_with("%"):
			readout = child
	ok(readout != null and readout.text == "%d%%" % roundi(slider.value * 100.0),
		"and the readout says the same", readout.text if readout != null else "none")

	finish()


func finish():
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
