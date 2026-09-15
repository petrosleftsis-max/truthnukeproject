extends Resource
class_name GlossaryBook
## The written half of the glossary: everything the game cannot work out for
## itself. Open res://glossary/glossary_book.tres and type into it.
##
## The other half is generated - a condition's numbers, a gate's allowance per
## level, a skill's range and cost all come from the game's own data, so they
## can never drift out of date with what the game actually does. What lives
## here is the part that needs a person: what these things mean, and why they
## are in the story at all.
##
## A character's own introduction is not here: it sits on their
## CombatantDefinition, next to everything else about them.


@export_group("Openings")
## Shown at the top of the glossary's first screen.
@export_multiline var foreword: String = ""
## Shown above the list of characters.
@export_multiline var cast_intro: String = ""
## Shown above the list of conditions, before any of their numbers.
@export_multiline var conditions_intro: String = ""
## Shown above the list of skills.
@export_multiline var skills_intro: String = ""

@export_group("The Gates")
## The whole Gates page, written as one piece. Shown as a page rather than a
## list, because the gates are one idea explained together rather than three
## things to look up separately.
@export_multiline var gates: String = ""
