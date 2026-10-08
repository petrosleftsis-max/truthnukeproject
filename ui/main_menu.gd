extends Control
class_name MainMenu
## The front door: what to play, what to fight, how it looks and sounds, and out.
##
## Panels, one at a time - the menu itself, the four ways into the game, the
## stealth stages, options, and the two settings under it. Built in code for the same reason the
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
## Behind everything.
const BACKDROP := Color("19212c") * Color(0.65, 0.65, 0.65, 1.0)

## The picture behind the menu.
const BACKGROUND_ART := "res://art/ui/main_menu_background.png"
## The art is a pencil sketch on white, so it is drawn as chalk on the
## menu's own dark blue: the paper becomes the backdrop, the pencil a pale
## line - the menu stays as dark as it was and its light text still reads.
## Set false for finished art, to show it in its own colours (dimmed).
const BACKGROUND_AS_SKETCH := true
## The colour the pencil lines come out in.
const SKETCH_INK := Color(0.55, 0.66, 0.8, 0.55)
## How much of the picture is left behind a panel other than the title screen.
const BACKDROP_QUIET := 0.4
const SKETCH_SHADER := """
shader_type canvas_item;
uniform vec4 paper : source_color;
uniform vec4 ink : source_color;
uniform float strength = 1.0;
void fragment() {
	vec3 drawn = texture(TEXTURE, UV).rgb;
	float line = clamp((1.0 - dot(drawn, vec3(0.299, 0.587, 0.114))) * 1.6, 0.0, 1.0);
	COLOR = vec4(mix(paper.rgb, ink.rgb, line * ink.a * strength), 1.0);
}
"""
const CARD := Color("1c2531")       ## A card at rest.
const CARD_LIT := Color("24344a")   ## Under the cursor or focus.
const CARD_EDGE := Color("2b3947")

const BATTLE_SELECT := "res://scenes/level_select.tscn"
## The point-and-click demo: clues, the journal, locks, a torn letter.
const CLUES_DEMO := "res://demos/try_pictures_demo.tscn"
## The fights one after another, with rests between (see DungeonDefinition).
const DUNGEON_DEMO := "res://data/dungeons/dungeon_demo.tres"
const EXPLORATION := "res://scenes/exploration.tscn"
const BATTLE := "res://scenes/game.tscn"
const STORY := "res://scenes/story.tscn"

## The four ways in, left to right. Each names what it opens: a `dialogue` to
## play over black, a `map` to walk around in, or an `encounter` to fight.
const WAYS_IN := [
	{
		"name": "Cyrus",
		"icon": "res://art/characters/cyrus/cyrus_colors.png",
		"description": "An introduction to the world and a tutorial stage.",
		"dialogue": "res://dialogue/cyrus_intro.dialogue",
		"then": EXPLORATION,
	},
	{
		"name": "Prometheus",
		"icon": "res://art/characters/prometheus/prometheus_colors.png",
		"description": "Narrative and gameplay team dynamics with an intermediate stage.",
		"map": "res://maps/laboratory_explore.tscn",
	},
	{
		"name": "Enfina",
		"icon": "res://art/characters/enfina/enfina_colors.png",
		"description": "A difficult stage.",
		"encounter": "res://data/encounters/encounter_03_watcher.tres",
	},
	{
		"name": "Alithia",
		"icon": "res://art/characters/alithia/alithia_colors.png",
		"description": "Narrative snippet of mid to end game.",
		# The conversation is in the map rather than named here: it is a scene
		# that happens in the church, on arrival, and leaves her standing in it
		# afterwards - see the ArrivalConversation node in maps/church.tscn.
		"map": "res://maps/church.tscn",
	},
]

