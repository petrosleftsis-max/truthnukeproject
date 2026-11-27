extends RefCounted
class_name CardRun
## A run of the card game, rules only (docs/card_game.md): the deck, health, gold and relics carried from room to room, the map
## and where the players are on it, and what each room gives. The screen (CardGame) shows it; a suite can play it with no screen.
##
## The map: `floors` floors of rooms on COLUMNS columns, PATHS paths climbing from the bottom, each room joined to one to three
## above it, and the boss at the top. The first row is fights, the middle one treasure, the last before the boss a rest; the
## rest are fights, events, elites, rests and shops by ROOM_WEIGHTS, never an elite, rest or shop straight after another.
##
## **Prometheus's hacking** (the designer's twists of 2026-11-27; docs/card_game.md "Hacking"): the run goes down through the
## `layers` of a system, a map each with its boss at its foot, the deeper the harder (twist 1: CardBattle.LAYER_*; each layer's own
## boss: CardDatabase.bosses_of). The system notices him: the `trace` (twist 3), raised by every fight, an elite more, a long fight
## and a loud card (CardDefinition.trace), lowered by covering his tracks at a rest; its answers are in the fights
## (CardBattle.TRACE_*), a Glitch in every deck from TRACE_GLITCH, and at TRACE_MOST he is traced: the run is lost. Deeper layers
## hide what their programs will do (twist 6: DARKNESS, Scanned). A rest is short (twist 13: rest_with); after a layer's boss the
## long rest mends everybody and reshapes each deck (long_rest, then next_layer). What was taken out of a deck is forgotten, and comes
## back upgraded as the last layer begins (twist 8: Lethe, `forgotten`). A boss beaten gives a code fragment of a locked character
## (CardUnlocks), as a Memento does.
##
## **Two players** (co-op, Slay the Spire 2's way; the designer: "Up to two, as the game already is"): each has their own
## character, deck, health, gold, relics, rewards and shop (`players`). `me` is whose the calls are (deck, hp, gold, relics, rewards,
## shop, take_card, rest, buy_card...: all `players[me]`'s), which the screen sets to whoever is choosing. They go where they both
## vote (vote; one at random of the two when they differ), fight together (CardBattle.add_player), and one down in a fight won gets
## up with 1 health.

signal changed
## A relic did its thing outside a fight (picked up, a fight won), for the screen to light it.
signal relic_used(key: String)

enum Room { FIGHT, ELITE, REST, SHOP, EVENT, TREASURE, BOSS }
## How a short rest is spent (rest_with): mend, upgrade a card, cover his tracks (the trace), or mend the partner (co-op).
enum Rest { PATCH, STUDY, COVER_TRACKS, MEND }

const FLOORS := 12
const COLUMNS := 6
const PATHS := 5
const START_HP := 60
const START_GOLD := 99
## room -> weight, for the floors that are not set.
const ROOM_WEIGHTS := {Room.FIGHT: 45, Room.EVENT: 22, Room.ELITE: 16, Room.REST: 12, Room.SHOP: 5}
## Elites and rests not before this row, shops not before the second.
const ELITE_FROM := 4
const REST_FROM := 4
const SHOP_FROM := 2
## How many fights come from the easy encounters before the hard ones.
const EASY_FIGHTS := 3
## Gold for a fight won, an elite's.
const FIGHT_GOLD := [10, 20]
const ELITE_GOLD := [25, 35]
## Chances of each rarity among the cards offered (common, uncommon, rare), after a fight and after an elite.
const FIGHT_RARITY := [60, 37, 3]
const ELITE_RARITY := [50, 40, 10]
## A rest mends this share of the most health; mending the partner (co-op) this share of theirs.
const REST_SHARE := 0.3
const MEND_SHARE := 0.3
## Shop prices: a card by rarity (common, uncommon, rare) and a relic by rarity, give or take a tenth; removing a card, and how
## much more each time.
const CARD_PRICES := [50, 75, 150]
const RELIC_PRICES := [150, 200, 260]
const REMOVE_PRICE := 75
const REMOVE_PRICE_RISE := 25
const SHOP_CARDS := 5
const SHOP_RELICS := 2
## The most layers a run goes down, and the share of enemies whose intents are encrypted on each (twist 6; index by layer).
const MOST_LAYERS := 3
const DARKNESS := [0.0, 0.15, 0.35, 0.55]
## The trace (twist 3), 0 to TRACE_MOST: TRACE_FIGHT for every fight, TRACE_ELITE more for an elite, one for every turn a fight lasts
## past TRACE_TURNS_FREE, and each loud card's own; Cover Tracks takes TRACE_COVER off. From TRACE_GLITCH a Glitch goes into every
## deck, once. TRACE_MARKS are where the screen's meter marks the system's answers.
const TRACE_MOST := 100
const TRACE_FIGHT := 1
const TRACE_ELITE := 3
const TRACE_TURNS_FREE := 6
const TRACE_COVER := 15
const TRACE_GLITCH := 75
const TRACE_MARKS := [25, 50, 75, 100]
## The card the trace puts in every deck from TRACE_GLITCH (data/cards/).
const GLITCH := "glitch"

