extends Control
## Not part of the game. Open scenes/try_stealth_stages.tscn and press F6 to
## pick a stealth test stage without going through the title screen - the same
## stages as its Stealth Stages (MainMenu.STEALTH_STAGES), and the lab demo.
## Each drops Cyrus onto its map with the party and kit it needs; reaching a
## stage's way out goes to the title screen's list of stages.

const LAB_DEMO := {
	"name": "The lab demo",
	"map": "res://scenes/stealth_demo.tscn",
	"description": "The first demo: three guards, a disguise and a notice board.",
}


## Everything on offer here, top to bottom.
static func stages() -> Array:
	return MainMenu.STEALTH_STAGES + [LAB_DEMO]


func _ready():
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.07, 0.09)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.add_theme_constant_override("separation", 14)
	add_child(column)
	var title := Label.new()
	title.text = "Stealth Stages"
	title.theme_type_variation = GameFonts.HEADER
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	for stage in stages():
		var row := VBoxContainer.new()
		var button := Button.new()
		button.text = stage.name
		button.custom_minimum_size = Vector2(520, 48)
		button.pressed.connect(_play.bind(stage.map))
		row.add_child(button)
		var about := Label.new()
		about.text = stage.description
		about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		about.custom_minimum_size = Vector2(520, 0)
		about.add_theme_font_size_override("font_size", 16)
		about.modulate = Color(1, 1, 1, 0.75)
		row.add_child(about)
		column.add_child(row)
	# Centred by hand once its size is known - a centre preset only moves its
	# top-left corner there.
	await get_tree().process_frame
	column.position = (get_viewport_rect().size - column.size) / 2.0


func _play(map: String):
	Campaign.reset()
	Campaign.current_map = map
	get_tree().change_scene_to_file("res://scenes/exploration.tscn")
