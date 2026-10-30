extends CanvasLayer
class_name CharacterChoice
## Whom the joiner's player plays, chosen as they first come into the host's
## game over a network - on a map, or into a fight under way (Net; the
## designer, 2026-10-30): a button for each of the party standing, pressed for
## theirs. The host keeps the rest, and at least one of them while there is
## anybody to keep. Done says so (chosen); choosing nobody watches for now. Over
## a network nothing waits for it - only this machine's own party stands while
## it is up (MenuPause). Later changes are asked for in the pause menu's Party
## Management.

signal chosen(keys: Array)

const INK := Color("dce8f5")
const MUTED := Color("8296a9")
const WARM := Color("e8c27a")

var _panel: PanelContainer = null
## Key -> its button.
var _buttons := {}
var _note: Label = null
var _gone := false


func _ready():
	name = "CharacterChoice"
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_panel.add_child(column)
	var title := Label.new()
	title.name = "Title"
	title.theme_type_variation = GameFonts.HEADER
	title.text = "Choose whom you play"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", INK)
	column.add_child(title)
	var hint := Label.new()
	hint.name = "Hint"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(560, 0)
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", MUTED)
	hint.text = "You have joined %s's game. Pick who you play; %s keeps the rest. To change it later, ask in the pause menu's Party Management." % [
		Coop.name_of(0), Coop.name_of(0)]
	column.add_child(hint)
	var row := HBoxContainer.new()
	row.name = "Party"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	var first: Button = null
	for key in PlayersPanel.party_now():
		var pick := Button.new()
		pick.name = key
		pick.toggle_mode = true
		pick.text = Campaign.display_name_of(key)
		pick.custom_minimum_size = Vector2(120, 40)
		pick.toggled.connect(_on_toggled.bind(key))
		row.add_child(pick)
		_buttons[key] = pick
		if first == null:
			first = pick
	_note = Label.new()
	_note.name = "Note"
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(560, 0)
	_note.add_theme_font_size_override("font_size", 14)
	_note.add_theme_color_override("font_color", WARM)
	if _buttons.size() < 2:
		_note.text = "There is only %s in the party - %s plays them for now." % [
			Campaign.display_name_of(_buttons.keys()[0]) if not _buttons.is_empty() else "nobody", Coop.name_of(0)]
		for key in _buttons:
			_buttons[key].disabled = true
	column.add_child(_note)
	var done := Button.new()
	done.name = "Done"
	done.text = "Done"
	done.custom_minimum_size = Vector2(220, 42)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.pressed.connect(_done)
	column.add_child(done)
	MenuPause.hold(self)
	FocusOnDemand.attach(self, first if first != null and not first.disabled else done)


func _process(_delta):
	# Centred by hand: anchors resolve against nothing under a bare CanvasLayer.
	_panel.reset_size()
	_panel.position = ((_panel.get_viewport_rect().size - _panel.size) / 2.0).round()


## The keys pressed, in marching order.
func picked() -> Array:
	return _buttons.keys().filter(func(key): return _buttons[key].button_pressed)


func _on_toggled(pressed: bool, key: String):
	# The host keeps somebody.
	if pressed and picked().size() >= _buttons.size():
		_buttons[key].set_pressed_no_signal(false)
		_note.text = "%s keeps at least one of the party." % Coop.name_of(0)
		return
	_note.text = ""


func _done():
	if _gone:
		return
	_gone = true
	MenuPause.release(self)
	chosen.emit(picked())
	queue_free()


func _exit_tree():
	MenuPause.release(self)
