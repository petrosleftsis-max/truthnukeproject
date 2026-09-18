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
enum SkillPanel { MAIN, SECONDARY, SPELLS, ITEMS }

## Reset to MAIN whenever the turn passes to someone new, so a turn always
## starts on the panel you'd expect.
var showing_panel := SkillPanel.MAIN

## Kept for anything still asking the old question. A spell is spent from the
## main slot unless it is also marked secondary, so "is this the secondary
## panel" is no longer the same question as "which slot will this spend".
var showing_secondary: bool:
	get: return showing_panel == SkillPanel.SECONDARY

const PANEL_NAMES := {
	SkillPanel.MAIN: "Main Skills",
	SkillPanel.SECONDARY: "Secondary Skills",
	SkillPanel.SPELLS: "Spells",
	SkillPanel.ITEMS: "Consumables",
}

## The node name of each panel's button, in enum order.
const PANEL_TABS := {
	SkillPanel.MAIN: "MainTab",
	SkillPanel.SECONDARY: "SecondaryTab",
	SkillPanel.SPELLS: "SpellsTab",
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


func _ready():
	for panel in PANEL_TABS:
		var tab := _tab(panel)
		if tab != null:
			tab.pressed.connect(set_skill_panel.bind(panel))
	var toggle = $Actions.get_node_or_null("LogToggle")
	if toggle != null:
		toggle.pressed.connect(toggle_log)
	_apply_log_state()
	# Things that happen to the party rather than in a fight - an item changing
	# hands, somebody joining or leaving - are announced by Campaign, which is
	# the one thing on screen in a battle and on a map alike.
	if not Campaign.announced.is_connected(update_information):
		Campaign.announced.connect(update_information)


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


func _tab(panel: int) -> Button:
	return $Actions/SkillPanelTabs.get_node_or_null(PANEL_TABS[panel]) as Button


## Switches which list the action panel is showing. A button per panel rather
## than one that cycles: with three of them, cycling meant pressing twice to
## reach the last one and remembering the order to know which press got you
## there. Three buttons say where you can go and which one you are on.
func set_skill_panel(panel: int):
	showing_panel = panel
	$Actions/SkillPanelLabel.text = PANEL_NAMES[showing_panel]
	for other in PANEL_TABS:
		var tab := _tab(other)
		if tab == null:
			continue
		var selected = other == showing_panel
		tab.add_theme_color_override("font_color", TAB_ON if selected else TAB_OFF)
		tab.add_theme_color_override("font_hover_color", TAB_ON)
		tab.button_pressed = selected
	if combat != null and not exploration_mode:
		_show_skills_for(combat.get_current_combatant())


## Hides the Spells tab for anyone who casts nothing, so a swordsman is not
## offered a panel that can only ever be empty. Main and Secondary always
## stand: both are action slots everybody has, and an empty one is worth
## seeing as empty.
func _refresh_tabs(comb):
	var known = combat != null and comb != null and not comb.is_empty()
	var spells_tab := _tab(SkillPanel.SPELLS)
	if spells_tab != null:
		var has_spells = known and not combat.spell_skills_of(comb).is_empty()
		spells_tab.visible = has_spells
		if not has_spells and showing_panel == SkillPanel.SPELLS:
			set_skill_panel(SkillPanel.MAIN)
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
		set_skill_list([], true)
		_update_spell_slots(null)
		return
	_update_spell_slots(comb)
	_refresh_tabs(comb)
	var list = []
	var used = false
	match showing_panel:
		SkillPanel.SECONDARY:
			list = combat.secondary_skills_of(comb)
			used = comb.get("secondary_used_this_turn", false)
		SkillPanel.SPELLS:
			list = combat.spell_skills_of(comb)
			# A spell spends whichever slot its own is_secondary says, so the
			# panel is only fully spent once both are gone.
			used = comb.get("skill_used_this_turn", false) and comb.get("secondary_used_this_turn", false)
		SkillPanel.ITEMS:
			list = combat.items_of(comb)
			# Same as the spells: which slot a consumable costs is the item's
			# own business, so the panel dies only when both slots have gone.
			used = comb.get("skill_used_this_turn", false) and comb.get("secondary_used_this_turn", false)
		_:
			list = combat.main_skills_of(comb)
			used = comb.get("skill_used_this_turn", false)
	set_skill_list(list, used, showing_panel == SkillPanel.SECONDARY)


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
	$Actions/SkillPanelLabel.visible = not enabled
	$Actions/SkillPanelTabs.visible = not enabled
	if enabled:
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
		new_status.set_health(member.hp, member.max_hp)
		new_status.name = member.name
		new_status.modulate = Color.WHITE if member.is_leader else Color(0.62, 0.62, 0.62)
	if members.is_empty():
		return
	$Actions/StatusIcon.set_icon(members[0].icon)
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


func update_turn_queue(combatants: Array, turn_queue: Array):
	for c in turn_queue:
		var comb = combatants[c]
		add_turn_queue_icon(comb)


func combatant_died(combatant):
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


func show_combatant_status_main(comb: Dictionary):
	if comb.side == 0:
		$Actions/StatusIcon.set_icon(comb.icon)
		$Actions/StatusIcon.set_health(comb.hp, combat.get_effective_stat(comb, "max_hp"))
	# A new turn always opens on the main panel.
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
		$Actions/SelectTargetMessage/MarginContainer/Label.text = "Click a hero, then a highlighted tile to move them there."
		lock_action_buttons()
		$Actions/EndTurnButton.disabled = false
		_apply_deployment_visibility()
	else:
		# Put back everything deployment tucked away, then let the normal rules
		# for whoever is acting decide what is actually pressable.
		_set_aiming(false)
		refresh_action_buttons()


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
	if not comb.get("items_as_secondary", false):
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
	# There is no CController while exploring - no turn is in progress and
	# nothing could resolve a skill - so every action button stays disabled.
	var player_turn = controller.player_turn if controller != null else false
	# Nothing may be picked while a combatant is walking or an animation is
	# resolving: the turn's state is mid-change, and the skill would be aimed
	# from wherever they happened to be standing at the time.
	var busy = controller != null and (controller.action_locked or not controller.is_idle())
	var comb = combat.get_current_combatant() if combat != null and not exploration_mode else {}
	for i in range(actions_grid_children.size()):
		var action = actions_grid_children[i] as Button
		if player_turn == false or skill_used or busy:
			action.disabled = true
		else:
			action.disabled = false
		if skill_list.size() > i:
			var skill_key = skill_list[i]
			var skill = SkillDatabase.skills[skill_key]
			# On the Spells panel each entry decides its own slot, since a
			# spell marked secondary is cast from the secondary action while
			# the rest are cast from the main one.
			var spends_secondary = as_secondary
			if showing_panel == SkillPanel.SPELLS:
				spends_secondary = skill.is_secondary
			elif showing_panel == SkillPanel.ITEMS:
				spends_secondary = _consumable_spends_secondary(comb, skill)
			if showing_panel in [SkillPanel.SPELLS, SkillPanel.ITEMS] and not comb.is_empty() and not action.disabled:
				var slot_spent = comb.get("secondary_used_this_turn", false) if spends_secondary else comb.get("skill_used_this_turn", false)
				# Greyed out for the two separate reasons a spell can be
				# unavailable: the action is gone, or the slots are.
				action.disabled = slot_spent or not combat.can_afford_skill(comb, skill)
			action.icon = skill.icon
			action.tooltip_text = build_skill_tooltip(skill)
			clear_action_button_connections(action)
			action.pressed.connect(func():
				controller.set_selected_skill(skill_key, spends_secondary)
				controller.begin_target_selection()
				)
		else:
			action.icon = null
			action.tooltip_text = ""
			clear_action_button_connections(action)
	$Actions/EndTurnButton.disabled = !player_turn


## Spell slots for whoever's turn it is: one bar per level, each with the
## number left over how many the battle started with. Hidden entirely for
## anyone with no slots at all, so a swordsman's HUD isn't carrying three empty
## gauges around.
func _update_spell_slots(comb):
	var row = $Actions/SpellSlots
	if comb == null or comb.is_empty() or exploration_mode:
		row.visible = false
		return
	var slots = comb.get("spell_slots", [])
	var maximums = comb.get("max_spell_slots", [])
	var any = false
	for level in range(1, 4):
		var ceiling = maximums[level] if level < maximums.size() else 0
		var entry = row.get_node("Level%d" % level)
		entry.visible = ceiling > 0
		if ceiling <= 0:
			continue
		any = true
		var left = slots[level] if level < slots.size() else 0
		var bar: ProgressBar = entry.get_node("Bar")
		bar.max_value = ceiling
		bar.value = left
		entry.get_node("Count").text = "%d/%d" % [left, ceiling]
		# Named rather than numbered: a spell is cast through a gate, and the
		# tooltip says which even where the row is too narrow to spell it out.
		entry.get_node("Name").text = Stats.gate_name(level)
		entry.tooltip_text = "%s: %d of %d left" % [Stats.gate_name(level), left, ceiling]
	row.visible = any


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
		lines.append("Costs: %s, or any higher gate" % Stats.gate_name(skill.spell_slot_level))
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
	if skill is ItemDefinition and not skill.is_secondary 		and _caster().get("items_as_secondary", false):
		action_slot = "Main or Secondary"
	lines.append("Action: %s" % action_slot)
	lines.append("Range: %d-%d" % [skill.min_range, skill.max_range])
	if skill.uses_stat_contest:
		lines.append("Lands on anyone with %s below the caster's %s. Everyone else takes half damage and none of the rest." % [
			Stats.stat_name(skill.contest_stat), Stats.stat_name(skill.scaling_stat)
		])
	else:
		lines.append("Hit chance: %d%%" % skill.accuracy)
		if combat.STUDIED_ACCURACY_BONUS > 0 and _reveals(skill):
			# Said once, on the action that earns it, rather than repeated on
			# every move in the game - where it was a line of small print on
			# thirty tooltips explaining a rule that belongs to one of them.
			lines.append("This character has +%d%% accuracy on an enemy studied by them." % combat.STUDIED_ACCURACY_BONUS)
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


func describe_aoe_shape(skill: SkillDefinition) -> String:
	match skill.aoe_shape:
		SkillDefinition.AoEShape.LINE:
			return "Line, length %d, width %d" % [skill.aoe_radius, skill.aoe_width]
		SkillDefinition.AoEShape.CONE:
			return "Cone, length %d" % skill.aoe_radius
		_:
			return "Radius %d" % skill.aoe_radius


## Whether `skill` is the one that takes an enemy's measure - the action the
## studied accuracy bonus belongs to.
func _reveals(skill: SkillDefinition) -> bool:
	if skill == null:
		return false
	for effect in skill.all_effects():
		if effect.type == EffectDefinition.EffectType.REVEAL:
			return true
	return false


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
			var swing = _base_damage(skill)
			if swing >= 0:
				return "Base Damage: %d %s" % [swing, Damage.type_name(effect.damage_type).to_lower()]
			return "Base Damage: %s" % Damage.type_name(effect.damage_type).to_lower()
		EffectDefinition.EffectType.HEAL:
			# Reads like the damage line, because it is worked out the same way.
			var mended = _heal_amount(skill)
			if mended >= 0:
				return "Heal: %d" % mended
			return "Heal: %d-%d" % [effect.min_amount, effect.max_amount]
		EffectDefinition.EffectType.STAT_MODIFIER:
			var sign_str = "+" if effect.modifier_amount >= 0 else ""
			return "%s%d %s for %d turn(s)" % [sign_str, effect.modifier_amount, effect.stat, effect.duration]
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
			var ticks = _dot_against_enemies(skill, effect.damage_type, effect.damage_modifier)
			if ticks != "":
				return "Damage over time: %s %s a turn for %d turn(s)" % [
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
			return "Inflicts %s for %d turn(s): %s" % [
				effect.condition.display_name, turns, effect.condition.describe()
			]
		EffectDefinition.EffectType.PUSH:
			# Said as "on collision", because the push's own min/max is collision
			# damage and reads identically to a plain Damage line otherwise -
			# which made it look like the skill dealt it twice. It used to say
			# "only if they hit a wall", which was wrong in the other direction:
			# a shove stopped by a body hurts both of them.
			var push_str = "Pushes target back %d tile(s)" % effect.knockback_distance
			if effect.max_amount > 0:
				# Not only a wall: a shove stopped by another body hurts them both,
				# and the map edge counts too.
				push_str += ", dealing %d-%d damage on collision" % [effect.min_amount, effect.max_amount]
			return push_str
		EffectDefinition.EffectType.PULL:
			return "Pulls target towards caster, up to %d tile(s)" % effect.knockback_distance
	return ""


func update_combatants(combatants: Array):
	for comb in combatants:
		var effective_max_hp = combat.get_effective_stat(comb, "max_hp")
		if comb.side == 0:
			var status = _icon_for($Status, comb)
			if status != null:
				status.set_health(comb.hp, effective_max_hp)
				_refresh_conditions(status, comb)
		if comb.side == 0 and not exploration_mode and combat.get_current_combatant() == comb:
			# The big portrait beside the skill panel belongs to whoever is
			# acting, and used to be written only on a turn change - so healing
			# or being hurt during your own turn left it showing the health you
			# started with, while the party portraits beside it told the truth.
			$Actions/StatusIcon.set_health(comb.hp, effective_max_hp)
		var turn_queue_icon = _icon_for($TurnQueue/Queue, comb)
		if turn_queue_icon != null:
			_refresh_conditions(turn_queue_icon, comb)
			turn_queue_icon.set_max_hp(effective_max_hp)
			turn_queue_icon.set_hp(comb.hp)
			# Order matters: set_current works out the border colour, so it has
			# to run before anything reads it.
			turn_queue_icon.set_current(combat.get_current_combatant() == comb, comb.side)
			turn_queue_icon.set_turn_taken(comb.turn_taken)


func set_movement(movement):
	$Actions/Movement.text = str(movement)


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
	if not aiming:
		# Restore whatever the current mode says these should be, rather than
		# blanket-showing things the mode had deliberately hidden.
		$Actions/Movement.visible = not exploration_mode
		$Actions/EndTurnButton.visible = not exploration_mode
		$Actions/SkillPanelLabel.visible = not exploration_mode
		$Actions/SkillPanelTabs.visible = not exploration_mode
		$Actions/SelectTargetMessage.visible = false
		# The slot row hides itself for anyone with no slots, so it can't just
		# be switched back on with the rest.
		_update_spell_slots(combat.get_current_combatant() if combat != null and not exploration_mode else null)
		# Nor can the log, if the player folded it away before aiming.
		_apply_log_state()
		if _deployment_mode:
			# Still placing the party - the cluster stays out of the way.
			_apply_deployment_visibility()


func _target_selection_finished():
	_set_aiming(false)


func _target_selection_started():
	_set_aiming(true)


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


## Everyone this caster's attacks would land on.
func _opposition(caster: Dictionary) -> Array:
	var found: Array = []
	if combat == null:
		return found
	for comb in combat.combatants:
		if comb.get("alive", false) and comb.get("side", 1) != caster.get("side", 0):
			found.append(comb)
	return found


## What `skill` swings for in the hands of whoever is acting, before the target
## on the other end of it soaks any. -1 with nobody to ask.
func _base_damage(skill: SkillDefinition) -> int:
	var caster = _caster()
	if skill == null or caster.is_empty() or not combat.has_method("base_skill_damage"):
		return -1
	return combat.base_skill_damage(caster, skill)


## The same for a lingering tick, which is worked out the same way and then
## scaled by the effect's own fraction.
func _dot_against_enemies(skill: SkillDefinition, damage_type: int, modifier: float) -> String:
	var caster = _caster()
	if skill == null or caster.is_empty():
		return ""
	var base = combat.dot_base_damage(caster, skill, modifier)
	if base <= 0.0:
		return ""
	var lowest = -1
	var highest = -1
	for target in _opposition(caster):
		var tick = combat.resisted_damage(target, damage_type, combat.dot_tick(target, base, 0, 0))
		if lowest < 0 or tick < lowest:
			lowest = tick
		if tick > highest:
			highest = tick
	if lowest < 0:
		return ""
	return "%d" % lowest if lowest == highest else "%d-%d" % [lowest, highest]


## What a heal from whoever is acting would restore, or -1 with nobody to ask.
func _heal_amount(skill: SkillDefinition) -> int:
	var caster = _caster()
	if skill == null or caster.is_empty() or not combat.has_method("heal_amount"):
		return -1
	return combat.heal_amount(caster, skill)


## --- What is currently on somebody ---


## Hangs a strip of condition marks on `holder` and keeps it in step with what
## `comb` is actually suffering. Built on demand rather than in the scene, since
## the portraits and queue icons are themselves built on demand.
##
## `where` is a layout preset: the party portraits carry theirs beside the face,
## the turn queue underneath it, which is where there is room in each.
func _refresh_conditions(holder: Control, comb: Dictionary, where: int = -1):
	var anchor: Control = holder.get_node_or_null("Icon")
	if anchor == null:
		anchor = holder
	var strip: ConditionStrip = anchor.get_node_or_null("Conditions")
	if strip == null:
		strip = ConditionStrip.new()
		strip.name = "Conditions"
		strip.add_theme_constant_override("separation", 2)
		anchor.add_child(strip)
		var preset = where
		if preset < 0:
			preset = Control.PRESET_CENTER_RIGHT if comb.get("side", 1) == 0 else Control.PRESET_CENTER_BOTTOM
		strip.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_KEEP_SIZE)
		# Clear of the portrait rather than over it: beside it for the party
		# column, below it for the queue along the top.
		if preset == Control.PRESET_CENTER_RIGHT:
			strip.position.x += 8
		else:
			strip.position.y += 6
		strip.grow_horizontal = Control.GROW_DIRECTION_END
		strip.grow_vertical = Control.GROW_DIRECTION_END
		strip.mouse_filter = Control.MOUSE_FILTER_PASS
	strip.show_for(comb, combat)
