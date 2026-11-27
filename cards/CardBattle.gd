extends RefCounted
class_name CardBattle
## One fight of the card game, rules only: no nodes, nothing drawn, so it runs the same in a suite (docs/card_game.md). The screen
## (CardGame) asks it what can be played, tells it what was, and listens to `changed`, `said` and `ended`.
##
## A turn: each player's Block goes, Poison bites, they draw HAND_SIZE and get their energy back, play cards, and end the turn
## (in co-op, each says Ready, and may take it back while the other still plays); the hands are discarded, every enemy loses its
## Block, and each in turn takes its Poison and does the move it showed. Then the round ends: what wears off counts down by one on
## everybody (but what the enemies put on that turn), and each enemy shows what it will do next. Hits are worked out by
## attack_damage and Block by block_gained.
##
## **Two players** (co-op, Slay the Spire 2's way; the designer, 2026-11-27): each has their own deck, piles, hand, energy, health,
## Block, statuses and relics (`players`); everything the one-player fight did reads the player playing now (`active`, and
## `player`, `hand`, `energy`... are theirs). The enemies hit everybody, each blocking for themselves, and have more health for it
## (COOP_LAYER_FACTOR) and more Block. A player at nothing is down for the rest of the fight; it is lost only when all are.
##
## How an enemy chooses (docs/card_game.md "How enemies choose"): its rules first (CardEnemyRule, by the fight's tier), then an
## opening move, then its pattern (the plan it made a turn earlier, which Second Sight shows), every move within its own limits
## (CardEnemyMove). What it shows is what it does but where one of its own traits says otherwise, and says so: Reactive, waking,
## curling up (Mode Shift), choking (Glutton), splitting, being seen at last. Encrypted ones show nothing until Scanned.
##
## Everything that happens is also told as it happens, one `beat` at a time, for the screen to play back in order (CardStage;
## docs/card_game.md "How it feels"). The rules never listen to their own beats and nothing in them waits: a suite plays a whole
## fight in a frame, as before.

signal changed
## Something happened worth a line ("The Rat bites for 6.").
signal said(text: String)
signal ended(won: bool)
## One thing that happened, for the screen: `what` is its kind and `info` what it needs. Whoever it happened to is `who` (and `from`
## and `to`): -1 for the first player and -2 for the second (who_of), an enemy's index, or NOBODY. A card is {key, upgraded, id}.
##
## - shuffled {count, start, player}: the discard pile shuffled into the draw pile (start: the deck at the start of the fight).
## - drawn {card, draw_left, discard_left, player}; discarded {cards, player}: the hand at the end of the turn; faded {cards,
##   player}: Ethereal cards exhausted from it first.
## - turn {turn}: the players' turn begins; enemy_turn {}: the enemies' does; ready {who, on}: a player's Ready; overtime {who,
##   player}: an enemy's Overtime ended a player's turn; down {who}: a player down for the fight.
## - played {card, index, target, type, all, player}; card_gone {card, to, player}: discard, exhaust or power; read {card}: a
##   half-read card's words, read at last.
## - energy {energy, change, player}; block {who, block, change}; status {who, key, before, after}; trace {gained}: the system
##   noticing (CardRun.trace).
## - hit {from, to, damage, blocked, lost, hp, block, max_hp, lethal, nth, of, sweep}: nth of `of` hits, sweep when it hits every
##   enemy; spines {from, to, lost, hp, max_hp, lethal}: whoever was hit biting back.
## - poison {who, lost, hp, max_hp, lethal}; heal {who, amount, hp, max_hp}; lose {who, lost, hp, max_hp, lethal, why}.
## - fell {who, last, rises}: an enemy down (last: the last of them; rises: the turns before it rises again, Linked, or 0).
## - move {who, name, intent, attacks}; move_done {who}; intent {who, intent, changed} (as intent_of says; changed: it changed its
##   mind, shown).
## - slept {who}; woke {who}; winding {who, name, left}; curled {who}; uncurled {who}; phase {who, line}; choked {who}.
## - given {from, cards, to, player}: cards it put in a player's `to` (discard, draw, hand); stolen {who, cards, player}: taken from
##   their draw pile; returned {who, cards, to}: given back (as it fell, choked, or one fell out of it).
## - joined {who, from}: an enemy come into the fight at `who` (from: who called it or split into it, or NOBODY), taking a fallen
##   one's place if `who` is in use; split {who}: it split and is gone; rising {who, left}; rose {who}.
## - relic {key, player}: a relic doing its thing; ended {won}.
## - Tethers (twist 7): card_gone's `to` is "tether" for one played (with `on`, whom it holds); tied {tether}; tether_did {tether,
##   snapping}; frayed {tether, strength}; snapped {tether, why}. A tether is {id, key, upgraded, holder, on, strength, most}.
signal beat(what: StringName, info: Dictionary)

const HAND_SIZE := 5
const HAND_MOST := 10
const ENERGY := 3
## How many Tethers each player holds at once (twist 7), more with a relic's More Tether Slots.
const TETHER_SLOTS := 2
## The most players at once (Coop.MAX_PLAYERS).
const MOST_PLAYERS := 2
## Who nobody is, in a beat.
const NOBODY := -99
## The most enemies standing at once: a summons or a split finds no room past it.
const MOST_ENEMIES := 4
## What a card drawn while Confused costs: from, to.
const CONFUSED_LEAST := 0
const CONFUSED_MOST := 3
## A run's Challenge (CardRun.challenge): from 1 enemies choose as in a fight one tier harder (their rules' From Tier), from 2 they
## have this much more health, from 3 they start every fight with this much Might.
const CHALLENGE_HEALTH := 0.1
const CHALLENGE_MIGHT := 1
## A deeper layer (the twist "down through a system's layers"; index 1 to 3): an encounter written for any layer has this much
## health and Might more there.
const LAYER_HEALTH := [1.0, 1.0, 1.25, 1.5]
const LAYER_MIGHT := [0, 0, 1, 2]
## In co-op an enemy has its health x the players x this, by layer (Slay the Spire 2's act factors), and its Block x the players.
const COOP_LAYER_FACTOR := [1.1, 1.1, 1.2, 1.3]
## The system's answers to its trace (CardRun.trace): from these, enemies start with a Might more each, and from the second a share
## more health.
const TRACE_MIGHT_FROM := [25, 50]
const TRACE_HEALTH_FROM := 50
const TRACE_HEALTH := 0.1

## The players: {name, hp, max_hp, block, statuses, fresh, block_at_end, draw_pile, hand, discard_pile, exhaust_pile, powers,
## energy, max_energy, cards_played, ready, down, relics, character}.
var players: Array = []
## Whose turn within the turn it is now: whom `player`, `hand`, `energy`... read, and whom a play is by.
var active := 0
## The player playing now (players[active]).
var player: Dictionary:
	get:
		return players[active]
	set(value):
		players[active] = value
var draw_pile: Array:
	get:
		return player.draw_pile
	set(value):
		player.draw_pile = value
var hand: Array:
	get:
		return player.hand
	set(value):
		player.hand = value
var discard_pile: Array:
	get:
		return player.discard_pile
	set(value):
		player.discard_pile = value
var exhaust_pile: Array:
	get:
		return player.exhaust_pile
	set(value):
		player.exhaust_pile = value
## Powers played this fight (gone from the deck until it is over).
var powers: Array:
	get:
		return player.powers
	set(value):
		player.powers = value
var energy: int:
	get:
		return int(player.energy)
	set(value):
		player.energy = value
var max_energy: int:
	get:
		return int(player.max_energy)
	set(value):
		player.max_energy = value
## Cards played this turn by the player now (Overtime).
var cards_played: int:
	get:
		return int(player.cards_played)
	set(value):
		player.cards_played = value
## The relics of the player now (keys), for their moments.
var relics: Array:
	get:
		return player.relics
	set(value):
		player.relics = value

## Each enemy: {key, definition, name, hp, max_hp, block, statuses, alive, move (CardEnemyMove, its next), history (move names), and
## what it chooses by: turns, used, last_used, cycle_at, planned, moves, pattern, rules, winding, countdown...}. A fallen one keeps
## its place, until a summons or a split takes it.
var enemies: Array = []
var turn := 0
var over := false
var won := false
var rng := RandomNumberGenerator.new()
## How hard a fight this is (CardRun sets it): a rule with a From Tier above it is not used.
var tier: CardEncounterDefinition.Tier = CardEncounterDefinition.Tier.EASY
## The run's Challenge (see the constants above).
var challenge := 0
## The layer of the system (1 to 3), and whether its enemies are made harder for it (an encounter for any layer).
var layer := 1
var scales_by_layer := false
## The run's trace as the fight begins (its answers: TRACE_*), and how much this fight added (loud cards).
var trace := 0
var trace_gained := 0
## The share of enemies whose intents are encrypted, shown only once Scanned (the twist "what the system lets him see").
var darkness := 0.0
## Second Sight (CardRelicDefinition.shows_next_moves, anybody's): each intent shows the plan after it.
var foresight := false
## The run's last boss (CardRun sets it): the Message says every word twice (twist 10, "the truth spoken").
var truth_spoken := false
## Every Tether on the table (twist 7): {id, key, upgraded, card (the card itself, the player's, back to their discard pile once it is
## gone; {} for an enemy's), holder (who_of: -1 or -2 a player, else an enemy's index), on (who_of of whom it holds), strength, most,
## hurt (health its enemy holder has lost towards its next strand)}.
var tethers: Array = []
var _next_tether := 0
## How many of the enemies' side have fallen this fight (CardEnemyRule.When.ALLY_FALLEN).
var fallen := 0
## Whether the enemies are taking their turn: a status that wears off and is put on during it skips the round's count down, so the
## Weakened a rat gives lasts the player's next turn rather than none of it.
var _enemies_acting := false
var _next_id := 0
## What an enemy shows while it sleeps, as it stirs (woken by a blow, it does nothing on its next turn), and as it chokes on a card
## it should not have eaten (Glutton).
var _asleep_move := CardEnemyMove.of("Asleep")
var _stirring_move := CardEnemyMove.of("Stirring")
var _choking_move := CardEnemyMove.of("Choking")


## A fight of `deck` (cards as {key, upgraded}) against `enemy_keys` (data/card_enemies/ keys, or CardEnemyDefinitions made in code),
## the (first) player at `hp` of `max_hp`, with `relic_keys`; `with_seed` makes it come out the same every time (0: any). A second
## player comes in with add_player, before start.
func _init(deck: Array, enemy_keys: Array, hp: int, max_hp: int, relic_keys: Array = [], with_seed: int = 0, player_name := "You"):
	if with_seed != 0:
		rng.seed = with_seed
	else:
		rng.randomize()
	players.append(_new_player(deck, hp, max_hp, relic_keys, player_name, ""))
	for key in enemy_keys:
		var definition: CardEnemyDefinition = key if key is CardEnemyDefinition else CardDatabase.enemy(str(key))
		if definition == null:
			push_warning("CardBattle: no enemy %s." % key)
			continue
		enemies.append(_new_enemy(definition, definition.name if key is CardEnemyDefinition else str(key)))
	_see_foresight()


