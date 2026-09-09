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

## Which action slot the skill panel is showing: false = main, true = secondary.
## Reset to main whenever the turn passes to someone new, so a turn always
## starts on the panel you'd expect.
var showing_secondary := false


func _ready():
	$Actions/SkillPanelToggle.pressed.connect(func(): set_skill_panel(not showing_secondary))


## Switches the action panel between a combatant's main and secondary skills.
## The two slots are spent separately - a turn can use one of each - so this is
## purely a view switch and never costs anything.
func set_skill_panel(secondary: bool):
	showing_secondary = secondary
	$Actions/SkillPanelLabel.text = "Secondary Skills" if secondary else "Main Skills"
	$Actions/SkillPanelToggle.text = "Main" if secondary else "Secondary"
	if combat != null and not exploration_mode:
		_show_skills_for(combat.get_current_combatant())


## Fills the action panel from whichever slot is currently on show.
func _show_skills_for(comb: Dictionary):
	if combat == null:
		set_skill_list([], true)
		return
	var list = combat.secondary_skills_of(comb) if showing_secondary else combat.main_skills_of(comb)
	var used = comb.get("secondary_used_this_turn", false) if showing_secondary else comb.get("skill_used_this_turn", false)
	set_skill_list(list, used, showing_secondary)


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
	$Actions/SkillPanelToggle.visible = not enabled
	if enabled:
		set_skill_list([], true)
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
	new_icon.name = combatant.name
	new_icon.set_side(combatant.side)


func update_turn_queue(combatants: Array, turn_queue: Array):
	for c in turn_queue:
		var comb = combatants[c]
		add_turn_queue_icon(comb)


func combatant_died(combatant):
	var turn_queue_icon = $TurnQueue/Queue.find_child(combatant.name, false, false)
#	if combatant.side == 0:
#		var status = $Status.find_child(combatant.name, false, false)
#		if status != null:
#			status.queue_free()
	if turn_queue_icon != null:
		turn_queue_icon.queue_free()


func add_combatant_status(comb: Dictionary):
	if comb.side == 0:
		var new_status = StatusIcon.instantiate()
		$Status.add_child(new_status)
		new_status.set_icon(comb.icon)
		new_status.set_health(comb.hp, combat.get_effective_stat(comb, "max_hp"))
		new_status.name = comb.name


func show_combatant_status_main(comb: Dictionary):
	if comb.side == 0:
		$Actions/StatusIcon.set_icon(comb.icon)
		$Actions/StatusIcon.set_health(comb.hp, combat.get_effective_stat(comb, "max_hp"))
	# A new turn always opens on the main panel.
	set_skill_panel(false)
	_show_skills_for(comb)


## True while the player is placing the party, before the first turn.
var _deployment_mode := false
var _end_turn_default_text := ""


## Switches the HUD into (or out of) the pre-battle deployment step. The End
## Turn button doubles as Begin Battle - it's the one "I'm done" control the
## layout already has, and it means nothing during deployment anyway. Skills
## are locked out so a hero can't act before the fight has started.
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
	else:
		refresh_action_buttons()


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
	_show_skills_for(combat.get_current_combatant())


func set_skill_list(skill_list: Array, skill_used: bool = false, as_secondary: bool = false):
	var actions_grid_children = $Actions/ActionsPanel/ActionsGrid.get_children()
	# There is no CController while exploring - no turn is in progress and
	# nothing could resolve a skill - so every action button stays disabled.
	var player_turn = controller.player_turn if controller != null else false
	# Nothing may be picked while a combatant is walking or an animation is
	# resolving: the turn's state is mid-change, and the skill would be aimed
	# from wherever they happened to be standing at the time.
	var busy = controller != null and (controller.action_locked or not controller.is_idle())
	for i in range(actions_grid_children.size()):
		var action = actions_grid_children[i] as Button
		if player_turn == false or skill_used or busy:
			action.disabled = true
		else:
			action.disabled = false
		if skill_list.size() > i:
			var skill_key = skill_list[i]
			var skill = SkillDatabase.skills[skill_key]
			action.icon = skill.icon
			action.tooltip_text = build_skill_tooltip(skill)
			clear_action_button_connections(action)
			action.pressed.connect(func():
				controller.set_selected_skill(skill_key, as_secondary)
				controller.begin_target_selection()
				)
		else:
			action.icon = null
			action.tooltip_text = ""
			clear_action_button_connections(action)
	$Actions/EndTurnButton.disabled = !player_turn


func clear_action_button_connections(action: Button):
	var connections = action.pressed.get_connections()
	for connection in connections:
		action.pressed.disconnect(connection.callable)


