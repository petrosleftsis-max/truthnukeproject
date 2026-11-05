extends CanvasLayer
class_name PrepareSpells
## Which spells somebody goes into the coming fights with (Campaign "Preparing spells";
## the designer, 2026-11-05). Put up by the map whenever Campaign.prepare_due: after a
## long rest, and as a dungeon that says so begins. Each caster in turn, for whoever
## steers them: so many spells by their level, a lock on any that should stay prepared
## through the next long rest, and Done. A window is shown only to the player who
## steers that character (over a network, on their own machine; on one screen, with the
## focus theirs). Somebody with no caster, or done before the other, is told who they
## are waiting for. Everybody can look through the character sheets and the glossary
## meanwhile. Up here only this machine's party stands; nothing else waits for it over a
## network. All of it placeholder looks, as ever.

signal finished

const INK := Color("dce8f5")
const MUTED := Color("8296a9")
const WARM := Color("e8c27a")
const LOCKED := Color("f0a15a")
const PANEL_SIZE := Vector2(720, 560)

var _panel: PanelContainer = null
var _title: Label = null
var _count: Label = null
var _note: Label = null
var _scroll: ScrollContainer = null
var _rows: VBoxContainer = null
var _same: Button = null
var _done: Button = null
var _sheets: Button = null
var _glossary: Button = null
var _glossary_panel: PanelContainer = null

## Whoever is being prepared for, "" while waiting on somebody else.
var preparing := ""
var _picked: Array = []
var _locks: Array = []
## Spell key -> its button, and its lock.
var _spell_buttons := {}
var _lock_buttons := {}
## Whether this machine has nobody left to prepare for and is waiting on the other's.
var waiting := false
## The groups stood still by waiting, not being a menu by then (Net needs those keys).
var _rooted: Array = []


func _ready():
	name = "PrepareSpells"
	# Under the character sheet, which goes over it (layer 8).
	layer = 7
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	MenuPause.hold(self)
	_next()


func _process(_delta):
	# Centred by hand: anchors resolve against nothing under a bare CanvasLayer.
	_panel.reset_size()
	_panel.position = ((_panel.get_viewport_rect().size - _panel.size) / 2.0).round()
	if _glossary_panel != null and _glossary_panel.visible:
		_glossary_panel.reset_size()
		_glossary_panel.position = ((_glossary_panel.get_viewport_rect().size - _glossary_panel.size) / 2.0).round()
	# Waiting: the other player has finished, or the other machine has gone.
	if waiting:
		if Campaign.preparing_left().is_empty():
			_finish()
		elif not own_left().is_empty():
			_next()
		else:
			_say_who_it_is()


func _build():
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_panel.add_child(column)
	_title = Label.new()
	_title.name = "Title"
	_title.theme_type_variation = GameFonts.HEADER
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", INK)
	column.add_child(_title)
	_count = Label.new()
	_count.name = "Count"
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.add_theme_font_size_override("font_size", 16)
	_count.add_theme_color_override("font_color", WARM)
	column.add_child(_count)
	_scroll = ScrollContainer.new()
	_scroll.name = "Spells"
	_scroll.custom_minimum_size = Vector2(PANEL_SIZE.x, PANEL_SIZE.y - 190)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 4)
	_scroll.add_child(_rows)
	_note = Label.new()
	_note.name = "Note"
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(PANEL_SIZE.x, 0)
	_note.add_theme_font_size_override("font_size", 14)
	_note.add_theme_color_override("font_color", MUTED)
	column.add_child(_note)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	column.add_child(buttons)
	_sheets = _button("Sheets", "Character sheets", _open_sheets)
	buttons.add_child(_sheets)
	_glossary = _button("Glossary", "Glossary", _open_glossary)
	buttons.add_child(_glossary)
	_same = _button("Same", "Same as last time", _same_as_last_time)
	buttons.add_child(_same)
	_done = _button("Done", "Done", _on_done)
	buttons.add_child(_done)


func _button(called: String, text: String, pressed: Callable) -> Button:
	var made := Button.new()
	made.name = called
	made.text = text
	made.custom_minimum_size = Vector2(150, 40)
	made.pressed.connect(pressed)
	return made


