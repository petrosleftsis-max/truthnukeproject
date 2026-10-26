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

## Palette, matching ui/blue_theme.tres - the small print a shade lighter than
## the menus' grey, since this is the page of small print.
const INK := Color("dce8f5")
const INK_DIM := Color("c2ceda")
const MUTED := Color("97abbf")
const ACCENT := Color("4a86c8")
## An attribute raised or lowered by what is on them, and the small badges a move
## carries ("from level 32", "known", "not learned").
const GOOD := Color("9fe0a0")
const BAD := Color("f0a090")
const SOON := Color("e8c872")
## The small boxes a state or a passive sits in, matching the menu's cards.
const TAG_FILL := Color("1c2531")
const TAG_EDGE := Color("2b3947")

## How large the idle animation is drawn. Frames are a tile across (192px) and
## the panel is not, so they come down to something that leaves room for the
## numbers beside them.
const PORTRAIT_SCALE := 0.75
const PORTRAIT_BOX := Vector2(190, 210)
## Wide enough that a condition or a passive, written out in full, wraps into a
## few lines rather than a column of them.
const PANEL_WIDTH := 720
## What is kept clear above and below the panel when it is as tall as it gets.
const SCREEN_MARGIN := 16
## How far one press of Up or Down moves the numbers when they run past the
## screen, and how much of a page Page Up and Page Down keep in view.
const SCROLL_STEP := 40
const PAGE_OVERLAP := 60
## How fast a pad scrolls the numbers, in pixels a second at full tilt.
const PAD_SCROLL_SPEED := 600.0
## The sheet's pages (see "Pages"). Levels is the party's own only.
const PAGES := ["Sheet", "Moves", "Levels"]
## How dark the world goes behind the sheet.
const BACKDROP := Color(0.02, 0.03, 0.05, 0.8)
## How long a passive's one-line summary on its tag may run before it is cut.
const SUMMARY_LENGTH := 64

## What being hidden means, for the State section. Hiding is a flag on the
## combatant rather than a status effect, so the HUD's marks never describe it
## and it has to be said here.
const HIDDEN_TEXT := "Out of sight: the other side treats them as not being there, and nothing can react to them. It lasts until an enemy has a clear line to them - being hit, or being the last of their side standing, gives them away too."
## And invisible, which is hiding that sight does not end.
const INVISIBLE_TEXT := "Out of sight even in plain view: the other side treats them as not being there, and nothing can react to them. Being seen or hit does not end it - doing anything to an enemy does, and so does nobody else on their side being left in sight."

var _open := false
var _index := 0
var _entries: Array = []

var _root: Control = null
var _panel: PanelContainer = null
var _body: HBoxContainer = null
var _stat_scroll: ScrollContainer = null
var _title: Label = null
var _subtitle: Label = null
var _path_button: Button = null
## The path choice opened from here, or null.
var path_picker: SubclassPicker = null
var _portrait: Control = null
var _animated: AnimatedSprite2D = null
var _still: TextureRect = null
var _stat_rows: VBoxContainer = null
var _members: HBoxContainer = null
var _hint: Label = null
## The page on show (PAGES), and the buttons that turn to each.
var _page := 0
var _tabs: HBoxContainer = null
## What a page can be narrowed to, above the scroll (the Moves page's roles, the
## Levels page's Unlocks Only), and the section the view is in on a long page.
var _toolbar: HBoxContainer = null
var _section: Label = null
## What a page keeps in sight above the scroll (the Levels page's next unlocks).
var _pinned: VBoxContainer = null
## The Moves page's role ("" for every move) and the Levels page's switch, kept
## from one character to the next.
var _move_filter := ""
var _unlocks_only := false
## A row to bring into view once the page is laid out (the level they are at).
var _scroll_target: Control = null
## The Levels page uncovering what is past ΛΗΘΗ, while it does.
var _unveiling: Tween = null


func _ready():
	layer = 8
	# One of the menus a pad's View opens - see Pad.
	add_to_group(&"pad_menu")
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
## Stops the game while it is up, exactly as opening it yourself does. Study
## costs an action and its whole payoff is the reading, so the reading gets the
## same quiet the C key gets - the skill that opened it carries on the moment
## the sheet is closed. This panel runs while the tree is paused, so closing it
## is always possible.
func open_on(who: String):
	open(true)
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
	dim.color = BACKDROP
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(centre)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	centre.add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)

	# The name sits above the sprite, as its heading.
	_title = Label.new()
	_title.theme_type_variation = GameFonts.HEADER
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", INK)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)

	_subtitle = Label.new()
	_subtitle.add_theme_font_size_override("font_size", 12)
	_subtitle.add_theme_color_override("font_color", MUTED)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_subtitle)

	# Somebody with a path still to choose can choose it from here, as well as
	# when the map asks - put away there, it is not lost.
	_path_button = Button.new()
	_path_button.name = "ChoosePath"
	_path_button.text = "Choose a path"
	_path_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_path_button.visible = false
	_path_button.pressed.connect(_choose_path)
	column.add_child(_path_button)

	# The pages: what they are made of, what they can do, what each level brings.
	_tabs = HBoxContainer.new()
	_tabs.name = "Pages"
	_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	_tabs.add_theme_constant_override("separation", 6)
	column.add_child(_tabs)
	for i in PAGES.size():
		var tab := Button.new()
		tab.name = PAGES[i]
		tab.text = PAGES[i]
		tab.toggle_mode = true
		# Focus stays on the row of companions; Tab or a trigger turns the page.
		tab.focus_mode = Control.FOCUS_NONE
		tab.add_theme_font_size_override("font_size", 13)
		tab.pressed.connect(_show_page.bind(i))
		_tabs.add_child(tab)

	_toolbar = HBoxContainer.new()
	_toolbar.name = "Toolbar"
	_toolbar.alignment = BoxContainer.ALIGNMENT_CENTER
	_toolbar.add_theme_constant_override("separation", 6)
	column.add_child(_toolbar)

	_pinned = VBoxContainer.new()
	_pinned.name = "Pinned"
	_pinned.add_theme_constant_override("separation", 4)
	column.add_child(_pinned)

	# Which section of a long page the view is in, kept in sight while the
	# section's own heading has scrolled away (see _follow_section).
	_section = Label.new()
	_section.name = "Section"
	_section.theme_type_variation = GameFonts.HEADER
	_section.add_theme_font_size_override("font_size", 15)
	_section.add_theme_color_override("font_color", INK_DIM)
	column.add_child(_section)

	_body = HBoxContainer.new()
	_body.add_theme_constant_override("separation", 18)
	column.add_child(_body)

	_portrait = Control.new()
	_portrait.custom_minimum_size = PORTRAIT_BOX
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(_portrait)

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

	# The numbers scroll, so a character with a lot on them never pushes the
	# buttons and the way out off the bottom of the screen. See _fit_to_screen.
	_stat_scroll = ScrollContainer.new()
	_stat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_stat_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(_stat_scroll)
	_stat_scroll.get_v_scroll_bar().value_changed.connect(func(_value): _follow_section())

	_stat_rows = VBoxContainer.new()
	_stat_rows.add_theme_constant_override("separation", 4)
	_stat_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stat_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stat_rows.alignment = BoxContainer.ALIGNMENT_CENTER
	_stat_scroll.add_child(_stat_rows)

	_members = HBoxContainer.new()
	_members.add_theme_constant_override("separation", 6)
	_members.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_members)

	var hint := Label.new()
	_hint = hint
	_name_keys()
	if not Pad.changed.is_connected(_name_keys):
		Pad.changed.connect(_name_keys)
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)


## --- For a pad's View (see Pad) ---


## First in a fight, where it is the one most wanted; last out of one.
func pad_menu_order() -> int:
	return 0 if combat != null else 3


func pad_menu_available() -> bool:
	var pictures = get_node_or_null("/root/Pictures")
	return not MenuPause.held_by_another(self) and not (pictures != null and pictures.is_open())


func pad_menu_is_open() -> bool:
	return _open


func pad_menu_open():
	open()


func pad_menu_close():
	close()


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
	if path_picker != null:
		path_picker.queue_free()
		path_picker = null
	_open = false
	_root.visible = false
	MenuPause.release(self)
	if _animated != null:
		_animated.stop()
	# Handed back so the camera stops thinking a menu has the keyboard.
	var focused = get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()


## What closes it, under the panel - from the keyboard or from a pad.
func _name_keys():
	if _hint != null and is_instance_valid(_hint):
		_hint.text = "%s or %s to close    %s for the next page" % [Pad.key([&"character_sheet", &"menus"]), Pad.key(&"ui_cancel"), Pad.key(&"skill_tab")]


## A pad reads down the numbers with the D-pad or the left stick, held, where
## the keyboard has Up and Down; left and right go from one of the party to
## the next, as the buttons along the bottom do. Tab or the right trigger
## turns the page - taken here, before the focus moves on Tab.
func _input(event):
	if not _open:
		return
	if path_picker == null and Pad.went_down(event, &"skill_tab") and _index < _entries.size():
		get_viewport().set_input_as_handled()
		_show_page((_page + 1) % _pages_of(_entries[_index]))
		return
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	if event.is_action(&"ui_up") or event.is_action(&"ui_down"):
		get_viewport().set_input_as_handled()


func _process(delta):
	if not _open or not Pad.using_pad:
		return
	var way := Input.get_axis(&"ui_up", &"ui_down")
	if way != 0.0:
		_stat_scroll.scroll_vertical += int(way * PAD_SCROLL_SPEED * delta)


func _unhandled_input(event):
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed(&"character_sheet"):
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
		return
	# The same reading from the keyboard as the wheel gives the mouse, for when
	# the numbers run longer than the screen.
	if not event is InputEventKey:
		return
	if _open:
		var page = maxi(int(_stat_scroll.size.y) - PAGE_OVERLAP, SCROLL_STEP)
		var by := 0
		match event.keycode:
			KEY_UP:
				by = -SCROLL_STEP
			KEY_DOWN:
				by = SCROLL_STEP
			KEY_PAGEUP:
				by = -page
			KEY_PAGEDOWN:
				by = page
		if by != 0:
			get_viewport().set_input_as_handled()
			_stat_scroll.scroll_vertical += by


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
				"key": comb.get("combatant_key", ""),
				"subclass": comb.get("subclass", ""),
				"gear": comb.get("gear", []),
				"faction": comb.get("faction", ""),
				"known_faction": comb.get("known_faction", "") != "",
				"movement": combat.get_effective_stat(comb, "movement"),
				"movement_class": comb.get("movement_class", 0),
				"base_movement_class": comb.get("base_movement_class", comb.get("movement_class", 0)),
				"resistances": comb.get("resistances", {}),
				"skills": _skills_they_actually_have(comb),
				"passives": comb.get("passives", []),
				"studied": comb.side != 0,
				"casts": comb.get("max_spell_slots", []).any(func(count): return count > 0),
				"spellcasting_stat": comb.get("spellcasting_stat", -1),
				# Kept so a skill can be previewed in their hands rather than
				# in whoever's happens to be acting - what an enemy hits for is
				# the reason to read their sheet at all.
				"combatant": comb,
			})
		return found
	for member in Campaign.party_members():
		var entry := map_entry_of(member)
		if not entry.is_empty():
			found.append(entry)
	return found


