extends Node
## Autoload. The journal: every clue the party has learned (see
## ClueDefinition), opened with J or the Journal button under a picture.
##
## Pick two and press Connect to work something out from them - a deduction,
## if they make one. And a conversation can ask the player to show somebody a
## clue or an item, then go on according to what was shown:
##
##     do Journal.present("What do you show the captain?")
##     if Journal.presented == "skimming"
##         Captain: ...where did you get that?
##     elif Journal.presented == ""
##         Captain: Well?
##     else
##         Captain: And what is that supposed to prove?
##
## Journal is a Dialogue Manager state shortcut (project.godot), like Pictures.
## While it is open the game is held (MenuPause) - unless something else, the
## pause menu or the character sheet, is holding it already: then it does not
## open at all.

## Whatever was shown at the last present(): a clue's key, an item's key, or ""
## for nothing (backed out).
var presented := ""
## "clue" or "item" for what was shown, "" for nothing.
var presented_kind := ""

signal _done

## Over the pictures (25) and the dialogue balloon (30), which a conversation
## asking for something to show is still holding.
const LAYER := 40
const TOAST_LAYER := 45
## The scenes J opens it in, besides anywhere a picture is up.
const OPENS_IN := ["res://scenes/exploration.tscn", "res://scenes/game.tscn"]

const INK := Color("dce8f5")
const MUTED := Color("8296a9")
const GOLD := Color(1.0, 0.84, 0.35)
const PANEL := Color("19212c")
const CARD := Color("1c2531")
const CARD_LIT := Color("24344a")
const CARD_EDGE := Color("2b3947")

enum Mode { BROWSE, PRESENT }

var _mode := Mode.BROWSE
var _prompt := ""
var _layer: CanvasLayer = null
var _list: VBoxContainer = null
var _detail_title: Label = null
var _detail_text: Label = null
var _detail_from: Label = null
var _result: Label = null
var _connect: Button = null
var _present: Button = null
## What is picked, oldest first: [{"kind": "clue"/"item", "key": ...}].
var _picked: Array = []
var _toast_layer: CanvasLayer = null


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not Campaign.clue_learned.is_connected(_on_clue_learned):
		Campaign.clue_learned.connect(_on_clue_learned)


func is_open() -> bool:
	return _layer != null


## Opens it to look through, and to connect clues in.
func open():
	if is_open():
		return
	_mode = Mode.BROWSE
	_prompt = ""
	_show()


## Asks the player to show something - a clue, or an item from the bag - and
## waits until they have, or backed out. What was shown is in `presented`.
func present(prompt: String = "") -> void:
	presented = ""
	presented_kind = ""
	if is_open():
		close()
	_mode = Mode.PRESENT
	_prompt = prompt
	_show()
	await _done


## Whether the last thing shown was any of `keys`.
func presented_any(keys: Array) -> bool:
	return presented != "" and keys.has(presented)


func close():
	if _layer == null:
		return
	_layer.queue_free()
	_layer = null
	_picked.clear()
	MenuPause.release(self)
	if _mode == Mode.PRESENT:
		_mode = Mode.BROWSE
		_done.emit()


## --- What the buttons do, for anybody else to do too ---


## Picks `key` - a clue, or (when showing something) an item - as the button for
## it would.
func pick(key: String):
	var kind = "clue" if Campaign.knows_clue(key) else "item"
	for entry in _picked:
		if entry.key == key:
			_picked.erase(entry)
			_rebuild()
			return
	_picked.append({"kind": kind, "key": key})
	var keep = 1 if _mode == Mode.PRESENT else 2
	while _picked.size() > keep:
		_picked.pop_front()
	_rebuild()


## Connects the two clues picked. The deduction they make (new or not), or "".
func connect_picked() -> String:
	if _picked.size() != 2:
		return ""
	var a: String = _picked[0].key
	var b: String = _picked[1].key
	var deduced = ClueBook.deduced_from(a, b)
	var knew = deduced != "" and Campaign.knows_clue(deduced)
	Campaign.connect_clues(a, b)
	_play("no_deduction" if deduced == "" else ("look" if knew else ""))
	if deduced == "":
		_say("These two don't connect.")
	elif knew:
		_say("Already worked out: %s." % _title_of(deduced))
	else:
		_say("Worked out: %s." % _title_of(deduced))
	_picked.clear()
	if deduced != "":
		_picked.append({"kind": "clue", "key": deduced})
	_rebuild()
	return deduced


## Shows the one thing picked, when asked to show something.
func present_picked():
	if _mode != Mode.PRESENT or _picked.size() != 1:
		return
	presented = _picked[0].key
	presented_kind = _picked[0].kind
	_play("present")
	close()


## Picks `key` and shows it, all at once.
func choose(key: String):
	if not (_picked.size() == 1 and _picked[0].key == key):
		_picked.clear()
		pick(key)
	present_picked()


