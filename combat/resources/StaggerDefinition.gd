@icon("res://art/editor_icons/stagger.svg")
extends Resource
class_name StaggerDefinition
## A boss's stagger bar (BossDefinition.stagger): what fills it, what empties
## it, and what a full one does.
##
## Full, the boss is Staggered: it loses its next turn, whatever it was
## readying (a declared skill) comes to nothing, and it takes harder hits until
## that lost turn is over. Then the bar starts again from empty. Or, with Harder
## Until at The Staggerer's Next Turn, it keeps its turn and is Reeling: hit
## harder until whoever's turn it was staggered in begins their next one.
##
## The standard bar is the defaults: Max 100, filled a point for each point of
## damage, nothing draining it. Change what fills it to change the fight:
## - burst: a heavy Drain Per Round, so only a lot of damage in one round fills it
## - one element: Damage Types set to Fire, and only fire counts
## - interrupt: Per Damage low and While Readying high, so it fills mostly while
##   the boss is winding up something declared
## - control: Per Blocked Condition, so the stuns it shrugs off still count
## - a mechanic: everything here at 0, and the bar filled only by the things on
##   the map (BattleObjectDefinition.stagger) or the arena's own hazards
##   catching it (HazardDefinition.stagger)
## The Hint says on screen what to do: "Ring the bells".

## Said under the bar - how to fill it, in the fight's own words.
@export_multiline var hint: String = ""
@export_range(1.0, 1000.0, 1.0, "or_greater") var max_value: float = 100.0

@export_group("What fills it")
## For each point of health the boss loses.
@export_range(0.0, 10.0, 0.05, "or_greater") var per_damage: float = 1.0
## Only damage of these types counts for Per Damage. Empty, any does.
@export var damage_types: Array[Damage.Type] = []
## For each hit landed on it, whatever its size.
@export_range(0.0, 100.0, 0.5, "or_greater") var per_hit: float = 0.0
## For each condition tried on it that it is immune to - a stun it shrugs off.
@export_range(0.0, 100.0, 0.5, "or_greater") var per_blocked_condition: float = 0.0
## Particular skills, by key, and how much each hit of one adds on top.
@export var from_skills: Dictionary[String, float] = {}
## Everything above, multiplied, while the boss is readying a declared skill.
@export_range(0.0, 10.0, 0.05, "or_greater") var while_readying: float = 1.0

@export_group("What empties it")
## Taken off at the top of every round.
@export_range(0.0, 1000.0, 1.0, "or_greater") var drain_per_round: float = 0.0

@export_group("Staggered")
## How long it is hit harder. Its Lost Turns: until the turns a full bar costs it are over. The Staggerer's Next Turn: it keeps
## its turn, and is hit harder until the next turn of whoever's turn it was staggered in begins - everybody gets one turn at it
## (the designer, 2026-11-27, for Erysichthon: "keep the damage vulnerability until the start of the turn of the creature in
## whose turn the boss got staggered"). Either way the bar fills again once it is over. Stored by number: append.
enum HarderUntil { ITS_LOST_TURNS, THE_STAGGERERS_NEXT_TURN }
@export var harder_until: HarderUntil = HarderUntil.ITS_LOST_TURNS
## Turns of the boss's that a full bar costs it, while it is hit harder until those are over (Its Lost Turns).
@export_range(1, 3, 1, "or_greater") var turns_lost: int = 1
## How much harder it is hit while staggered.
@export_range(1.0, 3.0, 0.05, "or_greater") var damage_taken: float = 1.5
## How much bigger the bar gets each time it fills: 0.25 is a quarter more.
@export_range(0.0, 2.0, 0.05, "or_greater") var grows_by: float = 0.0


## How the bar works, in a line or two, for its tooltip.
func describe() -> String:
	var lines: Array[String] = []
	if hint != "":
		lines.append(hint)
	var fills: Array[String] = []
	if per_damage > 0.0:
		if damage_types.is_empty():
			fills.append("damage")
		else:
			fills.append("%s damage" % "/".join(damage_types.map(func(type): return Damage.type_name(type).to_lower())))
	if per_hit > 0.0:
		fills.append("every hit")
	if per_blocked_condition > 0.0:
		fills.append("conditions it shrugs off")
	for key in from_skills:
		if SkillDatabase.skills.has(key):
			fills.append(SkillDatabase.skills[key].name)
	if not fills.is_empty():
		lines.append("Filled by %s." % ", ".join(fills))
	if while_readying > 1.0:
		lines.append("Fills faster while it is readying something.")
	if drain_per_round > 0.0:
		lines.append("Drains by %d each round." % roundi(drain_per_round))
	if harder_until == HarderUntil.THE_STAGGERERS_NEXT_TURN:
		lines.append("Full, it is staggered: every blow on it has +%d%% Output Efficiency until whoever staggered it acts again, and its turn is its own." % \
			roundi((damage_taken - 1.0) * 100.0))
	else:
		lines.append("Full, it is staggered: %s lost, and every blow on it has +%d%% Output Efficiency until then." % [
			"a turn" if turns_lost == 1 else "%d turns" % turns_lost, roundi((damage_taken - 1.0) * 100.0)])
	return "\n".join(lines)