## A party member away from a fight (one of Campaign.party_members()), as the
## sheet draws them - and as what they cast on a map is worked out from
## (OutsideMoves). {} for somebody not in the database.
static func map_entry_of(member: Dictionary) -> Dictionary:
	var definition: CombatantDefinition = CombatantDatabase.combatants.get(member.key)
	if definition == null:
		return {}
	var stats := Stats.stats_for_level(Campaign.party_level, definition.main_stat, definition.secondary_stat)
	var weapon_base := Stats.WEAPON_BASE
	# What they are wearing is what they will fight with (Combat.wear_gear).
	var weapon := EquipmentDefinition.named(Campaign.equipped_in(member.key, "weapon"))
	if weapon != null:
		weapon_base = weapon.weapon_base
	var armour := EquipmentDefinition.named(Campaign.equipped_in(member.key, "armour"))
	if armour != null:
		stats["defense"] = armour.defense
	# Brought back from falling in a fight, and weaker for it until a long rest (see
	# Combat.weaken). Their health already is: it is what they were last
	# fielded with.
	var frailty: float = Campaign.party_state.get(member.key, {}).get("frailty", 1.0)
	if frailty < 1.0:
		for key in stats:
			stats[key] = Combat.weakened_figure(stats[key], frailty)
		weapon_base = Combat.weakened_figure(weapon_base, frailty)
	return {
		"name": member.name,
		"level": Campaign.party_level,
		"hp": member.hp,
		"max_hp": member.max_hp,
		"stats": stats,
		"weapon_base": weapon_base,
		"sprite_frames": definition.sprite_frames,
		"map_sprite": definition.map_still(),
		"in_battle": false,
		"movement_class": definition.class_m,
		"base_movement_class": definition.class_m,
		"passives": passives_on_the_map(member.key, definition),
		"key": member.key,
		"subclass": Campaign.subclass_of(member.key),
		"casts": definition.casts_spells(),
		"spellcasting_stat": definition.spellcasting_stat,
	}


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
	# What they are besides their level: the path they took, or the side they
	# are on - and whether the party knows that side well enough to hit harder.
	var path := SubclassDefinition.named(entry.get("subclass", ""))
	var faction := FactionDefinition.named(entry.get("faction", ""))
	var also := ""
	if path != null:
		also = path.name + "    "
	elif faction != null:
		also = faction.name + (" (known)" if entry.get("known_faction", false) else "") + "    "
	_subtitle.text = "Level %d    %s%d / %d HP" % [entry.level, also, entry.hp, entry.max_hp]
	# A path to choose, or - after a long rest, until the next fight - to change.
	var key: String = entry.get("key", "")
	var changing: bool = not Campaign.needs_path(key) and Campaign.can_change_path(key)
	_path_button.visible = not entry.get("in_battle", false) and not entry.get("studied", false) and (Campaign.needs_path(key) or changing)
	_path_button.text = "Change path" if changing else "Choose a path"

	_show_tabs(entry)
	_show_portrait(entry)
	# The moves and the levels want the width the portrait would take.
	_portrait.visible = _page == 0
	_clear_toolbar()
	_scroll_target = null
	_section.visible = _page != 0
	_section.text = ""
	match _page:
		1:
			_show_moves(entry)
		2:
			_show_levels(entry)
		_:
			_show_stats(entry)
	_show_members()
	_fit_to_screen()


## Gives the numbers all the height they want, up to what the screen has room
## for, and lets them scroll past that. A long kit, a pile of states and a row
## of passives can outgrow the screen between them, and a sheet whose buttons
## and way out have gone off the bottom edge is one that cannot be finished.
##
## Measured a frame late, once the rows have been laid out at their real width:
## how tall a wrapped description is depends on how wide it is allowed to be.
func _fit_to_screen():
	# The last character's height stays until this one's is known, rather than
	# collapsing the sheet for a frame on every step between them.
	_stat_scroll.scroll_vertical = 0
	await get_tree().process_frame
	if not _open:
		return
	var around = _panel.get_combined_minimum_size().y - _body.get_combined_minimum_size().y
	var room = get_viewport().get_visible_rect().size.y - SCREEN_MARGIN * 2 - around
	_stat_scroll.custom_minimum_size.y = minf(_stat_rows.get_combined_minimum_size().y, room)
	_follow_section()
	# Down to the row the page wants seen, once it has its place (the level they
	# are at, on the Levels page).
	if _scroll_target != null:
		await get_tree().process_frame
		if _open and _scroll_target != null and is_instance_valid(_scroll_target):
			_stat_scroll.scroll_vertical = int(maxf(_scroll_target.position.y - 8.0, 0.0))


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
	_clear_rows()
	_show_health(entry)
	_show_attributes(entry)
	if entry.has("movement"):
		_stat_rows.add_child(_stat_row("Movement", "%d tiles" % entry.movement))
	if entry.has("movement_class"):
		_stat_rows.add_child(_stat_row("Movement type", _movement_type_of(entry)))
	_show_castings(entry)
	_show_gear(entry)
	_show_resistances(entry)
	_show_state(entry)
	# Their moves are the Moves page's - an ally's or a studied enemy's alike.
	_show_passives(entry)


## Their health as a bar, with the numbers beside it.
func _show_health(entry: Dictionary):
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_row_label("Health"))
	var most := maxi(int(entry.get("max_hp", 1)), 1)
	var now := clampi(int(entry.get("hp", most)), 0, most)
	var bar := ProgressBar.new()
	bar.name = "HealthBar"
	bar.max_value = most
	bar.value = now
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(220, 12)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var back := StyleBoxFlat.new()
	back.bg_color = TAG_FILL
	back.border_color = TAG_EDGE
	back.set_border_width_all(1)
	back.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	var share := float(now) / most
	fill.bg_color = HEALTH_COLOUR if share > 0.5 else (SOON if share > 0.25 else BAD)
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	row.add_child(_value_label("%d / %d" % [now, most]))
	_stat_rows.add_child(row)


## The five attributes and the weapon base, two to a line with each value beside
## its name. In a fight each is what it is now, what is on them folded in - green
## raised, red lowered, what it usually is on hover. The stat their spells answer
## to is marked, and Defense says what it takes off a hit.
func _show_attributes(entry: Dictionary):
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := _row_label("Attributes")
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(label)
	var grid := GridContainer.new()
	grid.name = "Attributes"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 2)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(grid)
	var stats: Dictionary = entry.get("stats", {})
	var subject: Dictionary = entry.get("combatant", {})
	var live: bool = not subject.is_empty() and combat != null and is_instance_valid(combat)
	for i in Stats.NAMES.size():
		var base: int = stats.get(Stats.KEYS[i], Stats.BASE_STAT)
		var now: int = combat.stat_of(subject, i) if live else base
		var note := ""
		var reading := "%s %d" % [Stats.NAMES[i], now]
		if i == Stats.Type.DEFENSE:
			var cut := roundi((1.0 - Stats.DEFENSE_PIVOT / (Stats.DEFENSE_PIVOT + maxf(now, 0.0))) * 100.0)
			note = "-%d%% a hit" % cut
			reading += "\nEvery hit on them is multiplied by %d / (%d + Defense): this takes %d%% off, before resistances." % [int(Stats.DEFENSE_PIVOT), int(Stats.DEFENSE_PIVOT), cut]
		elif entry.get("casts", false) and i == entry.get("spellcasting_stat", -1):
			note = "spells"
			reading += "\nTheir spells are worked out from it, whatever stat the spell names."
		if now != base:
			reading += "\n%d usually: %+d from what is on them." % [base, now - base]
			note = ("base %d" % base) + ("  " + note if note != "" else "")
		grid.add_child(_attribute_cell(Stats.NAMES[i], now, note, GOOD if now > base else (BAD if now < base else INK), reading))
	# Weapon base belongs with them: it is half of every damage number they
	# produce, and unlike the attributes it is set per encounter.
	var weapon: int = entry.get("weapon_base", Stats.WEAPON_BASE)
	grid.add_child(_attribute_cell("Weapon base", weapon, "", INK,
		"Weapon base %d\nA skill's base is weapon base + %s x its stat." % [weapon, CharacterSheet._figure(Stats.STAT_SCALING)]))
	_stat_rows.add_child(row)


## One attribute: its name, its value beside it, and a quiet note after.
func _attribute_cell(name_text: String, value: int, note: String, colour: Color, reading: String) -> Control:
	var cell := HBoxContainer.new()
	cell.add_theme_constant_override("separation", 8)
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.tooltip_text = TooltipText.wrap(reading)
	var called := Label.new()
	called.text = name_text
	called.custom_minimum_size = Vector2(98, 0)
	called.add_theme_font_size_override("font_size", 15)
	called.add_theme_color_override("font_color", MUTED)
	called.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(called)
	var number := Label.new()
	number.text = str(value)
	number.custom_minimum_size = Vector2(28, 0)
	number.add_theme_font_size_override("font_size", 17)
	number.add_theme_color_override("font_color", colour)
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(number)
	if note != "":
		var aside := Label.new()
		aside.text = note
		aside.add_theme_font_size_override("font_size", 13)
		aside.add_theme_color_override("font_color", ACCENT.lightened(0.3) if note.ends_with("spells") else MUTED)
		aside.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		aside.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(aside)
	return cell


## What they have to spend: castings through each gate they have any of, a pip
## each, lit while unspent; Devotion's own castings; and every move with only so
## many uses a short rest. In a fight, what is left of it now; out of one, what a
## fight starts with - or, in a dungeon, what the last one left.
func _show_castings(entry: Dictionary):
	var pools := _pools_of(entry)
	if pools.is_empty():
		return
	var tags := _labelled_tags("Castings")
	for pool in pools:
		tags.add_child(_pips(pool.name, pool.left, pool.most, pool.colour, pool.reading))


