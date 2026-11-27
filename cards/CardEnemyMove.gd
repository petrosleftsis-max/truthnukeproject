extends Resource
class_name CardEnemyMove
## One move of an enemy in the card game: shown above it as its intent the turn before it does it (docs/card_game.md). Beside what
## it does, when it may be chosen (its limits, an opening move, a countdown) and how likely (its weight, leaning with the fight).

enum Intent { ATTACK, ATTACK_DEFEND, ATTACK_DEBUFF, DEFEND, BUFF, DEBUFF, DEFEND_BUFF, NOTHING }
## Whom its Block, Heal and status taken (Gain Status) go to.
enum Helps {
	## Itself.
	ITSELF,
	## The worst hurt of the others of its side (itself if it is alone).
	WORST_HURT_ALLY,
	## Everybody of its side, itself too.
	EVERY_ALLY,
}
## Where the cards it gives the player go.
enum Pile { DISCARD, DRAW, HAND }

@export var name := ""
## Damage a hit to the player, Hits times; its Might adds to each.
@export var damage := 0
@export var hits := 1
## Block it gains.
@export var block := 0
## A status on the player (CardStatus), and how much.
@export var apply_status: StringName = &""
@export var apply_amount := 0
## A status on itself, and how much.
@export var gain_status: StringName = &""
@export var gain_amount := 0
## How likely it is against its others, for an enemy that picks at random.
@export var weight := 1

@export_group("When it may be chosen")
## Its first move, always: an enemy introducing itself (the first of them marked, if several are).
@export var first := false
## Never chosen by its pattern: only by one of its rules (or as its first move). A mend for when an ally is hurt, a call for help
## when it is alone.
@export var rule_only := false
## Never twice running.
@export var not_twice_running := false
## At most this many times a fight; 0: no limit.
@export var most_times := 0
## Not before its turn this (its first is 1); 0: from the start.
@export var not_before_turn := 0
## Once used, this many of its turns pass before it can be chosen again; 0: none.
@export var cooldown := 0
## A countdown: once chosen it takes this many of its turns to land, doing nothing else, its intent counting down (2, 1) for the
## player to race it, brace for it or kill it first. 0: it lands on its turn, as any move.
@export var wind_up := 0
## Likelier while this holds (CardEnemyRule's When, with Lean Number and Lean Status): its weight times Lean Factor.
@export var lean_when: CardEnemyRule.When = CardEnemyRule.When.NEVER
@export var lean_number := 0
@export var lean_status: StringName = &""
@export var lean_factor := 3.0

@export_group("More it does")
## Whom its Block, Heal and status taken go to.
@export var helps: Helps = Helps.ITSELF
## Health it mends (whoever Helps names).
@export var heal := 0
## Cards it gives the player (a Status card's key in data/cards/: wound, dazed, slimed, burn), how many, and where they go.
@export var adds_card := ""
@export var adds_count := 1
@export var adds_to: Pile = Pile.DISCARD
## Cards it takes from the player's draw pile (else their discard pile), given back into their hand as it falls.
@export var steals := 0
## Enemies it calls into the fight (data/card_enemies/ keys), as many as there is room for (CardBattle.MOST_ENEMIES).
@export var summons: Array[String] = []
## More damage a hit for every card it holds (a Glutton's, the Devourer's: fuller, it hits harder). Only with Damage above 0.
@export var damage_per_held := 0
## A Tether of its own (a data/cards/ key, an Enemy Only Tether) it ties onto every player standing (twist 7): at the end of each of
## its turns it does its Effects to them and frays, and every CardDefinition.TETHER_BREAK_DAMAGE health it loses cuts a strand.
@export var ties := ""
## How many of each player's Tethers it cuts, the strongest first: gone, with no snap.
@export var cuts_tethers := 0


func intent() -> Intent:
	var attacks := damage > 0
	var debuffs := (apply_status != &"" and apply_amount > 0) or adds_card != "" or steals > 0 or ties != "" or cuts_tethers > 0
	var defends := block > 0
	var buffs := (gain_status != &"" and gain_amount > 0) or heal > 0 or not summons.is_empty()
	if attacks and defends:
		return Intent.ATTACK_DEFEND
	if attacks and debuffs:
		return Intent.ATTACK_DEBUFF
	if attacks:
		return Intent.ATTACK
	if defends and buffs:
		return Intent.DEFEND_BUFF
	if defends:
		return Intent.DEFEND
	if debuffs:
		return Intent.DEBUFF
	if buffs:
		return Intent.BUFF
	return Intent.NOTHING


static func of(move_name: String, hit: int = 0, hit_times: int = 1, gains_block: int = 0, gives: StringName = &"", gives_amount: int = 0,
		takes: StringName = &"", takes_amount: int = 0, chance: int = 1) -> CardEnemyMove:
	var move := CardEnemyMove.new()
	move.name = move_name
	move.damage = hit
	move.hits = hit_times
	move.block = gains_block
	move.apply_status = gives
	move.apply_amount = gives_amount
	move.gain_status = takes
	move.gain_amount = takes_amount
	move.weight = chance
	return move


## Its limits and its countdown in words, for the enemy's tooltip ("" for none).
func describe_limits() -> String:
	var parts: Array[String] = []
	if first:
		parts.append("its first move")
	if rule_only:
		parts.append("only when a rule says so")
	if not_twice_running:
		parts.append("never twice running")
	if most_times > 0:
		parts.append("at most %d time%s a fight" % [most_times, "" if most_times == 1 else "s"])
	if not_before_turn > 1:
		parts.append("not before its turn %d" % not_before_turn)
	if cooldown > 0:
		parts.append("then %d turn%s before again" % [cooldown, "" if cooldown == 1 else "s"])
	if wind_up > 0:
		parts.append("lands %d turns after it is shown" % (wind_up + 1))
	return ", ".join(parts)
