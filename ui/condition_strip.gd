extends HBoxContainer
class_name ConditionStrip
## The row of little marks saying what is currently on a combatant - poisoned,
## slowed, hasted, burning - hung beside a party portrait or under a turn-queue
## icon.
##
## Everything a status effect does was previously only in the combat log, which
## scrolls away: two turns later there is nothing on screen saying why somebody
## is moving three tiles instead of five. This is that, permanently, where the
## portraits already are.
##
## One mark per effect, and the reading is in the tooltip - a strip of icons
## says "something is on them", and hovering says what, how long, and how much
## it is costing per turn.

## Everything uses the same mark for now. When conditions get art of their own
## this is where it comes from, and nothing else changes.
const MARK := preload("res://imagese/skills/fire_icon.png")

const MARK_SIZE := Vector2(22, 22)
## Tinted by what the effect does to you rather than by what kind it is: red
## for anything working against you, green for anything helping. Which of the
## two it is, is the thing worth seeing at a glance.
const HARMFUL := Color(1.0, 0.45, 0.4)
const HELPFUL := Color(0.55, 0.85, 0.55)

var _combat: Combat = null


## Rebuilds the strip for `comb`. Safe to call every time anything changes;
## there are never more than a handful of marks.
func show_for(comb: Dictionary, combat: Combat):
	_combat = combat
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for effect in comb.get("status_effects", []):
		var described = describe(comb, effect)
		if described == "":
			continue
		add_child(_mark(described, _is_helpful(effect)))


func _mark(tooltip: String, helpful: bool) -> TextureRect:
	var icon = TextureRect.new()
	icon.texture = MARK
	icon.custom_minimum_size = MARK_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = HELPFUL if helpful else HARMFUL
	# Without this the mouse passes straight through and there is no tooltip.
	icon.mouse_filter = Control.MOUSE_FILTER_STOP
	icon.tooltip_text = tooltip
	return icon


## Whether this is something the combatant wants. A buff is a raised stat; a
## condition is judged by its own effects, since "Blessed" and "Blinded" are
## stored identically.
func _is_helpful(effect: Dictionary) -> bool:
	match effect.get("stat", ""):
		"dot":
			return false
		"condition":
			var condition: ConditionDefinition = effect.get("condition")
			if condition == null:
				return false
			if condition.dot_modifier > 0.0 or condition.dot_max > 0:
				return false
			if condition.skips_turn or condition.prevents_movement or condition.prevents_secondary:
				return false
			return condition.movement_change > 0 or condition.accuracy_change > 0
	if effect.get("op", "add") == "mul":
		return effect.get("multiplier", 1.0) > 1.0
	return effect.get("amount", 0) > 0


## What one effect is doing, in the words the tooltip shows. Empty for anything
## with nothing worth saying.
func describe(comb: Dictionary, effect: Dictionary) -> String:
	var turns = effect.get("duration", 0)
	match effect.get("stat", ""):
		"dot":
			var per_turn = _tick(comb, effect.get("dot_base", 0.0), effect.get("damage_type", 0),
				effect.get("min_amount", 0), effect.get("max_amount", 0))
			var name = effect.get("source_name", "")
			var opening = "Lingering wound" if name == "" else "Lingering wound from %s" % name
			return "%s\n%d %s damage a turn for %s (%d in all)" % [
				opening, per_turn, Damage.type_name(effect.get("damage_type", 0)).to_lower(),
				_turns(turns), per_turn * turns
			]
		"condition":
			return _describe_condition(comb, effect)
	return _describe_stat_change(effect)


func _describe_condition(comb: Dictionary, effect: Dictionary) -> String:
	var condition: ConditionDefinition = effect.get("condition")
	if condition == null:
		return ""
	var lines := [condition.display_name]
	if condition.description != "":
		lines.append(condition.description)
	var doing := []
	if condition.dot_modifier > 0.0 or condition.dot_max > 0:
		var per_turn = _tick(comb, effect.get("dot_base", 0.0), condition.dot_type,
			condition.dot_min, condition.dot_max)
		var turns = effect.get("duration", 0)
		doing.append("%d %s damage a turn (%d in all)" % [
			per_turn, Damage.type_name(condition.dot_type).to_lower(), per_turn * turns
		])
	if condition.movement_change != 0:
		doing.append("%+d movement" % condition.movement_change)
	if condition.accuracy_change != 0:
		doing.append("%+d%% to hit" % condition.accuracy_change)
	if condition.max_range > 0:
		doing.append("cannot reach past %d tile(s)" % condition.max_range)
	if condition.skips_turn:
		doing.append("loses their turn")
	if condition.prevents_movement:
		doing.append("cannot move")
	if condition.prevents_secondary:
		doing.append("no secondary action")
	if condition.prevents_reactions:
		doing.append("no reactions")
	if not doing.is_empty():
		lines.append(", ".join(doing))
	lines.append("Wears off in %s" % _turns(effect.get("duration", 0)))
	return "\n".join(lines)


func _describe_stat_change(effect: Dictionary) -> String:
	var stat = effect.get("stat", "")
	if stat == "":
		return ""
	var named = effect.get("source_name", "")
	var lines := []
	if effect.get("op", "add") == "mul":
		var multiplier = effect.get("multiplier", 1.0)
		lines.append("%s x%s" % [stat.capitalize(), multiplier])
	else:
		lines.append("%s %+d" % [stat.capitalize(), effect.get("amount", 0)])
	if named != "":
		lines.append("From %s" % named)
	lines.append("Wears off in %s" % _turns(effect.get("duration", 0)))
	return "\n".join(lines)


## What a tick will actually take off this combatant: the same arithmetic the
## tick itself does, so the tooltip and the log can never disagree.
func _tick(comb: Dictionary, dot_base: float, damage_type: int, flat_min: int, flat_max: int) -> int:
	if _combat == null:
		return 0
	return _combat.resisted_damage(comb, damage_type, _combat.dot_tick(comb, dot_base, flat_min, flat_max))


func _turns(count: int) -> String:
	return "1 turn" if count == 1 else "%d turns" % count
