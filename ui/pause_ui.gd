extends CanvasLayer
## Simple pause/options overlay, independent of the combat HUD - works no
## matter whose turn it is or what's happening. Escape toggles the Pause
## panel (title "Pause", one "Options" button); Options swaps to a
## resolution picker (title "Options", one button per resolution). Picking
## a resolution just resizes the actual game window - the project's
## canvas_items stretch mode (set up when the game was moved to widescreen
## resolutions) handles rescaling everything else automatically, so nothing
## else needs to happen here.
##
## To add another resolution option later: duplicate one of the buttons
## under OptionsPanel/VBox in the editor, give it new text, and connect its
## pressed signal (or just add another line in _ready() below) to
## set_resolution() with the new width/height.

@export var controller: CController


func _ready():
	$PausePanel.visible = false
	$OptionsPanel.visible = false
	$PausePanel/VBox/OptionsButton.pressed.connect(_on_options_pressed)
	$OptionsPanel/VBox/Res1280Button.pressed.connect(func(): set_resolution(1280, 720))
	$OptionsPanel/VBox/Res1920Button.pressed.connect(func(): set_resolution(1920, 1080))
	$OptionsPanel/VBox/Res2560Button.pressed.connect(func(): set_resolution(2560, 1440))


func _unhandled_input(event):
	if not event.is_action_pressed("ui_cancel"):
		return
	if controller != null and controller.is_skill_selected():
		# Let CController's own Escape handling cancel the in-progress skill
		# targeting instead - that takes priority over opening this.
		return
	if $OptionsPanel.visible:
		# Escape from Options goes back to Pause, rather than closing everything.
		$OptionsPanel.visible = false
		$PausePanel.visible = true
	else:
		$PausePanel.visible = not $PausePanel.visible
	get_viewport().set_input_as_handled()


func _on_options_pressed():
	$PausePanel.visible = false
	$OptionsPanel.visible = true


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
	$OptionsPanel.visible = false