func _new_player(deck: Array, hp: int, max_hp: int, relic_keys: Array, player_name: String, character: String) -> Dictionary:
	var made := {"name": player_name, "hp": hp, "max_hp": max_hp, "block": 0, "statuses": {}, "fresh": {}, "block_at_end": 0,
		"draw_pile": [], "hand": [], "discard_pile": [], "exhaust_pile": [], "powers": [], "energy": 0, "max_energy": ENERGY,
		"cards_played": 0, "ready": false, "down": false, "relics": relic_keys.duplicate(), "character": character}
	for card in deck:
		var copy := {"key": card.key, "upgraded": card.get("upgraded", false), "id": _next_id}
		# The Message's words go with it (the run's, shared: read here, never written).
		if card.has("message"):
			copy["message"] = card.message
		made.draw_pile.append(copy)
		_next_id += 1
	return made


## A second player (co-op), before start: their deck, health, relics and name. The enemies grow to meet two.
func add_player(deck: Array, hp: int, max_hp: int, relic_keys: Array = [], player_name := "Partner", character: String = "") -> int:
	if players.size() >= MOST_PLAYERS:
		return -1
	players.append(_new_player(deck, hp, max_hp, relic_keys, player_name, character))
	_see_foresight()
	_rescale_all()
	return players.size() - 1


func _see_foresight():
	foresight = false
	for each in players:
		for relic_key in each.relics:
			var relic := CardDatabase.relic(relic_key)
			if relic != null and relic.shows_next_moves:
				foresight = true


## Whether two play.
func together() -> bool:
	return players.size() > 1


## The players still standing (not down).
func standing() -> Array:
	return players.filter(func(each): return not each.down and each.hp > 0)


## The other player of `index`'s, or -1 alone.
func partner_of(index: int) -> int:
	return (1 - index) if together() and index >= 0 and index <= 1 else -1


## An enemy of `definition`, ready to fight: its health rolled, its traits on, its ways of choosing its own to change, and made as
## hard as this fight makes them (its layer, two players, the trace, the Challenge).
func _new_enemy(definition: CardEnemyDefinition, key: String, hp: int = -1) -> Dictionary:
	var rolled := rng.randi_range(definition.max_hp_least, maxi(definition.max_hp_least, definition.max_hp_most))
	var enemy := {"key": key, "definition": definition, "name": definition.name, "hp": rolled, "max_hp": rolled, "base_hp": rolled,
		"block": 0, "statuses": {}, "fresh": {}, "alive": true, "move": null, "history": [],
		"turns": 0, "used": {}, "last_used": {}, "cycle_at": 0, "planned": null, "planned_cycle_at": 0,
		"winding": false, "countdown": 0, "moves": definition.moves.duplicate(), "pattern": definition.pattern,
		"rules": definition.rules.duplicate(), "phases_started": [], "revealed": false, "curl_left": 0, "curl_spines": 0,
		"shift_next": 0, "held": [], "rising": -1, "lost_round": 0, "curled_move": CardEnemyMove.of("Curled Up", 0, 1, definition.curl_block),
		"encrypted": false, "base_might": 0, "spilled": 0}
	# Keyed as the rules read them, whether the file wrote "spines" or &"spines".
	for status in definition.starting_statuses:
		var amount := int(definition.starting_statuses[status])
		if amount > 0:
			enemy.statuses[StringName(status)] = amount
	enemy.shift_next = int(enemy.statuses.get(&"mode_shift", 0))
	enemy.base_might = int(enemy.statuses.get(&"might", 0))
	enemy.encrypted = darkness > 0.0 and rng.randf() < darkness
	_rescale(enemy)
	if hp >= 0:
		enemy.hp = mini(hp, int(enemy.max_hp))
	return enemy


## `enemy`'s most health and Might as this fight makes them: its own, by layer, for two, by the trace and by the Challenge.
func _rescale(enemy: Dictionary):
	var most := float(enemy.base_hp)
	var more_might := 0
	var at := clampi(layer, 1, 3)
	if scales_by_layer:
		most *= LAYER_HEALTH[at]
		more_might += LAYER_MIGHT[at]
	if together():
		most *= float(players.size()) * COOP_LAYER_FACTOR[at]
	if trace >= TRACE_HEALTH_FROM:
		most *= 1.0 + TRACE_HEALTH
	for from in TRACE_MIGHT_FROM:
		if trace >= from:
			more_might += 1
	if challenge >= 2:
		most *= 1.0 + CHALLENGE_HEALTH
	if challenge >= 3:
		more_might += CHALLENGE_MIGHT
	enemy.max_hp = maxi(int(ceil(most - 0.0001)), 1)
	enemy.hp = enemy.max_hp
	var might := int(enemy.base_might) + more_might
	if might > 0:
		enemy.statuses[&"might"] = might
	else:
		enemy.statuses.erase(&"might")


## Every enemy made again as hard as the fight now says (before it starts: a setting changed).
func _rescale_all():
	for enemy in enemies:
		_rescale(enemy)


## The run's Challenge (CardRun.challenge), set as the fight is made, before the screen shows it: from 1 the enemies choose as in a
## fight a tier harder, from 2 they have more health, from 3 they start with Might.
func set_challenge(level: int):
	challenge = maxi(level, 0)
	_rescale_all()


## The layer of the system (1 to 3): an encounter written for any layer (`by_layer`) is made harder the deeper it is.
func set_layer(at: int, by_layer: bool = true):
	layer = clampi(at, 1, 3)
	scales_by_layer = by_layer
	_rescale_all()


## The run's trace as the fight begins: its answers (more Might, more health) on the enemies.
func set_trace(amount: int):
	trace = clampi(amount, 0, 100)
	_rescale_all()


## The share of enemies whose intents are encrypted until Scanned.
func set_darkness(share: float):
	darkness = clampf(share, 0.0, 1.0)
	for enemy in enemies:
		enemy.encrypted = darkness > 0.0 and rng.randf() < darkness


## Shuffles the decks, sets the relics of the start off, shows what the enemies will do and starts the first turn.
func start():
	for p in players.size():
		active = p
		_shuffle(draw_pile)
		beat.emit(&"shuffled", {"count": draw_pile.size(), "start": true, "player": p})
		_relics_at(CardRelicDefinition.When.FIGHT_START)
	active = 0
	for enemy in enemies:
		_choose_move(enemy)
	_start_turn()


func _start_turn():
	turn += 1
	for enemy in enemies:
		enemy.lost_round = 0
	beat.emit(&"turn", {"turn": turn})
	for p in players.size():
		active = p
		if player.down:
			continue
		cards_played = 0
		player.ready = false
		# Block goes as each turn begins - but the first, which keeps what the fight's start gave (Iron Buckle, a gate's Iron Hide).
		if turn > 1:
			_set_block(player, 0)
		_poison(player)
		if _check_end():
			active = 0
			return
		if player.down:
			continue
		_set_energy(max_energy)
		draw(HAND_SIZE)
		if turn == 1:
			_relics_at(CardRelicDefinition.When.FIRST_TURN)
		_relics_at(CardRelicDefinition.When.TURN_START)
	active = _first_standing()
	changed.emit()


## The first player still standing (the one whose hand a turn opens on), or 0.
func _first_standing() -> int:
	for p in players.size():
		if not players[p].down and players[p].hp > 0:
			return p
	return 0


## Draws `count` cards for the player now, shuffling the discard pile in when the draw pile runs out; never past HAND_MOST.
## Confused, each costs at random.
func draw(count: int):
	for i in count:
		if hand.size() >= HAND_MOST:
			return
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				return
			draw_pile = discard_pile
			discard_pile = []
			_shuffle(draw_pile)
			beat.emit(&"shuffled", {"count": draw_pile.size(), "start": false, "player": active})
		var card: Dictionary = draw_pile.pop_back()
		if int(player.statuses.get(&"confused", 0)) > 0:
			card["cost_now"] = rng.randi_range(CONFUSED_LEAST, CONFUSED_MOST)
		hand.append(card)
		beat.emit(&"drawn", {"card": card, "draw_left": draw_pile.size(), "discard_left": discard_pile.size(), "player": active})


## What `card` (of the hand) costs now: its own cost, or what being Confused made it.
func cost_of(card: Dictionary) -> int:
	if card.has("cost_now"):
		return int(card.cost_now)
	var definition := CardDatabase.card(card.key)
	if definition == null:
		return 0
	# The Message: what the run has made it cost (spoken lighter).
	if card.has("message"):
		return int(card.message.get("cost", definition.cost_for(card.upgraded)))
	return definition.cost_for(card.upgraded)


## Why the card at `index` in the hand of the player now cannot be played at enemy `who` (-1 for none), or "" if it can.
func refusal(index: int, who: int = -1) -> String:
	if over:
		return "The fight is over."
	if player.down:
		return "You are down for this fight."
	if index < 0 or index >= hand.size():
		return "No such card."
	var card: Dictionary = hand[index]
	var definition := CardDatabase.card(card.key)
	if definition == null:
		return "An unknown card."
	if definition.unplayable:
		return "It cannot be played."
	if definition.type == CardDefinition.Type.ATTACK and int(player.statuses.get(&"entangled", 0)) > 0:
		return "Entangled: no Attacks this turn."
	if cost_of(card) > energy:
		return "Not enough energy."
	if definition.target == CardDefinition.Target.ENEMY and (who < 0 or who >= enemies.size() or not enemies[who].alive):
		return "Choose an enemy."
	# A Tether needs a free slot, unless it renews one already held on the same target (twist 7).
	if definition.type == CardDefinition.Type.TETHER and _renewing(card.key, _tether_target(definition, who)).is_empty() \
			and tethers_held_by(who_of(player)).size() >= tether_slots(active):
		return "Your Tethers are all held: let one go first."
	return ""


## Whether the card at `index` needs an enemy chosen.
func needs_target(index: int) -> bool:
	if index < 0 or index >= hand.size():
		return false
	var definition := CardDatabase.card(hand[index].key)
	return definition != null and definition.target == CardDefinition.Target.ENEMY


## Plays player `by`'s card `id` (its id, the same on both machines of a network game), at enemy `who`. False if it is not in their
## hand or cannot be played.
func play_card_id(by: int, id: int, who: int = -1) -> bool:
	if by < 0 or by >= players.size():
		return false
	for i in players[by].hand.size():
		if int(players[by].hand[i].id) == id:
			return play_as(by, i, who)
	return false


## Plays the card at `index` of player `by`'s hand (a move of theirs from the other machine), as play does.
func play_as(by: int, index: int, who: int = -1) -> bool:
	if by < 0 or by >= players.size():
		return false
	var was := active
	active = by
	var played := play(index, who)
	active = was if not over else active
	return played


