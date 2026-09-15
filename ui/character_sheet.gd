extends CanvasLayer
class_name CharacterSheet
## The sheet behind C: who this character is, what they are made of, and what
## every one of their companions is made of, without leaving the map.
##
## Everything a combatant's numbers decide - how hard they hit, what they can
## survive, which skills they have unlocked - was previously only inferable
## from watching a fight happen. This is the one place to read it directly.
##
## Opens on whoever is most relevant right now: the combatant whose turn it is
## during a battle, the party leader while exploring. Buttons along the bottom
## step through everyone else on the player's side, and only appear when there
## is somebody else to step to.
##
## Built in code rather than as a scene for the same reason the battle selector
## is: nearly all of it is per character - a portrait that has to animate, a
## row of buttons as long as the party is - and a scene file would be a second
## place to keep the layout in step.


## Set in a battle scene. Left null while exploring, where there is no Combat
## node and the party comes from Campaign instead.
@export var combat: Combat

## Palette, matching ui/blue_theme.tres.
const INK := Color("dce8f5")
const INK_DIM := Color("c2ceda")
const MUTED := Color("8296a9")
const ACCENT := Color("4a86c8")

## How large the idle animation is drawn. Frames are a tile across (192px) and
## the panel is not, so they come down to something that leaves room for the
## numbers beside them.
const PORTRAIT_SCALE := 0.75
const PORTRAIT_BOX := Vector2(190, 210)

var _open := false
var _index := 0
var _entries: Array = []

var _root: Control = null
var _title: Label = null
var _subtitle: Label = null
var _portrait: Control = null
var _animated: AnimatedSprite2D = null
var _still: TextureRect = null
var _stat_rows: VBoxContainer = null
var _members: HBoxContainer = null


func _ready():
	layer = 8
	# Still runs while the game is held, since it is one of the two things that
	# can be doing the holding. See MenuPause.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false
	if combat != null and combat.has_signal("combatant_studied"):
		combat.combatant_studied.connect(_on_combatant_studied)


## Study has just opened someone up, so show what was found rather than making
## the player go and look: the skill costs an action, and its whole payoff is
## the reading.
func _on_combatant_studied(combatant: Dictionary):
	open_on(combatant.name)


## Opens the sheet on a named combatant, falling back to the usual choice when
## there is nobody by that name to show.
##
## Doesn't stop the game the way opening it yourself does: this is the sheet
## arriving in the middle of the skill that measured them, which is still
## resolving, and freezing it half-finished is not what was asked for. Nobody
## can move while the sheet is up either way.
func open_on(who: String):
	open(false)
	if not _open:
		return
	for i in range(_entries.size()):
		if _entries[i].name == who:
			_index = i
			_show_entry()
			return


## --- Layout ---


func _build():
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Swallows clicks on the map behind it, so opening the sheet mid-turn can't
	# also order somebody to walk somewhere.
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.05, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(centre)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	centre.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	# The name sits above the sprite, as its heading.
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", INK)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)

	_subtitle = Label.new()
	_subtitle.add_theme_font_size_override("font_size", 12)
	_subtitle.add_theme_color_override("font_color", MUTED)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_subtitle)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	column.add_child(body)

	_portrait = Control.new()
	_portrait.custom_minimum_size = PORTRAIT_BOX
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_portrait)

	# An animated combatant plays their idle here; one with no SpriteFrames
	# falls back to the flat map sprite, so the sheet works either way.
	_animated = AnimatedSprite2D.new()
	_animated.scale = Vector2(PORTRAIT_SCALE, PORTRAIT_SCALE)
	_animated.position = PORTRAIT_BOX * 0.5
	_portrait.add_child(_animated)

	_still = TextureRect.new()
	_still.set_anchors_preset(Control.PRESET_FULL_RECT)
	_still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_still.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_still.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.add_child(_still)

	_stat_rows = VBoxContainer.new()
	_stat_rows.add_theme_constant_override("separation", 4)
	_stat_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stat_rows.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(_stat_rows)

	_members = HBoxContainer.new()
	_members.add_theme_constant_override("separation", 6)
	_members.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_members)

	var hint := Label.new()
	hint.text = "C or Escape to close"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)


## --- Opening and closing ---


func is_open() -> bool:
	return _open


func toggle():
	if _open:
		close()
	else:
		open()


## `hold_the_game` is what makes this a menu rather than an overlay: the game
## stops behind it, so a click that lands beside the panel cannot reach the map
## and move somebody.
func open(hold_the_game: bool = true):
	_entries = _gather()
	if _entries.is_empty():
		return
	_index = _default_index()
	_open = true
	_root.visible = true
	if hold_the_game:
		MenuPause.hold(self)
	_show_entry()


func close():
	_open = false
	_root.visible = false
	MenuPause.release(self)
	if _animated != null:
		_animated.stop()
	# Handed back so the camera stops thinking a menu has the keyboard.
	var focused = get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()