## Backs out: shows nothing.
func cancel():
	presented = ""
	presented_kind = ""
	close()


## The keys listed right now, clues first.
func listed() -> Array:
	var keys: Array = Campaign.known_clues().duplicate()
	if _mode == Mode.PRESENT:
		keys.append_array(_bag_items())
	return keys


## The line under the lists - what Connect said.
func result_text() -> String:
	return _result.text if _result != null else ""


## --- Building it ---


func _show():
	if MenuPause.held_by_another(self):
		# The pause menu, or the character sheet: not the moment. Asked from a
		# conversation, it still has to answer, so it shows nothing.
		if _mode == Mode.PRESENT:
			_mode = Mode.BROWSE
			_done.emit.call_deferred()
		return
	MenuPause.hold(self)
	_picked.clear()
	_build()
	_rebuild()
	_play("journal")


func _build():
	_layer = CanvasLayer.new()
	_layer.name = "Journal"
	_layer.layer = LAYER
	add_child(_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(centre)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1000, 580)
	panel.add_theme_stylebox_override("panel", _box(PANEL, CARD_EDGE, 18))
	centre.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var heading := Label.new()
	heading.theme_type_variation = GameFonts.HEADER
	heading.add_theme_font_size_override("font_size", 30)
	heading.text = "Show something" if _mode == Mode.PRESENT else "Journal"
	column.add_child(heading)
	var hint := Label.new()
	hint.add_theme_color_override("font_color", GOLD if _mode == Mode.PRESENT else MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = _prompt if _mode == Mode.PRESENT and _prompt != "" else \
		("Pick a clue, or something from the bag, and show it." if _mode == Mode.PRESENT \
		else "Pick two clues and Connect them to work something out.")
	column.add_child(hint)
	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 16)
	column.add_child(middle)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(380, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	middle.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)
	var detail_panel := PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", _box(CARD, CARD_EDGE, 14))
	middle.add_child(detail_panel)
	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 8)
	detail_panel.add_child(detail)
	_detail_title = Label.new()
	_detail_title.theme_type_variation = GameFonts.HEADER
	_detail_title.add_theme_font_size_override("font_size", 24)
	_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(_detail_title)
	_detail_text = Label.new()
	_detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_text.add_theme_color_override("font_color", INK)
	detail.add_child(_detail_text)
	_detail_from = Label.new()
	_detail_from.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_from.add_theme_color_override("font_color", MUTED)
	detail.add_child(_detail_from)
	_result = Label.new()
	_result.add_theme_color_override("font_color", GOLD)
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_result)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 10)
	column.add_child(buttons)
	if _mode == Mode.PRESENT:
		_present = _button("Show it", present_picked)
		buttons.add_child(_present)
		buttons.add_child(_button("Show nothing (Esc)", cancel))
		_connect = null
	else:
		_connect = _button("Connect", func(): connect_picked())
		buttons.add_child(_connect)
		buttons.add_child(_button("Close (J)", close))
		_present = null


func _rebuild():
	if _list == null or not is_instance_valid(_list):
		return
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var clues: Array = Campaign.known_clues()
	if clues.is_empty() and (_mode == Mode.BROWSE or _bag_items().is_empty()):
		var none := Label.new()
		none.text = "Nothing written down yet."
		none.add_theme_color_override("font_color", MUTED)
		_list.add_child(none)
	for key in clues:
		var clue: ClueDefinition = ClueBook.clue(key)
		if clue != null:
			_list.add_child(_entry(key, clue.title if clue.title != "" else key, clue.icon, clue.is_deduction()))
	if _mode == Mode.PRESENT:
		var items = _bag_items()
		if not items.is_empty():
			var heading := Label.new()
			heading.text = "In the bag"
			heading.add_theme_color_override("font_color", MUTED)
			_list.add_child(heading)
			for key in items:
				var item: ItemDefinition = ItemDatabase.item(key)
				_list.add_child(_entry(key, item.name, item.icon, false))
	_show_detail()
	if _connect != null:
		_connect.disabled = _picked.size() != 2
	if _present != null:
		_present.disabled = _picked.size() != 1


func _entry(key: String, label: String, icon: Texture2D, deduced: bool) -> Button:
	var button := Button.new()
	button.name = key
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text = label
	button.icon = icon
	button.expand_icon = false
	button.add_theme_constant_override("icon_max_width", 28)
	button.button_pressed = _is_picked(key)
	if deduced:
		button.add_theme_color_override("font_color", GOLD)
		button.add_theme_color_override("font_pressed_color", GOLD)
		button.tooltip_text = "Worked out"
	button.pressed.connect(pick.bind(key))
	return button