var rng := RandomNumberGenerator.new()
## The players: {name, character, deck ({key, upgraded}), hp, max_hp, gold, relics, remove_price, forgotten (cards taken out this
## run, for Lethe), lethe_back (what came back), rewards, shop}.
var players: Array = []
## Whose the calls are (the screen's: whoever is choosing now).
var me := 0
var deck: Array:
	get:
		return players[me].deck
	set(value):
		players[me].deck = value
var hp: int:
	get:
		return int(players[me].hp)
	set(value):
		players[me].hp = value
var max_hp: int:
	get:
		return int(players[me].max_hp)
	set(value):
		players[me].max_hp = value
var gold: int:
	get:
		return int(players[me].gold)
	set(value):
		players[me].gold = value
var relics: Array:
	get:
		return players[me].relics
	set(value):
		players[me].relics = value
var remove_price: int:
	get:
		return int(players[me].remove_price)
	set(value):
		players[me].remove_price = value
## What a fight won gives the player now: {gold, cards (keys), relic (key or "")}; empty when nothing waits.
var rewards: Dictionary:
	get:
		return players[me].rewards
	set(value):
		players[me].rewards = value
## The shop of the room the players are in, the player now's: {cards: [{key, price, sold}], relics: [{key, price, sold}]}.
var shop: Dictionary:
	get:
		return players[me].shop
	set(value):
		players[me].shop = value
## id -> {id, row, column, room (Room), next (ids)}.
var rooms := {}
## The room the players are in, or -1 before the first of the layer.
var at := -1
var visited: Array = []
var fights_won := 0
var battle: CardBattle = null
var over := false
var won := false
var _last_encounter := ""
var _events_seen: Array = []
## How hard the run is (Slay the Spire's Ascension; docs/proposals_2026-11-27_card_ai.md item 22), chosen before its first room:
## 0 as the fights are made; from 1 enemies choose as in a fight a tier harder (their rules' From Tier), from 2 they have a tenth
## more health, from 3 they start every fight with 1 Might (CardBattle.set_challenge).
var challenge := 0
const CHALLENGE_MOST := 3
## How many layers this run goes down, which it is on, and how many floors each has (a hack can be shorter: CardHack).
var layers := 1
var layer := 1
var floors := FLOORS
## The trace, whether he has been traced (the run lost to it) and whether the Glitch has gone in.
var trace := 0
var traced := false
var glitched := false
## The long rest waits (a layer's boss beaten, more layers to go): long_rest, then next_layer.
var long_rest_due := false
## Code fragments found this run: {character, opened}; and whose the last boss gave ("" for none).
var fragments_found: Array = []
var boss_fragment := ""
## Where each player votes to go next (co-op): player -> room id.
var votes := {}


## A run for `characters` (data/card_characters/ keys; one or two players), `with_seed` making it the same every time (0: any),
## `layer_count` layers of `floor_count` floors. With no character, one player starts as the card game first did (STARTING_DECK).
func _init(with_seed: int = 0, characters: Array = [], layer_count: int = 1, floor_count: int = FLOORS):
	if with_seed != 0:
		rng.seed = with_seed
	else:
		rng.randomize()
	layers = clampi(layer_count, 1, MOST_LAYERS)
	floors = maxi(floor_count, 3)
	if characters.is_empty():
		_add_player("", "You")
	else:
		var count := mini(characters.size(), CardBattle.MOST_PLAYERS)
		for i in count:
			_add_player(str(characters[i]), _name_for(characters, i, count))
	me = 0
	_make_map()
	# Each player's Blessings to choose from (twist 15), made now so both machines of a network game make the same.
	for p in players.size():
		me = p
		blessing_choices()
	me = 0


func _name_for(characters: Array, i: int, count: int) -> String:
	if count <= 1:
		return "You"
	var definition := CardDatabase.character(str(characters[i]))
	var called: String = definition.name if definition != null and definition.name != "" else "Player %d" % (i + 1)
	if count > 1 and str(characters[0]) == str(characters[1]):
		called += " %d" % (i + 1)
	return called


func _add_player(character: String, player_name: String):
	var definition := CardDatabase.character(character)
	var health: int = definition.health if definition != null else START_HP
	players.append({"name": player_name, "character": character, "deck": [], "hp": health, "max_hp": health, "gold": START_GOLD,
		"relics": [], "remove_price": REMOVE_PRICE, "forgotten": [], "lethe_back": [], "rewards": {}, "shop": {},
		"message_offers": [], "blessing_offers": [], "blessing": "", "chest": "", "chest_at": -2, "event_cards": []})
	me = players.size() - 1
	var cards: Array = CardDatabase.STARTING_DECK
	if definition != null and not definition.starting_deck.is_empty():
		cards = definition.starting_deck
	for key in cards:
		if CardDatabase.card(key) != null:
			deck.append({"key": key, "upgraded": false})
	# The Message (twist 10): in every deck, its words written by the run's events.
	var message := CardDatabase.card(CardDefinition.MESSAGE)
	if message != null:
		deck.append({"key": CardDefinition.MESSAGE, "upgraded": false, "message": {"words": [], "cost": message.cost, "lightened": false}})
	var relic: String = definition.starting_relic if definition != null and definition.starting_relic != "" else CardDatabase.STARTING_RELIC
	if CardDatabase.relic(relic) != null:
		gain_relic(relic)


