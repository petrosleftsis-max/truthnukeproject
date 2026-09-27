extends Node
## Autoload. Shows point-and-click pictures (see Picture) over whatever is
## running, and handles what their hotspots do.
##
## Opened from a PictureInteractable on a map, or from a conversation:
##
##     do Pictures.open("res://pictures/desk.tscn")
##
## which holds the conversation until the pictures are closed again, the same
## way `do Actors.walk(...)` holds it until the walk is done.
##
## Pictures stack: a hotspot can open another (the drawer inside the desk), and
## Back - or Escape - returns to the one before. Backing out of the first
## closes them all. Along the bottom sit the line the last click said, the
## party's bag to use an item from, and Back.

signal closed

## Just under the dialogue balloon's layer (30), so a conversation started from
## a hotspot plays over the picture rather than behind it.
const LAYER := 25
## Near enough opaque that the map's HUD does not ghost through behind the bar.
const DIM := Color(0.02, 0.03, 0.05, 0.98)
## Room kept below the picture for the bar, and above it for the title.
const BAR_ROOM := 150.0
const TITLE_ROOM := 72.0
const BALLOON_SCENE := "res://ui/dialogue_balloon.tscn"

## Off in tests, which want to see where a hotspot would send the party without
## the scene changing under them.
var leave_for_map := true

var _layer: CanvasLayer = null
var _holder: Control = null
var _title: Label = null
var _caption: Label = null
var _hover_label: Label = null
var _bag: HBoxContainer = null
var _back: Button = null
var _stack: Array = []
var _hovered: Hotspot = null
## The item picked from the bag to use on the next thing clicked, or "".
var _holding := ""
var _talking := false


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS


## Opens `picture` - a path to a Picture scene, or the scene itself - and waits
## until the pictures are closed again. Opening one while another is showing
## stacks it on top, and returns straight away.
func open(picture) -> void:
	var scene: PackedScene = load(picture) if picture is String else picture
	if scene == null:
		push_warning("Pictures: there is no picture at '%s'." % [picture])
		return
	var first = _stack.is_empty()
	show_picture(scene.instantiate())
	if first:
		await closed


func is_open() -> bool:
	return not _stack.is_empty()


## The picture on show, or null.
func current() -> Picture:
	return _stack.back() if not _stack.is_empty() else null


## Puts `picture` (a Picture node, not yet in the tree) on top of the stack.
func show_picture(picture: Picture):
	if _layer == null:
		_build()
	var under = current()
	if under != null:
		under.visible = false
	_stack.append(picture)
	# The size it was laid out at. A picture anchored to fill the screen in the
	# editor has none until it is in a tree - it was drawn at the window's size.
	var design: Vector2 = picture.size
	if design.x <= 0.0 or design.y <= 0.0:
		design = Vector2(ProjectSettings.get_setting("display/window/size/viewport_width", 1280),
			ProjectSettings.get_setting("display/window/size/viewport_height", 720))
	picture.set_meta("design_size", design)
	picture.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_holder.add_child(picture)
	picture.size = design
	picture.refresh()
	_title.text = picture.title
	_title.visible = picture.title != ""
	_say("")
	_fit()
	_refresh_bag()


## One picture back. The last one closes the lot.
func back():
	if _stack.is_empty():
		return
	var top: Picture = _stack.pop_back()
	_hovered = null
	top.queue_free()
	if _stack.is_empty():
		close()
		return
	var under = current()
	under.visible = true
	under.refresh()
	_title.text = under.title
	_title.visible = under.title != ""
	_say("")


## Closes every picture.
func close():
	for picture in _stack:
		if is_instance_valid(picture):
			picture.queue_free()
	_stack.clear()
	_hovered = null
	_holding = ""
	if _layer != null:
		_layer.queue_free()
		_layer = null
	closed.emit()


## What the line along the bottom says right now.
func caption() -> String:
	return _caption.text if _caption != null else ""


## The item being held to use on something, or "".
func holding() -> String:
	return _holding


