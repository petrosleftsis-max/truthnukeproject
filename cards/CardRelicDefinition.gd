extends Resource
class_name CardRelicDefinition
## A relic of the card game: kept for the whole run, it does its Effect at its moment (docs/card_game.md). One file in
## data/card_relics/.

enum When {
	## The moment it is picked up, once (most health, gold).
	PICKED_UP,
	## At the start of every fight, before the first hand is drawn.
	FIGHT_START,
	## At the start of the first turn of every fight, after the hand is drawn.
	FIRST_TURN,
	## At the start of every turn of the player's.
	TURN_START,
	## Whenever a fight is won.
	FIGHT_WON,
	## Whenever an enemy falls (Night Hunter).
	ENEMY_FALLS,
}
## BLESSING: one of the run's first choice, after the gate (twist 15); never in a chest or a shop.
enum Rarity { STARTER, COMMON, UNCOMMON, RARE, BLESSING }

@export var name := ""
@export var when: When = When.FIGHT_START
## What it does then. An Apply puts its status on every enemy.
@export var effect: CardEffect
@export var rarity: Rarity = Rarity.COMMON
## Its picture (a slot): none, and a stand-in.
@export var picture: Texture2D
@export_multiline var flavour := ""
## Held, every fight shows what each enemy means to do after the move it shows (docs/proposals_2026-11-27_card_ai.md, item 21):
## a plan, which its rules can still change.
@export var shows_next_moves := false
## Held, this many more Tethers can be held at once (twist 7: CardBattle.TETHER_SLOTS).
@export_range(0, 4) var more_tether_slots := 0
## Where it comes from in the main game, for its tooltip ("Cyrus's Night Hunter"); empty for none.
@export var learned_from := ""


## Whether it can turn up in a chest, a shop or an elite's reward (no starter, no Blessing).
func offered() -> bool:
	return rarity != Rarity.STARTER and rarity != Rarity.BLESSING


func describe() -> String:
	if more_tether_slots > 0 and effect == null:
		return "Hold %d more Tether%s at once." % [more_tether_slots, "" if more_tether_slots == 1 else "s"]
	if shows_next_moves and effect == null:
		return "In every fight, see what each enemy means to do after its next move."
	if effect == null:
		return ""
	var moment: String = ["When picked up", "At the start of each fight", "On the first turn of each fight",
		"At the start of each turn", "Whenever a fight is won", "Whenever an enemy falls"][when]
	var amount := effect.amount
	var what := ""
	match effect.kind:
		CardEffect.Kind.BLOCK:
			what = "gain %d Block" % amount
		CardEffect.Kind.DRAW:
			what = "draw %d more card%s" % [amount, "" if amount == 1 else "s"]
		CardEffect.Kind.ENERGY:
			what = "gain %d energy" % amount
		CardEffect.Kind.APPLY:
			what = "give every enemy %d %s" % [amount, CardStatus.name_of(effect.status)]
		CardEffect.Kind.GAIN:
			what = "gain %d %s" % [amount, CardStatus.name_of(effect.status)]
		CardEffect.Kind.HEAL:
			what = "mend %d health" % amount
		CardEffect.Kind.MAX_HP:
			what = "gain %d most health" % amount
		CardEffect.Kind.GOLD:
			what = "gain %d gold" % amount
		CardEffect.Kind.DAMAGE:
			what = "deal %d damage to every enemy" % amount
		_:
			what = "something"
	return "%s, %s." % [moment, what]
