extends Resource
class_name ClueDefinition
## Something the party has learned, kept in the journal (J): a figure in a
## ledger, what somebody claimed, a letter pieced back together.
##
## Save one in res://clues/ - its file name is its key, the way an item's is.
## It is learned by a hotspot (Gives Clue), a solved puzzle, or a conversation:
##
##     do Campaign.learn_clue("ledger_count")
##
## A clue with two others under From Clues is a deduction instead: nothing hands
## it over, it is worked out by picking those two in the journal and pressing
## Connect. Any clue - a deduction too - can be shown to somebody in a
## conversation (see Journal.present).

## What the journal lists it as - "The ledger's count".
@export var title: String = ""
## What the journal says about it.
@export_multiline var text: String = ""
## Shown beside it in the journal. Optional.
@export var icon: Texture2D

@export_group("Deduction")
## The two clues that, connected in the journal, give this one. Empty for a
## clue that is found rather than worked out.
@export var from_clues: Array[String] = []

@export_group("When learned")
## Set on Campaign the moment it is learned - the flag a Guard's Route Known
## Flag waits on (the duty roster that shows who walks where), a door's
## Requires Flag, or anything a conversation asks after.
@export var sets_flag: String = ""
## Combatants, by key, whose character sheet is open from the start of any
## fight once this is known - the letter that says what the gate guard is
## weak to. The same reading Study gives, without the action spent on it.
@export var reveals_combatants: Array[String] = []


## Whether it is worked out rather than found.
func is_deduction() -> bool:
	return from_clues.size() >= 2