func _unhandled_input(event):
	if not event is InputEventKey or not event.pressed or event.is_echo():
		return
	if event.keycode == KEY_C:
		# Not while the pause menu has the game held - one menu at a time, and
		# the sheet opening behind the pause panel is nobody's intention.
		if MenuPause.held_by_another(self):
			return
		get_viewport().set_input_as_handled()
		toggle()
		return
	if _open and event.is_action_pressed("ui_cancel"):
		# Taken before the pause menu sees it, so Escape closes what is actually
		# in front of you rather than opening something on top of it.
		get_viewport().set_input_as_handled()
		close()


## --- Who there is to show ---


## Everyone on the player's side, as plain dictionaries the sheet can draw.
##
## Two sources, because there are two situations. In a battle the combatants
## exist and carry real levels, real attributes and whatever damage they have
## taken. While exploring none of that exists yet - nobody has been deployed -
## so the entry is built from the database at the level the map has the party
## at (see MapSetup), which is what they are until a fight says otherwise.
func _gather() -> Array:
	var found: Array = []
	if combat != null and is_instance_valid(combat) and not combat.combatants.is_empty():
		for comb in combat.combatants:
			if not comb.alive:
				continue
			# The player's own, plus any enemy Study has opened up. An enemy
			# nobody has studied is not here at all: that their numbers are
			# hidden until somebody goes and measures them is the whole point
			# of the skill.
			if comb.side != 0 and not comb.get("studied", false):
				continue
			found.append({
				"name": comb.name,
				"level": comb.get("level", 1),
				"hp": comb.hp,
				"max_hp": combat.get_effective_stat(comb, "max_hp"),
				"stats": comb.get("stats", {}),
				"weapon_base": comb.get("weapon_base", Stats.WEAPON_BASE),
				"sprite_frames": comb.get("sprite_frames"),
				"map_sprite": comb.get("map_sprite"),
				"in_battle": true,
				"movement": combat.get_effective_stat(comb, "movement"),
				"resistances": comb.get("resistances", {}),
				"skills": _skills_they_actually_have(comb),
				"studied": comb.side != 0,
				# Kept so a skill can be previewed in their hands rather than
				# in whoever's happens to be acting - what an enemy hits for is
				# the reason to read their sheet at all.
				"combatant": comb,
			})
		return found
	for member in Campaign.party_members():
		var definition: CombatantDefinition = CombatantDatabase.combatants.get(member.key)
		if definition == null:
			continue
		found.append({
			"name": member.name,
			"level": Campaign.party_level,
			"hp": member.hp,
			"max_hp": member.max_hp,
			"stats": Stats.stats_for_level(Campaign.party_level, definition.main_stat, definition.secondary_stat),
			"weapon_base": Stats.WEAPON_BASE,
			"sprite_frames": definition.sprite_frames,
			"map_sprite": definition.map_still(),
			"in_battle": false,
		})
	return found


## Whoever it makes most sense to open on: the combatant taking their turn if
## it is one of the player's, otherwise the first of them - which while
## exploring is the party leader, since Campaign lists them leader first.
func _default_index() -> int:
	if combat == null or not is_instance_valid(combat) or combat.combatants.is_empty():
		return 0
	var current = combat.get_current_combatant()
	for i in range(_entries.size()):
		if _entries[i].name == current.name and current.side == 0:
			return i
	return 0


## --- Drawing one of them ---


func _show_entry():
	if _index < 0 or _index >= _entries.size():
		return
	var entry = _entries[_index]
	_title.text = entry.name
	_subtitle.text = "Level %d    %d / %d HP" % [entry.level, entry.hp, entry.max_hp]

	_show_portrait(entry)
	_show_stats(entry)
	_show_members()


func _show_portrait(entry: Dictionary):
	var frames = entry.get("sprite_frames")
	if frames != null and frames.has_animation("idle"):
		_animated.visible = true
		_still.visible = false
		_animated.sprite_frames = frames
		_animated.play("idle")
	else:
		# No animation set for this one - the flat map sprite still says who
		# they are, which is the point of the portrait.
		_animated.visible = false
		_still.visible = true
		_still.texture = entry.get("map_sprite")


func _show_stats(entry: Dictionary):
	for child in _stat_rows.get_children():
		_stat_rows.remove_child(child)
		child.queue_free()
	var stats: Dictionary = entry.get("stats", {})
	for i in range(Stats.NAMES.size()):
		var key = Stats.KEYS[i]
		_stat_rows.add_child(_stat_row(Stats.NAMES[i], str(stats.get(key, Stats.BASE_STAT))))
	# Weapon base belongs with them: it is half of every damage number they
	# produce, and unlike the attributes it is set per encounter.
	_stat_rows.add_child(_stat_row("Weapon base", str(entry.get("weapon_base", Stats.WEAPON_BASE))))
	if entry.has("movement"):
		_stat_rows.add_child(_stat_row("Movement", str(entry.movement)))
	_show_resistances(entry)
	_show_skills(entry)


