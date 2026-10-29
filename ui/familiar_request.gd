extends PanelContainer
class_name FamiliarRequest
## The other co-op player asking for the familiar (FamiliarKeeper
## .request_control - the designer, 2026-10-29): the question is put to the
## player who steers its caster, and only theirs to answer (Coop.take_focus).
## Holds the game while it is up (MenuPause). Allow hands it over; Refuse, or
## Cancel, keeps it.

signal answered(yes: bool)

var keeper: FamiliarKeeper = null
## Who asks, and who is asked - players, by number.
var asker := -1
var asked := 0

var _gone := false


func _ready():
	name = "FamiliarRequest"
	process_mode = Node.PROCESS_MODE_ALWAYS
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var title := Label.new()
	title.name = "Title"
	title.theme_type_variation = &"HeaderLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var animal: String = keeper.familiar.form.name.to_lower() if keeper != null and keeper.familiar != null else "familiar"
	title.text = "%s asks to steer the %s" % [Coop.name_of(asker), animal]
	title.add_theme_color_override("font_color", Coop.colour_of(asker))
	column.add_child(title)
	var who := Label.new()
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	who.text = "%s, %s's familiar is yours to give." % [Coop.name_of(asked), Campaign.display_name_of(keeper.caster) if keeper != null else "Alithia"]
	who.add_theme_color_override("font_color", Coop.colour_of(asked))
	column.add_child(who)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	var allow := Button.new()
	allow.name = "Allow"
	allow.text = "Allow"
	allow.pressed.connect(answer.bind(true))
	row.add_child(allow)
	var refuse := Button.new()
	refuse.name = "Refuse"
	refuse.text = Pad.hint("Refuse", &"ui_cancel")
	refuse.pressed.connect(answer.bind(false))
	row.add_child(refuse)
	# The game held, and the question theirs alone - not whoever pressed to ask.
	Coop.acting = Coop.ANYONE
	MenuPause.hold(self)
	Coop.take_focus(asked, self)
	FocusOnDemand.attach(self, allow)


func _process(_delta):
	# Centred by hand: anchors resolve against nothing under a bare CanvasLayer.
	reset_size()
	position = ((get_viewport_rect().size - size) / 2.0).round()


func answer(yes: bool):
	if _gone:
		return
	_gone = true
	Coop.let_go(self)
	MenuPause.release(self)
	answered.emit(yes)
	queue_free()


func _exit_tree():
	if not _gone:
		Coop.let_go(self)
		MenuPause.release(self)


func _unhandled_input(event: InputEvent):
	if _gone or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		answer(false)
