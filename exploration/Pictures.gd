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
## party's bag to use an item from (or put two together, or hold a lens over
## the picture), the journal and Back.
##
## How it all sounds, what the cursor shows and how much moves is
## res://pictures/feedback.tres (see PictureFeedback).

signal closed

## Just under the dialogue balloon's layer (30), so a conversation started from
## a hotspot plays over the picture rather than behind it.
const LAYER := 25
## Near enough opaque that the map's HUD does not ghost through behind the bar.
const DIM := Color(0.02, 0.03, 0.05, 0.98)
## Room kept below the picture for the bar, and above it for the title.
const BAR_ROOM := 150.0
const TITLE_ROOM := 92.0
const BALLOON_SCENE := "res://ui/dialogue_balloon.tscn"
## How far round the pointer a lens shows hidden things, on screen.
const LENS_RADIUS := 90.0
## What the bag says when two things are put together that make nothing.
const NO_COMBINATION := "Those don't go together."

## Off in tests, which want to see where a hotspot would send the party without
## the scene changing under them.
var leave_for_map := true
## Where a held lens is, when something other than the mouse says - tests, which
## have no mouse to move. null: wherever the mouse is.
var lens_point = null

var _layer: CanvasLayer = null
var _holder: Control = null
var _title: Label = null
var _progress: Label = null
var _caption: Label = null
var _hover_label: Label = null
var _badge: _Badge = null
var _lens_ring: _LensRing = null
var _bag: HBoxContainer = null
var _back: Button = null
var _stack: Array = []
var _hovered: Control = null
## The item picked from the bag to use on the next thing clicked, or "".
var _holding := ""
var _talking := false
var _players: Array = []
var _next_player := 0
## The way into the picture on top: 0 to 1, and where on screen it grows from
## (no area: it only fades in).
var _intro := 1.0
var _intro_from := Rect2()


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
		_let_go_of(under)
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
	_begin_intro()
	_fit()
	_refresh_bag()
	_refresh_progress()


## One picture back. The last one closes the lot.
func back():
	if _stack.is_empty():
		return
	var top: Picture = _stack.pop_back()
	_let_go_of(top)
	top.queue_free()
	if _stack.is_empty():
		close()
		return
	play("back")
	var under = current()
	under.visible = true
	under.refresh()
	_title.text = under.title
	_title.visible = under.title != ""
	_say("")
	_intro_from = Rect2()
	_begin_intro()
	_refresh_progress()
	_refresh_hover()


## Nothing in `picture` is under the mouse any more - it is being covered or
## put away, and the mouse never left anything in it to say so. Without this
## the name and the sign of whatever was clicked stayed up over the next
## picture.
func _let_go_of(picture: Picture):
	for spot in picture.hotspots():
		spot._set_hovered(false)
	_hovered = null
	_refresh_hover()


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
		_players.clear()
	closed.emit()


## What the line along the bottom says right now.
func caption() -> String:
	return _caption.text if _caption != null else ""


## The item being held to use on something, or "".
func holding() -> String:
	return _holding


## Whether a lens is being held over the picture.
func lens_held() -> bool:
	return _is_lens(_holding)


## Picks up `item_key` from the bag to use on the next thing clicked; given the
## one already held, puts it back; given a second while one is held, puts the
## two together.
func hold(item_key: String):
	if _holding == item_key:
		_holding = ""
	elif _holding != "":
		var first = _holding
		_holding = ""
		_combine(first, item_key)
	else:
		_holding = item_key
		if _is_lens(item_key):
			play("lens")
	_refresh_bag()
	_refresh_hover()


func _combine(a: String, b: String):
	var made = Campaign.combine_items(a, b)
	if made == "":
		_say(NO_COMBINATION)
		play("combine_wrong")
		return
	var item: ItemDefinition = ItemDatabase.item(made)
	var said = item.combine_text if item != null and item.combine_text != "" else "Put together: %s." % _item_name(made)
	_say(said)
	play("combine_right")


func _is_lens(item_key: String) -> bool:
	var item: ItemDefinition = ItemDatabase.item(item_key) if item_key != "" else null
	return item != null and item.reveals_hidden_details


## --- What the hotspots call ---


