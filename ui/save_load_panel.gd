extends VBoxContainer
class_name SaveLoadPanel
## The list of saves, to save into or load from (SaveGame). Saving offers the
## three slots; loading offers those and the three automatic saves made before
## fights. Writing over a save, and loading in the middle of a run, ask first.
##
## Built in code, by the pause menu and the title screen.

## Back was pressed.
signal closed

const MUTED := Color("8296a9")
const GOLD := Color(1.0, 0.84, 0.35)

## Saving rather than loading.
var saving := false
## Whether loading asks first - not from the title screen, where nothing is lost.
var asks_before_loading := true
## The slot waiting to be confirmed, or "".
var pending := ""

var _list: VBoxContainer = null
var _note: Label = null
var _confirm_row: HBoxContainer = null
var _confirm_text: Label = null
var _yes: Button = null
var _back: Button = null
var _focus: FocusOnDemand = null


## Builds it for saving or for loading.
func open_as(save: bool, ask_before_loading: bool = true):
	saving = save
	asks_before_loading = ask_before_loading
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 12)
	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "Save Game" if saving else "Load Game"
	add_child(title)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	add_child(_list)
	_note = Label.new()
	_note.name = "Note"
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.add_theme_color_override("font_color", GOLD)
	add_child(_note)
	_confirm_row = HBoxContainer.new()
	_confirm_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_confirm_row.add_theme_constant_override("separation", 10)
	_confirm_row.visible = false
	add_child(_confirm_row)
	_confirm_text = Label.new()
	_confirm_row.add_child(_confirm_text)
	_yes = Button.new()
	_yes.name = "Yes"
	_yes.text = "Yes"
	_yes.pressed.connect(_on_yes)
	_confirm_row.add_child(_yes)
	var no := Button.new()
	no.name = "No"
	no.text = "No"
	no.pressed.connect(_on_no)
	_confirm_row.add_child(no)
	_back = Button.new()
	_back.name = "Back"
	_back.text = "Back"
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back.pressed.connect(func(): closed.emit())
	add_child(_back)
	redraw()


## The slots as they stand now.
func redraw():
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var slots: Array = SaveGame.MANUAL_SLOTS if saving else SaveGame.AUTO_SLOTS + SaveGame.MANUAL_SLOTS
	var first: Control = null
	for slot in slots:
		var button := Button.new()
		button.name = "Slot_" + slot
		button.text = SaveGame.describe(slot)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(560, 0)
		# Nothing to load from an empty one.
		button.disabled = not saving and not SaveGame.exists(slot)
		button.pressed.connect(_on_slot.bind(slot))
		_list.add_child(button)
		if first == null and not button.disabled:
			first = button
	if first == null:
		first = _back
	if _focus == null:
		_focus = FocusOnDemand.attach(self, first)
	else:
		_focus.remember(first)


func _on_slot(slot: String):
	_note.text = ""
	if saving and SaveGame.exists(slot):
		_ask(slot, "Write over this save?")
	elif saving:
		_save(slot)
	elif asks_before_loading:
		_ask(slot, "Load it? Anything since the last save is lost.")
	else:
		SaveGame.load_slot(slot)


func _ask(slot: String, question: String):
	pending = slot
	_confirm_text.text = question
	_confirm_row.visible = true
	_yes.grab_focus.call_deferred()


func _on_yes():
	var slot := pending
	pending = ""
	_confirm_row.visible = false
	if saving:
		_save(slot)
	else:
		SaveGame.load_slot(slot)


func _on_no():
	pending = ""
	_confirm_row.visible = false


func _save(slot: String):
	var why := SaveGame.why_not(get_tree())
	if why != "":
		_note.text = why
		return
	_note.text = "Saved." if SaveGame.save(slot, get_tree()) else "It could not be saved."
	redraw()
