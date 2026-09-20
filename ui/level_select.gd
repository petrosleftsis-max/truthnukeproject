extends Control
## The menu the game opens on: pick an encounter, see what condition the party
## is in, and reset them when they have been ground down too far.
##
## To add an encounter: make a new EncounterDefinition resource (see that
## script's header) and drop it into the Encounters array on this scene's root
## node in the inspector. Nothing else needs changing - the cards, keyboard
## navigation and scene loading are all built from this list at runtime.
##
## The look is built here rather than in the scene because most of it is per
## entry: a card knows how many enemies its encounter has, a party row knows
## how hurt that member is, and both need their colours to follow that.


## Every encounter offered, in the order they appear on screen.
@export var encounters: Array[EncounterDefinition]
## The battle scene loaded once an encounter is picked. One scene plays them
## all; the choice is passed through Campaign.current_encounter.
@export_file("*.tscn") var battle_scene: String = "res://scenes/game.tscn"

## Palette. Kept in one place so the whole menu can be re-tinted by editing
## these seven colours rather than hunting through the builders below.
const INK := Color("dce8f5")        ## Headings.
const INK_DIM := Color("c2ceda")    ## Body text on an unfocused card.
const MUTED := Color("8296a9")      ## Labels, descriptions, counts.
const ACCENT := Color("4a86c8")     ## Focus, and the party panel's edge.
const PANEL := Color("19212c")      ## Party panel.
const CARD := Color("1c2531")       ## A card at rest.
const CARD_LIT := Color("24344a")   ## A card under the cursor or focus.
const CARD_EDGE := Color("2b3947")
const TRACK := Color("2b3542")      ## Empty part of a health bar.

## Health bar fill, by how much is left. Red is only for the dead.
const HEALTH_FULL := Color("6fb26a")
const HEALTH_HURT := Color("c8913f")
const HEALTH_GONE := Color("a05a5a")

const ICON_SIZE := 18

@onready var _title: Label = $Center/VBox/Title
@onready var _party_panel: PanelContainer = $Center/VBox/PartyPanel
@onready var _party_box: VBoxContainer = $Center/VBox/PartyPanel/PartyBox
@onready var _list: VBoxContainer = $Center/VBox/EncounterList
@onready var _reset_button: Button = $Center/VBox/ResetButton
@onready var _main_menu_button: Button = $Center/VBox/MainMenuButton


func _ready():
	_title.add_theme_color_override("font_color", INK)
	_style_party_panel()
	_style_reset_button()
	_style_quiet_button(_main_menu_button)
	_reset_button.pressed.connect(_on_reset_pressed)
	# Opened mid-run, this hands you back where you were - the fight, or the
	# map and the tile you were standing on. Opened from the title screen there
	# is nothing to go back to, so it stays what it was.
	if Campaign.can_leave_arena():
		_main_menu_button.text = "Return"
		_main_menu_button.pressed.connect(Campaign.leave_arena)
	else:
		_main_menu_button.pressed.connect(Campaign.to_main_menu)
	_rebuild()


## Rebuilds the cards and the party panel. Called on load and again after a
## reset, so the screen always reflects the current campaign state rather than
## a snapshot from when it was first opened.
func _rebuild():
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for child in _party_box.get_children():
		_party_box.remove_child(child)
		child.queue_free()

	var wiped = Campaign.is_party_wiped()
	_build_party_panel(wiped)

	var buttons: Array = []
	for encounter in encounters:
		if encounter == null:
			continue
		var card = _build_encounter_card(encounter, wiped)
		_list.add_child(card)
		if not wiped:
			buttons.append(card)

	buttons.append(_reset_button)
	FocusLoop.link(buttons)
	# Held back rather than taken: a first card lit up under a mouse that is
	# elsewhere reads as already chosen. See FocusOnDemand.
	FocusOnDemand.attach(self, buttons[0])


## --- The party panel ---