## The mouse has moved onto `thing` - a Hotspot, a dial, a piece - or off
## everything (null).
func hover(thing: Control):
	if thing != null and thing != _hovered and _hints() != Picture.HoverHints.NONE:
		play("hover")
	_hovered = thing
	_refresh_hover()


func click(hotspot: Hotspot):
	if _talking or hotspot == null or not hotspot.visible or not hotspot.can_be_pointed_at():
		return
	if _holding != "" and not lens_held():
		_use_item_on(hotspot)
		return
	if hotspot.requires_flag != "" and not Campaign.flag(hotspot.requires_flag):
		Campaign.mark_examined(hotspot.examined_id())
		_say(hotspot.locked_text)
		play("locked", hotspot.click_sound)
		_refresh_current()
		return
	if hotspot.gives_item != "" and Campaign.room_for_one() == "":
		_say("There's no room left to carry that.")
		play("use_wrong")
		return
	Campaign.mark_examined(hotspot.examined_id())
	play(hotspot.verb_name(), hotspot.click_sound)
	hotspot.play_click_animation()
	_say(hotspot.examine_text)
	if hotspot.gives_item != "":
		Campaign.give_item(Campaign.room_for_one(), hotspot.gives_item)
		_refresh_bag()
	if hotspot.gives_clue != "":
		Campaign.learn_clue(hotspot.gives_clue)
	if hotspot.sets_flag != "":
		Campaign.set_flag(hotspot.sets_flag)
	if hotspot.dialogue != null:
		_talk(hotspot.dialogue, hotspot.dialogue_title)
	if hotspot.opens_picture != "":
		_intro_from = hotspot.get_global_rect()
		open(hotspot.opens_picture)
	elif hotspot.goes_to_map != "":
		_go_to_map(hotspot.goes_to_map, hotspot.arrives_at)
	_refresh_current()


func _use_item_on(hotspot: Hotspot):
	var item_key = _holding
	_holding = ""
	if hotspot.takes_item == "" or hotspot.takes_item != item_key:
		_say(hotspot.wrong_item_text)
		play("use_wrong")
		_refresh_bag()
		_refresh_hover()
		return
	Campaign.mark_examined(hotspot.examined_id())
	if hotspot.item_is_used_up:
		for key in Campaign.living_party():
			if Campaign.take_item(key, item_key):
				break
	if hotspot.item_sets_flag != "":
		Campaign.set_flag(hotspot.item_sets_flag)
	_say(hotspot.item_text)
	play("use_right")
	if hotspot.dialogue != null and hotspot.item_dialogue_title != "":
		_talk(hotspot.dialogue, hotspot.item_dialogue_title)
	_refresh_bag()
	_refresh_current()


## A Puzzle reports it is solved (Puzzle.check). It has set its own flag.
func puzzle_solved(puzzle: Puzzle):
	Campaign.mark_examined(puzzle.examined_id())
	if _hovered != null and is_instance_valid(_hovered) and puzzle.is_ancestor_of(_hovered):
		hover(null)
	play("solved")
	nudge(puzzle, 1.05)
	if puzzle.solved_text != "":
		_say(puzzle.solved_text)
	if puzzle.gives_item != "":
		var who = Campaign.room_for_one()
		if who != "":
			Campaign.give_item(who, puzzle.gives_item)
		_refresh_bag()
	if puzzle.gives_clue != "":
		Campaign.learn_clue(puzzle.gives_clue)
	_refresh_current()


## A quick swell and settle on `thing` - a dial turned, a piece snapped in, a
## puzzle solved. Nothing when animation is off.
func nudge(thing: Control, by: float = 1.08):
	if thing == null or not PictureFeedback.current().animate or not thing.is_inside_tree():
		return
	thing.pivot_offset = thing.size / 2.0
	var swell := thing.create_tween()
	swell.tween_property(thing, "scale", Vector2(by, by), 0.07)
	swell.tween_property(thing, "scale", Vector2.ONE, 0.12)


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
	_refresh_progress()
	_refresh_hover()


func _say(text: String):
	if _caption != null:
		_caption.text = text
		_caption.visible = text != ""


## --- Sound ---