## The newest thing picked, written out on the right.
func _show_detail():
	if _picked.is_empty():
		_detail_title.text = ""
		_detail_text.text = "Pick something to read it."
		_detail_from.text = ""
		return
	var entry: Dictionary = _picked.back()
	if entry.kind == "clue":
		var clue: ClueDefinition = ClueBook.clue(entry.key)
		_detail_title.text = clue.title if clue != null else entry.key
		_detail_text.text = clue.text if clue != null else ""
		_detail_from.text = ""
		if clue != null and clue.is_deduction():
			_detail_from.text = "Worked out from: %s and %s" % [_title_of(clue.from_clues[0]), _title_of(clue.from_clues[1])]
	else:
		var item: ItemDefinition = ItemDatabase.item(entry.key)
		_detail_title.text = item.name if item != null else entry.key
		_detail_text.text = item.description if item != null else ""
		_detail_from.text = ""


func _is_picked(key: String) -> bool:
	for entry in _picked:
		if entry.key == key:
			return true
	return false


## One of each kind of item the party carries.
func _bag_items() -> Array:
	var found: Array = []
	for member in Campaign.living_party():
		for key in Campaign.inventory_of(member):
			if key != "" and not found.has(key) and ItemDatabase.item(key) != null:
				found.append(key)
	return found


func _title_of(key: String) -> String:
	var clue: ClueDefinition = ClueBook.clue(key)
	return clue.title if clue != null and clue.title != "" else key


func _say(text: String):
	if _result != null:
		_result.text = text


func _button(text: String, pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(150, 40)
	button.pressed.connect(pressed)
	return button


func _box(fill: Color, edge: Color, margin: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.set_content_margin_all(margin)
	return box


func _play(event: String):
	if event == "":
		return
	var viewer = get_node_or_null("/root/Pictures")
	if viewer != null:
		viewer.play(event)


## --- New clues ---


func _on_clue_learned(key: String, deduced: bool):
	_play("deduction" if deduced else "clue")
	toast(("Worked out: %s" if deduced else "New clue: %s") % _title_of(key))
	if is_open():
		_rebuild()


## A note in the top corner for a moment - "New clue: ...". Slides in and fades
## out on its own; nothing waits on it. In the corner rather than the middle,
## where a picture's title is.
func toast(text: String):
	if _toast_layer == null or not is_instance_valid(_toast_layer):
		_toast_layer = CanvasLayer.new()
		_toast_layer.name = "JournalToast"
		_toast_layer.layer = TOAST_LAYER
		add_child(_toast_layer)
	for old in _toast_layer.get_children():
		old.queue_free()
	var note := PanelContainer.new()
	note.name = "Toast"
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.add_theme_stylebox_override("panel", _box(PANEL, GOLD, 12))
	var label := Label.new()
	label.text = text + "   (J)"
	label.add_theme_color_override("font_color", GOLD)
	label.add_theme_font_size_override("font_size", 22)
	note.add_child(label)
	_toast_layer.add_child(note)
	note.reset_size()
	var screen := note.get_viewport_rect().size
	var resting := Vector2(screen.x - note.size.x - 24.0, 18.0)
	note.position = resting
	if not PictureFeedback.current().animate:
		var gone := note.create_tween()
		gone.tween_interval(2.6)
		gone.tween_callback(note.queue_free)
		return
	note.position = resting + Vector2(note.size.x + 40.0, 0)
	note.modulate.a = 0.0
	var slide := note.create_tween()
	slide.set_parallel()
	slide.tween_property(note, "position", resting, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	slide.tween_property(note, "modulate:a", 1.0, 0.2)
	slide.chain().tween_interval(2.2)
	slide.chain().tween_property(note, "modulate:a", 0.0, 0.4)
	slide.chain().tween_callback(note.queue_free)


## The note showing, or "" - for tests.
func toast_text() -> String:
	if _toast_layer == null or not is_instance_valid(_toast_layer):
		return ""
	for note in _toast_layer.get_children():
		if not note.is_queued_for_deletion():
			return note.get_child(0).text
	return ""


## --- Keys ---


func _input(event):
	if not is_open():
		return
	if event.is_action_pressed("ui_cancel") \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		get_viewport().set_input_as_handled()
		if _mode == Mode.PRESENT:
			cancel()
		else:
			close()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_J and _mode == Mode.BROWSE:
		get_viewport().set_input_as_handled()
		close()


func _unhandled_input(event):
	if is_open() or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.physical_keycode != KEY_J or not _can_open_here() or MenuPause.held_by_another(self):
		return
	get_viewport().set_input_as_handled()
	open()


func _can_open_here() -> bool:
	var viewer = get_node_or_null("/root/Pictures")
	if viewer != null and viewer.is_open():
		return true
	var scene = get_tree().current_scene
	return scene != null and OPENS_IN.has(scene.scene_file_path)