## Whether two play.
func together() -> bool:
	return players.size() > 1


## The character of the player now ("" for the first card game's).
func character() -> String:
	return str(players[me].character)


## The other player of `p`'s, or -1 alone.
func partner_of(p: int) -> int:
	return (1 - p) if together() else -1


## --- The map ---


func _make_map():
	rooms.clear()
	var at_cell := {}
	var edges := {}
	var next_id := 0
	var starts := []
	for path in PATHS:
		var column := rng.randi_range(0, COLUMNS - 1)
		# The first two paths never start in the same place.
		if path == 1:
			while column == starts[0]:
				column = rng.randi_range(0, COLUMNS - 1)
		starts.append(column)
		for row in floors:
			var cell := Vector2i(column, row)
			if not at_cell.has(cell):
				at_cell[cell] = next_id
				rooms[next_id] = {"id": next_id, "floor": row, "column": column, "room": Room.FIGHT, "next": []}
				next_id += 1
			if row == floors - 1:
				break
			var options := [column - 1, column, column + 1].filter(func(c): return c >= 0 and c < COLUMNS)
			_shuffle(options)
			var chosen: int = options[0]
			for option in options:
				if not _crosses(edges, row, column, option):
					chosen = option
					break
			edges[Vector3i(row, column, chosen)] = true
			column = chosen
	for edge in edges:
		var from: int = at_cell[Vector2i(edge.y, edge.x)]
		var to: int = at_cell[Vector2i(edge.z, edge.x + 1)]
		if not rooms[from].next.has(to):
			rooms[from].next.append(to)
	var boss := next_id
	rooms[boss] = {"id": boss, "floor": floors, "column": floori(COLUMNS / 2.0), "room": Room.BOSS, "next": []}
	for id in rooms:
		if rooms[id].floor == floors - 1:
			rooms[id].next.append(boss)
	_choose_rooms()


## Whether a way from `from` to `to` between `row` and the next would cross one already drawn.
func _crosses(edges: Dictionary, row: int, from: int, to: int) -> bool:
	for edge in edges:
		if edge.x != row:
			continue
		if (edge.y < from and edge.z > to) or (edge.y > from and edge.z < to):
			return true
	return false


func _choose_rooms():
	var parents := {}
	for id in rooms:
		for to in rooms[id].next:
			if not parents.has(to):
				parents[to] = []
			parents[to].append(id)
	var ids := rooms.keys()
	ids.sort_custom(func(a, b): return rooms[a].floor < rooms[b].floor)
	for id in ids:
		var room: Dictionary = rooms[id]
		if room.room == Room.BOSS:
			continue
		if room.floor == 0:
			room.room = Room.FIGHT
		elif room.floor == floors - 1:
			room.room = Room.REST
		elif room.floor == floori(floors / 2.0):
			room.room = Room.TREASURE
		else:
			var before: Array = parents.get(id, []).map(func(parent): return rooms[parent].room)
			for attempt in 8:
				room.room = _weighted_room(room.floor)
				if not (room.room in [Room.ELITE, Room.REST, Room.SHOP] and before.has(room.room)) \
						and not (room.room == Room.REST and room.floor == floors - 2):
					break
			if room.room == Room.REST and room.floor == floors - 2:
				room.room = Room.FIGHT


func _weighted_room(row: int) -> Room:
	var weights := {}
	for room in ROOM_WEIGHTS:
		if (room == Room.ELITE and row < ELITE_FROM) or (room == Room.REST and row < REST_FROM) or (room == Room.SHOP and row < SHOP_FROM):
			continue
		weights[room] = ROOM_WEIGHTS[room]
	var total := 0
	for room in weights:
		total += weights[room]
	var roll := rng.randi_range(1, total)
	for room in weights:
		roll -= weights[room]
		if roll <= 0:
			return room
	return Room.FIGHT


## The rooms the players can go to next.
func choices() -> Array:
	if over or long_rest_due:
		return []
	if at < 0:
		return rooms.keys().filter(func(id): return rooms[id].floor == 0)
	return rooms[at].next.duplicate()


## Goes to room `id`. False if it is not one of the choices.
func go_to(id: int) -> bool:
	if not choices().has(id):
		return false
	at = id
	visited.append(id)
	votes.clear()
	for each in players:
		each.rewards = {}
		each.shop = {}
	# A shop's stock made as it is entered, each player's in turn: the same on both machines of a network game.
	if room_here() == Room.SHOP:
		var was := me
		for p in players.size():
			me = p
			shop_here()
		me = was
	changed.emit()
	return true


