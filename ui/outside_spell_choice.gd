extends PanelContainer
## The choice of which spell to cast on a map, when there is more than one to
## cast: on a watched map Invisibility (Prometheus) and Find Familiar (Alithia),
## and anywhere the spells that would do something now (OutsideMoves.ready_spells
## - a heal with somebody hurt, Resuscitate with somebody down). The Outside Spell key (G) opens it;
## with only one, it goes straight to that one. Holds the game while it is up
## (MenuPause), as the invisibility picker does.

signal closed

const MUTED := Color("8296a9")

var watch: StealthWatch = null
## The stealth bar, which opens the invisibility picker.
var bar: StealthBar = null
## The map, for the other spells - the watch's, on a watched one.
var scene: Node = null

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
	if scene == null and watch != null:
		scene = watch.scene
	var first: Button = null
	if watch != null and not watch.invisibility_spell().is_empty():
		var hide := Button.new()
		hide.name = "Invisibility"
		hide.text = SkillDatabase.skills[watch.invisibility_spell().skill].name
		hide.disabled = watch.could_go_invisible().is_empty()
		hide.pressed.connect(_hide)
		row.add_child(hide)
		if not hide.disabled:
			first = hide
	if watch != null and not watch.familiar_spell().is_empty():
		var call := Button.new()
		call.name = "Familiar"
		call.text = SkillDatabase.skills[watch.familiar_spell().skill].name
		var refusal: String = watch.familiar_refusal()
		call.disabled = refusal != ""
		call.tooltip_text = refusal
		call.pressed.connect(_call)
		row.add_child(call)
		if first == null and not call.disabled:
			first = call
	for ready in OutsideMoves.ready_spells(scene):
		var skill: SkillDefinition = SkillDatabase.skills[ready.move]
		var cast := Button.new()
		cast.name = ready.move
		cast.text = "%s (%s)" % [skill.name, Campaign.display_name_of(ready.key)]
		cast.tooltip_text = "%s - %s" % [OutsideMoves.USE_NAMES[OutsideMoves.use_of(skill)], OutsideMoves.noise_fact(skill)]
		cast.pressed.connect(_cast.bind(ready.key, ready.move))
		row.add_child(cast)
		if first == null:
			first = cast
	var cancel := Button.new()
	cancel.name = "Cancel"
	cancel.text = Pad.hint("Cancel", &"ui_cancel")
	cancel.pressed.connect(close)
	column.add_child(cancel)
	MenuPause.hold(self)
	FocusOnDemand.attach(self, first if first != null else cancel)


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


## `key` casts `move` (OutsideMoves).
func _cast(key: String, move: String):
	close()
	OutsideMoves.use(scene, key, move)


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
