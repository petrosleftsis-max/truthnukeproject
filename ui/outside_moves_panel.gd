extends PanelContainer
class_name OutsideMovesPanel
## The leader's moves on a map, in the action bar's place (OutsideMoves; the
## designer, 2026-10-26): Skills and Spells, the castings left through each gate
## and the Gates of Iris, and how loud each move is - said only out here. Clicking
## one uses it; one that does nothing outside a fight, or nothing now, is greyed
## and its tooltip says why. Out Of Combat Only narrows the spells to those marked
## for it (OutsideMoves.shown_out_of_combat), and stays as it was left for as long
## as the game runs. Swap Leader (Tab) changes whose they are. The Outside Spell
## key (G) offers the spells to keys and a pad, which have no pointer on a map.

const BUTTON_SIZE := Vector2(46, 46)
const COLUMNS := 6
const SCROLL_HEIGHT := 98.0
## How often it looks again at what can be used - a guard turning up, somebody
## hurt - in seconds.
const REFRESH_SECONDS := 0.25
const TAB_ON := Color("dce8f5")
const TAB_OFF := Color("8296a9")
## A move's noise on its button: a letter in a colour.
const NOISE_MARKS := {
	SkillDefinition.Loudness.SILENT: ["S", Color("9fc7a4")],
	SkillDefinition.Loudness.QUIET: ["Q", Color("e0b04a")],
	SkillDefinition.Loudness.LOUD: ["L", Color("e05a4a")],
}

## Kept for the viewer while the game runs, map to map.
static var remembered_only := false
static var remembered_spells := false

## The map (ExplorationScene).
var scene: Node = null
var showing_spells := false
var out_of_combat_only := false

var _skills_tab: Button = null
var _spells_tab: Button = null
var _only: CheckBox = null
var _gates: HBoxContainer = null
var _grid: GridContainer = null
var _empty: Label = null
var _since := 0.0
## Whose moves, on which tab, the buttons were last built for.
var _built_for := ""


