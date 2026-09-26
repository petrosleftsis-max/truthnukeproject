extends Resource
class_name PassiveDefinition
## A skill nobody presses. It is part of who somebody is: working all the time,
## or switching itself on when its moment comes, and never offered on the
## action panel because there is nothing there to choose.
##
## Kept apart from SkillDefinition rather than being a skill with a flag on it.
## Everything that walks a combatant's skill list - the three panels, the
## reactions, the AI hunting for something to swing - would otherwise have to
## be taught to step over it, and the first place that forgot would offer the
## player a button that does nothing. A combatant lists these under Passives
## instead, and the character sheet reads them out under a heading of their own.
##
## What one does is a switch below for each thing the rules know how to hand
## out. Combat only looks at the switches of a passive whose moment holds - see
## Combat.active_passives - so one waiting on its condition does nothing at all.


## When it is working.
##
## Stored by number, so a new one goes on the end. Put one in the middle and
## every passive already written with a later one quietly means something else.
enum ActiveWhen {
	ALWAYS,             ## From the first turn of a fight to the last.
	BELOW_HALF_HEALTH,  ## Only while they are down to half their health or less.
}

@export var name: String = ""
## What it does, in the words the character sheet shows. Written out in full on
## the sheet rather than left behind a tooltip, so say it plainly.
@export_multiline var description: String = ""
## Optional. The sheet names the passive either way.
@export var icon: Texture2D
@export var active_when: ActiveWhen = ActiveWhen.ALWAYS

@export_group("What it does")
## Casts without spending anything. Whatever they know they can use, however
## deep a gate the spell is cast through and however many gates they have of
## their own - which may be none. The Mimic's: its whole trick is doing what it
## just watched somebody else do, and without this it copies a spell and then
## cannot pay for it, which is a turn spent doing nothing at all.
@export var casts_without_gates: bool = false
## Skills, by key, they can also use as their secondary action - still on the
## main panel as well, so either action will do. Cyrus's Light Footed: it is why he
## can Run twice in one turn.
@export var secondary_skills: Array[String] = []
## Consumables that would cost the main action can be used as the secondary
## one instead. Cyrus's Quick Hands: it is why he can drink a potion and still
## swing in the same turn.
@export var items_as_secondary: bool = false
## Every skill they use is worked out from this attribute instead of the one
## the skill names: its damage, its heals, what it burns for, and its side of a
## contest. "Own stat" leaves each skill to its own. The Mimic's: whatever it
## copies - a greatsword swing, a Fire Burst - comes out of its Self.
##
## The names are Stats.NAMES in order, with -1 in front for "leave it be"; a
## stat added there needs adding here too.
@export_enum("Own stat:-1", "Physical:0", "Mindfulness:1", "Intellect:2", "Self:3", "Defense:4")
var scales_every_skill_with: int = -1


## When it works, as the character sheet says it.
func describe_when() -> String:
	match active_when:
		ActiveWhen.BELOW_HALF_HEALTH:
			return "Active at half health or below"
	return "Always active"


## What its switches do, a line each, in the words the glossary prints. Kept
## beside the switches so a new one is described where it is added.
func describe_effects() -> Array:
	var lines := []
	if casts_without_gates:
		lines.append("Casts without opening a gate, however deep a gate the spell calls for.")
	if not secondary_skills.is_empty():
		lines.append("Can use %s as a secondary action as well as a main one." % _named(secondary_skills))
	if items_as_secondary:
		lines.append("Can use items as a secondary action as well as a main one.")
	if scales_every_skill_with >= 0:
		lines.append("Every skill scales with %s, whatever stat the skill itself names."
			% Stats.stat_name(scales_every_skill_with))
	return lines


## "Stealth, Slip Past and Run" from their keys.
static func _named(keys: Array) -> String:
	var names := []
	for key in keys:
		var skill = SkillDatabase.skills.get(key) if not Engine.is_editor_hint() else null
		names.append(skill.name if skill != null else String(key).capitalize())
	if names.size() <= 1:
		return "".join(names)
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + names[-1]
