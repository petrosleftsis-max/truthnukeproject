extends Control

signal turn_ended()
## Emitted when the player is done arranging the party and wants to fight.
signal deployment_finished()

@export var combat: Combat
@export var controller: CController

const TQIcon = preload("res://ui/tq_icon.tscn")
const StatusIcon = preload("res://ui/status_icon.tscn")

## True while this HUD is being used for exploration rather than a battle.
var exploration_mode := false

## Which list the action panel is showing. Three of them now: the two action
## slots, plus everything that costs a spell slot. Spells are a panel of their
## own rather than part of the main list because they are read against a
## resource - you pick one knowing what it will cost, not just what it does.
enum SkillPanel { MAIN, SECONDARY, ITEMS }

## Reset to MAIN whenever the turn passes to someone new, so a turn always
## starts on the panel you'd expect.
var showing_panel := SkillPanel.MAIN

## Whether the panel is showing what the current tab casts rather than what it
## swings. Orthogonal to the tab: Main and Spells together are the spells cast
## from the main action, Secondary and Spells the ones cast from the secondary.
##
## It used to be a fourth tab, which meant a list mixing both action slots and
## no way to ask "what can I cast with my secondary". Reset with the panel when
## the turn passes on.
var showing_spells := false

## Kept for anything still asking the old question. A spell is spent from the
## main slot unless it is also marked secondary, so "is this the secondary
## panel" is no longer the same question as "which slot will this spend".
var showing_secondary: bool:
	get: return showing_panel == SkillPanel.SECONDARY

## The node name of each panel's button, in enum order.
const PANEL_TABS := {
	SkillPanel.MAIN: "MainTab",
	SkillPanel.SECONDARY: "SecondaryTab",
	SkillPanel.ITEMS: "ItemsTab",
}

## The tab you are on, so it reads as selected rather than as another thing to
## press. Matching ui/blue_theme.tres.
const TAB_ON := Color("dce8f5")
const TAB_OFF := Color("8296a9")


## Whether the player has tucked the combat log out of the way. Kept for the
## whole battle rather than reset per turn: having to hide it again every time
## somebody else acted would be worse than not being able to hide it at all.
var _log_minimised := false

## The party member whose side of the HUD is on show instead of the one acting,
## after their portrait was clicked. Empty when the HUD shows whoever is acting.
## See view_combatant.
var _viewing: Dictionary = {}

## How the party portraits not being looked at are drawn while one is.
const PORTRAIT_ASIDE := Color(0.62, 0.62, 0.62)


func _ready():
	for panel in PANEL_TABS:
		var tab := _tab(panel)
		if tab != null:
			tab.pressed.connect(set_skill_panel.bind(panel))
	var spells := _spells_toggle()
	if spells != null:
		spells.pressed.connect(toggle_spells)
	var toggle = $Actions.get_node_or_null("LogToggle")
	if toggle != null:
		toggle.pressed.connect(toggle_log)
	_apply_log_state()
	_build_undo_button()
	_style_turn_buttons()
	_pips = ActionPips.new()
	$Actions.add_child(_pips)
	_pips.position = PIPS_AT
	_pips.visible = false
	# Before the grid's buttons are hung with marks: the shelves copy a clean one.
	_build_shelves()
	_build_hotkey_marks()
	_unit_card = UnitCard.new()
	add_child(_unit_card)
	_turn_banner = TurnBanner.new()
	add_child(_turn_banner)
	_build_danger_legend()
	# The label says what the number is, rather than leaving a lone "4" to
	# be worked out.
	$Actions/Movement.offset_left = MOVE_LABEL_LEFT
	$Actions/EndTurnButton.tooltip_text = KEYS_HINT
	# Things that happen to the party rather than in a fight - an item changing
	# hands, somebody joining or leaving - are announced by Campaign, which is
	# the one thing on screen in a battle and on a map alike.
	if not Campaign.announced.is_connected(update_information):
		Campaign.announced.connect(update_information)


## --- Taking a walk back ---
##
## A button over End Turn, and Backspace, walk the player acting back to where
## their turn began - see CController.can_undo_move for when that is allowed.
## Only there once they have walked; greyed out, saying why, once something on
## the way has made it too late.

const UNDO_TIP := "Walk back to where this turn began - or to just after the last skill, item or reaction - with the movement you had there (Backspace)"
const UNDO_TOO_LATE := "Too late to walk back: something happened on the way - a reaction, a skill or item, or somebody's state changed"

var _undo_button: Button = null


func _build_undo_button():
	var end_turn = $Actions/EndTurnButton
	# End Turn's own look, without its wiring: copied with no signals.
	_undo_button = end_turn.duplicate(0)
	_undo_button.name = "UndoMoveButton"
	_undo_button.text = "Undo Move"
	_undo_button.tooltip_text = UNDO_TIP
	_undo_button.visible = false
	$Actions.add_child(_undo_button)
	_undo_button.position = end_turn.position - Vector2(0, end_turn.size.y + 5)
	_undo_button.pressed.connect(_on_undo_pressed)


## --- The HUD's furniture ---

## Where the main/secondary marks sit: above the big portrait, left of the
## skill tabs.
const PIPS_AT := Vector2(-108, 10)
const MOVE_LABEL_LEFT := -108.0
## What every key does, on End Turn - the button every turn ends on, and so the
## one most often hovered.
const KEYS_HINT := "End this character's turn (Space)\n1-9: pick a skill    Tab: next tab\nBackspace: undo a walk    Shift: see where enemies could strike\nC: character sheet    Esc: menu"
const HOTKEY_MARK := "Hotkey"

var _pips: ActionPips = null
var _unit_card: UnitCard = null
var _turn_banner: TurnBanner = null
var _danger_legend: PanelContainer = null


