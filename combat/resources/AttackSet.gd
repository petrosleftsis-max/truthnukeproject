@icon("res://art/editor_icons/skill.svg")
extends Resource
class_name AttackSet
## Blows one after another in a single turn, all at one target (CombatantDefinition.attack_sets, BossPhase.attack_sets_added;
## Combat "A turn of several blows", ai_attack_sets). Erysichthon's: two Claws and a Chomp, and from half health a second set
## at somebody else, from further off (the designer, 2026-11-27).

## The blows, by skill key, in the order they come.
@export var skills: Array[String] = []
## Tiles each blow of this set reaches - 0 leaves every skill its own.
@export_range(0, 20, 1, "suffix:tiles") var reach: int = 0
## It springs at its target first, along a straight line, and lands as near them as there is room - then strikes from there
## with the blows' own reach (Combat.lunge_at). Reach above is how far it springs from.
@export var lunges: bool = false
## At somebody none of the sets before it went for this turn. With nobody else to go for, it is not used.
@export var another_target: bool = false


## What the set does, in a few words, for a sheet: "Claw, Claw and Chomp, at one target".
func describe() -> String:
	var names: Array[String] = []
	for key in skills:
		var skill: SkillDefinition = SkillDatabase.skills.get(key) if not Engine.is_editor_hint() else null
		names.append(skill.name if skill != null else key)
	var said := ""
	if names.size() <= 1:
		said = "".join(names)
	else:
		said = "%s and %s" % [", ".join(names.slice(0, names.size() - 1)), names[-1]]
	said += ", at another target" if another_target else ", at one target"
	if reach > 0:
		said += (", springing at them from up to %d tiles" if lunges else ", from up to %d tiles") % reach
	return said