## Plays the card at `index` of the hand of the player now at enemy `who`. False if it cannot be (refusal says why). A Ready player
## playing one is playing again (Ready taken back).
func play(index: int, who: int = -1) -> bool:
	if refusal(index, who) != "":
		return false
	var by := active
	var card: Dictionary = hand[index]
	var definition := CardDatabase.card(card.key)
	var cost := cost_of(card)
	if player.ready:
		_set_ready_flag(by, false)
	hand.remove_at(index)
	card.erase("cost_now")
	beat.emit(&"played", {"card": card, "index": index, "target": who if definition.target == CardDefinition.Target.ENEMY else -1,
		"type": definition.type, "all": definition.target == CardDefinition.Target.ALL_ENEMIES, "player": by})
	_set_energy(energy - cost)
	said.emit("%s %s %s." % [player.name, "play" if player.name == "You" else "plays", definition.name_for(card.upgraded)])
	var gone_to := &"discard"
	if definition.type == CardDefinition.Type.TETHER:
		# A Tether does nothing as it is played: it takes hold, and works at the end of each of its holder's turns (twist 7).
		gone_to = &"tether"
		beat.emit(&"card_gone", {"card": card, "to": gone_to, "player": by, "on": _tether_target(definition, who)})
		_tie(card, definition, who_of(player), _tether_target(definition, who))
	else:
		for effect in definition.effects:
			active = by
			_card_effect(effect, card.upgraded, definition, who)
			if over:
				break
		# The Message (twist 10): its words, as the run wrote them; at the run's last boss, every one of them twice.
		if not over and card.has("message"):
			for spoken in (2 if truth_spoken else 1):
				for word in card.message.get("words", []):
					var effect: CardEffect = word.get("effect")
					if effect == null or over:
						continue
					active = by
					_card_effect(effect, false, definition, who, int(word.get("amount", effect.amount)))
		active = by
		if definition.type == CardDefinition.Type.POWER:
			powers.append(card)
			gone_to = &"power"
		elif definition.exhausts:
			exhaust_pile.append(card)
			gone_to = &"exhaust"
		else:
			discard_pile.append(card)
		beat.emit(&"card_gone", {"card": card, "to": gone_to, "player": by})
	# Half-read code: its words read at last, for good (CardUnlocks).
	if definition.half_read() and not CardUnlocks.read(card.key):
		CardUnlocks.mark_read(card.key)
		beat.emit(&"read", {"card": card})
	if definition.trace > 0:
		trace_gained += definition.trace
		beat.emit(&"trace", {"gained": definition.trace})
	var turn_was := turn
	if not _check_end():
		_after_a_card(definition)
	# A player down by their own card (its cost, a Toll, Spines) with the other Ready: the enemies' turn.
	if not over and turn == turn_was and together() and _all_ready():
		end_turn()
	if not over and turn == turn_was:
		active = by
	changed.emit()
	return true


## What the enemies' traits make of a card the player now played: Enrage and Curiosity grow, Toll bites, and Overtime ends that
## player's turn.
func _after_a_card(definition: CardDefinition):
	var by := active
	cards_played += 1
	var toll := 0
	var limit := 0
	var clock := {}
	for enemy in enemies:
		if not enemy.alive:
			continue
		if definition.type == CardDefinition.Type.SKILL and int(enemy.statuses.get(&"enrage", 0)) > 0:
			add_status(enemy, &"might", int(enemy.statuses.get(&"enrage", 0)))
		if definition.type == CardDefinition.Type.POWER and int(enemy.statuses.get(&"curiosity", 0)) > 0:
			add_status(enemy, &"might", int(enemy.statuses.get(&"curiosity", 0)))
		toll += int(enemy.statuses.get(&"toll", 0))
		var overtime := int(enemy.statuses.get(&"overtime", 0))
		if overtime > 0 and (limit == 0 or overtime < limit):
			limit = overtime
			clock = enemy
	if toll > 0:
		_lose_health(players[by], toll, &"toll")
		if _check_end():
			return
	if limit > 0 and players[by].cards_played >= limit and not over and not players[by].down:
		said.emit("Overtime: %s turn is over." % ("your" if not together() else players[by].name + "'s"))
		beat.emit(&"overtime", {"who": who_of(clock), "player": by})
		if together():
			set_ready(by, true)
		else:
			end_turn()


## One effect of a card played by the player now at enemy `who`; `amount_now` (0 or more) in place of the effect's own (the
## Message's words, grown by the run).
func _card_effect(effect: CardEffect, upgraded: bool, definition: CardDefinition, who: int, amount_now: int = -1):
	var amount := effect.amount_for(upgraded) if amount_now < 0 else amount_now
	var targets: Array = []
	if definition.target == CardDefinition.Target.ALL_ENEMIES:
		targets = enemies.filter(func(enemy): return enemy.alive)
	elif who >= 0 and who < enemies.size():
		targets = [enemies[who]]
	# A card for your partner: what it gives goes to them (to yourself alone, or with them down).
	var by := active
	if definition.target == CardDefinition.Target.ALLY and effect.kind in [CardEffect.Kind.BLOCK, CardEffect.Kind.HEAL,
			CardEffect.Kind.DRAW, CardEffect.Kind.ENERGY, CardEffect.Kind.GAIN]:
		var partner := partner_of(by)
		if partner >= 0 and not players[partner].down:
			active = partner
	match effect.kind:
		CardEffect.Kind.DAMAGE:
			var hits := effect.times_for(upgraded)
			for hit in hits:
				for enemy in targets:
					if enemy.alive and players[by].hp > 0:
						_hit(players[by], enemy, amount, hit, hits, targets.size() > 1)
		CardEffect.Kind.BLOCK:
			_set_block(player, player.block + block_gained(player, amount))
		CardEffect.Kind.DRAW:
			draw(amount)
		CardEffect.Kind.ENERGY:
			_set_energy(energy + amount)
		CardEffect.Kind.APPLY:
			for enemy in targets:
				if enemy.alive:
					add_status(enemy, effect.status, amount)
		CardEffect.Kind.GAIN:
			add_status(player, effect.status, amount)
		CardEffect.Kind.HEAL:
			_heal(player, amount)
		CardEffect.Kind.LOSE_HP:
			_lose_health(player, amount)
		CardEffect.Kind.DRAIN:
			for enemy in targets:
				if enemy.alive:
					_drain(player, enemy, amount)
	active = by


## How much a hit of `base` from `attacker` does to `defender` before Block: Might added (and the Command of the attacker's side),
## a quarter off if Weakened, half again if the defender is Exposed. `defender` may be empty (no one in particular).
func attack_damage(attacker: Dictionary, defender: Dictionary, base: int) -> int:
	var damage := float(base + int(attacker.statuses.get(&"might", 0)) + _command_for(attacker))
	if int(attacker.statuses.get(&"weakened", 0)) > 0:
		damage *= CardStatus.WEAKENED_SHARE
	if not defender.is_empty() and int(defender.statuses.get(&"exposed", 0)) > 0:
		damage *= CardStatus.EXPOSED_SHARE
	return maxi(0, int(floor(damage)))


## What the others of `attacker`'s side command it to deal more (Command), while they stand. Nothing for a player.
func _command_for(attacker: Dictionary) -> int:
	if not attacker.has("alive"):
		return 0
	var more := 0
	for other in enemies:
		if other.alive and not is_same(other, attacker):
			more += int(other.statuses.get(&"command", 0))
	return more


## How much Block `who` gets from `base`: Footing added, a quarter less if Brittle.
func block_gained(who: Dictionary, base: int) -> int:
	var block := float(base + int(who.statuses.get(&"footing", 0)))
	if int(who.statuses.get(&"brittle", 0)) > 0:
		block *= CardStatus.BRITTLE_SHARE
	return maxi(0, int(floor(block)))


## Block an enemy gains from `base`: as block_gained, and twice as much with two players (Slay the Spire 2's).
func _enemy_block(enemy: Dictionary, base: int) -> int:
	return block_gained(enemy, base) * (players.size() if together() else 1)


## One hit: Block first, then health; Spines bite back. `nth` of `of` hits; `sweep` when the card hits every enemy (for the screen).
func _hit(attacker: Dictionary, defender: Dictionary, base: int, nth: int = 0, of: int = 1, sweep: bool = false):
	var damage := attack_damage(attacker, defender, base)
	var blocked := mini(defender.block, damage)
	defender.block -= blocked
	var loss := _capped(defender, damage - blocked)
	var left := maxi(0, defender.hp - loss)
	beat.emit(&"hit", {"from": who_of(attacker), "to": who_of(defender), "damage": damage, "blocked": blocked, "lost": defender.hp - left,
		"hp": left, "block": defender.block, "max_hp": defender.max_hp, "lethal": left <= 0 and defender.hp > 0, "nth": nth, "of": of,
		"sweep": sweep})
	_lose(defender, loss)
	var spines := int(defender.statuses.get(&"spines", 0))
	if spines > 0:
		var after := maxi(0, attacker.hp - spines)
		beat.emit(&"spines", {"from": who_of(defender), "to": who_of(attacker), "lost": attacker.hp - after, "hp": after,
			"max_hp": attacker.max_hp, "lethal": after <= 0 and attacker.hp > 0})
		_lose(attacker, spines)
	if not attacker.has("alive") and defender.has("alive") and defender.alive:
		_struck(defender)


## An enemy just hit by an attack: seen at last (Once Hit), or changing its mind (Reactive).
func _struck(enemy: Dictionary):
	var definition: CardEnemyDefinition = enemy.definition
	if definition.shows == CardEnemyDefinition.Shows.ONCE_HIT and not enemy.revealed:
		enemy.revealed = true
		beat.emit(&"intent", {"who": who_of(enemy), "intent": intent_of(enemy), "changed": false})
	if int(enemy.statuses.get(&"reactive", 0)) > 0 and not enemy.move in [_asleep_move, _stirring_move, _choking_move] \
			and int(enemy.curl_left) <= 0:
		var was: CardEnemyMove = enemy.move
		enemy.winding = false
		enemy.countdown = 0
		enemy.move = _decide(enemy, was.name if was != null else "")
		_after_deciding(enemy)
		if enemy.move != was:
			said.emit("%s changes what it will do." % enemy.name)
		beat.emit(&"intent", {"who": who_of(enemy), "intent": intent_of(enemy), "changed": enemy.move != was})


## `amount` health off `who`, Block or not, as one thing the screen shows (a card's cost, a Toll, a Burn).
func _lose_health(who: Dictionary, amount: int, why: StringName = &""):
	var loss := _capped(who, amount)
	if loss <= 0:
		return
	var left := maxi(0, who.hp - loss)
	beat.emit(&"lose", {"who": who_of(who), "lost": who.hp - left, "hp": left, "max_hp": who.max_hp, "lethal": left <= 0 and who.hp > 0,
		"why": why})
	_lose(who, loss)


