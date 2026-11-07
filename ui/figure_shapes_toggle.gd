extends CheckButton
class_name FigureShapesToggle
## Whether the light falls on figures as on a shape worked out from their pictures (GameSettings.figure_shapes): on the title
## screen's Options and the pause menu's, saved between runs, to compare with it off.


func _init():
	text = "Figures lit as shapes"
	tooltip_text = "The light falls on each figure as on a shape worked out from its picture. Off, as on a flat picture"
	button_pressed = GameSettings.figure_shapes()
	toggled.connect(func(on: bool): GameSettings.set_figure_shapes(on))