## The stealth stages, top to bottom: short stand-alone maps, each finished by
## reaching its way out, which comes back here. Built by
## tools/build_stealth_stages.gd.
const STEALTH_STAGES := [
	{
		"name": "The Tools",
		"map": "res://maps/stealth_stages/stealth_1.tscn",
		"description": "Get into the vault - the guard walking the corridor has the key. Throw pebbles to draw guards off, hide behind the crates, lift the key from his pocket, and listen for the guards you cannot see.",
	},
	{
		"name": "The Watch",
		"map": "res://maps/stealth_stages/stealth_2.tscn",
		"description": "A statue that never stops turning and sees through anything, a hound that smells you through walls, and a captain whose shout brings the whole barracks.",
	},
	{
		"name": "Escort",
		"map": "res://maps/stealth_stages/stealth_3.tscn",
		"description": "Get Enfina out. She can be seen as easily as you can, so every hiding place has to hold you both.",
	},
	{
		"name": "Disguise",
		"map": "res://maps/stealth_stages/stealth_4.tscn",
		"description": "Find a priest's robes. The priest at the checkpoint will want a word, the hall guard will not look twice - and the door guard sees through any disguise.",
	},
	{
		"name": "Lights Out",
		"map": "res://maps/stealth_stages/stealth_5.tscn",
		"description": "A dark archive: put the lamps out, creep (Ctrl) over gravel and glass, lift the key from a sleeping porter and read who walks where - then steal the ledger. Guards notice a lamp gone out or a door left open.",
	},
	{
		"name": "Supper Time",
		"map": "res://maps/stealth_stages/stealth_6.tscn",
		"description": "Poison the aide's supper or dart him, plant a letter in the empty study, and overhear the guards in the hall - who check on each other. The cook runs for help if she sees you.",
	},
	{
		"name": "The Checkpoint",
		"map": "res://maps/stealth_stages/stealth_7.tscn",
		"description": "The camp is on edge. In priest's robes, a word (E beside one) calms the guards they fool - and the view on the ground shows who they fool. Lift the quartermaster's bombs, then ambush the gate (F) or slip round by the ditch.",
	},
]
## The panel a stage's way out comes back to - see StealthGoal.ends_at_menu.
const STEALTH_PANEL := "stealth"
## How to play, shown above the stages.
const STEALTH_HELP := "Stay out of the guards' sight - what they can see is tinted on the ground. Move with WASD, dash with Shift. The bar along the top shows everything else you can do, and its key."

const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]

var _panels := {}
## The picture behind it all (see _backdrop_art).
var _backdrop: TextureRect = null
var _stack: Array = []
## The stage last started from here, to name when it sends the player back.
static var _last_stage := ""
var _stealth_note: Label = null
var _note: Label = null
## Fullscreen, fake fullscreen or windowed, above the sizes.
var _window_mode: WindowModePicker = null


func _ready():
	# Fullscreen if that is how the player left it.
	GameSettings.restore_window_mode()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = BACKDROP
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	_backdrop = _backdrop_art()
	add_child(_backdrop)

	_panels["root"] = _build_root()
	_panels["play"] = _build_play()
	_panels[STEALTH_PANEL] = _build_stealth()
	_panels["options"] = _build_options()
	_panels["resolution"] = _build_resolution()
	_panels["volume"] = _build_volume()
	_panels["glossary"] = _build_glossary()
	for key in _panels:
		add_child(_panels[key])
	_keyboard = FocusOnDemand.attach(self, null)
	_show("root")
	# Sent back here to somewhere in particular - a stage's way out, back to the
	# stages - with the front door still behind it for Back.
	if _panels.has(Campaign.menu_opens_at):
		_show(Campaign.menu_opens_at)
		if Campaign.menu_opens_at == STEALTH_PANEL and Campaign.menu_note != "":
			_stealth_note.text = "%s: %s" % [_last_stage, Campaign.menu_note] if _last_stage != "" else Campaign.menu_note
			_stealth_note.visible = true
	elif Campaign.menu_note != "":
		_note.text = Campaign.menu_note
		_note.visible = true
	Campaign.menu_opens_at = ""
	Campaign.menu_note = ""


## The picture behind the menu, filling the screen whatever its shape - cut at
## the edges rather than squashed or letterboxed. Nothing at all when the file
## is missing, which leaves the plain backdrop.
func _backdrop_art() -> TextureRect:
	var art := TextureRect.new()
	art.name = "Backdrop"
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists(BACKGROUND_ART):
		art.texture = load(BACKGROUND_ART)
	if BACKGROUND_AS_SKETCH:
		var chalk := ShaderMaterial.new()
		chalk.shader = Shader.new()
		chalk.shader.code = SKETCH_SHADER
		chalk.set_shader_parameter("paper", BACKDROP)
		chalk.set_shader_parameter("ink", SKETCH_INK)
		chalk.set_shader_parameter("strength", 1.0)
		art.material = chalk
	else:
		# Finished art shown as painted, darkened enough that the menu's light
		# text still reads over it.
		art.modulate = Color(0.45, 0.48, 0.55)
	return art