func _style_party_panel():
	var box := StyleBoxFlat.new()
	box.bg_color = PANEL
	box.border_width_left = 3
	box.border_color = ACCENT
	box.content_margin_left = 11
	box.content_margin_right = 11
	box.content_margin_top = 9
	box.content_margin_bottom = 9
	_party_panel.add_theme_stylebox_override("panel", box)


func _build_party_panel(wiped: bool):
	_party_box.add_child(_caption("PARTY" if not wiped else "PARTY LOST"))
	var members = Campaign.party_members()
	if wiped:
		_party_box.add_child(_note("Everyone has fallen. Reset to fight again."))
		return
	if members.is_empty():
		# Before the first battle there is no roster yet - it gets seeded when a
		# map or an encounter first loads - so there is nothing to itemise.
		_party_box.add_child(_note("At full strength."))
		return
	for member in members:
		_party_box.add_child(_build_party_row(member))


## One member: portrait, name, health bar, and the numbers behind the bar.
func _build_party_row(member: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)

	row.add_child(_icon(member.icon))

	var name_label := Label.new()
	name_label.text = member.name
	name_label.custom_minimum_size = Vector2(96, 0)
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", INK_DIM)
	row.add_child(name_label)

	var fraction = 0.0 if member.max_hp <= 0 else float(member.hp) / float(member.max_hp)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 7)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.max_value = maxi(member.max_hp, 1)
	bar.value = member.hp
	bar.show_percentage = false
	var track := StyleBoxFlat.new()
	track.bg_color = TRACK
	bar.add_theme_stylebox_override("background", track)
	var fill := StyleBoxFlat.new()
	# Amber below a third, which is roughly "one more hit could do it".
	fill.bg_color = HEALTH_FULL if fraction > 0.34 else HEALTH_HURT
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)

	var count := Label.new()
	count.text = "%d/%d" % [member.hp, member.max_hp]
	count.add_theme_font_size_override("font_size", 11)
	count.add_theme_color_override("font_color", MUTED)
	row.add_child(count)
	return row


## --- Encounter cards ---
##
## Still a Button, so focus, keyboard navigation and the disabled state all
## behave exactly as before. The contents are children that ignore the mouse,
## which lets a click land on the button underneath them.
func _build_encounter_card(encounter: EncounterDefinition, wiped: bool) -> Button:
	var card := Button.new()
	# Tall enough for a name, the enemy portraits, and two lines of description.
	card.custom_minimum_size = Vector2(0, 88)
	# The name is the button's own text rather than a label laid over it, so the
	# card still announces what it is to anything that reads buttons - and so
	# hovering, focus and the disabled tint all treat it as one thing.
	card.text = encounter.display_name
	card.alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.add_theme_font_size_override("font_size", 15)
	card.add_theme_color_override("font_color", INK)
	card.add_theme_color_override("font_hover_color", INK)
	card.add_theme_color_override("font_focus_color", INK)
	card.add_theme_color_override("font_pressed_color", INK)
	card.add_theme_color_override("font_disabled_color", MUTED)
	# A wiped party would spawn an encounter with nobody on the player's side,
	# so there would be nothing to play. Reset is the way out.
	card.disabled = wiped
	if encounter.description != "":
		card.tooltip_text = encounter.description
	card.pressed.connect(_on_encounter_pressed.bind(encounter))
	_style_card(card)

	# The enemy portraits, top right. Anchored across the full width with the
	# row pushed to the end, which needs no grow-direction juggling.
	var icons := HBoxContainer.new()
	icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icons.add_theme_constant_override("separation", 3)
	icons.alignment = BoxContainer.ALIGNMENT_END
	icons.anchor_right = 1.0
	icons.offset_left = 11
	icons.offset_right = -11
	icons.offset_top = 7
	icons.offset_bottom = 7 + ICON_SIZE
	for enemy_icon in _enemy_icons(encounter):
		icons.add_child(_icon(enemy_icon))
	card.add_child(icons)

	if encounter.description != "":
		var description := Label.new()
		description.text = encounter.description
		description.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Wrapped, and trimmed with an ellipsis if even two lines will not hold
		# it - a description that runs off the side of its own card reads as a
		# layout fault rather than as text. The whole of it is in the tooltip.
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.max_lines_visible = 2
		description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		description.add_theme_font_size_override("font_size", 11)
		description.add_theme_color_override("font_color", MUTED)
		description.anchor_top = 1.0
		description.anchor_right = 1.0
		description.anchor_bottom = 1.0
		description.offset_left = 11
		description.offset_right = -11
		# Room for two lines at this size; a third is trimmed with an ellipsis and
		# the whole of it stays in the tooltip.
		description.offset_top = -40
		description.offset_bottom = -8
		card.add_child(description)
	return card