## The pools _show_castings draws: {name, left, most, colour, reading} each.
func _pools_of(entry: Dictionary) -> Array:
	var pools := []
	var subject: Dictionary = entry.get("combatant", {})
	var live: bool = not subject.is_empty() and combat != null and is_instance_valid(combat)
	var key: String = entry.get("key", "")
	var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
	var level: int = entry.get("level", 1)
	var most: Array = []
	var left: Array = []
	var spent := {}
	if live:
		most = subject.get("max_spell_slots", [])
		left = subject.get("spell_slots", most)
		for what in Combat.SPENT_UNTIL_REST:
			if subject.has(what):
				spent[what] = subject[what]
	elif definition != null:
		most = definition.gates_at(level)
		left = most
		var carried: Dictionary = Campaign.party_state.get(key, {})
		if Campaign.in_dungeon():
			spent = carried.get("spent_until_rest", {})
		# Castings spent on the map are off the next fight's gates (Campaign
		# "Gates outside a fight"), and a dungeon's carried ones are what is left.
		if Campaign.party_order.has(key):
			left = Campaign.gates_left_outside(key)
	for gate in range(1, most.size()):
		if most[gate] > 0:
			var unspent: int = left[gate] if gate < left.size() else most[gate]
			pools.append({"name": Stats.short_gate_name(gate), "left": unspent, "most": most[gate], "colour": Stats.gate_colour(gate),
				"reading": "%s: %d of %d castings left" % [Stats.gate_name(gate), unspent, most[gate]]})
	# The gates opened only outside a fight (Iris), on the map.
	if not live and Campaign.party_order.has(key):
		var outside_most := Campaign.outside_gates_most(key)
		var outside_left := Campaign.outside_gates_left(key)
		for gate in range(1, outside_most.size()):
			if outside_most[gate] > 0:
				pools.append({"name": Stats.short_outside_gate_name(gate), "left": outside_left[gate], "most": outside_most[gate],
					"colour": Stats.OUTSIDE_GATES[gate].colour,
					"reading": "%s: %d of %d castings left, outside a fight" % [Stats.outside_gate_name(gate), outside_left[gate], outside_most[gate]]})
	# Devotion: castings of their own for named spells (Combat "Spare castings").
	var passives: Array = entry.get("passives", [])
	var spares := 0
	var spare_name := ""
	for passive in passives:
		if passive != null and passive.spare_castings > 0 and passive.required_level <= level:
			spares += passive.spare_castings
			if spare_name == "":
				spare_name = passive.name
	if spares > 0:
		var unspent := maxi(spares - int(spent.get("spare_spent", 0)), 0)
		pools.append({"name": spare_name, "left": unspent, "most": spares, "colour": HEALTH_COLOUR,
			"reading": "%s: %d of %d castings left, spent before any gate" % [spare_name, unspent, spares]})
	# Moves used only so often a short rest.
	var uses: Dictionary = spent.get("uses", {})
	for move in (entry.get("skills", []) if live else _moves_of(entry)):
		var skill: SkillDefinition = SkillDatabase.skills.get(move)
		if skill == null or skill.uses_per_short_rest <= 0 or skill.required_level > level:
			continue
		var a_rest := Combat.uses_a_rest({"level": level}, skill)
		var unspent := maxi(a_rest - int(uses.get(move, 0)), 0)
		pools.append({"name": skill.name, "left": unspent, "most": a_rest, "colour": SOON,
			"reading": "%s: %d of %d uses left until a short rest" % [skill.name, unspent, a_rest]})
	return pools


## A pool as its name and a pip per use, lit while unspent.
func _pips(name_text: String, left: int, most: int, colour: Color, reading: String) -> Control:
	var tag := _tag(name_text, INK, "%d/%d" % [left, most], reading)
	var line: HBoxContainer = tag.get_child(0)
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 3)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in mini(most, 12):
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(9, 9)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var look := StyleBoxFlat.new()
		look.set_corner_radius_all(5)
		look.set_border_width_all(1)
		look.border_color = colour
		look.bg_color = colour if i < left else Color(0, 0, 0, 0)
		pip.add_theme_stylebox_override("panel", look)
		pips.add_child(pip)
	line.add_child(pips)
	line.move_child(pips, 1)
	return tag


## How they get about - on foot, flying or mounted - which decides what they can
## cross and what it costs them. When something has changed it for now, as a
## Hover lifts a walker off the ground for a few turns, it says what they
## usually are too, so the change reads as passing rather than as who they are.
func _movement_type_of(entry: Dictionary) -> String:
	var now = Stats.movement_class_name(entry.movement_class)
	var usually = Stats.movement_class_name(entry.get("base_movement_class", entry.movement_class))
	if now == usually:
		return now
	return "%s (usually %s)" % [now, usually]


## What they shrug off and what gets through them, a tag an element, listed only
## where it is not simply "normal" - a wall of zeroes, or a row saying "none",
## says nothing worth reading.
func _show_resistances(entry: Dictionary):
	var resistances: Dictionary = entry.get("resistances", {})
	var resists := []
	var weak := []
	for type in resistances:
		if resistances[type] > 0:
			resists.append(type)
		elif resistances[type] < 0:
			weak.append(type)
	for found in [[resists, "Resists", GOOD], [weak, "Weak to", BAD]]:
		if found[0].is_empty():
			continue
		var tags := _labelled_tags(found[1])
		for type in found[0]:
			var amount: int = resistances[type]
			var element := Damage.type_name(type)
			var reading := "%s: shrugs off %d%% of it" % [element, amount] if amount > 0 else "%s: takes %d%% more of it" % [element, -amount]
			tags.add_child(_tag(element, found[2], "%+d%%" % amount, reading))


## One skill as its icon alone, large, with its preview on it - the Moves page's.
func _skill_icon(skill: SkillDefinition, subject: Dictionary) -> Control:
	var icon := TextureRect.new()
	icon.texture = skill.icon
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_STOP
	icon.tooltip_text = TooltipText.wrap(_preview_of(skill, subject))
	SkillLook.decorate(icon, skill)
	return icon


## What they do without being asked, under a heading of its own - none of it is
## on the action panel, so this is the one place it can be read. A tag each,
## named and saying whether it is working, with what it does on hover: written
## out in full they took over the sheet, and there will be more of them.
func _show_passives(entry: Dictionary):
	var passives: Array = entry.get("passives", [])
	if passives.is_empty():
		return
	var subject: Dictionary = entry.get("combatant", {})
	var level: int = entry.get("level", 1)
	var tags := _labelled_tags("Passive Skills")
	var later := []
	for ranks in passive_families(passives):
		# One passive in ranks (Combat "Ranks of a passive"): only the highest
		# unlocked shows, its description giving the totals - the first rank
		# until any is.
		var passive := shown_rank(ranks, level)
		var reading := [passive.name, passive.describe_when()]
		if passive.description != "":
			reading.append_array(["", passive.description])
		# Not reached yet: said so, dimmed, and after the ones that are working -
		# never "Always active" for something they do not have.
		if passive.required_level > level:
			var tag := _tag(passive.name, INK, "from level %d" % passive.required_level, "\n".join(reading), passive.icon)
			tag.modulate.a = 0.5
			later.append(tag)
			continue
		tags.add_child(_tag(passive.name, INK, _note_for(passive, subject), "\n".join(reading), passive.icon))
	for tag in later:
		tags.add_child(tag)


## Which of `ranks` (one family, in order) the sheet shows at `level`: the
## highest unlocked, or the first until any is.
static func shown_rank(ranks: Array, level: int) -> PassiveDefinition:
	var shown: PassiveDefinition = ranks[0]
	for rank in ranks:
		if rank.required_level <= level:
			shown = rank
	return shown


## `passives` gathered into families - every rank of one passive together, in
## the order they come in (Combat "Ranks of a passive") - in the order the first
## of each appears.
static func passive_families(passives: Array) -> Array:
	var order := []
	var families := {}
	for passive in passives:
		if passive == null:
			continue
		var family := Combat.passive_family(passive)
		if not families.has(family):
			families[family] = []
			order.append(family)
		families[family].append(passive)
	var found := []
	for family in order:
		var ranks: Array = families[family]
		ranks.sort_custom(func(a, b): return a.required_level < b.required_level)
		found.append(ranks)
	return found


## What is on them right now - hidden, burning, slowed, raised - apart from
## what they are and what they can do. A tag each, tinted the way its mark on
## the battle HUD is, green for what helps and red for what hurts; hovering one
## says what it does in the very words the HUD's mark uses, so the two places
## can never describe the same thing differently.
##
## Only in a battle. Nothing is on anybody while they walk the map, so the
## section is left off there rather than saying so.
func _show_state(entry: Dictionary):
	var subject: Dictionary = entry.get("combatant", {})
	if subject.is_empty() or combat == null or not is_instance_valid(combat):
		return
	var states := []
	if combat.is_invisible(subject):
		states.append({"text": "Invisible\n" + INVISIBLE_TEXT, "helpful": true})
	elif combat.is_hidden(subject):
		states.append({"text": "Hidden\n" + HIDDEN_TEXT, "helpful": true})
	var reader := ConditionStrip.new()
	states.append_array(reader.states_of(subject, combat))
	reader.free()
	# Nothing on them, nothing said: the row comes and goes with what it lists.
	if states.is_empty():
		return
	var tags := _labelled_tags("State")
	for state in states:
		var colour = ConditionStrip.HELPFUL if state.helpful else ConditionStrip.HARMFUL
		tags.add_child(_tag(state.text.split("\n")[0], colour, "", state.text))


## A row with `heading` on the left and room beside it for tags, which run on
## to a second line when they run out of width. Returns where the tags go.
func _labelled_tags(heading: String) -> HFlowContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := _row_label(heading)
	# Level with the first line of tags rather than centred on all of them.
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(label)
	var tags := HFlowContainer.new()
	tags.add_theme_constant_override("h_separation", 6)
	tags.add_theme_constant_override("v_separation", 6)
	tags.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(tags)
	_stat_rows.add_child(row)
	return tags


## One named thing as a small box to hover: its name, a short note beside it,
## and `reading` - the whole of what it means - as its tooltip.
##
## The one chip the three pages share: a passive, a state, a skill (`skill` set,
## for the action panel's badge on its icon), a level's unlock, a pool of
## castings.
func _tag(title_text: String, title_colour: Color, note: String, reading: String, icon: Texture2D = null,
		skill: SkillDefinition = null, badge: String = "") -> Control:
	var tag := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = TAG_FILL
	box.border_color = TAG_EDGE
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	tag.add_theme_stylebox_override("panel", box)
	# The labels inside ignore the mouse, so the hover lands here.
	tag.mouse_filter = Control.MOUSE_FILTER_STOP
	tag.tooltip_text = TooltipText.wrap(reading)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	tag.add_child(line)
	if icon != null:
		var picture := TextureRect.new()
		picture.texture = icon
		picture.custom_minimum_size = Vector2(22, 22)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(picture)
		if skill != null:
			SkillLook.decorate(picture, skill, badge)
			var mark = picture.get_node_or_null(SkillLook.BADGE)
			if mark != null:
				mark.add_theme_font_size_override("font_size", 9)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", title_colour)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(title)
	if note != "":
		var aside := Label.new()
		aside.text = note
		aside.add_theme_font_size_override("font_size", 13)
		aside.add_theme_color_override("font_color", MUTED)
		aside.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		aside.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(aside)
	return tag


