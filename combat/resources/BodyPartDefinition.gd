@tool
@icon("res://art/editor_icons/body_part.svg")
extends Resource
class_name BodyPartDefinition
## A place on somebody big that can be aimed at and broken - a called shot.
## Listed on their CombatantDefinition (Body Parts). A hit aimed at one of its
## tiles hurts the part as well as the body, and once the part has taken its
## Health it breaks, for the rest of the fight (Combat "Body parts").

enum Broken {
	ROOTED,     ## Legs: they cannot move again this fight.
	WEAKENED,   ## Arms: every hit of theirs lands for less (Weakened To).
	EXPOSED,    ## An armour plate: every hit on them lands for more (Exposed By).
	STAGGERED,  ## A boss's weak point: Stagger added to their stagger bar.
	DISARMED,   ## A weapon arm: the skills in Disarms are gone.
}

@export var name: String = ""
## Which of their tiles it is, counted from their top-left: (0, 0) is the corner
## they stand on, (1, 0) the tile to its right.
@export var tiles: Array[Vector2i] = []
## What it takes to break it, as a share of their health - every hit aimed at
## it counts, in full, so it follows their level.
@export_range(0.05, 1.0, 0.05) var health_share: float = 0.3
@export var when_broken: Broken = Broken.ROOTED
## Weakened: the share of their damage still landing.
@export_range(0.1, 1.0, 0.05) var weakened_to: float = 0.6
## Exposed: what every hit on them is multiplied by.
@export_range(1.0, 3.0, 0.05) var exposed_by: float = 1.3
## Staggered: added to their stagger bar (a boss's).
@export_range(0.0, 200.0, 1.0) var stagger: float = 50.0
## Disarmed: the skills, by key, they lose.
@export var disarms: Array[String] = []


## What breaking it does, as the log and the hover say it.
func describe_broken() -> String:
	match when_broken:
		Broken.ROOTED:
			return "cannot move"
		Broken.WEAKENED:
			return "hits for %d%%" % roundi(weakened_to * 100)
		Broken.EXPOSED:
			return "takes %d%% more" % roundi((exposed_by - 1.0) * 100)
		Broken.STAGGERED:
			return "reels"
		Broken.DISARMED:
			return "loses a weapon"
	return ""