## As much of `amount` as `who` can lose this round: all of it, but what Invincible holds back.
func _capped(who: Dictionary, amount: int) -> int:
	var most := int(who.statuses.get(&"invincible", 0))
	if most <= 0 or not who.has("lost_round"):
		return maxi(amount, 0)
	return clampi(amount, 0, maxi(most - int(who.lost_round), 0))


func _lose(who: Dictionary, amount: int):
	amount = _capped(who, amount)
	if amount <= 0:
		return
	who.hp = maxi(0, who.hp - amount)
	if who.has("lost_round"):
		who.lost_round = int(who.lost_round) + amount
	if not who.has("alive"):
		# A player at nothing: down for the rest of the fight while the other stands (co-op).
		if who.hp <= 0 and together() and not who.get("down", false):
			_down(who)
		return
	if who.hp <= 0 and who.alive:
		_falls(who)
		return
	if not who.alive:
		return
	# Losing health wakes a sleeper, brings a curl nearer, makes a glutton spill, and can start a phase.
	if int(who.statuses.get(&"asleep", 0)) > 0:
		_woken(who)
	var shift := int(who.statuses.get(&"mode_shift", 0))
	if shift > 0 and int(who.curl_left) <= 0:
		add_status(who, &"mode_shift", -mini(amount, shift))
		if int(who.statuses.get(&"mode_shift", 0)) <= 0:
			_curl(who)
	_spills(who)
	_strain_tethers(who, amount)
	_check_phases(who)


## Player `who` is down: out of this fight (their hand gone), back on their feet after it if the other wins it.
func _down(who: Dictionary):
	who.down = true
	who.ready = true
	who.block = 0
	var p := players.find(who)
	said.emit("%s is down!" % who.name)
	beat.emit(&"down", {"who": who_of(who)})
	_loosen(who_of(who))
	if not who.hand.is_empty():
		beat.emit(&"discarded", {"cards": who.hand.duplicate(), "player": p})
		who.discard_pile.append_array(who.hand)
		who.hand.clear()
	# With them down, the other's Ready may be all that is wanted: play() and set_ready see to it (_all_ready).


## Whether everybody still standing has said Ready (co-op): then the enemies take their turn.
func _all_ready() -> bool:
	var up := standing()
	return not up.is_empty() and up.all(func(each): return each.ready)


## `enemy` falls: for good, or down for a while (Linked, with another Linked standing). Its Pack grows, what it held comes back.
func _falls(enemy: Dictionary):
	enemy.alive = false
	enemy.block = 0
	enemy.winding = false
	fallen += 1
	var linked := int(enemy.statuses.get(&"linked", 0))
	var others_linked := enemies.any(func(other): return other.alive and int(other.statuses.get(&"linked", 0)) > 0)
	enemy.rising = linked if linked > 0 and others_linked else -1
	if linked > 0 and not others_linked:
		# All the Linked down at once: none of them rises.
		for other in enemies:
			if int(other.statuses.get(&"linked", 0)) > 0:
				other.rising = -1
	said.emit("%s falls%s." % [enemy.name, " - for now" if int(enemy.rising) > 0 else ""])
	beat.emit(&"fell", {"who": who_of(enemy), "last": enemies.all(func(other): return not other.alive), "rises": maxi(int(enemy.rising), 0)})
	# Whatever it held, and whatever held it, goes loose (twist 7).
	_loosen(who_of(enemy))
	# Night Hunter and its kind (a relic Whenever An Enemy Falls), for every player standing.
	if not enemies.all(func(other): return not other.alive):
		var was := active
		for p in players.size():
			if not players[p].down and players[p].hp > 0:
				active = p
				_relics_at(CardRelicDefinition.When.ENEMY_FALLS)
		active = was
	if not enemy.held.is_empty():
		_give_back(enemy, enemy.held.duplicate(), true)
		enemy.held.clear()
		enemy.statuses.erase(&"holding")
		said.emit("%s lets go of what it took." % enemy.name)
	for other in enemies:
		if other.alive and not is_same(other, enemy) and int(other.statuses.get(&"pack", 0)) > 0:
			add_status(other, &"might", int(other.statuses.get(&"pack", 0)))


## Cards `enemy` held back to their owners: into their hands while there is room (`to_hand`), else their discard piles.
func _give_back(enemy: Dictionary, cards: Array, to_hand: bool):
	var all_in_hand := true
	for card in cards:
		var owner: int = clampi(int(card.get("owner", 0)), 0, players.size() - 1)
		var whose: Dictionary = players[owner]
		card.erase("owner")
		if to_hand and whose.hand.size() < HAND_MOST and not whose.down:
			whose.hand.append(card)
		else:
			whose.discard_pile.append(card)
			all_in_hand = false
	beat.emit(&"returned", {"who": who_of(enemy), "cards": cards, "to": &"hand" if to_hand and all_in_hand else &"discard"})


## `who` mends `amount`, up to their most.
func _heal(who: Dictionary, amount: int):
	var before: int = who.hp
	who.hp = mini(who.max_hp, who.hp + amount)
	if who.hp > before:
		beat.emit(&"heal", {"who": who_of(who), "amount": who.hp - before, "hp": who.hp, "max_hp": who.max_hp})


## Sets `who`'s Block, telling the screen.
func _set_block(who: Dictionary, value: int):
	var before: int = who.block
	who.block = maxi(value, 0)
	if who.block != before:
		beat.emit(&"block", {"who": who_of(who), "block": who.block, "change": who.block - before})


## Sets the energy left this turn of the player now, telling the screen.
func _set_energy(value: int):
	var before := energy
	energy = maxi(value, 0)
	if energy != before:
		beat.emit(&"energy", {"energy": energy, "change": energy - before, "player": active})


## Who `fighter` is to the screen: -1 the first player, -2 the second, else an enemy's index (NOBODY for nobody of this fight).
func who_of(fighter: Dictionary) -> int:
	for p in players.size():
		if is_same(players[p], fighter):
			return -1 - p
	for i in enemies.size():
		if is_same(enemies[i], fighter):
			return i
	return NOBODY


## The player a `who` of the screen's is (0, 1), or -1 for an enemy or nobody.
static func player_index(who: int) -> int:
	return -1 - who if who < 0 and who >= -MOST_PLAYERS else -1


func add_status(who: Dictionary, key: StringName, amount: int):
	if key == &"" or amount == 0:
		return
	var before := int(who.statuses.get(key, 0))
	var now := before + amount
	if now <= 0:
		who.statuses.erase(key)
		who.fresh.erase(key)
	else:
		who.statuses[key] = now
		if amount > 0 and not CardStatus.lasts(key) and _enemies_acting:
			who.fresh[key] = true
	if maxi(now, 0) != before:
		beat.emit(&"status", {"who": who_of(who), "key": key, "before": before, "after": maxi(now, 0)})
	# Scanned: what it will do is seen at once (twist 6).
	if key == &"scanned" and before <= 0 and now > 0 and who.has("alive") and who.alive:
		beat.emit(&"intent", {"who": who_of(who), "intent": intent_of(who), "changed": true})


## Poison at the start of `who`'s turn: it loses that much, block or not, and the poison weakens by one.
func _poison(who: Dictionary):
	var poison := int(who.statuses.get(&"poison", 0))
	if poison <= 0:
		return
	said.emit("%s loses %d to poison." % [who.name, poison])
	var loss := _capped(who, poison)
	var left := maxi(0, who.hp - loss)
	beat.emit(&"poison", {"who": who_of(who), "lost": who.hp - left, "hp": left, "max_hp": who.max_hp, "lethal": left <= 0 and who.hp > 0})
	_lose(who, loss)
	add_status(who, &"poison", -1)


## The end of `who`'s turn: Ward's block and Frenzy's might.
func _end_of_turn_statuses(who: Dictionary):
	var ward := int(who.statuses.get(&"ward", 0))
	if ward > 0:
		# Flat, as Ward always was; an enemy's twice over with two players, as all its Block is.
		_set_block(who, who.block + ward * (players.size() if who.has("alive") and together() else 1))
	var frenzy := int(who.statuses.get(&"frenzy", 0))
	if frenzy > 0:
		add_status(who, &"might", frenzy)


## The end of a round, once the enemies have acted: what wears off counts down by one on everybody, but what the enemies put on
## during their turn, which has not had its round yet.
func _end_of_round():
	for who in players.filter(func(each): return not each.down) + enemies.filter(func(enemy): return enemy.alive):
		for key in who.statuses.keys():
			if key == &"poison" or CardStatus.lasts(key):
				continue
			if who.fresh.has(key):
				who.fresh.erase(key)
				continue
			add_status(who, key, -1)


## Player `p`'s Ready (co-op): on, they are done for this turn unless they take it back; with every player standing Ready, the
## enemies take their turn. Alone, Ready is ending the turn.
func set_ready(p: int, on: bool = true):
	if over or p < 0 or p >= players.size() or players[p].down:
		return
	if not together():
		if on:
			end_turn()
		return
	_set_ready_flag(p, on)
	if on and _all_ready():
		end_turn()


func _set_ready_flag(p: int, on: bool):
	if bool(players[p].ready) == on:
		return
	players[p].ready = on
	beat.emit(&"ready", {"who": -1 - p, "on": on})


## The players are done: what burns in their hands burns and what is Ethereal fades, the hands go to the discard piles, the
## enemies take their turns (one called or split into this turn waits for the next), the fallen Linked rise, and the round ends.
func end_turn():
	if over:
		return
	var was := active
	for p in players.size():
		active = p
		if player.down:
			continue
		player.block_at_end = player.block
		var burning := 0
		for card in hand:
			var definition := CardDatabase.card(card.key)
			if definition != null and definition.burns > 0:
				burning += definition.burns
		if burning > 0:
			said.emit("%s burn%s for %d." % [player.name, "" if player.name == "You" else "s", burning])
			_lose_health(player, burning, &"burn")
			if _check_end():
				return
			if player.down:
				continue
		var faded := hand.filter(func(card): return CardDatabase.card(card.key) != null and CardDatabase.card(card.key).ethereal)
		if not faded.is_empty():
			for card in faded:
				hand.erase(card)
				card.erase("cost_now")
				exhaust_pile.append(card)
			beat.emit(&"faded", {"cards": faded.duplicate(), "player": p})
		for card in hand:
			card.erase("cost_now")
		beat.emit(&"discarded", {"cards": hand.duplicate(), "player": p})
		discard_pile.append_array(hand)
		hand.clear()
		_end_of_turn_statuses(player)
		# Their Tethers do their thing and fray (twist 7).
		_tether_turn(-1 - p)
		if _check_end():
			return
	active = was
	beat.emit(&"enemy_turn", {})
	_enemies_acting = true
	# Their Block goes as their turn begins, all of them at once: Block one gives another lasts until the enemies' next turn.
	for enemy in enemies:
		if enemy.alive:
			_set_block(enemy, 0)
	for enemy in enemies.duplicate():
		if not enemy.alive:
			continue
		_poison(enemy)
		if _check_end():
			_enemies_acting = false
			return
		if not enemy.alive:
			continue
		_act(enemy)
		if _check_end():
			_enemies_acting = false
			return
		if enemy.alive:
			_end_of_turn_statuses(enemy)
			# Its Tethers on the players do their thing and fray (twist 7).
			_tether_turn(who_of(enemy))
			if _check_end():
				_enemies_acting = false
				return
		beat.emit(&"move_done", {"who": who_of(enemy)})
	_rising()
	_end_of_round()
	_enemies_acting = false
	for enemy in enemies:
		if enemy.alive:
			_choose_move(enemy)
	_start_turn()