## A few words on a passive's tag. For one that is always working, what it does,
## in a line (passive_summary) - "Always active" on every tag said nothing; for
## one waiting on something, whether it is on right now in a battle, and only
## that it depends on something while walking the map. When it works and the
## whole of what it does are in the tooltip.
func _note_for(passive: PassiveDefinition, subject: Dictionary) -> String:
	if passive.active_when == PassiveDefinition.ActiveWhen.ALWAYS:
		return passive_summary(passive)
	if subject.is_empty() or combat == null or not is_instance_valid(combat):
		return "Conditional"
	return "Active now" if combat.passive_is_active(subject, passive) else "Not active"


## What `passive` does, in a line for its tag: its description's numbers - what
## follows the colon, where it has one ("Hide hardened...: a tenth less damage
## from anything") - up to a dash or the sentence's end, cut at SUMMARY_LENGTH.
## The first of its effects when it has no description.
static func passive_summary(passive: PassiveDefinition) -> String:
	var text := passive.description.strip_edges()
	if text == "":
		var effects := passive.describe_effects()
		text = effects[0] if not effects.is_empty() else ""
	var stop := text.find(". ")
	if stop >= 0:
		text = text.left(stop + 1)
	var colon := text.find(": ")
	if colon >= 0 and colon < text.length() - 3:
		text = text.substr(colon + 2)
	var dash := text.find(" - ")
	if dash > 0:
		text = text.left(dash)
	text = text.strip_edges().trim_suffix(".")
	if text.length() > SUMMARY_LENGTH:
		var cut := text.left(SUMMARY_LENGTH).rfind(" ")
		text = text.left(cut if cut > 0 else SUMMARY_LENGTH).trim_suffix(",") + "…"
	return text


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


## A row: its name on the left, its value beside it (not off at the far edge,
## where the eye lost which name it belonged to).
func _stat_row(label_text: String, value_text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_row_label(label_text))
	row.add_child(_value_label(value_text))
	return row


## The name down the left of a row.
func _row_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(130, 0)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", MUTED)
	return label


## A row's value.
func _value_label(text: String) -> Label:
	var value := Label.new()
	value.text = text
	value.add_theme_font_size_override("font_size", 17)
	value.add_theme_color_override("font_color", INK)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return value


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


## What `key` does without being asked at the party's level, away from a fight:
## their own passives and their path's that have come in by now.
static func passives_on_the_map(key: String, definition: CombatantDefinition) -> Array:
	var found: Array = definition.passives.duplicate()
	var charm := EquipmentDefinition.named(Campaign.equipped_in(key, "charm"))
	if charm != null and charm.passive != null:
		found.append(charm.passive)
	var path := SubclassDefinition.named(Campaign.subclass_of(key))
	if path != null and Campaign.party_level >= Stats.SUBCLASS_LEVEL:
		for passive in path.passives:
			if passive != null and Campaign.party_level >= passive.required_level:
				found.append(passive)
	return found


## --- Choosing a path from here ---


## Puts the path choice over the sheet for whoever is on show.
func _choose_path():
	if path_picker != null or _index < 0 or _index >= _entries.size():
		return
	path_picker = SubclassPicker.new()
	path_picker.process_mode = Node.PROCESS_MODE_ALWAYS
	_root.add_child(path_picker)
	var key: String = _entries[_index].get("key", "")
	path_picker.offer(key, true, not Campaign.needs_path(key) and Campaign.can_change_path(key))
	path_picker.chosen.connect(func(_key, _subclass): _close_path_picker())
	path_picker.put_away.connect(_close_path_picker)


func _close_path_picker():
	if path_picker == null:
		return
	path_picker.queue_free()
	path_picker = null
	_regather()


## --- Gear ---
##
## What they are wearing (EquipmentDefinition). In a fight, read only. On the
## map, a button a slot: pressed, the pieces in the stash that fit it come up
## underneath to put on, with Take Off if something is on already.

## The slot whose choices are showing, or "".
var _gear_slot_open := ""


func _show_gear(entry: Dictionary):
	if entry.get("in_battle", false):
		var worn: Array = entry.get("gear", [])
		if worn.is_empty():
			return
		var worn_tags := _labelled_tags("Gear")
		for piece_name in worn:
			worn_tags.add_child(_tag(piece_name, INK, "", piece_name))
		return
	var key: String = entry.get("key", "")
	if key == "":
		return
	var tags := _labelled_tags("Gear")
	# Weapon, armour and charm; containers are changed on the inventory screen.
	for i in EquipmentDefinition.GEAR_SLOTS:
		var slot: String = EquipmentDefinition.SLOT_KEYS[i]
		var piece := EquipmentDefinition.named(Campaign.equipped_in(key, slot))
		var button := Button.new()
		button.name = "Gear_" + slot
		button.text = "%s: %s" % [EquipmentDefinition.SLOT_NAMES[i], piece.name if piece != null else "-"]
		button.tooltip_text = TooltipText.wrap(_gear_reading(piece) if piece != null else "Nothing worn. Press to choose from the stash.")
		button.pressed.connect(_choose_gear_slot.bind(slot))
		tags.add_child(button)
	if _gear_slot_open != "":
		_show_gear_choices(key, _gear_slot_open)


## What a piece is and does, for its tooltip.
func _gear_reading(piece: EquipmentDefinition) -> String:
	var lines := [piece.name, piece.summary()]
	if piece.description != "":
		lines.append_array(["", piece.description])
	return "\n".join(lines)


func _choose_gear_slot(slot: String):
	_gear_slot_open = "" if _gear_slot_open == slot else slot
	_show_entry()


## The pieces in the stash that fit `slot` for `key`, a button each.
func _show_gear_choices(key: String, slot: String):
	var tags := _labelled_tags("")
	var fitting := Campaign.gear_for(key, slot)
	for piece_key in fitting:
		var piece := EquipmentDefinition.named(piece_key)
		var button := Button.new()
		button.name = "Wear_" + piece_key
		button.text = "Wear %s" % piece.name
		button.tooltip_text = TooltipText.wrap(_gear_reading(piece))
		button.pressed.connect(func(): _wear(key, piece_key))
		tags.add_child(button)
	if Campaign.equipped_in(key, slot) != "":
		var off := Button.new()
		off.name = "TakeOff"
		off.text = "Take off"
		off.pressed.connect(func(): _take_off(key, slot))
		tags.add_child(off)
	if fitting.is_empty() and Campaign.equipped_in(key, slot) == "":
		var none := Label.new()
		none.text = "Nothing in the stash fits."
		none.add_theme_color_override("font_color", MUTED)
		tags.add_child(none)


func _wear(key: String, piece_key: String):
	Campaign.equip(key, piece_key)
	_gear_slot_open = ""
	_regather()


func _take_off(key: String, slot: String):
	Campaign.unequip(key, slot)
	_gear_slot_open = ""
	_regather()


## Everybody worked out again, staying on whoever is showing.
func _regather():
	var showing := _index
	_entries = _gather()
	_index = clampi(showing, 0, maxi(_entries.size() - 1, 0))
	_show_entry()


## --- Pages ---
##
## The sheet has three: what somebody is made of (the numbers, gear, state and
## passives above), what they can do (Moves - every skill, the spells on a shelf
## per gate) and what every level brings them (Levels - the party's own only).
## The buttons under the name go between them, and so does Tab or the right
## trigger.


## Whether `entry` has a Levels page: one of the party, not an enemy Study opened.
func _has_levels(entry: Dictionary) -> bool:
	return not entry.get("studied", false) and CombatantDatabase.combatants.has(entry.get("key", ""))


## How many pages `entry` has.
func _pages_of(entry: Dictionary) -> int:
	return PAGES.size() if _has_levels(entry) else PAGES.size() - 1


## Turns to page `which` (PAGES) for whoever is on show.
func _show_page(which: int):
	_page = which
	_show_entry()


## The page buttons, the one showing pressed in.
func _show_tabs(entry: Dictionary):
	var pages := _pages_of(entry)
	if _page >= pages:
		_page = 0
	for i in _tabs.get_child_count():
		var tab: Button = _tabs.get_child(i)
		tab.visible = i < pages
		tab.set_pressed_no_signal(i == _page)
		tab.add_theme_color_override("font_color", ACCENT if i == _page else INK_DIM)


## The section of a long page the view is in: the last heading scrolled past,
## named above the scroll - and nothing at the top, where its own heading shows.
func _follow_section():
	if _section == null or not _section.visible:
		return
	var at := _stat_scroll.scroll_vertical
	var current := ""
	for row in _stat_rows.get_children():
		if not row.visible or not row.has_meta("section"):
			continue
		# Only once its heading has gone up out of sight - not while it shows.
		if row.position.y + row.size.y > at + 2:
			break
		current = row.get_meta("section")
	_section.text = current
	_section.modulate.a = 1.0 if at > 0 and current != "" else 0.0


## The toolbar and what is pinned above the scroll emptied, for the page about
## to fill them.
func _clear_toolbar():
	for holder in [_toolbar, _pinned]:
		for child in holder.get_children():
			holder.remove_child(child)
			child.queue_free()
		holder.visible = false


## A toggle on the toolbar, pressed in while `on`.
func _toolbar_toggle(text: String, on: bool, pressed: Callable) -> Button:
	var button := Button.new()
	button.name = text.replace(" ", "")
	button.text = text
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.set_pressed_no_signal(on)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", INK_DIM)
	button.add_theme_color_override("font_pressed_color", ACCENT.lightened(0.35))
	button.pressed.connect(pressed)
	_toolbar.add_child(button)
	_toolbar.visible = true
	return button


## Everything the rows hold, gone - and an unveiling still playing, stopped.
func _clear_rows():
	if _unveiling != null and _unveiling.is_valid():
		_unveiling.kill()
	_unveiling = null
	for child in _stat_rows.get_children():
		_stat_rows.remove_child(child)
		child.queue_free()


## A heading across the rows, in `colour`, with a quieter `note` beside it.
func _heading(text: String, colour: Color = INK, note: String = "") -> Control:
	var line := HBoxContainer.new()
	line.set_meta("section", text)
	line.add_theme_constant_override("separation", 10)
	var label := Label.new()
	label.text = text
	label.theme_type_variation = GameFonts.HEADER
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", colour)
	line.add_child(label)
	if note != "":
		var aside := Label.new()
		aside.text = note
		aside.add_theme_font_size_override("font_size", 12)
		aside.add_theme_color_override("font_color", MUTED)
		aside.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(aside)
	_stat_rows.add_child(line)
	return line


## --- Moves ---
##
## A row a move: its icon (the action panel's preview on hover), its name and
## badges (its path, when it comes in, known or not), a line of what it is in
## numbers - which action, how far, how wide, how hard and in what element, what
## it leaves on them, what it costs - and what the skill says of itself, quieter,
## under that. The toolbar narrows the page to one role.

## The roles the Moves page can be narrowed to, in the order their buttons come.
const ROLES := ["Damage", "Healing", "Control", "Support", "Movement"]