## The portrait of every enemy in the encounter, in spawn order - how many
## you are walking into, at a glance, without opening the fight.
func _enemy_icons(encounter: EncounterDefinition) -> Array:
	var found: Array = []
	for spawn in encounter.spawns:
		if spawn.side == 0:
			continue
		var definition: CombatantDefinition = CombatantDatabase.combatants.get(spawn.combatant_key)
		if definition != null and definition.portrait() != null:
			found.append(definition.portrait())
	return found


func _style_card(card: Button):
	card.add_theme_stylebox_override("normal", _card_box(CARD, CARD_EDGE))
	card.add_theme_stylebox_override("hover", _card_box(CARD_LIT, ACCENT))
	card.add_theme_stylebox_override("pressed", _card_box(CARD_LIT, ACCENT))
	card.add_theme_stylebox_override("focus", _card_box(CARD_LIT, ACCENT))
	card.add_theme_stylebox_override("disabled", _card_box(PANEL, CARD_EDGE))


func _card_box(fill: Color, edge: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_border_width_all(1)
	box.border_color = edge
	box.set_corner_radius_all(3)
	box.content_margin_left = 11
	box.content_margin_right = 11
	# The button centres its own text inside the content box, so a deep bottom
	# margin is what lifts the name clear of the description underneath it.
	box.content_margin_top = 4
	box.content_margin_bottom = 24
	return box


func _style_reset_button():
	_style_quiet_button(_reset_button)


## The understated look the buttons under the list share: no fill, a hairline
## above, and the accent only when it is being pointed at. They are ways out of
## the screen rather than things to pick, and should not compete with the cards.
func _style_quiet_button(button: Button):
	button.add_theme_color_override("font_color", MUTED)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_focus_color", INK)
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0, 0, 0, 0)
	flat.border_width_top = 1
	flat.border_color = CARD_EDGE
	flat.content_margin_top = 8
	flat.content_margin_bottom = 6
	button.add_theme_stylebox_override("normal", flat)
	var lit := flat.duplicate()
	lit.border_color = ACCENT
	button.add_theme_stylebox_override("hover", lit)
	button.add_theme_stylebox_override("pressed", lit)
	button.add_theme_stylebox_override("focus", lit)


## --- Small shared pieces ---


func _icon(texture: Texture2D) -> Control:
	var rect := TextureRect.new()
	rect.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.texture = texture
	return rect


func _caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", MUTED)
	return label


func _note(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", INK_DIM)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## Arena Mode is a fight picked off a list rather than one walked into, so the
## encounter decides who is in it. Clearing the roster lets Combat seed it from
## the encounter's own player spawns - without this, trying the lab fight after
## walking the crossroads as Cyrus fielded Cyrus alone, because the roster was
## still the one that map had set.
##
## Carried damage is left alone: "Reset party" on this screen is how that is
## cleared, and quietly healing everyone would make that button a lie.
func _on_encounter_pressed(encounter: EncounterDefinition):
	Campaign.party_order.clear()
	Campaign.current_map = ""
	Campaign.return_to_position = false
	Campaign.current_encounter = encounter
	SceneTransition.change_scene(battle_scene)


func _on_reset_pressed():
	Campaign.reset()
	_rebuild()