## Those of the casters still to prepare whom this machine's player steers.
func own_left() -> Array:
	return Campaign.preparing_left().filter(func(key): return not Coop.on() or Coop.is_local(Coop.controller_of(key)))


func _next():
	var mine := own_left()
	if mine.is_empty():
		if Campaign.preparing_left().is_empty():
			_finish()
		else:
			_wait()
		return
	_show_caster(mine[0])


func _show_caster(key: String):
	if waiting:
		waiting = false
		_root_own_groups(false)
		MenuPause.hold(self)
	preparing = key
	_picked = Campaign.prepared_list(key).duplicate()
	_locks = Campaign.locked_spells.get(key, []).duplicate()
	var player := Coop.controller_of(key)
	# On one screen, theirs alone to answer while it is up.
	if Coop.on() and not Net.with_another():
		Coop.take_focus(player, self)
	_title.text = "%s: prepare spells" % Campaign.display_name_of(key)
	if Coop.on():
		_title.text += " - %s" % Coop.name_of(player)
	_scroll.visible = true
	_same.visible = not Campaign.last_prepared.get(key, []).is_empty()
	_done.visible = true
	_note.text = "Prepared spells are the ones they can cast until the next long rest. A locked spell stays prepared through it."
	_fill_rows()
	_refresh_count()


func _fill_rows():
	for row in _rows.get_children():
		_rows.remove_child(row)
		row.queue_free()
	_spell_buttons.clear()
	_lock_buttons.clear()
	var gates := {}
	for spell in Campaign.prepare_choices(preparing):
		var gate: int = SkillDatabase.skills[spell].spell_slot_level
		if not gates.has(gate):
			gates[gate] = []
		gates[gate].append(spell)
	var order: Array = gates.keys()
	order.sort()
	for gate in order:
		var heading := Label.new()
		heading.text = Stats.gate_name(gate)
		heading.theme_type_variation = GameFonts.HEADER
		heading.add_theme_font_size_override("font_size", 17)
		heading.add_theme_color_override("font_color", Stats.gate_colour(gate))
		_rows.add_child(heading)
		for spell in gates[gate]:
			_rows.add_child(_spell_row(spell))


func _spell_row(spell: String) -> Control:
	var skill: SkillDefinition = SkillDatabase.skills[spell]
	var row := HBoxContainer.new()
	row.name = "Row_" + spell
	row.add_theme_constant_override("separation", 8)
	var pick := Button.new()
	pick.name = "Spell_" + spell
	pick.toggle_mode = true
	pick.text = skill.name
	pick.custom_minimum_size = Vector2(220, 32)
	pick.icon = skill.icon
	pick.expand_icon = true
	pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
	pick.tooltip_text = TooltipText.wrap(skill.description)
	pick.set_pressed_no_signal(_picked.has(spell))
	pick.toggled.connect(_toggle_spell.bind(spell))
	row.add_child(pick)
	var lock := Button.new()
	lock.name = "Lock_" + spell
	lock.toggle_mode = true
	lock.text = "Lock"
	lock.custom_minimum_size = Vector2(64, 32)
	lock.tooltip_text = "Locked, it stays prepared through the next long rest. Take the lock off at a long rest to let it go."
	lock.set_pressed_no_signal(_locks.has(spell))
	lock.toggled.connect(_toggle_lock.bind(spell))
	row.add_child(lock)
	var facts := Label.new()
	facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	facts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	facts.add_theme_font_size_override("font_size", 13)
	facts.add_theme_color_override("font_color", MUTED)
	facts.text = ", ".join(CharacterSheet.facts_of(skill, {"level": Campaign.party_level}))
	row.add_child(facts)
	_spell_buttons[spell] = pick
	_lock_buttons[spell] = lock
	_show_lock(spell)
	return row


func _show_lock(spell: String):
	var lock: Button = _lock_buttons.get(spell)
	if lock != null:
		lock.add_theme_color_override("font_color", LOCKED if _locks.has(spell) else MUTED)


func _refresh_count():
	var most := Campaign.prepare_limit()
	_count.text = "Prepared %d of %d" % [_picked.size(), most]
	_count.add_theme_color_override("font_color", WARM if _picked.size() < most else LOCKED)