## Which of ROLES `skill` plays: hurting, mending (bringing somebody back
## included), holding somebody down or moving them, helping a friend, getting
## about. Any it fits; a move fitting none is under "All" alone.
static func roles_of(skill: SkillDefinition) -> Array:
	var roles := []
	var add := func(role: String):
		if not roles.has(role):
			roles.append(role)
	if skill.deals_damage:
		add.call("Damage")
	if skill.teleports != SkillDefinition.TeleportWho.NOBODY:
		add.call("Movement")
	var friendly := skill.targets_ally
	for effect in skill.all_effects():
		if effect == null:
			continue
		match effect.type:
			EffectDefinition.EffectType.HEAL, EffectDefinition.EffectType.REVIVE:
				add.call("Healing")
			EffectDefinition.EffectType.PUSH, EffectDefinition.EffectType.PULL, EffectDefinition.EffectType.STEAL, \
					EffectDefinition.EffectType.CANCEL_CASTING, EffectDefinition.EffectType.DISPEL_MAGIC, \
					EffectDefinition.EffectType.SWALLOW, EffectDefinition.EffectType.TRAP:
				add.call("Control")
			EffectDefinition.EffectType.CONDITION, EffectDefinition.EffectType.DAMAGE_OVER_TIME, \
					EffectDefinition.EffectType.STAT_MODIFIER, EffectDefinition.EffectType.STAT_MULTIPLIER, \
					EffectDefinition.EffectType.RESISTANCE, EffectDefinition.EffectType.DISPEL:
				if effect.type == EffectDefinition.EffectType.STAT_MODIFIER and effect.stat == "movement" and effect.modifier_amount > 0:
					add.call("Movement")
				elif effect.applies_to_caster or friendly:
					add.call("Support")
				else:
					add.call("Control")
			EffectDefinition.EffectType.MOVEMENT_CLASS, EffectDefinition.EffectType.CLIMB, EffectDefinition.EffectType.HIDE, \
					EffectDefinition.EffectType.INVISIBLE:
				add.call("Movement")
			EffectDefinition.EffectType.SUMMON, EffectDefinition.EffectType.SUMMON_DECOY, EffectDefinition.EffectType.ZONE, \
					EffectDefinition.EffectType.UPGRADE_ELEMENT, EffectDefinition.EffectType.COMMAND, EffectDefinition.EffectType.DRAW, \
					EffectDefinition.EffectType.FAMILIAR:
				add.call("Support")
	return roles


## `skill` in numbers, a phrase each: which action it takes, how far it reaches
## and how wide it lands, how hard and in what element in `comb`'s hands (their
## level's rank), what it leaves on them and for how long, and what it costs.
## `comb` is the combatant in a fight, or {"level": n} out of one.
static func facts_of(skill: SkillDefinition, comb: Dictionary) -> Array:
	var facts := []
	# Cast only on a map (Find Familiar): no action, reach or target to speak of.
	if skill.outside_only():
		facts.append("Outside a fight")
		if Combat.is_spell(skill):
			facts.append(Stats.short_gate_name(skill.spell_slot_level))
		return facts
	if skill.declared:
		facts.append("Declared")
	elif skill.is_reactive and skill.reaction_only:
		facts.append("Reaction")
	else:
		facts.append("Secondary" if skill.is_secondary else "Main")
		if skill.is_reactive:
			facts.append("also a reaction")
	# Melee is a rule in the data (Combat.is_melee) set on some moves that reach
	# no one - Run, Slip Past - so what the reach says comes first.
	if skill.max_range <= 0:
		facts.append("On themselves")
	elif skill.melee and skill.max_range <= 1:
		facts.append("Melee")
	elif skill.min_range > 1 and skill.min_range < skill.max_range:
		facts.append("Range %d-%d" % [skill.min_range, skill.max_range])
	else:
		facts.append("Range %d" % skill.max_range)
	if skill.aoe_radius > 0:
		facts.append("%s %d" % [["Radius", "Line", "Cone"][skill.aoe_shape], skill.aoe_radius])
	if skill.deals_damage:
		var element := Damage.type_name(skill.damage_type)
		if skill is ItemDefinition:
			facts.append("%d %s" % [skill.item_power, element])
		else:
			facts.append("x%s %s" % [_figure(Combat.modifier_of(comb, skill)), element])
	for effect in skill.all_effects():
		if effect == null:
			continue
		if effect.type == EffectDefinition.EffectType.HEAL:
			var share := Combat.heal_share_of(comb, skill, effect)
			var whose := "their own" if effect.applies_to_caster else "their"
			if effect.heals_share_only:
				facts.append("mends %d%% of %s health" % [roundi(share * 100), whose])
			else:
				facts.append("heals" + (" + %d%% of %s health" % [roundi(share * 100), whose] if share > 0.0 else ""))
		elif effect.type == EffectDefinition.EffectType.CONDITION and effect.condition != null and not effect.applies_to_caster:
			var shown := Combat.ranked_condition_effect(comb, skill, effect)
			var turns := Combat.rank_duration(comb, skill)
			if turns <= 0:
				turns = shown.condition_duration if shown.condition_duration > 0 else shown.condition.duration
			facts.append("%s %d turn%s" % [shown.condition.display_name, turns, "" if turns == 1 else "s"])
	if Combat.is_spell(skill):
		facts.append(Stats.short_gate_name(skill.spell_slot_level))
	if skill.uses_per_short_rest > 0:
		var uses := Combat.uses_a_rest(comb, skill)
		facts.append("%d use%s a short rest" % [uses, "" if uses == 1 else "s"])
	return facts


## Roughly what `skill` hits for in `entry`'s hands before anybody's Defense -
## the action panel's figure in a fight; out of one, the same arithmetic from
## the sheet's numbers (power_behind x the rank's multiplier). -1 for a move
## that does not hurt.
func expected_damage(entry: Dictionary, skill: SkillDefinition) -> int:
	if not skill.deals_damage:
		return -1
	var subject: Dictionary = entry.get("combatant", {})
	if not subject.is_empty() and combat != null and is_instance_valid(combat):
		return combat.base_skill_damage(subject, skill)
	if skill is ItemDefinition:
		return roundi(skill.item_power * Combat.modifier_of({"level": entry.get("level", 1)}, skill))
	var stat := skill.scaling_stat as int
	if Combat.is_spell(skill) and entry.get("spellcasting_stat", -1) >= 0:
		stat = entry.spellcasting_stat
	for passive in entry.get("passives", []):
		if passive != null and passive.scales_every_skill_with >= 0 and passive.required_level <= entry.get("level", 1):
			stat = passive.scales_every_skill_with
	var value: int = entry.get("stats", {}).get(Stats.KEYS[stat], Stats.BASE_STAT)
	return roundi(Stats.base_damage(value, entry.get("weapon_base", Stats.WEAPON_BASE)) * Combat.modifier_of({"level": entry.get("level", 1)}, skill))


## What `skill`'s heal mends in `entry`'s hands, not counting any share of the
## target's own health: heal_amount in a fight; out of one, the same arithmetic
## from the sheet's numbers - the flat rule (EffectDefinition.heals_flat) or
## power x the dial, the heal bonus of their passives on top. 0 for no heal.
func expected_heal(entry: Dictionary, skill: SkillDefinition) -> int:
	var heal: EffectDefinition = null
	for effect in skill.all_effects():
		if effect != null and effect.type == EffectDefinition.EffectType.HEAL and not effect.heals_share_only:
			heal = effect
			break
	if heal == null:
		return 0
	var subject: Dictionary = entry.get("combatant", {})
	if not subject.is_empty() and combat != null and is_instance_valid(combat):
		return combat.heal_amount(subject, skill, heal)
	return heal_on_the_map(entry, skill, heal)


## What `heal` (one of `skill`'s) mends in `entry`'s hands away from a fight -
## expected_heal's arithmetic without a Combat, which a heal cast on a map
## (OutsideMoves) is worked out by too. 0 for an item.
static func heal_on_the_map(entry: Dictionary, skill: SkillDefinition, heal: EffectDefinition) -> int:
	if skill is ItemDefinition or heal == null:
		return 0
	var level: int = entry.get("level", 1)
	var bonus := 1.0
	var stat := skill.scaling_stat as int
	if Combat.is_spell(skill) and entry.get("spellcasting_stat", -1) >= 0:
		stat = entry.spellcasting_stat
	for passive in entry.get("passives", []):
		if passive != null and passive.required_level <= level:
			bonus += passive.heal_bonus
			if passive.scales_every_skill_with >= 0:
				stat = passive.scales_every_skill_with
	var value := float(entry.get("stats", {}).get(Stats.KEYS[stat], Stats.BASE_STAT))
	var weapon := float(entry.get("weapon_base", Stats.WEAPON_BASE))
	if heal.heals_flat():
		return roundi((heal.heal_flat + heal.heal_per_stat * value + heal.heal_per_weapon * weapon) * bonus)
	var dial: float = heal.heal_modifier if heal.heal_modifier > 0.0 else skill.ability_modifier
	return roundi(Stats.base_damage(int(value), int(weapon)) * dial * bonus)


## Every move `entry` has, by key. In a fight, what they carry into it. Out of
## one, their own skills and their path's - every one, the ones still to come
## included, since what is coming is worth knowing when it is your own.
func _moves_of(entry: Dictionary) -> Array:
	if entry.get("in_battle", false):
		return entry.get("skills", [])
	var definition: CombatantDefinition = CombatantDatabase.combatants.get(entry.get("key", ""))
	if definition == null:
		return []
	var keys: Array = Array(definition.skills)
	for key in definition.secondary_skills:
		if not keys.has(key):
			keys.append(key)
	var path := SubclassDefinition.named(entry.get("subclass", ""))
	if path != null:
		for key in path.skills:
			if not keys.has(key):
				keys.append(key)
	return keys


## The level gate `gate` first opens at (Stats.GATE_STEPS).
static func gate_opens_at(gate: int) -> int:
	for step in Stats.GATE_STEPS:
		if step[1].size() >= gate:
			return step[0]
	return Stats.MAX_LEVEL + 1


