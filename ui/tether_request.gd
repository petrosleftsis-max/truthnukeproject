extends CanvasLayer
class_name TetherRequest
## The other player asking to end a tether this player holds (the designer, 2026-11-07: "if a player
## tries to cancel another player's tether effect, a request is sent to the other player to accept or
## not"). Theirs alone to answer: on one screen the question is given to them (Coop.take_focus), and over
## a network it opens on their own machine (Net.ask_to_let_go). The game stands while it is up. Agree
## says yes; Refuse, or Cancel, no.

signal answered(yes: bool)

const MUTED := Color("8296a9")

## Who asks and who is asked, players by number; who holds it, and what.
var asker := 0
var asked := 0
var holder_name := ""
var spell_name := ""

var _panel: PanelContainer = null
var _gone := false


func _ready():
	name = "TetherRequest"
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)
	var title := Label.new()
	title.name = "Title"
	title.theme_type_variation = GameFonts.HEADER
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Coop.colour_of(asker))
	title.text = "%s asks you to end %s" % [Coop.name_of(asker), spell_name]
	column.add_child(title)
	var detail := Label.new()
	detail.name = "Detail"
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_theme_font_size_override("font_size", 14)
	detail.add_theme_color_override("font_color", MUTED)
	detail.text = "%s holds it on a tether. Ending it costs nothing, and it is gone for good." % holder_name
	column.add_child(detail)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	var agree := Button.new()
	agree.name = "Agree"
	agree.text = "Agree"
	agree.custom_minimum_size = Vector2(120, 38)
	agree.pressed.connect(answer.bind(true))
	row.add_child(agree)
	var refuse := Button.new()
	refuse.name = "Refuse"
	refuse.text = Pad.hint("Refuse", &"ui_cancel")
	refuse.custom_minimum_size = Vector2(120, 38)
	refuse.pressed.connect(answer.bind(false))
	row.add_child(refuse)
	Coop.acting = Coop.ANYONE
	MenuPause.hold(self)
	if Coop.is_local(asked):
		Coop.take_focus(asked, self)
	FocusOnDemand.attach(self, agree)


func _process(_delta):
	_panel.reset_size()
	_panel.position = ((_panel.get_viewport_rect().size - _panel.size) / 2.0).round()


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
	if not _gone and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		answer(false)
