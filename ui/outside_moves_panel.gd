extends PanelContainer
class_name OutsideMovesPanel
## The leader's moves on a map, in the action bar's place (OutsideMoves; the
## designer, 2026-10-26): Skills, Spells and the damaging Items they carry (to
## start a fight with, or knock a wall down), the castings left through each gate
## and the Gates of Iris, and how loud each move is - said only out here. Clicking
## one uses it; one that does nothing outside a fight, or nothing now, is greyed
## and its tooltip says why. Out Of Combat Only narrows the spells to those marked
## for it (OutsideMoves.shown_out_of_combat), and stays as it was left for as long
## as the game runs. Swap Leader (Tab) changes whose they are. The Outside Spell
## key (G) offers the spells to keys and a pad, which have no pointer on a map.
##
## The Spells tab is the fight's Spells panel (the designer, 2026-10-31): a shelf
## per gate, its tag at the start (SpellShelves), and first a shelf for the
## Gates of Iris - the spells paid through it (Invisibility, the Out Of Combat
## ones it covers). Only gates with a spell on show have a shelf, so Out Of
## Combat Only leaves out the gates with nothing left to show. The gate counters
## beside the tabs (Iris among them) stand down while the shelves are up, as in
## a fight.

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

## The tabs.
enum Tab { SKILLS, SPELLS, ITEMS }

## Kept for the viewer while the game runs, map to map.
static var remembered_only := false
static var remembered_tab := Tab.SKILLS

## The map (ExplorationScene).
var scene: Node = null
var tab := Tab.SKILLS
var out_of_combat_only := false
## Whether the Spells tab is on show.
var showing_spells: bool:
	get:
		return tab == Tab.SPELLS

var _skills_tab: Button = null
var _spells_tab: Button = null
var _items_tab: Button = null
## Readying instead of using (OutsideMoves "Readied, out of a fight").
var readying := false
var _ready_box: CheckBox = null
var _only: CheckBox = null
var _gates: HBoxContainer = null
var _scroll: ScrollContainer = null
var _grid: GridContainer = null
## The Spells tab's shelves, and the button they are made from.
var _shelves: SpellShelves = null
var _template: Button = null
var _empty: Label = null
var _since := 0.0
## Whose moves, on which tab, the buttons were last built for.
var _built_for := ""


func _ready():
	tab = remembered_tab
	out_of_combat_only = remembered_only
	mouse_filter = Control.MOUSE_FILTER_STOP
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	add_child(column)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	column.add_child(top)
	_skills_tab = _tab("Skills", Tab.SKILLS)
	top.add_child(_skills_tab)
	_spells_tab = _tab("Spells", Tab.SPELLS)
	top.add_child(_spells_tab)
	_items_tab = _tab("Items", Tab.ITEMS)
	top.add_child(_items_tab)
	_only = CheckBox.new()
	_only.name = "OutOfCombatOnly"
	_only.text = "Out of combat only"
	_only.focus_mode = Control.FOCUS_NONE
	_only.add_theme_font_size_override("font_size", 13)
	_only.tooltip_text = "Only the spells for outside a fight."
	_only.button_pressed = out_of_combat_only
	_only.toggled.connect(set_out_of_combat_only)
	top.add_child(_only)
	_ready_box = CheckBox.new()
	_ready_box.name = "Readying"
	_ready_box.text = "Ready"
	_ready_box.focus_mode = Control.FOCUS_NONE
	_ready_box.add_theme_font_size_override("font_size", 13)
	_ready_box.tooltip_text = "Click a move to hold it back for a guard stepping into its reach, into an area you mark, or being hit. Whoever readies it has to keep that in sight, or it is lost."
	_ready_box.toggled.connect(set_readying)
	top.add_child(_ready_box)
	var stay := Button.new()
	stay.name = "StayHere"
	stay.focus_mode = Control.FOCUS_NONE
	stay.flat = true
	stay.add_theme_font_size_override("font_size", 13)
	stay.text = Pad.hint("Stay", &"stay_here")
	stay.tooltip_text = "The leader stays where they are, and the next of the party leads. Walk back up to them to bring them along again."
	# Over a network the host's map is told too (Net).
	stay.pressed.connect(func():
		scene.stay_here()
		Net.pressed_here(&"stay_here", Coop.controller_of(who())))
	top.add_child(stay)
	_gates = HBoxContainer.new()
	_gates.name = "Gates"
	_gates.add_theme_constant_override("separation", 6)
	column.add_child(_gates)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(COLUMNS * BUTTON_SIZE.x + (COLUMNS - 1) * 4, SCROLL_HEIGHT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_template = Button.new()
	_template.custom_minimum_size = BUTTON_SIZE
	_template.focus_mode = Control.FOCUS_NONE
	_template.expand_icon = true
	_shelves = SpellShelves.new()
	# Exactly the grid's size, as in a fight, so the panel keeps its shape from
	# tab to tab; what does not fit scrolls.
	_shelves.custom_minimum_size = _scroll.custom_minimum_size
	column.add_child(_shelves)
	var holder := VBoxContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(holder)
	_grid = GridContainer.new()
	_grid.name = "Moves"
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	holder.add_child(_grid)
	_empty = Label.new()
	_empty.add_theme_font_size_override("font_size", 13)
	_empty.add_theme_color_override("font_color", TAB_OFF)
	column.add_child(_empty)
	if not Campaign.party_changed.is_connected(_on_party_changed):
		Campaign.party_changed.connect(_on_party_changed)
	refresh(true)


func _exit_tree():
	if Campaign.party_changed.is_connected(_on_party_changed):
		Campaign.party_changed.disconnect(_on_party_changed)


func _notification(what: int):
	# The shelves' template was never in the tree to go with it.
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_template):
		_template.free()


