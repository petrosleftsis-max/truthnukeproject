extends PanelContainer
## The choice of which spell to cast on a stealth map, when the party knows more
## than one - Invisibility (Prometheus) and Find Familiar (Alithia). The Outside
## Spell key (G) opens it; with only one known, it goes straight to that one.
## Holds the game while it is up (MenuPause), as the invisibility picker does.

signal closed

const MUTED := Color("8296a9")

var watch: StealthWatch = null
## The stealth bar, which opens the invisibility picker.
var bar: StealthBar = null

var _gone := false


func _ready():
	name = "OutsideSpellChoice"
	process_mode = Node.PROCESS_MODE_ALWAYS
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "Which spell?"
	column.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	var hide := Button.new()
	hide.name = "Invisibility"
	var spell: Dictionary = watch.invisibility_spell()
	hide.text = SkillDatabase.skills[spell.skill].name if not spell.is_empty() else "Invisibility"
	hide.disabled = spell.is_empty() or watch.could_go_invisible().is_empty()
	hide.pressed.connect(_hide)
	row.add_child(hide)
	var call := Button.new()
	call.name = "Familiar"
	var familiar: Dictionary = watch.familiar_spell()
	call.text = SkillDatabase.skills[familiar.skill].name if not familiar.is_empty() else "Find Familiar"
	var refusal: String = watch.familiar_refusal()
	call.disabled = refusal != ""
	call.tooltip_text = refusal
	call.pressed.connect(_call)
	row.add_child(call)
	var cancel := Button.new()
	cancel.name = "Cancel"
	cancel.text = Pad.hint("Cancel", &"ui_cancel")
	cancel.pressed.connect(close)
	column.add_child(cancel)
	MenuPause.hold(self)
	FocusOnDemand.attach(self, hide if not hide.disabled else (call if not call.disabled else cancel))


func _process(_delta):
	# Centred by hand: anchors resolve against nothing under a bare CanvasLayer.
	reset_size()
	position = ((get_viewport_rect().size - size) / 2.0).round()


func _exit_tree():
	MenuPause.release(self)


## On to who to hide.
func _hide():
	close()
	if bar != null:
		bar.open_picker()


## Calls the familiar.
func _call():
	close()
	watch.summon_familiar()


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