## Picks up `item_key` from the bag to use on the next thing clicked - or, given
## the one already held, puts it back.
func hold(item_key: String):
	_holding = "" if _holding == item_key else item_key
	_refresh_bag()
	_refresh_hover()


## --- What the hotspots call ---


func hover(hotspot: Hotspot):
	_hovered = hotspot
	_refresh_hover()


func click(hotspot: Hotspot):
	if _talking or hotspot == null or not hotspot.visible:
		return
	if _holding != "":
		_use_item_on(hotspot)
		return
	if hotspot.requires_flag != "" and not Campaign.flag(hotspot.requires_flag):
		_say(hotspot.locked_text)
		return
	_say(hotspot.examine_text)
	if hotspot.sets_flag != "":
		Campaign.set_flag(hotspot.sets_flag)
	if hotspot.dialogue != null:
		_talk(hotspot.dialogue, hotspot.dialogue_title)
	if hotspot.opens_picture != "":
		open(hotspot.opens_picture)
	elif hotspot.goes_to_map != "":
		_go_to_map(hotspot.goes_to_map, hotspot.arrives_at)
	_refresh_current()


func _use_item_on(hotspot: Hotspot):
	var item_key = _holding
	_holding = ""
	if hotspot.takes_item == "" or hotspot.takes_item != item_key:
		_say(hotspot.wrong_item_text)
		_refresh_bag()
		return
	if hotspot.item_is_used_up:
		for key in Campaign.living_party():
			if Campaign.take_item(key, item_key):
				break
	if hotspot.item_sets_flag != "":
		Campaign.set_flag(hotspot.item_sets_flag)
	_say(hotspot.item_text)
	if hotspot.dialogue != null and hotspot.item_dialogue_title != "":
		_talk(hotspot.dialogue, hotspot.item_dialogue_title)
	_refresh_bag()
	_refresh_current()


func _talk(dialogue: Resource, title: String):
	var manager = get_node_or_null("/root/DialogueManager")
	if manager == null:
		push_warning("Pictures: there is no DialogueManager to play '%s' through." % title)
		return
	_talking = true
	manager.dialogue_ended.connect(_on_talk_ended, CONNECT_ONE_SHOT)
	manager.show_dialogue_balloon_scene(BALLOON_SCENE, dialogue, title if title != "" else "start")


func _on_talk_ended(_resource = null):
	_talking = false
	_refresh_bag()
	_refresh_current()


## Leaves the pictures for a map: the party arrives at `entry` (or the map's
## first entry point).
func _go_to_map(map_path: String, entry: String):
	Campaign.travel_to_map(map_path, entry)
	close()
	if leave_for_map:
		SceneTransition.change_scene("res://scenes/exploration.tscn")


func _refresh_current():
	var picture = current()
	if picture != null:
		picture.refresh()


func _say(text: String):
	if _caption != null:
		_caption.text = text
		_caption.visible = text != ""


## --- The viewer ---


func _build():
	_layer = CanvasLayer.new()
	_layer.name = "Pictures"
	_layer.layer = LAYER
	add_child(_layer)
	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Nothing behind the pictures can be clicked while they are up.
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_background_input)
	_layer.add_child(dim)
	_holder = Control.new()
	_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_holder)
	_title = Label.new()
	_title.theme_type_variation = GameFonts.HEADER
	_title.add_theme_font_size_override("font_size", 34)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title.offset_top = 14
	_layer.add_child(_title)
	var bar := PanelContainer.new()
	bar.name = "Bar"
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -BAR_ROOM + 20
	bar.offset_bottom = -16
	bar.offset_left = 120
	bar.offset_right = -120
	_layer.add_child(bar)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	bar.add_child(column)
	_caption = Label.new()
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", 22)
	column.add_child(_caption)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	_bag = HBoxContainer.new()
	_bag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bag.add_theme_constant_override("separation", 6)
	row.add_child(_bag)
	_back = Button.new()
	_back.text = "Back (Esc)"
	_back.focus_mode = Control.FOCUS_NONE
	_back.pressed.connect(back)
	row.add_child(_back)
	var hover_panel := PanelContainer.new()
	hover_panel.name = "HoverName"
	hover_panel.theme_type_variation = &"TooltipPanel"
	hover_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_panel.visible = false
	_hover_label = Label.new()
	_hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_panel.add_child(_hover_label)
	_layer.add_child(hover_panel)