## Plays the sound for `event` (a PictureFeedback slot: "look", "take",
## "solved"...) - or `instead`, when something has a sound of its own. The
## journal plays through here too.
func play(event: String, instead: AudioStream = null):
	var stream: AudioStream = instead if instead != null else PictureFeedback.current().sound(event)
	if stream == null:
		return
	if _players.is_empty() or not is_instance_valid(_players[0]):
		_players.clear()
		for i in 4:
			var player := AudioStreamPlayer.new()
			player.name = "Sound%d" % i
			if AudioServer.get_bus_index("SFX") >= 0:
				player.bus = "SFX"
			add_child(player)
			_players.append(player)
	var player: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = stream
	player.play()


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
	_title.offset_top = 10
	_layer.add_child(_title)
	_progress = Label.new()
	_progress.name = "Progress"
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_progress.offset_top = 56
	_progress.add_theme_font_size_override("font_size", 18)
	_progress.add_theme_color_override("font_color", Color(0.78, 0.74, 0.62))
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_progress)
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
	var journal := Button.new()
	journal.name = "Journal"
	journal.text = "Journal (J)"
	journal.focus_mode = Control.FOCUS_NONE
	journal.pressed.connect(_open_journal)
	row.add_child(journal)
	_back = Button.new()
	_back.text = "Back (Esc)"
	_back.focus_mode = Control.FOCUS_NONE
	_back.pressed.connect(back)
	row.add_child(_back)
	_lens_ring = _LensRing.new()
	_lens_ring.name = "Lens"
	_lens_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lens_ring.visible = false
	_layer.add_child(_lens_ring)
	_badge = _Badge.new()
	_badge.name = "Badge"
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.size = Vector2(34, 34)
	_badge.visible = false
	_layer.add_child(_badge)
	var hover_panel := PanelContainer.new()
	hover_panel.name = "HoverName"
	hover_panel.theme_type_variation = &"TooltipPanel"
	hover_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_panel.visible = false
	_hover_label = Label.new()
	_hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_panel.add_child(_hover_label)
	_layer.add_child(hover_panel)


func _open_journal():
	var journal = get_node_or_null("/root/Journal")
	if journal != null:
		journal.open()


## Starts the way into the picture now on top: grown out of `_intro_from` when
## a hotspot opened it, faded in otherwise.
func _begin_intro():
	var feedback := PictureFeedback.current()
	var seconds = feedback.zoom_seconds if _intro_from.has_area() else feedback.fade_seconds
	_intro = 0.0 if feedback.animate and seconds > 0.0 else 1.0
	if _intro >= 1.0:
		_intro_from = Rect2()


## Scales the picture on show to fit above the bar, keeping its shape - part
## of the way there while it is still coming in.
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
	var target_position: Vector2 = ((room - picture_size * fit) / 2.0 + Vector2(0, top)).floor()
	if _intro >= 1.0:
		picture.scale = Vector2(fit, fit)
		picture.position = target_position
		picture.modulate.a = 1.0
		return
	var eased := ease(_intro, 0.4)
	if _intro_from.has_area():
		var from_scale = minf(_intro_from.size.x / picture_size.x, _intro_from.size.y / picture_size.y)
		var from_position = _intro_from.get_center() - picture_size * from_scale / 2.0
		var now_scale = lerpf(from_scale, fit, eased)
		picture.scale = Vector2(now_scale, now_scale)
		picture.position = from_position.lerp(target_position, eased)
	else:
		picture.scale = Vector2(fit, fit)
		picture.position = target_position
	picture.modulate.a = lerpf(0.0, 1.0, eased)


func _process(delta):
	if _layer == null:
		return
	if _intro < 1.0:
		var feedback := PictureFeedback.current()
		var seconds = feedback.zoom_seconds if _intro_from.has_area() else feedback.fade_seconds
		_intro = minf(_intro + delta / maxf(seconds, 0.001), 1.0)
		if _intro >= 1.0:
			_intro_from = Rect2()
	_fit()
	var mouse = _holder.get_viewport().get_mouse_position()
	var screen = _holder.get_viewport_rect().size
	_update_lens(mouse)
	_badge.position = mouse + Vector2(14, 14)
	var panel: Control = _hover_label.get_parent()
	if panel.visible:
		panel.reset_size()
		var beside = 52.0 if _badge.visible else 22.0
		panel.position = (mouse + Vector2(beside, 18)).clamp(Vector2.ZERO, screen - panel.size)