## Player `p` votes to go to room `id` (co-op): once every player has, they go - where they agree, else to one of the two at
## random. Alone, it is going there. The room gone to, or -1 while the other has still to vote (or `id` is no choice).
func vote(p: int, id: int) -> int:
	if not choices().has(id) or p < 0 or p >= players.size():
		return -1
	votes[p] = id
	if votes.size() < players.size():
		changed.emit()
		return -1
	var wanted: Array = votes.values()
	var going: int = wanted[rng.randi_range(0, wanted.size() - 1)]
	go_to(going)
	return going


func room_here() -> Room:
	return rooms[at].room if at >= 0 else Room.FIGHT


func floor_here() -> int:
	return rooms[at].floor if at >= 0 else -1


static func room_name(room: Room) -> String:
	return ["Fight", "Elite", "Rest", "Shop", "Event", "Treasure", "Boss"][room]


## --- Fights ---


## A fight for the room the players are in: the battle, its signals for the screen to connect before it calls start(). Its
## encounter is one of the layer's (CardDatabase.encounters_for, bosses_of), made as hard as the layer, the trace, the Challenge and
## two players make it, its intents as dark as the layer.
func new_battle() -> CardBattle:
	var tier: CardEncounterDefinition.Tier = CardEncounterDefinition.Tier.EASY
	match room_here():
		Room.ELITE:
			tier = CardEncounterDefinition.Tier.ELITE
		Room.BOSS:
			tier = CardEncounterDefinition.Tier.BOSS
		_:
			tier = CardEncounterDefinition.Tier.EASY if fights_won < EASY_FIGHTS else CardEncounterDefinition.Tier.HARD
	var pool: Array = CardDatabase.bosses_of(layer) if tier == CardEncounterDefinition.Tier.BOSS else CardDatabase.encounters_for(tier, layer)
	if pool.size() > 1:
		pool.erase(_last_encounter)
	var key: String = pool[rng.randi_range(0, pool.size() - 1)] if not pool.is_empty() else ""
	_last_encounter = key
	return battle_of(key, tier)


## A fight against encounter `key` (data/card_encounters/), for this run's players (a hack of one fight goes straight to it).
func battle_of(key: String, tier: CardEncounterDefinition.Tier = CardEncounterDefinition.Tier.EASY) -> CardBattle:
	var encounter: CardEncounterDefinition = CardDatabase.encounters().get(key)
	var enemies: Array = encounter.enemies if encounter != null else []
	var first: Dictionary = players[0]
	battle = CardBattle.new(first.deck, enemies, first.hp, first.max_hp, first.relics, rng.randi() | 1, first.name)
	battle.players[0].character = first.character
	for p in range(1, players.size()):
		var other: Dictionary = players[p]
		battle.add_player(other.deck, other.hp, other.max_hp, other.relics, other.name, other.character)
	battle.tier = tier
	battle.set_layer(layer, encounter == null or encounter.layer != layer)
	battle.set_trace(trace)
	battle.set_challenge(challenge)
	battle.set_darkness(DARKNESS[clampi(layer, 0, DARKNESS.size() - 1)])
	# The run's last boss: the Message speaks every word twice (twist 10).
	battle.truth_spoken = (room_here() == Room.BOSS or tier == CardEncounterDefinition.Tier.BOSS) and layer >= layers
	return battle


## Takes what the fight left: each player's health (one down gets up with 1), the trace it raised, and on a win, gold, three cards
## to choose from and an elite's or a boss's relic each, a boss's code fragment, and after a layer's boss the long rest. A loss, the
## last boss beaten or the trace full ends the run.
func finish_battle():
	if battle == null:
		return
	for p in players.size():
		if p < battle.players.size():
			players[p].hp = maxi(int(battle.players[p].hp), 0)
	var turns := battle.turn
	var loud := battle.trace_gained
	if not battle.won:
		over = true
		won = false
		battle = null
		changed.emit()
		return
	for each in players:
		if int(each.hp) <= 0:
			each.hp = 1
	fights_won += 1
	var room := room_here()
	battle = null
	add_trace(TRACE_FIGHT + (TRACE_ELITE if room == Room.ELITE else 0) + maxi(turns - TRACE_TURNS_FREE, 0) + loud)
	if over:
		changed.emit()
		return
	var was := me
	for p in players.size():
		me = p
		_relics_won()
	me = was
	if room == Room.BOSS:
		boss_fragment = find_fragment()
		if layer >= layers:
			over = true
			won = true
			changed.emit()
			return
		long_rest_due = true
	var big := room == Room.ELITE or room == Room.BOSS
	for p in players.size():
		me = p
		var gold_range: Array = ELITE_GOLD if big else FIGHT_GOLD
		var got := rng.randi_range(gold_range[0], gold_range[1])
		gold += got
		rewards = {"gold": got, "cards": card_choices(3, ELITE_RARITY if big else FIGHT_RARITY), "relic": ""}
		if big:
			var relic := random_relic()
			if relic != "":
				gain_relic(relic)
				rewards.relic = relic
	me = was
	changed.emit()


