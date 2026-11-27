extends Resource
class_name CardEventOption
## One choice in an event of the card game (CardEventDefinition).

enum Action {
	NONE,
	## Choose one of three cards, or none.
	CARD_REWARD,
	## Take a card of the deck out for the rest of the run (it is forgotten: twist 8).
	REMOVE_CARD,
	## Upgrade a card of the deck.
	UPGRADE_CARD,
	## A relic not had yet, at random.
	RANDOM_RELIC,
	## Rewrite a card of the deck into another of the same rarity, at random (the Shifting Room).
	TRANSFORM_CARD,
	## Every half-read card of the deck read at once (Notes on the Wall).
	READ_ALL,
	## A word of the truth for the Message (twist 10): a few ways for it to grow, at random, to choose one of (CardRun.message_offers).
	MESSAGE,
}

@export var label := ""
## What is said once it is chosen.
@export_multiline var outcome := ""
## Gold gained (less than nothing: paid; it cannot be chosen without the gold).
@export var gold := 0
## Health gained or lost (it cannot be chosen if it would kill).
@export var hp := 0
## Most health gained or lost.
@export var max_hp := 0
@export var action: Action = Action.NONE
## The system's trace raised (or, less than nothing, lowered) by it (CardRun.trace).
@export_range(-50, 50) var trace := 0
## A code fragment of the locked deck nearest to opening (CardUnlocks): a Memento.
@export var fragment := false
## A card put in the deck (data/cards/ key), a Status card for a price.
@export var adds_card := ""
