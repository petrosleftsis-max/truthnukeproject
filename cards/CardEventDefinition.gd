extends Resource
class_name CardEventDefinition
## An event of the card game: the "?" rooms on the map, a few lines and a choice (docs/card_game.md). One file in
## data/card_events/.

@export var title := ""
@export_multiline var text := ""
@export var options: Array[CardEventOption] = []
## A word of the truth to be had here too (twist 10): with no Message option of its own, the event also offers to listen for one
## (CardRun.event_options), instead of what the others give.
@export var offers_a_word := true
