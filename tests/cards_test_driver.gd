extends Node
## The card game (docs/card_game.md): its content loads, a fight follows its rules (damage, block, statuses and how long they last,
## drawing and reshuffling, powers, exhaust, winning and losing), a run makes a map that always reaches the boss and gives what each
## room should, and the screen plays a room through.

var LOG_PATH := HarnessLog.path_for("cards")
var _log: FileAccess
var _fail := 0


func log_line(t: String):
	_log.store_line(t)
	_log.flush()


func ok(condition: bool, label: String, detail: String = ""):
	if condition:
		log_line("  PASS  %s %s" % [label, detail])
	else:
		_fail += 1
		log_line("  FAIL  %s %s" % [label, detail])


func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(300.0).timeout.connect(func(): log_line("DID NOT FINISH"); get_tree().quit(2))
	await get_tree().process_frame
	the_content()
	the_rules()
	the_statuses()
	the_turns()
	the_end_of_a_fight()
	the_run()
	the_beats()
	the_slots()
	how_enemies_choose()
	their_traits()
	into_the_deck()
	as_a_side()
	the_enemies_made()
	the_gates()
	two_players()
	the_layers_and_the_trace()
	half_read_and_the_devourer()
	rests_lethe_and_oddities()
	tethers()
	the_message()
	relics_and_blessings()
	await the_screen()
	await the_feel()
	await the_screen_for_two()
	await the_screen_together()
	await the_hack()
	log_line("FAILURES: %d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func deck_of(keys: Array) -> Array:
	return keys.map(func(key): return {"key": key, "upgraded": false})


## A fight that keeps what it tells the screen: its beats as [what, info], from before it starts.
func heard_fight(keys: Array, enemies: Array, hp: int = 60) -> Array:
	var battle := CardBattle.new(deck_of(keys), enemies, hp, 60, [], 4242)
	var heard := []
	battle.beat.connect(func(what, info): heard.append([what, info]))
	battle.start()
	return [battle, heard]


func kinds(heard: Array) -> Array:
	return heard.map(func(beat): return beat[0])


## A fight against `enemies` with `keys` in the deck, its hand dealt and nothing done yet.
func fight(keys: Array, enemies: Array, hp: int = 60) -> CardBattle:
	var battle := CardBattle.new(deck_of(keys), enemies, hp, 60, [], 4242)
	battle.start()
	return battle


func index_of(battle: CardBattle, key: String) -> int:
	for i in battle.hand.size():
		if battle.hand[i].key == key:
			return i
	return -1


## An enemy made here, for a rule of choosing to be tried on its own: `moves`, `pattern`, its health, its traits.
func made(enemy_name: String, pattern: CardEnemyDefinition.Pattern, moves: Array, statuses: Dictionary = {}, hp: int = 50) -> CardEnemyDefinition:
	var enemy := CardEnemyDefinition.new()
	enemy.name = enemy_name
	enemy.pattern = pattern
	enemy.max_hp_least = hp
	enemy.max_hp_most = hp
	for move in moves:
		enemy.moves.append(move)
	enemy.starting_statuses = statuses
	return enemy


## A move made here, `weight` likely, with a limit or more set by `how` (last, so a one-line lambda can end the call).
func move_with(move_name: String, damage: int, weight: int, how: Callable) -> CardEnemyMove:
	var move := CardEnemyMove.of(move_name, damage, 1, 0, &"", 0, &"", 0, weight)
	how.call(move)
	return move


## The names of what `battle`'s enemy `who` shows over `turns` turns (its health kept up, the player's too).
func intents_over(battle: CardBattle, turns: int, who: int = 0) -> Array:
	var seen := []
	for i in turns:
		seen.append(battle.enemies[who].move.name if battle.enemies[who].move != null else "")
		battle.player.hp = battle.player.max_hp
		battle.enemies[who].hp = battle.enemies[who].max_hp
		battle.end_turn()
	return seen


## Puts card `key` in `battle`'s hand and gives it the energy for it; its index.
func in_hand(battle: CardBattle, key: String) -> int:
	battle.hand.append({"key": key, "upgraded": false, "id": 900 + battle.hand.size() + battle.turn * 20})
	battle.energy = 9
	return battle.hand.size() - 1


func the_content():
	log_line("======== what it is made of ========")
	var cards := CardDatabase.cards()
	ok(cards.size() >= 25, "the cards load", "%d" % cards.size())
	ok(cards.keys().all(func(key): return cards[key].describe(false) != "" and cards[key].name != ""), "every card has a name and says what it does")
	ok(CardDatabase.STARTING_DECK.all(func(key): return cards.has(key)), "the starting deck is all there")
	for rarity in [CardDefinition.Rarity.COMMON, CardDefinition.Rarity.UNCOMMON, CardDefinition.Rarity.RARE]:
		ok(not CardDatabase.cards_of(rarity).is_empty(), "cards to win of every rarity", "%d" % rarity)
	ok(CardDatabase.enemies().size() >= 8, "the enemies load", "%d" % CardDatabase.enemies().size())
	var missing := []
	for key in CardDatabase.encounters():
		for enemy in CardDatabase.encounters()[key].enemies:
			if CardDatabase.enemy(enemy) == null:
				missing.append(enemy)
	ok(missing.is_empty(), "every encounter's enemies exist", "%s" % [missing])
	for tier in [CardEncounterDefinition.Tier.EASY, CardEncounterDefinition.Tier.HARD, CardEncounterDefinition.Tier.ELITE, CardEncounterDefinition.Tier.BOSS]:
		ok(not CardDatabase.encounters_of(tier).is_empty(), "encounters of every kind", "%d" % tier)
	ok(CardDatabase.relics().keys().all(func(key): return CardDatabase.relic(key).describe() != ""), "every relic says what it does")
	ok(CardDatabase.relic(CardDatabase.STARTING_RELIC) != null, "the starting relic is there")
	ok(not CardDatabase.events().is_empty() and CardDatabase.events().values().all(func(event): return not event.options.is_empty()), "events, each with a choice")
	var upgraded := CardDatabase.card("thrust").describe(true)
	ok(upgraded.contains("9") and not CardDatabase.card("thrust").describe(false).contains("9"), "an upgraded card says its upgraded numbers", upgraded)
	log_line("")


func the_rules():
	log_line("======== a fight ========")
	var battle := fight(["thrust", "thrust", "thrust", "thrust", "thrust", "guard", "guard", "guard", "guard", "heavy_swing"], ["rat"])
	ok(battle.hand.size() == CardBattle.HAND_SIZE and battle.draw_pile.size() == 10 - CardBattle.HAND_SIZE, "five cards in hand, the rest to draw")
	ok(battle.energy == CardBattle.ENERGY, "three energy")
	var rat: Dictionary = battle.enemies[0]
	ok(rat.move != null, "the enemy shows what it will do", rat.move.name if rat.move != null else "")
	var thrust := index_of(battle, "thrust")
	if thrust < 0:
		battle.hand.append({"key": "thrust", "upgraded": false, "id": 99})
		thrust = battle.hand.size() - 1
	ok(battle.refusal(thrust, -1) != "", "a card for an enemy is not played at nobody")
	var before: int = rat.hp
	ok(battle.play(thrust, 0), "played at the rat")
	ok(rat.hp == before - 6, "it takes 6", "%d -> %d" % [before, rat.hp])
	ok(battle.energy == 2 and battle.discard_pile.size() == 1, "one energy spent, the card on the discard pile")
	battle.energy = 0
	battle.hand.append({"key": "thrust", "upgraded": false, "id": 100})
	ok(battle.refusal(battle.hand.size() - 1, 0) == "Not enough energy.", "not without the energy")
	battle.energy = 3
	# Block.
	battle.hand.append({"key": "guard", "upgraded": false, "id": 101})
	battle.play(battle.hand.size() - 1)
	ok(battle.player.block == 5, "Guard gives 5 Block", "%d" % battle.player.block)
	# An upgraded card.
	battle.hand.append({"key": "thrust", "upgraded": true, "id": 102})
	before = rat.hp
	battle.play(battle.hand.size() - 1, 0)
	ok(rat.hp == maxi(before - 9, 0), "Thrust+ hits for 9", "%d -> %d" % [before, rat.hp])
	log_line("")


func the_statuses():
	log_line("======== statuses ========")
	var battle := fight(["guard", "guard", "guard", "guard", "guard"], ["sellsword"])
	var enemy: Dictionary = battle.enemies[0]
	ok(battle.attack_damage(battle.player, enemy, 6) == 6, "a plain hit")
	battle.add_status(enemy, &"exposed", 1)
	ok(battle.attack_damage(battle.player, enemy, 6) == 9, "half again on the Exposed")
	battle.add_status(battle.player, &"weakened", 1)
	ok(battle.attack_damage(battle.player, enemy, 6) == 6, "Weakened and Exposed: 6 x 0.75 x 1.5, rounded down", "%d" % battle.attack_damage(battle.player, enemy, 6))
	battle.add_status(battle.player, &"weakened", -1)
	battle.add_status(battle.player, &"might", 2)
	ok(battle.attack_damage(battle.player, {}, 6) == 8, "Might adds to each hit")
	ok(battle.block_gained(battle.player, 5) == 5, "plain Block")
	battle.add_status(battle.player, &"footing", 1)
	ok(battle.block_gained(battle.player, 5) == 6, "Footing adds")
	battle.add_status(battle.player, &"brittle", 1)
	ok(battle.block_gained(battle.player, 5) == 4, "Brittle takes a quarter off, rounded down")
	# Spines bite back.
	var golem := fight(["thrust", "thrust", "thrust", "thrust", "thrust"], ["golem"])
	var hp: int = golem.player.hp
	golem.play(0, 0)
	ok(int(golem.enemies[0].statuses.get(&"spines", 0)) == 3 and golem.player.hp == hp - 3, "Spines: hitting the Golem costs 3", "%d -> %d" % [hp, golem.player.hp])
	log_line("")


func the_turns():
	log_line("======== turns ========")
	var battle := fight(["thrust", "thrust", "guard", "guard", "guard", "guard", "guard"], ["rat"])
	var rat: Dictionary = battle.enemies[0]
	# Exposed from the player's card covers this turn and the next: it counts down at the end of each round.
	battle.hand.append({"key": "heavy_swing", "upgraded": false, "id": 50})
	battle.play(battle.hand.size() - 1, 0)
	ok(int(rat.statuses.get(&"exposed", 0)) == 2, "Heavy Swing: Exposed 2")
	rat.move = CardEnemyMove.of("Wait")
	battle.end_turn()
	ok(int(rat.statuses.get(&"exposed", 0)) == 1, "1 left on the player's next turn")
	rat.move = CardEnemyMove.of("Wait")
	battle.end_turn()
	ok(not rat.statuses.has(&"exposed"), "and gone after that")
	# Block takes a hit first, and goes at the start of the player's turn.
	battle.player.block = 0
	battle.hand.append({"key": "guard", "upgraded": false, "id": 51})
	battle.energy = 3
	battle.play(battle.hand.size() - 1)
	var hp: int = battle.player.hp
	rat.move = CardEnemyMove.of("Bite", 6)
	var bite := battle.attack_damage(rat, battle.player, 6)
	battle.end_turn()
	ok(battle.player.hp == hp - maxi(bite - 5, 0), "the bite goes through the Block first", "%d -> %d" % [hp, battle.player.hp])
	ok(battle.player.block == 0, "and Block is gone at the start of the turn")
	# Weakened put on the player by an enemy lasts their next turn.
	rat.move = CardEnemyMove.of("Gnaw", 3, 1, 0, &"weakened", 1)
	battle.end_turn()
	ok(int(battle.player.statuses.get(&"weakened", 0)) == 1, "the rat's Weakened is on the player for their turn")
	rat.move = CardEnemyMove.of("Wait")
	battle.end_turn()
	ok(not battle.player.statuses.has(&"weakened"), "and gone after it")
	# Poison.
	battle.add_status(rat, &"poison", 3)
	var rat_hp: int = rat.hp
	rat.move = CardEnemyMove.of("Wait")
	battle.end_turn()
	ok(rat.hp == rat_hp - 3 and int(rat.statuses.get(&"poison", 0)) == 2, "Poison: 3 at the start of its turn, then 2", "%d -> %d" % [rat_hp, rat.hp])
	# The discard pile goes back in when the draw pile runs out.
	ok(battle.hand.size() == CardBattle.HAND_SIZE, "a full hand drawn again and again from a small deck", "%d" % battle.hand.size())
	# A power stays out of the deck; an exhausting card goes for the fight.
	var powered := fight(["battle_hymn", "expose", "thrust", "thrust", "thrust"], ["gnawer"])
	var hymn := index_of(powered, "battle_hymn")
	powered.play(hymn)
	ok(int(powered.player.statuses.get(&"might", 0)) == 2 and powered.powers.size() == 1 and powered.discard_pile.is_empty(), "a power: Might 2, and not in the discard pile")
	var expose := index_of(powered, "expose")
	powered.play(expose, 0)
	ok(powered.exhaust_pile.size() == 1 and int(powered.enemies[0].statuses.get(&"exposed", 0)) == 2, "Expose: exhausted, Exposed 2 on the enemy")
	# An enemy that goes in order, and one at random that never does the same thing three times running.
	var in_order := fight(["guard", "guard", "guard", "guard", "guard"], [made("In Order", CardEnemyDefinition.Pattern.CYCLE,
		[CardEnemyMove.of("One", 1), CardEnemyMove.of("Two", 1), CardEnemyMove.of("Three", 1)])])
	var seen := []
	for i in 4:
		seen.append(in_order.enemies[0].move.name)
		in_order.player.hp = 60
		in_order.end_turn()
	ok(seen == ["One", "Two", "Three", "One"], "an enemy in order goes round its moves", "%s" % [seen])
	var random_one := fight(["guard", "guard", "guard", "guard", "guard"], ["rat"])
	var thrice := false
	for i in 40:
		random_one.player.hp = 60
		random_one.end_turn()
		var history: Array = random_one.enemies[0].history
		if history.size() >= 3 and history[-1] == history[-2] and history[-2] == history[-3]:
			thrice = true
	ok(not thrice, "the Rat never does the same move three times running")
	log_line("")


func the_end_of_a_fight():
	log_line("======== the end of a fight ========")
	var battle := fight(["thrust", "thrust", "thrust", "thrust", "thrust"], ["rat"])
	var result := []
	battle.ended.connect(func(won): result.append(won))
	battle.enemies[0].hp = 1
	battle.enemies[0].block = 0
	battle.play(0, 0)
	ok(battle.over and battle.won and result == [true], "the last enemy down: won")
	ok(battle.refusal(0, 0) != "", "and nothing more is played")
	var lost := fight(["guard", "guard", "guard", "guard", "guard"], ["sellsword"], 3)
	lost.enemies[0].move = CardEnemyMove.of("Slash", 11)
	lost.end_turn()
	ok(lost.over and not lost.won and lost.player.hp == 0, "the player down: lost")
	log_line("")


func reaches_boss(run: CardRun, id: int, memo: Dictionary) -> bool:
	if memo.has(id):
		return memo[id]
	var room: Dictionary = run.rooms[id]
	var found: bool = room.room == CardRun.Room.BOSS
	for to in room.next:
		if reaches_boss(run, to, memo):
			found = true
	memo[id] = found
	return found


func the_run():
	log_line("======== a run ========")
	var run := CardRun.new(777)
	# Its deck and the Message (twist 10, in every deck).
	ok(run.deck.size() == CardDatabase.STARTING_DECK.size() + 1 and run.deck[-1].key == CardDefinition.MESSAGE and run.relics == [CardDatabase.STARTING_RELIC]
		and run.hp == CardRun.START_HP and run.gold == CardRun.START_GOLD, "a run starts with its deck and the Message, its relic, its health and its gold")
	var memo := {}
	var all_reach := run.rooms.keys().all(func(id): return reaches_boss(run, id, memo))
	ok(all_reach, "every room leads to the boss")
	var bosses := run.rooms.values().filter(func(room): return room.room == CardRun.Room.BOSS)
	ok(bosses.size() == 1 and bosses[0].floor == CardRun.FLOORS, "one boss, at the top")
	ok(run.rooms.values().all(func(room): return room.floor != 0 or room.room == CardRun.Room.FIGHT), "the first floor is fights")
	ok(run.rooms.values().all(func(room): return room.floor != CardRun.FLOORS - 1 or room.room == CardRun.Room.REST), "a rest before the boss")
	ok(run.rooms.values().all(func(room): return room.floor != floori(CardRun.FLOORS / 2.0) or room.room == CardRun.Room.TREASURE), "treasure halfway")
	var starts := run.choices()
	ok(starts.size() >= 2, "more than one way to start", "%d" % starts.size())
	ok(not run.go_to(run.rooms.size() + 5), "nowhere that is not a choice")
	run.go_to(starts[0])
	var battle := run.new_battle()
	ok(not battle.enemies.is_empty(), "a fight", "%s" % [battle.enemies.map(func(enemy): return enemy.name)])
	battle.start()
	battle.player.hp = 40
	for enemy in battle.enemies:
		enemy.hp = 0
		enemy.alive = false
	battle._check_end()
	run.finish_battle()
	ok(run.fights_won == 1 and run.hp == 46, "won: Field Dressing mends 6", "%d" % run.hp)
	ok(run.rewards.gold >= CardRun.FIGHT_GOLD[0] and run.rewards.gold <= CardRun.FIGHT_GOLD[1] and run.gold == CardRun.START_GOLD + run.rewards.gold, "gold for it")
	var offered: Array = run.rewards.cards
	ok(offered.size() == 3 and offered.all(func(key): return CardDatabase.card(key).rarity != CardDefinition.Rarity.STARTER), "three cards to choose from, none a starter", "%s" % [offered])
	ok(offered.size() == 3 and offered[0] != offered[1] and offered[1] != offered[2] and offered[0] != offered[2], "all different")
	run.take_card(offered[0])
	ok(run.deck.size() == CardDatabase.STARTING_DECK.size() + 2, "one taken into the deck")
	# A rest.
	run.hp = 30
	run.rest()
	ok(run.hp == 30 + int(ceil(run.max_hp * CardRun.REST_SHARE)), "a rest mends three tenths", "%d" % run.hp)
	var index: int = run.upgradable()[0]
	ok(run.upgrade(index) and run.deck[index].upgraded and not run.upgrade(index), "a card upgraded, once")
	# A shop.
	run.gold = 1000
	var stock := run.shop_here()
	ok(stock.cards.size() == CardRun.SHOP_CARDS and stock.relics.size() == CardRun.SHOP_RELICS, "a shop of cards and relics", "%d, %d" % [stock.cards.size(), stock.relics.size()])
	var size := run.deck.size()
	var price: int = stock.cards[0].price
	ok(run.buy_card(0) and run.deck.size() == size + 1 and run.gold == 1000 - price and not run.buy_card(0), "a card bought, and only once")
	var relics := run.relics.size()
	ok(run.buy_relic(0) and run.relics.size() == relics + 1, "a relic bought")
	size = run.deck.size()
	var removal := run.remove_price
	ok(run.buy_removal(0) and run.deck.size() == size - 1 and run.remove_price == removal + CardRun.REMOVE_PRICE_RISE, "a card taken out, dearer next time")
	ok(not run.buy_removal(0), "once a shop")
	run.gold = 0
	run.shop = {}
	run.shop_here()
	ok(not run.buy_card(0), "not without the gold")
	# Relics and events.
	var most := run.max_hp
	run.gain_relic("heart_charm")
	ok(run.max_hp == most + 8 or run.relics.count("heart_charm") == 1, "Heart Charm: 8 more health at most", "%d -> %d" % [most, run.max_hp])
	var paying := CardEventOption.new()
	paying.gold = -50
	run.gold = 20
	ok(not run.can_choose(paying), "an event's price not paid without the gold")
	run.gold = 60
	run.choose(paying)
	ok(run.gold == 10, "and paid with it")
	var relic_option := CardEventOption.new()
	relic_option.action = CardEventOption.Action.RANDOM_RELIC
	relics = run.relics.size()
	run.choose(relic_option)
	ok(run.relics.size() == relics + 1, "an event's relic")
	# The end of a run.
	var lost := CardRun.new(778)
	lost.go_to(lost.choices()[0])
	var losing := lost.new_battle()
	losing.start()
	losing.player.hp = 0
	losing._check_end()
	lost.finish_battle()
	ok(lost.over and not lost.won and lost.choices().is_empty(), "a fight lost ends the run")
	log_line("")


func the_beats():
	log_line("======== what a fight tells the screen ========")
	var made := heard_fight(["thrust", "thrust", "thrust", "guard", "guard", "guard", "guard", "heavy_swing", "twin_cut", "expose"], ["rat"])
	var battle: CardBattle = made[0]
	var heard: Array = made[1]
	var start := kinds(heard)
	ok(start.size() > 0 and start[0] == &"shuffled" and heard[0][1].start, "a fight starts with the deck shuffled", "%s" % [start.slice(0, 3)])
	ok(start.has(&"intent") and start.has(&"turn"), "the enemies show what they will do, and the turn begins")
	ok(start.count(&"drawn") == CardBattle.HAND_SIZE and start.find(&"turn") < start.find(&"drawn"), "five cards drawn, after the turn begins")
	var energy_at := start.find(&"energy")
	ok(energy_at >= 0 and int(heard[energy_at][1].energy) == CardBattle.ENERGY, "the energy filled")
	# A card played.
	heard.clear()
	var rat: Dictionary = battle.enemies[0]
	var at := index_of(battle, "thrust")
	if at < 0:
		battle.hand.append({"key": "thrust", "upgraded": false, "id": 90})
		at = battle.hand.size() - 1
	var foreseen := battle.preview_damage(at, 0)
	var before: int = rat.hp
	battle.play(at, 0)
	ok(foreseen == before - int(rat.hp), "the preview on its bar is what the card takes", "%d, %d" % [foreseen, before - int(rat.hp)])
	var played := kinds(heard)
	ok(played.slice(0, 2) == [&"played", &"energy"] and played.has(&"hit") and played[-1] == &"card_gone", "a card played: played, energy, the hit, gone", "%s" % [played])
	var hit: Dictionary = heard[played.find(&"hit")][1]
	ok(int(hit.to) == 0 and int(hit.from) == -1 and int(hit.lost) == 6 and int(hit.hp) == int(rat.hp), "the hit says who, how much and what is left", "%s" % [hit])
	ok(heard[-1][1].to == &"discard", "and it went to the discard pile")
	# Block taking a blow, through the beats.
	heard.clear()
	battle.hand.append({"key": "guard", "upgraded": false, "id": 91})
	battle.energy = 3
	battle.play(battle.hand.size() - 1)
	var block_at := kinds(heard).find(&"block")
	ok(block_at >= 0 and int(heard[block_at][1].block) == 5 and int(heard[block_at][1].change) == 5, "Block gained: +5")
	heard.clear()
	rat.move = CardEnemyMove.of("Bite", 7)
	battle.end_turn()
	var turn := kinds(heard)
	ok(turn[0] == &"discarded" and turn.has(&"enemy_turn") and turn.find(&"move") > turn.find(&"enemy_turn"), "End Turn: the hand discarded, then the enemies' turn and the rat's move", "%s" % [turn.slice(0, 5)])
	var struck: Dictionary = heard[turn.find(&"hit")][1]
	ok(int(struck.to) == -1 and int(struck.blocked) == 5 and int(struck.lost) == maxi(int(struck.damage) - 5, 0), "the bite through the Block", "%s" % [struck])
	ok(turn.has(&"move_done") and turn.find(&"intent") > turn.find(&"move_done") and turn.find(&"turn") > turn.find(&"intent"), "then what it will do next, then the player's turn")
	# Statuses: put on, and wearing off.
	heard.clear()
	battle.energy = 3
	battle.hand.append({"key": "expose", "upgraded": false, "id": 92})
	battle.play(battle.hand.size() - 1, 0)
	var put := heard.filter(func(beat): return beat[0] == &"status")
	ok(put.size() == 1 and put[0][1].key == &"exposed" and int(put[0][1].before) == 0 and int(put[0][1].after) == 2, "Exposed put on: 0 to 2")
	ok(heard[-1][1].to == &"exhaust", "Expose exhausts")
	heard.clear()
	rat.move = CardEnemyMove.of("Wait")
	battle.end_turn()
	var wore := heard.filter(func(beat): return beat[0] == &"status" and beat[1].key == &"exposed")
	ok(wore.size() == 1 and int(wore[0][1].after) == 1, "and wearing off: 2 to 1 at the round's end")
	# Poison.
	heard.clear()
	battle.add_status(rat, &"poison", 2)
	rat.move = CardEnemyMove.of("Wait")
	battle.end_turn()
	var bite := heard.filter(func(beat): return beat[0] == &"poison")
	ok(bite.size() == 1 and int(bite[0][1].who) == 0 and int(bite[0][1].lost) == 2, "Poison biting at the start of its turn")
	# Spines.
	var spiked := heard_fight(["thrust", "thrust", "thrust", "thrust", "thrust"], ["golem"])
	var golem_fight: CardBattle = spiked[0]
	var spiked_heard: Array = spiked[1]
	spiked_heard.clear()
	golem_fight.play(0, 0)
	var back := spiked_heard.filter(func(beat): return beat[0] == &"spines")
	ok(back.size() == 1 and int(back[0][1].from) == 0 and int(back[0][1].to) == -1 and int(back[0][1].lost) == 3, "Spines biting back")
	# A flurry and the last enemy down.
	var last := heard_fight(["twin_cut", "twin_cut", "twin_cut", "twin_cut", "twin_cut"], ["rat"])
	var ending: CardBattle = last[0]
	var ending_heard: Array = last[1]
	ending.enemies[0].hp = 5
	ending.enemies[0].block = 0
	ending_heard.clear()
	ending.play(0, 0)
	var end_kinds := kinds(ending_heard)
	var hits := ending_heard.filter(func(beat): return beat[0] == &"hit")
	ok(hits.size() >= 1 and int(hits[0][1].of) == 2 and int(hits[0][1].nth) == 0, "a flurry's hits say which of how many")
	ok(end_kinds.has(&"fell") and ending_heard[end_kinds.find(&"fell")][1].last and end_kinds[-1] == &"ended" and ending_heard[-1][1].won,
		"the last enemy falls, and the fight is won", "%s" % [end_kinds])
	ok(end_kinds.find(&"card_gone") < end_kinds.find(&"ended"), "the card goes before the fight ends")
	# The beats change nothing: the same fight with and without anybody listening comes out the same.
	var quiet := fight(["thrust", "thrust", "thrust", "guard", "guard"], ["sellsword"])
	var loud: CardBattle = heard_fight(["thrust", "thrust", "thrust", "guard", "guard"], ["sellsword"])[0]
	for i in 3:
		quiet.end_turn()
		loud.end_turn()
	ok(quiet.player.hp == loud.player.hp and quiet.enemies[0].hp == loud.enemies[0].hp and quiet.turn == loud.turn, "listening changes nothing in the fight")
	log_line("")


## The slots: every sound the card game asks for is in the sound bank, with a stand-in; every picture in CardLooks.
func the_slots():
	log_line("======== its slots ========")
	var bank_slots := []
	for property in SoundBank.new().get_property_list():
		bank_slots.append(StringName(property.name))
	var picture_slots := []
	for property in CardLooks.new().get_property_list():
		picture_slots.append(StringName(property.name))
	# Every &"card_..." the card game's code names is a sound (or tune), but its pictures' slots, a count kept for a suite and the
	# beat a card going makes.
	var asked := []
	for file in DirAccess.get_files_at("res://cards"):
		if not file.ends_with(".gd"):
			continue
		var text := FileAccess.get_file_as_string("res://cards/" + file)
		var finder := RegEx.create_from_string("&\"(card_[a-z_]+)\"")
		for found in finder.search_all(text):
			var slot := StringName(found.get_string(1))
			if not asked.has(slot) and not picture_slots.has(slot) and not slot in [&"card_refused", &"card_gone"]:
				asked.append(slot)
	var missing := asked.filter(func(slot): return not bank_slots.has(slot))
	ok(asked.size() >= 30 and missing.is_empty(), "every sound and tune the card game asks for is a slot in the sound bank", "%d asked, missing %s" % [asked.size(), missing])
	var no_stand_in := asked.filter(func(slot): return not String(slot).begins_with("card_music") and slot != &"card_rest_fire" and not PlaceholderSounds.RECIPES.has(String(slot)))
	ok(no_stand_in.is_empty(), "each with a stand-in while it is empty (but the fire's crackle and the music)", "%s" % [no_stand_in])
	var looks := CardLooks.now()
	ok(looks != null and load(CardLooks.PATH) is CardLooks, "the pictures' slots load (data/card_looks.tres)")
	var look_slots := []
	for property in looks.get_property_list():
		look_slots.append(StringName(property.name))
	var wanted := [&"card_back", &"energy_orb", &"block_shield", &"intent_attack", &"intent_attack_heavy", &"intent_block", &"intent_grow",
		&"intent_curse", &"intent_unknown", &"room_fight", &"room_elite", &"room_rest", &"room_shop", &"room_event", &"room_chest",
		&"room_boss", &"map_marker", &"rest_fire", &"chest_closed", &"chest_open", &"coin", &"hit_slash", &"player_picture"]
	for key in CardStatus.ALL:
		wanted.append(StringName("status_" + String(key)))
	ok(wanted.all(func(slot): return look_slots.has(slot)), "a picture slot for each", "%s" % [wanted.filter(func(slot): return not look_slots.has(slot))])
	# The pace.
	Comfort.set_card_fast(true)
	Comfort.forget()
	ok(Comfort.card_fast() and is_equal_approx(CardFeel.time(1.0), CardFeel.FAST), "Fast plays it all at half the time, and is kept")
	Comfort.set_card_fast(false)
	ok(is_equal_approx(CardFeel.time(1.0), 1.0), "Normal at its own")
	# A blow's weight, by the tactics fights' own thresholds.
	ok(CardFeel.stop_for(5, 100) == 0.0 and CardFeel.stop_for(10, 100) == Combat.HIT_STOP_MINIMUM and CardFeel.stop_for(40, 100) >= Combat.HIT_STOP_HEAVY
		and CardFeel.stop_for(1, 100, true) == Combat.HIT_STOP_KILL, "a blow's stop: none for a scratch, more for more, most for the last")
	ok(CardFeel.shake_for(20, 100) == 0.0 and CardFeel.shake_for(50, 100) > Combat.SHAKE_HEAVY and CardFeel.shake_for(1, 100, true) == Combat.SHAKE_KILL, "and its shake")
	log_line("")


## --- How enemies choose, and their traits (docs/proposals_2026-11-27_card_ai.md; the designer: "Do them all") ---

const R := CardEnemyDefinition.Pattern.RANDOM
const C := CardEnemyDefinition.Pattern.CYCLE
const GUARDS := ["guard", "guard", "guard", "guard", "guard", "guard", "guard", "guard", "guard", "guard"]
const THRUSTS := ["thrust", "thrust", "thrust", "thrust", "thrust", "thrust", "thrust"]


func how_enemies_choose():
	log_line("======== how enemies choose ========")
	# 1. An opening move.
	var opener := fight(GUARDS, [made("Opener", R, [CardEnemyMove.of("Plain", 1, 1, 0, &"", 0, &"", 0, 9), move_with("Hello", 1, 1, func(move): move.first = true)])])
	ok(opener.enemies[0].move.name == "Hello", "its opening move first", opener.enemies[0].move.name)
	# 2. Limits.
	var twice := fight(GUARDS, [made("Twice", R, [move_with("Often", 1, 100, func(move): move.not_twice_running = true), CardEnemyMove.of("Else", 1)])])
	var often := intents_over(twice, 30)
	var ran_twice := false
	for i in range(1, often.size()):
		if often[i] == "Often" and often[i - 1] == "Often":
			ran_twice = true
	ok(not ran_twice and often.count("Often") >= 10, "never twice running, and still often", "%d of 30" % often.count("Often"))
	var once := fight(GUARDS, [made("Once", R, [move_with("Rare", 1, 100, func(move): move.most_times = 1), CardEnemyMove.of("Else", 1)])])
	ok(intents_over(once, 20).count("Rare") == 1, "at most once a fight")
	var late := fight(GUARDS, [made("Late", R, [move_with("Later", 1, 100, func(move): move.not_before_turn = 3), CardEnemyMove.of("Else", 1)])])
	var late_seen := intents_over(late, 6)
	ok(late_seen.slice(0, 2).count("Later") == 0 and late_seen.slice(2).count("Later") >= 2, "not before its turn 3", "%s" % [late_seen])
	var cool := fight(GUARDS, [made("Cool", R, [move_with("Big", 1, 100, func(move): move.cooldown = 2), CardEnemyMove.of("Else", 1)])])
	var cool_seen := intents_over(cool, 15)
	var too_soon := false
	for i in cool_seen.size():
		if cool_seen[i] == "Big" and cool_seen.slice(maxi(i - 2, 0), i).has("Big"):
			too_soon = true
	ok(not too_soon and cool_seen.count("Big") >= 4, "two of its turns between, every time", "%s" % [cool_seen])
	# 3. A countdown.
	var bomb := fight(GUARDS, [made("Fuse", C, [move_with("Blast", 10, 1, func(move): move.wind_up = 1), CardEnemyMove.of("Tick", 1)])])
	ok(bomb.enemies[0].move.name == "Blast" and int(bomb.intent_of(bomb.enemies[0]).countdown) == 2, "a countdown shows its turns: 2")
	var hp: int = bomb.player.hp
	bomb.end_turn()
	ok(bomb.player.hp == hp and bomb.enemies[0].move.name == "Blast" and int(bomb.intent_of(bomb.enemies[0]).countdown) == 1,
		"it winds up, and shows 1", "%d -> %d" % [hp, bomb.player.hp])
	hp = bomb.player.hp
	bomb.end_turn()
	ok(bomb.player.hp == hp - 10 and bomb.enemies[0].move.name == "Tick", "then it lands, and goes on", "%d -> %d" % [hp, bomb.player.hp])
	# 5. Rules, and a move only a rule chooses.
	var mend := CardEnemyMove.of("Mend Self")
	mend.heal = 10
	mend.rule_only = true
	var hurt_one := made("Hurt", R, [CardEnemyMove.of("Hit", 3), mend])
	hurt_one.rules.append(CardEnemyRule.of(CardEnemyRule.When.ITS_HEALTH_UNDER, "Mend Self", 50))
	var ruled := fight(GUARDS, [hurt_one])
	ok(intents_over(ruled, 6).count("Mend Self") == 0, "a move only a rule chooses is not its pattern's")
	ruled.enemies[0].hp = 10
	ruled.end_turn()
	ok(ruled.enemies[0].move.name == "Mend Self", "hurt, its rule chooses it", ruled.enemies[0].move.name)
	ruled.end_turn()
	ok(ruled.enemies[0].hp == 20, "and it mends", "%d" % ruled.enemies[0].hp)
	# 22. Rules by the fight's tier, and the run's Challenge.
	var picky := made("Picky", C, [CardEnemyMove.of("Plain", 1), CardEnemyMove.of("Clever", 1)])
	picky.rules.append(CardEnemyRule.of(CardEnemyRule.When.ALWAYS, "Clever", 0, &"", CardEncounterDefinition.Tier.HARD))
	var easy := CardBattle.new(deck_of(GUARDS), [picky], 60, 60, [], 4242)
	easy.start()
	ok(easy.enemies[0].move.name == "Plain", "a rule for harder fights is not used in an easy one")
	var hard := CardBattle.new(deck_of(GUARDS), [picky], 60, 60, [], 4242)
	hard.tier = CardEncounterDefinition.Tier.HARD
	hard.start()
	ok(hard.enemies[0].move.name == "Clever", "but is in a hard one")
	var challenged := CardBattle.new(deck_of(GUARDS), [picky], 60, 60, [], 4242)
	challenged.set_challenge(1)
	challenged.start()
	ok(challenged.enemies[0].move.name == "Clever", "and in an easy one at Challenge 1")
	var tougher := CardBattle.new(deck_of(GUARDS), [made("Tough", R, [CardEnemyMove.of("Hit", 1)], {}, 40)], 60, 60, [], 4242)
	tougher.set_challenge(3)
	ok(tougher.enemies[0].max_hp == 44 and int(tougher.enemies[0].statuses.get(&"might", 0)) == 1, "Challenge 2: a tenth more health; 3: Might 1",
		"%d, %s" % [tougher.enemies[0].max_hp, tougher.enemies[0].statuses])
	# 6. A move leaning likelier while its lean holds.
	var weaken := CardEnemyMove.of("Weaken", 1)
	weaken.lean_when = CardEnemyRule.When.PLAYER_LACKS
	weaken.lean_status = &"weakened"
	weaken.lean_factor = 9.0
	var leaned := intents_over(fight(GUARDS, [made("Leaning", R, [weaken, CardEnemyMove.of("Hit", 1)])]), 40).count("Weaken")
	ok(leaned >= 24, "a move leans likelier while its lean holds", "%d of 40" % leaned)
	# 7. Honest: what it shows is what it does.
	var honest := heard_fight(GUARDS, ["sellsword", "rat", "alchemist"])
	var watched: CardBattle = honest[0]
	var heard: Array = honest[1]
	var lied := []
	for i in 12:
		watched.player.hp = 60
		var shown_names := watched.enemies.map(func(enemy): return enemy.move.name if enemy.move != null and enemy.alive else "")
		heard.clear()
		watched.end_turn()
		for beat in heard:
			if beat[0] == &"move" and shown_names[int(beat[1].who)] != str(beat[1].name):
				lied.append("%s: %s" % [shown_names[int(beat[1].who)], beat[1].name])
	ok(lied.is_empty(), "what an enemy shows is what it does", "%s" % [lied])
	# 21. Second Sight.
	var seer := CardBattle.new(deck_of(GUARDS), [made("Seen", C, [CardEnemyMove.of("One", 1), CardEnemyMove.of("Two", 1), CardEnemyMove.of("Three", 1)])],
		60, 60, ["second_sight"], 4242)
	seer.start()
	var now := seer.intent_of(seer.enemies[0])
	ok(seer.foresight and now.has("then") and str(now.then.name) == "Two", "Second Sight: what it means to do after")
	seer.end_turn()
	ok(seer.enemies[0].move.name == "Two", "and it does")
	var blind := fight(GUARDS, ["rat"])
	ok(not blind.intent_of(blind.enemies[0]).has("then"), "without it, nothing after")
	# 20. Unseen until hit.
	var veiled := made("Veiled", R, [CardEnemyMove.of("Hit", 1)])
	veiled.shows = CardEnemyDefinition.Shows.ONCE_HIT
	var veil := fight(THRUSTS, [veiled])
	ok(veil.intent_of(veil.enemies[0]).hidden, "one unseen until hit: its intent hidden")
	veil.play(0, 0)
	ok(not veil.intent_of(veil.enemies[0]).hidden and str(veil.intent_of(veil.enemies[0]).name) == "Hit", "hit, it is seen")
	veil.end_turn()
	ok(veil.intent_of(veil.enemies[0]).hidden, "and unseen again as it chooses anew")
	log_line("")


func their_traits():
	log_line("======== their traits ========")
	# 8, 9. Enrage and Curiosity.
	var angry := fight(GUARDS, [made("Angry", R, [CardEnemyMove.of("Hit", 1)], {"enrage": 2, "curiosity": 3})])
	angry.play(in_hand(angry, "guard"))
	ok(int(angry.enemies[0].statuses.get(&"might", 0)) == 2, "Enrage: a Skill played, Might 2")
	angry.play(in_hand(angry, "battle_hymn"))
	ok(int(angry.enemies[0].statuses.get(&"might", 0)) == 5, "Curiosity: a Power played, Might 3 more")
	angry.play(in_hand(angry, "thrust"), 0)
	ok(int(angry.enemies[0].statuses.get(&"might", 0)) == 5, "an Attack, nothing")
	# 10. Toll and Overtime.
	var tolled := fight(GUARDS, [made("Toller", R, [CardEnemyMove.of("Wait")], {"toll": 2})])
	var hp: int = tolled.player.hp
	tolled.play(in_hand(tolled, "guard"))
	ok(tolled.player.hp == hp - 2, "Toll: a card played costs 2", "%d -> %d" % [hp, tolled.player.hp])
	var clock := fight(GUARDS, [made("Clock", R, [CardEnemyMove.of("Wait")], {"overtime": 2})])
	var turn_was := clock.turn
	clock.play(in_hand(clock, "guard"))
	ok(clock.turn == turn_was, "Overtime 2: one card, still your turn")
	clock.play(in_hand(clock, "guard"))
	ok(clock.turn == turn_was + 1 and clock.cards_played == 0, "two, and your turn is over", "%d -> %d" % [turn_was, clock.turn])
	# 11. Reactive.
	var restless := fight(THRUSTS, [made("Restless", R, [CardEnemyMove.of("One", 1), CardEnemyMove.of("Two", 1), CardEnemyMove.of("Three", 1)], {"reactive": 1}, 200)])
	var before: String = restless.enemies[0].move.name
	restless.play(0, 0)
	ok(restless.enemies[0].move.name != before, "Reactive: hit, it changes what it will do", "%s -> %s" % [before, restless.enemies[0].move.name])
	# 12. Asleep.
	var sleeper_made := made("Sleeper", R, [CardEnemyMove.of("Hit", 4)], {"asleep": 2}, 100)
	sleeper_made.sleep_block = 5
	var sleeper := fight(THRUSTS, [sleeper_made])
	ok(sleeper.intent_of(sleeper.enemies[0]).asleep, "Asleep: it shows so")
	hp = sleeper.player.hp
	sleeper.end_turn()
	ok(sleeper.player.hp == hp and int(sleeper.enemies[0].statuses.get(&"asleep", 0)) == 1 and sleeper.enemies[0].block == 5,
		"it sleeps a turn, gaining its Block", "%s, block %d" % [sleeper.enemies[0].statuses, sleeper.enemies[0].block])
	sleeper.enemies[0].block = 0
	sleeper.play(0, 0)
	ok(not sleeper.enemies[0].statuses.has(&"asleep") and sleeper.enemies[0].move.name == "Stirring", "hit, it wakes, stirring")
	hp = sleeper.player.hp
	sleeper.end_turn()
	ok(sleeper.player.hp == hp and sleeper.enemies[0].move.name == "Hit", "it does nothing that turn, then fights", sleeper.enemies[0].move.name)
	# 13. Mode Shift.
	var shifting := made("Shifter", R, [CardEnemyMove.of("Hit", 2)], {"mode_shift": 5}, 200)
	shifting.curl_block = 20
	shifting.curl_spines = 3
	shifting.curl_turns = 2
	shifting.curl_grows = 10
	var shifter := fight(THRUSTS, [shifting])
	shifter.play(0, 0)
	var curled: Dictionary = shifter.enemies[0]
	ok(int(curled.curl_left) == 2 and curled.block >= 20 and int(curled.statuses.get(&"spines", 0)) == 3 and shifter.intent_of(curled).curled,
		"Mode Shift: 5 lost, it curls up: Block 20, Spines 3, for 2 turns", "%s, block %d" % [curled.statuses, curled.block])
	shifter.end_turn()
	shifter.end_turn()
	ok(int(curled.curl_left) == 0 and not curled.statuses.has(&"spines") and int(curled.statuses.get(&"mode_shift", 0)) == 15,
		"then it uncurls, and the next curl takes 15", "%s" % [curled.statuses])
	# 19. Invincible.
	var capped := fight(THRUSTS, [made("Capped", R, [CardEnemyMove.of("Wait")], {"invincible": 8}, 200)])
	var big: Dictionary = capped.enemies[0]
	var top: int = big.hp
	capped.play(0, 0)
	capped.play(0, 0)
	ok(big.hp == top - 8, "Invincible 8: two hits of 6, it loses 8", "%d -> %d" % [top, big.hp])
	ok(capped.preview_damage(0, 0) == 0, "and the preview says no more this round")
	capped.end_turn()
	capped.play(0, 0)
	ok(big.hp == top - 14, "a new round, and it can lose again", "%d" % big.hp)
	# 4. A phase.
	var phased := made("Phased", C, [CardEnemyMove.of("Before", 1)], {}, 100)
	var second := CardEnemyPhase.new()
	second.health_under = 50
	second.line = "It changes."
	second.statuses = {"might": 3}
	second.moves.append(CardEnemyMove.of("After", 1))
	phased.phases.append(second)
	var phase_fight := fight(THRUSTS, [phased])
	phase_fight.enemies[0].hp = 52
	phase_fight.play(0, 0)
	ok(int(phase_fight.enemies[0].statuses.get(&"might", 0)) == 3 and phase_fight.enemies[0].move.name == "Before",
		"under half: its phase starts, Might 3, and what it showed stays", phase_fight.enemies[0].move.name)
	phase_fight.end_turn()
	ok(phase_fight.enemies[0].move.name == "After", "from its next choice, its new moves")
	# 17. A split.
	var splitter := made("Splitter", R, [CardEnemyMove.of("Hit", 1)], {}, 100)
	var burst := CardEnemyPhase.new()
	burst.health_under = 50
	burst.splits_into = ["imp", "imp"]
	splitter.phases.append(burst)
	var split_fight := fight(THRUSTS, [splitter])
	split_fight.enemies[0].hp = 52
	split_fight.play(0, 0)
	var imps := split_fight.enemies.filter(func(enemy): return enemy.alive and enemy.key == "imp")
	ok(imps.size() == 2 and imps.all(func(imp): return imp.hp <= 46 and imp.move != null), "under half it splits: two, each with no more than it had left",
		"%s" % [split_fight.enemies.map(func(enemy): return "%s %d" % [enemy.name, enemy.hp])])
	ok(not split_fight.over, "and the fight goes on")
	log_line("")


func into_the_deck():
	log_line("======== into the deck, and the hand ========")
	ok(["wound", "dazed", "slimed", "burn"].all(func(key): return CardDatabase.card(key) != null and CardDatabase.card(key).type == CardDefinition.Type.STATUS),
		"the four Status cards are there")
	var offered_status := false
	for rarity in [CardDefinition.Rarity.COMMON, CardDefinition.Rarity.UNCOMMON, CardDefinition.Rarity.RARE]:
		for key in CardDatabase.cards_of(rarity):
			if CardDatabase.card(key).type == CardDefinition.Type.STATUS:
				offered_status = true
	ok(not offered_status, "and never offered")
	var wounding := CardEnemyMove.of("Wounding")
	wounding.adds_card = "wound"
	wounding.adds_count = 2
	var junk := fight(GUARDS, [made("Junker", C, [wounding])])
	junk.end_turn()
	var wounds := 0
	for pile in [junk.discard_pile, junk.hand, junk.draw_pile]:
		wounds += pile.filter(func(card): return card.key == "wound").size()
	ok(wounds == 2, "a move puts 2 Wounds in the discard pile", "%d" % wounds)
	ok(junk.refusal(in_hand(junk, "wound")) == "It cannot be played.", "a Wound cannot be played")
	var piles := fight(GUARDS, [made("Waiter", C, [CardEnemyMove.of("Wait")])])
	in_hand(piles, "dazed")
	in_hand(piles, "burn")
	var hp: int = piles.player.hp
	piles.end_turn()
	ok(piles.exhaust_pile.any(func(card): return card.key == "dazed"), "Dazed in the hand as the turn ends: exhausted")
	ok(piles.player.hp == hp - 2, "Burn in the hand as the turn ends: 2 lost", "%d -> %d" % [hp, piles.player.hp])
	var slimed_at := in_hand(piles, "slimed")
	ok(piles.refusal(slimed_at) == "" and piles.play(slimed_at) and piles.exhaust_pile.any(func(card): return card.key == "slimed"), "Slimed: played for 1, and gone")
	# 15. Entangled, Confused, a card taken.
	var tangled := fight(["thrust", "thrust", "thrust", "thrust", "thrust", "guard"], [made("Netter", C, [CardEnemyMove.of("Wait")])])
	tangled.add_status(tangled.player, &"entangled", 1)
	ok(tangled.refusal(index_of(tangled, "thrust"), 0) == "Entangled: no Attacks this turn.", "Entangled: no Attacks")
	ok(tangled.refusal(in_hand(tangled, "guard")) == "", "but Skills")
	var muddled := fight(GUARDS, [made("Muddler", C, [CardEnemyMove.of("Wait")])])
	muddled.add_status(muddled.player, &"confused", 2)
	muddled.end_turn()
	var costs := muddled.hand.map(func(card): return muddled.cost_of(card))
	ok(muddled.hand.all(func(card): return card.has("cost_now")) and costs.all(func(cost): return cost >= 0 and cost <= 3),
		"Confused: every card drawn costs 0 to 3", "%s" % [costs])
	var taking := CardEnemyMove.of("Take")
	taking.steals = 1
	var thief_fight := fight(THRUSTS, [made("Thief", C, [taking], {}, 30)])
	thief_fight.end_turn()
	var thief: Dictionary = thief_fight.enemies[0]
	ok(thief.held.size() == 1 and int(thief.statuses.get(&"holding", 0)) == 1, "a card taken from the draw pile: it holds 1")
	var taken: Dictionary = thief.held[0] if not thief.held.is_empty() else {}
	thief.hp = 1
	thief.block = 0
	thief_fight.play(0, 0)
	ok(not taken.is_empty() and thief_fight.hand.any(func(card): return int(card.id) == int(taken.id)), "felled, it gives the card back, into the hand")
	log_line("")


func as_a_side():
	log_line("======== as a side ========")
	# 16. Help for the worst hurt, and for everybody.
	var shield := CardEnemyMove.of("Shield", 0, 1, 7)
	shield.helps = CardEnemyMove.Helps.WORST_HURT_ALLY
	var mending := CardEnemyMove.of("Heal")
	mending.heal = 9
	mending.helps = CardEnemyMove.Helps.WORST_HURT_ALLY
	var team := fight(GUARDS, [made("Shielder", C, [shield, mending]), made("Hurt", C, [CardEnemyMove.of("Wait")]), made("Fine", C, [CardEnemyMove.of("Wait")])])
	team.enemies[1].hp = 10
	team.end_turn()
	ok(team.enemies[1].block == 7 and team.enemies[0].block == 0 and team.enemies[2].block == 0, "its Block goes to the worst hurt of its side",
		"%s" % [team.enemies.map(func(enemy): return enemy.block)])
	team.end_turn()
	ok(team.enemies[1].hp == 19, "and its mending", "%d" % team.enemies[1].hp)
	var everybody := CardEnemyMove.of("Rally", 0, 1, 5)
	everybody.helps = CardEnemyMove.Helps.EVERY_ALLY
	var rally := fight(GUARDS, [made("Rallier", C, [everybody]), made("A", C, [CardEnemyMove.of("Wait")]), made("B", C, [CardEnemyMove.of("Wait")])])
	rally.end_turn()
	ok(rally.enemies.all(func(enemy): return enemy.block == 5), "or every one of its side")
	# Command, and a Pack.
	var commanded := fight(GUARDS, [made("Captain", C, [CardEnemyMove.of("Wait")], {"command": 3}), made("Soldier", C, [CardEnemyMove.of("Hit", 5)], {"pack": 2})])
	ok(commanded.attack_damage(commanded.enemies[1], commanded.player, 5) == 8, "Command 3: the rest of its side hit 3 harder")
	ok(commanded.attack_damage(commanded.enemies[0], commanded.player, 5) == 5, "but not itself")
	commanded.enemies[0].hp = 1
	commanded.enemies[0].block = 0
	commanded.play(in_hand(commanded, "thrust"), 0)
	ok(commanded.attack_damage(commanded.enemies[1], commanded.player, 5) == 7 and int(commanded.enemies[1].statuses.get(&"might", 0)) == 2,
		"the Captain down: no Command, and the Pack gains Might 2")
	# 17. Calling for help, while there is room.
	var calling := CardEnemyMove.of("Call")
	calling.summons = ["imp"]
	var caller := fight(GUARDS, [made("Caller", C, [calling])])
	for i in 5:
		caller.player.hp = 60
		caller.end_turn()
	var standing := caller.enemies.filter(func(enemy): return enemy.alive).size()
	ok(standing == CardBattle.MOST_ENEMIES, "it calls imps in, no more than %d standing" % CardBattle.MOST_ENEMIES, "%d" % standing)
	# 18. Linked.
	var linked := fight(THRUSTS, [made("Left", C, [CardEnemyMove.of("Wait")], {"linked": 2}, 10), made("Right", C, [CardEnemyMove.of("Wait")], {"linked": 2}, 10)])
	linked.enemies[0].hp = 1
	linked.play(0, 0)
	ok(not linked.enemies[0].alive and int(linked.enemies[0].rising) == 2 and not linked.over, "Linked: one down, it will rise in 2")
	linked.end_turn()
	linked.end_turn()
	ok(linked.enemies[0].alive and linked.enemies[0].hp == 5, "and it rises with half its health", "%d" % linked.enemies[0].hp)
	linked.enemies[0].hp = 1
	linked.enemies[1].hp = 1
	linked.play(0, 0)
	linked.play(0, 1)
	ok(linked.over and linked.won, "both down in the same turn: none rises, and the fight is won")
	log_line("")


## The content tools/build_card_ai_content.gd wrote, as the rules read it.
func the_enemies_made():
	log_line("======== the enemies as made ========")
	var problems := []
	for key in CardDatabase.enemies():
		var enemy: CardEnemyDefinition = CardDatabase.enemies()[key]
		for rule in enemy.rules:
			if rule != null and enemy.move_named(rule.move) == null:
				problems.append("%s: a rule for %s" % [key, rule.move])
		for move in enemy.moves:
			if move == null:
				continue
			if move.adds_card != "" and CardDatabase.card(move.adds_card) == null:
				problems.append("%s: %s gives %s" % [key, move.name, move.adds_card])
			for called in move.summons:
				if CardDatabase.enemy(called) == null:
					problems.append("%s calls %s" % [key, called])
		for phase in enemy.phases:
			for into in phase.splits_into:
				if CardDatabase.enemy(into) == null:
					problems.append("%s splits into %s" % [key, into])
		for status in enemy.starting_statuses:
			if not CardStatus.ALL.has(StringName(status)):
				problems.append("%s: no status %s" % [key, status])
	ok(problems.is_empty(), "every rule, card, call, split and trait an enemy names is there", "%s" % [problems])
	ok(CardDatabase.enemies().size() >= 19 and CardDatabase.encounters().size() >= 20, "the new enemies and fights load",
		"%d enemies, %d fights" % [CardDatabase.enemies().size(), CardDatabase.encounters().size()])
	var traits := {"golem": "asleep", "ogre": "enrage", "colossus": "mode_shift", "priest": "curiosity", "rat": "pack", "summoner": "command",
		"phantom_soldier": "linked", "bellkeeper": "toll", "ash_warden": "overtime", "bound_beast": "reactive"}
	var missing := []
	for key in traits:
		var enemy := CardDatabase.enemy(key)
		if enemy == null or not enemy.starting_statuses.keys().any(func(status): return str(status) == traits[key]):
			missing.append("%s %s" % [key, traits[key]])
	ok(missing.is_empty(), "each trait on the enemy it was given to", "%s" % [missing])
	var colossus := CardDatabase.enemy("colossus")
	ok(colossus != null and colossus.phases.size() == 1 and colossus.phases[0].statuses.keys().any(func(status): return str(status) == "invincible"),
		"the Colossus rises at half health, Invincible")
	var bomber := CardDatabase.enemy("bomber")
	ok(bomber != null and bomber.move_named("Bomb") != null and bomber.move_named("Bomb").wind_up > 0, "the Bomber's Bomb counts down")
	ok(CardDatabase.enemy("sorcerer") != null and CardDatabase.enemy("sorcerer").shows == CardEnemyDefinition.Shows.ONCE_HIT, "the Sorcerer is unseen until hit")
	ok(CardDatabase.enemy("mimic") != null and not CardDatabase.enemy("mimic").phases.is_empty() and CardDatabase.enemy("mimic").phases[0].splits_into.size() == 2,
		"the Mimic splits")
	ok(CardDatabase.relic("second_sight") != null and CardDatabase.relic("second_sight").shows_next_moves, "Second Sight is there")
	# Every fight plays out with nothing going wrong: each encounter, eight turns, the player kept standing, the cards played as they can.
	var broke := []
	for key in CardDatabase.encounters():
		var battle := CardBattle.new(deck_of(["thrust", "thrust", "guard", "guard", "thrust", "guard", "heavy_swing", "thrust", "guard", "guard"]),
			CardDatabase.encounters()[key].enemies, 60, 60, ["second_sight"], 77)
		battle.tier = CardDatabase.encounters()[key].tier
		battle.start()
		for i in 8:
			if battle.over:
				break
			battle.player.hp = 60
			for card in battle.hand.duplicate():
				var at := battle.hand.find(card)
				var living := battle.living()
				if at >= 0 and not living.is_empty() and battle.refusal(at, living[0]) == "":
					battle.play(at, living[0])
					if battle.over:
						break
			if not battle.over:
				battle.end_turn()
		if battle.enemies.any(func(enemy): return enemy.alive and enemy.move == null):
			broke.append(key)
	ok(broke.is_empty(), "every fight plays eight turns through, every enemy standing always with a move", "%s" % [broke])
	log_line("")


func the_screen():
	log_line("======== the screen ========")
	CardGame.seed_for_next = 9001
	get_tree().change_scene_to_file(CardGame.SCENE)
	for i in 6:
		await get_tree().process_frame
	var game = get_tree().current_scene
	ok(game is CardGame and game.view == "map", "it opens on the map", "%s" % [game.view if game is CardGame else game])
	if not game is CardGame:
		return
	var buttons: Array = game.find_children("*", "Button", true, false).filter(func(b): return not b.disabled and b.tooltip_text == "Fight")
	ok(buttons.size() == game.run.choices().size(), "a button for each room it can go to", "%d" % buttons.size())
	game.choose_room(game.run.choices()[0])
	await get_tree().process_frame
	ok(game.view == "battle" and game.battle != null and game.battle.hand.size() == CardBattle.HAND_SIZE, "a fight, a hand dealt")
	var hand: Array = game.find_children("*", "CardView", true, false)
	ok(hand.size() == CardBattle.HAND_SIZE, "the hand shown", "%d" % hand.size())
	var battle: CardBattle = game.battle
	var energy := battle.energy
	var playable := -1
	for i in battle.hand.size():
		if battle.refusal(i, 0 if battle.needs_target(i) else -1) == "":
			playable = i
			break
	ok(playable >= 0 and game.play_card(playable, 0 if battle.needs_target(playable) else -1) and battle.energy < energy, "a card played from the screen")
	game.end_turn()
	ok(battle.turn == 2 or battle.over, "a turn ended", "turn %d" % battle.turn)
	game._choose_card(0)
	ok(game._selected == 0 or battle.refusal(0, 0) != "", "a card chosen by its number")
	for enemy in battle.enemies:
		enemy.hp = 0
		enemy.alive = false
	battle._check_end()
	await get_tree().create_timer(CardGame.FIGHT_OVER_SECONDS + 0.3).timeout
	ok(game.view == "rewards" and game.battle == null, "won: the rewards", game.view)
	var size: int = game.run.deck.size()
	game._take_and_leave(game.run.rewards.cards[0])
	await get_tree().process_frame
	ok(game.view == "map" and game.run.deck.size() == size + 1, "a card taken, back on the map")
	game._show_deck()
	await get_tree().process_frame
	ok(game._overlay != null and game._overlay.find_children("*", "CardView", true, false).size() == game.run.deck.size(), "the deck to look at")
	game._close_deck()
	log_line("")


## Waits until `condition` gives something, or `most` seconds (real ones) have gone; what it last gave.
func until(condition: Callable, most: float):
	var began := Time.get_ticks_msec()
	var got = condition.call()
	while not got and Time.get_ticks_msec() - began < int(most * 1000.0):
		await get_tree().process_frame
		got = condition.call()
	return got


func wait_real(seconds: float):
	await get_tree().create_timer(seconds, true, false, true).timeout


## The card game played with everything moving, as it would be seen (CardFeel.plays_headless), at the Fast pace: the hand's views
## stay and the fight is played back a beat at a time, and the screen ends up as the rules have it.
func the_feel():
	log_line("======== how it feels (everything moving) ========")
	CardFeel.plays_headless = true
	CardFeel.seen.clear()
	Comfort.set_card_fast(true)
	CardGame.seed_for_next = 9001
	get_tree().change_scene_to_file(CardGame.SCENE)
	for i in 6:
		await get_tree().process_frame
	var game = get_tree().current_scene
	if not game is CardGame:
		ok(false, "the card game opens", "%s" % [game])
		_done_feeling()
		return
	game.choose_room(game.run.choices()[0])
	ok(game._walking, "the way to the room is walked first")
	var stage = await until(func(): return game.stage, 4.0)
	ok(stage is CardStage and game.view == "battle", "then a wipe into the fight")
	if not stage is CardStage:
		_done_feeling()
		return
	var battle: CardBattle = stage.battle
	await until(func(): return stage._intro_done and not stage._playing and stage.hand.views.size() == battle.hand.size(), 6.0)
	ok(stage.hand.views.size() == CardBattle.HAND_SIZE and stage.hand.order.all(func(id): return stage.hand.views[id] is CardView),
		"the hand dealt: a view each card, kept by its id")
	var first: CardView = stage.hand.views[stage.hand.order[0]]
	var last_card: CardView = stage.hand.views[stage.hand.order[-1]]
	ok(first.rotation < 0.0 and last_card.rotation > 0.0, "the hand as a fan", "%.2f, %.2f" % [first.rotation, last_card.rotation])
	ok(int(CardFeel.seen.get(&"drawn", 0)) >= CardBattle.HAND_SIZE and int(CardFeel.seen.get(&"card_drawn", 0)) >= CardBattle.HAND_SIZE,
		"each card drawn, with its sound")
	ok(stage.enemy_views.all(func(view): return view.figure != null and view.figure.sprite.is_playing()),
		"each enemy stands as its main-game figure, its idle playing")
	ok(stage.enemy_views.all(func(view): return view._intent.visible and view._intent.get_child_count() > 0), "what each will do shown over it")
	var figure: CardFigure = stage.enemy_views[0].figure
	figure.set_health_share(0.1)
	ok(figure.idle_pace() < CombatantSprite.HURT_PACE and figure.idle_pace() >= CombatantSprite.HURT_SLOWEST, "a hurt enemy's idle slower",
		"%.2f" % figure.idle_pace())
	figure.set_health_share(1.0)
	# An attack chosen: its arrow, and its preview on the enemy's bar; then played.
	var attack := -1
	for i in battle.hand.size():
		if battle.needs_target(i) and battle.refusal(i, battle.living()[0]) == "":
			attack = i
			break
	if attack >= 0:
		stage.keys_in_use = true
		stage.choose_card(attack)
		await get_tree().process_frame
		var aimed: int = stage.target
		ok(stage.aim.visible and aimed >= 0 and stage.enemy_views[aimed].previewing() != null,
			"an attack chosen: its arrow, and on the enemy's bar what it would take")
		var id := int(battle.hand[attack].id)
		var others: Array = stage.hand.order.filter(func(other): return other != id)
		var their_views: Array = others.map(func(other): return stage.hand.views[other])
		stage.play_card(attack, aimed)
		await until(func(): return not stage._playing, 4.0)
		var kept := true
		for n in others.size():
			if stage.hand.views.get(others[n]) != their_views[n]:
				kept = false
		ok(kept and not stage.hand.views.has(id), "the card played left the hand; the others' views stayed, not made again")
		ok(stage.enemy_views[aimed].hp == int(battle.enemies[aimed].hp), "the enemy's health shown as the rules have it",
			"%d, %d" % [stage.enemy_views[aimed].hp, battle.enemies[aimed].hp])
		ok(int(CardFeel.seen.get(&"card_hit", 0)) + int(CardFeel.seen.get(&"card_hit_heavy", 0)) >= 1, "the blow heard")
		await until(func(): return stage._flying == 0, 2.0)
		ok(stage.discard_pile.count == battle.discard_pile.size(), "the discard pile counts the card once it has landed")
	# A card that cannot be played.
	var refused := int(CardFeel.seen.get(&"card_refused", 0))
	battle.energy = 0
	if not battle.hand.is_empty():
		stage.choose_card(0)
		ok(int(CardFeel.seen.get(&"card_refused", 0)) == refused + 1 and int(CardFeel.seen.get(&"orb_refused", 0)) >= 1
			and int(CardFeel.seen.get(&"bubble", 0)) >= 1, "with no energy a card shakes its head, the orb flashes red, and why is said")
	# End Turn: the hand waits for the enemies, then comes back.
	stage.end_turn()
	ok(stage._locked, "End Turn: the hand waits while the enemies act")
	await until(func(): return not stage._locked and not stage._playing, 10.0)
	ok(not stage._locked and battle.turn == 2 and stage.hand.views.size() == battle.hand.size(), "and comes back for the next turn, a view each card")
	ok(int(CardFeel.seen.get(&"move", 0)) >= 1 and int(CardFeel.seen.get(&"card_enemy_turn", 0)) >= 1, "each enemy's move played out")
	ok(stage.player_view.hp == int(battle.player.hp), "the player's health shown as the rules have it")
	await wait_real(0.5)
	ok(game._hp_label.text == "Health %d/%d" % [battle.player.hp, game.run.max_hp], "and the run's bar follows it", game._hp_label.text)
	# Won.
	for enemy in battle.enemies:
		enemy.hp = 0
		enemy.alive = false
	battle._check_end()
	await until(func(): return game.view == "rewards", 8.0)
	ok(game.view == "rewards" and int(CardFeel.seen.get(&"card_fight_won", 0)) >= 1, "won: Victory, then the rewards", game.view)
	var rewards: Array = game._body.find_children("*", "CardView", true, false)
	await wait_real(1.4)
	ok(rewards.size() == 3 and rewards.all(func(card): return is_instance_valid(card) and not card.face_down), "the reward cards turned over")
	var deck: int = game.run.deck.size()
	game._take_and_leave(game.run.rewards.cards[0])
	await until(func(): return game.view == "map", 4.0)
	ok(game.view == "map" and game.run.deck.size() == deck + 1, "a card taken flies to the deck, then back to the map")
	# The rooms.
	game._show_treasure()
	await wait_real(1.2)
	var chest = game._body.find_child("Chest", true, false)
	ok(chest is CardIcon and chest.what == &"chest_open", "a chest: its lid flies open")
	game._show_rest()
	await wait_real(0.3)
	ok(game._body.find_child("Fire", true, false) != null, "a rest's fire")
	game._show_event()
	await get_tree().process_frame
	ok(game._typing != null, "an event's words typing out")
	await until(func(): return game._typing == null, 6.0)
	var choices: Array = game._body.find_children("*", "Button", true, false)
	ok(game._typing == null and not choices.is_empty() and choices.all(func(button): return button.visible), "then its choices")
	game._show_shop()
	await wait_real(0.3)
	ok(game.view == "shop", "a shop")
	_done_feeling()
	log_line("")


func _done_feeling():
	CardFeel.plays_headless = false
	Comfort.set_card_fast(false)


## --- Prometheus's hacking (the designer, 2026-11-27): the gates as characters, two players, the twists ---


## Campaign's flags these sections write (fragments found, cards read), taken back.
func _forget_unlocks():
	for key in Campaign.flags.keys():
		if str(key).begins_with("card_fragments:") or str(key).begins_with("card_read:"):
			Campaign.flags.erase(key)
	CardUnlocks.all_open = false


func _killed_all(battle: CardBattle):
	for enemy in battle.enemies:
		enemy.hp = 0
		enemy.alive = false
	battle._check_end()


func _is_glitch(card: Dictionary) -> bool:
	return card.key == "glitch"


func the_gates():
	log_line("======== the gates as characters, and their code fragments ========")
	_forget_unlocks()
	var keys := CardDatabase.characters_in_order()
	ok(keys.size() == 10 and keys[0] == "world" and keys[-1] == "yaldabaoth", "the ten gates, World first", "%s" % [keys])
	ok(keys.all(func(key): return CardDatabase.character(key).health == 60 and CardDatabase.character(key).starting_deck.size() == 11),
		"each as strong as the others: 60 health, eleven cards")
	var missing := []
	for key in keys:
		for card in CardDatabase.character(key).starting_deck:
			if CardDatabase.card(card) == null:
				missing.append(card)
	ok(missing.is_empty(), "every card of every gate's deck there", "%s" % [missing])
	ok(keys.all(func(key): return CardDatabase.character(key).starting_deck.has("scan")), "every deck has a Scan")
	ok(keys.all(func(key): return CardDatabase.character(key).playstyle.contains("\n")), "every gate says how it plays, a line and then more")
	ok(CardUnlocks.unlocked("world") and not CardUnlocks.unlocked("hermes"), "World is open from the start, Hermes not")
	ok(CardUnlocks.unlocked_keys() == ["world"], "only World", "%s" % [CardUnlocks.unlocked_keys()])
	ok(CardUnlocks.nearest_locked() == "hermes", "the nearest to opening: Hermes, first by gate", CardUnlocks.nearest_locked())
	var opened := [CardUnlocks.add_fragment("hermes"), CardUnlocks.add_fragment("hermes"), CardUnlocks.add_fragment("hermes")]
	ok(opened == [false, false, true] and CardUnlocks.unlocked("hermes"), "three fragments of Hermes's code open it", "%s" % [opened])
	ok(not CardUnlocks.add_fragment("hermes") and CardUnlocks.fragments("hermes") == 3, "and no more than its three")
	CardUnlocks.add_fragment("sophia")
	ok(CardUnlocks.nearest_locked() == "sophia", "a gate begun is the nearest to opening", CardUnlocks.nearest_locked())
	CardUnlocks.all_open = true
	ok(CardUnlocks.unlocked_keys().size() == 10, "practice: every gate open")
	CardUnlocks.all_open = false
	var run := CardRun.new(77, ["hermes"])
	ok(run.players.size() == 1 and run.character() == "hermes" and run.deck.size() == 12 and run.deck.any(func(card): return card.key == "lunge")
		and run.deck.any(func(card): return card.key == CardDefinition.MESSAGE), "a run as Hermes: his deck, and the Message")
	ok(run.hp == 60 and run.relics == ["gate_quick_hands"], "his health and his gate's own relic (twist 15)", "%s" % [run.relics])
	ok(CardDatabase.cards_of(CardDefinition.Rarity.COMMON).has("shared_shield") == false and CardDatabase.cards_of(CardDefinition.Rarity.COMMON, "", true).has("shared_shield"),
		"a card for a partner is offered only with two")
	_forget_unlocks()
	log_line("")


func two_players():
	log_line("======== two players (co-op, Slay the Spire 2's way) ========")
	var pair := CardBattle.new(deck_of(GUARDS), [made("Dummy", R, [CardEnemyMove.of("Hit", 6)], {}, 40)], 60, 60, [], 4242, "Hermes")
	ok(pair.add_player(deck_of(THRUSTS), 50, 60, [], "World") == 1 and pair.together(), "a second player joins")
	ok(pair.enemies[0].max_hp == 88, "the enemy has twice the health and a tenth more for two, on the first layer", "%d" % pair.enemies[0].max_hp)
	pair.start()
	ok(pair.players[0].hand.size() == CardBattle.HAND_SIZE and pair.players[1].hand.size() == CardBattle.HAND_SIZE, "each draws a hand")
	ok(pair.players[0].hand.all(func(card): return card.key == "guard") and pair.players[1].hand.all(func(card): return card.key == "thrust"),
		"from their own deck")
	ok(pair.active == 0 and pair.energy == CardBattle.ENERGY and int(pair.players[1].energy) == CardBattle.ENERGY, "each with their own energy")
	pair.set_ready(0, true)
	ok(pair.turn == 1 and pair.players[0].ready, "one Ready: the turn goes on")
	pair.active = 0
	pair.play(0)
	ok(not pair.players[0].ready, "playing a card takes the Ready back")
	pair.set_ready(0, true)
	pair.set_ready(1, true)
	ok(pair.turn == 2, "both Ready: the enemies act, and the next turn", "turn %d" % pair.turn)
	ok(int(pair.players[0].hp) == 59 and int(pair.players[1].hp) == 44, "the enemy hit them both, each blocking for themselves",
		"%d, %d" % [pair.players[0].hp, pair.players[1].hp])
	pair.active = 0
	pair.hand.append({"key": "shared_shield", "upgraded": false, "id": 990})
	pair.energy = 3
	pair.play(pair.hand.size() - 1)
	ok(int(pair.players[1].block) == 7 and int(pair.players[0].block) == 0, "Shared Shield: the Block is the partner's", "%d" % pair.players[1].block)
	pair.players[1].hp = 1
	pair._lose(pair.players[1], 5)
	ok(pair.players[1].down and not pair.over and pair.standing().size() == 1, "one at nothing is down for the fight; it goes on")
	pair.set_ready(0, true)
	ok(pair.turn == 3, "the one standing's Ready is enough", "turn %d" % pair.turn)
	pair.players[0].hp = 1
	pair._lose(pair.players[0], 9)
	ok(pair._check_end() and not pair.won, "both down: the fight is lost")
	# A run for two: votes, a fight for both, getting up after it, rewards each.
	var duo := CardRun.new(88, ["world", "hermes"])
	ok(duo.together() and duo.players[0].name == "World" and duo.players[1].name == "Hermes", "a run for two")
	var first: Array = duo.choices()
	ok(duo.vote(0, first[0]) == -1 and duo.at < 0, "one vote: waiting for the other's")
	ok(duo.vote(1, first[0]) == first[0] and duo.at == first[0], "the same vote: they go there")
	var next: Array = duo.choices()
	if next.size() >= 2:
		duo.vote(0, next[0])
		var went := duo.vote(1, next[1])
		ok(went == next[0] or went == next[1], "two votes differing: one of the two", "%d of %s" % [went, next])
	var battle := duo.new_battle()
	ok(battle.together() and battle.players[1].name == "Hermes" and battle.players[1].character == "hermes", "its fights have both")
	battle.start()
	battle.players[1].hp = 0
	battle.players[1].down = true
	_killed_all(battle)
	duo.finish_battle()
	# Up with 1 health, then what their relics mend after a fight won (none of the gates' own does, since twist 15).
	var mend := 0
	for key in duo.players[1].relics:
		var relic := CardDatabase.relic(key)
		if relic != null and relic.when == CardRelicDefinition.When.FIGHT_WON and relic.effect != null and relic.effect.kind == CardEffect.Kind.HEAL:
			mend += relic.effect.amount
	ok(int(duo.players[1].hp) == 1 + mend, "won with one down: they get up with 1 health (and their relics' mending)", "%d" % duo.players[1].hp)
	ok(not duo.players[0].rewards.is_empty() and not duo.players[1].rewards.is_empty(), "rewards for each")
	duo.me = 1
	ok(duo.rewards == duo.players[1].rewards and duo.deck == duo.players[1].deck, "the calls are the player now's")
	duo.me = 0
	log_line("")


func the_layers_and_the_trace():
	log_line("======== layers, the trace, scanning ========")
	var deep := CardBattle.new(deck_of(GUARDS), [made("Dummy", R, [CardEnemyMove.of("Hit", 6)], {}, 40)], 60, 60, [], 4242)
	deep.set_layer(3, true)
	ok(deep.enemies[0].max_hp == 60 and int(deep.enemies[0].statuses.get(&"might", 0)) == 2, "the third layer: half again the health, 2 Might",
		"%d, %s" % [deep.enemies[0].max_hp, deep.enemies[0].statuses])
	var written := CardBattle.new(deck_of(GUARDS), [made("Dummy", R, [CardEnemyMove.of("Hit", 6)], {}, 40)], 60, 60, [], 4242)
	written.set_layer(3, false)
	ok(written.enemies[0].max_hp == 40 and not written.enemies[0].statuses.has(&"might"), "a fight written for its layer is played as written")
	var noticed := CardBattle.new(deck_of(GUARDS), [made("Dummy", R, [CardEnemyMove.of("Hit", 6)], {}, 40)], 60, 60, [], 4242)
	noticed.set_trace(50)
	ok(noticed.enemies[0].max_hp == 44 and int(noticed.enemies[0].statuses.get(&"might", 0)) == 2, "a trace of 50: a tenth more health, 2 Might",
		"%d, %s" % [noticed.enemies[0].max_hp, noticed.enemies[0].statuses])
	ok(CardDatabase.bosses_of(1) == ["boss_colossus"] and CardDatabase.bosses_of(2) == ["boss_devourer"] and CardDatabase.bosses_of(3) == ["boss_core"],
		"each layer its own boss")
	ok(CardDatabase.encounters_for(CardEncounterDefinition.Tier.HARD, 2).all(func(key): return CardDatabase.encounters()[key].layer in [0, 2]),
		"a layer's fights: its own and any layer's")
	var run := CardRun.new(99, ["world"])
	run.add_trace(74)
	ok(not run.glitched and run.deck.filter(_is_glitch).is_empty(), "below 75: no Glitch")
	run.add_trace(1)
	ok(run.glitched and run.deck.filter(_is_glitch).size() == 1, "at 75 a Glitch goes into the deck")
	run.add_trace(-10)
	run.add_trace(10)
	ok(run.deck.filter(_is_glitch).size() == 1, "once")
	run.add_trace(25)
	ok(run.traced and run.over and not run.won, "at 100 he is traced: the run is lost")
	var loud := fight(GUARDS, [made("Dummy", R, [CardEnemyMove.of("Hit", 1)], {}, 90)])
	loud.play(in_hand(loud, "crushing_blow"), 0)
	ok(loud.trace_gained == 2, "a loud card raises the trace", "%d" % loud.trace_gained)
	var dark := CardBattle.new(deck_of(GUARDS), [made("Dummy", R, [CardEnemyMove.of("Hit", 6)], {}, 40)], 60, 60, [], 4242)
	dark.set_darkness(1.0)
	var heard := []
	dark.beat.connect(func(what, info): heard.append([what, info]))
	dark.start()
	var hidden := dark.intent_of(dark.enemies[0])
	ok(hidden.hidden and hidden.encrypted and int(hidden.damage) == 0, "encrypted: what it will do is hidden")
	dark.play(in_hand(dark, "scan"), 0)
	var seen := dark.intent_of(dark.enemies[0])
	ok(not seen.hidden and int(seen.damage) == 6, "Scanned: it is seen", "%s" % [seen])
	ok(heard.any(func(beat): return beat[0] == &"intent" and not beat[1].intent.hidden), "and shown at once")
	ok(dark.hand.size() == CardBattle.HAND_SIZE + 1, "Scan draws a card in its place", "%d" % dark.hand.size())
	var core := fight(GUARDS, ["core"])
	ok(core.intent_of(core.enemies[0]).hidden, "the Core shows nothing until Scanned")
	log_line("")


func half_read_and_the_devourer():
	log_line("======== half-read code, and the Devourer ========")
	_forget_unlocks()
	var swing := CardDatabase.card("heavy_swing")
	ok(swing.half_read() and swing.describe(false, null, -1, false, "heavy_swing").contains(CardDefinition.STRUCK), "Heavy Swing is half-read: its last line struck out")
	ok(not swing.describe(false).contains(CardDefinition.STRUCK), "all of it said where no card is meant (the editor, a glossary)")
	var played := fight(GUARDS, [made("Dummy", R, [CardEnemyMove.of("Hit", 1)], {}, 90)])
	var heard := []
	played.beat.connect(func(what, info): heard.append([what, info]))
	played.play(in_hand(played, "heavy_swing"), 0)
	ok(CardUnlocks.read("heavy_swing") and heard.any(func(beat): return beat[0] == &"read"), "played once: read, for good")
	ok(not swing.describe(false, null, -1, false, "heavy_swing").contains(CardDefinition.STRUCK), "and its words shown")
	ok(int(played.enemies[0].statuses.get(&"exposed", 0)) > 0, "what was struck out did its work all the same")
	_forget_unlocks()
	var reader := CardRun.new(5, ["world"])
	ok(reader.read_all() >= 1 and CardUnlocks.read("heavy_swing"), "Notes on the Wall: every half-read card of the deck read")
	_forget_unlocks()
	var dev := fight(GUARDS, ["devourer"])
	ok(dev.enemies[0].move.name == "Devour", "the Devourer opens by devouring")
	dev.end_turn()
	ok(dev.enemies[0].held.size() == 2 and int(dev.enemies[0].statuses.get(&"holding", 0)) == 2, "it ate two cards", "%d" % dev.enemies[0].held.size())
	dev.enemies[0].move = dev.enemies[0].definition.move_named("Gnash")
	ok(int(dev.intent_of(dev.enemies[0]).damage) == 13, "Gnash: 3 more for every card it holds", "%d" % int(dev.intent_of(dev.enemies[0]).damage))
	var hand_before := dev.hand.size()
	dev._lose(dev.enemies[0], int(ceil(dev.enemies[0].max_hp * 0.26)))
	ok(dev.enemies[0].held.size() == 1 and dev.hand.size() == hand_before + 1, "a quarter of its health gone: one falls back out, into the hand")
	var choke := fight(GUARDS, ["devourer"])
	choke.draw_pile.clear()
	choke.discard_pile.clear()
	choke.draw_pile.append({"key": "slimed", "upgraded": false, "id": 777})
	choke.draw_pile.append({"key": "guard", "upgraded": false, "id": 778})
	choke.end_turn()
	ok(choke.enemies[0].held.is_empty() and choke.enemies[0].move.name == "Choking", "it ate a Status card: it chokes, and spits it all out",
		"%s" % choke.enemies[0].move.name)
	var hp_before: int = choke.player.hp
	choke.end_turn()
	ok(int(choke.player.hp) == hp_before, "and does nothing on its turn")
	log_line("")


func rests_lethe_and_oddities():
	log_line("======== rests, Lethe, the long rest, the oddities ========")
	_forget_unlocks()
	var run := CardRun.new(21, ["world", "hermes"], 3)
	ok(run.layers == 3 and run.layer == 1, "a run of three layers")
	ok(not run.rest_options().has(CardRun.Rest.COVER_TRACKS), "nothing to cover without a trace")
	run.add_trace(20)
	ok(run.rest_with(CardRun.Rest.COVER_TRACKS) and run.trace == 5, "Cover Tracks: the trace 15 lower", "%d" % run.trace)
	run.players[1].hp = 20
	ok(run.rest_options().has(CardRun.Rest.MEND) and run.rest_with(CardRun.Rest.MEND) and int(run.players[1].hp) == 38,
		"Mend: the partner mends a third of their most", "%d" % run.players[1].hp)
	var size := run.deck.size()
	run.remove_card(0)
	ok(run.deck.size() == size - 1 and run.players[0].forgotten.size() == 1, "a card taken out is forgotten")
	run.at = run.rooms.keys().filter(func(id): return run.rooms[id].room == CardRun.Room.BOSS)[0]
	var boss := run.new_battle()
	boss.start()
	_killed_all(boss)
	run.finish_battle()
	ok(run.long_rest_due and run.choices().is_empty() and not run.over, "a layer's boss beaten: the long rest before anything else")
	ok(str(run.players[0].rewards.get("relic", "")) != "" and run.boss_fragment != "", "a boss's rewards, a relic among them, and a code fragment")
	run.players[0].hp = 10
	run.long_rest()
	ok(int(run.players[0].hp) == int(run.players[0].max_hp), "the long rest mends fully")
	run.next_layer()
	ok(run.layer == 2 and not run.long_rest_due and not run.choices().is_empty() and run.players[0].forgotten.size() == 1, "the second layer: a new map")
	run.next_layer()
	var back: Array = run.players[0].lethe_back
	ok(run.layer == 3 and back.size() == 1 and bool(back[0].upgraded) and run.players[0].forgotten.is_empty(),
		"the last layer: what was forgotten comes back, upgraded")
	var events := ["looping_corridor", "shifting_room", "talking_thing", "notes_on_the_wall", "memento", "stash"]
	ok(events.all(func(key): return CardDatabase.events().has(key)), "the six oddities")
	_forget_unlocks()
	var odd := CardRun.new(31, ["world"])
	var memento: CardEventDefinition = CardDatabase.events()["memento"]
	odd.choose(memento.options[0])
	ok(odd.trace == 10 and odd.fragments_found.size() == 1 and odd.fragments_found[0].character == "hermes",
		"a Memento: a fragment of the nearest gate's code, for some trace", "%s" % [odd.fragments_found])
	var talk: CardEventDefinition = CardDatabase.events()["talking_thing"]
	var gold := odd.gold
	odd.choose(talk.options[1])
	ok(odd.gold == gold + 75 and odd.deck.any(_is_glitch), "the Talking Thing: gold, and a Glitch in the deck")
	var was: String = odd.deck[0].key
	var now := odd.transform_card(0)
	ok(now != "" and now != was and odd.deck[0].key == now, "the Shifting Room rewrites a card", "%s -> %s" % [was, now])
	_forget_unlocks()
	log_line("")


func the_screen_for_two():
	log_line("======== the screen: two players, one hand at a time, and the gates ========")
	_forget_unlocks()
	# One hand at a time, and the rooms in turn (both are choices on the character choice; the_screen_together has them on).
	CardGame.both_hands = false
	CardGame.rooms_together = false
	CardGame.characters_for_next = ["world", "hermes"]
	CardGame.seed_for_next = 4321
	get_tree().change_scene_to_file(CardGame.SCENE)
	for i in 6:
		await get_tree().process_frame
	var game = get_tree().current_scene
	if not game is CardGame:
		ok(false, "the card game opens for two", "%s" % [game])
		return
	ok(game.view == "map" and game.run.together() and game.run.layers == CardRun.MOST_LAYERS, "two players, three layers, on the map")
	var first: int = game.run.choices()[0]
	game.choose_room(first)
	await get_tree().process_frame
	ok(game.view == "map" and game.run.votes.size() == 1 and game.run.at < 0, "one vote: the other's to make")
	game.choose_room(first)
	await get_tree().process_frame
	ok(game.view == "battle" and game.stage != null and game.stage.player_views.size() == 2, "both voted: a fight, both in it")
	if game.view != "battle" or game.stage == null:
		return
	var stage: CardStage = game.stage
	var battle: CardBattle = game.battle
	ok(stage.shown == 0 and stage.swap_button.visible, "the first player's hand, and a button for the other's")
	stage.swap_hands()
	ok(stage.shown == 1 and battle.active == 1 and stage.hand.views.size() == battle.players[1].hand.size(), "swapped: the other's hand, theirs to play")
	stage.end_turn()
	ok(battle.players[1].ready and stage.shown == 0 and battle.turn == 1, "Ready: and the other's hand comes up")
	stage.end_turn()
	ok(battle.turn == 2, "both Ready: the enemies' turn, then the next", "%d" % battle.turn)
	_killed_all(battle)
	await get_tree().create_timer(CardGame.FIGHT_OVER_SECONDS + 0.3).timeout
	ok(game.view == "rewards" and game.run.me == 0, "won: the first player's rewards", game.view)
	game._leave_rewards()
	await get_tree().process_frame
	ok(game.view == "rewards" and game.run.me == 1, "then the second's")
	game._leave_rewards()
	await get_tree().process_frame
	ok(game.view == "map" and game.run.me == 0, "then the map")
	CardGame.practice = false
	get_tree().change_scene_to_file(CardGame.SCENE)
	for i in 6:
		await get_tree().process_frame
	game = get_tree().current_scene
	ok(game is CardGame and game.view == "characters", "with nothing said: the gates to choose from")
	if not game is CardGame:
		return
	var world: Button = game.find_child("Character_world", true, false)
	var hermes: Button = game.find_child("Character_hermes", true, false)
	ok(world != null and not world.disabled and hermes != null and hermes.disabled, "World can be chosen; Hermes is locked")
	game._character_chosen("world")
	ok(game.view == "blessings" and game.run.character() == "world" and game.run.layers == CardRun.MOST_LAYERS,
		"chosen: a whole run as World, its Blessing first (twist 15)", game.view)
	var offered: Array = game.run.players[0].blessing_offers
	ok(offered.size() == mini(3, CardDatabase.relics().values().filter(func(relic): return relic.rarity == CardRelicDefinition.Rarity.BLESSING).size())
		and offered.all(func(key): return CardDatabase.relic(key).rarity == CardRelicDefinition.Rarity.BLESSING), "up to three Blessings offered", "%s" % [offered])
	if not offered.is_empty():
		game._bless(offered[0])
	await get_tree().process_frame
	ok(game.view == "map" and (offered.is_empty() or game.run.relics.has(offered[0])), "one taken: it is a relic of the run's, and the map", game.view)
	CardGame.both_hands = true
	CardGame.rooms_together = true
	log_line("")


## --- The designer's "try them all" (2026-11-27): Tethers, the Message, the gates' relics and the Blessings, two on one screen ---


## Card `key` of the fight's deck put into the hand (from wherever it is), with the energy to play it; its index, or -1.
func _to_hand(battle: CardBattle, key: String) -> int:
	battle.energy = 9
	var at := index_of(battle, key)
	if at >= 0:
		return at
	for pile in [battle.draw_pile, battle.discard_pile]:
		for card in pile:
			if card.key == key:
				pile.erase(card)
				battle.hand.append(card)
				return battle.hand.size() - 1
	return -1


func _waiting() -> CardEnemyDefinition:
	return made("Dummy", R, [CardEnemyMove.of("Wait")], {}, 60)


func tethers():
	log_line("======== Tethers (twist 7) ========")
	var leash := CardDatabase.card("leash")
	ok(leash != null and leash.type == CardDefinition.Type.TETHER and leash.strength_for(false) == 3 and leash.offered(), "Leash: a Tether, strength 3, to be won")
	var battle := fight(GUARDS, [_waiting()])
	var at := in_hand(battle, "leash")
	ok(battle.needs_target(at), "it is played onto an enemy")
	battle.play(at, 0)
	ok(battle.tethers.size() == 1 and int(battle.tethers[0].on) == 0 and int(battle.tethers[0].holder) == -1, "played: it holds that enemy, the player's")
	ok(not battle.discard_pile.any(func(card): return card.key == "leash") and not battle.hand.any(func(card): return card.key == "leash"),
		"on the table, in no pile")
	var heard := []
	battle.beat.connect(func(what, info): heard.append([what, info]))
	battle.end_turn()
	ok(heard.any(func(beat): return beat[0] == &"status" and int(beat[1].who) == 0 and beat[1].key == &"weakened" and int(beat[1].after) == 1),
		"its holder's turn over: it gives the enemy 1 Weakened")
	ok(battle.tethers.size() == 1 and int(battle.tethers[0].strength) == 2, "and frays by 1", "%d" % (battle.tethers[0].strength if not battle.tethers.is_empty() else -1))
	battle.end_turn()
	battle.end_turn()
	ok(battle.tethers.is_empty() and battle.enemies[0].hp == 54, "frayed through: it snaps, its snap dealing 6", "%d" % battle.enemies[0].hp)
	ok(heard.any(func(beat): return beat[0] == &"snapped" and beat[1].why == &"frayed"), "and says so")
	ok((battle.discard_pile + battle.draw_pile + battle.hand).any(func(card): return card.key == "leash"), "back among its holder's cards")
	var again := fight(GUARDS, [_waiting()])
	again.play(in_hand(again, "leash"), 0)
	again.end_turn()
	again.play(in_hand(again, "leash"), 0)
	ok(again.tethers.size() == 1 and int(again.tethers[0].strength) == 3, "the same card onto the same: renewed, at full strength")
	var full := fight(GUARDS, [_waiting(), _waiting()])
	full.play(in_hand(full, "leash"), 0)
	full.play(in_hand(full, "siphon"), 0)
	var third := in_hand(full, "leash")
	ok(full.refusal(third, 1) == "Your Tethers are all held: let one go first.", "two held: a third refused", full.refusal(third, 1))
	ok(full.refusal(third, 0) == "", "but renewing one is not")
	full.players[0].relics.append("spool")
	ok(full.refusal(third, 1) == "", "with the Spool, a third")
	var go := fight(GUARDS, [_waiting()])
	go.play(in_hand(go, "leash"), 0)
	ok(go.let_go(0, int(go.tethers[0].id)) and go.tethers.is_empty() and go.enemies[0].hp == 54, "let go early: it snaps now, dealing its 6")
	var drain := fight(GUARDS, [_waiting()], 40)
	drain.play(in_hand(drain, "siphon"), 0)
	drain.end_turn()
	ok(drain.enemies[0].hp == 58 and drain.players[0].hp == 42, "Siphon: drains 2 from the enemy into its holder", "%d, %d" % [drain.enemies[0].hp, drain.players[0].hp])
	var link := fight(THRUSTS, [made("Hitter", R, [CardEnemyMove.of("Hit", 5)], {}, 60)])
	link.play(in_hand(link, "guard_link"), -1)
	ok(link.tethers.size() == 1 and int(link.tethers[0].on) == -1, "Guard Link alone: on yourself")
	link.end_turn()
	ok(link.players[0].hp == 59, "its 4 Block at the end of your turn: 1 of a 5 through", "%d" % link.players[0].hp)
	var frail := made("Frail", R, [CardEnemyMove.of("Wait")], {}, 5)
	var loose := fight(GUARDS, [frail, _waiting()])
	loose.play(in_hand(loose, "leash"), 0)
	loose._lose(loose.enemies[0], 10)
	ok(loose.tethers.is_empty() and loose.enemies[1].hp == 60, "whoever it held fallen: it goes loose, snapping nothing")
	var leech := CardDatabase.enemy("leech")
	ok(leech != null and leech.moves.any(func(move): return move.ties == "leech_line"), "the Leech ties a Leech Line")
	var tied := fight(GUARDS, ["leech"])
	var before: int = tied.players[0].hp
	tied.end_turn()
	ok(tied.tethers.size() == 1 and int(tied.tethers[0].on) == -1 and int(tied.tethers[0].holder) == 0, "Latch: its Tether on the player")
	ok(tied.players[0].hp == before - 2, "draining 2 at the end of its turn, Block or not", "%d" % tied.players[0].hp)
	if not tied.tethers.is_empty():
		var strength: int = tied.tethers[0].strength
		tied._lose(tied.enemies[0], CardDefinition.TETHER_BREAK_DAMAGE)
		ok(tied.tethers.is_empty() or int(tied.tethers[0].strength) == strength - 1, "every %d health off its holder cuts a strand" % CardDefinition.TETHER_BREAK_DAMAGE)
	var severer := CardDatabase.enemy("severer")
	var sever: Array = severer.moves.filter(func(move): return move.cuts_tethers > 0) if severer != null else []
	if not sever.is_empty():
		var cut := fight(GUARDS, [made("Cutter", C, [sever[0]], {}, 60)])
		cut.play(in_hand(cut, "leash"), 0)
		cut.end_turn()
		ok(cut.tethers.is_empty() and cut.enemies[0].hp == 60, "Sever: the strongest of yours cut, with no snap")
		ok(cut.intent_of(cut.enemies[0]).get("cuts", 0) == 1 and CardStage.intent_words(cut.intent_of(cut.enemies[0])).contains("cut 1 of your Tethers"),
			"and its intent says it will", CardStage.intent_words(cut.intent_of(cut.enemies[0])))
	else:
		ok(false, "the Severer cuts Tethers")
	log_line("")


func the_message():
	log_line("======== the Message (twist 10) ========")
	var run := CardRun.new(515, ["world"])
	var message := run.message_of(0)
	ok(not message.is_empty() and message.words.is_empty() and run.deck.any(func(card): return card.key == CardDefinition.MESSAGE), "every deck has the Message, nearly empty")
	var at := -1
	for i in run.deck.size():
		if run.deck[i].key == CardDefinition.MESSAGE:
			at = i
	ok(at >= 0 and not run.removable().has(at) and not run.remove_card(at) and run.transform_card(at) == "", "never taken out or rewritten")
	var offers := run.message_offers()
	ok(offers.size() == 3 and offers.all(func(offer): return offer.kind in ["word", "lighten"]), "an event's offers: three ways to grow (new words, or spoken lighter, at first)", "%s" % [offers])
	var word_at := -1
	for i in offers.size():
		if offers[i].kind == "word":
			word_at = i
			break
	var chosen: String = offers[word_at].word if word_at >= 0 else ""
	ok(word_at >= 0 and run.grow_message(word_at) and message.words.size() == 1 and message.words[0].key == chosen, "one chosen: a word of it now", chosen)
	if not message.words.is_empty():
		run.players[0].message_offers = [{"kind": "deepen", "word": chosen}]
		var was := int(message.words[0].amount)
		run.grow_message(0)
		ok(int(message.words[0].amount) == was + CardDatabase.message_word(chosen).step, "deepened: its number grows by its step")
	run.players[0].message_offers = [{"kind": "lighten"}]
	run.grow_message(0)
	ok(int(message.cost) == 0 and bool(message.lightened), "spoken lighter: it costs nothing now")
	var walls := CardDatabase.message_word("walls")
	if walls != null:
		var entry := {"key": CardDefinition.MESSAGE, "upgraded": false, "message": {"words": [{"key": "walls", "amount": 4, "effect": walls.effect,
			"line": walls.line}], "cost": 1, "lightened": false}}
		for spoken in [false, true]:
			var said := CardBattle.new([entry] + deck_of(GUARDS), [_waiting(), _waiting()], 60, 60, [], 4242)
			said.truth_spoken = spoken
			said.start()
			said.play(_to_hand(said, CardDefinition.MESSAGE), -1)
			var left := 52 if spoken else 56
			ok(said.enemies[0].hp == left and said.enemies[1].hp == left, ("at the run's last boss, every word twice" if spoken else
				"played: its words do what they say (4 to every enemy)"), "%d" % said.enemies[0].hp)
	else:
		ok(false, "the word \"Its walls are only code\"")
	var listening := run.event_options(CardDatabase.events().keys()[0])
	ok(listening.any(func(option): return option.action == CardEventOption.Action.MESSAGE), "an event: listening for a word, beside its own options")
	ok(CardDatabase.events().has("voice_in_the_wires"), "and an event of its own for it")
	var last := CardRun.new(99, ["world"], 1)
	var boss: Array = CardDatabase.bosses_of(1)
	ok(not boss.is_empty() and last.battle_of(boss[0], CardEncounterDefinition.Tier.BOSS).truth_spoken, "the run's last boss: the truth spoken")
	var two := CardRun.new(99, ["world"], 3)
	ok(not two.battle_of(boss[0], CardEncounterDefinition.Tier.BOSS).truth_spoken, "a boss before the last layer's: not yet")
	log_line("")


func relics_and_blessings():
	log_line("======== relics: each gate's own, the Blessings, the party's (twist 15) ========")
	var own := {}
	for key in CardDatabase.characters_in_order():
		own[key] = CardDatabase.character(key).starting_relic
	var unique := {}
	for relic in own.values():
		unique[relic] = true
	ok(own.values().all(func(relic): return relic != "field_dressing" and CardDatabase.relic(relic) != null and CardDatabase.relic(relic).rarity == CardRelicDefinition.Rarity.STARTER)
		and unique.size() == own.size(), "every gate starts with a relic of its own", "%s" % [own])
	var blessings: Array = CardDatabase.relics().keys().filter(func(key): return CardDatabase.relic(key).rarity == CardRelicDefinition.Rarity.BLESSING)
	ok(blessings.size() >= 3, "Blessings: Iron, the Patient and the Swift", "%s" % [blessings])
	var run := CardRun.new(31, ["world"])
	var drawn := {}
	for i in 40:
		drawn[run.random_relic()] = true
	ok(not drawn.keys().any(func(key): return blessings.has(key) or (key != "" and CardDatabase.relic(key).rarity == CardRelicDefinition.Rarity.STARTER)),
		"none of them, nor a gate's own, in a chest")
	ok(run.shop_here().relics.all(func(item): return CardDatabase.relic(item.key).offered()), "or a shop")
	var offered: Array = run.players[0].blessing_offers
	ok(offered.size() == mini(3, blessings.size()) and run.blessings_due(), "a run's first choice: up to three", "%s" % [offered])
	ok(run.choose_blessing(offered[0]) and run.relics.has(offered[0]) and not run.blessings_due(), "one chosen: the run's")
	ok(not run.choose_blessing(blessings[0]), "and no second")
	for key in ["night_hunter", "mercy", "breaker", "meditate"]:
		var relic := CardDatabase.relic(key)
		ok(relic != null and relic.rarity == CardRelicDefinition.Rarity.RARE and relic.offered() and relic.learned_from != "",
			"the party's %s: a rare relic, for every gate" % (relic.name if relic != null else key))
	var hunt := CardBattle.new(deck_of(GUARDS), [made("Frail", R, [CardEnemyMove.of("Wait")], {}, 5), _waiting()], 60, 60, ["night_hunter"], 4242)
	hunt.start()
	var energy: int = hunt.energy
	hunt._lose(hunt.enemies[0], 99)
	ok(hunt.energy == energy + 1, "Night Hunter: an enemy falls, 1 energy", "%d" % hunt.energy)
	var world := CardBattle.new(deck_of(GUARDS), [_waiting()], 60, 60, ["gate_iron_hide"], 4242)
	world.start()
	ok(world.players[0].block == 6, "World's Iron Hide: 6 Block as the fight starts, kept through its first turn", "%d" % world.players[0].block)
	log_line("")


func the_screen_together():
	log_line("======== the screen: two players, both hands at once, rooms together ========")
	_forget_unlocks()
	CardGame.both_hands = true
	CardGame.rooms_together = true
	CardGame.characters_for_next = ["world", "hermes"]
	CardGame.seed_for_next = 9876
	get_tree().change_scene_to_file(CardGame.SCENE)
	for i in 6:
		await get_tree().process_frame
	var game = get_tree().current_scene
	if not game is CardGame:
		ok(false, "the card game opens for two")
		return
	var first: int = game.run.choices()[0]
	game.choose_room(first)
	game.choose_room(first)
	await get_tree().process_frame
	ok(game.view == "battle" and game.stage != null, "both voted: a fight")
	if game.stage == null:
		return
	var stage: CardStage = game.stage
	var battle: CardBattle = game.battle
	ok(stage.both_hands and stage.seats.size() == 2 and not stage.swap_button.visible, "both hands at once: a seat each, no Swap")
	ok(stage.seats[0].hand.views.size() == battle.players[0].hand.size() and stage.seats[1].hand.views.size() == battle.players[1].hand.size(),
		"each seat holds its own player's hand")
	# The second's card, pressed on their seat: played from their hand.
	var guard_id := -1
	for card in battle.players[1].hand:
		if card.key == "guard":
			guard_id = int(card.id)
	if guard_id >= 0:
		stage._card_clicked(guard_id, 1)
		stage._card_clicked(guard_id, 1)
		ok(not battle.players[1].hand.any(func(card): return int(card.id) == guard_id) and int(battle.players[1].block) > 0,
			"pressed twice on their seat: the second's Guard, played", "%d" % battle.players[1].block)
	stage._end_pressed(0)
	ok(battle.players[0].ready and battle.turn == 1, "the first's Ready, on their seat")
	stage._end_pressed(1)
	ok(battle.turn == 2, "and the second's: the enemies' turn, and the next", "%d" % battle.turn)
	# Each on their own device: a pad's press is its player's.
	game.devices = [[Coop.KEYBOARD], [7]]
	var press := InputEventJoypadButton.new()
	press.device = 7
	press.button_index = JOY_BUTTON_A
	press.pressed = true
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	var stray := InputEventJoypadButton.new()
	stray.device = 5
	stray.pressed = true
	ok(game.player_of_event(press) == 1 and game.player_of_event(key) == 0 and game.player_of_event(stray) == CardGame.NOBODY_HERE,
		"each device its player's; one nobody plays with, nobody's")
	_killed_all(battle)
	await get_tree().create_timer(CardGame.FIGHT_OVER_SECONDS + 0.3).timeout
	ok(game.view == "rewards" and game._halves.size() == 2, "won: the rewards for both at once, a half each", game.view)
	if game._halves.size() == 2:
		ok(game._halves[0].find_children("*", "CardView", true, false).size() == game.run.players[0].rewards.get("cards", []).size()
			and game._halves[1].find_children("*", "CardView", true, false).size() == game.run.players[1].rewards.get("cards", []).size(),
			"each half its own player's cards")
		var deck_was: int = game.run.players[1].deck.size()
		var taking: String = game.run.players[1].rewards.cards[0]
		game._in_half(1, game._take_and_leave.bind(taking))
		await get_tree().process_frame
		ok(game.run.players[1].deck.size() == deck_was + 1 and game.view == "rewards" and bool(game._halves_done[1]),
			"the second takes one: theirs, and their half waits for the other")
		game._in_half(0, game._leave_rewards)
		await get_tree().process_frame
		ok(game.view == "map" and game._halves.is_empty(), "the first skips: both done, the map")
	game.devices = []
	log_line("")


func _run_hack(hack: HackDefinition, id: String, into: Dictionary):
	var outcome: Dictionary = await Hacking.run(hack, id)
	into.merge(outcome)


func the_hack():
	log_line("======== the card game as Prometheus's hacking ========")
	_forget_unlocks()
	Campaign.set_party(["prometheus"], 10)
	var hack := HackDefinition.new()
	hack.title = "A Test Lock"
	hack.fragment_of = "hermes"
	ok(hack.minigame == HackDefinition.Minigame.CARDS, "a hack is the card game unless it asks for its board")
	var outcome := {}
	_run_hack(hack, "card_test_lock", outcome)
	await until(func(): return Hacking.card_game != null, 3.0)
	var game: CardGame = Hacking.card_game
	ok(game != null and game.hacking != null and game.get_parent() is CanvasLayer, "it opens over the world, on a layer of its own")
	if game == null:
		return
	ok(game.view == "characters", "who hacks is chosen first")
	game._character_chosen("world")
	ok(game.view == "battle" and game.battle != null, "a hack of one fight: straight into it", game.view)
	var share: float = Hacking.health_share_for(Hacking.intellect_of_member("prometheus"))
	ok(int(game.run.players[0].max_hp) == int(round(60 * share)), "the deck's health by Prometheus's Intellect", "%d (x%.2f)" % [game.run.players[0].max_hp, share])
	if game.battle != null:
		_killed_all(game.battle)
	await until(func(): return game.view == "end", 4.0)
	ok(game.view == "end" and game.run.won, "won: through", game.view)
	game.leave_game()
	await until(func(): return not Hacking.running(), 3.0)
	ok(outcome.get("result", "") == "success" and Hacking.succeeded("card_test_lock"), "Hacking says so, and leaves its flag", "%s" % [outcome])
	ok(CardUnlocks.fragments("hermes") == 1, "and a fragment of Hermes's code is found")
	var left := {}
	_run_hack(HackDefinition.new(), "", left)
	await until(func(): return Hacking.card_game != null, 3.0)
	if Hacking.card_game != null:
		Hacking.card_game.leave_game()
	await until(func(): return not Hacking.running(), 3.0)
	ok(left.get("result", "") == "walked_away", "left before the end: walked away", "%s" % [left])
	ok(not get_tree().paused, "and the world goes on")
	# Two players on this screen (the main game's co-op): both play the hack, each on their own device (the designer, 2026-11-27).
	Coop.reset()
	Coop.join(Coop.KEYBOARD)
	Coop.join(0)
	var both := {}
	_run_hack(HackDefinition.new(), "", both)
	await until(func(): return Hacking.card_game != null, 3.0)
	var pair: CardGame = Hacking.card_game
	ok(pair != null and pair.hacking.players == 2 and pair.view == "characters", "two players on this screen: both play the hack, each choosing a gate")
	if pair != null:
		pair._character_chosen("world")
		pair._character_chosen("world")
		ok(pair.view == "battle" and pair.battle != null and pair.battle.together(), "  both chosen: one fight for the two", pair.view)
		ok(pair.devices.size() == 2 and pair.devices[0] == [Coop.KEYBOARD] and pair.devices[1] == [0], "  each on their own device, as in the game",
			"%s" % [pair.devices])
		ok(pair.stage != null and pair.stage.both_hands, "  both hands at once")
		pair.leave_game()
	await until(func(): return not Hacking.running(), 3.0)
	Coop.reset()
	Campaign.flags.erase("hacked:card_test_lock")
	_forget_unlocks()
	log_line("")
