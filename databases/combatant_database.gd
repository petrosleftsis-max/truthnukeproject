extends Node

@export var combatants: Dictionary


## Checks that every skill anybody is carrying actually exists, and says so
## plainly if one doesn't.
##
## A skill key is just a string in two places that have to agree, and nothing
## makes them. A key that doesn't match - a typo, a renamed skill, a capital
## letter - reads fine everywhere until the combatant with it reaches the line
## that looks the skill up, which can be most of a fight away and reports
## itself as a dictionary error deep in Combat rather than as the missing
## skill it is. This turns that into one message at startup naming the
## combatant, the key and the nearest thing to it in the database.
##
## Loaded after SkillDatabase (see the autoload order in project.godot), so the
## skills are there to check against.
func _ready():
	for key in combatants:
		var definition: CombatantDefinition = combatants[key]
		if definition == null:
			push_error("Combatant '%s' has no definition resource." % key)
			continue
		for skill_key in definition.skills:
			if SkillDatabase.skills.has(skill_key):
				continue
			push_error("Combatant '%s' carries the skill '%s', which is not in the skill database.%s" % [
				key, skill_key, _did_you_mean(skill_key)])


## The database key a mistyped one was probably meant to be. Almost always a
## difference of case, which is the hardest kind to see in a list of names.
func _did_you_mean(skill_key: String) -> String:
	for known in SkillDatabase.skills:
		if String(known).to_lower() == skill_key.to_lower():
			return " Did you mean '%s'?" % known
	return ""