func _relics_won():
	for key in relics:
		var relic := CardDatabase.relic(key)
		if relic == null or relic.when != CardRelicDefinition.When.FIGHT_WON or relic.effect == null:
			continue
		match relic.effect.kind:
			CardEffect.Kind.HEAL:
				hp = mini(max_hp, hp + relic.effect.amount)
			CardEffect.Kind.GOLD:
				gold += relic.effect.amount
			CardEffect.Kind.MAX_HP:
				max_hp += relic.effect.amount
				hp += relic.effect.amount
			_:
				continue
		relic_used.emit(key)


## `count` different cards to choose from, by the rarity chances `weights` (common, uncommon, rare): everybody's and the player
## now's character's own, a co-op card only with two.
func card_choices(count: int, weights: Array) -> Array:
	var found := []
	for attempt in count * 8:
		if found.size() >= count:
			break
		var rarity := _weighted_rarity(weights)
		var pool := CardDatabase.cards_of(rarity, character(), together()).filter(func(key): return not found.has(key))
		if pool.is_empty():
			pool = CardDatabase.cards().keys().filter(func(key): return not found.has(key) and CardDatabase.offered_to(key, character(), together()))
		if pool.is_empty():
			break
		found.append(pool[rng.randi_range(0, pool.size() - 1)])
	return found


func _weighted_rarity(weights: Array) -> CardDefinition.Rarity:
	var roll := rng.randi_range(1, weights[0] + weights[1] + weights[2])
	if roll <= weights[0]:
		return CardDefinition.Rarity.COMMON
	if roll <= weights[0] + weights[1]:
		return CardDefinition.Rarity.UNCOMMON
	return CardDefinition.Rarity.RARE


## Takes card `key` into the deck (one of the rewards, an event's, a purchase's).
func take_card(key: String):
	if CardDatabase.card(key) == null:
		return
	deck.append({"key": key, "upgraded": false})
	rewards.erase("cards")
	changed.emit()


## --- The trace (twist 3) ---


## Raises the trace by `amount` (less than nothing lowers it): from TRACE_GLITCH a Glitch into every deck, once; at TRACE_MOST he is
## traced, and the run is over.
func add_trace(amount: int):
	if amount == 0 or traced:
		return
	trace = clampi(trace + amount, 0, TRACE_MOST)
	if trace >= TRACE_GLITCH and not glitched and CardDatabase.card(GLITCH) != null:
		glitched = true
		for each in players:
			each.deck.append({"key": GLITCH, "upgraded": false})
	if trace >= TRACE_MOST:
		traced = true
		over = true
		won = false
	changed.emit()


## --- Fragments (twist 4: the decks are found in pieces) ---


## A code fragment found: of the locked character nearest to opening (CardUnlocks). Its character, or "" with all open.
func find_fragment() -> String:
	var key := CardUnlocks.nearest_locked()
	if key == "":
		return ""
	var opened := CardUnlocks.add_fragment(key)
	fragments_found.append({"character": key, "opened": opened})
	return key


## --- Relics ---


## A relic not had yet, at random, of any rarity but the starter's and a Blessing's; "" when there are none left.
func random_relic() -> String:
	var pool := CardDatabase.relics().keys().filter(func(key): return not relics.has(key) and CardDatabase.relic(key).offered())
	if pool.is_empty():
		return ""
	return pool[rng.randi_range(0, pool.size() - 1)]


## --- Blessings (twist 15: the run's first choice, after the gate) ---


## Up to `count` Blessings for the player now to choose one of, at random, kept for the screen (and the same on both machines).
func blessing_choices(count: int = 3) -> Array:
	var pool := CardDatabase.relics().keys().filter(func(key): return CardDatabase.relic(key).rarity == CardRelicDefinition.Rarity.BLESSING)
	_shuffle(pool)
	players[me].blessing_offers = pool.slice(0, count)
	return players[me].blessing_offers


## The player now takes Blessing `key` (one of their offers); "" takes none. False if it is not one of them.
func choose_blessing(key: String) -> bool:
	if key != "" and not players[me].blessing_offers.has(key):
		return false
	players[me].blessing_offers = []
	players[me].blessing = key
	players[me]["blessed"] = true
	if key != "":
		gain_relic(key)
	changed.emit()
	return true


## Whether somebody has still to choose their Blessing (before the first room, with any Blessings there are).
func blessings_due() -> bool:
	if at >= 0 or layer != 1 or not CardDatabase.relics().values().any(func(relic): return relic.rarity == CardRelicDefinition.Rarity.BLESSING):
		return false
	return players.any(func(each): return not bool(each.get("blessed", false)))