## The lens, while one is held: drawn round the pointer, lighting up the hidden
## hotspots it covers and drawing the hidden layers just inside it.
func _update_lens(mouse: Vector2):
	var picture = current()
	var on = lens_held() and picture != null
	_lens_ring.visible = on
	if on:
		_lens_ring.position = mouse - Vector2(LENS_RADIUS, LENS_RADIUS)
		_lens_ring.size = Vector2(LENS_RADIUS, LENS_RADIUS) * 2.0
	if picture == null:
		return
	var at: Vector2 = lens_point if lens_point != null else _holder.get_global_mouse_position()
	for spot in picture.hotspots():
		if spot.hidden_detail:
			spot.lens_lit = on and _rect_within(spot.get_global_rect(), at, LENS_RADIUS * 0.8)
	for layer in picture.find_children("*", "PictureLayer", true, false):
		if layer.hidden_detail:
			layer.set_lens(at, LENS_RADIUS if on else 0.0)


## Whether any of `box` lies within `radius` of `point`.
func _rect_within(box: Rect2, point: Vector2, radius: float) -> bool:
	var nearest = point.clamp(box.position, box.end)
	return nearest.distance_to(point) <= radius


func _hints() -> int:
	var picture = current()
	return picture.hover_hints if picture != null else Picture.HoverHints.OUTLINE_AND_NAME


## What clicking `thing` would do, as the cursor shows it.
func _verb_of(thing: Control) -> String:
	if thing is Hotspot and _holding != "" and not lens_held():
		return "use"
	if thing.has_method("verb_name"):
		return thing.verb_name()
	return "look"


func _refresh_hover():
	if _hover_label == null:
		return
	var panel: Control = _hover_label.get_parent()
	var quiet = _hints() == Picture.HoverHints.NONE
	var holding_tool = _holding != "" and not lens_held()
	if _hovered == null or not is_instance_valid(_hovered):
		panel.visible = holding_tool
		_hover_label.text = "Use %s on..." % _item_name(_holding) if holding_tool else ""
		_badge.verb = ""
		_badge.visible = false
		return
	var what: String = _hovered.display_name if _hovered.display_name != "" else String(_hovered.name)
	if quiet:
		# A picture meant to be searched gives nothing away: not the name, not
		# what a click would do - only what the item in hand is for.
		panel.visible = holding_tool
		_hover_label.text = "Use %s on..." % _item_name(_holding) if holding_tool else ""
		_badge.visible = false
		return
	if holding_tool:
		_hover_label.text = "Use %s on %s" % [_item_name(_holding), what]
	else:
		var seen = _hovered is Hotspot and _hovered.was_examined()
		_hover_label.text = what + ("  (seen)" if seen else "")
	panel.visible = true
	_badge.verb = _verb_of(_hovered)
	_badge.texture = PictureFeedback.current().cursor(_badge.verb)
	_badge.visible = true
	_badge.queue_redraw()


## "Noticed 3 of 7" under the title.
func _refresh_progress():
	if _progress == null:
		return
	var picture = current()
	if picture == null or not picture.show_progress:
		_progress.visible = false
		return
	var counted: Vector2i = picture.progress()
	_progress.visible = counted.y > 0
	_progress.text = "Noticed %d of %d" % [counted.x, counted.y]
	_progress.offset_top = 56 if _title.visible else 10


## What the progress line under the title says right now.
func progress_text() -> String:
	return _progress.text if _progress != null and _progress.visible else ""


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
		button.name = item_key
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.button_pressed = item_key == _holding
		button.icon = item.icon
		button.expand_icon = false
		button.add_theme_constant_override("icon_max_width", 40)
		button.text = "%s%s" % [item.name, " x%d" % counts[item_key] if counts[item_key] > 1 else ""]
		if item.reveals_hidden_details:
			button.tooltip_text = "Hold it over the picture to look closer"
		elif _holding != "" and _holding != item_key:
			button.tooltip_text = "Put %s and this together" % _item_name(_holding)
		else:
			button.tooltip_text = "Pick it up to use on something, or to put with something else"
		button.pressed.connect(hold.bind(item_key))
		_bag.add_child(button)
	_refresh_hover()


func _item_name(item_key: String) -> String:
	var item: ItemDefinition = ItemDatabase.item(item_key)
	return item.name if item != null else item_key


