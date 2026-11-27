extends Resource
class_name CardEnemyRule
## "If this, do that": one of a card game enemy's rules (docs/card_game.md "How enemies choose"). Its rules are checked in order
## each time it chooses its next move, before its pattern: the first that holds, and whose move it may use now (the move's own
## limits), decides. A move's Lean uses the same When, Number and Status to make it likelier instead of certain.

enum When {
	## Never: nothing set.
	NEVER,
	## Always.
	ALWAYS,
	## Its own health under Number percent of its most.
	ITS_HEALTH_UNDER,
	## The player's Block at least Number.
	PLAYER_BLOCK_AT_LEAST,
	## The player's health under Number percent of their most.
	PLAYER_HEALTH_UNDER,
	## The player has at least Number (at least 1) of Status.
	PLAYER_HAS,
	## The player has none of Status.
	PLAYER_LACKS,
	## It has at least Number (at least 1) of Status.
	IT_HAS,
	## It has none of Status.
	IT_LACKS,
	## Another of its side under Number percent of their most health.
	ALLY_HURT,
	## One of its side has fallen this fight.
	ALLY_FALLEN,
	## Nobody of its side stands but itself.
	ALONE,
	## Its Number-th turn or later (its first is 1).
	TURN_AT_LEAST,
	## Every Number-th turn of its (Number, twice Number...).
	TURN_EVERY,
}

@export var when: When = When.ALWAYS
@export var number := 0
## The status For Player Has, Player Lacks, It Has and It Lacks (CardStatus keys).
@export var status: StringName = &""
## The move it does then: the name of one of its own moves.
@export var move := ""
## Only in fights this hard or harder, so the same enemy can be plainer in an easy fight (and a run's Challenge counts them harder).
@export var from_tier: CardEncounterDefinition.Tier = CardEncounterDefinition.Tier.EASY


## A made rule, for the content builder and the tests.
static func of(holds: When, then_move: String, how_much: int = 0, which_status: StringName = &"",
		at_least: CardEncounterDefinition.Tier = CardEncounterDefinition.Tier.EASY) -> CardEnemyRule:
	var rule := CardEnemyRule.new()
	rule.when = holds
	rule.move = then_move
	rule.number = how_much
	rule.status = which_status
	rule.from_tier = at_least
	return rule


## The rule in words, for the enemy's tooltip and a suite.
func describe() -> String:
	var said := ""
	match when:
		When.NEVER:
			return ""
		When.ALWAYS:
			said = "Always"
		When.ITS_HEALTH_UNDER:
			said = "Under %d%% health" % number
		When.PLAYER_BLOCK_AT_LEAST:
			said = "While you have %d Block or more" % number
		When.PLAYER_HEALTH_UNDER:
			said = "While you are under %d%% health" % number
		When.PLAYER_HAS:
			said = "While you have %s" % CardStatus.name_of(status)
		When.PLAYER_LACKS:
			said = "While you have no %s" % CardStatus.name_of(status)
		When.IT_HAS:
			said = "While it has %s" % CardStatus.name_of(status)
		When.IT_LACKS:
			said = "While it has no %s" % CardStatus.name_of(status)
		When.ALLY_HURT:
			said = "While an ally is under %d%% health" % number
		When.ALLY_FALLEN:
			said = "Once an ally has fallen"
		When.ALONE:
			said = "When it is alone"
		When.TURN_AT_LEAST:
			said = "From its turn %d" % number
		When.TURN_EVERY:
			said = "Every %d turns" % number
	return "%s: %s." % [said, move]