## What they shrug off and what gets through them, listed only where it is not
## simply "normal" - a wall of zeroes says nothing worth reading.
func _show_resistances(entry: Dictionary):
	var resistances: Dictionary = entry.get("resistances", {})
	var resists := []
	var weak := []
	for type in resistances:
		var amount = resistances[type]
		if amount > 0:
			resists.append("%s %d%%" % [Damage.type_name(type), amount])
		elif amount < 0:
			weak.append("%s %d%%" % [Damage.type_name(type), amount])
	if resists.is_empty() and weak.is_empty():
		if entry.has("resistances"):
			_stat_rows.add_child(_stat_row("Resistances", "none"))
		return
	if not resists.is_empty():
		_stat_rows.add_child(_stat_row("Resists", ", ".join(resists)))
	if not weak.is_empty():
		_stat_rows.add_child(_stat_row("Weak to", ", ".join(weak)))


## Everything they can do, as the icons the player already knows from the action
## panel - each carrying the same preview the panel would show, worked out for
## the character whose sheet this is.
##
## Names alone said what an enemy could do without saying what it would cost
## you, which is the half worth knowing before you walk into it.
func _show_skills(entry: Dictionary):
	var keys: Array = entry.get("skills", [])
	if keys.is_empty():
		return
	var subject: Dictionary = entry.get("combatant", {})
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = "Skills"
	label.custom_minimum_size = Vector2(150, 0)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", MUTED)
	row.add_child(label)
	var icons := HFlowContainer.new()
	icons.add_theme_constant_override("h_separation", 6)
	icons.add_theme_constant_override("v_separation", 6)
	icons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for key in keys:
		var skill: SkillDefinition = SkillDatabase.skills.get(key)
		if skill == null:
			continue
		icons.add_child(_skill_chip(skill, subject))
	row.add_child(icons)
	_stat_rows.add_child(row)


## One skill, as its icon with its preview on it. A TextureRect rather than a
## button: there is nothing to press here, only something to read.
func _skill_chip(skill: SkillDefinition, subject: Dictionary) -> Control:
	var chip := TextureRect.new()
	chip.texture = skill.icon
	chip.custom_minimum_size = Vector2(40, 40)
	chip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.tooltip_text = _preview_of(skill, subject)
	return chip


## The action panel's own words for a skill, in `subject`'s hands. Falls back to
## the skill's name and description when there is no panel to ask - the sheet is
## also opened from the exploration map, where no battle is running.
func _preview_of(skill: SkillDefinition, subject: Dictionary) -> String:
	var panel = combat.game_ui if combat != null and is_instance_valid(combat) else null
	if panel != null and panel.has_method("build_skill_tooltip"):
		return panel.build_skill_tooltip(skill, subject)
	var lines := [skill.name]
	if skill.description != "":
		lines.append(skill.description)
	return "
".join(lines)


func _stat_row(label_text: String, value_text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(150, 0)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", MUTED)
	row.add_child(label)
	var value := Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 16)
	value.add_theme_color_override("font_color", INK)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value)
	return row


## One button per companion, so any of them can be read without closing and
## reopening on somebody else. Absent entirely when there is nobody else - a
## row with a single button in it is a control that does nothing.
func _show_members():
	for child in _members.get_children():
		_members.remove_child(child)
		child.queue_free()
	if _entries.size() < 2:
		_members.visible = false
		return
	_members.visible = true
	var buttons: Array = []
	for i in range(_entries.size()):
		var button := Button.new()
		button.text = _entries[i].name
		button.add_theme_font_size_override("font_size", 13)
		if i == _index:
			# The one being read is marked rather than disabled, so the row
			# always says where you are as well as where you can go.
			button.add_theme_color_override("font_color", ACCENT)
			button.add_theme_color_override("font_hover_color", ACCENT)
		button.pressed.connect(_on_member_pressed.bind(i))
		_members.add_child(button)
		buttons.append(button)
	FocusLoop.link(buttons)
	if _index < buttons.size():
		buttons[_index].grab_focus()


func _on_member_pressed(index: int):
	_index = index
	_show_entry()


## The skills a combatant actually has at the level they are fighting at.
##
## Only narrowed for enemies, which is what Study reports: a level 1 sorcerer
## listing a spell they cannot cast until level 3 reads as a threat that is not
## there, and planning around it is planning around nothing. The player's own
## sheet still lists everything, because what is coming at the next level is
## worth knowing when it is your own character.
func _skills_they_actually_have(comb: Dictionary) -> Array:
	var keys: Array = comb.get("skill_list", [])
	if comb.side == 0 or combat == null:
		return keys
	var found: Array = []
	for key in keys:
		var skill: SkillDefinition = SkillDatabase.skills.get(key)
		if skill != null and combat.meets_level_for(comb, skill):
			found.append(key)
	return found
