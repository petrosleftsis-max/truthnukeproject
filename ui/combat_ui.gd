extends Control

signal turn_ended()

@export var combat: Combat
@export var controller: CController

const TQIcon = preload("res://ui/tq_icon.tscn")
const StatusIcon = preload("res://ui/status_icon.tscn")
	
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
	set_skill_list(comb.skill_list, comb.skill_used_this_turn)


func _on_end_turn_button_pressed():
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
	var current = combat.get_current_combatant()
	set_skill_list(current.skill_list, current.skill_used_this_turn)


func set_skill_list(skill_list: Array, skill_used: bool = false):
	var actions_grid_children = $Actions/ActionsPanel/ActionsGrid.get_children()
	var player_turn = controller.player_turn
	for i in range(actions_grid_children.size()):
		var action = actions_grid_children[i] as Button
		if player_turn == false or skill_used:
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
				controller.set_selected_skill(skill_key)
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
	lines.append("Targets: %s" % ("Allies" if skill.targets_ally else "Enemies"))
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
		EffectDefinition.EffectType.PUSH:
			var push_str = "Pushes target back %d tile(s)" % effect.knockback_distance
			if effect.max_amount > 0:
				push_str += " (%d-%d damage on collision)" % [effect.min_amount, effect.max_amount]
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


func _target_selection_finished():
	$Actions/SelectTargetMessage.visible = false


func _target_selection_started():
	$Actions/SelectTargetMessage.visible = true
