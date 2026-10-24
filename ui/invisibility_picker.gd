extends PanelContainer
## Who Invisibility hides, on a stealth map: a button for each of the party on
## the map, all lit to begin with, and what that costs from the caster's Gates
## of Iris - a casting each. Holds the game while it is open (MenuPause), so
## choosing is not a race against the guards.
##
## Opened by the stealth bar's button or its key (G); the key again casts,
## Escape or Cancel puts it away. Built in code by StealthBar, which asks the
## watch for everything.

signal closed

const MUTED := Color("8296a9")

var watch: StealthWatch = null
## Party member key -> the button that says whether they are hidden.
var toggles := {}

var _cost: Label = null
var _cast: Button = null
var _gone := false


func _ready():
	name = "InvisibilityPicker"
	process_mode = Node.PROCESS_MODE_ALWAYS
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "Invisibility - who?"
	column.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	var first: Control = null
	for key in _standing():
		var toggle := Button.new()
		toggle.name = key
		toggle.toggle_mode = true
		if watch.unseen(key):
			toggle.text = "%s (%s)" % [Campaign.display_name_of(key), StealthBar.clock(watch.unseen_left(key))]
			toggle.disabled = true
		else:
			toggle.text = Campaign.display_name_of(key)
			toggle.button_pressed = true
			if first == null:
				first = toggle
		toggle.toggled.connect(func(_on): _refresh())
		row.add_child(toggle)
		toggles[key] = toggle
	_cost = Label.new()
	_cost.name = "Cost"
	_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cost.custom_minimum_size = Vector2(420, 0)
	_cost.add_theme_color_override("font_color", MUTED)
	column.add_child(_cost)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	_cast = Button.new()
	_cast.name = "Cast"
	_cast.pressed.connect(cast)
	buttons.add_child(_cast)
	var cancel := Button.new()
	cancel.name = "Cancel"
	cancel.text = Pad.hint("Cancel", &"ui_cancel")
	cancel.pressed.connect(close)
	buttons.add_child(cancel)
	_refresh()
	MenuPause.hold(self)
	FocusOnDemand.attach(self, first if first != null else cancel)


func _process(_delta):
	# Centred by hand: anchors resolve against nothing under a bare CanvasLayer.
	reset_size()
	position = ((get_viewport_rect().size - size) / 2.0).round()


func _exit_tree():
	MenuPause.release(self)


## Everybody on the map, leader first.
func _standing() -> Array:
	return watch._party_standing().map(func(someone): return someone.key)


## Who is lit to be hidden.
func chosen() -> Array:
	var keys := []
	for key in toggles:
		if toggles[key].button_pressed and not toggles[key].disabled:
			keys.append(key)
	return keys


func _refresh():
	var keys := chosen()
	_cast.text = Pad.hint("Cast", &"outside_spell")
	var refusal: String = "Choose somebody to hide" if keys.is_empty() else watch.invisibility_refusal(keys)
	_cast.disabled = refusal != ""
	_cast.tooltip_text = refusal
	if refusal != "":
		_cost.text = refusal
		return
	var spell: Dictionary = watch.invisibility_spell(keys.size())
	var skill: SkillDefinition = SkillDatabase.skills[spell.skill]
	var left: int = Campaign.outside_gates_left(spell.caster)[skill.outside_gate]
	_cost.text = "%d of %s's %d castings of %s - unseen for %s, until they do something to a guard. Hounds still smell them." % [
		keys.size(), Campaign.display_name_of(spell.caster), left, Stats.short_outside_gate_name(skill.outside_gate),
		StealthBar.clock(skill.outside_seconds)]


## Hides whoever is lit, and puts this away. False, and nothing done, when
## that can't be.
func cast() -> bool:
	var keys := chosen()
	if keys.is_empty() or watch.invisibility_refusal(keys) != "":
		return false
	close()
	return watch.go_invisible(keys)


func close():
	if _gone:
		return
	_gone = true
	MenuPause.release(self)
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent):
	if _gone or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif Pad.went_down(event, &"outside_spell"):
		cast()
		get_viewport().set_input_as_handled()