## One enemy's turn: asleep it sleeps, curled it holds, winding it counts down, choking it splutters; else it does the move it showed.
func _act(enemy: Dictionary):
	var definition: CardEnemyDefinition = enemy.definition
	enemy.turns = int(enemy.turns) + 1
	if enemy.move == _asleep_move or int(enemy.statuses.get(&"asleep", 0)) > 0:
		said.emit("%s sleeps." % enemy.name)
		beat.emit(&"slept", {"who": who_of(enemy)})
		if definition.sleep_block > 0:
			_set_block(enemy, enemy.block + definition.sleep_block * (players.size() if together() else 1))
		add_status(enemy, &"asleep", -1)
		if int(enemy.statuses.get(&"asleep", 0)) <= 0:
			said.emit("%s wakes." % enemy.name)
			beat.emit(&"woke", {"who": who_of(enemy)})
		return
	if enemy.move == _stirring_move or enemy.move == _choking_move:
		said.emit("%s %s." % [enemy.name, "shakes off its sleep" if enemy.move == _stirring_move else "chokes"])
		beat.emit(&"move", {"who": who_of(enemy), "name": enemy.move.name, "intent": CardEnemyMove.Intent.NOTHING, "attacks": false})
		return
	if int(enemy.curl_left) > 0:
		beat.emit(&"move", {"who": who_of(enemy), "name": "Curled Up", "intent": CardEnemyMove.Intent.DEFEND, "attacks": false})
		said.emit("%s stays curled up." % enemy.name)
		_set_block(enemy, enemy.block + _enemy_block(enemy, definition.curl_block))
		enemy.curl_left = int(enemy.curl_left) - 1
		add_status(enemy, &"curled", -1)
		if int(enemy.curl_left) <= 0:
			_uncurl(enemy)
		return
	if enemy.winding and int(enemy.countdown) > 0:
		enemy.countdown = int(enemy.countdown) - 1
		var move: CardEnemyMove = enemy.move
		said.emit("%s winds up: %s in %d." % [enemy.name, move.name if move != null else "?", int(enemy.countdown) + 1])
		beat.emit(&"winding", {"who": who_of(enemy), "name": move.name if move != null else "", "left": int(enemy.countdown) + 1})
		return
	enemy.winding = false
	_do_move(enemy)


func _do_move(enemy: Dictionary):
	var move: CardEnemyMove = enemy.move
	if move == null:
		return
	beat.emit(&"move", {"who": who_of(enemy), "name": move.name, "intent": move.intent(), "attacks": move.damage > 0})
	enemy.history.append(move.name)
	enemy.used[move.name] = int(enemy.used.get(move.name, 0)) + 1
	enemy.last_used[move.name] = int(enemy.turns)
	var helped := _helped(enemy, move)
	if move.block > 0:
		for who in helped:
			_set_block(who, who.block + _enemy_block(who, move.block))
	if move.heal > 0:
		for who in helped:
			_heal(who, move.heal)
	var base: int = move.damage + move.damage_per_held * int(enemy.held.size())
	if base > 0 and move.damage > 0:
		var first: Dictionary = standing()[0] if not standing().is_empty() else player
		var each := attack_damage(enemy, first, base)
		said.emit("%s: %s, %d%s." % [enemy.name, move.name, each, (" x%d" % move.hits) if move.hits > 1 else ""])
		# It hits everybody standing, each blocking for themselves.
		for hit in move.hits:
			for target in standing():
				if target.hp > 0 and enemy.alive:
					_hit(enemy, target, base, hit, move.hits)
	else:
		said.emit("%s: %s." % [enemy.name, move.name])
	if over or not enemy.alive or standing().is_empty():
		return
	if move.apply_status != &"" and move.apply_amount > 0:
		for target in standing():
			add_status(target, move.apply_status, move.apply_amount)
	if move.gain_status != &"" and move.gain_amount > 0:
		for who in helped:
			add_status(who, move.gain_status, move.gain_amount)
	var was := active
	for p in players.size():
		if players[p].down:
			continue
		active = p
		if move.adds_card != "" and move.adds_count > 0:
			_give_cards(enemy, move.adds_card, move.adds_count, move.adds_to)
		if move.steals > 0 and enemy.alive:
			_steal(enemy, move.steals)
	active = was
	# Its Tether tied onto everybody standing; theirs cut, the strongest first (twist 7).
	if move.ties != "" and enemy.alive:
		for target in standing():
			_tie_enemy(enemy, move.ties, target)
	if move.cuts_tethers > 0 and enemy.alive:
		for p in players.size():
			if not players[p].down:
				_cut_strongest(-1 - p, move.cuts_tethers)
	if not move.summons.is_empty() and enemy.alive:
		_summon(enemy, move.summons)


## Whom `move` of `enemy`'s helps: itself, the worst hurt of the rest of its side, or all of them.
func _helped(enemy: Dictionary, move: CardEnemyMove) -> Array:
	match move.helps:
		CardEnemyMove.Helps.EVERY_ALLY:
			return enemies.filter(func(other): return other.alive)
		CardEnemyMove.Helps.WORST_HURT_ALLY:
			var worst := _worst_hurt_ally(enemy)
			return [worst] if not worst.is_empty() else [enemy]
	return [enemy]


## The worst hurt of `enemy`'s side but itself (by share of health), or {} when it is alone.
func _worst_hurt_ally(enemy: Dictionary) -> Dictionary:
	var worst := {}
	for other in enemies:
		if not other.alive or is_same(other, enemy):
			continue
		if worst.is_empty() or float(other.hp) / maxf(float(other.max_hp), 1.0) < float(worst.hp) / maxf(float(worst.max_hp), 1.0):
			worst = other
	return worst


## --- Choosing ---


## Picks what `enemy` will do next, and shows it: a countdown keeps its move until it lands.
func _choose_move(enemy: Dictionary):
	if not enemy.alive:
		return
	if bool(enemy.get("choking", false)):
		enemy.choking = false
		enemy.move = _choking_move
		enemy.planned = null
		enemy.revealed = false
		beat.emit(&"intent", {"who": who_of(enemy), "intent": intent_of(enemy), "changed": false})
		return
	if not enemy.winding:
		enemy.move = _decide(enemy)
		_after_deciding(enemy)
	enemy.revealed = false
	beat.emit(&"intent", {"who": who_of(enemy), "intent": intent_of(enemy), "changed": false})


## Once `enemy` has a new move: its countdown set, and its plan for the turn after made.
func _after_deciding(enemy: Dictionary):
	var move: CardEnemyMove = enemy.move
	enemy.winding = move != null and move.wind_up > 0 and enemy.moves.has(move)
	enemy.countdown = move.wind_up if enemy.winding else 0
	enemy.planned = _plan_after(enemy)


## What `enemy` will do on its next turn: asleep, stirring or curled up as it is; else its first rule that holds, its plan (made a
## turn before), or a fresh pick of its pattern - every move within its limits. `exclude`: a move not to choose (Reactive's last).
func _decide(enemy: Dictionary, exclude: String = "") -> CardEnemyMove:
	if int(enemy.statuses.get(&"asleep", 0)) > 0:
		return _asleep_move
	if int(enemy.curl_left) > 0:
		return enemy.curled_move
	var moves: Array = enemy.moves
	if moves.is_empty():
		return null
	var state := _state_of(enemy)
	for rule in enemy.rules:
		if rule == null or not _tier_reaches(rule.from_tier) or not _holds(enemy, rule.when, rule.number, rule.status):
			continue
		var ruled := _move_named(enemy, rule.move)
		if ruled != null and ruled.name != exclude and _allowed(ruled, state):
			return ruled
	var planned: CardEnemyMove = enemy.planned
	if planned != null and planned.name != exclude and moves.has(planned) and _allowed(planned, state):
		enemy.cycle_at = int(enemy.planned_cycle_at)
		return planned
	var picked := _pattern_pick(enemy, state, exclude)
	enemy.cycle_at = int(state.cycle_at)
	return picked


## What it plans to do the turn after its next, by its pattern, as if its next move were done: the forecast Second Sight shows.
## Its rules can still change it when the time comes.
func _plan_after(enemy: Dictionary) -> CardEnemyMove:
	var move: CardEnemyMove = enemy.move
	if move == null or enemy.moves.is_empty() or move in [_asleep_move, _stirring_move, _choking_move] or move == enemy.curled_move:
		return null
	var state := _state_of(enemy)
	if enemy.moves.has(move):
		state.history = state.history + [move.name]
		state.used[move.name] = int(state.used.get(move.name, 0)) + 1
		state.last_used[move.name] = int(state.turn) + int(move.wind_up)
		state.turn = int(state.turn) + 1 + int(move.wind_up)
	else:
		state.turn = int(state.turn) + 1
	var plan := _pattern_pick(enemy, state)
	enemy.planned_cycle_at = int(state.cycle_at)
	return plan


## What choosing for its next turn goes by: which turn of its that is, what it has done, and where its cycle is.
func _state_of(enemy: Dictionary) -> Dictionary:
	return {"turn": int(enemy.turns) + 1, "history": enemy.history.duplicate(), "used": enemy.used.duplicate(),
		"last_used": enemy.last_used.duplicate(), "cycle_at": int(enemy.cycle_at)}


## Its pattern's pick for the turn `state` describes: its opening move on its first turn, else in order (Cycle) or at random by
## weight, never three times running (Random); only moves within their limits, while any are.
func _pattern_pick(enemy: Dictionary, state: Dictionary, exclude: String = "") -> CardEnemyMove:
	var moves: Array = enemy.moves
	var allowed: Array = moves.filter(func(move): return move != null and move.name != exclude and _allowed(move, state))
	if allowed.is_empty():
		allowed = moves.filter(func(move): return move != null and move.name != exclude)
	if allowed.is_empty():
		allowed = moves.filter(func(move): return move != null)
	if allowed.is_empty():
		return null
	if int(state.turn) == 1:
		for move in allowed:
			if move.first:
				if enemy.pattern == CardEnemyDefinition.Pattern.CYCLE and not move.rule_only:
					state.cycle_at = moves.find(move) + 1
				return move
	# What only a rule chooses is not the pattern's (but when nothing else is left).
	var by_pattern: Array = allowed.filter(func(move): return not move.rule_only)
	if not by_pattern.is_empty():
		allowed = by_pattern
	if enemy.pattern == CardEnemyDefinition.Pattern.CYCLE:
		for step in moves.size():
			var at := (int(state.cycle_at) + step) % moves.size()
			if allowed.has(moves[at]):
				state.cycle_at = at + 1
				return moves[at]
		return allowed[0]
	# At random by weight (leaning with the fight), but never the same move a third time running.
	var history: Array = state.history
	var tired := ""
	if history.size() >= 2 and history[-1] == history[-2]:
		tired = history[-1]
	var choices: Array = allowed.filter(func(move): return move.name != tired)
	if choices.is_empty():
		choices = allowed
	var weights: Array = choices.map(func(move): return _weight_of(enemy, move))
	var total := 0
	for weight in weights:
		total += int(weight)
	var roll := rng.randi_range(1, maxi(total, 1))
	for i in choices.size():
		roll -= int(weights[i])
		if roll <= 0:
			return choices[i]
	return choices[-1]