## End Turn is what every turn ends on, so it is the one button in the accent;
## Undo Move beside it takes the theme's ordinary look rather than the flat grey
## it was copied with.
func _style_turn_buttons():
	var end_turn: Button = $Actions/EndTurnButton
	end_turn.add_theme_stylebox_override("normal", _accent_box(Color("2d5a8c"), Color("7fb4ea")))
	end_turn.add_theme_stylebox_override("hover", _accent_box(Color("3a6fa8"), Color("a5ccf2")))
	end_turn.add_theme_stylebox_override("pressed", _accent_box(Color("24496f"), Color("7fb4ea")))
	end_turn.add_theme_color_override("font_color", Color("eef4fb"))
	end_turn.add_theme_color_override("font_hover_color", Color.WHITE)
	end_turn.add_theme_color_override("font_pressed_color", Color.WHITE)
	if _undo_button != null:
		for style in ["normal", "hover", "pressed", "disabled", "focus"]:
			_undo_button.remove_theme_stylebox_override(style)
		for colour in ["font_color", "font_disabled_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			_undo_button.remove_theme_color_override(colour)


func _accent_box(fill: Color, edge: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	return box


## A small number in the corner of each of the first nine action buttons - the
## key that picks it.
func _build_hotkey_marks():
	var slots = $Actions/ActionsPanel/ActionsGrid.get_children()
	for i in mini(slots.size(), 9):
		_hotkey_mark(slots[i], i + 1).visible = false


## The number `key` in the corner of `button`, made the first time it is asked
## for. The grid's are made once; the shelves' each time they are built.
func _hotkey_mark(button: Button, key: int) -> Label:
	var mark: Label = button.get_node_or_null(HOTKEY_MARK)
	if mark == null:
		mark = Label.new()
		mark.name = HOTKEY_MARK
		mark.add_theme_font_size_override("font_size", 11)
		mark.add_theme_color_override("font_color", Color("c2ceda"))
		mark.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		mark.add_theme_constant_override("outline_size", 3)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(mark)
		mark.position = Vector2(3, 0)
	mark.text = str(key)
	return mark


## Says what the danger view's colours mean while Shift is held.
func _build_danger_legend():
	_danger_legend = PanelContainer.new()
	_danger_legend.name = "DangerLegend"
	_danger_legend.theme_type_variation = &"TooltipPanel"
	_danger_legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_danger_legend.visible = false
	var text := Label.new()
	text.text = "Red: an enemy could reach and hit here next turn - deeper red, more of them\nOrange edge: stepping out of here sets off an enemy's reaction"
	text.add_theme_font_size_override("font_size", 14)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_danger_legend.add_child(text)
	add_child(_danger_legend)


func set_danger_legend(on: bool):
	if _danger_legend == null:
		return
	_danger_legend.visible = on and not exploration_mode
	if _danger_legend.visible:
		_danger_legend.reset_size()
		var screen = get_viewport_rect().size
		_danger_legend.global_position = Vector2((screen.x - _danger_legend.size.x) * 0.5, TurnBanner.TOP + 56.0)


func show_unit_card(comb: Dictionary):
	if _unit_card == null or combat == null:
		return
	if _unit_card.visible and _unit_card.shown_id == comb.get("id", -2):
		_unit_card.place()
	else:
		_unit_card.show_for(comb, combat)


func hide_unit_card():
	if _unit_card != null:
		_unit_card.hide_card()


## What hovering a face in the turn queue says.
func _queue_tip(comb: Dictionary) -> String:
	if not comb.get("alive", false):
		return comb.name
	var most = combat.get_effective_stat(comb, "max_hp")
	if comb.side != 0 and combat.is_hidden(comb):
		return "%s\nHidden - somewhere you cannot see" % comb.name
	return "%s\n%d / %d HP\nClick to find them on the map" % [comb.name, comb.hp, most]


## Takes the view to whoever's face in the queue was clicked - unless they are
## hidden, or the view is busy following somebody's turn.
func _on_queue_input(event: InputEvent, comb: Dictionary):
	if _aim_through_face(event, comb):
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	accept_event()
	if combat == null or combat.camera == null or not comb.get("alive", false):
		return
	if comb.side != 0 and combat.is_hidden(comb):
		return
	if combat.camera.is_following():
		return
	combat.camera.position = Grid.tile_to_world(comb.position)
	combat.camera.clamp_to_map()


func _point_out(comb: Dictionary):
	if controller != null and controller.has_method("highlight_unit"):
		controller.highlight_unit(comb)
	if _aiming_now():
		controller.preview_aim_at_combatant(comb)
		_face_preview = true


func _stop_pointing():
	if controller != null and controller.has_method("clear_highlight"):
		controller.clear_highlight()
	# Taken away even once the aim is over - clicked, the skill went off and
	# left the mark on whoever it was used on.
	if _face_preview:
		_face_preview = false
		if controller != null and controller.has_method("clear_aim_preview"):
			controller.clear_aim_preview()


## --- Aiming at a face ---
##
## While a skill is being aimed, the faces in the party column and the turn
## queue stand in for the bodies on the map: hovered, they show what it would do
## to them; clicked, it is used on them - by the same rules as a click on the
## map, reach included. See CController.aim_refusal. Right-click puts the aim
## away, as it does over the map.

## Whether hovering a face has put marks on the map that leaving it should take
## away.
var _face_preview := false


func _aiming_now() -> bool:
	return controller != null and controller.has_method("aim_at_combatant") and controller.is_skill_selected() \
			and not exploration_mode and not _deployment_mode


## Takes a click on `comb`'s face for the aim, if there is one. True when it
## was the aim's to take, whether it was used or refused: a face clicked while
## aiming is never also a request to go to them or see their side of the HUD.
func _aim_through_face(event: InputEvent, comb: Dictionary) -> bool:
	if not _aiming_now() or not (event is InputEventMouseButton):
		return false
	accept_event()
	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		controller.aim_at_combatant(comb)
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.is_released():
		controller.cancel_skill_selection()
	return true


## What hovering a face says: why the skill being aimed could not be used on
## them - or nothing when it could, since the prompt beside the cursor says what
## it would do. Its own tooltip the rest of the time.
func _face_tip(face: Control, comb: Dictionary) -> String:
	if not _aiming_now():
		return face.tooltip_text
	var refusal: String = controller.aim_refusal(comb)
	if refusal == "":
		return ""
	return "%s\n%s" % [comb.name, refusal]


## Picks the skill in slot `index` the way clicking it would. False, and
## nothing done, when that could not be clicked right now either.
func _press_hotkey(index: int) -> bool:
	if controller == null or not controller.player_turn or controller.is_skill_selected():
		return false
	if controller.action_locked or not controller.is_idle():
		return false
	var slots = action_buttons()
	if index >= slots.size():
		return false
	var slot: Button = slots[index]
	if slot.icon == null or not slot.is_visible_in_tree():
		return false
	if slot.disabled:
		# Greyed out - spent, unaffordable, or a teammate's - so only a look.
		return _look_at(slot.get_meta(SKILL_META, ""))
	slot.pressed.emit()
	return true


## --- Looking at what cannot be used ---
##
## A greyed-out skill can still be pressed, to aim it without using it: its
## reach, where it would land and what it would do, from whoever it belongs to.
## See CController.begin_look.

const SKILL_META := "skill_key"

## Which action buttons already turn a click on them, greyed out, into a look.
var _look_wired := {}


## Takes a look at `skill_key` in the hands of whoever's HUD is on show. False,
## and nothing done, when no aiming could start right now either.
func _look_at(skill_key: String) -> bool:
	if skill_key == "" or combat == null or controller == null or exploration_mode or _deployment_mode:
		return false
	if not controller.has_method("begin_look") or not controller.player_turn:
		return false
	if controller.action_locked or not controller.is_idle() or controller.is_skill_selected():
		return false
	var owner := shown_combatant()
	if owner.is_empty() or not owner.get("alive", false):
		return false
	controller.begin_look(skill_key, owner)
	return true


func _looking_only() -> bool:
	return controller != null and controller.has_method("is_look_only") and controller.is_look_only()


## A click on a greyed-out button: the button itself will not press, so the
## look is started from here.
func _on_action_gui_input(event: InputEvent, action: Button):
	if not action.disabled or not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or event.pressed:
		return
	if _look_at(action.get_meta(SKILL_META, "")):
		accept_event()


## Tab moves to the next tab there is - Main, Secondary, Items, and round.
func _cycle_panel() -> bool:
	if controller != null and controller.is_skill_selected():
		return false
	var order = [SkillPanel.MAIN, SkillPanel.SECONDARY, SkillPanel.ITEMS]
	var at = order.find(showing_panel)
	for step in range(1, order.size() + 1):
		var next = order[(at + step) % order.size()]
		var tab := _tab(next)
		if tab == null or tab.visible:
			set_skill_panel(next)
			return true
	return false


## The damage an aimed skill would do, marked on the health bars of everybody it
## would catch - in the turn queue and the party column both.
func _show_ghost(target: Dictionary, change: int):
	for holder in [$TurnQueue/Queue, $Status]:
		var icon = _icon_for(holder, target)
		if icon != null and icon.has_method("show_change"):
			icon.show_change(change)


func _clear_ghosts():
	for holder in [$TurnQueue/Queue, $Status]:
		for icon in holder.get_children():
			if icon.has_method("clear_change"):
				icon.clear_change()


func _announce_turn(comb: Dictionary):
	if _turn_banner == null or exploration_mode or _deployment_mode or comb.is_empty():
		return
	_turn_banner.announce("%s's Turn" % comb.name, Color("dce8f5") if comb.side == 0 else Color("e08a8a"))


func _on_undo_pressed():
	if controller != null and controller.has_method("undo_move"):
		controller.undo_move()


## Shown once the player acting has walked, pressable while the walk can still
## be taken back.
func _refresh_undo():
	if _undo_button == null:
		return
	var can_show = controller != null and controller.has_method("has_walked") \
			and not exploration_mode and not _deployment_mode and not is_viewing_other() \
			and not controller.is_skill_selected() and controller.has_walked()
	_undo_button.visible = can_show
	if not can_show:
		return
	var allowed = controller.can_undo_move()
	_undo_button.disabled = not allowed
	_undo_button.tooltip_text = UNDO_TIP if allowed else UNDO_TOO_LATE


## Folds the combat log away, or brings it back. The button stays where the
## log's corner was, so there is always something to press to get it back.
func toggle_log():
	_log_minimised = not _log_minimised
	_apply_log_state()


func log_minimised() -> bool:
	return _log_minimised


func _apply_log_state():
	var panel = $Actions.get_node_or_null("Information")
	if panel != null:
		# Nothing has happened yet while the party is being placed, and the
		# cluster is meant to be out of the way until the battle starts.
		panel.visible = not _log_minimised and not _deployment_mode
	var toggle = $Actions.get_node_or_null("LogToggle")
	if toggle != null:
		toggle.text = "+" if _log_minimised else "-"
		toggle.tooltip_text = "Show the combat log" if _log_minimised else "Hide the combat log"


func _spells_toggle() -> Button:
	return $Actions.get_node_or_null("SpellsToggle") as Button


## Swaps the panel between what this slot swings and what it casts.
##
## The button says where pressing it takes you rather than where you are, the
## way a light switch does: it reads "Spells" while you are looking at skills,
## and "Skills" while you are looking at spells.
func toggle_spells():
	showing_spells = not showing_spells
	if combat != null and not exploration_mode:
		_show_skills_for(shown_combatant())
	_refresh_spells_toggle(shown_combatant())


func _refresh_spells_toggle(comb):
	var spells := _spells_toggle()
	if spells == null:
		return
	# Nothing to swap to on the Items tab, which is neither skills nor spells,
	# and nothing to swap to for somebody who casts nothing at all.
	var castable = combat != null and comb != null and not comb.is_empty() \
			and not combat.spell_skills_of(comb).is_empty()
	spells.visible = castable and showing_panel != SkillPanel.ITEMS
	spells.text = "Skills" if showing_spells else "Spells"


func _tab(panel: int) -> Button:
	return $Actions/SkillPanelTabs.get_node_or_null(PANEL_TABS[panel]) as Button


## Switches which list the action panel is showing. A button per panel rather
## than one that cycles: with three of them, cycling meant pressing twice to
## reach the last one and remembering the order to know which press got you
## there. Three buttons say where you can go and which one you are on.
func set_skill_panel(panel: int):
	showing_panel = panel
	_refresh_spells_toggle(shown_combatant())
	for other in PANEL_TABS:
		var tab := _tab(other)
		if tab == null:
			continue
		var selected = other == showing_panel
		tab.add_theme_color_override("font_color", TAB_ON if selected else TAB_OFF)
		tab.add_theme_color_override("font_hover_color", TAB_ON)
		tab.button_pressed = selected
	if combat != null and not exploration_mode:
		_show_skills_for(shown_combatant())


## Hides the Spells tab for anyone who casts nothing, so a swordsman is not
## offered a panel that can only ever be empty. Main and Secondary always
## stand: both are action slots everybody has, and an empty one is worth
## seeing as empty.
func _refresh_tabs(comb):
	var known = combat != null and comb != null and not comb.is_empty()
	# Somebody who casts nothing is shown no way to ask for spells, and a list
	# they are looking at that empties under them drops back to their skills.
	if known and combat.spell_skills_of(comb).is_empty():
		showing_spells = false
	_refresh_spells_toggle(comb)
	var items_tab := _tab(SkillPanel.ITEMS)
	if items_tab != null:
		# Empty hands, no tab - the same rule the Spells tab follows.
		var carrying = known and not combat.items_of(comb).is_empty()
		items_tab.visible = carrying
		if not carrying and showing_panel == SkillPanel.ITEMS:
			set_skill_panel(SkillPanel.MAIN)


## Fills the action panel from whichever list is currently on show, and keeps
## the spell slot readout in step with whoever's turn it is.
func _show_skills_for(comb: Dictionary):
	if combat == null:
		_set_shelved(false)
		set_skill_list([], true)
		_update_spell_slots(null)
		return
	_refresh_tabs(comb)
	# Spells go on shelves, one per gate; skills and items stay on the grid.
	var shelved = showing_spells and showing_panel != SkillPanel.ITEMS
	_set_shelved(shelved)
	_update_spell_slots(comb)
	var list = []
	var used = false
	match showing_panel:
		SkillPanel.SECONDARY:
			# The spells cast from this slot, or the skills swung from it.
			list = combat.spells_in_slot(comb, true) if showing_spells else combat.secondary_skills_of(comb)
			used = comb.get("secondary_used_this_turn", false)
		SkillPanel.ITEMS:
			list = combat.items_of(comb)
			# Same as the spells: which slot a consumable costs is the item's
			# own business, so the panel dies only when both slots have gone.
			used = comb.get("skill_used_this_turn", false) and comb.get("secondary_used_this_turn", false)
		_:
			list = combat.spells_in_slot(comb, false) if showing_spells else combat.main_skills_of(comb)
			used = comb.get("skill_used_this_turn", false)
	if shelved:
		_fill_shelves(comb, list, used, showing_panel == SkillPanel.SECONDARY)
	else:
		set_skill_list(list, used, showing_panel == SkillPanel.SECONDARY)
	# Mid-walk, the turn is not theirs to end. The skills already grey out for
	# the duration (see CController.is_idle, which calls this on both ends of a
	# move) but End Turn did not, and a Button press goes through its own
	# pressed signal rather than _unhandled_input - so the keyboard was refusing
	# what the mouse was still allowed to do, and a turn could be ended with
	# somebody halfway between two tiles.
	if controller != null and controller.has_method("is_idle"):
		$Actions/EndTurnButton.disabled = not controller.is_idle() or is_viewing_other()
	_refresh_undo()
	if _pips != null:
		_pips.show_for(comb, combat)


## Switches the HUD between battle and exploration. Exploration keeps the party
## status panel and the message log - both still useful while walking around -
## and hides the three things that only mean anything on a combat turn: the
## turn queue, the movement counter and End Turn. The action buttons are
## emptied rather than hidden, so the panel stays where it is instead of the
## layout shifting between modes; there is no Combat node to resolve a skill
## against out here.
func set_exploration_mode(enabled: bool):
	exploration_mode = enabled
	$TurnQueue.visible = not enabled
	$Actions/Movement.visible = not enabled
	$Actions/EndTurnButton.visible = not enabled
	$Actions/SkillPanelTabs.visible = not enabled
	if _pips != null:
		_pips.visible = not enabled
	if enabled:
		_set_shelved(false)
		set_skill_list([], true)
		_update_spell_slots(null)
		$Actions/SelectTargetMessage.visible = false


## Draws the party portraits down the left while exploring.
##
## The combat path fills this panel from Combat's combatant_added signal, which
## never fires out here - so before this the column simply sat empty. Takes
## plain dictionaries (see Campaign.party_members) rather than combatant
## dictionaries, because there is no Combat to ask for effective stats.
##
## The leader is shown at full brightness and mirrored into the large portrait
## the combat HUD uses for whoever's turn it is, so it always reads as "this is
## the one you're steering".
func show_exploration_party(members: Array):
	for child in $Status.get_children():
		$Status.remove_child(child)
		child.queue_free()
	for member in members:
		var new_status = StatusIcon.instantiate()
		$Status.add_child(new_status)
		new_status.set_icon(member.icon)
		new_status.set_name_text(member.name)
		new_status.set_health(member.hp, member.max_hp)
		new_status.name = member.name
		new_status.modulate = Color.WHITE if member.is_leader else Color(0.62, 0.62, 0.62)
	if members.is_empty():
		return
	$Actions/StatusIcon.set_icon(members[0].icon)
	$Actions/StatusIcon.set_name_text(members[0].name)
	$Actions/StatusIcon.set_health(members[0].hp, members[0].max_hp)


## Shows what the party can interact with right now, reusing the same banner
## combat uses to say "select a target". Pass "" to clear it.
func set_interaction_prompt(text: String):
	$Actions/SelectTargetMessage.visible = text != ""
	if text != "":
		$Actions/SelectTargetMessage/MarginContainer/Label.text = text


func add_turn_queue_icon(combatant: Dictionary):
	var new_icon = TQIcon.instantiate()
	$TurnQueue/Queue.add_child(new_icon)
	new_icon.set_max_hp(combat.get_effective_stat(combatant, "max_hp"))
	new_icon.set_hp(combatant.hp)
	new_icon.texture = combatant.icon
	# Named for the editor's benefit, found by id: three barbarians share a name,
	# and Godot would quietly make the second one "Barbarian2" anyway.
	new_icon.name = "TQ%d" % combatant.get("id", 0)
	new_icon.set_meta("combatant_id", combatant.get("id", 0))
	new_icon.set_side(combatant.side)
	# Hovered: who it is, and a gold outline on them on the map. Clicked: the
	# view goes to them.
	new_icon.mouse_filter = Control.MOUSE_FILTER_STOP
	new_icon.tooltip_text = _queue_tip(combatant)
	new_icon.tip_source = _face_tip.bind(new_icon, combatant)
	new_icon.mouse_entered.connect(_point_out.bind(combatant))
	new_icon.mouse_exited.connect(_stop_pointing)
	new_icon.gui_input.connect(_on_queue_input.bind(combatant))


func update_turn_queue(combatants: Array, turn_queue: Array):
	for c in turn_queue:
		var comb = combatants[c]
		add_turn_queue_icon(comb)


func combatant_died(combatant):
	if combatant == _viewing:
		stop_viewing()
	var turn_queue_icon = _icon_for($TurnQueue/Queue, combatant)
#	if combatant.side == 0:
#		var status = $Status.find_child(combatant.name, false, false)
#		if status != null:
#			status.queue_free()
	if turn_queue_icon != null:
		turn_queue_icon.queue_free()


## The icon standing for `comb`, or null. By id rather than by name, so a fight
## with three of the same combatant in it takes the right one off the screen.
func _icon_for(container: Node, comb: Dictionary) -> Node:
	var wanted = comb.get("id", -1)
	for child in container.get_children():
		if child.get_meta("combatant_id", -2) == wanted:
			return child
	return null


func add_combatant_status(comb: Dictionary):
	if comb.side == 0:
		var new_status = StatusIcon.instantiate()
		$Status.add_child(new_status)
		new_status.set_icon(comb.icon)
		new_status.set_health(comb.hp, combat.get_effective_stat(comb, "max_hp"))
		new_status.name = "Status%d" % comb.get("id", 0)
		new_status.set_meta("combatant_id", comb.get("id", 0))
		# Clicked anywhere on it, the health bar included - which would otherwise
		# take the click for itself.
		for part in new_status.find_children("*", "Control", true, false):
			part.mouse_filter = Control.MOUSE_FILTER_IGNORE
		new_status.mouse_filter = Control.MOUSE_FILTER_STOP
		new_status.tooltip_text = "%s - click to see their side of the HUD" % comb.name
		new_status.tip_source = _face_tip.bind(new_status, comb)
		new_status.gui_input.connect(_on_portrait_input.bind(comb))
		new_status.set_name_text(comb.name)
		new_status.mouse_entered.connect(_point_out.bind(comb))
		new_status.lights_on_hover = true
		new_status.mouse_exited.connect(_stop_pointing)


func _on_portrait_input(event: InputEvent, comb: Dictionary):
	if _aim_through_face(event, comb):
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		view_combatant(comb)


## --- Looking at somebody else's turn ---
##
## Clicking a party portrait shows that character's side of the HUD as though it
## were their turn - their face, health, movement and gates, and every tab of
## their kit, previewed in their own hands - with each action greyed out, since
## it is not. End Turn greys out with them: the turn it would end is not the one
## on show.
##
## It lasts until the turn it is not moves on: the one acting walks or acts, the
## turn passes, Escape is pressed, or the one acting (or the one being looked
## at) has their portrait clicked.


## Whoever the HUD is showing: the party member being looked at, or whoever is
## acting.
func shown_combatant() -> Dictionary:
	if is_viewing_other():
		return _viewing
	if combat == null or exploration_mode:
		return {}
	return combat.get_current_combatant()


## Whether the HUD is showing somebody other than whoever is acting.
func is_viewing_other() -> bool:
	return not _viewing.is_empty() and _viewing.get("alive", false) and combat != null \
			and _viewing != combat.get_current_combatant()


## Shows `comb`'s side of the HUD - or goes back to whoever is acting, when that
## is who was clicked, or when `comb` is already on show.
func view_combatant(comb: Dictionary):
	if combat == null or exploration_mode or _deployment_mode:
		return
	if comb == combat.get_current_combatant() or comb == _viewing or not comb.get("alive", false):
		stop_viewing()
		return
	_viewing = comb
	_show_whoever_is_shown()


## Back to whoever is acting.
func stop_viewing():
	if _viewing.is_empty():
		return
	_viewing = {}
	_show_whoever_is_shown()


## Redraws everything on the HUD that belongs to one person, for whoever is on
## show now.
func _show_whoever_is_shown():
	var comb = shown_combatant()
	if comb.is_empty():
		return
	if comb.side == 0:
		$Actions/StatusIcon.set_icon(comb.icon)
		$Actions/StatusIcon.set_name_text(comb.name)
		$Actions/StatusIcon.set_health(comb.hp, combat.get_effective_stat(comb, "max_hp"))
	# What they would have to walk with on their turn, or what the one acting
	# has left of theirs.
	if is_viewing_other():
		$Actions/Movement.text = "Move %d" % combat.get_effective_stat(comb, "movement")
	elif controller != null:
		$Actions/Movement.text = "Move %d" % controller.movement
	showing_spells = false
	set_skill_panel(SkillPanel.MAIN)
	_refresh_portraits()
	var banner = $Actions/SelectTargetMessage
	if is_viewing_other():
		$Actions/SelectTargetMessage/MarginContainer/Label.text = "Looking at %s - Esc to go back" % comb.name
		banner.visible = true
	else:
		banner.visible = false


## Dims every party portrait but the one being looked at, so the column says
## whose side of the HUD is on show. All of them lit when it is the one acting.
func _refresh_portraits():
	for status in $Status.get_children():
		var lit = not is_viewing_other() or status.get_meta("combatant_id", -1) == _viewing.get("id", -2)
		status.modulate = Color.WHITE if lit else PORTRAIT_ASIDE


## Escape goes back, taken before anything else hears it - the pause menu would
## otherwise open over a HUD still showing somebody else.
func _input(event):
	if not is_viewing_other():
		return
	# Mid-look at a teammate's skill, Escape ends the look first; the view of
	# them stays until it is pressed again.
	if controller != null and controller.is_skill_selected():
		return
	if event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		stop_viewing()


func show_combatant_status_main(comb: Dictionary):
	# A new turn is always shown as the turn it is.
	if is_viewing_other():
		$Actions/SelectTargetMessage.visible = false
	_viewing = {}
	_refresh_portraits()
	hide_unit_card()
	_announce_turn(comb)
	if comb.side == 0:
		$Actions/StatusIcon.set_icon(comb.icon)
		$Actions/StatusIcon.set_name_text(comb.name)
		$Actions/StatusIcon.set_health(comb.hp, combat.get_effective_stat(comb, "max_hp"))
	# A new turn always opens on the main panel, showing skills rather than
	# whatever the last turn happened to be looking at.
	showing_spells = false
	set_skill_panel(SkillPanel.MAIN)
	_show_skills_for(comb)
	# The queue has to be redrawn on every turn change, not only when someone
	# takes damage, or the ring stays on whoever acted last.
	if combat != null:
		update_combatants(combat.combatants)


## True while the player is placing the party, before the first turn.
var _deployment_mode := false
var _end_turn_default_text := ""


## Switches the HUD into (or out of) the pre-battle deployment step. The End
## Turn button doubles as Begin Battle - it's the one "I'm done" control the
## layout already has, and it means nothing during deployment anyway. Skills
## are locked out so a hero can't act before the fight has started.
## What deployment still needs on screen. Everything else in the Actions
## cluster goes away until the battle starts.
const DEPLOYMENT_KEEP := ["EndTurnButton", "SelectTargetMessage"]


## Clears the HUD for the deployment step, the same way aiming a skill does.
##
## Hiding rather than merely disabling: a disabled skill button was re-enabled
## by any refresh_action_buttons() that happened to run while the party was
## being placed, and pressing one then began target selection - which hid the
## whole cluster and waited for a target that deployment would never deliver,
## leaving the HUD gone for the rest of the battle.
func _apply_deployment_visibility():
	for child in $Actions.get_children():
		child.visible = child.name in DEPLOYMENT_KEEP


func set_deployment_mode(active: bool):
	if _end_turn_default_text == "":
		_end_turn_default_text = $Actions/EndTurnButton.text
	_deployment_mode = active
	$Actions/EndTurnButton.visible = true
	$Actions/EndTurnButton.disabled = false
	$Actions/EndTurnButton.text = "Begin Battle" if active else _end_turn_default_text
	$Actions/SelectTargetMessage.visible = active
	if active:
		if _turn_banner != null:
			_turn_banner.dismiss()
		$Actions/SelectTargetMessage/MarginContainer/Label.text = "Click a hero, then a highlighted tile to move them there."
		lock_action_buttons()
		$Actions/EndTurnButton.disabled = false
		_apply_deployment_visibility()
	else:
		# Put back everything deployment tucked away, then let the normal rules
		# for whoever is acting decide what is actually pressable.
		_set_aiming(false)
		refresh_action_buttons()
		# The first turn was handed out before the party was placed, when a
		# banner would only have been in the way. Now it is the turn.
		if combat != null and not combat.combatants.is_empty():
			_announce_turn(combat.get_current_combatant())


## Space ends the turn, the same as pressing the button.
##
## The key itself rather than ui_accept, which is also Enter and the gamepad's
## A: those advance dialogue and press whatever button has focus, and a turn
## ending because somebody dismissed a line would be a nasty surprise.
## Everything the button refuses, this refuses too - it is the same press, so
## it cannot end a turn the button would not.
func _unhandled_input(event):
	if not (event is InputEventKey and event.pressed and not event.is_echo()):
		return
	var code = event.physical_keycode
	if (code >= KEY_1 and code <= KEY_9) or code == KEY_TAB:
		# 1-9 pick the skill in that slot, Tab moves to the next tab - both
		# refusing whatever a click would refuse.
		if exploration_mode or _deployment_mode or combat == null or controller == null:
			return
		if controller.has_method("a_menu_is_over_the_map") and controller.a_menu_is_over_the_map():
			return
		var done = _cycle_panel() if code == KEY_TAB else _press_hotkey(code - KEY_1)
		if done:
			get_viewport().set_input_as_handled()
		return
	if event.physical_keycode == KEY_BACKSPACE:
		# Backspace walks back, where the button would - and refuses whatever it
		# would refuse, can_undo_move being the one judge of both.
		if exploration_mode or _deployment_mode or combat == null or controller == null:
			return
		if controller.has_method("a_menu_is_over_the_map") and controller.a_menu_is_over_the_map():
			return
		if controller.has_method("undo_move") and controller.undo_move():
			get_viewport().set_input_as_handled()
		return
	if event.physical_keycode != KEY_SPACE:
		return
	if exploration_mode or _deployment_mode or combat == null:
		return
	if controller == null or not controller.player_turn:
		return
	# Mid-aim, mid-walk or mid-animation: not now.
	if controller.is_skill_selected() or controller.action_locked or not controller.is_idle():
		return
	if controller.has_method("a_menu_is_over_the_map") and controller.a_menu_is_over_the_map():
		return
	if $Actions/EndTurnButton.disabled or not $Actions/EndTurnButton.visible:
		return
	get_viewport().set_input_as_handled()
	_on_end_turn_button_pressed()


func _on_end_turn_button_pressed():
	# The same refusal the keyboard makes, in the one place every route to
	# ending a turn passes through - greying the button out is what the player
	# sees, and this is what makes it true.
	if not _deployment_mode and controller != null and controller.has_method("is_idle") \
			and not controller.is_idle():
		return
	if _deployment_mode:
		deployment_finished.emit()
	else:
		turn_ended.emit()


func update_information(info: String):
	$Actions/Information/Text.append_text(info)


## Force-disables every action button, including End Turn - used right
## before a skill's animation starts playing, since Button presses bypass
## _unhandled_input's action_locked check entirely (they go through their
## own pressed signal instead), so the buttons need locking separately.
func lock_action_buttons():
	for action in $Actions/ActionsPanel/ActionsGrid.get_children():
		action.disabled = true
	if _shelves != null:
		for action in _shelves.buttons():
			action.disabled = true
	$Actions/EndTurnButton.disabled = true


## Re-establishes normal button state for whoever's turn it currently is -
## used right after a skill's animation finishes, to undo lock_action_buttons.
func refresh_action_buttons():
	if combat == null:
		return
	if _deployment_mode:
		# The party is still being placed. Nothing here is anybody's to press
		# yet, and a refresh from elsewhere must not quietly hand it back.
		lock_action_buttons()
		$Actions/EndTurnButton.disabled = false
		_apply_deployment_visibility()
		return
	# Something happened on the turn being played - a step, a skill - so the HUD
	# goes back to showing it rather than someone else's.
	if is_viewing_other():
		stop_viewing()
		return
	_show_skills_for(combat.get_current_combatant())


## Which action a consumable costs whoever is holding it. Its own is_secondary
## decides, except for anyone quick enough to reach for a potion with their off
## hand once the main action has gone - that is Cyrus, and it is why he can
## drink and still swing.
func _consumable_spends_secondary(comb: Dictionary, item: SkillDefinition) -> bool:
	if item.is_secondary:
		return true
	if comb.is_empty():
		return false
	if combat == null or not combat.items_as_secondary(comb):
		return false
	# The secondary first, and the main action only once the secondary is gone.
	#
	# It read the other way round - the main action unless that had already been
	# spent - which meant reaching for a bottle cost the turn's real action
	# while the slot that exists precisely so it would not sat unused. Somebody
	# who can use items from either slot should be spending the cheaper one.
	return not comb.get("secondary_used_this_turn", false)


func set_skill_list(skill_list: Array, skill_used: bool = false, as_secondary: bool = false):
	var actions_grid_children = $Actions/ActionsPanel/ActionsGrid.get_children()
	var skills := skill_list.map(func(key): return SkillDatabase.skills[key])
	var tags := SkillLook.tags_for(skills)
	for i in range(actions_grid_children.size()):
		var action = actions_grid_children[i] as Button
		if skill_list.size() > i:
			_fill_action(action, skill_list[i], skill_used, as_secondary, tags[i])
		else:
			_empty_action(action, skill_used)
	_finish_action_panel()


## One action button made to offer `skill_key`: its picture and badge, whether
## it can be pressed right now, what hovering it says, and what pressing it does.
## The grid and the spell shelves both fill their buttons through this, so the
## two can never disagree about when a skill is available.
func _fill_action(action: Button, skill_key: String, skill_used: bool, as_secondary: bool, tag: String = ""):
	# There is no CController while exploring - no turn is in progress and
	# nothing could resolve a skill - so every action button stays disabled.
	var player_turn = controller.player_turn if controller != null else false
	# Nothing may be picked while a combatant is walking or an animation is
	# resolving: the turn's state is mid-change, and the skill would be aimed
	# from wherever they happened to be standing at the time.
	var busy = controller != null and (controller.action_locked or not controller.is_idle())
	var comb = shown_combatant()
	# Somebody else's kit, on a turn that is not theirs: all of it greyed out,
	# and none of it wired to anything, so no route can pick one of it.
	var looking = is_viewing_other()
	action.disabled = player_turn == false or skill_used or busy or looking
	var skill = SkillDatabase.skills[skill_key]
	# On the Spells panel each entry decides its own slot, since a
	# spell marked secondary is cast from the secondary action while
	# the rest are cast from the main one.
	var spends_secondary = as_secondary
	if showing_panel == SkillPanel.ITEMS:
		spends_secondary = _consumable_spends_secondary(comb, skill)
	if (showing_spells or showing_panel == SkillPanel.ITEMS) and not comb.is_empty() and not action.disabled:
		var slot_spent = comb.get("secondary_used_this_turn", false) if spends_secondary else comb.get("skill_used_this_turn", false)
		# Greyed out for the two separate reasons a spell can be
		# unavailable: the action is gone, or the slots are.
		action.disabled = slot_spent or not combat.can_afford_skill(comb, skill)
	action.icon = skill.icon
	SkillLook.decorate(action, skill, tag)
	var key_mark = action.get_node_or_null(HOTKEY_MARK)
	if key_mark != null:
		key_mark.visible = not exploration_mode
	# Worked out in the hands of whoever is on show, so looking at a
	# teammate says what they would hit for rather than the one acting.
	var tip := build_skill_tooltip(skill, _viewing if looking else {})
	var paying := _gate_up(action, comb, skill)
	if paying > 0:
		tip = "Your %s is spent - this will use %s.\n\n%s" % [
			Stats.gate_name(skill.spell_slot_level), Stats.gate_name(paying), tip]
	action.tooltip_text = TooltipText.wrap(tip)
	clear_action_button_connections(action)
	# Pressable or not, it can be looked at: a greyed-out button does not press,
	# so its clicks are caught here and turned into a look. See _look_at.
	action.set_meta(SKILL_META, skill_key)
	# Wired once per button, remembered here by the button itself rather than
	# by a mark on it - a copied button carries the mark but not the wire.
	if not _look_wired.has(action.get_instance_id()):
		action.gui_input.connect(_on_action_gui_input.bind(action))
		_look_wired[action.get_instance_id()] = true
	if not looking:
		action.pressed.connect(func():
			controller.set_selected_skill(skill_key, spends_secondary)
			controller.begin_target_selection()
			)


func _empty_action(action: Button, skill_used: bool = true):
	# Pressable-looking or not by the same rule as a filled one, so an empty
	# slot does not stand out from its row; with nothing wired, pressing it
	# does nothing either way.
	var player_turn = controller.player_turn if controller != null else false
	var busy = controller != null and (controller.action_locked or not controller.is_idle())
	action.disabled = player_turn == false or skill_used or busy or is_viewing_other()
	action.icon = null
	action.tooltip_text = ""
	SkillLook.decorate(action, null)
	_gate_up(action, {}, null)
	var key_mark = action.get_node_or_null(HOTKEY_MARK)
	if key_mark != null:
		key_mark.visible = false
	clear_action_button_connections(action)
	action.set_meta(SKILL_META, "")


func _finish_action_panel():
	var player_turn = controller.player_turn if controller != null else false
	$Actions/EndTurnButton.disabled = !player_turn or is_viewing_other()


## --- Casting through a higher gate ---
##
## A spell can always be cast through a higher gate than its own once its own
## has run dry - a World spell through Hermes - and that spends the rarer
## casting. Worth knowing before pressing it rather than finding out from the
## counters afterwards, so the button says so: a small arrow and the paying
## gate's initial, in that gate's colour, in the corner.

const GATE_UP := "GateUp"


## Marks `action` if casting `skill` now would take a higher gate than its own,
## and takes the mark off otherwise. Returns the gate it would take, or 0.
func _gate_up(action: Button, comb: Dictionary, skill: SkillDefinition) -> int:
	var paying := 0
	if skill != null and not comb.is_empty() and combat != null and skill.spell_slot_level > 0 \
			and not combat.casts_without_gates(comb):
		var through = combat.slot_available_for(comb, skill.spell_slot_level)
		if through > skill.spell_slot_level:
			paying = through
	var mark: Label = action.get_node_or_null(GATE_UP)
	if paying == 0:
		if mark != null:
			mark.visible = false
		return 0
	if mark == null:
		mark = Label.new()
		mark.name = GATE_UP
		mark.add_theme_font_size_override("font_size", 11)
		mark.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		mark.add_theme_constant_override("outline_size", 4)
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		action.add_child(mark)
		mark.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		mark.offset_left = -30
		mark.offset_right = -3
		mark.offset_top = 0
		mark.offset_bottom = 16
	mark.text = "↑" + Stats.short_gate_name(paying).left(1)
	mark.add_theme_color_override("font_color", Stats.gate_colour(paying))
	mark.visible = true
	return paying


## --- The spell shelves ---

## The Spells panel, one shelf per gate, in place of the grid. See SpellShelves.
var _shelves: SpellShelves = null
## A clean copy of an action button, taken before anything was hung on the
## grid's, for the shelves to make theirs from.
var _slot_template: Button = null


func _build_shelves():
	var grid: GridContainer = $Actions/ActionsPanel/ActionsGrid
	_slot_template = grid.get_child(0).duplicate(0)
	# The grid can already have been filled by the time this runs - the battle
	# sets itself up around the HUD - and a copy carries whatever was on it:
	# a badge, a number, markers saying it was wired. None of it belongs on a
	# new button.
	for child in _slot_template.get_children():
		_slot_template.remove_child(child)
		child.free()
	for meta in _slot_template.get_meta_list():
		_slot_template.remove_meta(meta)
	SkillLook.decorate(_slot_template, null)
	_slot_template.icon = null
	_slot_template.tooltip_text = ""
	_shelves = SpellShelves.new()
	# Exactly the grid's size, so the panel does not change shape when the
	# switch is pressed; what does not fit scrolls.
	_shelves.custom_minimum_size = grid.get_combined_minimum_size()
	$Actions/ActionsPanel.add_child(_shelves)


## Whether the shelves are what the action panel is showing.
func showing_shelves() -> bool:
	return _shelves != null and _shelves.visible


func _set_shelved(on: bool):
	if _shelves == null:
		return
	_shelves.visible = on
	$Actions/ActionsPanel/ActionsGrid.visible = not on


func _fill_shelves(comb: Dictionary, spells: Array, used: bool, as_secondary: bool):
	_shelves.build(spells, comb, _slot_template, "%s/%s" % [comb.get("id", -1), as_secondary])
	var shown := _shelves.buttons()
	var keys := _shelves.keys()
	var tags := SkillLook.tags_for(keys.map(func(key): return SkillDatabase.skills[key]))
	for i in shown.size():
		if i < 9:
			_hotkey_mark(shown[i], i + 1)
		_fill_action(shown[i], keys[i], used, as_secondary, tags[i])
	_finish_action_panel()


## Every button the action panel is offering right now, in the order the keys
## 1-9 count them: the grid's slots, or the shelves' spells.
func action_buttons() -> Array:
	if showing_shelves():
		return _shelves.buttons()
	return $Actions/ActionsPanel/ActionsGrid.get_children()


## The gate counters beside the skill tabs: one tag per gate the one on show
## can cast through, with the castings left as dots. Hidden for anyone with no
## gates at all, so a swordsman's HUD isn't carrying empty gauges around - and
## while the spell shelves are up, which carry the same tags at their starts.
func _update_spell_slots(comb):
	var row = $Actions/SpellSlots
	if comb == null or comb.is_empty() or exploration_mode:
		row.visible = false
		return
	var slots = comb.get("spell_slots", [])
	var maximums = comb.get("max_spell_slots", [])
	var wanted := []
	for level in range(1, maximums.size()):
		if maximums[level] > 0:
			wanted.append(level)
	# Rebuilt only when the gates themselves change; otherwise each tag is told
	# its new count, so hovering one does not lose its tooltip every refresh.
	var have := row.get_children().filter(func(child): return child is GateTag).map(func(tag): return tag.level)
	if have != wanted:
		for child in row.get_children():
			row.remove_child(child)
			child.queue_free()
		for level in wanted:
			var tag := GateTag.new()
			tag.name = "Gate%d" % level
			row.add_child(tag)
	for tag in row.get_children():
		if tag is GateTag:
			var level: int = tag.level if tag.level > 0 else int(String(tag.name).trim_prefix("Gate"))
			tag.show_gate(level, slots[level] if level < slots.size() else 0, maximums[level] if level < maximums.size() else 0)
	row.visible = not wanted.is_empty() and not showing_shelves()


func clear_action_button_connections(action: Button):
	var connections = action.pressed.get_connections()
	for connection in connections:
		action.pressed.disconnect(connection.callable)


## Builds the full hover tooltip for a skill's action button: its name, the
## author-written description (if any), and an auto-generated stats summary
## read straight from the skill's actual data - so the numbers shown can
## never drift out of sync with what the skill really does.
## What a skill does, as the action panel says it.
##
## `in_the_hands_of` asks what it would be worth for somebody other than whoever
## is currently acting - which is what a character sheet wants, since the whole
## point of reading an enemy's sheet is knowing what *they* hit for rather than
## what you would hit for with their skill.
func build_skill_tooltip(skill: SkillDefinition, in_the_hands_of: Dictionary = {}) -> String:
	var was_subject = _tooltip_subject
	_tooltip_subject = in_the_hands_of
	var built = _build_skill_tooltip(skill)
	_tooltip_subject = was_subject
	return built


func _build_skill_tooltip(skill: SkillDefinition) -> String:
	var lines: Array[String] = [skill.name]
	if skill.description != "":
		lines.append(skill.description)
	lines.append("")
	if skill.spell_slot_level > 0:
		lines.append("Costs: %s, or any higher gate" % Stats.short_gate_name(skill.spell_slot_level))
	# Which of the two actions a turn gives you this spends. It decides
	# whether a skill can be used alongside another one, which is worth
	# knowing before choosing it rather than after.
	#
	# For a consumable it depends on who is holding it: somebody with
	# items_as_secondary - Cyrus - can spend a bottle from either slot, where
	# everybody else spends their main action on one. Reading the flag off the
	# skill alone told Cyrus his own bottles cost him his turn.
	#
	# "Main or Secondary" because either is true depending on what is left of
	# the turn; which one it actually takes is decided by
	# _consumable_spends_secondary, and it reaches for the secondary first.
	var action_slot = "Secondary" if skill.is_secondary else "Main"
	# And whose passive says so, when one does - so "or Secondary" on Cyrus's
	# Run is traced to Light Footed on his sheet rather than being a mystery.
	var holder := _caster()
	if not skill.is_secondary and combat != null and not holder.is_empty():
		var granted_by: PassiveDefinition = null
		if skill is ItemDefinition:
			granted_by = combat.items_as_secondary_from(holder)
			if granted_by == null and combat.items_as_secondary(holder):
				action_slot = "Main or Secondary"
		else:
			var key = SkillDatabase.skills.find_key(skill)
			granted_by = combat.secondary_grant_from(holder, key if key != null else "")
		if granted_by != null:
			action_slot = "Main, or Secondary through %s" % granted_by.name
	lines.append("Action: %s" % action_slot)
	lines.append("Range: %d-%d" % [skill.min_range, skill.max_range])
	if skill.uses_stat_contest:
		# A graze keeps the damage at half strength and drops everything else,
		# so a skill carrying no damage at all does nothing whatever to whoever
		# shrugs it off - and saying "half damage" of Blind names a number that
		# was never there.
		var hurts := false
		for contested in skill.all_effects():
			if contested != null and contested.type == EffectDefinition.EffectType.DAMAGE:
				hurts = true
		var beaten_by = "the caster's %s" % Stats.stat_name(_scaling_stat(skill))
		if skill is ItemDefinition:
			beaten_by = "%d" % skill.item_power
		lines.append("Lands on anyone with %s below %s. %s" % [
			Stats.stat_name(skill.contest_stat), beaten_by,
			"Everyone else takes half damage and none of the rest." if hurts
				else "Everyone else shrugs it off entirely."
		])
	else:
		lines.append("Hit chance: %d%%" % skill.accuracy)
	# Which attribute the numbers on this skill are worked out from, so the
	# panel says why the same Fireball is worth more in one pair of hands than
	# another - and which stat to raise if you want it to hurt more.
	#
	# Only when something on it actually scales: every skill carries a scaling
	# stat whether it uses one or not, so Blind and Stealth would otherwise
	# advertise a Mystic that does nothing for them.
	if _scales_off_the_caster(skill):
		var moved_by = _scaling_moved_by()
		lines.append("Scales with: %s%s" % [Stats.stat_name(_scaling_stat(skill)),
			", through %s" % moved_by.name if moved_by != null else ""])
	lines.append("Targets: %s" % ("Everyone caught in it" if skill.affects_both_sides else ("Allies" if skill.targets_ally else "Enemies")))
	if skill.aoe_radius > 0:
		lines.append("Area: %s" % describe_aoe_shape(skill))
	if skill.respects_blocking:
		lines.append("Requires a clear line of sight")
	if skill.is_reactive:
		lines.append("Reactive: triggers automatically if a valid target leaves its range on their turn")
	if skill.all_effects().size() > 0:
		lines.append("")
		lines.append("Effects:")
		for effect in skill.all_effects():
			var line = "- " + describe_effect(effect, skill)
			if effect.applies_to_caster:
				# Otherwise a skill aimed at an enemy reads as though the buff
				# on the end of it lands on them.
				line += " (on yourself)"
			lines.append(line)
	return "\n".join(lines)


## Whether any of `skill`'s numbers are worked out from the caster's scaling
## stat - damage, a heal, a tick, or the slam at the end of a shove.
##
## An item never does: what is written on the bottle is what it is worth
## whoever uncorks it, which is why ItemDefinition hides the field entirely.
func _scales_off_the_caster(skill: SkillDefinition) -> bool:
	if skill == null or skill is ItemDefinition:
		return false
	for effect in skill.all_effects():
		if effect == null:
			continue
		match effect.type:
			EffectDefinition.EffectType.DAMAGE, \
					EffectDefinition.EffectType.HEAL, \
					EffectDefinition.EffectType.DAMAGE_OVER_TIME:
				return true
			EffectDefinition.EffectType.PUSH:
				# A shove that does not hurt is just a shove.
				if effect.damage_modifier > 0.0:
					return true
			EffectDefinition.EffectType.CONDITION:
				# Stunned and Blinded burn nobody; Burn and Poisoned do, and
				# what they tick for comes off whoever inflicted them.
				if effect.condition_dot_strength() > 0.0:
					return true
	return false


func describe_aoe_shape(skill: SkillDefinition) -> String:
	match skill.aoe_shape:
		SkillDefinition.AoEShape.LINE:
			return "Line, length %d, width %d" % [skill.aoe_radius, skill.aoe_width]
		SkillDefinition.AoEShape.CONE:
			return "Cone, length %d" % skill.aoe_radius
		_:
			return "Radius %d" % skill.aoe_radius


func describe_effect(effect: EffectDefinition, skill: SkillDefinition = null) -> String:
	match effect.type:
		EffectDefinition.EffectType.DAMAGE:
			# What it will actually take off, worked out against the enemies
			# standing on the board - "Intellect x1.5" is the rule behind the
			# number, and the number is what the decision is made on.
			# What the skill is worth before any defence is taken off it. It
			# used to be worked out against every enemy on the board and shown
			# as the spread, which read as the skill rolling dice rather than
			# as the targets differing.
			# Turned on the caster, the target is settled - their defence and
			# their resistance are both known - so the panel says what it will
			# cost rather than what it is worth. "Base" is dropped, because it
			# is the word that promises a figure still to be soaked.
			if effect.applies_to_caster:
				var on_self = _damage_to_self(skill, effect)
				if on_self >= 0:
					return "Damage: %d %s" % [on_self, Damage.type_name(effect.damage_type).to_lower()]
			var swing = _base_damage(skill)
			if swing >= 0:
				return "Base Damage: %d %s" % [swing, Damage.type_name(effect.damage_type).to_lower()]
			return "Base Damage: %s" % Damage.type_name(effect.damage_type).to_lower()
		EffectDefinition.EffectType.HEAL:
			# Reads like the damage line, because it is worked out the same way.
			var mended = _heal_amount(skill, effect)
			if mended >= 0:
				return "Heal: %d" % mended
			return "Heal: %d-%d" % [effect.min_amount, effect.max_amount]
		EffectDefinition.EffectType.STAT_MODIFIER:
			var sign_str = "+" if effect.modifier_amount >= 0 else ""
			return "%s%d %s for %d turn(s)" % [sign_str, effect.modifier_amount, effect.stat, effect.duration]
		EffectDefinition.EffectType.UPGRADE_ELEMENT:
			# Named rather than described in the abstract, because "the upgraded
			# form" means nothing until you know fire becomes plasma.
			var pairs: Array = []
			for base in Damage.UPGRADES:
				pairs.append("%s to %s" % [Damage.type_name(base),
					Damage.type_name(Damage.UPGRADES[base])])
			return "Raises the element of their next damaging spell (%s), for %d turn(s)" % [
				", ".join(pairs), effect.duration]
		EffectDefinition.EffectType.RESISTANCE:
			var harder = effect.modifier_amount > 0
			return "%s %s resistance by %d%% for %d turn(s)" % [
				"Raises" if harder else "Lowers",
				Damage.type_name(effect.damage_type).to_lower(),
				absi(effect.modifier_amount), effect.duration
			]
		EffectDefinition.EffectType.MOVEMENT_CLASS:
			var moving_as = Stats.movement_class_name(effect.movement_class).to_lower()
			if effect.movement_class == 1:
				return "Moves as flying for %d turn(s): over what blocks a walker, and across rough ground as though it were flat" % effect.duration
			return "Moves as %s for %d turn(s)" % [moving_as, effect.duration]
		EffectDefinition.EffectType.DAMAGE_OVER_TIME:
			# Per turn and in total, because a wound that ticks for 6 over 4 turns
			# is a different decision from one that ticks for 20 once.
			var ticks = _tick_figure(skill, effect.damage_type, effect.damage_modifier,
				effect.applies_to_caster)
			if ticks >= 0:
				return "Damage over time: %s%d %s a turn for %d turn(s)" % [
					"" if effect.applies_to_caster else "base ",
					ticks, Damage.type_name(effect.damage_type).to_lower(), effect.duration
				]
			return "Damage over time: %d-%d %s for %d turn(s)" % [
				effect.min_amount, effect.max_amount, Damage.type_name(effect.damage_type).to_lower(), effect.duration
			]
		EffectDefinition.EffectType.DISPEL:
			var scope_str = "all"
			if effect.dispel_scope == EffectDefinition.DispelScope.BUFFS_ONLY:
				scope_str = "buff"
			elif effect.dispel_scope == EffectDefinition.DispelScope.DEBUFFS_ONLY:
				scope_str = "debuff"
			var stat_str = effect.dispel_stat if effect.dispel_stat != "" else "all"
			return "Dispels %s %s effects" % [scope_str, stat_str]
		EffectDefinition.EffectType.CONDITION:
			if effect.condition == null:
				return "Inflicts a condition (none assigned)"
			# The skill's own duration when it sets one, so the tooltip says what
			# this skill actually lands rather than what the condition says on
			# its own - those are allowed to differ now.
			var turns = effect.condition_duration if effect.condition_duration > 0 else effect.condition.duration
			# A condition describes itself in words - "a strong DOT" - which says
			# how it compares to other conditions but not what it costs you here.
			# The number belongs beside it, worked out from whoever is holding
			# the skill, the same way the skill's own damage line is.
			var says = effect.condition.describe()
			var burning = _condition_tick(effect, skill)
			if burning != "":
				says += " (%s)" % burning
			return "Inflicts %s for %d turn(s): %s" % [
				effect.condition.display_name, turns, says
			]
		EffectDefinition.EffectType.PUSH:
			# A collision is worked out from the shover now, the same as any
			# other hit, so it is quoted the same way: the base figure, before
			# whoever lands takes their defence and resistances off it. It used
			# to print the effect's own min-max pair, which since the change is
			# only the fallback for a shove with no skill behind it - and a
			# skill quoting its fallback is quoting a number it will not use.
			var push_str = "Pushes target back %d tile(s)" % effect.knockback_distance
			# Not only a wall: a shove stopped by another body hurts them both,
			# and the map edge counts too.
			var slam = _collision_damage(skill, effect)
			if slam > 0:
				push_str += ", for a base %d %s on collision" % [
					slam, Damage.type_name(effect.damage_type).to_lower()]
			elif effect.max_amount > 0:
				push_str += ", dealing %d-%d damage on collision" % [effect.min_amount, effect.max_amount]
			return push_str
		EffectDefinition.EffectType.PULL:
			return "Pulls target towards caster, up to %d tile(s)" % effect.knockback_distance
		# These three had no words at all, so Run, Guard, Stealth and Study ended
		# their previews on a bare "-".
		EffectDefinition.EffectType.STAT_MULTIPLIER:
			# "x2" rather than the "x2.0" a float prints as.
			var times = effect.stat_multiplier
			var shown = str(int(times)) if is_equal_approx(times, roundf(times)) else str(times)
			return "x%s %s for %d turn(s)" % [shown, effect.stat, effect.duration]
		EffectDefinition.EffectType.HIDE:
			return "Slips out of sight, if no enemy can see them - until one can"
		EffectDefinition.EffectType.REVEAL:
			return "Lays their character sheet open to you for the rest of the battle"
	return ""


func update_combatants(combatants: Array):
	for comb in combatants:
		var effective_max_hp = combat.get_effective_stat(comb, "max_hp")
		if comb.side == 0:
			var status = _icon_for($Status, comb)
			if status != null:
				status.set_health(comb.hp, effective_max_hp)
				_refresh_conditions(status, comb)
		if comb.side == 0 and not exploration_mode and shown_combatant() == comb:
			# The big portrait beside the skill panel belongs to whoever is
			# acting, and used to be written only on a turn change - so healing
			# or being hurt during your own turn left it showing the health you
			# started with, while the party portraits beside it told the truth.
			$Actions/StatusIcon.set_health(comb.hp, effective_max_hp)
		var turn_queue_icon = _icon_for($TurnQueue/Queue, comb)
		if turn_queue_icon != null:
			turn_queue_icon.tooltip_text = _queue_tip(comb)
			_refresh_conditions(turn_queue_icon, comb)
			turn_queue_icon.set_max_hp(effective_max_hp)
			turn_queue_icon.set_hp(comb.hp)
			# Order matters: set_current works out the border colour, so it has
			# to run before anything reads it.
			turn_queue_icon.set_current(combat.get_current_combatant() == comb, comb.side)
			turn_queue_icon.set_turn_taken(comb.turn_taken)


func set_movement(movement):
	$Actions/Movement.text = "Move %d" % movement


## While a skill is being aimed, everything but the party portraits and the
## turn queue gets out of the way, so the map - and the skill's range and area
## preview drawn on it - is unobstructed. The Actions cluster carries the skill
## buttons, movement counter, End Turn and message log, so hiding it as a whole
## clears all of them at once.
##
## The banner goes too. It is only ever given text by deployment and by
## exploration, so aiming a skill brought it back still reading "Click a hero,
## then a highlighted tile to move them there" - advice for a step that ended
## before the battle started.
func _set_aiming(aiming: bool):
	$Actions.visible = true
	for child in $Actions.get_children():
		child.visible = not aiming
	if aiming and _looking_only():
		# Only a look: say so, since nothing on the map does.
		var caster: Dictionary = controller.aiming_caster()
		var skill: SkillDefinition = SkillDatabase.skills.get(controller._selected_skill)
		$Actions/SelectTargetMessage/MarginContainer/Label.text = "Just looking at %s's %s - Esc or right-click to stop" % [
			caster.get("name", "?"), skill.name if skill != null else "skill"]
		$Actions/SelectTargetMessage.visible = true
	if not aiming:
		# Restore whatever the current mode says these should be, rather than
		# blanket-showing things the mode had deliberately hidden.
		$Actions/Movement.visible = not exploration_mode
		$Actions/EndTurnButton.visible = not exploration_mode
		$Actions/SkillPanelTabs.visible = not exploration_mode
		# Back to saying whose HUD is on show, if it is somebody else's - a look
		# can be taken at a teammate's skill while viewing them.
		if is_viewing_other():
			$Actions/SelectTargetMessage/MarginContainer/Label.text = "Looking at %s - Esc to go back" % _viewing.name
			$Actions/SelectTargetMessage.visible = true
		else:
			$Actions/SelectTargetMessage.visible = false
		# The slot row hides itself for anyone with no slots, so it can't just
		# be switched back on with the rest.
		_update_spell_slots(shown_combatant() if combat != null and not exploration_mode else null)
		# Nor can the log, if the player folded it away before aiming.
		_apply_log_state()
		# Nor Undo Move, which is only there once somebody has walked.
		_refresh_undo()
		# Nor Spells, which is only there for somebody who casts something -
		# switched back on with the rest, it offered a swordsman a button that
		# vanished the moment it was pressed.
		_refresh_spells_toggle(shown_combatant())
		if _pips != null and combat != null and not exploration_mode:
			_pips.show_for(shown_combatant(), combat)
		if _deployment_mode:
			# Still placing the party - the cluster stays out of the way.
			_apply_deployment_visibility()


func _target_selection_finished():
	hide_hit_preview()
	_set_aiming(false)


func _target_selection_started():
	_set_aiming(true)


## --- What a hit will do, while aiming ---
##
## Beside the cursor while a skill is being aimed: everyone the aim would catch,
## what it would do to each of them if it connects - after their own defence and
## resistance - and, for a contested skill, whose number wins, and so whether it
## lands in full or is shrugged off to half its damage and nothing else. The
## figures come from Combat.predict_hit, which takes the same steps the hit
## itself will, so the prompt and the log afterwards agree.

## Out of the cursor's way, below and to the right of it.
const HIT_PREVIEW_OFFSET := Vector2(24, 24)
const HIT_PREVIEW_ENEMY := Color("e08a8a")
const HIT_PREVIEW_ALLY := Color("7fe08a")
const HIT_PREVIEW_WINS := Color("dce8f5")
const HIT_PREVIEW_LOSES := Color("c8913f")

var _hit_preview: PanelContainer = null
var _hit_rows: VBoxContainer = null


func _build_hit_preview():
	_hit_preview = PanelContainer.new()
	_hit_preview.name = "HitPreview"
	# Dressed as a tooltip, since it is one - it just cannot wait for a hover.
	_hit_preview.theme_type_variation = &"TooltipPanel"
	_hit_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hit_preview.visible = false
	_hit_rows = VBoxContainer.new()
	_hit_rows.add_theme_constant_override("separation", 6)
	_hit_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hit_preview.add_child(_hit_rows)
	add_child(_hit_preview)


## Shows what `skill_key`, aimed at `aim` by whoever is acting, would do to
## everyone it would catch. Hidden when it would catch nobody.
func show_hit_preview(skill_key: String, aim: Vector2i):
	if combat == null or exploration_mode or not SkillDatabase.skills.has(skill_key):
		hide_hit_preview()
		return
	if _hit_preview == null:
		_build_hit_preview()
	# From whoever the aim is from: the one acting, or the teammate whose skill
	# is only being looked at - it is their reach and their numbers.
	var caster = controller.aiming_caster() if controller != null and controller.has_method("aiming_caster") \
			else combat.get_current_combatant()
	var skill: SkillDefinition = SkillDatabase.skills[skill_key]
	var targets = combat.targets_if_aimed(caster, skill, aim)
	if targets.is_empty():
		hide_hit_preview()
		return
	for row in _hit_rows.get_children():
		_hit_rows.remove_child(row)
		row.queue_free()
	var heading := _hit_label(skill.name, 13, TAB_OFF)
	_hit_rows.add_child(heading)
	if _looking_only():
		_hit_rows.add_child(_hit_label("%s's - just looking, can't be used now" % caster.name, 12, TAB_OFF))
	_clear_ghosts()
	for target in targets:
		var hit = combat.predict_hit(caster, target, skill)
		_hit_rows.add_child(_hit_row(caster, target, skill, hit))
		_show_ghost(target, int(hit.heal) - int(hit.damage))
	_hit_preview.visible = true
	_hit_preview.reset_size()
	_place_hit_preview()


func hide_hit_preview():
	if _hit_preview != null:
		_hit_preview.visible = false
	_clear_ghosts()


## Keeps the prompt beside the cursor, and on the screen: it flips to the other
## side of the cursor rather than running off an edge.
func _place_hit_preview():
	var screen = get_viewport_rect().size
	var mouse = get_viewport().get_mouse_position()
	var size = _hit_preview.get_combined_minimum_size()
	var at = mouse + HIT_PREVIEW_OFFSET
	if at.x + size.x > screen.x:
		at.x = mouse.x - HIT_PREVIEW_OFFSET.x - size.x
	if at.y + size.y > screen.y:
		at.y = mouse.y - HIT_PREVIEW_OFFSET.y - size.y
	_hit_preview.global_position = at.clamp(Vector2.ZERO, (screen - size).max(Vector2.ZERO))


## One target: who, what it does to them, and - for a contest - how it goes.
func _hit_row(caster: Dictionary, target: Dictionary, skill: SkillDefinition, hit: Dictionary) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var side_colour = HIT_PREVIEW_ALLY if target.side == caster.side else HIT_PREVIEW_ENEMY
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(_hit_label(target.name, 15, side_colour))
	line.add_child(_hit_label(_what_it_does(hit), 15, HIT_PREVIEW_WINS))
	row.add_child(line)
	if hit.contested:
		var verdict: String
		if hit.wins:
			verdict = "lands in full"
		elif hit.deals_damage:
			verdict = "shrugged off - half damage, nothing else"
		else:
			verdict = "shrugged off - nothing lands"
		# Whose number is whose: the caster's own attribute, or the bottle's
		# power for a thrown item, which owes nothing to the thrower.
		var ours = hit.our_stat_name if skill is ItemDefinition else "your " + hit.our_stat_name
		row.add_child(_hit_label("Their %s %d vs %s %d: %s" % [
			hit.their_stat_name, hit.their_stat, ours, hit.our_stat, verdict],
			12, HIT_PREVIEW_WINS if hit.wins else HIT_PREVIEW_LOSES))
		if not hit.wins and not hit.dropped.is_empty():
			row.add_child(_hit_label("Loses: %s" % ", ".join(hit.dropped), 12, HIT_PREVIEW_LOSES))
	elif hit.hit_chance < 100:
		row.add_child(_hit_label("%d%% to hit" % hit.hit_chance, 12, TAB_OFF))
	return row


## The headline for one target: damage, a heal, or what else lands.
func _what_it_does(hit: Dictionary) -> String:
	var parts := []
	if hit.deals_damage:
		parts.append("%d damage%s" % [hit.damage, " - lethal" if hit.lethal else ""])
	if hit.heal > 0:
		parts.append("heals %d" % hit.heal)
	if not hit.also.is_empty():
		parts.append("+ " + ", ".join(hit.also))
	if parts.is_empty():
		return "no damage"
	return "  ".join(parts)


func _hit_label(text: String, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## --- What a skill will actually do ---
##
## The tooltip used to print the rule behind a number - "Intellect x1.5" - and
## leave the arithmetic to the player. These work the number out instead, from
## whoever's turn it is against the enemies actually standing on the board, so
## what the tooltip promises is what the log will report.


## Whoever is choosing a skill right now, or an empty dictionary out of battle.
## Whose hands a tooltip is being worked out for, when it is not the hands of
## whoever is acting. Set only for the length of one build_skill_tooltip call -
## see build_skill_tooltip's `in_the_hands_of`.
var _tooltip_subject: Dictionary = {}


func _caster() -> Dictionary:
	if not _tooltip_subject.is_empty():
		return _tooltip_subject
	if combat == null or not combat.has_method("get_current_combatant"):
		return {}
	var current = combat.get_current_combatant()
	return current if current != null else {}


## The attribute `skill` is worked out from in the hands the tooltip is for -
## its own, unless a passive of theirs says otherwise.
func _scaling_stat(skill: SkillDefinition) -> int:
	var caster = _caster()
	if caster.is_empty() or combat == null or not combat.has_method("scaling_stat_of"):
		return skill.scaling_stat
	return combat.scaling_stat_of(caster, skill)


## The passive putting every skill in those hands on one stat, or null.
func _scaling_moved_by() -> PassiveDefinition:
	var caster = _caster()
	if caster.is_empty() or combat == null or not combat.has_method("scaling_stat_from"):
		return null
	return combat.scaling_stat_from(caster)


## What `skill` swings for in the hands of whoever is acting, before the target
## on the other end of it soaks any. -1 with nobody to ask.
func _base_damage(skill: SkillDefinition) -> int:
	var caster = _caster()
	if skill == null or caster.is_empty() or not combat.has_method("base_skill_damage"):
		return -1
	return combat.base_skill_damage(caster, skill)


## What one tick of a lingering effect is worth, as a number. -1 when there is
## nothing to scale off, which is an item's condition and says to fall back to
## the flat range written on it.
##
## Aimed at somebody else this is the BASE figure, before their defence and
## resistance take their share - the same promise the Base Damage line above it
## makes, and the only honest one while who it lands on is still unsettled. It
## used to be worked out against whichever enemies happened to be standing
## about and shown as a spread, which read as the tick rolling dice rather than
## as the targets differing.
##
## Turned on the caster the target IS settled - Trailblaze sets its own caster
## alight - so there the real figure is known and is what gets shown.
func _tick_figure(skill: SkillDefinition, damage_type: int, modifier: float, on_self: bool) -> int:
	var caster = _caster()
	if skill == null or caster.is_empty():
		return -1
	var base = combat.dot_base_damage(caster, skill, modifier)
	if base <= 0.0:
		return -1
	if on_self:
		return combat.resisted_damage(caster, damage_type, combat.dot_tick(caster, base, 0, 0))
	return maxi(roundi(base), 0)


## What a collision from this skill is worth in the hands of whoever is acting,
## before the one who lands soaks it. -1 with nobody to ask, and 0 for a shove
## that does not hurt.
func _collision_damage(skill: SkillDefinition, effect: EffectDefinition) -> int:
	var caster = _caster()
	if skill == null or caster.is_empty() or not combat.has_method("collision_impact"):
		return -1
	return combat.collision_impact(caster, effect, skill)


## What a hit this skill turns on its own caster would actually take off them,
## defence and resistance and all. -1 with nobody to ask.
func _damage_to_self(skill: SkillDefinition, effect: EffectDefinition) -> int:
	var caster = _caster()
	if skill == null or caster.is_empty() or not combat.has_method("skill_damage"):
		return -1
	# The same two steps do_damage takes, in the same order.
	var raw = combat.skill_damage(caster, caster, skill)
	return combat.resisted_damage(caster, effect.damage_type, raw)


## What one tick of `condition` would take off whoever is standing opposite,
## inflicted by `skill` in the hands of whoever is acting. Empty for a condition
## that does not burn at all.
func _condition_tick(effect: EffectDefinition, skill: SkillDefinition) -> String:
	var condition: ConditionDefinition = effect.condition
	if condition == null:
		return ""
	var flavour = Damage.type_name(condition.dot_type).to_lower()
	# The effect's own strength when it sets one, so the preview shows what THIS
	# skill's version of the condition costs rather than the condition's.
	var ticks = _tick_figure(skill, condition.dot_type, effect.condition_dot_strength(),
		effect.applies_to_caster)
	if ticks >= 0:
		return "%s%d %s damage a turn" % [
			"" if effect.applies_to_caster else "base ", ticks, flavour]
	# Nothing to scale off at all - a condition applied by hand, with no skill
	# and no item behind it - falls back to the range written on the condition.
	if condition.dot_max > 0:
		return "%d-%d %s damage a turn" % [condition.dot_min, condition.dot_max, flavour]
	return ""


## What a heal from whoever is acting would restore, or -1 with nobody to ask.
func _heal_amount(skill: SkillDefinition, effect: EffectDefinition = null) -> int:
	var caster = _caster()
	if skill == null or caster.is_empty() or not combat.has_method("heal_amount"):
		return -1
	# The effect goes with it, because a heal can carry its own dial - the
	# panel showing the skill's instead would promise the wrong number on
	# anything that both cuts and mends.
	return combat.heal_amount(caster, skill, effect)


## --- What is currently on somebody ---


## Hangs a strip of condition marks on `holder` and keeps it in step with what
## `comb` is actually suffering. Built on demand rather than in the scene, since
## the portraits and queue icons are themselves built on demand.
##
## `where` is a layout preset: the party portraits carry theirs beside the face,
## the turn queue underneath it, which is where there is room in each.
## Marks under a face in the turn queue: small enough that three sit side by
## side within the face's own width, then onto the next line.
const QUEUE_MARK_SIZE := Vector2(14, 14)
const QUEUE_MARK_COLUMNS := 3
## Beside a party portrait there is room to the right, but not the whole map's
## worth: four across, then down.
const PORTRAIT_MARK_COLUMNS := 4


func _refresh_conditions(holder: Control, comb: Dictionary):
	# A party portrait keeps its face under Layout; a queue face is the face.
	var anchor: Control = holder.get_node_or_null("Layout/Icon")
	if anchor == null:
		anchor = holder.get_node_or_null("Icon")
	if anchor == null:
		anchor = holder
	var strip: ConditionStrip = anchor.get_node_or_null("Conditions")
	if strip == null:
		strip = ConditionStrip.new()
		strip.name = "Conditions"
		strip.mouse_filter = Control.MOUSE_FILTER_PASS
		# Where the face is decides where its marks go - not whose side they are
		# on. A party member's face in the queue used to take the party column's
		# placement, beside it, and so sat on top of the next face along.
		var in_queue = holder.get_parent() == $TurnQueue/Queue
		strip.set_meta("in_queue", in_queue)
		if in_queue:
			strip.mark_size = QUEUE_MARK_SIZE
			strip.columns = QUEUE_MARK_COLUMNS
		else:
			strip.columns = PORTRAIT_MARK_COLUMNS
		anchor.add_child(strip)
	strip.show_for(comb, combat)
	_place_strip(strip)


## Pins the strip to its face at exactly the size its marks need, every time
## they change. Left to grow on its own it never shrank back when a condition
## wore off, and the marks left behind sat off to one side.
func _place_strip(strip: ConditionStrip):
	var need := strip.get_combined_minimum_size()
	if strip.get_meta("in_queue", false):
		# Under the face, centred on it, a line at a time downwards.
		strip.anchor_left = 0.5
		strip.anchor_right = 0.5
		strip.anchor_top = 1.0
		strip.anchor_bottom = 1.0
		strip.offset_left = -need.x * 0.5
		strip.offset_right = need.x * 0.5
		strip.offset_top = 4.0
		strip.offset_bottom = 4.0 + need.y
		# The face acting now is drawn larger; its marks stay everybody else's
		# size, or they grow out past it and under the next face.
		strip.pivot_offset = Vector2(need.x * 0.5, 0.0)
		var face_scale: Vector2 = strip.get_parent().scale
		strip.scale = Vector2.ONE / face_scale if face_scale.x > 0.0 else Vector2.ONE
	else:
		# Beside the portrait, centred on it top to bottom.
		strip.anchor_left = 1.0
		strip.anchor_right = 1.0
		strip.anchor_top = 0.5
		strip.anchor_bottom = 0.5
		strip.offset_left = 8.0
		strip.offset_right = 8.0 + need.x
		strip.offset_top = -need.y * 0.5
		strip.offset_bottom = need.y * 0.5