func _tab(text: String, which: int) -> Button:
	var button := Button.new()
	button.name = text + "Tab"
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.flat = true
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(show_tab.bind(which))
	return button


func _process(delta):
	_since += delta
	if _since >= REFRESH_SECONDS:
		refresh()


func _on_party_changed():
	refresh.call_deferred(true)


## Skills (false) or Spells (true).
func show_spells(spells: bool):
	show_tab(Tab.SPELLS if spells else Tab.SKILLS)


func show_tab(which: int):
	tab = which
	remembered_tab = which
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
	if tab == Tab.ITEMS:
		return OutsideMoves.items_of(who())
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
	for button in _move_buttons():
		if button.name == move:
			return button
	return null


## The buttons on show: the grid's, or the shelves'.
func _move_buttons() -> Array:
	if _grid == null:
		return []
	return Array(_shelves.buttons()) if showing_spells else _grid.get_children()


## The shelves (SpellShelves), while the Spells tab is up.
func shelves() -> SpellShelves:
	return _shelves if showing_spells else null


## Looks again at what can be used now; `rebuild` lays the buttons out afresh.
func refresh(rebuild: bool = false):
	_since = 0.0
	if _grid == null:
		return
	var key := who()
	var moves := shown_moves()
	var built := "%s|%s|%s|%s" % [key, tab, out_of_combat_only, ",".join(moves)]
	if rebuild or built != _built_for:
		_built_for = built
		for child in _grid.get_children():
			_grid.remove_child(child)
			child.queue_free()
		if showing_spells:
			_fill_shelves(key, moves)
		else:
			for move in moves:
				_grid.add_child(_button(move))
	_skills_tab.add_theme_color_override("font_color", TAB_ON if tab == Tab.SKILLS else TAB_OFF)
	_spells_tab.add_theme_color_override("font_color", TAB_ON if tab == Tab.SPELLS else TAB_OFF)
	_items_tab.add_theme_color_override("font_color", TAB_ON if tab == Tab.ITEMS else TAB_OFF)
	_only.visible = showing_spells
	_scroll.visible = not showing_spells
	_shelves.visible = showing_spells and not moves.is_empty()
	if showing_spells:
		_shelves.show_counts(_castings_of(key))
	for button in _move_buttons():
		_freshen(button, key)
	_empty.visible = moves.is_empty()
	_empty.text = "No out-of-combat spells." if showing_spells and out_of_combat_only else ["No skills.", "No spells.", "Nothing to throw that hurts."][tab]
	_show_gates(key)


## The Iris gate `skill` is paid through, `key`'s having castings there - its
## own Outside Gate (Invisibility: Iris alone), or the one an Out Of Combat
## spell is paid through first - or 0.
func _iris_of(key: String, skill: SkillDefinition) -> int:
	var gate := skill.outside_gate if skill.outside_gate > 0 else OutsideMoves.iris_gate_for(skill)
	var most := Campaign.outside_gates_most(key)
	return gate if gate > 0 and gate < most.size() and most[gate] > 0 else 0


## `key`'s castings for the shelves' tags: the gates' (left for the next fight),
## and the Gates of Iris's.
func _castings_of(key: String) -> Dictionary:
	return {"spell_slots": Campaign.gates_left_outside(key), "max_spell_slots": Campaign.gates_most(key),
		"iris_left": Campaign.outside_gates_left(key), "iris_most": Campaign.outside_gates_most(key)}


## The spells on the shelves: through the Gates of Iris first, each Iris gate's
## shelf; the rest by their gate, as in a fight.
func _fill_shelves(key: String, moves: Array):
	var iris := {}
	var by_gate := []
	for move in moves:
		var gate := _iris_of(key, SkillDatabase.skills[move])
		if gate > 0:
			if not iris.has(gate):
				iris[gate] = []
			iris[gate].append(move)
		else:
			by_gate.append(move)
	_shelves.build(by_gate, _castings_of(key), _template, key, false, iris)
	var shown := _shelves.buttons()
	var keys := _shelves.keys()
	for i in shown.size():
		_dress(shown[i], keys[i])