## The chest of the room the players are in, the player now's: a relic not had yet, gained; "" for none. Once a room, whatever asks.
func open_chest() -> String:
	if int(players[me].get("chest_at", -2)) == at:
		return str(players[me].chest)
	players[me].chest_at = at
	var key := random_relic()
	players[me].chest = key
	if key != "":
		gain_relic(key)
	return key


func gain_relic(key: String):
	var relic := CardDatabase.relic(key)
	if relic == null or relics.has(key):
		return
	relics.append(key)
	if relic.when == CardRelicDefinition.When.PICKED_UP and relic.effect != null:
		match relic.effect.kind:
			CardEffect.Kind.MAX_HP:
				max_hp += relic.effect.amount
				hp += relic.effect.amount
				relic_used.emit(key)
			CardEffect.Kind.HEAL:
				hp = mini(max_hp, hp + relic.effect.amount)
				relic_used.emit(key)
			CardEffect.Kind.GOLD:
				gold += relic.effect.amount
				relic_used.emit(key)
	changed.emit()


## --- Rests (twist 13) ---


func rest_amount() -> int:
	return int(ceil(max_hp * REST_SHARE))


## Patch: the player now mends REST_SHARE of their most.
func rest():
	hp = mini(max_hp, hp + rest_amount())
	changed.emit()


## How a short rest can be spent: Patch, Study (with something to upgrade), Cover Tracks (with a trace), and Mend the partner (co-op,
## with them hurt).
func rest_options() -> Array:
	var found := [Rest.PATCH]
	if not upgradable().is_empty():
		found.append(Rest.STUDY)
	if trace > 0:
		found.append(Rest.COVER_TRACKS)
	if together() and int(players[partner_of(me)].hp) < int(players[partner_of(me)].max_hp):
		found.append(Rest.MEND)
	return found


static func rest_name(how: Rest) -> String:
	return ["Patch", "Study", "Cover Tracks", "Mend"][how]


## What the partner would mend (co-op).
func mend_amount() -> int:
	var partner := partner_of(me)
	return int(ceil(int(players[partner].max_hp) * MEND_SHARE)) if partner >= 0 else 0


## The player now spends the rest: Patch, Study (card `index` upgraded), Cover Tracks (TRACE_COVER off the trace) or Mend (the
## partner mends MEND_SHARE of theirs). False if it cannot be done.
func rest_with(how: Rest, index: int = -1) -> bool:
	if not rest_options().has(how):
		return false
	match how:
		Rest.PATCH:
			rest()
		Rest.STUDY:
			return upgrade(index)
		Rest.COVER_TRACKS:
			add_trace(-TRACE_COVER)
		Rest.MEND:
			var partner: Dictionary = players[partner_of(me)]
			partner.hp = mini(int(partner.max_hp), int(partner.hp) + mend_amount())
			changed.emit()
	return true


## The long rest after a layer's boss: everybody mends fully. Each then reshapes their deck (a card out, forgotten, or one
## upgraded: remove_card, upgrade) before next_layer.
func long_rest():
	for each in players:
		each.hp = each.max_hp
	changed.emit()


## Down to the next layer: a new map, and as the last layer begins (of a run of more than one) what Lethe took comes back, upgraded.
func next_layer():
	if layer >= layers:
		return
	long_rest_due = false
	layer += 1
	at = -1
	visited.clear()
	votes.clear()
	_make_map()
	if layer == layers and layers > 1:
		_lethe_returns()
	changed.emit()


## A-letheia, un-forgetting (twist 8): every card taken out of each deck this run comes back into it, upgraded.
func _lethe_returns():
	for each in players:
		each.lethe_back = []
		for card in each.forgotten:
			var back := {"key": card.key, "upgraded": true}
			each.deck.append(back)
			each.lethe_back.append(back)
		each.forgotten.clear()


## The deck's cards that upgrading would change (their indexes).
func upgradable() -> Array:
	var found := []
	for i in deck.size():
		var definition := CardDatabase.card(deck[i].key)
		if not deck[i].upgraded and definition != null and definition.upgrades():
			found.append(i)
	return found


func upgrade(index: int) -> bool:
	if not upgradable().has(index):
		return false
	deck[index].upgraded = true
	changed.emit()
	return true


## The deck's cards that can be taken out or rewritten (their indexes): all but the Message.
func removable() -> Array:
	return range(deck.size()).filter(func(i): return str(deck[i].key) != CardDefinition.MESSAGE)


## Takes card `index` out of the deck, for the rest of the run: forgotten, and back at the last layer (Lethe) but for a Status card.
## Never the Message.
func remove_card(index: int) -> bool:
	if not removable().has(index):
		return false
	var card: Dictionary = deck[index]
	deck.remove_at(index)
	var definition := CardDatabase.card(card.key)
	if definition != null and definition.type != CardDefinition.Type.STATUS:
		players[me].forgotten.append(card)
	changed.emit()
	return true


