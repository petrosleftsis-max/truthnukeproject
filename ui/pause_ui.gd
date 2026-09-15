extends CanvasLayer
## Simple pause/options overlay, independent of the combat HUD - works no
## matter whose turn it is or what's happening. Escape toggles the Pause
## panel (title "Pause", with "Options", "Arena Mode" and "Main Menu");
## Options swaps to a resolution picker with the volume sliders under it.
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

## Whatever held the keyboard when this opened, handed back when it closes.
var _focus_before: Control = null


func _ready():
	# The whole point of this menu is that nothing happens while it is up, so
	# it has to be the one thing that still runs while the game is held. See
	# MenuPause.
	process_mode = Node.PROCESS_MODE_ALWAYS
	$PausePanel.visible = false
	$OptionsPanel.visible = false
	$PausePanel/VBox/OptionsButton.pressed.connect(_on_options_pressed)
	$PausePanel/VBox/LevelSelectButton.pressed.connect(_on_level_select_pressed)
	$PausePanel/VBox/MainMenuButton.pressed.connect(_on_main_menu_pressed)
	$OptionsPanel/VBox/Res1280Button.pressed.connect(func(): set_resolution(1280, 720))
	$OptionsPanel/VBox/Res1920Button.pressed.connect(func(): set_resolution(1920, 1080))
	$OptionsPanel/VBox/Res2560Button.pressed.connect(func(): set_resolution(2560, 1440))
	_volume = VolumeSliders.new()
	$OptionsPanel/VBox.add_child(_volume)
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
	if not $PausePanel.visible and not $OptionsPanel.visible:
		# Who had the keyboard before this opened. A dialogue balloon holds it
		# while a conversation is on, and Enter stops advancing the conversation
		# if it doesn't get it back.
		_focus_before = get_viewport().gui_get_focus_owner()
	MenuPause.hold(self)
	$PausePanel.visible = panel == $PausePanel
	$OptionsPanel.visible = panel == $OptionsPanel
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
	if $OptionsPanel.visible:
		# Escape from Options goes back to Pause, rather than closing everything.
		_show_panel($PausePanel, _pause_buttons)
	elif $PausePanel.visible:
		_close()
	else:
		_show_panel($PausePanel, _pause_buttons)
	get_viewport().set_input_as_handled()


func _on_options_pressed():
	_show_panel($OptionsPanel, _options_buttons)


## Jumps straight to the battle list. Exploration is the hub now, so this is
## the way to reach a fight without walking to it - handy for testing an
## encounter in isolation. It abandons whatever is on screen, so anything
## unresolved in the current battle is simply dropped.
func _on_level_select_pressed():
	# Let go before leaving, or the battle list arrives frozen.
	_close()
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
