extends CanvasLayer
class_name ConversationMirror
## A conversation on the host's machine, shown on the joiner's (Net): the line,
## who says it, and the answers there are. The conversation itself runs only on
## the host. When the joiner's player began it they press on through its lines
## here, and that is sent back; otherwise this shows what the host's player is
## reading. An answer is both players' to choose (the designer, 2026-10-30):
## picked here, it is sent and the answers wait for the other's pick; picked
## differently, they come back with what each chose (choose_again). While it is
## up nothing else here hears a press but Escape, which is the pause menu's.
## While a picture the conversation opened is up here it steps aside, as the
## host's balloon does, and hears nothing.

const INK := Color("dce8f5")
const MUTED := Color("8296a9")

var _name: Label = null
var _text: RichTextLabel = null
var _answers: VBoxContainer = null
var _hint: Label = null
## Whether this machine's player is the one deciding.
var mine := false


func _ready():
	name = "ConversationMirror"
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.anchor_left = 0.08
	panel.anchor_right = 0.92
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -230
	panel.offset_bottom = -24
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	_name = Label.new()
	_name.name = "Speaker"
	_name.theme_type_variation = GameFonts.HEADER
	_name.add_theme_font_size_override("font_size", 20)
	_name.add_theme_color_override("font_color", INK)
	column.add_child(_name)
	_text = RichTextLabel.new()
	_text.name = "Line"
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.add_theme_font_size_override("normal_font_size", 18)
	column.add_child(_text)
	_answers = VBoxContainer.new()
	_answers.name = "Answers"
	_answers.add_theme_constant_override("separation", 4)
	column.add_child(_answers)
	_hint = Label.new()
	_hint.name = "Hint"
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.add_theme_color_override("font_color", MUTED)
	column.add_child(_hint)


## Shows `text`, said by `character`, with `answers` ([text, allowed] each) -
## chosen here when `is_mine`.
func show_line(character: String, text: String, answers: Array, is_mine: bool):
	mine = is_mine
	_name.visible = character != ""
	_name.text = character
	_text.text = text
	for child in _answers.get_children():
		_answers.remove_child(child)
		child.queue_free()
	_allowed.clear()
	var first: Button = null
	for i in answers.size():
		var button := Button.new()
		button.text = answers[i][0]
		button.disabled = not answers[i][1]
		button.pressed.connect(_pick.bind(i))
		_answers.add_child(button)
		_allowed.append(answers[i][1])
		if first == null and not button.disabled:
			first = button
	if not answers.is_empty():
		_hint.text = "Choose together - the answer you both pick is taken."
	elif not mine:
		_hint.text = "The other player is reading."
	else:
		_hint.text = "Press %s to go on" % Pad.key(&"ui_accept")
	if first != null:
		first.grab_focus()


## Which answers may be picked at all, by number.
var _allowed: Array = []


func _pick(index: int):
	Net.answer_line(index)
	show_pick_note("Waiting for the other player to choose...", true)


## How the choosing stands - `waiting` with this player's pick in, the answers
## put away until the other's comes.
func show_pick_note(text: String, waiting: bool):
	_hint.text = text
	for i in _answers.get_child_count():
		_answers.get_child(i).disabled = waiting or not _allowed[i]


## The picks differed: the answers again, and `text` saying what each chose.
func choose_again(text: String):
	show_pick_note(text, false)
	for child in _answers.get_children():
		if not child.disabled:
			child.grab_focus()
			break


func _process(_delta):
	visible = not _picture_up()


func _picture_up() -> bool:
	var pictures = get_node_or_null("/root/Pictures")
	return pictures != null and pictures.is_open()


func _unhandled_input(event: InputEvent):
	if not event.is_pressed() or event.is_echo() or _picture_up():
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		return
	get_viewport().set_input_as_handled()
	if not mine or _answers.get_child_count() > 0:
		return
	if event.is_action_pressed(&"ui_accept") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		Net.answer_line(-1)