## Rewrites card `index` into another of its rarity at random (a starter into a common), for the player now's character: the
## Shifting Room. The card it became, or "".
func transform_card(index: int) -> String:
	if not removable().has(index):
		return ""
	var was: CardDefinition = CardDatabase.card(deck[index].key)
	var rarity: CardDefinition.Rarity = was.rarity if was != null and was.rarity != CardDefinition.Rarity.STARTER else CardDefinition.Rarity.COMMON
	var pool := CardDatabase.cards_of(rarity, character(), together()).filter(func(key): return key != deck[index].key)
	if pool.is_empty():
		return ""
	var key: String = pool[rng.randi_range(0, pool.size() - 1)]
	deck[index] = {"key": key, "upgraded": bool(deck[index].upgraded)}
	changed.emit()
	return key


## Every half-read card of the deck read at once (Notes on the Wall). How many were.
func read_all() -> int:
	var count := 0
	for card in deck:
		var definition := CardDatabase.card(card.key)
		if definition != null and definition.half_read() and not CardUnlocks.read(card.key):
			CardUnlocks.mark_read(card.key)
			count += 1
	changed.emit()
	return count


## --- The shop ---


## What the shop in this room sells the player now, made the first time it is asked for.
func shop_here() -> Dictionary:
	if not shop.is_empty():
		return shop
	shop = {"cards": [], "relics": []}
	for key in card_choices(SHOP_CARDS, FIGHT_RARITY):
		var rarity: int = CardDatabase.card(key).rarity
		shop.cards.append({"key": key, "price": _priced(CARD_PRICES[clampi(rarity - 1, 0, 2)]), "sold": false})
	var offered := []
	for i in SHOP_RELICS:
		var pool := CardDatabase.relics().keys().filter(func(key): return not relics.has(key) and not offered.has(key) and CardDatabase.relic(key).offered())
		if pool.is_empty():
			break
		var key: String = pool[rng.randi_range(0, pool.size() - 1)]
		offered.append(key)
		var rarity: int = CardDatabase.relic(key).rarity
		shop.relics.append({"key": key, "price": _priced(RELIC_PRICES[clampi(rarity - 1, 0, 2)]), "sold": false})
	return shop


func _priced(base: int) -> int:
	return int(round(base * rng.randf_range(0.9, 1.1)))


func buy_card(index: int) -> bool:
	var stock: Array = shop_here().cards
	if index < 0 or index >= stock.size() or stock[index].sold or gold < stock[index].price:
		return false
	gold -= stock[index].price
	stock[index].sold = true
	deck.append({"key": stock[index].key, "upgraded": false})
	changed.emit()
	return true


func buy_relic(index: int) -> bool:
	var stock: Array = shop_here().relics
	if index < 0 or index >= stock.size() or stock[index].sold or gold < stock[index].price:
		return false
	gold -= stock[index].price
	stock[index].sold = true
	gain_relic(stock[index].key)
	changed.emit()
	return true


## Pays to take card `index` out of the deck, once a shop (Lethe Water: it is forgotten).
func buy_removal(index: int) -> bool:
	if shop_here().get("removed", false) or gold < remove_price or not removable().has(index):
		return false
	gold -= remove_price
	remove_price += REMOVE_PRICE_RISE
	shop.removed = true
	return remove_card(index)


## --- Events (twist 14: the network's oddities) ---


## The event of this room: one not seen yet this run if there is one.
func event_here() -> String:
	var keys := CardDatabase.events().keys()
	if keys.is_empty():
		return ""
	var fresh := keys.filter(func(key): return not _events_seen.has(key))
	var pool := fresh if not fresh.is_empty() else keys
	var key: String = pool[rng.randi_range(0, pool.size() - 1)]
	_events_seen.append(key)
	return key


## Whether `option` can be chosen by the player now: the gold for it, health enough not to die of it, a card for what it does to
## one.
func can_choose(option: CardEventOption) -> bool:
	return gold + option.gold >= 0 and hp + option.hp > 0 and max_hp + option.max_hp > 0 \
		and not (option.action == CardEventOption.Action.UPGRADE_CARD and upgradable().is_empty()) \
		and not (option.action in [CardEventOption.Action.REMOVE_CARD, CardEventOption.Action.TRANSFORM_CARD] and removable().is_empty()) \
		and not (option.action == CardEventOption.Action.MESSAGE and not message_can_grow())


## The options of event `key` as the player now sees them: its own, and listening for a word of the truth for the Message when it
## offers one and has no Message option of its own (twist 10).
func event_options(key: String) -> Array:
	var event: CardEventDefinition = CardDatabase.events().get(key)
	if event == null:
		return []
	var found: Array = event.options.duplicate()
	if event.offers_a_word and not message_of(me).is_empty() \
			and not found.any(func(option): return option != null and option.action == CardEventOption.Action.MESSAGE):
		found.append(_listening())
	return found


## The option every event that offers a word has: listening for it.
static var _listen: CardEventOption = null


static func _listening() -> CardEventOption:
	if _listen == null:
		_listen = CardEventOption.new()
		_listen.label = "Listen: a word of the truth for the Message"
		_listen.outcome = "Under the noise of the place, something true is being said."
		_listen.action = CardEventOption.Action.MESSAGE
	return _listen