## Builds the full hover tooltip for a skill's action button: its name, the
## author-written description (if any), and an auto-generated stats summary
## read straight from the skill's actual data - so the numbers shown can
## never drift out of sync with what the skill really does.
func build_skill_tooltip(skill: SkillDefinition) -> String:
	var lines: Array[String] = [skill.name]
	if skill.description != "":
		lines.append(skill.description)
	lines.append("")
	lines.append("Range: %d-%d" % [skill.min_range, skill.max_range])
	lines.append("Hit chance: %d%%" % skill.accuracy)
	lines.append("Targets: %s" % ("Everyone caught in it" if skill.affects_both_sides else ("Allies" if skill.targets_ally else "Enemies")))
	if skill.aoe_radius > 0:
		lines.append("Area: %s" % describe_aoe_shape(skill))
	if skill.respects_blocking:
		lines.append("Requires a clear line of sight")
	if skill.is_reactive:
		lines.append("Reactive: triggers automatically if a valid target leaves its range on their turn")
	if skill.effects.size() > 0:
		lines.append("")
		lines.append("Effects:")
		for effect in skill.effects:
			lines.append("- " + describe_effect(effect))
	return "\n".join(lines)


func describe_aoe_shape(skill: SkillDefinition) -> String:
	match skill.aoe_shape:
		SkillDefinition.AoEShape.LINE:
			return "Line, length %d, width %d" % [skill.aoe_radius, skill.aoe_width]
		SkillDefinition.AoEShape.CONE:
			return "Cone, length %d" % skill.aoe_radius
		_:
			return "Radius %d" % skill.aoe_radius


func describe_effect(effect: EffectDefinition) -> String:
	match effect.type:
		EffectDefinition.EffectType.DAMAGE:
			return "Damage: %d-%d" % [effect.min_amount, effect.max_amount]
		EffectDefinition.EffectType.HEAL:
			return "Heal: %d-%d" % [effect.min_amount, effect.max_amount]
		EffectDefinition.EffectType.STAT_MODIFIER:
			var sign_str = "+" if effect.modifier_amount >= 0 else ""
			return "%s%d %s for %d turn(s)" % [sign_str, effect.modifier_amount, effect.stat, effect.duration]
		EffectDefinition.EffectType.DAMAGE_OVER_TIME:
			return "Damage over time: %d-%d for %d turn(s)" % [effect.min_amount, effect.max_amount, effect.duration]
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
			return "Inflicts %s for %d turn(s): %s" % [
				effect.condition.display_name, effect.condition.duration, effect.condition.describe()
			]
		EffectDefinition.EffectType.PUSH:
			# Spelled out as "only if", because the push's own min/max is
			# collision damage and reads identically to a plain Damage line
			# otherwise - which made it look like the skill dealt it twice.
			var push_str = "Pushes target back %d tile(s)" % effect.knockback_distance
			if effect.max_amount > 0:
				push_str += ", dealing %d-%d damage only if they hit a wall" % [effect.min_amount, effect.max_amount]
			return push_str
		EffectDefinition.EffectType.PULL:
			return "Pulls target towards caster, up to %d tile(s)" % effect.knockback_distance
	return ""


func update_combatants(combatants: Array):
	for comb in combatants:
		var effective_max_hp = combat.get_effective_stat(comb, "max_hp")
		if comb.side == 0:
			var status = $Status.find_child(comb.name, false, false)
			if status != null:
				status.set_health(comb.hp, effective_max_hp)
		var turn_queue_icon = $TurnQueue/Queue.find_child(comb.name, false, false)
		if turn_queue_icon != null:
			turn_queue_icon.set_max_hp(effective_max_hp)
			turn_queue_icon.set_hp(comb.hp)
			turn_queue_icon.set_side(comb.side)
			turn_queue_icon.set_turn_taken(comb.turn_taken)


func set_movement(movement):
	$Actions/Movement.text = str(movement)


## While a skill is being aimed, everything but the party portraits and the
## turn queue gets out of the way, so the map - and the skill's range and area
## preview drawn on it - is unobstructed. The Actions cluster carries the skill
## buttons, movement counter, End Turn and message log, so hiding it as a whole
## clears all of them at once; the aiming banner is put back on top of it.
func _set_aiming(aiming: bool):
	$Actions.visible = true
	for child in $Actions.get_children():
		if child.name != "SelectTargetMessage":
			child.visible = not aiming
	$Actions/SelectTargetMessage.visible = aiming
	if not aiming:
		# Restore whatever the current mode says these should be, rather than
		# blanket-showing things the mode had deliberately hidden.
		$Actions/Movement.visible = not exploration_mode
		$Actions/EndTurnButton.visible = not exploration_mode
		$Actions/SkillPanelLabel.visible = not exploration_mode
		$Actions/SkillPanelToggle.visible = not exploration_mode
		$Actions/SelectTargetMessage.visible = false


func _target_selection_finished():
	_set_aiming(false)


func _target_selection_started():
	_set_aiming(true)