func _toggle_spell(pressed: bool, spell: String):
	if pressed:
		if _picked.size() >= Campaign.prepare_limit():
			_spell_buttons[spell].set_pressed_no_signal(false)
			_note.text = "They can prepare %d at this level: let one go first." % Campaign.prepare_limit()
			return
		_picked.append(spell)
	else:
		if _locks.has(spell):
			_spell_buttons[spell].set_pressed_no_signal(true)
			_note.text = "%s is locked: take the lock off first." % SkillDatabase.skills[spell].name
			return
		_picked.erase(spell)
	_refresh_count()


func _toggle_lock(pressed: bool, spell: String):
	if pressed:
		if not _picked.has(spell):
			if _picked.size() >= Campaign.prepare_limit():
				_lock_buttons[spell].set_pressed_no_signal(false)
				_note.text = "They can prepare %d at this level: let one go first." % Campaign.prepare_limit()
				return
			_picked.append(spell)
			_spell_buttons[spell].set_pressed_no_signal(true)
		_locks.append(spell)
	else:
		_locks.erase(spell)
	_show_lock(spell)
	_refresh_count()


## What they had prepared before this long rest, as far as it still goes.
func _same_as_last_time():
	var kept: Array = _locks.duplicate()
	for spell in Campaign.last_prepared.get(preparing, []):
		if not kept.has(spell) and _spell_buttons.has(spell) and kept.size() < Campaign.prepare_limit():
			kept.append(spell)
	_picked = kept
	for spell in _spell_buttons:
		_spell_buttons[spell].set_pressed_no_signal(_picked.has(spell))
	_refresh_count()


func _on_done():
	if preparing == "":
		return
	Campaign.set_prepared(preparing, _picked, _locks)
	Campaign.finish_preparing(preparing)
	Net.send_menu_changes()
	Coop.let_go(self)
	preparing = ""
	_next()


## Nobody left for this machine's player to prepare: told who they are waiting for.
func _wait():
	waiting = true
	preparing = ""
	_scroll.visible = false
	_same.visible = false
	_done.visible = false
	_count.text = ""
	_note.text = "You can look through the character sheets and the glossary meanwhile."
	_say_who_it_is()
	# No longer a menu that keeps what it changes, so what the other machine changes
	# reaches here; but the party still stands.
	MenuPause.release(self)
	_root_own_groups(true)


func _say_who_it_is():
	var left: Array = Campaign.preparing_left()
	var players := []
	for key in left:
		var named := Coop.name_of(Coop.controller_of(key))
		if not players.has(named):
			players.append(named)
	_title.text = "Waiting for %s to choose their spells" % " and ".join(players)


func _root_own_groups(on: bool):
	var scene = get_tree().current_scene
	if on:
		_rooted.clear()
		var groups: Dictionary = scene.get("groups") if scene != null and scene.get("groups") != null else {}
		for id in groups:
			if Coop.is_local(id) and is_instance_valid(groups[id]) and not groups[id].rooted:
				groups[id].rooted = true
				_rooted.append(groups[id])
		var alone = scene.get("party") if scene != null else null
		if groups.is_empty() and alone != null and is_instance_valid(alone) and not alone.rooted:
			alone.rooted = true
			_rooted.append(alone)
	else:
		for group in _rooted:
			if is_instance_valid(group):
				group.rooted = false
		_rooted.clear()


func _finish():
	waiting = false
	_root_own_groups(false)
	MenuPause.release(self)
	Coop.let_go(self)
	Campaign.prepare_due = false
	Net.send_menu_changes()
	finished.emit()
	queue_free()


func _exit_tree():
	_root_own_groups(false)
	MenuPause.release(self)
	Coop.let_go(self)


func _open_sheets():
	for node in get_tree().get_nodes_in_group(&"pad_menu"):
		if node is CharacterSheet:
			node.open(true)
			return


func _open_glossary():
	if _glossary_panel == null:
		_glossary_panel = PanelContainer.new()
		_glossary_panel.name = "GlossaryHere"
		_glossary_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(_glossary_panel)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 8)
		_glossary_panel.add_child(column)
		var book := GlossaryPanel.new()
		book.custom_minimum_size = Vector2(PANEL_SIZE.x, PANEL_SIZE.y)
		column.add_child(book)
		book.show_contents()
		var back := _button("BackFromGlossary", "Back", func(): _glossary_panel.visible = false)
		back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(back)
	_glossary_panel.visible = true