## A move's weight as things stand, in hundredths: its Weight, times its Lean Factor while its lean holds.
func _weight_of(enemy: Dictionary, move: CardEnemyMove) -> int:
	var weight := float(maxi(move.weight, 1))
	if move.lean_when != CardEnemyRule.When.NEVER and _holds(enemy, move.lean_when, move.lean_number, move.lean_status):
		weight *= maxf(move.lean_factor, 0.0)
	return maxi(int(round(weight * 100.0)), 1)


## Whether `move` may be chosen for the turn `state` describes: its limits (twice running, a fight's most, its first turn, its
## cooldown), and room for whatever it calls.
func _allowed(move: CardEnemyMove, state: Dictionary) -> bool:
	var history: Array = state.history
	var on := int(state.turn)
	if move.not_twice_running and not history.is_empty() and history[-1] == move.name:
		return false
	if move.most_times > 0 and int(state.used.get(move.name, 0)) >= move.most_times:
		return false
	if move.not_before_turn > 0 and on < move.not_before_turn:
		return false
	if move.cooldown > 0 and state.last_used.has(move.name) and on - int(state.last_used[move.name]) <= move.cooldown:
		return false
	if not move.summons.is_empty() and _room() <= 0:
		return false
	return true


## Whether `when` (with `number` and `status`) holds for `enemy` now (CardEnemyRule.When). "The player" is any player standing for
## Has, Block and health; Lacks, all of them.
func _holds(enemy: Dictionary, when: CardEnemyRule.When, number: int, status: StringName) -> bool:
	var up := standing()
	if up.is_empty():
		up = players
	match when:
		CardEnemyRule.When.ALWAYS:
			return true
		CardEnemyRule.When.ITS_HEALTH_UNDER:
			return enemy.hp * 100 < number * maxi(int(enemy.max_hp), 1)
		CardEnemyRule.When.PLAYER_BLOCK_AT_LEAST:
			return up.any(func(each): return maxi(int(each.block), int(each.get("block_at_end", 0))) >= number)
		CardEnemyRule.When.PLAYER_HEALTH_UNDER:
			return up.any(func(each): return each.hp * 100 < number * maxi(int(each.max_hp), 1))
		CardEnemyRule.When.PLAYER_HAS:
			return up.any(func(each): return int(each.statuses.get(status, 0)) >= maxi(number, 1))
		CardEnemyRule.When.PLAYER_LACKS:
			return up.all(func(each): return int(each.statuses.get(status, 0)) <= 0)
		CardEnemyRule.When.IT_HAS:
			return int(enemy.statuses.get(status, 0)) >= maxi(number, 1)
		CardEnemyRule.When.IT_LACKS:
			return int(enemy.statuses.get(status, 0)) <= 0
		CardEnemyRule.When.ALLY_HURT:
			return enemies.any(func(other): return other.alive and not is_same(other, enemy) and other.hp * 100 < number * maxi(int(other.max_hp), 1))
		CardEnemyRule.When.ALLY_FALLEN:
			return fallen > 0
		CardEnemyRule.When.ALONE:
			return not enemies.any(func(other): return other.alive and not is_same(other, enemy))
		CardEnemyRule.When.TURN_AT_LEAST:
			return int(enemy.turns) + 1 >= number
		CardEnemyRule.When.TURN_EVERY:
			return number > 0 and (int(enemy.turns) + 1) % number == 0
	return false


## Whether a rule for fights of `from` and harder is used in this one (its tier, raised a step by a Challenge of 1 or more).
func _tier_reaches(from: CardEncounterDefinition.Tier) -> bool:
	return mini(int(tier) + (1 if challenge >= 1 else 0), int(CardEncounterDefinition.Tier.BOSS)) >= int(from)


func _move_named(enemy: Dictionary, move_name: String) -> CardEnemyMove:
	for move in enemy.moves:
		if move != null and move.name == move_name:
			return move
	return null


## Whether `enemy`'s intent is hidden from the players now: encrypted and not Scanned, Shows Nothing, or unseen until hit.
func intent_hidden(enemy: Dictionary) -> bool:
	if int(enemy.statuses.get(&"scanned", 0)) > 0:
		return false
	var definition: CardEnemyDefinition = enemy.definition
	return bool(enemy.encrypted) or definition.shows == CardEnemyDefinition.Shows.NOTHING \
		or (definition.shows == CardEnemyDefinition.Shows.ONCE_HIT and not bool(enemy.revealed))


## What `enemy` shows it will do: {intent, damage (each hit, as it would land now on the player now), hits, name, block, apply (a
## status it will put on the players), gain (one it will take), heal, helps, adds (a card it gives), steals, summons, countdown
## (turns before it lands, winding), asleep, curled, hidden (nothing to see), encrypted, then (Second Sight: the same of its plan
## after)}.
func intent_of(enemy: Dictionary) -> Dictionary:
	var move: CardEnemyMove = enemy.move
	var nothing := {"intent": CardEnemyMove.Intent.NOTHING, "damage": 0, "hits": 0, "name": "", "block": 0, "apply": &"", "gain": &"",
		"heal": 0, "helps": 0, "adds": "", "steals": 0, "summons": false, "countdown": 0, "asleep": false, "curled": false, "hidden": false,
		"encrypted": false, "ties": "", "cuts": 0}
	if not enemy.alive:
		return nothing
	if intent_hidden(enemy) and move != _asleep_move:
		nothing.hidden = true
		nothing.encrypted = bool(enemy.encrypted)
		nothing.name = "?"
		return nothing
	var shown := _intent_of_move(enemy, move)
	if move == _asleep_move:
		shown.asleep = true
	shown.curled = move != null and move == enemy.curled_move
	shown.countdown = int(enemy.countdown) + 1 if enemy.winding else 0
	if foresight and enemy.planned != null:
		shown["then"] = _intent_of_move(enemy, enemy.planned)
	return shown


func _intent_of_move(enemy: Dictionary, move: CardEnemyMove) -> Dictionary:
	if move == null:
		return {"intent": CardEnemyMove.Intent.NOTHING, "damage": 0, "hits": 0, "name": "", "block": 0, "apply": &"", "gain": &"",
			"heal": 0, "helps": 0, "adds": "", "steals": 0, "summons": false, "countdown": 0, "asleep": false, "curled": false, "hidden": false,
			"encrypted": false, "ties": "", "cuts": 0}
	var base: int = move.damage + move.damage_per_held * int(enemy.held.size())
	return {"intent": move.intent(), "damage": attack_damage(enemy, player, base) if move.damage > 0 else 0, "hits": move.hits,
		"name": move.name, "block": move.block, "apply": move.apply_status if move.apply_amount > 0 else &"",
		"gain": move.gain_status if move.gain_amount > 0 else &"", "heal": move.heal, "helps": int(move.helps),
		"adds": move.adds_card if move.adds_count > 0 else "", "steals": move.steals, "summons": not move.summons.is_empty(),
		"countdown": 0, "asleep": false, "curled": false, "hidden": false, "encrypted": false, "ties": move.ties,
		"cuts": move.cuts_tethers}


## --- Traits and phases ---


## A blow woke `enemy`: it stirs, doing nothing on its next turn, and shows so at once.
func _woken(enemy: Dictionary):
	enemy.statuses.erase(&"asleep")
	beat.emit(&"status", {"who": who_of(enemy), "key": &"asleep", "before": 1, "after": 0})
	said.emit("%s wakes!" % enemy.name)
	beat.emit(&"woke", {"who": who_of(enemy)})
	enemy.move = _stirring_move
	enemy.winding = false
	enemy.countdown = 0
	enemy.planned = null
	beat.emit(&"intent", {"who": who_of(enemy), "intent": intent_of(enemy), "changed": true})


## Mode Shift ran out: `enemy` curls up behind Block and Spines for a while, and shows so at once.
func _curl(enemy: Dictionary):
	var definition: CardEnemyDefinition = enemy.definition
	enemy.statuses.erase(&"mode_shift")
	enemy.curl_left = maxi(definition.curl_turns, 1)
	enemy.curl_spines = definition.curl_spines
	said.emit("%s curls up!" % enemy.name)
	beat.emit(&"curled", {"who": who_of(enemy)})
	_set_block(enemy, enemy.block + _enemy_block(enemy, definition.curl_block))
	add_status(enemy, &"spines", definition.curl_spines)
	add_status(enemy, &"curled", int(enemy.curl_left))
	enemy.winding = false
	enemy.countdown = 0
	enemy.move = enemy.curled_move
	enemy.planned = null
	beat.emit(&"intent", {"who": who_of(enemy), "intent": intent_of(enemy), "changed": true})


## Done curling: its Spines go back to what they were and its Mode Shift comes back, more to take than before.
func _uncurl(enemy: Dictionary):
	var definition: CardEnemyDefinition = enemy.definition
	add_status(enemy, &"spines", -int(enemy.curl_spines))
	enemy.curl_spines = 0
	enemy.shift_next = int(enemy.shift_next) + definition.curl_grows
	add_status(enemy, &"mode_shift", int(enemy.shift_next))
	enemy.statuses.erase(&"curled")
	said.emit("%s uncurls." % enemy.name)
	beat.emit(&"uncurled", {"who": who_of(enemy)})


## A Glutton hurt: for every quarter of its health gone, one card it ate falls out of it, into its owner's hand (the twist
## "a program that devours his code": what it ate falls back out through the hole).
func _spills(enemy: Dictionary):
	if int(enemy.statuses.get(&"glutton", 0)) <= 0 or enemy.held.is_empty():
		return
	var quarters_gone := int(floor(4.0 * (1.0 - float(enemy.hp) / maxf(float(enemy.max_hp), 1.0))))
	while int(enemy.spilled) < quarters_gone and not enemy.held.is_empty():
		enemy.spilled = int(enemy.spilled) + 1
		var card: Dictionary = enemy.held.pop_at(rng.randi_range(0, enemy.held.size() - 1))
		add_status(enemy, &"holding", -1)
		said.emit("A card falls out of %s." % enemy.name)
		_give_back(enemy, [card], true)