## Fades the picture back behind a panel full of text - a list of stages, the
## options - and brings it up again on the title screen, which has little over
## it.
func _quieten_backdrop(quiet: bool):
	if _backdrop == null:
		return
	var fade := create_tween()
	if _backdrop.material is ShaderMaterial:
		var chalk: ShaderMaterial = _backdrop.material
		fade.tween_method(func(value): chalk.set_shader_parameter("strength", value),
			chalk.get_shader_parameter("strength"), BACKDROP_QUIET if quiet else 1.0, 0.25)
	else:
		fade.tween_property(_backdrop, "modulate:a", BACKDROP_QUIET if quiet else 1.0, 0.25)


## --- The panels ---


## A centred column with a heading, which every panel is.
func _panel(title_text: String) -> VBoxContainer:
	var holder := VBoxContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.add_theme_constant_override("separation", 14)
	var title := Label.new()
	title.theme_type_variation = GameFonts.HEADER
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", INK)
	holder.add_child(title)
	return holder


func _build_root() -> Control:
	var holder := _panel("Messengers of Truth")
	# How a run that has just come back here went - a dungeon cleared. Hidden
	# otherwise.
	_note = Label.new()
	_note.name = "Note"
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.add_theme_font_size_override("font_size", 16)
	_note.add_theme_color_override("font_color", Color("9fc7a4"))
	_note.visible = false
	holder.add_child(_note)
	var buttons := VBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 8)
	buttons.custom_minimum_size = Vector2(280, 0)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	buttons.add_child(_menu_button("Play", func(): _show("play")))
	buttons.add_child(_menu_button("Arena Mode", func(): SceneTransition.change_scene(BATTLE_SELECT)))
	buttons.add_child(_menu_button("Stealth Stages", func(): _show(STEALTH_PANEL)))
	buttons.add_child(_menu_button("Clues Demo", func(): SceneTransition.change_scene(CLUES_DEMO)))
	buttons.add_child(_menu_button("Dungeon Demo", func(): Campaign.start_dungeon(load(DUNGEON_DEMO))))
	buttons.add_child(_menu_button("Options", func(): _show("options")))
	buttons.add_child(_menu_button("Glossary", func(): _open_glossary()))
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


## The stealth stages, one under another: a button to start each, with what it
## is about beneath it. A list rather than cards because they are played in
## order, each bringing in something new.
func _build_stealth() -> Control:
	var holder := _panel("Stealth Stages")
	# How the last one went, when a stage's way out has just sent the player
	# back here. Hidden otherwise.
	_stealth_note = Label.new()
	_stealth_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stealth_note.add_theme_font_size_override("font_size", 16)
	_stealth_note.add_theme_color_override("font_color", Color("9fc7a4"))
	_stealth_note.visible = false
	holder.add_child(_stealth_note)
	var help := Label.new()
	help.text = STEALTH_HELP
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size = Vector2(620, 0)
	help.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	help.add_theme_font_size_override("font_size", 14)
	help.add_theme_color_override("font_color", INK_DIM)
	holder.add_child(help)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.custom_minimum_size = Vector2(620, 0)
	column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for i in STEALTH_STAGES.size():
		var stage: Dictionary = STEALTH_STAGES[i]
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		row.add_child(_menu_button("%d   %s" % [i + 1, stage.name], _start_stage.bind(stage)))
		var about := Label.new()
		about.text = stage.description
		about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		about.add_theme_font_size_override("font_size", 13)
		about.add_theme_color_override("font_color", MUTED)
		row.add_child(about)
		column.add_child(row)
	# Scrolled rather than stretched, so the list can grow and Back stays on
	# the screen. The keyboard's place is kept in view as it moves.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(644, 430)
	scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	scroll.follow_focus = true
	scroll.add_child(column)
	holder.add_child(scroll)
	holder.add_child(_back_button())
	return holder


