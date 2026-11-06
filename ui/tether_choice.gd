extends CanvasLayer
class_name TetherChoice
## Right clicked on what a tether holds (Combat "Letting go of a tether", StealthWatch "Tethers, out of
## a fight"): a little menu beside the pointer, asking if they are sure (the designer, 2026-11-07): what
## can be ended there, or asked for, and Keep. Nothing ends until one of those is chosen. The game
## stands while it is up (MenuPause). Keep, Cancel, a right click or a click anywhere else keeps it.

signal chosen(index: int)

const INK := Color("dce8f5")

## What each button says, in the order chosen answers.
var entries: Array = []
## Where on the screen it opens.
var at := Vector2.ZERO
## Whose question it is, on one screen.
var player := -1

var _panel: PanelContainer = null
var _gone := false


func _ready():
	name = "TetherChoice"
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_panel.add_child(column)
	var sure := Label.new()
	sure.name = "Sure"
	sure.text = "Are you sure?"
	sure.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sure.add_theme_color_override("font_color", INK)
	column.add_child(sure)
	var first: Button = null
	for i in entries.size():
		var button := Button.new()
		button.name = "Choice%d" % i
		button.text = entries[i]
		button.custom_minimum_size = Vector2(200, 34)
		button.pressed.connect(_choose.bind(i))
		column.add_child(button)
		if first == null:
			first = button
	var keep := Button.new()
	keep.name = "Keep"
	keep.text = Pad.hint("Keep it", &"ui_cancel")
	keep.custom_minimum_size = Vector2(200, 34)
	keep.pressed.connect(close)
	column.add_child(keep)
	Coop.acting = Coop.ANYONE
	MenuPause.hold(self)
	if player >= 0:
		Coop.take_focus(player, self)
	FocusOnDemand.attach(self, keep)


func _process(_delta):
	_panel.reset_size()
	var room: Vector2 = _panel.get_viewport_rect().size - _panel.size
	_panel.position = Vector2(clampf(at.x + 8.0, 0.0, maxf(room.x, 0.0)), clampf(at.y + 8.0, 0.0, maxf(room.y, 0.0))).round()


func _choose(index: int):
	if _gone:
		return
	close()
	chosen.emit(index)


func close():
	if _gone:
		return
	_gone = true
	if player >= 0:
		Coop.let_go(self)
	MenuPause.release(self)
	queue_free()


func _exit_tree():
	if not _gone:
		if player >= 0:
			Coop.let_go(self)
		MenuPause.release(self)


func _input(event: InputEvent):
	if _gone or _panel == null:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT or not _panel.get_global_rect().has_point(event.position):
			get_viewport().set_input_as_handled()
			close()


func _unhandled_input(event: InputEvent):
	if not _gone and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
