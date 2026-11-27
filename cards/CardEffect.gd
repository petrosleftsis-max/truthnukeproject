extends Resource
class_name CardEffect
## One thing a card, a relic or an event does (docs/card_game.md). A card's effects happen in order; what they land on is the card's
## Target for Damage and Apply, and the player for everything else.

enum Kind {
	## Damage to the card's target(s), Amount a hit, Times hits; the player's Might adds to each, Weakened takes a quarter off, and
	## Exposed on whoever is hit adds half. Block takes it first.
	DAMAGE,
	## Block for the player, Amount plus their Footing (a quarter less while Brittle). Gone at the start of their next turn.
	BLOCK,
	## Draw Amount cards.
	DRAW,
	## Amount more energy this turn.
	ENERGY,
	## Amount of Status on the card's target(s) (CardStatus).
	APPLY,
	## Amount of Status on the player.
	GAIN,
	## The player mends Amount, up to their most.
	HEAL,
	## The player loses Amount, block or not.
	LOSE_HP,
	## The player's most health goes up by Amount, and they mend as much (relics and events).
	MAX_HP,
	## Amount gold (relics and events; less than nothing for a price).
	GOLD,
	## The target loses Amount health, Block or not, and whoever drains it mends as much as it lost (a Tether's Siphon; an enemy's
	## Leech Line drains the player into the enemy).
	DRAIN,
}

@export var kind: Kind = Kind.DAMAGE
@export var amount: int = 0
## The amount once the card is upgraded; -1 keeps Amount.
@export var upgraded_amount: int = -1
## How many hits a Damage effect is.
@export var times: int = 1
## The hits once upgraded; -1 keeps Times.
@export var upgraded_times: int = -1
## For Apply and Gain: which status (CardStatus.ALL's keys: might, footing, exposed, weakened, brittle, poison, ward, spines,
## frenzy).
@export var status: StringName = &""
## Half-read code (the designer's twist 4): its words are struck out on the card until the card has been played once, in any run
## (CardUnlocks.read). It does what it does all the same.
@export var struck := false


func amount_for(upgraded: bool) -> int:
	return upgraded_amount if upgraded and upgraded_amount >= 0 else amount


func times_for(upgraded: bool) -> int:
	return upgraded_times if upgraded and upgraded_times >= 0 else times


## A made effect, for the content builder and the tests.
static func of(effect_kind: Kind, how_much: int, upgraded_to: int = -1, hits: int = 1, upgraded_hits: int = -1,
		which_status: StringName = &"") -> CardEffect:
	var effect := CardEffect.new()
	effect.kind = effect_kind
	effect.amount = how_much
	effect.upgraded_amount = upgraded_to
	effect.times = hits
	effect.upgraded_times = upgraded_hits
	effect.status = which_status
	return effect
