extends CanvasLayer
## Simple pause/options overlay, independent of the combat HUD - works no
## matter whose turn it is or what's happening. Escape toggles the Pause
## panel (title "Pause", with "Glossary", "Options", "Arena Mode" and "Main
## Menu"); Options swaps to a resolution picker with the volume sliders under
## it, and Glossary swaps to the same book the main menu opens.
## The sliders are the same ones the main menu shows (ui/volume_sliders.gd)
## and are driven with the mouse - the arrow keys belong to the button loop
## here. Picking a resolution just resizes the actual game window - the project's
## canvas_items stretch mode (set up when the game was moved to widescreen
## resolutions) handles rescaling everything else automatically, so nothing
## else needs to happen here.
##
## Whichever panel is showing takes keyboard focus, so the arrow keys (and
## Tab) cycle its buttons and Enter/Space presses the focused one. That focus
## is also what stops CameraController panning the map underneath - it skips
## keyboard panning whenever anything holds focus, which only ever happens
## here, since every combat HUD button is focus_mode = None.
##
## To add another resolution option later: duplicate one of the buttons
## under OptionsPanel/VBox in the editor, give it new text, add it to
## _options_buttons below, and connect its pressed signal in _ready().

@export var controller: CController

@onready var _pause_buttons: Array = [
	$PausePanel/VBox/GlossaryButton,
	$PausePanel/VBox/OptionsButton,
	$PausePanel/VBox/LevelSelectButton,
	$PausePanel/VBox/MainMenuButton,
]
@onready var _options_buttons: Array = [
	$OptionsPanel/VBox/Res1280Button,
	$OptionsPanel/VBox/Res1920Button,
	$OptionsPanel/VBox/Res2560Button,
]

## Built rather than placed, so the sliders and what they do live in one place
## shared with the main menu (see ui/volume_sliders.gd).
var _volume: VolumeSliders = null

## The same book the main menu opens, built the same way and for the same
## reason: one glossary, read from wherever you happen to be. It wants far more
## room than the other two panels, since it is a list and a page side by side.
var _glossary: GlossaryPanel = null
var _glossary_panel: PanelContainer = null

## Whatever held the keyboard when this opened, handed back when it closes.
var _focus_before: Control = null


func _ready():
	# The whole point of this menu is that nothing happens while it is up, so
	# it has to be the one thing that still runs while the game is held. See
	# MenuPause.
	process_mode = Node.PROCESS_MODE_ALWAYS
	$PausePanel.visible = false
	$OptionsPanel.visible = false
	$PausePanel/VBox/GlossaryButton.pressed.connect(_on_glossary_pressed)
	$PausePanel/VBox/OptionsButton.pressed.connect(_on_options_pressed)
	$PausePanel/VBox/LevelSelectButton.pressed.connect(_on_level_select_pressed)
	$PausePanel/VBox/MainMenuButton.pressed.connect(_on_main_menu_pressed)
	$OptionsPanel/VBox/Res1280Button.pressed.connect(func(): set_resolution(1280, 720))
	$OptionsPanel/VBox/Res1920Button.pressed.connect(func(): set_resolution(1920, 1080))
	$OptionsPanel/VBox/Res2560Button.pressed.connect(func(): set_resolution(2560, 1440))
	_volume = VolumeSliders.new()
	$OptionsPanel/VBox.add_child(_volume)
	_build_glossary()
	FocusLoop.link(_pause_buttons)
	FocusLoop.link(_options_buttons)


## Holds the keyboard's place on the first button of whatever is now visible,
## without lighting it up for somebody using the mouse. See FocusOnDemand.
var _keyboard: FocusOnDemand


## Shows one panel, hides the other, and remembers where the keyboard starts.
##
## Also stops the game. Blocking input was not enough on its own: a click that
## landed beside the panel rather than on it reached the map underneath and
## moved somebody, and whatever was already in flight carried on regardless.
func _show_panel(panel: Control, buttons: Array):
	if not $PausePanel.visible and not $OptionsPanel.visible and not _glossary_showing():
		# Who had the keyboard before this opened. A dialogue balloon holds it
		# while a conversation is on, and Enter stops advancing the conversation
		# if it doesn't get it back.
		_focus_before = get_viewport().gui_get_focus_owner()
	MenuPause.hold(self)
	$PausePanel.visible = panel == $PausePanel
	$OptionsPanel.visible = panel == $OptionsPanel
	if _glossary_panel != null:
		_glossary_panel.visible = panel == _glossary_panel
	if not buttons.is_empty():
		if _keyboard == null:
			_keyboard = FocusOnDemand.attach(self, buttons[0])
		else:
			_keyboard.remember(buttons[0])