## Scales the picture on show to fit above the bar, keeping its shape.
func _fit():
	var picture = current()
	if picture == null or _layer == null:
		return
	var screen = _holder.get_viewport_rect().size
	# Below the title, when there is one, so it is never written over the art.
	var top = TITLE_ROOM if _title.visible else 0.0
	var room = Vector2(screen.x, screen.y - BAR_ROOM - top)
	var picture_size: Vector2 = picture.get_meta("design_size", room)
	var fit = minf(room.x / picture_size.x, room.y / picture_size.y)
	picture.scale = Vector2(fit, fit)
	picture.position = ((room - picture_size * fit) / 2.0 + Vector2(0, top)).floor()


func _process(_delta):
	if _layer == null:
		return
	_fit()
	var panel: Control = _hover_label.get_parent()
	if panel.visible:
		panel.reset_size()
		var mouse = _holder.get_viewport().get_mouse_position()
		var screen = _holder.get_viewport_rect().size
		panel.position = (mouse + Vector2(22, 22)).clamp(Vector2.ZERO, screen - panel.size)


func _refresh_hover():
	if _hover_label == null:
		return
	var panel: Control = _hover_label.get_parent()
	if _hovered == null or not is_instance_valid(_hovered):
		panel.visible = _holding != ""
		_hover_label.text = "Use %s on..." % _item_name(_holding) if _holding != "" else ""
		return
	var what = _hovered.display_name if _hovered.display_name != "" else String(_hovered.name)
	_hover_label.text = "Use %s on %s" % [_item_name(_holding), what] if _holding != "" else what
	panel.visible = true


## The party's bag along the bottom: one button per kind of item carried, the
## one being held pressed in.
func _refresh_bag():
	if _bag == null:
		return
	for child in _bag.get_children():
		_bag.remove_child(child)
		child.queue_free()
	var counts := {}
	var order := []
	for key in Campaign.living_party():
		for item_key in Campaign.inventory_of(key):
			if item_key == "":
				continue
			if not counts.has(item_key):
				order.append(item_key)
			counts[item_key] = counts.get(item_key, 0) + 1
	for item_key in order:
		var item: ItemDefinition = ItemDatabase.item(item_key)
		if item == null:
			continue
		var button := Button.new()
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.button_pressed = item_key == _holding
		button.icon = item.icon
		button.expand_icon = false
		button.add_theme_constant_override("icon_max_width", 40)
		button.text = "%s%s" % [item.name, " x%d" % counts[item_key] if counts[item_key] > 1 else ""]
		button.tooltip_text = "Pick it up to use on something"
		button.pressed.connect(hold.bind(item_key))
		_bag.add_child(button)
	_refresh_hover()


func _item_name(item_key: String) -> String:
	var item: ItemDefinition = ItemDatabase.item(item_key)
	return item.name if item != null else item_key


## A click on the picture's background, or the dimmed edge: puts down whatever
## is being held.
func _on_background_input(event):
	if event is InputEventMouseButton and event.pressed:
		if _holding != "":
			hold(_holding)


## _input rather than _unhandled_input: the pause menu lives in the scene, which
## hears unhandled input before an autoload does, and Escape here means "back",
## not "pause".
func _input(event):
	if _layer == null or _talking:
		return
	var cancel = event.is_action_pressed("ui_cancel") \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT)
	if not cancel:
		return
	get_viewport().set_input_as_handled()
	# The item in hand goes down first; with nothing held, one picture back.
	if _holding != "":
		hold(_holding)
	else:
		back()