func _show_moves(entry: Dictionary):
	_clear_rows()
	var key: String = entry.get("key", "")
	var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
	var path := SubclassDefinition.named(entry.get("subclass", ""))
	var level: int = entry.get("level", 1)
	var skills := []
	var secondaries := []
	var spells := {}
	var roles := {}
	for move in _moves_of(entry):
		var skill: SkillDefinition = SkillDatabase.skills.get(move)
		if skill == null:
			continue
		for role in roles_of(skill):
			roles[role] = true
		if Combat.is_spell(skill):
			if not spells.has(skill.spell_slot_level):
				spells[skill.spell_slot_level] = []
			spells[skill.spell_slot_level].append(move)
		elif skill.is_secondary or (definition != null and definition.secondary_skills.has(move)):
			secondaries.append(move)
		else:
			skills.append(move)
	if skills.is_empty() and secondaries.is_empty() and spells.is_empty():
		_stat_rows.add_child(_stat_row("Moves", "none"))
		return
	# The roles they have moves for, on the toolbar.
	if not roles.has(_move_filter):
		_move_filter = ""
	var shown_roles := ROLES.filter(func(role): return roles.has(role))
	if shown_roles.size() > 1:
		_toolbar_toggle("All", _move_filter == "", _filter_moves.bind(""))
		for role in shown_roles:
			_toolbar_toggle(role, _move_filter == role, _filter_moves.bind(role))
	var by_level := func(a, b): return SkillDatabase.skills[a].required_level < SkillDatabase.skills[b].required_level
	if not skills.is_empty():
		_heading("Skills", INK, "a main action")
		skills.sort_custom(by_level)
		for move in skills:
			_move_row(entry, move, path, level)
	if not secondaries.is_empty():
		_heading("Secondary actions", INK, "beside the main one")
		secondaries.sort_custom(by_level)
		for move in secondaries:
			_move_row(entry, move, path, level)
	# The spells on a shelf per gate, World first, as the Spells panel has them -
	# each saying how many castings it has, and in a fight how many are left.
	var pools := {}
	for pool in _pools_of(entry):
		pools[pool.name] = pool
	var gates: Array = spells.keys()
	gates.sort()
	for gate in gates:
		var opens := gate_opens_at(gate)
		var note := "opens at level %d" % opens
		if level >= opens:
			var pool: Dictionary = pools.get(Stats.short_gate_name(gate), {})
			note = "open"
			if not pool.is_empty():
				note = "%d of %d castings left" % [pool.left, pool.most] if entry.get("in_battle", false) else "%d casting%s a fight" % [pool.most, "" if pool.most == 1 else "s"]
		_heading(Stats.gate_name(gate), Stats.gate_colour(gate), note)
		var shelf: Array = spells[gate]
		shelf.sort_custom(by_level)
		for move in shelf:
			_move_row(entry, move, path, level)
	_apply_move_filter()


## Narrows the Moves page to `role` ("" for every move).
func _filter_moves(role: String):
	_move_filter = role
	for button in _toolbar.get_children():
		button.set_pressed_no_signal(button.text == (role if role != "" else "All"))
	_apply_move_filter()
	_stat_scroll.scroll_vertical = 0
	_fit_to_screen()


## Shows the moves of the role chosen, and the headings with any left under them.
func _apply_move_filter():
	var heading: Control = null
	var any := false
	for row in _stat_rows.get_children():
		if row.has_meta("section"):
			if heading != null:
				heading.visible = any
			heading = row
			any = false
		elif row.has_meta("roles"):
			row.visible = _move_filter == "" or row.get_meta("roles").has(_move_filter)
			any = any or row.visible
	if heading != null:
		heading.visible = any


## One move as a row: its icon (its preview on hover), its name and badges, what
## it is in numbers, and what it says of itself. Somebody who learns their
## spells (Campaign.learns_spells) is told which they know, and, out of a fight,
## can learn one from a book or a Gate Nade in the party's bags right here. In a
## fight a spell there is nothing left to cast it with is dimmed.
func _move_row(entry: Dictionary, move: String, path: SubclassDefinition, level: int):
	var skill: SkillDefinition = SkillDatabase.skills[move]
	var key: String = entry.get("key", "")
	var subject: Dictionary = entry.get("combatant", {})
	var badges := []
	var dim := false
	if path != null and path.skills.has(move):
		badges.append([path.name, PATH_COLOUR])
	if comes_in(skill) > level and not entry.get("studied", false):
		badges.append(["from level %d" % comes_in(skill), SOON])
		dim = true
	var teachers := []
	var learner: bool = not entry.get("studied", false) and Combat.is_spell(skill) and key != "" and Campaign.learns_spells(key)
	if learner and not entry.get("in_battle", false):
		if Campaign.knows_spell(key, move):
			badges.append(["known", GOOD])
		else:
			badges.append(["not learned", BAD])
			dim = true
			teachers = Campaign.teachers_of(move)
	var live: bool = not subject.is_empty() and combat != null and is_instance_valid(combat)
	if live and not dim and Combat.is_spell(skill) and not combat.can_afford_skill(subject, skill):
		badges.append(["no castings left", BAD])
		dim = true
	var row := HBoxContainer.new()
	row.name = "Move_" + move
	row.set_meta("roles", roles_of(skill))
	row.add_theme_constant_override("separation", 10)
	var chip := _skill_icon(skill, subject)
	chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(chip)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 1)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", 8)
	words.add_child(title)
	var called := Label.new()
	called.text = skill.name
	called.add_theme_font_size_override("font_size", 16)
	called.add_theme_color_override("font_color", INK)
	title.add_child(called)
	for badge in badges:
		title.add_child(_badge(badge[0], badge[1]))
	# What it is in numbers, and roughly what it hits for.
	var facts := facts_of(skill, subject if live else {"level": level})
	var hits := expected_damage(entry, skill)
	if hits >= 0:
		facts.append("about %d before Defense" % hits)
	var mends := expected_heal(entry, skill)
	for i in facts.size():
		if mends > 0 and facts[i].begins_with("heals"):
			facts[i] = "heals %d%s" % [mends, facts[i].trim_prefix("heals")]
	# On a map, how loud it is out there - said only outside a fight.
	if not entry.get("in_battle", false):
		facts.append(OutsideMoves.noise_fact(skill))
	var numbers := Label.new()
	numbers.name = "Facts"
	numbers.text = "  ·  ".join(facts)
	numbers.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	numbers.add_theme_font_size_override("font_size", 13)
	numbers.add_theme_color_override("font_color", INK_DIM)
	numbers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(numbers)
	if skill.description != "":
		var about := Label.new()
		about.text = skill.description
		about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		about.add_theme_font_size_override("font_size", 13)
		about.add_theme_color_override("font_color", MUTED)
		about.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_child(about)
	if not teachers.is_empty():
		var item: ItemDefinition = ItemDatabase.item(teachers[0].item)
		var learn := Button.new()
		learn.name = "Learn_" + move
		learn.text = "Learn it - uses %s's %s" % [Campaign.display_name_of(teachers[0].holder), item.name if item != null else teachers[0].item]
		learn.add_theme_font_size_override("font_size", 14)
		learn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		# Stands out from the row it is on: the one thing to press on this page.
		for state in ["normal", "hover", "pressed", "focus"]:
			var look := StyleBoxFlat.new()
			look.bg_color = ACCENT.lightened(0.15 if state == "hover" else 0.0).darkened(0.2 if state == "pressed" else 0.0)
			look.border_color = ACCENT.lightened(0.4)
			look.set_border_width_all(1 if state != "focus" else 2)
			look.set_corner_radius_all(4)
			look.content_margin_left = 12
			look.content_margin_right = 12
			look.content_margin_top = 4
			look.content_margin_bottom = 4
			learn.add_theme_stylebox_override(state, look)
		learn.add_theme_color_override("font_color", Color.WHITE)
		learn.add_theme_color_override("font_hover_color", Color.WHITE)
		learn.pressed.connect(_learn.bind(key, move))
		words.add_child(learn)
	elif learner and not entry.get("in_battle", false) and not Campaign.knows_spell(key, move):
		var how := Label.new()
		how.text = "Learned from its spellbook, or by taking a Gate Nade of it apart."
		how.add_theme_font_size_override("font_size", 12)
		how.add_theme_color_override("font_color", MUTED)
		words.add_child(how)
	if dim:
		# The Learn button stays at full strength on a dimmed row.
		chip.modulate.a = 0.55
		called.modulate.a = 0.55
		numbers.modulate.a = 0.55
	_stat_rows.add_child(row)


## A small coloured word in a pill - a move's path, when it comes in, whether it
## is known.
func _badge(text: String, colour: Color) -> Control:
	var pill := PanelContainer.new()
	var look := StyleBoxFlat.new()
	look.bg_color = Color(colour, 0.14)
	look.border_color = Color(colour, 0.55)
	look.set_border_width_all(1)
	look.set_corner_radius_all(8)
	look.content_margin_left = 7
	look.content_margin_right = 7
	look.content_margin_top = 0
	look.content_margin_bottom = 1
	pill.add_theme_stylebox_override("panel", look)
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var word := Label.new()
	word.text = text
	word.add_theme_font_size_override("font_size", 12)
	word.add_theme_color_override("font_color", colour)
	pill.add_child(word)
	return pill


## `key` learns `spell` from the first book or Gate Nade in the party's bags.
func _learn(key: String, spell: String):
	Campaign.learn_spell(key, spell)
	_regather()


## --- Levels ---
##
## Level 1 to 64, a row each, under the chapter it is reached in: what every one
## brings - health, attributes, castings through the gates, skills, spells,
## passives, the path. Nothing past 55, ΛΗΘΗ, until Chapter V has begun
## (Campaign.levels_in_view); the first time the page is opened after, the
## rest is uncovered row by row (Campaign.levels_unveiled).

const LETHE := "ΛΗΘΗ"
const ALETHEIA := "ΑΛΗΘΕΙΑ"
const LEVEL_NAME_COLOUR := Color("e8c872")
const HEALTH_COLOUR := Color("9fe0a0")
const PASSIVE_COLOUR := Color("e8c872")
const PATH_COLOUR := Color("c8a0f0")
## How long each row takes to come out from under ΛΗΘΗ, and the pause first.
const UNVEIL_ROW_SECONDS := 0.35
const UNVEIL_PAUSE := 0.8


func _show_levels(entry: Dictionary):
	_clear_rows()
	var key: String = entry.get("key", "")
	var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
	if definition == null:
		return
	var now: int = entry.get("level", 1)
	var grants := level_entries_of(key, entry.get("subclass", ""))
	var shown := Campaign.levels_in_view()
	var unveil: bool = shown > Campaign.LETHE_LEVEL and not Campaign.levels_unveiled
	_toolbar_toggle("Unlocks only", _unlocks_only, _only_unlocks)
	_show_next(entry, grants, now, shown)
	var veiled := []
	var lethe_row: Control = null
	for level in range(1, shown + 1):
		var chapter := Campaign.chapter_of_level(level)
		if level == 1 or Campaign.chapter_of_level(level - 1) != chapter:
			var first: int = 1 if chapter == 1 else Campaign.CHAPTER_LEVELS[chapter - 2] + 1
			var header := _heading("Chapter %s" % Campaign.CHAPTER_NAMES[chapter - 1], INK,
				"levels %d to %d" % [first, Campaign.CHAPTER_LEVELS[chapter - 1]])
			if level > Campaign.LETHE_LEVEL:
				veiled.append(header)
		var row := _level_row(level, now, grants.get(level, []), entry)
		if level == Campaign.LETHE_LEVEL:
			lethe_row = row
		if level > Campaign.LETHE_LEVEL:
			veiled.append(row)
		# The page opens on the level they are at (the unveiling finds its own way).
		if level == now and not unveil and now > 1:
			_scroll_target = row
	var veil: Control = null
	if shown <= Campaign.LETHE_LEVEL or unveil:
		veil = _veil_line()
		if unveil:
			_stat_rows.move_child(veil, lethe_row.get_index() + 1)
	_apply_unlocks_only()
	if unveil:
		_unveil(veiled, veil, lethe_row)