func _button(move: String) -> Button:
	var button := Button.new()
	button.name = move
	button.custom_minimum_size = BUTTON_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.expand_icon = true
	_dress(button, move)
	return button


## What `move`'s button shows and does: its icon and look, its noise, its use.
func _dress(button: Button, move: String):
	var skill: SkillDefinition = OutsideMoves.definition_of(move)
	button.icon = skill.icon
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


## Greyed or not, and what hovering it says.
func _freshen(button: Button, key: String):
	var move: String = button.name
	var skill: SkillDefinition = OutsideMoves.definition_of(move)
	if skill == null:
		return
	var why := OutsideMoves.refusal(scene, key, move)
	if readying:
		var watch = scene.get("stealth")
		why = "Only where guards watch" if watch == null else watch.ready_refusal(key, move, SkillDefinition.Trigger.ENTERS_REACH)
	button.disabled = why != ""
	var lines := [skill.name, OutsideMoves.USE_NAMES[OutsideMoves.use_of(skill)], "Noise: " + OutsideMoves.noise_fact(skill)]
	if skill.outside_gate > 0:
		# Invisibility: through Iris alone, a casting for each it hides.
		lines.append("Paid through the %s, a casting for each it hides" % Stats.outside_gate_name(skill.outside_gate))
	elif skill.spell_slot_level > 0:
		var cost := Stats.gate_name(skill.spell_slot_level)
		if OutsideMoves.iris_gate_for(skill) > 0:
			cost = "%s first, then %s" % [Stats.outside_gate_name(OutsideMoves.iris_gate_for(skill)), cost]
		lines.append("Paid through the " + cost)
	if OutsideMoves.use_of(skill) == OutsideMoves.Use.INVISIBILITY:
		var watch = scene.get("stealth")
		if watch != null and is_instance_valid(watch):
			var hidden := []
			for one in Campaign.living_party():
				if watch.unseen(one):
					hidden.append("%s %s" % [Campaign.display_name_of(one), StealthBar.clock(watch.unseen_left(one))])
			if not hidden.is_empty():
				lines.append("Invisible: " + ", ".join(hidden))
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
	if readying:
		_choose_trigger(move)
		return
	# Over a network the joiner's moves are the host's to use (Net).
	# On a joiner it is used on the host, but for what is chosen here first
	# (OutsideMoves.use).
	OutsideMoves.use(scene, who(), move)
	refresh()


## Readying moves rather than using them, or not.
func set_readying(on: bool):
	readying = on
	if _ready_box != null and _ready_box.button_pressed != on:
		_ready_box.set_pressed_no_signal(on)
	refresh(true)


## What a move readied waits for (OutsideReadyChoice).
func _choose_trigger(move: String):
	var layer := CanvasLayer.new()
	layer.name = "ReadyChoice"
	layer.layer = 60
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	scene.add_child(layer)
	var choice := OutsideReadyChoice.new()
	choice.scene = scene
	choice.key = who()
	choice.move = move
	choice.closed.connect(layer.queue_free)
	choice.closed.connect(set_readying.bind(false))
	layer.add_child(choice)


## The leader's castings beside the tabs, as in a fight (GateTag): each gate they
## have, and Iris - stood down while the shelves, which carry the same tags, are up.
func _show_gates(key: String):
	var reading := []
	var castings := _castings_of(key)
	for gate in range(1, mini(castings.spell_slots.size(), castings.max_spell_slots.size())):
		if castings.max_spell_slots[gate] > 0:
			reading.append([false, gate])
	for gate in range(1, castings.iris_most.size()):
		if castings.iris_most[gate] > 0:
			reading.append([true, gate])
	var tags := _gates.get_children()
	while tags.size() < reading.size():
		var tag := GateTag.new()
		_gates.add_child(tag)
		tags.append(tag)
	for i in tags.size():
		tags[i].visible = i < reading.size()
		if i >= reading.size():
			continue
		var of_iris: bool = reading[i][0]
		var gate: int = reading[i][1]
		if of_iris:
			tags[i].name = "Gate_" + Stats.short_outside_gate_name(gate)
			tags[i].show_iris(gate, castings.iris_left[gate], castings.iris_most[gate])
		else:
			tags[i].name = "Gate_" + Stats.short_gate_name(gate)
			tags[i].show_gate(gate, castings.spell_slots[gate], castings.max_spell_slots[gate])
	_gates.visible = not reading.is_empty() and not showing_spells
