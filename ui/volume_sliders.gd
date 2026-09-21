extends VBoxContainer
class_name VolumeSliders
## The music and sound-effect sliders, as one thing both menus can drop in.
##
## Wherever volume is adjustable it should look and behave the same, and there
## should be one place where "what the slider does" is decided. The main menu
## builds one of these into its Volume panel; the pause menu puts one under
## Options, so the volume can be fixed without leaving the game.
##
## Levels live on Music, which saves them to user://settings.cfg, so a slider
## moved in one menu is already where you left it in the other.


## Label on the left, current level on the right, for each bus Music knows.
const ROWS := [
	{"label": "Music", "bus": "music"},
	{"label": "Sound effects", "bus": "sfx"},
]

## Matches the menus around it: body text and a dimmer readout beside it.
const INK_DIM := Color("c2ceda")
const MUTED := Color("8296a9")


func _ready():
	add_theme_constant_override("separation", 12)
	for row in ROWS:
		add_child(_row(row.label, row.bus))


## One slider, with what it controls on the left and where it currently sits on
## the right - a slider with no number is a guess.
func _row(label_text: String, which: String) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var heading := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", INK_DIM)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(label)
	var readout := Label.new()
	readout.add_theme_font_size_override("font_size", 15)
	readout.add_theme_color_override("font_color", MUTED)
	heading.add_child(readout)
	row.add_child(heading)

	var slider := HSlider.new()
	slider.name = "%sSlider" % which.capitalize()
	slider.min_value = 0.0
	slider.max_value = 1.0
	# One percent at a time. The readout is whole percentages, so a coarser step
	# meant the number jumped in fives and the levels in between were simply not
	# reachable - the slider could show 45 or 50 and nothing else.
	slider.step = 0.01
	slider.value = Music.volume(which)
	slider.custom_minimum_size = Vector2(0, 20)
	readout.text = "%d%%" % roundi(slider.value * 100.0)
	slider.value_changed.connect(func(level):
		Music.set_volume(which, level)
		readout.text = "%d%%" % roundi(level * 100.0)
	)
	row.add_child(slider)
	return row


## The sliders themselves, in order, for anything that needs to put keyboard
## focus on them - the pause menu cycles its controls with the arrow keys.
func sliders() -> Array:
	var found: Array = []
	for child in find_children("*", "HSlider", true, false):
		found.append(child)
	return found