## Starts whichever of `enemy`'s phases its health has fallen into.
func _check_phases(enemy: Dictionary):
	var definition: CardEnemyDefinition = enemy.definition
	for i in definition.phases.size():
		var phase: CardEnemyPhase = definition.phases[i]
		if phase == null or enemy.phases_started.has(i) or not enemy.alive:
			continue
		if enemy.hp * 100 < phase.health_under * maxi(int(enemy.max_hp), 1):
			enemy.phases_started.append(i)
			_start_phase(enemy, phase)


func _start_phase(enemy: Dictionary, phase: CardEnemyPhase):
	if phase.line != "":
		said.emit(phase.line)
	beat.emit(&"phase", {"who": who_of(enemy), "line": phase.line})
	if not phase.splits_into.is_empty():
		_split(enemy, phase.splits_into)
		return
	if phase.clears_harm:
		for key in enemy.statuses.keys():
			if CardStatus.harmful(key):
				add_status(enemy, key, -int(enemy.statuses[key]))
	for status in phase.statuses:
		add_status(enemy, StringName(status), int(phase.statuses[status]))
	if phase.block > 0:
		_set_block(enemy, enemy.block + _enemy_block(enemy, phase.block))
	if not phase.moves.is_empty():
		enemy.moves = phase.moves.duplicate()
		enemy.pattern = phase.pattern
		enemy.cycle_at = 0
	if not phase.rules.is_empty():
		enemy.rules = phase.rules.duplicate()
	# What it shows stays what it does; the phase's moves are its from its next choice.
	if not enemy.winding:
		enemy.planned = _plan_after(enemy)
	beat.emit(&"intent", {"who": who_of(enemy), "intent": intent_of(enemy), "changed": false})


## `enemy` splits into `keys`, each with as much health as it has left (no more than their own most), and is gone: the first takes
## its place, the rest any room there is.
func _split(enemy: Dictionary, keys: Array):
	var at := who_of(enemy)
	var left := int(enemy.hp)
	enemy.alive = false
	enemy.block = 0
	beat.emit(&"split", {"who": at})
	var first := true
	for key in keys:
		var definition := CardDatabase.enemy(str(key))
		if definition == null:
			continue
		var made := _new_enemy(definition, str(key), left)
		var placed := -1
		if first:
			enemies[at] = made
			placed = at
			first = false
		else:
			placed = _place(made)
		if placed < 0:
			continue
		beat.emit(&"joined", {"who": placed, "from": at})
		_choose_move(made)


## `caller` calls `keys` into the fight, as many as there is room for; each shows what it will do, and acts from its next turn.
func _summon(caller: Dictionary, keys: Array):
	for key in keys:
		if _room() <= 0:
			break
		var definition := CardDatabase.enemy(str(key))
		if definition == null:
			continue
		var made := _new_enemy(definition, str(key))
		var placed := _place(made)
		if placed < 0:
			break
		said.emit("%s calls a %s." % [caller.name, made.name])
		beat.emit(&"joined", {"who": placed, "from": who_of(caller)})
		_choose_move(made)


## How many more enemies can stand: MOST_ENEMIES less those standing or about to rise.
func _room() -> int:
	return MOST_ENEMIES - enemies.filter(func(other): return other.alive or int(other.rising) >= 0).size()


## Puts `made` in a fallen one's place (one not rising), else after the others; its index, or -1 with no room.
func _place(made: Dictionary) -> int:
	for i in enemies.size():
		if not enemies[i].alive and int(enemies[i].rising) < 0:
			enemies[i] = made
			return i
	if enemies.size() < MOST_ENEMIES:
		enemies.append(made)
		return enemies.size() - 1
	return -1


## The fallen Linked count down, and rise with half their health while another Linked stands.
func _rising():
	for enemy in enemies:
		if enemy.alive or int(enemy.rising) <= 0:
			continue
		enemy.rising = int(enemy.rising) - 1
		if int(enemy.rising) > 0:
			beat.emit(&"rising", {"who": who_of(enemy), "left": int(enemy.rising)})
			continue
		if not enemies.any(func(other): return other.alive and int(other.statuses.get(&"linked", 0)) > 0):
			enemy.rising = -1
			continue
		enemy.rising = -1
		enemy.alive = true
		enemy.hp = maxi(int(enemy.max_hp) / 2, 1)
		enemy.block = 0
		var definition: CardEnemyDefinition = enemy.definition
		enemy.statuses.clear()
		enemy.fresh.clear()
		for status in definition.starting_statuses:
			var amount := int(definition.starting_statuses[status])
			if amount > 0:
				enemy.statuses[StringName(status)] = amount
		enemy.winding = false
		enemy.countdown = 0
		enemy.planned = null
		said.emit("%s rises again." % enemy.name)
		beat.emit(&"rose", {"who": who_of(enemy)})


## `enemy` puts `count` of card `key` (a Status card) into the player now's `where`.
func _give_cards(enemy: Dictionary, key: String, count: int, where: CardEnemyMove.Pile):
	var definition := CardDatabase.card(key)
	if definition == null:
		push_warning("CardBattle: no card %s to give." % key)
		return
	var given: Array = []
	var to := &"discard"
	for i in count:
		var card := {"key": key, "upgraded": false, "id": _next_id}
		_next_id += 1
		match where:
			CardEnemyMove.Pile.HAND:
				if hand.size() < HAND_MOST:
					hand.append(card)
					to = &"hand"
				else:
					discard_pile.append(card)
			CardEnemyMove.Pile.DRAW:
				draw_pile.insert(rng.randi_range(0, draw_pile.size()), card)
				to = &"draw"
			_:
				discard_pile.append(card)
		given.append(card)
	said.emit("%s gives %s %d %s." % [enemy.name, "you" if not together() else player.name, count, definition.name])
	beat.emit(&"given", {"from": who_of(enemy), "cards": given, "to": to, "player": active})


## `enemy` takes `count` of the player now's cards, at random from the draw pile (else the discard pile: the hand is empty on the
## enemies' turn), holding them until it falls. A Glutton eats them: one that is a Status card chokes it, and it spits out all it
## ate.
func _steal(enemy: Dictionary, count: int):
	var taken: Array = []
	var choked := false
	for i in count:
		var pile: Array = draw_pile if not draw_pile.is_empty() else discard_pile
		if pile.is_empty():
			break
		var card: Dictionary = pile.pop_at(rng.randi_range(0, pile.size() - 1))
		card.erase("cost_now")
		card["owner"] = active
		enemy.held.append(card)
		taken.append(card)
		var definition := CardDatabase.card(card.key)
		if int(enemy.statuses.get(&"glutton", 0)) > 0 and definition != null and definition.type == CardDefinition.Type.STATUS:
			choked = true
	if taken.is_empty():
		return
	said.emit("%s takes %d of %s cards." % [enemy.name, taken.size(), "your" if not together() else player.name + "'s"])
	beat.emit(&"stolen", {"who": who_of(enemy), "cards": taken, "player": active})
	add_status(enemy, &"holding", taken.size())
	if choked:
		_choke(enemy)


## A Glutton ate what it should not have: it chokes, doing nothing on its next turn, and spits out everything it ate.
func _choke(enemy: Dictionary):
	said.emit("%s chokes on it, and spits everything out!" % enemy.name)
	beat.emit(&"choked", {"who": who_of(enemy)})
	var out: Array = enemy.held.duplicate()
	enemy.held.clear()
	enemy.statuses.erase(&"holding")
	beat.emit(&"status", {"who": who_of(enemy), "key": &"holding", "before": out.size(), "after": 0})
	_give_back(enemy, out, false)
	# Its next turn is spent choking (_choose_move, as the round ends).
	enemy.winding = false
	enemy.countdown = 0
	enemy.planned = null
	enemy["choking"] = true


func _relics_at(when: CardRelicDefinition.When):
	for key in relics:
		var relic := CardDatabase.relic(key)
		if relic == null or relic.when != when or relic.effect == null:
			continue
		var effect: CardEffect = relic.effect
		if not effect.kind in [CardEffect.Kind.BLOCK, CardEffect.Kind.DRAW, CardEffect.Kind.ENERGY, CardEffect.Kind.APPLY,
				CardEffect.Kind.GAIN, CardEffect.Kind.HEAL, CardEffect.Kind.DAMAGE]:
			continue
		beat.emit(&"relic", {"key": key, "player": active})
		match effect.kind:
			CardEffect.Kind.BLOCK:
				_set_block(player, player.block + effect.amount)
			CardEffect.Kind.DRAW:
				draw(effect.amount)
			CardEffect.Kind.ENERGY:
				_set_energy(energy + effect.amount)
			CardEffect.Kind.APPLY:
				for enemy in enemies:
					if enemy.alive:
						add_status(enemy, effect.status, effect.amount)
			CardEffect.Kind.GAIN:
				add_status(player, effect.status, effect.amount)
			CardEffect.Kind.HEAL:
				_heal(player, effect.amount)
			CardEffect.Kind.DAMAGE:
				for enemy in enemies.duplicate():
					if enemy.alive:
						_lose_health(enemy, effect.amount)
		said.emit("%s." % relic.name)


## Ends the fight if one side is down. True if it is over.
func _check_end() -> bool:
	if over:
		return true
	if players.all(func(each): return each.hp <= 0):
		over = true
		won = false
		beat.emit(&"ended", {"won": false})
		changed.emit()
		ended.emit(false)
		return true
	if enemies.all(func(enemy): return not enemy.alive):
		over = true
		won = true
		beat.emit(&"ended", {"won": true})
		changed.emit()
		ended.emit(true)
		return true
	return false


## How much health card `index` of the hand would take off enemy `who` as things stand, after that enemy's Block: its Damage
## effects, each hit through whatever Block is left, worked out as the card's own text works its numbers out (and no more than its
## Invincible lets it lose). For the screen's preview on the enemy's health bar.
func preview_damage(index: int, who: int) -> int:
	if index < 0 or index >= hand.size() or who < 0 or who >= enemies.size() or not enemies[who].alive:
		return 0
	var card: Dictionary = hand[index]
	var definition := CardDatabase.card(card.key)
	if definition == null:
		return 0
	var enemy: Dictionary = enemies[who]
	var block: int = enemy.block
	var lost := 0
	for effect in definition.effects:
		if effect.kind != CardEffect.Kind.DAMAGE:
			continue
		for hit in effect.times_for(card.upgraded):
			var damage := attack_damage(player, enemy, effect.amount_for(card.upgraded))
			var soaked := mini(block, damage)
			block -= soaked
			lost += damage - soaked
	return mini(_capped(enemy, lost), enemy.hp)


