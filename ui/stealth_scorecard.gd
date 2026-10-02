extends CanvasLayer
class_name StealthScorecard
## The card at a stealth map's way out: how it went, as a rank - Ghost,
## Shadow or Brawler - with the tally behind it and what there was to do.
## Continue carries on to wherever the way out goes. See
## StealthWatch.scorecard for what goes on it.

const PANEL := Color(0.08, 0.1, 0.14, 0.96)
const EDGE := Color("f2d38a")
const INK := Color("e8e2d4")
const MUTED := Color("8296a9")
const DONE := Color("9fc7a4")
const LOST := Color("e05a4a")
const RANK_COLOURS := {"Ghost": Color("a9c8f0"), "Shadow": Color("c9b3f0"), "Brawler": Color("e0b04a")}

var continue_button: Button = null
var _done := Callable()


func _init():
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS


## Shows `card` and calls `done` when Continue is pressed.
func open(card: Dictionary, done: Callable):
	_done = done
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = PANEL
	box.border_color = EDGE
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.content_margin_left = 36
	box.content_margin_right = 36
	box.content_margin_top = 24
	box.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", box)
	panel.custom_minimum_size = Vector2(440, 0)
	centre.add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	panel.add_child(rows)
	var rank := _label(card.get("rank", ""), 40, RANK_COLOURS.get(card.get("rank", ""), INK))
	rank.theme_type_variation = GameFonts.HEADER
	rows.add_child(rank)
	rows.add_child(_label(card.get("says", ""), 18, MUTED))
	rows.add_child(HSeparator.new())
	var tally := GridContainer.new()
	tally.columns = 2
	tally.add_theme_constant_override("h_separation", 28)
	tally.add_theme_constant_override("v_separation", 4)
	for line in [
			["Time", "%d:%02d" % [int(card.get("seconds", 0.0)) / 60, int(card.get("seconds", 0.0)) % 60]],
			["Times noticed", str(card.get("noticed", 0))],
			["Fights", str(card.get("fights", 0))],
			["Takedowns", str(card.get("takedowns", 0))],
			["Poisoned", str(card.get("poisoned", 0))],
			["Bodies found", str(card.get("bodies_found", 0))],
			["Pockets picked", str(card.get("pockets", 0))]]:
		tally.add_child(_label(line[0], 18, MUTED, HORIZONTAL_ALIGNMENT_LEFT))
		tally.add_child(_label(line[1], 18, INK, HORIZONTAL_ALIGNMENT_RIGHT))
	rows.add_child(tally)
	var objectives: Array = card.get("objectives", [])
	if not objectives.is_empty():
		rows.add_child(HSeparator.new())
		for objective in objectives:
			var said = {"done": "done", "lost": "missed"}.get(objective[1], "not done")
			var colour = {"done": DONE, "lost": LOST}.get(objective[1], MUTED)
			rows.add_child(_label("%s - %s" % [objective[0], said], 17, colour, HORIZONTAL_ALIGNMENT_LEFT))
	continue_button = Button.new()
	continue_button.text = "Continue"
	continue_button.custom_minimum_size = Vector2(180, 40)
	continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	continue_button.pressed.connect(_on_continue)
	rows.add_child(continue_button)
	continue_button.grab_focus.call_deferred()


func _label(text: String, size: int, colour: Color, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	return label


func _on_continue():
	var done = _done
	_done = Callable()
	queue_free()
	if done.is_valid():
		done.call()
