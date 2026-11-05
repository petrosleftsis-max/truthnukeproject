extends CanvasLayer
class_name ConversationMirror
## A conversation on the host's machine, shown on the joiner's (Net): the line,
## who says it, their portrait, and the answers there are - laid out and coloured
## as the host's balloon has them (ui/dialogue_balloon.tscn), so both players see
## the same thing (the designer, 2026-11-04: "No portrait or color for names in
## dialogue for players who didn't initiate dialogue"). The conversation itself
## runs only on the host. When the joiner's player began it they press on through
## its lines here, and that is sent back; otherwise this shows what the host's
## player is reading. An answer is both players' to choose (the designer,
## 2026-10-30): picked here, it is sent and the answers wait for the other's pick;
## picked differently, they come back with what each chose (choose_again). While
## it is up nothing else here hears a press but Escape, which is the pause menu's.
## While a picture the conversation opened is up here it steps aside, as the
## host's balloon does, and hears nothing.

const MUTED := Color("8296a9")
## The speaker's name, as the balloon's Character Label has it.
const NAME_COLOUR := Color(0.290196, 0.52549, 0.784314, 1)
## How long a character takes to type out, as the balloon's Dialogue Label has it.
const SECONDS_A_LETTER := 0.02

var _portrait: TextureRect = null
var _name: RichTextLabel = null
var _text: RichTextLabel = null
var _answers: VBoxContainer = null
var _hint: Label = null
var _typing: Tween = null
## Whether this machine's player is the one deciding.
var mine := false


func _ready():
	name = "ConversationMirror"
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Over the whole screen, as the balloon is: a click anywhere presses on, and
	# none goes through to the map behind.
	var balloon := Control.new()
	balloon.name = "Balloon"
	balloon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var look := Theme.new()
	look.default_font_size = 20
	look.set_constant("margin_left", "MarginContainer", 30)
	look.set_constant("margin_right", "MarginContainer", 30)
	look.set_constant("margin_top", "MarginContainer", 15)
	look.set_constant("margin_bottom", "MarginContainer", 15)
	balloon.theme = look
	balloon.gui_input.connect(_on_balloon_input)
	add_child(balloon)
	var along_the_bottom := MarginContainer.new()
	along_the_bottom.anchor_top = 1.0
	along_the_bottom.anchor_right = 1.0
	along_the_bottom.anchor_bottom = 1.0
	along_the_bottom.offset_top = -219.0
	along_the_bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	balloon.add_child(along_the_bottom)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	along_the_bottom.add_child(panel)
	var inside := MarginContainer.new()
	panel.add_child(inside)
	var row := HBoxContainer.new()
	inside.add_child(row)
	_portrait = TextureRect.new()
	_portrait.name = "Portrait"
	_portrait.visible = false
	_portrait.custom_minimum_size = Vector2(180, 180)
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_portrait)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	_name = RichTextLabel.new()
	_name.name = "Speaker"
	_name.bbcode_enabled = true
	_name.fit_content = true
	_name.scroll_active = false
	_name.mouse_filter = Control.MOUSE_FILTER_PASS
	_name.add_theme_color_override("default_color", NAME_COLOUR)
	var display := GameFonts.display_font()
	if display != null:
		_name.add_theme_font_override("normal_font", display)
	column.add_child(_name)
	_text = RichTextLabel.new()
	_text.name = "Line"
	_text.bbcode_enabled = true
	_text.scroll_active = false
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(_text)
	_hint = Label.new()
	_hint.name = "Hint"
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.add_theme_color_override("font_color", MUTED)
	column.add_child(_hint)
	# In the middle of the screen, over the rest, as the balloon's.
	var middle := CenterContainer.new()
	middle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	balloon.add_child(middle)
	_answers = VBoxContainer.new()
	_answers.name = "Answers"
	_answers.add_theme_constant_override("separation", 2)
	_answers.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.add_child(_answers)


## Shows `text`, said by `character` - their portrait by `tags`, as the balloon
## finds it - with `answers` ([text, allowed] each) - chosen here when `is_mine`.
func show_line(character: String, text: String, answers: Array, is_mine: bool, tags: Array = []):
	mine = is_mine
	_name.visible = character != ""
	_name.text = tr(character, "dialogue")
	var face := DialogueBalloon.portrait_of(character, tags)
	_portrait.texture = face
	_portrait.visible = face != null
	_text.text = text
	_type_out(text)
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


## The line typed out as the balloon's is, letter by letter.
func _type_out(text: String):
	if _typing != null and _typing.is_valid():
		_typing.kill()
	_text.visible_ratio = 0.0
	_typing = create_tween()
	_typing.tween_property(_text, "visible_ratio", 1.0, maxf(text.length() * SECONDS_A_LETTER, 0.01))


func _finish_typing():
	if _typing != null and _typing.is_valid():
		_typing.kill()
	_text.visible_ratio = 1.0


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
	if event.is_action_pressed(&"ui_accept"):
		_press_on()


## A click anywhere on the screen, as on the balloon.
func _on_balloon_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not _picture_up():
		_press_on()


## Pressed on through the line, if it is this player's to: the line finished
## here, and the host told.
func _press_on():
	if not mine or _answers.get_child_count() > 0:
		return
	_finish_typing()
	Net.answer_line(-1)
