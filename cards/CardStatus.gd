extends RefCounted
class_name CardStatus
## The statuses of the card game (docs/card_game.md): what each is called, what it does, and whether it wears off. Kept in code
## rather than in files because the battle's rules read them by key; a name or a line of text can change here freely.
##
## The traits of enemies are statuses too (docs/proposals_2026-11-27_card_ai.md sections 3 and 5): an enemy starts with them
## (CardEnemyDefinition.starting_statuses) and they show as badges with their words, so the player sees the rule.

## key -> {name, text (%d is the amount, where it says it), lasts (true: stays all fight, or counts down by its own rule; false: one
## less at the end of each round, but the round the enemies put it on), harmful (shown in red)}.
const ALL := {
	&"might": {"name": "Might", "text": "Each hit deals %d more.", "lasts": true, "harmful": false},
	&"footing": {"name": "Footing", "text": "Each Block card gives %d more.", "lasts": true, "harmful": false},
	&"ward": {"name": "Ward", "text": "At the end of each of its turns, gains %d Block.", "lasts": true, "harmful": false},
	&"spines": {"name": "Spines", "text": "Whoever hits it loses %d health a hit.", "lasts": true, "harmful": false},
	&"frenzy": {"name": "Frenzy", "text": "At the end of each of its turns, gains %d Might.", "lasts": true, "harmful": false},
	&"exposed": {"name": "Exposed", "text": "Takes half again as much from hits, for %d turns.", "lasts": false, "harmful": true},
	&"weakened": {"name": "Weakened", "text": "Deals a quarter less with hits, for %d turns.", "lasts": false, "harmful": true},
	&"brittle": {"name": "Brittle", "text": "Gains a quarter less Block, for %d turns.", "lasts": false, "harmful": true},
	&"poison": {"name": "Poison", "text": "Loses %d health at the start of its turn, one less each time.", "lasts": false,
		"harmful": true},
	# What the player's cards meet (2026-11-27).
	&"entangled": {"name": "Entangled", "text": "Cannot play Attacks, for %d turns.", "lasts": false, "harmful": true},
	&"confused": {"name": "Confused", "text": "Every card drawn costs 0 to 3 at random, for %d turns.", "lasts": false,
		"harmful": true},
	# Enemies' traits: what punishes how the player plays.
	&"enrage": {"name": "Enrage", "text": "Whenever you play a Skill, it gains %d Might.", "lasts": true, "harmful": false},
	&"curiosity": {"name": "Curiosity", "text": "Whenever you play a Power, it gains %d Might.", "lasts": true, "harmful": false},
	&"overtime": {"name": "Overtime", "text": "Once you have played %d cards in a turn, your turn ends.", "lasts": true,
		"harmful": false},
	&"toll": {"name": "Toll", "text": "Whenever you play a card, you lose %d health.", "lasts": true, "harmful": false},
	&"reactive": {"name": "Reactive", "text": "Whenever an attack hits it, it changes what it will do.", "lasts": true,
		"harmful": false},
	&"asleep": {"name": "Asleep", "text": "Does nothing. Wakes when it loses health, or after %d more of its turns.", "lasts": true,
		"harmful": false},
	&"mode_shift": {"name": "Mode Shift", "text": "After losing %d more health, it curls up: Block and Spines for a while.",
		"lasts": true, "harmful": false},
	&"curled": {"name": "Curled Up", "text": "Curled up behind Block and Spines for %d more of its turns.", "lasts": true,
		"harmful": false},
	&"invincible": {"name": "Invincible", "text": "Loses no more than %d health a round.", "lasts": true, "harmful": false},
	# Enemies' traits: how a side fights together.
	&"command": {"name": "Command", "text": "While it stands, the rest of its side deal %d more a hit.", "lasts": true,
		"harmful": false},
	&"pack": {"name": "Pack", "text": "Whenever another of its side falls, it gains %d Might.", "lasts": true, "harmful": false},
	&"linked": {"name": "Linked", "text": "Fallen, it rises again %d turns later, unless all the Linked are down.", "lasts": true,
		"harmful": false},
	&"holding": {"name": "Holding", "text": "Holds %d of your cards, given back as it falls.", "lasts": true, "harmful": false},
	# Prometheus's hacking (the designer's twists, 2026-11-27).
	&"scanned": {"name": "Scanned", "text": "Its intent is shown, encrypted or not, for the rest of the fight.", "lasts": true,
		"harmful": true},
	&"glutton": {"name": "Glutton", "text": "Eats the cards it takes; a Status card chokes it, and it spits them all out. Each quarter of its health lost, one falls back out.",
		"lasts": true, "harmful": false},
}

## How much more an Exposed one takes, how much less a Weakened one deals and a Brittle one gains.
const EXPOSED_SHARE := 1.5
const WEAKENED_SHARE := 0.75
const BRITTLE_SHARE := 0.75


static func name_of(key: StringName) -> String:
	return ALL[key].name if ALL.has(key) else String(key).capitalize()


static func text_of(key: StringName, amount: int) -> String:
	if not ALL.has(key):
		return ""
	var text: String = ALL[key].text
	return text % amount if text.contains("%d") else text


static func lasts(key: StringName) -> bool:
	return ALL.has(key) and ALL[key].lasts


static func harmful(key: StringName) -> bool:
	return ALL.has(key) and ALL[key].harmful