## Does what `option` costs and gives in numbers, and what needs no choosing: a relic, the trace, a fragment, a card put in, the
## half-read cards read. What is left to choose (a card, a card to take out, upgrade or rewrite) is its Action, for the screen.
func choose(option: CardEventOption) -> CardEventOption.Action:
	gold += option.gold
	max_hp = maxi(1, max_hp + option.max_hp)
	hp = clampi(hp + option.hp + maxi(option.max_hp, 0), 1, max_hp)
	if option.action == CardEventOption.Action.RANDOM_RELIC:
		var relic := random_relic()
		if relic != "":
			gain_relic(relic)
	if option.adds_card != "" and CardDatabase.card(option.adds_card) != null:
		deck.append({"key": option.adds_card, "upgraded": false})
	if option.fragment:
		find_fragment()
	if option.action == CardEventOption.Action.READ_ALL:
		read_all()
	if option.action == CardEventOption.Action.MESSAGE:
		message_offers()
	# A card to choose from (made here, so both machines of a network game make the same).
	if option.action == CardEventOption.Action.CARD_REWARD:
		players[me].event_cards = card_choices(3, FIGHT_RARITY)
	if option.trace != 0:
		add_trace(option.trace)
	changed.emit()
	return option.action


## --- The Message (twist 10) ---
##
## Every deck has the Message (CardDefinition.MESSAGE): never taken out, rewritten or forgotten, nearly empty at first. An event
## offers ways for it to grow, at random: a new word (CardMessageWord, a line doing its effect each time it is played), a word it has
## deepened, or it spoken lighter (costing less). The player chooses one. At the run's last boss it says every word twice
## (CardBattle.truth_spoken): strong, not a win by itself.


## Player `p`'s Message: {words: [{key, amount, effect, line}], cost, lightened}, or {} without one.
func message_of(p: int) -> Dictionary:
	if p < 0 or p >= players.size():
		return {}
	for card in players[p].deck:
		if str(card.key) == CardDefinition.MESSAGE and card.has("message"):
			return card.message
	return {}


## Whether the player now's Message can grow at all (room for a word, a word to deepen, or its cost to lower).
func message_can_grow() -> bool:
	var message := message_of(me)
	return not message.is_empty() and (message.words.size() < CardDefinition.MESSAGE_MOST_WORDS or not message.words.is_empty()
		or (int(message.cost) > 0 and not bool(message.lightened)))


## Up to `count` ways for the player now's Message to grow, at random (kept for the screen, and the same on both machines of a
## network game): {kind: "word" (a new one, `word` its key), "deepen" (`word`, one it has), or "lighten"}.
func message_offers(count: int = 3) -> Array:
	var message := message_of(me)
	if message.is_empty():
		players[me].message_offers = []
		return []
	var have: Array = message.words.map(func(word): return str(word.key))
	var fresh: Array = []
	for key in CardDatabase.message_words():
		if not have.has(key):
			for i in maxi(CardDatabase.message_word(key).weight, 1):
				fresh.append(key)
	var pool: Array = []
	var room: bool = message.words.size() < CardDefinition.MESSAGE_MOST_WORDS
	for i in 3:
		if not room or fresh.is_empty():
			break
		var key: String = fresh[rng.randi_range(0, fresh.size() - 1)]
		fresh = fresh.filter(func(other): return other != key)
		pool.append({"kind": "word", "word": key})
	if not message.words.is_empty():
		pool.append({"kind": "deepen", "word": str(message.words[rng.randi_range(0, message.words.size() - 1)].key)})
	if int(message.cost) > 0 and not bool(message.lightened):
		pool.append({"kind": "lighten"})
	_shuffle(pool)
	players[me].message_offers = pool.slice(0, count)
	return players[me].message_offers


## The player now's Message grows by offer `index` (of message_offers); -1 lets it be. False if there is no such offer.
func grow_message(index: int) -> bool:
	var offers: Array = players[me].message_offers
	players[me].message_offers = []
	if index < 0:
		changed.emit()
		return true
	if index >= offers.size():
		return false
	var offer: Dictionary = offers[index]
	var message := message_of(me)
	match str(offer.kind):
		"word":
			var word: CardMessageWord = CardDatabase.message_word(str(offer.word))
			if word == null or word.effect == null or message.words.size() >= CardDefinition.MESSAGE_MOST_WORDS:
				return false
			message.words.append({"key": str(offer.word), "amount": word.effect.amount, "effect": word.effect, "line": word.line})
		"deepen":
			for entry in message.words:
				if str(entry.key) == str(offer.word):
					var word: CardMessageWord = CardDatabase.message_word(str(offer.word))
					entry.amount = int(entry.amount) + (word.step if word != null else 1)
		"lighten":
			message.cost = maxi(int(message.cost) - 1, 0)
			message.lightened = true
	changed.emit()
	return true


func _shuffle(list: Array):
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = list[i]
		list[i] = list[j]
		list[j] = swap