## The glossary keeps its own little stack of screens, so it arrives as one
## panel rather than six. Back inside it walks its own trail; Back on its first
## screen hands the menu back.
func _build_glossary() -> Control:
	var panel := GlossaryPanel.new()
	panel.closed.connect(_go_back)
	return panel


## Opened at its contents page rather than wherever it was last left, because
## coming back to the menu and pressing Glossary is starting again.
func _open_glossary():
	_show("glossary")
	var panel = _panels["glossary"]
	if panel.has_method("show_contents"):
		panel.show_contents()


func _build_options() -> Control:
	var holder := _panel("Options")
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	buttons.custom_minimum_size = Vector2(280, 0)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	buttons.add_child(_menu_button("Resolution", func(): _show("resolution")))
	buttons.add_child(_menu_button("Volume", func(): _show("volume")))
	holder.add_child(buttons)
	var speed := BattleSpeedPicker.new()
	speed.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for button in speed.buttons:
		button.custom_minimum_size = Vector2(84, 0)
		_dress(button)
	holder.add_child(speed)
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
	_window_mode = WindowModePicker.new()
	_window_mode.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for button in _window_mode.buttons:
		button.custom_minimum_size = Vector2(150, 0)
		_dress(button)
	holder.add_child(_window_mode)
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
	_dress(button)
	button.pressed.connect(on_press)
	return button


## The menu's look on any button - a card that lights up, edged in the accent
## when focused or pressed. A toggle that is on stays pressed, so the speed
## picker's chosen setting keeps its edge.
func _dress(button: Button):
	button.custom_minimum_size.y = 42
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_focus_color", INK)
	button.add_theme_stylebox_override("normal", _box(CARD))
	button.add_theme_stylebox_override("hover", _box(CARD_LIT))
	button.add_theme_stylebox_override("focus", _box(CARD_LIT, ACCENT))
	button.add_theme_stylebox_override("pressed", _box(CARD_LIT, ACCENT))
	button.add_theme_stylebox_override("hover_pressed", _box(CARD_LIT, ACCENT))
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_color_override("font_hover_pressed_color", INK)


## One of the four ways in: a portrait, a name, and what you are letting
## yourself in for.
func _way_in_card(way: Dictionary) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(210, 300)
	card.add_theme_stylebox_override("normal", _box(CARD))
	card.add_theme_stylebox_override("hover", _box(CARD_LIT))
	card.add_theme_stylebox_override("focus", _box(CARD_LIT, ACCENT))
	card.add_theme_stylebox_override("pressed", _box(CARD_LIT, ACCENT))
	card.tooltip_text = TooltipText.wrap(way.description)
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
	_quieten_backdrop(key != "root")


func _go_back():
	if _stack.size() > 1:
		_stack.pop_back()
	_show(_stack.back() if not _stack.is_empty() else "root", false)


## Remembers whatever the panel offers first, so the menu can be driven without
## a mouse - without lighting it up for somebody who is using one. See
## FocusOnDemand: the highlight is claimed on the first arrow key and let go
## again the moment the mouse moves.
func _focus_first(panel: Control):
	for node in panel.find_children("*", "Button", true, false):
		if node.visible:
			_keyboard.remember(node)
			return
	_keyboard.remember(null)


## Holds the keyboard's place without taking it. Built in _ready, before any
## panel is shown.
var _keyboard: FocusOnDemand


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


## Drops Cyrus into a stealth stage, with whoever and whatever it gives him.
func _start_stage(stage: Dictionary):
	_set_up_stage(stage)
	SceneTransition.change_scene(EXPLORATION)


## Everything starting a stage does short of going there.
func _set_up_stage(stage: Dictionary):
	Campaign.reset()
	_last_stage = stage.name
	Campaign.current_map = stage.map
	Campaign.target_entry = ""


## Resizing the window is all this has to do: the project stretches everything
## else to fit, which is why the pause menu's picker does the same and no more.
## In fullscreen it goes back to a window, which the picker above then says.
func _set_resolution(size: Vector2i):
	GameSettings.set_window_size(size)
	_window_mode.refresh()


func _quit():
	get_tree().quit()


## Escape steps back out of whatever is open, which is what it does everywhere
## else in the game.
func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel") and _stack.size() > 1:
		_go_back()
		get_viewport().set_input_as_handled()