## Closes the overlay and hands keyboard control back to the game - without
## the explicit release, the last button keeps focus while invisible and the
## camera stays frozen.
func _close():
	$PausePanel.visible = false
	$OptionsPanel.visible = false
	if _glossary_panel != null:
		_glossary_panel.visible = false
	MenuPause.release(self)
	var focused = get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()
	if is_instance_valid(_focus_before) and _focus_before.is_visible_in_tree():
		_focus_before.grab_focus()
	_focus_before = null


func _unhandled_input(event):
	if not event.is_action_pressed("ui_cancel"):
		return
	if controller != null and controller.is_skill_selected():
		# Let CController's own Escape handling cancel the in-progress skill
		# targeting instead - that takes priority over opening this.
		return
	if $OptionsPanel.visible or _glossary_showing():
		# Escape from a sub-panel goes back to Pause rather than closing
		# everything, so one key does not drop you out of the game from three
		# screens deep.
		_show_panel($PausePanel, _pause_buttons)
	elif $PausePanel.visible:
		_close()
	else:
		_show_panel($PausePanel, _pause_buttons)
	get_viewport().set_input_as_handled()


func _on_options_pressed():
	_show_panel($OptionsPanel, _options_buttons)


func _glossary_showing() -> bool:
	return _glossary_panel != null and _glossary_panel.visible


## The book, in a panel of its own. Wide, because it puts a list of entries
## beside the page they open.
func _build_glossary():
	_glossary_panel = PanelContainer.new()
	_glossary_panel.name = "GlossaryPanel"
	_glossary_panel.visible = false
	_glossary_panel.set_anchors_preset(Control.PRESET_CENTER)
	_glossary_panel.offset_left = -420.0
	_glossary_panel.offset_top = -280.0
	_glossary_panel.offset_right = 420.0
	_glossary_panel.offset_bottom = 280.0
	_glossary_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_glossary_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_glossary = GlossaryPanel.new()
	# Back inside the book walks its own trail; Back on its first screen is
	# what hands the pause menu back, exactly as it hands the main menu back.
	_glossary.closed.connect(func(): _show_panel($PausePanel, _pause_buttons))
	_glossary_panel.add_child(_glossary)
	add_child(_glossary_panel)


## Opened at its contents page rather than wherever it was last left, because
## pressing Glossary is starting again - the same as from the main menu.
func _on_glossary_pressed():
	_show_panel(_glossary_panel, [])
	if _glossary != null and _glossary.has_method("show_contents"):
		_glossary.show_contents()


## Jumps straight to the battle list. Exploration is the hub now, so this is
## the way to reach a fight without walking to it - handy for testing an
## encounter in isolation. It abandons whatever is on screen, so anything
## unresolved in the current battle is simply dropped.
func _on_level_select_pressed():
	# Let go before leaving, or the battle list arrives frozen.
	_close()
	# Remembered before anything is cleared, so the arena can hand the player
	# back to the fight or the map they left - including the tile they were
	# standing on, which only a map has.
	var scene = get_tree().current_scene
	var standing_at = null
	if scene != null and scene.has_method("party_position"):
		standing_at = scene.party_position()
	Campaign.enter_arena_from(scene.scene_file_path if scene != null else "", standing_at)
	Campaign.return_to_position = false
	SceneTransition.change_scene("res://scenes/level_select.tscn")


## Back to the title screen. Abandons the battle, the same way Arena Mode
## above does - and unlike quitting, which in a web build does nothing at all.
func _on_main_menu_pressed():
	_close()
	Campaign.to_main_menu()


func set_resolution(width: int, height: int):
	# Window.size can be unreliable here specifically because canvas_items
	# stretch mode is active - it goes through Godot's content-scale
	# bookkeeping rather than actually resizing the OS window. DisplayServer
	# operates on the real window directly, bypassing that.
	# The project has window/size/resizable=false, which on some platforms
	# blocks *programmatic* resize requests too, not just user drag-resize -
	# clear that flag right before resizing, then restore it, so dragging
	# stays locked but this still works.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, false)
	DisplayServer.window_set_size(Vector2i(width, height))
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, true)
	print("Requested resolution ", width, "x", height, " - actual window size is now ", DisplayServer.window_get_size())
	get_window().move_to_center()
	# Applying a choice closes the whole overlay and returns to the game,
	# rather than going back to the Pause panel.
	_close()