## What the next level with anything new brings, kept above the scroll.
func _show_next(entry: Dictionary, grants: Dictionary, now: int, shown: int):
	for level in range(now + 1, shown + 1):
		var unlocks: Array = grants.get(level, []).filter(func(item): return not is_growth(item))
		if unlocks.is_empty():
			continue
		var box := PanelContainer.new()
		box.name = "Next"
		var frame := StyleBoxFlat.new()
		frame.bg_color = TAG_FILL
		frame.border_color = Color(SOON, 0.45)
		frame.set_border_width_all(1)
		frame.set_corner_radius_all(4)
		frame.content_margin_left = 10
		frame.content_margin_right = 10
		frame.content_margin_top = 4
		frame.content_margin_bottom = 4
		box.add_theme_stylebox_override("panel", frame)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		box.add_child(line)
		var when := Label.new()
		when.text = "Next at level %d" % level
		when.theme_type_variation = GameFonts.HEADER
		when.add_theme_font_size_override("font_size", 15)
		when.add_theme_color_override("font_color", SOON)
		when.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		line.add_child(when)
		_unlock_flows(unlocks, entry, line)
		_pinned.add_child(box)
		_pinned.visible = true
		return


## Shows only the levels that unlock something, without their growth, or all.
func _only_unlocks():
	_unlocks_only = not _unlocks_only
	_apply_unlocks_only()
	_stat_scroll.scroll_vertical = 0
	_fit_to_screen()


func _apply_unlocks_only():
	for row in _stat_rows.get_children():
		if row.has_meta("unlocks"):
			row.visible = row.get_meta("unlocks") or not _unlocks_only or row == _scroll_target
			var growth = row.find_child("Growth", true, false)
			if growth != null:
				growth.visible = not _unlocks_only


## What every level brings `key`, on `subclass` if they have chosen it (every
## path's, each named, if not): level -> its lines, as BBCode.
static func levels_of(key: String, subclass: String = "") -> Dictionary:
	var lines := {}
	var entries := level_entries_of(key, subclass)
	for level in entries:
		lines[level] = entries[level].map(func(entry): return entry.text)
	return lines


## What levels_of says, as the Levels page draws it: level -> an entry for each
## thing that level brings - {"kind", "text"} (the line, as BBCode), and for
## each kind what its chip needs. Growth (health, stats, gate) goes in a quiet
## line; everything else is an unlock, a chip: gate_open, skill, rank, passive,
## path_passive (with "skill", "passive", "path"), and path (the choice at 24,
## with "paths" and "chosen").
static func level_entries_of(key: String, subclass: String = "") -> Dictionary:
	var definition: CombatantDefinition = CombatantDatabase.combatants.get(key)
	var lines := {}
	if definition == null:
		return lines
	var add := func(level: int, entry: Dictionary):
		if not lines.has(level):
			lines[level] = []
		lines[level].append(entry)
	var learns: bool = definition.learns_spells
	var paths := []
	for path_key in definition.subclasses:
		if subclass == "" or path_key == subclass:
			var path := SubclassDefinition.named(path_key)
			if path != null:
				paths.append(path)
	# Whether they cast through the gates at all - by their own spells, or a path's.
	var casts: bool = definition.casts_spells()
	for path in paths:
		for skill_key in path.skills:
			var skill: SkillDefinition = SkillDatabase.skills.get(skill_key)
			if skill != null and skill.spell_slot_level > 0:
				casts = true
	for level in range(1, Stats.MAX_LEVEL + 1):
		# Health.
		var health := definition.hp_at(level)
		if level == 1:
			add.call(level, {"kind": "health", "text": "[color=#%s]%d health[/color]" % [HEALTH_COLOUR.to_html(false), health]})
		elif health != definition.hp_at(level - 1):
			add.call(level, {"kind": "health", "text": "[color=#%s]+%d health[/color] (%d)" % [HEALTH_COLOUR.to_html(false), health - definition.hp_at(level - 1), health]})
		# Attributes - Defence is the gear's, not the level's.
		var stats := Stats.stats_for_level(level, definition.main_stat, definition.secondary_stat)
		var before := Stats.stats_for_level(level - 1, definition.main_stat, definition.secondary_stat) if level > 1 else {}
		var grown := []
		for i in Stats.KEYS.size():
			var stat_key: String = Stats.KEYS[i]
			if stat_key == "defense":
				continue
			if level == 1:
				grown.append("%s %d" % [Stats.NAMES[i], stats[stat_key]])
			elif stats[stat_key] != before[stat_key]:
				grown.append("%s %d (+%d)" % [Stats.NAMES[i], stats[stat_key], stats[stat_key] - before[stat_key]])
		if not grown.is_empty():
			add.call(level, {"kind": "stats", "text": ", ".join(grown)})
		# Castings through the gates.
		if casts:
			var gates := Stats.gates_for_level(level)
			var had := Stats.gates_for_level(level - 1) if level > 1 else Stats.no_gates()
			for gate in range(1, gates.size()):
				var colour: String = Stats.gate_colour(gate).to_html(false)
				if had[gate] == 0 and gates[gate] > 0:
					add.call(level, {"kind": "gate_open", "gate": gate, "castings": gates[gate],
						"text": "[color=#%s]%s open[/color]: %d casting%s" % [colour, Stats.gate_name(gate), gates[gate], "" if gates[gate] == 1 else "s"]})
				elif gates[gate] > had[gate]:
					add.call(level, {"kind": "gate", "text": "[color=#%s]%s[/color]: %d castings (+%d)" % [colour, Stats.gate_name(gate), gates[gate], gates[gate] - had[gate]]})
		if level == Stats.SUBCLASS_LEVEL and not definition.subclasses.is_empty():
			var names := []
			var all_paths := []
			for path_key in definition.subclasses:
				var path := SubclassDefinition.named(path_key)
				if path != null:
					names.append(path.name)
					all_paths.append(path)
			var chosen := SubclassDefinition.named(subclass)
			add.call(level, {"kind": "path", "paths": all_paths, "chosen": chosen,
				"text": "[color=#%s]Chooses a path[/color]: %s%s" % [PATH_COLOUR.to_html(false), " or ".join(names),
				" - took %s" % chosen.name if chosen != null else ""]})
	# Skills and spells, at the level they come in.
	var own := Array(definition.skills)
	for skill_key in definition.secondary_skills:
		if not own.has(skill_key):
			own.append(skill_key)
	for skill_key in own:
		var skill: SkillDefinition = SkillDatabase.skills.get(skill_key)
		if skill != null:
			add.call(comes_in(skill), {"kind": "skill", "skill": skill, "learnable": learns and Combat.is_spell(skill) and not definition.starting_spells.has(skill_key),
				"text": _gain_line(skill, skill_key, definition, learns, "")})
			for rank in skill.ranks:
				if rank != null:
					add.call(maxi(rank.level, comes_in(skill)), {"kind": "rank", "skill": skill, "rank": rank, "text": _rank_line(skill, rank)})
	for passive in definition.passives:
		if passive != null:
			add.call(clampi(passive.required_level, 1, Stats.MAX_LEVEL), {"kind": "passive", "passive": passive,
				"text": "[color=#%s]Passive[/color]: %s" % [PASSIVE_COLOUR.to_html(false), passive.name]})
	for path in paths:
		for skill_key in path.skills:
			var skill: SkillDefinition = SkillDatabase.skills.get(skill_key)
			if skill != null and not own.has(skill_key):
				add.call(maxi(comes_in(skill), Stats.SUBCLASS_LEVEL), {"kind": "skill", "skill": skill, "path": path,
					"learnable": learns and Combat.is_spell(skill) and not definition.starting_spells.has(skill_key),
					"text": _gain_line(skill, skill_key, definition, learns, path.name)})
				for rank in skill.ranks:
					if rank != null:
						add.call(maxi(rank.level, Stats.SUBCLASS_LEVEL), {"kind": "rank", "skill": skill, "rank": rank, "path": path,
							"text": _rank_line(skill, rank)})
		for passive in path.passives:
			if passive != null:
				add.call(clampi(maxi(passive.required_level, Stats.SUBCLASS_LEVEL), 1, Stats.MAX_LEVEL), {"kind": "path_passive", "passive": passive, "path": path,
					"text": "[color=#%s]%s[/color]: passive %s" % [PATH_COLOUR.to_html(false), path.name, passive.name]})
	return lines


## Whether a level's entry is growth, drawn in its quiet line, rather than an
## unlock, drawn as a chip.
static func is_growth(entry: Dictionary) -> bool:
	return entry.kind in ["health", "stats", "gate"]


## A skill growing stronger (SkillRank), as a line for the Levels page: what it
## is called from here if that changes, and what changes.
static func _rank_line(skill: SkillDefinition, rank: SkillRank) -> String:
	var called := " - %s" % rank.title if rank.title != "" else ""
	return "[color=#%s]%s%s[/color] grows stronger: %s" % [ACCENT.lightened(0.25).to_html(false), skill.name, called, ", ".join(_rank_changes(rank))]


## What a rank changes, a phrase each.
static func _rank_changes(rank: SkillRank) -> Array:
	var changes := []
	if rank.ability_modifier > 0.0:
		changes.append("x%s" % _figure(rank.ability_modifier))
	if rank.condition_dot_modifier > 0.0:
		changes.append("lingering x%s" % _figure(rank.condition_dot_modifier))
	if rank.condition_duration > 0:
		changes.append("%d turns" % rank.condition_duration)
	if rank.condition != null:
		changes.append(rank.condition.display_name)
	if rank.heal_share_of_health > 0.0:
		changes.append("mends %d%% of health" % roundi(rank.heal_share_of_health * 100.0))
	if rank.splash_radius > 0:
		changes.append("x%s to everybody within %d of who it lands on%s" % [_figure(rank.splash_modifier), rank.splash_radius,
			(", shoved %d" % rank.splash_shove) if rank.splash_shove > 0 else ""])
	return changes


## A dial as it is written - 1.5, 0.25 - without trailing noughts.
static func _figure(value: float) -> String:
	var text := "%.2f" % value
	while text.ends_with("0"):
		text = text.left(-1)
	return text.trim_suffix(".")


## The level `skill` can first be used at: its own Required Level, and for a
## spell no sooner than its gate opens (Hover asks for no level, and still waits
## for the Gates of Hermes).
static func comes_in(skill: SkillDefinition) -> int:
	var level := skill.required_level
	if Combat.is_spell(skill):
		level = maxi(level, gate_opens_at(skill.spell_slot_level))
	return clampi(level, 1, Stats.MAX_LEVEL)