func _ready():
	showing_spells = remembered_spells
	out_of_combat_only = remembered_only
	mouse_filter = Control.MOUSE_FILTER_STOP
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	add_child(column)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	column.add_child(top)
	_skills_tab = _tab("Skills", false)
	top.add_child(_skills_tab)
	_spells_tab = _tab("Spells", true)
	top.add_child(_spells_tab)
	_only = CheckBox.new()
	_only.name = "OutOfCombatOnly"
	_only.text = "Out of combat only"
	_only.focus_mode = Control.FOCUS_NONE
	_only.add_theme_font_size_override("font_size", 13)
	_only.tooltip_text = "Only the spells for outside a fight."
	_only.button_pressed = out_of_combat_only
	_only.toggled.connect(set_out_of_combat_only)
	top.add_child(_only)
	_gates = HBoxContainer.new()
	_gates.name = "Gates"
	_gates.add_theme_constant_override("separation", 10)
	column.add_child(_gates)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(COLUMNS * BUTTON_SIZE.x + (COLUMNS - 1) * 4, SCROLL_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var holder := VBoxContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(holder)
	_grid = GridContainer.new()
	_grid.name = "Moves"
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	holder.add_child(_grid)
	_empty = Label.new()
	_empty.add_theme_font_size_override("font_size", 13)
	_empty.add_theme_color_override("font_color", TAB_OFF)
	holder.add_child(_empty)
	if not Campaign.party_changed.is_connected(_on_party_changed):
		Campaign.party_changed.connect(_on_party_changed)
	refresh(true)


func _exit_tree():
	if Campaign.party_changed.is_connected(_on_party_changed):
		Campaign.party_changed.disconnect(_on_party_changed)


func _tab(text: String, spells: bool) -> Button:
	var tab := Button.new()
	tab.name = text + "Tab"
	tab.text = text
	tab.focus_mode = Control.FOCUS_NONE
	tab.flat = true
	tab.add_theme_font_size_override("font_size", 14)
	tab.pressed.connect(show_spells.bind(spells))
	return tab


func _process(delta):
	_since += delta
	if _since >= REFRESH_SECONDS:
		refresh()


func _on_party_changed():
	refresh.call_deferred(true)


## Skills (false) or Spells (true).
func show_spells(spells: bool):
	showing_spells = spells
	remembered_spells = spells
	refresh(true)


func set_out_of_combat_only(on: bool):
	out_of_combat_only = on
	remembered_only = on
	if _only != null and _only.button_pressed != on:
		_only.set_pressed_no_signal(on)
	refresh(true)


## Whose moves these are: the leader.
func who() -> String:
	return Campaign.leader()


## The moves on show, by key: the leader's skills, or spells by gate - narrowed
## to the out-of-combat ones while Out Of Combat Only is ticked.
func shown_moves() -> Array:
	var shown := []
	for move in OutsideMoves.moves_of(who()):
		var skill: SkillDefinition = SkillDatabase.skills[move]
		if Combat.is_spell(skill) != showing_spells:
			continue
		if showing_spells and out_of_combat_only and not OutsideMoves.shown_out_of_combat(skill):
			continue
		shown.append(move)
	if showing_spells:
		shown.sort_custom(func(a, b): return SkillDatabase.skills[a].spell_slot_level < SkillDatabase.skills[b].spell_slot_level)
	return shown


## The button for `move`, or null when it is not on show.
func button_for(move: String) -> Button:
	return _grid.get_node_or_null(move) as Button if _grid != null else null


## Looks again at what can be used now; `rebuild` lays the buttons out afresh.
func refresh(rebuild: bool = false):
	_since = 0.0
	if _grid == null:
		return
	var key := who()
	var moves := shown_moves()
	var built := "%s|%s|%s|%s" % [key, showing_spells, out_of_combat_only, ",".join(moves)]
	if rebuild or built != _built_for:
		_built_for = built
		for child in _grid.get_children():
			_grid.remove_child(child)
			child.queue_free()
		for move in moves:
			_grid.add_child(_button(move))
	_skills_tab.add_theme_color_override("font_color", TAB_ON if not showing_spells else TAB_OFF)
	_spells_tab.add_theme_color_override("font_color", TAB_ON if showing_spells else TAB_OFF)
	_only.visible = showing_spells
	for button in _grid.get_children():
		_freshen(button, key)
	_empty.visible = moves.is_empty()
	_empty.text = "No out-of-combat spells." if showing_spells and out_of_combat_only else ("No spells." if showing_spells else "No skills.")
	_show_gates(key)


func _button(move: String) -> Button:
	var skill: SkillDefinition = SkillDatabase.skills[move]
	var button := Button.new()
	button.name = move
	button.custom_minimum_size = BUTTON_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.icon = skill.icon
	button.expand_icon = true
	SkillLook.decorate(button, skill)
	var mark: Array = NOISE_MARKS.get(skill.noise, [])
	if not mark.is_empty():
		var badge := Label.new()
		badge.name = "Noise"
		badge.text = mark[0]
		badge.add_theme_font_size_override("font_size", 11)
		badge.add_theme_color_override("font_color", mark[1])
		badge.add_theme_color_override("font_outline_color", Color.BLACK)
		badge.add_theme_constant_override("outline_size", 3)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.position = Vector2(BUTTON_SIZE.x - 11, -2)
		button.add_child(badge)
	button.pressed.connect(_use.bind(move))
	return button


## Greyed or not, and what hovering it says.
func _freshen(button: Button, key: String):
	var move: String = button.name
	var skill: SkillDefinition = SkillDatabase.skills.get(move)
	if skill == null:
		return
	var why := OutsideMoves.refusal(scene, key, move)
	button.disabled = why != ""
	var lines := [skill.name, OutsideMoves.USE_NAMES[OutsideMoves.use_of(skill)], "Noise: " + OutsideMoves.noise_fact(skill)]
	if skill.spell_slot_level > 0:
		var cost := Stats.gate_name(skill.spell_slot_level)
		if OutsideMoves.iris_gate_for(skill) > 0:
			cost = "%s first, then %s" % [Stats.outside_gate_name(OutsideMoves.iris_gate_for(skill)), cost]
		lines.append("Paid through the " + cost)
	if skill.description != "":
		lines.append("")
		lines.append(skill.description)
	if why != "":
		lines.push_front("")
		lines.push_front(why)
	var tip := TooltipText.wrap("\n".join(lines))
	if button.tooltip_text != tip:
		button.tooltip_text = tip


func _use(move: String):
	OutsideMoves.use(scene, who(), move)
	refresh()


## The leader's castings: each gate they have, and Iris.
func _show_gates(key: String):
	var reading := []
	var left := Campaign.gates_left_outside(key)
	var most := Campaign.gates_most(key)
	for gate in range(1, mini(left.size(), most.size())):
		if most[gate] > 0:
			reading.append([Stats.short_gate_name(gate), left[gate], most[gate], Stats.gate_colour(gate)])
	var outside_left := Campaign.outside_gates_left(key)
	var outside_most := Campaign.outside_gates_most(key)
	for gate in range(1, outside_most.size()):
		if outside_most[gate] > 0:
			reading.append([Stats.short_outside_gate_name(gate), outside_left[gate], outside_most[gate], Stats.OUTSIDE_GATES[gate].colour])
	var labels := _gates.get_children()
	while labels.size() < reading.size():
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 13)
		_gates.add_child(label)
		labels.append(label)
	for i in labels.size():
		labels[i].visible = i < reading.size()
		if i < reading.size():
			labels[i].name = "Gate_" + reading[i][0]
			labels[i].text = "%s %d/%d" % [reading[i][0], reading[i][1], reading[i][2]]
			labels[i].add_theme_color_override("font_color", reading[i][3])
	_gates.visible = not reading.is_empty()
