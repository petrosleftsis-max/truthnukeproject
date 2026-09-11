extends Control
class_name MainMenu
## The front door: what to play, what to fight, how it looks and sounds, and out.
##
## Four panels, one at a time - the menu itself, the four ways into the game,
## options, and the two settings under it. Built in code for the same reason the
## battle selector is: nearly all of it is repeated rows built from data, and a
## scene file would be a second place to keep the layout in step.
##
## Palette and type match ui/blue_theme.tres and the battle selector, so the
## menu and the game it opens read as one thing.

## Palette, shared with the battle selector.
const INK := Color("dce8f5")        ## Headings.
const INK_DIM := Color("c2ceda")    ## Body text.
const MUTED := Color("8296a9")      ## Descriptions and labels.
const ACCENT := Color("4a86c8")     ## Focus.
const PANEL := Color("19212c")
const CARD := Color("1c2531")       ## A card at rest.
const CARD_LIT := Color("24344a")   ## Under the cursor or focus.
const CARD_EDGE := Color("2b3947")

const BATTLE_SELECT := "res://scenes/level_select.tscn"
const EXPLORATION := "res://scenes/exploration.tscn"
const BATTLE := "res://scenes/game.tscn"
const STORY := "res://scenes/story.tscn"

## The four ways in, left to right. Each names what it opens: a `dialogue` to
## play over black, a `map` to walk around in, or an `encounter` to fight.
const WAYS_IN := [
	{
		"name": "Cyrus",
		"icon": "res://imagese/icon/cyrus colors.png",
		"description": "An introduction to the world and a tutorial stage.",
		"dialogue": "res://Dialogue/cyrus_intro.dialogue",
		"then": EXPLORATION,
	},
	{
		"name": "Prometheus",
		"icon": "res://imagese/icon/prometheus colors.png",
		"description": "Narrative and gameplay team dynamics with an intermediate stage.",
		"map": "res://skills/laboratory_terrain_explore.tscn",
	},
	{
		"name": "Enfina",
		"icon": "res://imagese/icon/enfina colors.png",
		"description": "A difficult stage.",
		"encounter": "res://encounters/encounter_03_watcher.tres",
	},
	{
		"name": "Alithia",
		"icon": "res://imagese/icon/alithia colors.png",
		"description": "Narrative snippet of mid to end game.",
		# The conversation is in the map rather than named here: it is a scene
		# that happens in the church, on arrival, and leaves her standing in it
		# afterwards - see the ArrivalConversation node in church.tscn.
		"map": "res://church.tscn",
	},
]

const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]

var _panels := {}
var _stack: Array = []


func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = PANEL.darkened(0.35)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	_panels["root"] = _build_root()
	_panels["play"] = _build_play()
	_panels["options"] = _build_options()
	_panels["resolution"] = _build_resolution()
	_panels["volume"] = _build_volume()
	for key in _panels:
		add_child(_panels[key])
	_show("root")


## --- The panels ---


## A centred column with a heading, which every panel is.
func _panel(title_text: String) -> VBoxContainer:
	var holder := VBoxContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.add_theme_constant_override("separation", 14)
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", INK)
	holder.add_child(title)
	return holder


func _build_root() -> Control:
	var holder := _panel("Messengers of Truth")
	var buttons := VBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 8)
	buttons.custom_minimum_size = Vector2(280, 0)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	buttons.add_child(_menu_button("Play", func(): _show("play")))
	buttons.add_child(_menu_button("Arena Mode", func(): SceneTransition.change_scene(BATTLE_SELECT)))
	buttons.add_child(_menu_button("Options", func(): _show("options")))
	buttons.add_child(_menu_button("Exit", _quit))
	holder.add_child(buttons)
	return holder


## The four ways in, side by side. A row rather than a list because they are
## alternatives of the same kind rather than steps in an order.
func _build_play() -> Control:
	var holder := _panel("Where to begin")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for way in WAYS_IN:
		row.add_child(_way_in_card(way))
	holder.add_child(row)
	holder.add_child(_back_button())
	return holder


func _build_options() -> Control:
	var holder := _panel("Options")
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	buttons.custom_minimum_size = Vector2(280, 0)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	buttons.add_child(_menu_button("Resolution", func(): _show("resolution")))
	buttons.add_child(_menu_button("Volume", func(): _show("volume")))
	holder.add_child(buttons)
	holder.add_child(_back_button())
	return holder


