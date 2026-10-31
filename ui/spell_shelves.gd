extends ScrollContainer
class_name SpellShelves
## The Spells panel: one shelf per gate, its tag - the gate's name and the
## castings left through it - at the start, and the spells cast through it
## after, wrapping onto another line when there are more than fit.
##
## It keeps the action panel's size and scrolls rather than growing: there are
## three gates today and more to come, and a panel that grew with them would
## push everything around it off the screen.

const SEPARATION := 4
## Wide enough for the longest gate name there is.
const TAG_WIDTH := 64

var _rows: VBoxContainer = null
var _buttons: Array[Button] = []
var _keys: Array[String] = []
## Whose spells, from which action, are on the shelves - so a rebuild for the
## same panel keeps its place, and a different one starts at the top.
var _showing := ""


func _init():
	name = "SpellShelves"
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	visible = false
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", SEPARATION)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_rows)
	_style_scrollbar()


## Builds a shelf for each gate `spells` are cast through, lowest gate first,
## from copies of `template`. What each button does is the caller's business:
## buttons() and keys() hand them back in the order they are shown.
##
## `flat` puts them all on one shelf with no gate tag - for skills, more of them
## than the action grid has buttons for (CombatUI._show_skills_for).
##
## `iris` (outside a fight - OutsideMovesPanel) is the spells paid through the
## Gates of Iris, by Iris gate: a shelf each, first, tagged with comb's
## "iris_left" and "iris_most" castings.
func build(spells: Array, comb: Dictionary, template: Button, showing: String, flat: bool = false, iris: Dictionary = {}):
	var keep_place := showing == _showing
	var place := scroll_vertical
	_showing = showing
	for row in _rows.get_children():
		_rows.remove_child(row)
		row.queue_free()
	_buttons.clear()
	_keys.clear()
	var by_gate := {}
	for key in spells:
		var skill: SkillDefinition = SkillDatabase.skills[key]
		var gate := 0 if flat else maxi(skill.spell_slot_level, 1)
		if not by_gate.has(gate):
			by_gate[gate] = []
		by_gate[gate].append(key)
	var gates := by_gate.keys()
	gates.sort()
	var iris_gates := iris.keys().filter(func(gate): return not iris[gate].is_empty())
	iris_gates.sort()
	for gate in iris_gates:
		_shelf("Iris%d" % gate, iris[gate], template, gate, true)
	for gate in gates:
		_shelf("Gate%d" % gate, by_gate[gate], template, gate, false)
	show_counts(comb)
	# The new rows are laid out on the next frame; the old place can only be
	# gone back to once they have been.
	if keep_place:
		set_deferred("scroll_vertical", place)
	else:
		scroll_vertical = 0


## A shelf of `spells` called `shelf_name`: tagged with `gate` (an Iris gate
## when `of_iris`; none for 0).
func _shelf(shelf_name: String, spells: Array, template: Button, gate: int, of_iris: bool):
	var shelf := HBoxContainer.new()
	shelf.name = shelf_name
	shelf.add_theme_constant_override("separation", SEPARATION)
	_rows.add_child(shelf)
	if gate > 0:
		var tag := GateTag.new(true)
		tag.name = "Tag"
		tag.iris = of_iris
		tag.level = gate
		tag.custom_minimum_size = Vector2(TAG_WIDTH, template.custom_minimum_size.y)
		# At the top of its shelf, beside the first line of spells, however
		# many lines the shelf runs to.
		tag.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		shelf.add_child(tag)
	var spread := HFlowContainer.new()
	spread.name = "Spells"
	spread.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spread.add_theme_constant_override("h_separation", SEPARATION)
	spread.add_theme_constant_override("v_separation", SEPARATION)
	shelf.add_child(spread)
	for key in spells:
		var button: Button = template.duplicate(0)
		button.name = key
		spread.add_child(button)
		_buttons.append(button)
		_keys.append(key)


## Each shelf's tag told the castings left: comb's "spell_slots" and
## "max_spell_slots", and for the Gates of Iris its "iris_left" and "iris_most".
func show_counts(comb: Dictionary):
	for shelf in _rows.get_children():
		var tag = shelf.get_node_or_null("Tag")
		if not tag is GateTag:
			continue
		var gate: int = tag.level
		var left: Array = comb.get("iris_left" if tag.iris else "spell_slots", [])
		var most: Array = comb.get("iris_most" if tag.iris else "max_spell_slots", [])
		var have: int = left[gate] if gate < left.size() else 0
		var could: int = most[gate] if gate < most.size() else 0
		if tag.iris:
			tag.show_iris(gate, have, could)
		else:
			tag.show_gate(gate, have, could)


func buttons() -> Array[Button]:
	return _buttons


func keys() -> Array[String]:
	return _keys


## The shelf for `gate`, or null when nothing on show is cast through it - for
## the Gates of Iris `gate` when `of_iris`.
func shelf(gate: int, of_iris: bool = false) -> HBoxContainer:
	return _rows.get_node_or_null(("Iris%d" if of_iris else "Gate%d") % gate)


## Slim, and in the HUD's blue - the engine's own is a grey slab.
func _style_scrollbar():
	var bar := get_v_scroll_bar()
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.07, 0.09, 0.12, 0.6)
	track.set_corner_radius_all(3)
	track.content_margin_left = 3
	track.content_margin_right = 3
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color("4a86c8")
	grab.set_corner_radius_all(3)
	var lit := grab.duplicate()
	lit.bg_color = Color("7fb4ea")
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("scroll_focus", track)
	bar.add_theme_stylebox_override("grabber", grab)
	bar.add_theme_stylebox_override("grabber_highlight", lit)
	bar.add_theme_stylebox_override("grabber_pressed", lit)
