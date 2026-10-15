@icon("res://art/editor_icons/hack_line.svg")
extends Resource
class_name HackLine
## One line on a Rewrite the Rule sheet (HackDefinition.lines): something the
## spell or the machine is set to - "Targets: Intruders", "Reach: 4" - that
## Prometheus can change, what it has to end up as, and what changing it costs.
##
## A number when Options is empty, a choice between the Options otherwise.

## What it is called on the sheet: "Targets", "Reach", "Opens for".
@export var label: String = ""
## The choices, for a line that is one of a few things. Empty for a number.
@export var options: Array[String] = []
## Where it starts: the number, or which of the Options (0 is the first).
@export var value: int = 0
@export_group("A number")
@export var minimum: int = 0
@export var maximum: int = 10
@export_group("Changing it")
## Edits each step away from where it started costs.
@export_range(1, 10, 1) var cost: int = 1
## The label of another line that has to have been changed from its start
## before this one can be touched. Empty for none.
@export var locked_until: String = ""
## Counted in the sheet's sum, which has to stay where it started when the
## sheet is Balanced.
@export var watched: bool = false
## Other lines this one drags with it, by label: each step this one moves up
## moves those by the amount given (negative the other way), and each step down
## the opposite. A step that would push any of them past its ends cannot be
## made. A sheet with any of these spends edits on every step taken.
@export var pushes: Dictionary[String, int] = {}
@export_group("What it has to be")
@export_enum("Anything", "At most", "At least", "Exactly") var goal: int = 0
## The number, or which of the Options.
@export var goal_value: int = 0


func is_choice() -> bool:
	return not options.is_empty()


func lowest() -> int:
	return 0 if is_choice() else minimum


func highest() -> int:
	return options.size() - 1 if is_choice() else maximum


## How `at` reads on the sheet.
func shown(at: int) -> String:
	if is_choice():
		return options[clampi(at, 0, options.size() - 1)]
	return str(at)


## Whether `at` is what this line has to end up as.
func met_by(at: int) -> bool:
	match goal:
		1:
			return at <= goal_value
		2:
			return at >= goal_value
		3:
			return at == goal_value
	return true


## What it has to be, in words - "" for anything.
func goal_text() -> String:
	match goal:
		1:
			return "at most %s" % shown(goal_value)
		2:
			return "at least %s" % shown(goal_value)
		3:
			return shown(goal_value)
	return ""
