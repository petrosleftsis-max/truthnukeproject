extends PanelContainer
class_name ReadyPicker
## The player readying a move in a fight (Combat "Ready" - the designer,
## 2026-10-29): first the move, then what it waits for - somebody stepping into
## its reach or out of it, somebody casting, somebody stepping into an area
## marked on the board, or somebody chosen, in sight, being hit. The HUD's Ready
## button opens it (combat_ui); an area is then marked with a click on the board.

signal closed

const MUTED := Color("8296a9")

var combat: Combat = null
var comb: Dictionary = {}
## The HUD, which takes the click that marks an area.
var hud: Control = null

var _column: VBoxContainer = null
var _gone := false
var _skill_key := ""


func _ready():
	name = "ReadyPicker"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 8)
	add_child(_column)
	_show_moves()


func _process(_delta):
	# Centred by hand: anchors resolve against nothing under a bare CanvasLayer.
	reset_size()
	position = ((get_viewport_rect().size - size) / 2.0).round()


## Every move `comb` could ready now, by key.
func readiable() -> Array:
	var found := []
	for key in comb.get("skill_list", []):
		if combat.ready_refusal(comb, key, SkillDefinition.Trigger.ENTERS_REACH) == "":
			found.append(key)
	return found


## Every trigger `_skill_key` could wait for, as [label, trigger, watched or {}].
func triggers() -> Array:
	var skill: SkillDefinition = SkillDatabase.skills[_skill_key]
	var by := _by()
	var who: String = SkillDefinition.WHO_NAMES[by]
	var found := [
		["%s steps into its reach" % who.capitalize(), SkillDefinition.Trigger.ENTERS_REACH, {}],
		["%s leaves its reach" % who.capitalize(), SkillDefinition.Trigger.LEAVES_REACH, {}],
		["%s casts a spell" % who.capitalize(), SkillDefinition.Trigger.CASTS, {}],
	]
	if not combat.is_melee(skill):
		found.append(["%s steps into a cone you point" % who.capitalize(), SkillDefinition.Trigger.ENTERS_AREA, {}])
	for other in combat.combatants:
		if not other.get("alive", false) or is_same(other, comb) or other.has("object") or other.get("illusion", false):
			continue
		if combat.ready_refusal(comb, _skill_key, SkillDefinition.Trigger.HIT_IN_SIGHT, Combat.NO_AREA, by, other) == "":
			found.append(["%s is hit" % other.name, SkillDefinition.Trigger.HIT_IN_SIGHT, other])
	return found


## Who sets an either-side trigger off: allies for a move meant for them.
func _by() -> int:
	var skill: SkillDefinition = SkillDatabase.skills.get(_skill_key)
	return SkillDefinition.SetOffBy.ALLIES if skill != null and skill.targets_ally else SkillDefinition.SetOffBy.ENEMIES


func _clear():
	for child in _column.get_children():
		_column.remove_child(child)
		child.queue_free()


func _heading(text: String):
	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = text
	_column.add_child(title)


func _button(text: String, called: String, pressed: Callable) -> Button:
	var button := Button.new()
	button.name = called
	button.text = text
	button.pressed.connect(pressed)
	_column.add_child(button)
	return button


func _cancel_button():
	_button(Pad.hint("Cancel", &"ui_cancel"), "Cancel", close)


func _show_moves():
	_clear()
	_heading("Ready what?")
	var first: Button = null
	for key in readiable():
		var button := _button(SkillDatabase.skills[key].name, key, _choose_move.bind(key))
		if first == null:
			first = button
	if first == null:
		var none := Label.new()
		none.text = "Nothing %s could ready now." % comb.get("name", "they")
		none.add_theme_color_override("font_color", MUTED)
		_column.add_child(none)
	_cancel_button()
	FocusOnDemand.attach(self, first if first != null else _column.get_child(_column.get_child_count() - 1))


func _choose_move(key: String):
	_skill_key = key
	_clear()
	_heading("%s - for when?" % SkillDatabase.skills[key].name)
	var first: Button = null
	var index := 0
	for option in triggers():
		var button := _button(option[0], "Trigger%d" % index, _choose_trigger.bind(option[1], option[2]))
		button.set_meta("trigger", option[1])
		index += 1
		if first == null:
			first = button
	_button("Back", "Back", _show_moves)
	_cancel_button()
	FocusOnDemand.attach(self, first)


func _choose_trigger(trigger: int, watched: Dictionary):
	if trigger == SkillDefinition.Trigger.ENTERS_AREA:
		var hold := {"comb": comb, "skill": _skill_key, "by": _by()}
		close()
		if hud != null and hud.has_method("mark_ready_area"):
			hud.mark_ready_area(hold)
		return
	var skill_key := _skill_key
	var by := _by()
	close()
	# Over a network the other machine readies it too (Net).
	Net.fight_move(combat, "ready", [comb.get("id", -1), skill_key, trigger, Combat.NO_AREA, by, watched.get("id", -1)])
	combat.ready_action(comb, skill_key, trigger, Combat.NO_AREA, by, watched)


func close():
	if _gone:
		return
	_gone = true
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent):
	if _gone or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