func _shuffle(pile: Array):
	for i in range(pile.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = pile[i]
		pile[i] = pile[j]
		pile[j] = swap


## The enemies still standing, by index.
func living() -> Array:
	var found := []
	for i in enemies.size():
		if enemies[i].alive:
			found.append(i)
	return found


## --- Tethers (the designer's twist 7, 2026-11-27) ---
##
## A Tether card is played onto its target and stays on the table: at the end of each of its holder's turns it does its Effects and
## frays by 1; at 0 it snaps and does its Snap Effects. Its holder can let it go early (it snaps). The same card onto the same target
## renews it. An enemy's is tied by a move (CardEnemyMove.ties) and frays as the enemy is hurt too; an enemy's move can cut the
## players' (CardEnemyMove.cuts_tethers). One whose holder or target falls goes loose. Beats: tied {tether}, tether_did {tether},
## frayed {tether, strength}, snapped {tether, why: frayed, let_go, cut, broken, loose, renewed}.


## The fighter a screen's `who` is (a player's, an enemy's), or {}.
func fighter_of(who: int) -> Dictionary:
	var p := player_index(who)
	if p >= 0:
		return players[p] if p < players.size() else {}
	return enemies[who] if who >= 0 and who < enemies.size() else {}


## How many Tethers player `p` can hold at once: TETHER_SLOTS, and more for their relics.
func tether_slots(p: int) -> int:
	var slots := TETHER_SLOTS
	if p >= 0 and p < players.size():
		for key in players[p].relics:
			var relic := CardDatabase.relic(key)
			if relic != null:
				slots += relic.more_tether_slots
	return slots


## The Tethers `holder` (a who) holds.
func tethers_held_by(holder: int) -> Array:
	return tethers.filter(func(tether): return int(tether.holder) == holder)


## The Tethers on `who`.
func tethers_on(who: int) -> Array:
	return tethers.filter(func(tether): return int(tether.on) == who)


## Whom a Tether card of the player now's would hold: the enemy `who`, the partner (themselves alone or with them down), or themselves.
func _tether_target(definition: CardDefinition, who: int) -> int:
	match definition.target:
		CardDefinition.Target.ENEMY:
			return who
		CardDefinition.Target.ALLY:
			var partner := partner_of(active)
			if partner >= 0 and not players[partner].down:
				return -1 - partner
	return -1 - active


## The player now's Tether of card `key` already on `on`, which playing another would renew; {} for none.
func _renewing(key: String, on: int) -> Dictionary:
	for tether in tethers:
		if str(tether.key) == key and int(tether.holder) == -1 - active and int(tether.on) == on:
			return tether
	return {}


## What the screen is told of `tether`.
func _tether_info(tether: Dictionary) -> Dictionary:
	return {"id": tether.id, "key": tether.key, "upgraded": tether.upgraded, "holder": tether.holder, "on": tether.on,
		"strength": tether.strength, "most": tether.most}


## Card `card` (a Tether) played by the player `holder` onto `on`: it takes hold, at its full strength; the same one already there is
## let go first (renewed).
func _tie(card: Dictionary, definition: CardDefinition, holder: int, on: int):
	var old := _renewing(card.key, on)
	if not old.is_empty():
		_snap(old, &"renewed")
	var strength := definition.strength_for(bool(card.upgraded))
	var tether := {"id": _next_tether, "key": card.key, "upgraded": bool(card.upgraded), "card": card, "holder": holder, "on": on,
		"strength": strength, "most": strength, "hurt": 0}
	_next_tether += 1
	tethers.append(tether)
	var whom: Dictionary = fighter_of(on)
	said.emit("%s ties %s to %s." % [players[player_index(holder)].name if player_index(holder) >= 0 else "?", definition.name,
		str(whom.get("name", "?"))])
	beat.emit(&"tied", {"tether": _tether_info(tether)})


## `enemy` ties its Tether `key` (an Enemy Only card) onto player `target`; one of the same already there is held anew.
func _tie_enemy(enemy: Dictionary, key: String, target: Dictionary):
	var definition := CardDatabase.card(key)
	if definition == null or definition.type != CardDefinition.Type.TETHER:
		push_warning("CardBattle: %s ties no Tether called %s." % [enemy.name, key])
		return
	var holder := who_of(enemy)
	var on := who_of(target)
	for tether in tethers:
		if int(tether.holder) == holder and int(tether.on) == on and str(tether.key) == key:
			tether.strength = tether.most
			tether.hurt = 0
			beat.emit(&"frayed", {"tether": _tether_info(tether), "strength": tether.strength})
			return
	var strength := definition.strength_for(false)
	var tether := {"id": _next_tether, "key": key, "upgraded": false, "card": {}, "holder": holder, "on": on, "strength": strength,
		"most": strength, "hurt": 0}
	_next_tether += 1
	tethers.append(tether)
	said.emit("%s ties %s to %s." % [enemy.name, definition.name, target.name])
	beat.emit(&"tied", {"tether": _tether_info(tether)})


## Player `p` lets their Tether `id` go early: it snaps now, doing its snap. Takes their Ready back, as playing a card does. False if
## it cannot be (not theirs, not their turn, the fight over).
func let_go(p: int, id: int) -> bool:
	if over or p < 0 or p >= players.size() or players[p].down:
		return false
	for tether in tethers:
		if int(tether.id) == id and int(tether.holder) == -1 - p:
			var was := active
			active = p
			if players[p].ready:
				_set_ready_flag(p, false)
			said.emit("%s lets go of %s." % [players[p].name, CardDatabase.card(tether.key).name if CardDatabase.card(tether.key) != null else tether.key])
			_snap(tether, &"let_go")
			var turn_was := turn
			_check_end()
			if not over and turn == turn_was and together() and _all_ready():
				end_turn()
			if not over and turn == turn_was:
				active = was
			changed.emit()
			return true
	return false


## The end of `holder`'s turn: each of its Tethers does its thing, then frays by 1.
func _tether_turn(holder: int):
	for tether in tethers_held_by(holder):
		if over or not tethers.has(tether):
			continue
		_tether_does(tether, false)
		if over or not tethers.has(tether):
			continue
		_fray(tether, 1, &"frayed")


## `tether` does its Effects (`snapping`: its Snap Effects): what lands goes on whoever it holds, what comes back goes to its holder,
## or, holding a player (the partner, yourself), to them.
func _tether_does(tether: Dictionary, snapping: bool):
	var definition := CardDatabase.card(tether.key)
	var holder: Dictionary = fighter_of(int(tether.holder))
	var on: Dictionary = fighter_of(int(tether.on))
	if definition == null or holder.is_empty() or on.is_empty():
		return
	var effects: Array = definition.snap_effects if snapping else definition.effects
	if effects.is_empty():
		return
	beat.emit(&"tether_did", {"tether": _tether_info(tether), "snapping": snapping})
	var was := active
	var holds_a_player := player_index(int(tether.on)) >= 0
	var receiver: Dictionary = on if holds_a_player and not holder.has("alive") else holder
	for effect in effects:
		if over:
			break
		var amount: int = effect.amount_for(bool(tether.upgraded))
		match effect.kind:
			CardEffect.Kind.DAMAGE:
				if holds_a_player == holder.has("alive"):
					var hits: int = effect.times_for(bool(tether.upgraded))
					for hit in hits:
						if on.hp > 0 and holder.hp > 0 and (not on.has("alive") or on.alive):
							_hit(holder, on, amount, hit, hits)
			CardEffect.Kind.APPLY:
				if holds_a_player == holder.has("alive"):
					add_status(on, effect.status, amount)
			CardEffect.Kind.DRAIN:
				if holds_a_player == holder.has("alive"):
					_drain(holder, on, amount)
			CardEffect.Kind.BLOCK:
				var gained := block_gained(receiver, amount)
				if receiver.has("alive"):
					gained = _enemy_block(receiver, amount)
				_set_block(receiver, receiver.block + gained)
			CardEffect.Kind.HEAL:
				_heal(receiver, amount)
			CardEffect.Kind.GAIN:
				add_status(receiver, effect.status, amount)
			CardEffect.Kind.DRAW:
				var p := players.find(receiver)
				if p >= 0 and not receiver.down:
					active = p
					draw(amount)
			CardEffect.Kind.ENERGY:
				var p := players.find(receiver)
				if p >= 0 and not receiver.down:
					active = p
					_set_energy(energy + amount)
		_check_end()
	active = was


## `drainer` drains `amount` health out of `from`, Block or not, and mends as much as `from` lost.
func _drain(drainer: Dictionary, from: Dictionary, amount: int):
	var before: int = from.hp
	_lose_health(from, amount, &"drain")
	var lost: int = before - int(from.hp)
	if lost > 0 and drainer.hp > 0:
		_heal(drainer, lost)


## `tether` frays by `by` strands; at none it snaps (`why`).
func _fray(tether: Dictionary, by: int, why: StringName):
	tether.strength = maxi(int(tether.strength) - by, 0)
	beat.emit(&"frayed", {"tether": _tether_info(tether), "strength": tether.strength})
	if int(tether.strength) <= 0:
		_snap(tether, why)


## `tether` is gone: frayed through or let go, it does its snap first; cut, broken, loose or renewed, it just goes. A player's goes
## back to its owner's discard pile.
func _snap(tether: Dictionary, why: StringName):
	if not tethers.has(tether):
		return
	# Off the table first, so whatever its snap sets off (a fall, and so its other Tethers loose) never finds it again.
	tethers.erase(tether)
	beat.emit(&"snapped", {"tether": _tether_info(tether), "why": why})
	var p := player_index(int(tether.holder))
	if p >= 0 and p < players.size() and not tether.card.is_empty():
		players[p].discard_pile.append(tether.card)
	if why == &"frayed" or why == &"let_go":
		_tether_does(tether, true)


## Whatever `who` held, and whatever held them, goes loose: they fell, or went down.
func _loosen(who: int):
	for tether in tethers.duplicate():
		if int(tether.holder) == who or int(tether.on) == who:
			_snap(tether, &"loose")


## An enemy hurt: every TETHER_BREAK_DAMAGE health it has lost since tying cuts a strand of each of its Tethers.
func _strain_tethers(enemy: Dictionary, amount: int):
	if amount <= 0 or not enemy.has("alive"):
		return
	for tether in tethers_held_by(who_of(enemy)):
		tether.hurt = int(tether.hurt) + amount
		var strands := int(tether.hurt) / CardDefinition.TETHER_BREAK_DAMAGE
		if strands > 0:
			tether.hurt = int(tether.hurt) % CardDefinition.TETHER_BREAK_DAMAGE
			_fray(tether, strands, &"broken")


## The strongest `count` of `holder`'s Tethers cut (an enemy's move): gone, with no snap.
func _cut_strongest(holder: int, count: int):
	var held := tethers_held_by(holder)
	held.sort_custom(func(a, b): return int(a.strength) > int(b.strength) or (int(a.strength) == int(b.strength) and int(a.id) > int(b.id)))
	for i in mini(count, held.size()):
		said.emit("A Tether is cut.")
		_snap(held[i], &"cut")
