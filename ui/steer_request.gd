extends CanvasLayer
class_name SteerRequest
## The other player, over a network, asking for a change in whom each steers
## (Net.ask_for; the designer, 2026-10-30): one of this player's characters for
## themselves, or one of their own for this player. This player's alone to
## answer. Only this machine's own party stands while it is up (MenuPause).
## Agree says yes; Refuse, or Cancel, no.

signal answered(yes: bool)

const INK := Color("dce8f5")
const MUTED := Color("8296a9")

## The character, who would steer them, and who asks - players by number.
var key := ""
var to := 0
var from := 0

var _panel: PanelContainer = null
var _gone := false


func _ready():
	name = "SteerRequest"
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
	title.add_theme_color_override("font_color", Coop.colour_of(from))
	title.text = ("%s asks to play %s" if to == from else "%s offers you %s") % [Coop.name_of(from), Campaign.display_name_of(key)]
	column.add_child(title)
	var detail := Label.new()
	detail.name = "Detail"
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_theme_font_size_override("font_size", 14)
	detail.add_theme_color_override("font_color", MUTED)
	detail.text = "%s would be %s's to steer, on the map and in fights." % [Campaign.display_name_of(key), Coop.name_of(to)]
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
	MenuPause.hold(self)
	FocusOnDemand.attach(self, agree)


func _process(_delta):
	# Centred by hand: anchors resolve against nothing under a bare CanvasLayer.
	_panel.reset_size()
	_panel.position = ((_panel.get_viewport_rect().size - _panel.size) / 2.0).round()


func answer(yes: bool):
	if _gone:
		return
	_gone = true
	MenuPause.release(self)
	answered.emit(yes)
	queue_free()


func _exit_tree():
	MenuPause.release(self)


func _unhandled_input(event: InputEvent):
	if _gone or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		answer(false)