func _build_resolution() -> Control:
	var holder := _panel("Resolution")
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	buttons.custom_minimum_size = Vector2(280, 0)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for size in RESOLUTIONS:
		buttons.add_child(_menu_button("%d x %d" % [size.x, size.y], _set_resolution.bind(size)))
	holder.add_child(buttons)
	holder.add_child(_back_button())
	return holder


func _build_volume() -> Control:
	var holder := _panel("Volume")
	var rows := VolumeSliders.new()
	rows.custom_minimum_size = Vector2(360, 0)
	rows.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.add_child(rows)
	holder.add_child(_back_button())
	return holder


## --- The pieces ---


func _menu_button(text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 42)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_focus_color", INK)
	button.add_theme_stylebox_override("normal", _box(CARD))
	button.add_theme_stylebox_override("hover", _box(CARD_LIT))
	button.add_theme_stylebox_override("focus", _box(CARD_LIT, ACCENT))
	button.add_theme_stylebox_override("pressed", _box(CARD_LIT, ACCENT))
	button.pressed.connect(on_press)
	return button


## One of the four ways in: a portrait, a name, and what you are letting
## yourself in for.
func _way_in_card(way: Dictionary) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(210, 300)
	card.add_theme_stylebox_override("normal", _box(CARD))
	card.add_theme_stylebox_override("hover", _box(CARD_LIT))
	card.add_theme_stylebox_override("focus", _box(CARD_LIT, ACCENT))
	card.add_theme_stylebox_override("pressed", _box(CARD_LIT, ACCENT))
	card.tooltip_text = way.description
	card.pressed.connect(_start.bind(way))

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 12
	column.offset_right = -12
	column.offset_top = 12
	column.offset_bottom = -12
	column.add_theme_constant_override("separation", 10)
	# The card is the button; nothing inside it should swallow the click.
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)

	var portrait := TextureRect.new()
	if ResourceLoader.exists(way.icon):
		portrait.texture = load(way.icon)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(0, 170)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(portrait)

	var name_label := Label.new()
	name_label.text = way.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 19)
	name_label.add_theme_color_override("font_color", INK)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(name_label)

	var description := Label.new()
	description.text = way.description
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Wrapped and given the room to wrap into, so the whole of it stays on the
	# card rather than running off the side of it.
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description.add_theme_font_size_override("font_size", 12)
	description.add_theme_color_override("font_color", MUTED)
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(description)
	return card


func _back_button() -> Button:
	var back := _menu_button("Back", _go_back)
	back.custom_minimum_size = Vector2(180, 36)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return back


func _box(fill: Color, edge: Color = CARD_EDGE) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box


## --- Going places ---


## Shows one panel and remembers the way back, so Back always means "the panel I
## came from" rather than a fixed destination.
func _show(key: String, remember: bool = true):
	if remember and not _stack.is_empty() and _stack.back() == key:
		remember = false
	if remember:
		_stack.append(key)
	for other in _panels:
		_panels[other].visible = other == key
	_focus_first(_panels[key])


func _go_back():
	if _stack.size() > 1:
		_stack.pop_back()
	_show(_stack.back() if not _stack.is_empty() else "root", false)


## Keyboard focus on whatever the panel offers first, so the menu can be driven
## without a mouse.
func _focus_first(panel: Control):
	for node in panel.find_children("*", "Button", true, false):
		if node.visible:
			node.grab_focus()
			return


## Starts one of the four. A story plays over black and then goes wherever it
## says; a map drops the party into it; an encounter goes straight to the fight.
func _start(way: Dictionary):
	Campaign.reset()
	if way.has("dialogue"):
		Campaign.begin_story(way.dialogue, "start", way.get("then", ""))
		SceneTransition.change_scene(STORY)
		return
	if way.has("map"):
		# Named here rather than left to the exploration scene's own default,
		# which is only what running that scene straight from the editor opens.
		Campaign.current_map = way.map
		Campaign.target_entry = ""
		SceneTransition.change_scene(EXPLORATION)
		return
	if way.has("encounter"):
		Campaign.current_encounter = load(way.encounter)
		SceneTransition.change_scene(BATTLE)


## Resizing the window is all this has to do: the project stretches everything
## else to fit, which is why the pause menu's picker does the same and no more.
func _set_resolution(size: Vector2i):
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, false)
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, true)


func _quit():
	get_tree().quit()


## Escape steps back out of whatever is open, which is what it does everywhere
## else in the game.
func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel") and _stack.size() > 1:
		_go_back()
		get_viewport().set_input_as_handled()
