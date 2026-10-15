extends Control
class_name InterrogationPanel
## After a won fight, everybody taken alive (Combat.prisoners - surrendered, or
## knocked out while the party was taking them alive), to question and then let
## go or hand over. ResultUI puts it up before its own panel.
##
## Questioning is Campaign.interrogate: what clues and gold they give up, who
## they answer to, and enough about their kind to use against the next of them -
## or, for somebody with an interrogation_dialogue, that conversation instead.
## What becomes of them is Campaign.release_prisoner.

signal done

const BALLOON_SCENE := "res://ui/dialogue_balloon.tscn"
const TEXT := Color("e8e0cc")
const DIM := Color("9a907a")
const GOOD := Color("9fe0a8")

var _prisoners: Array = []
var _rows: VBoxContainer = null
var _done_button: Button = null
## How many of each kind were taken, by combatant key.
var _counts: Dictionary = {}


## Puts up `prisoners` (combatant dictionaries) - one of each kind, with
## `counts` saying how many of that kind (combatant key) were taken.
func show_prisoners(prisoners: Array, counts: Dictionary = {}):
	_counts = counts
	_prisoners = prisoners
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	centre.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var title := Label.new()
	title.text = "Prisoners"
	title.theme_type_variation = GameFonts.HEADER
	title.add_theme_font_size_override("font_size", 26)
	column.add_child(title)
	var about := Label.new()
	about.text = "Taken alive. Question them, then let them go or hand them over to the watch."
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.add_theme_color_override("font_color", DIM)
	column.add_child(about)
	# Everybody taken alive in a fight can be a long list: it scrolls.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, mini(prisoners.size() * 76, 430))
	column.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 12)
	scroll.add_child(_rows)
	for prisoner in prisoners:
		_rows.add_child(_row_for(prisoner))
	_done_button = Button.new()
	_done_button.text = "Done"
	_done_button.pressed.connect(func(): done.emit())
	column.add_child(_done_button)
	var first := _first_button()
	if first != null:
		FocusOnDemand.attach(self, first)


func _row_for(prisoner: Dictionary) -> Control:
	var row := VBoxContainer.new()
	row.set_meta("prisoner", prisoner)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	row.add_child(top)
	var face := TextureRect.new()
	face.texture = prisoner.get("icon")
	face.custom_minimum_size = Vector2(48, 48)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top.add_child(face)
	var name_label := Label.new()
	var taken: int = _counts.get(prisoner.get("combatant_key", ""), 1)
	name_label.text = "%s - %s" % [prisoner.get("base_name", prisoner.name),
		("%d taken" % taken) if taken > 1 else ("surrendered" if prisoner.get("taken", "") == "surrendered" else "knocked out")]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", TEXT)
	top.add_child(name_label)
	var question := Button.new()
	question.name = "Question"
	question.text = "Question"
	question.pressed.connect(_question.bind(row))
	top.add_child(question)
	var release := Button.new()
	release.name = "Release"
	release.text = "Let go"
	release.pressed.connect(_settle.bind(row, false))
	top.add_child(release)
	var hand_over := Button.new()
	hand_over.name = "HandOver"
	hand_over.text = "Hand over"
	hand_over.pressed.connect(_settle.bind(row, true))
	top.add_child(hand_over)
	var learned := Label.new()
	learned.name = "Learned"
	learned.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	learned.add_theme_color_override("font_color", GOOD)
	learned.visible = false
	row.add_child(learned)
	return row


## Questions the prisoner on `row`.
func _question(row: Control):
	var prisoner: Dictionary = row.get_meta("prisoner")
	var key: String = prisoner.get("combatant_key", "")
	var question: Button = row.find_child("Question", true, false)
	question.disabled = true
	var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
	var lines: Array = Campaign.interrogate(key)
	var manager = get_node_or_null("/root/DialogueManager")
	if definition != null and definition.interrogation_dialogue != null and manager != null:
		# Their own conversation, over this panel, and back to it after.
		visible = false
		manager.show_dialogue_balloon_scene(BALLOON_SCENE, definition.interrogation_dialogue,
			definition.interrogation_title if definition.interrogation_title != "" else "start")
		await manager.dialogue_ended
		if not is_inside_tree():
			return
		visible = true
	var learned: Label = row.find_child("Learned", true, false)
	learned.text = "\n".join(lines.map(func(line): return "- " + line)) if not lines.is_empty() else "They have nothing worth telling."
	learned.visible = true
	_refocus()


## Lets the prisoner on `row` go, or hands them over.
func _settle(row: Control, handed_over: bool):
	var prisoner: Dictionary = row.get_meta("prisoner")
	var key: String = prisoner.get("combatant_key", "")
	Campaign.release_prisoner(key, handed_over, _counts.get(key, 1))
	for button_name in ["Question", "Release", "HandOver"]:
		var button: Button = row.find_child(button_name, true, false)
		if button != null:
			button.queue_free()
	var learned: Label = row.find_child("Learned", true, false)
	learned.text = (learned.text + "\n" if learned.visible else "") + ("Handed over to the watch." if handed_over else "Let go.")
	learned.visible = true
	_refocus.call_deferred()


func _first_button() -> Button:
	for row in _rows.get_children() if _rows != null else []:
		for button_name in ["Question", "Release"]:
			var button: Button = row.find_child(button_name, true, false)
			if button != null and not button.disabled and not button.is_queued_for_deletion():
				return button
	return _done_button


func _refocus():
	var first := _first_button()
	if first != null and is_inside_tree():
		first.grab_focus()


## For a test: the row of the prisoner called `prisoner_name`, or null.
func row_of(prisoner_name: String) -> Control:
	for row in _rows.get_children():
		if row.get_meta("prisoner").name == prisoner_name:
			return row
	return null