## A click on the picture's background, or the dimmed edge: puts down whatever
## is being held.
func _on_background_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _holding != "":
			hold(_holding)


## _input rather than _unhandled_input: the pause menu lives in the scene, which
## hears unhandled input before an autoload does, and Escape here means "back",
## not "pause".
func _input(event):
	if _layer == null or _talking:
		return
	var journal = get_node_or_null("/root/Journal")
	if journal != null and journal.is_open():
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


## The little sign beside the pointer saying what a click will do: your image
## from PictureFeedback, or a glyph drawn here.
class _Badge extends Control:
	const INK := Color(1.0, 0.84, 0.35)
	const BACKING := Color(0.05, 0.06, 0.08, 0.85)
	var verb := ""
	var texture: Texture2D = null

	func _draw():
		if verb == "":
			return
		if texture != null:
			draw_texture_rect(texture, Rect2(Vector2.ZERO, size), false)
			return
		var c := size / 2.0
		draw_circle(c, 16.0, BACKING)
		draw_arc(c, 16.0, 0.0, TAU, 32, INK, 2.0)
		match verb:
			"look":
				# An eye.
				draw_arc(c + Vector2(0, 6), 10.0, PI * 1.2, PI * 1.8, 12, INK, 2.0)
				draw_arc(c - Vector2(0, 6), 10.0, PI * 0.2, PI * 0.8, 12, INK, 2.0)
				draw_circle(c, 3.0, INK)
			"take":
				# Into the hand: an arrow down onto a tray.
				draw_line(c + Vector2(0, -9), c + Vector2(0, 3), INK, 2.0)
				draw_polyline(PackedVector2Array([c + Vector2(-4, -1), c + Vector2(0, 3), c + Vector2(4, -1)]), INK, 2.0)
				draw_polyline(PackedVector2Array([c + Vector2(-8, 3), c + Vector2(-8, 8), c + Vector2(8, 8), c + Vector2(8, 3)]), INK, 2.0)
			"talk":
				# A speech bubble.
				draw_rect(Rect2(c + Vector2(-9, -8), Vector2(18, 12)), INK, false, 2.0)
				draw_polyline(PackedVector2Array([c + Vector2(-4, 4), c + Vector2(-6, 9), c + Vector2(1, 4)]), INK, 2.0)
			"use":
				# A cog.
				draw_arc(c, 5.0, 0.0, TAU, 16, INK, 2.0)
				for spoke in 6:
					var way := Vector2.RIGHT.rotated(TAU * spoke / 6.0)
					draw_line(c + way * 6.0, c + way * 10.0, INK, 2.5)
			"go":
				# A magnifying glass: a closer look.
				draw_arc(c + Vector2(-2, -2), 6.0, 0.0, TAU, 16, INK, 2.0)
				draw_line(c + Vector2(2.5, 2.5), c + Vector2(8, 8), INK, 3.0)
			"turn":
				# Round and round.
				draw_arc(c, 8.0, -PI * 0.2, PI * 1.4, 20, INK, 2.0)
				var tip := c + Vector2.RIGHT.rotated(-PI * 0.2) * 8.0
				draw_polyline(PackedVector2Array([tip + Vector2(-5, -1), tip, tip + Vector2(1, 5)]), INK, 2.0)
			"move":
				# Four ways.
				draw_line(c + Vector2(-9, 0), c + Vector2(9, 0), INK, 2.0)
				draw_line(c + Vector2(0, -9), c + Vector2(0, 9), INK, 2.0)
				for way in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
					var tip: Vector2 = c + way * 9.0
					var side: Vector2 = way.orthogonal() * 3.0
					draw_polyline(PackedVector2Array([tip - way * 3.0 + side, tip, tip - way * 3.0 - side]), INK, 2.0)


## The ring a lens is drawn as, round the pointer.
class _LensRing extends Control:
	func _draw():
		var c := size / 2.0
		var r := size.x / 2.0
		draw_circle(c, r, Color(0.55, 0.85, 1.0, 0.06))
		draw_arc(c, r, 0.0, TAU, 48, Color(0.55, 0.85, 1.0, 0.7), 3.0)
		draw_arc(c, r - 5.0, 0.0, TAU, 48, Color(0.0, 0.0, 0.0, 0.35), 2.0)