## A skill or spell coming in, as a line for the Levels page: learned there, or -
## for somebody who learns their spells - able to be learned from there on.
static func _gain_line(skill: SkillDefinition, skill_key: String, definition: CombatantDefinition, learns: bool, path_name: String) -> String:
	var from := "[color=#%s]%s[/color]: " % [PATH_COLOUR.to_html(false), path_name] if path_name != "" else ""
	if not Combat.is_spell(skill):
		return "%s[color=#%s]%s[/color]" % [from, ACCENT.lightened(0.25).to_html(false), skill.name]
	var gate := "[color=#%s]%s[/color]" % [Stats.gate_colour(skill.spell_slot_level).to_html(false), skill.name]
	if learns and not definition.starting_spells.has(skill_key):
		return "%s%s can be learned (its spellbook, or a Gate Nade of it)" % [from, gate]
	return "%s%s, a spell" % [from, gate]


## One level as a row: its number - and ΛΗΘΗ or ΑΛΗΘΕΙΑ under 55 and 64 - its
## growth in a quiet line, and what it unlocks as chips to hover. The level they
## are at is outlined; those still to come dimmed.
func _level_row(level: int, now: int, entries: Array, entry: Dictionary = {}) -> Control:
	var box := PanelContainer.new()
	box.name = "Level_%d" % level
	var frame := StyleBoxFlat.new()
	frame.bg_color = TAG_FILL if level == now else Color(0, 0, 0, 0)
	frame.border_color = ACCENT if level == now else Color(0, 0, 0, 0)
	frame.set_border_width_all(1)
	frame.set_corner_radius_all(4)
	frame.content_margin_left = 8
	frame.content_margin_right = 8
	frame.content_margin_top = 3
	frame.content_margin_bottom = 3
	box.add_theme_stylebox_override("panel", frame)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var number := VBoxContainer.new()
	number.custom_minimum_size = Vector2(96, 0)
	number.add_theme_constant_override("separation", 0)
	row.add_child(number)
	var called := Label.new()
	called.text = "Level %d" % level
	called.theme_type_variation = GameFonts.HEADER
	called.add_theme_font_size_override("font_size", 15)
	called.add_theme_color_override("font_color", ACCENT.lightened(0.25) if level == now else INK)
	number.add_child(called)
	if level == now:
		var here := Label.new()
		here.text = "now"
		here.add_theme_font_size_override("font_size", 12)
		here.add_theme_color_override("font_color", ACCENT.lightened(0.25))
		number.add_child(here)
	var named := ""
	if level == Campaign.LETHE_LEVEL:
		named = LETHE
	elif level == Campaign.ALETHEIA_LEVEL:
		named = ALETHEIA
	if named != "":
		var greek := Label.new()
		greek.name = "Named"
		greek.text = named
		greek.add_theme_font_size_override("font_size", 16)
		greek.add_theme_color_override("font_color", LEVEL_NAME_COLOUR)
		number.add_child(greek)
	var said := VBoxContainer.new()
	said.add_theme_constant_override("separation", 3)
	said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(said)
	var growth := entries.filter(func(item): return is_growth(item))
	var unlocks := entries.filter(func(item): return not is_growth(item))
	box.set_meta("unlocks", not unlocks.is_empty())
	# Health, attributes, castings: one quiet line, a dot between.
	if not growth.is_empty() or unlocks.is_empty():
		var grew := RichTextLabel.new()
		grew.name = "Growth"
		grew.bbcode_enabled = true
		grew.fit_content = true
		grew.scroll_active = false
		grew.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		grew.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grew.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grew.add_theme_font_size_override("normal_font_size", 13)
		grew.add_theme_color_override("default_color", MUTED)
		grew.text = "   ·   ".join(growth.map(func(item): return item.text)) if not growth.is_empty() else "[color=#%s]-[/color]" % MUTED.to_html(false)
		said.add_child(grew)
	if not unlocks.is_empty():
		_unlock_flows(unlocks, entry, said)
	var alpha := 0.62 if level > now else 1.0
	box.set_meta("alpha", alpha)
	box.modulate.a = alpha
	_stat_rows.add_child(box)
	return box


## A level's unlocks as chips under `parent`: the choice of a path on a line of
## its own, so nothing else reads as one of the paths, then everything else.
func _unlock_flows(unlocks: Array, entry: Dictionary, parent: Control):
	var holder := VBoxContainer.new()
	holder.name = "Unlocks"
	holder.add_theme_constant_override("separation", 4)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(holder)
	for paths in [true, false]:
		var these := unlocks.filter(func(item): return (item.kind == "path") == paths)
		if these.is_empty():
			continue
		var chips := HFlowContainer.new()
		chips.add_theme_constant_override("h_separation", 6)
		chips.add_theme_constant_override("v_separation", 4)
		chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		holder.add_child(chips)
		for item in these:
			_unlock_chips(item, entry, chips)


## What a level unlocks, as chips in `into`: a gate opening, a skill or spell
## (its path's name beside it, or whether it is learned rather than had), a
## skill growing stronger, a passive, and at 24 the paths - each with what it
## brings on hover, the one taken marked.
func _unlock_chips(item: Dictionary, entry: Dictionary, into: Control):
	var subject: Dictionary = entry.get("combatant", {})
	match item.kind:
		"gate_open":
			into.add_child(_tag("%s open" % Stats.gate_name(item.gate), Stats.gate_colour(item.gate),
				"%d casting%s" % [item.castings, "" if item.castings == 1 else "s"], "%s open: %d castings" % [Stats.gate_name(item.gate), item.castings]))
		"skill":
			var skill: SkillDefinition = item.skill
			var colour := Stats.gate_colour(skill.spell_slot_level) if Combat.is_spell(skill) else ACCENT.lightened(0.35)
			var notes := []
			if item.has("path"):
				notes.append(item.path.name)
			if item.get("learnable", false):
				notes.append("can be learned")
			elif Combat.is_spell(skill):
				notes.append("spell")
			into.add_child(_tag(skill.name, colour, ", ".join(notes), _unlock_reading(skill, entry, subject), skill.icon, skill))
		"rank":
			var skill: SkillDefinition = item.skill
			var rank: SkillRank = item.rank
			var title := skill.name + (" - %s" % rank.title if rank.title != "" else "")
			var changes := ", ".join(_rank_changes(rank))
			into.add_child(_tag(title, ACCENT.lightened(0.35), "stronger: " + changes,
				"%s grows stronger\n%s\n\n%s" % [title, changes, skill.description], skill.icon, skill))
		"passive", "path_passive":
			var passive: PassiveDefinition = item.passive
			var reading := [passive.name, passive.describe_when()]
			if passive.description != "":
				reading.append_array(["", passive.description])
			var from := "%s passive" % item.path.name if item.kind == "path_passive" else "passive"
			into.add_child(_tag(passive.name, PATH_COLOUR if item.kind == "path_passive" else PASSIVE_COLOUR, from, "\n".join(reading), passive.icon))
		"path":
			var chooses := Label.new()
			chooses.text = "Chooses a path:"
			chooses.add_theme_font_size_override("font_size", 14)
			chooses.add_theme_color_override("font_color", PATH_COLOUR)
			chooses.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			into.add_child(chooses)
			var chosen: SubclassDefinition = item.chosen
			for path in item.paths:
				var tag := _tag(path.name, PATH_COLOUR, "taken" if path == chosen else "", _path_reading(path), path.icon)
				if chosen != null and path != chosen:
					tag.modulate.a = 0.5
				into.add_child(tag)
		_:
			var other := RichTextLabel.new()
			other.bbcode_enabled = true
			other.fit_content = true
			other.text = item.text
			into.add_child(other)


## What a skill a level brings says on hover: the action panel's preview in a
## fight; out of one, its name, its numbers and what it says of itself.
func _unlock_reading(skill: SkillDefinition, entry: Dictionary, subject: Dictionary) -> String:
	if not subject.is_empty():
		return _preview_of(skill, subject)
	var lines := [skill.name, "  ·  ".join(facts_of(skill, {"level": maxi(entry.get("level", 1), comes_in(skill))}))]
	if skill.description != "":
		lines.append_array(["", skill.description])
	return "\n".join(lines)


## A path at 24, on hover: what it is, and the skills and passives it brings.
func _path_reading(path: SubclassDefinition) -> String:
	var lines := [path.name]
	if path.description != "":
		lines.append(path.description)
	var skills := []
	for key in path.skills:
		var skill: SkillDefinition = SkillDatabase.skills.get(key)
		if skill != null:
			skills.append("%s (%d)" % [skill.name, maxi(comes_in(skill), Stats.SUBCLASS_LEVEL)])
	if not skills.is_empty():
		lines.append_array(["", "Skills: " + ", ".join(skills)])
	var passives := []
	for passive in path.passives:
		if passive != null:
			passives.append("%s (%d)" % [passive.name, maxi(passive.required_level, Stats.SUBCLASS_LEVEL)])
	if not passives.is_empty():
		lines.append("Passives: " + ", ".join(passives))
	return "\n".join(lines)


## Where the levels stop until Chapter V: what is past ΛΗΘΗ, forgotten.
func _veil_line() -> Control:
	var veil := Label.new()
	veil.name = "Veil"
	veil.text = "Past %s, nothing is remembered." % LETHE
	veil.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	veil.add_theme_font_size_override("font_size", 13)
	veil.add_theme_color_override("font_color", MUTED)
	_stat_rows.add_child(veil)
	return veil


## The levels past ΛΗΘΗ uncovered, the first time the page is opened in Chapter
## V: the veil fades, ΛΗΘΗ flares, and the rows come up one after another, the
## view following them down to ΑΛΗΘΕΙΑ.
func _unveil(rows: Array, veil: Control, lethe_row: Control):
	Campaign.levels_unveiled = true
	for row in rows:
		row.modulate.a = 0.0
	_unveiling = create_tween()
	# Once the rows are laid out (_fit_to_screen), down to ΛΗΘΗ.
	_unveiling.tween_interval(0.15)
	_unveiling.tween_callback(func():
		if lethe_row != null and is_instance_valid(lethe_row):
			_stat_scroll.ensure_control_visible(lethe_row))
	var greek = lethe_row.find_child("Named", true, false) if lethe_row != null else null
	if greek != null:
		_unveiling.tween_property(greek, "modulate", Color(2.2, 2.0, 1.4), UNVEIL_PAUSE * 0.5)
		_unveiling.tween_property(greek, "modulate", Color.WHITE, UNVEIL_PAUSE * 0.5)
	else:
		_unveiling.tween_interval(UNVEIL_PAUSE)
	if veil != null:
		_unveiling.tween_property(veil, "modulate:a", 0.0, UNVEIL_ROW_SECONDS)
		_unveiling.tween_callback(veil.hide)
	for row in rows:
		var alpha: float = row.get_meta("alpha", 1.0)
		_unveiling.tween_callback(func():
			if is_instance_valid(row):
				_stat_scroll.ensure_control_visible(row))
		_unveiling.tween_property(row, "modulate:a", alpha, UNVEIL_ROW_SECONDS)
