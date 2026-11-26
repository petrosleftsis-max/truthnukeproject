@tool
@icon("res://art/editor_icons/interactable.svg")
extends Node
class_name Hours
## When its parent is here (the proposals of 2026-11-19, "The hours and the weather change the map"; the designer: "Do all"). Put
## one under a shopkeeper and the shop is shut at night; under a townsman, with Elsewhere a marker by his door, and after dark he is
## at home; under a Guard, and he keeps a shift - two guards on one post, one by day and one by night, change at dawn and dusk.
## Away with nowhere else to be, the parent is out of sight and out of use. A guard's shift is the watch's to keep (StealthWatch
## "Shifts"): off it he is kept off the map, and as the hour turns he walks off to his Elsewhere - where the shift changes - or in
## from it to his beat, while the party watches. Anybody else comes and goes as the hours turn. By the four parts of the day
## (Light.Hour). PROPOSAL.

@export var by_day: bool = true
@export var at_dusk: bool = true
@export var at_night: bool = false
@export var at_dawn: bool = true
## Where the parent is while away from here, if anywhere: a Marker2D, say, by a house's door. Empty: away is gone. A guard's is where
## his shift changes: he walks off to it, and in from it.
@export var elsewhere: NodePath

const CHECK_EVERY := 1.0

var _here_at := Vector2.INF
var _check := 0.0


## Whether it is here in `part` of the day.
func here_in(part: int) -> bool:
	match part:
		Light.Hour.DAY:
			return by_day
		Light.Hour.DUSK:
			return at_dusk
		Light.Hour.NIGHT:
			return at_night
		_:
			return at_dawn


func here_now() -> bool:
	return here_in(Campaign.time_of_day)


func _ready():
	if Engine.is_editor_hint():
		return
	var parent := get_parent() as Node2D
	if parent != null:
		_here_at = parent.global_position
	_apply.call_deferred()


func _process(delta: float):
	if Engine.is_editor_hint():
		return
	_check -= delta
	if _check > 0.0:
		return
	_check = CHECK_EVERY
	_apply()


func _apply():
	var parent := get_parent() as Node2D
	# A guard's shift is the watch's to keep, as the map loads.
	if parent == null or parent is Guard:
		return
	var here := here_now()
	var spot: Node2D = get_node_or_null(elsewhere) as Node2D if elsewhere != NodePath() else null
	if spot != null:
		parent.global_position = _here_at if here else spot.global_position
		return
	parent.visible = here
	if "kept_hidden" in parent:
		parent.kept_hidden = not here
