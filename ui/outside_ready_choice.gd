extends PanelContainer
class_name OutsideReadyChoice
## What a move readied on a map waits for (OutsideMoves "Readied, out of a
## fight"): a guard stepping into its reach, a guard stepping into an area marked
## with the next click on the map, or a guard in sight being hit by the party.
## The moves panel's Ready opens it. Holds the game while it is up (MenuPause).

signal closed

var scene: Node = null
var key := ""
var move := ""

var _gone := false


func _ready():
	name = "OutsideReadyChoice"
	process_mode = Node.PROCESS_MODE_ALWAYS
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "%s - for when?" % OutsideMoves.definition_of(move).name
	column.add_child(title)
	var first: Button = null
	for option in options():
		var button := Button.new()
		button.name = option.name
		button.text = option.text
		button.pressed.connect(_choose.bind(option))
		column.add_child(button)
		if first == null:
			first = button
	var cancel := Button.new()
	cancel.name = "Cancel"
	cancel.text = Pad.hint("Cancel", &"ui_cancel")
	cancel.pressed.connect(close)
	column.add_child(cancel)
	MenuPause.hold(self)
	FocusOnDemand.attach(self, first if first != null else cancel)


## What it could wait for: [{name, text, trigger, watched}].
func options() -> Array:
	var watch = scene.stealth
	var found := [
		{"name": "EntersReach", "text": "A guard steps into its reach", "trigger": SkillDefinition.Trigger.ENTERS_REACH, "watched": null},
		{"name": "EntersArea", "text": "A guard steps into an area you mark", "trigger": SkillDefinition.Trigger.ENTERS_AREA, "watched": null},
	]
	for guard in watch.guards:
		if is_instance_valid(guard) and guard.visible and watch.ready_refusal(key, move, SkillDefinition.Trigger.HIT_IN_SIGHT, StealthWatch.NO_TILE, guard) == "":
			found.append({"name": "Hit_" + String(guard.name), "text": "%s is hit" % watch._name_of(guard),
				"trigger": SkillDefinition.Trigger.HIT_IN_SIGHT, "watched": guard})
	return found


func _choose(option: Dictionary):
	var watch = scene.stealth
	close()
	if option.trigger == SkillDefinition.Trigger.ENTERS_AREA:
		watch.mark_ready_area(key, move)
		return
	var refused: String = watch.ready_refusal(key, move, option.trigger, StealthWatch.NO_TILE, option.watched)
	if refused != "" and scene.has_method("log_message"):
		scene.log_message(refused + ".\n")
	watch.ready_outside(key, move, option.trigger, StealthWatch.NO_TILE, option.watched)


func _process(_delta):
	# Centred by hand: anchors resolve against nothing under a bare CanvasLayer.
	reset_size()
	position = ((get_viewport_rect().size - size) / 2.0).round()


func _exit_tree():
	MenuPause.release(self)


func close():
	if _gone:
		return
	_gone = true
	MenuPause.release(self)
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent):
	if _gone or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
