@icon("res://art/editor_icons/condition.svg")
extends Resource
class_name CombatLines
## What somebody may say in a bubble over their head as a fight goes (SpeechBubbles; the designer, 2026-11-07: "dialogue that only shows up
## as a bubble above a character that goes away by itself. we can add lines for every character depending on what happens in combat").
## Set on a CombatantDefinition's Speech group, per creature. Empty lists say nothing, so nobody has to have any of these. Several
## lines for one moment take turns, so nobody repeats themselves straight away.

@export_group("The fight")
@export var fight_starts: Array[String] = []
## Their first blow of the fight.
@export var first_blow: Array[String] = []
## The fight is over, and they are standing.
@export var won: Array[String] = []

@export_group("What they do")
## They fell somebody.
@export var fells_somebody: Array[String] = []
## They react to something.
@export var reacts: Array[String] = []
## They take a blow meant for somebody else.
@export var takes_a_blow: Array[String] = []
## They study somebody.
@export var studies: Array[String] = []
## A spell through a deep gate (from Sophia on).
@export var deep_spell: Array[String] = []
## The last casting they had left: they are out of castings now.
@export var last_casting: Array[String] = []
## A blow of theirs takes half or more of somebody's health, felling them or not (Combat.BIG_HIT_SHARE).
@export var big_hit_given: Array[String] = []
## Using a move in particular, by its key: {"trailblaze": ["Keep up."]}.
@export var when_using: Dictionary = {}

@export_group("What happens to them")
## Somebody on their side falls, and they are the nearest.
@export var ally_falls: Array[String] = []
## They have fallen below a third of their health.
@export var badly_hurt: Array[String] = []
## Somebody else mends them.
@export var healed: Array[String] = []
## A blow takes half or more of their health, and they are still standing.
@export var big_hit_taken: Array[String] = []
## They are brought back from being down (a Resuscitate, Smelling Salts).
@export var brought_back: Array[String] = []
## Somebody of their own side, or they themselves, lifts something harmful off them (Cleanse, Calm).
@export var condition_lifted: Array[String] = []
## Anything harmful takes hold of them, with nothing of its own to say below.
@export var afflicted: Array[String] = []
## A condition in particular, by its file's name: {"burn": ["..."], "stunned": ["..."], "fear": ["..."]}.
@export var when_afflicted: Dictionary = {}

@export_group("Others")
## They have seen through an illusion.
@export var seen_through: Array[String] = []
## A boss changing phase.
@export var phase: Array[String] = []
## One of the other side breaks and runs: one of their own side, chosen at random, says one of these.
@export var enemy_gives_up: Array[String] = []
## Another of their side fells somebody who is not a boss, by that one's key: {"cyrus": ["Never run out of tricks, friend."]}. One
## of the side says one line for each such kill, chosen at random among those with a line for whoever did it.
@export var praise: Dictionary = {}


## The lines for `event`, for what `about` says: a move's key or a condition's file name.
func lines_for(event: StringName, about: String = "") -> Array:
	match event:
		&"using":
			return when_using.get(about, [])
		&"afflicted":
			var own: Array = when_afflicted.get(about, [])
			return own if not own.is_empty() else afflicted
		&"praise":
			return praise.get(about, [])
	var found = get(event)
	return found if found is Array else []
