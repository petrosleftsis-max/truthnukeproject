extends SceneTree
## Writes the card game's enemy content of 2026-11-27 (docs/proposals_2026-11-27_card_ai.md; the designer: "Do them all, don't do
## any twists yet"): the Status cards enemies give (Wound, Dazed, Slimed, Burn), the Second Sight relic, nine new enemies and eight
## fights that show what enemies can do now, and the ten enemies there were given rules, limits, traits and phases. Every name and
## number is a placeholder, the designer's to change in the editor afterwards. Run from a project whose classes are imported:
##     godot --headless --path . --import
##     godot --headless --path . --script res://tools/build_card_ai_content.gd
## A new file is written only where there is none. The ten enemies there were are changed where they stand: what else they hold
## (a number changed in the editor since) stays, and what this adds is added once, so running it again changes nothing.

const CARDS := "res://data/cards/"
const ENEMIES := "res://data/card_enemies/"
const ENCOUNTERS := "res://data/card_encounters/"
const RELICS := "res://data/card_relics/"
const W := CardEnemyRule.When
const T := CardEncounterDefinition.Tier
const CYCLE := CardEnemyDefinition.Pattern.CYCLE
const RANDOM := CardEnemyDefinition.Pattern.RANDOM

var written := 0
var changed_files := 0
var kept := 0


func _init():
	_status_cards()
	_relics()
	_new_enemies()
	_encounters()
	_the_ten()
	print("card AI content: %d written, %d changed, %d already there" % [written, changed_files, kept])
	quit()


func _save_new(resource: Resource, path: String):
	if ResourceLoader.exists(path):
		kept += 1
		return
	var error := ResourceSaver.save(resource, path)
	if error != OK:
		push_error("could not write %s (%d)" % [path, error])
		return
	written += 1


## A move: name, damage, hits, block, a status on the player and how much, one taken and how much, weight.
func _move(move_name: String, hit: int = 0, times: int = 1, guard: int = 0, gives: StringName = &"", gives_amount: int = 0,
		takes: StringName = &"", takes_amount: int = 0, weight: int = 1) -> CardEnemyMove:
	return CardEnemyMove.of(move_name, hit, times, guard, gives, gives_amount, takes, takes_amount, weight)


func _enemy(enemy_name: String, least: int, most: int, pattern: CardEnemyDefinition.Pattern, moves: Array, statuses: Dictionary,
		borrow: String) -> CardEnemyDefinition:
	var enemy := CardEnemyDefinition.new()
	enemy.name = enemy_name
	enemy.max_hp_least = least
	enemy.max_hp_most = most
	enemy.pattern = pattern
	for move in moves:
		enemy.moves.append(move)
	enemy.starting_statuses = statuses
	enemy.borrow_picture_from = borrow
	return enemy


## --- What enemies put in the player's piles ---


func _status_cards():
	_status_card("wound", "Wound", 0, true, false, 0, false, "A cut that slows the hand.")
	_status_card("dazed", "Dazed", 0, true, true, 0, false, "Ringing ears.")
	_status_card("slimed", "Slimed", 1, false, false, 0, true, "Sticky, and in the way.")
	_status_card("burn", "Burn", 0, true, false, 2, false, "It is still burning.")


func _status_card(key: String, card_name: String, cost: int, unplayable: bool, ethereal: bool, burns: int, exhausts: bool, flavour: String):
	var card := CardDefinition.new()
	card.name = card_name
	card.type = CardDefinition.Type.STATUS
	card.rarity = CardDefinition.Rarity.STARTER
	card.cost = cost
	card.target = CardDefinition.Target.NONE
	card.unplayable = unplayable
	card.ethereal = ethereal
	card.burns = burns
	card.exhausts = exhausts
	card.flavour = flavour
	_save_new(card, CARDS + key + ".tres")


func _relics():
	var sight := CardRelicDefinition.new()
	sight.name = "Second Sight"
	sight.rarity = CardRelicDefinition.Rarity.UNCOMMON
	sight.when = CardRelicDefinition.When.FIGHT_START
	sight.shows_next_moves = true
	sight.flavour = "You see the blow after the blow."
	_save_new(sight, RELICS + "second_sight.tres")


## --- Nine new enemies, each showing something enemies can do now ---


func _new_enemies():
	# Splits at half health (item 17), and its ichor Slimes your deck (14).
	var ichor := _move("Sticky Ichor", 0, 1, 6, &"", 0, &"", 0, 2)
	ichor.adds_card = "slimed"
	ichor.adds_count = 2
	var mimic := _enemy("Mimic", 46, 50, RANDOM, [_move("Chomp", 8, 1, 0, &"", 0, &"", 0, 2), ichor, _move("Gnash", 5, 2, 0, &"", 0, &"", 0, 2)], {}, "mimic")
	var burst := CardEnemyPhase.new()
	burst.health_under = 50
	burst.line = "The Mimic bursts apart!"
	burst.splits_into = ["imp", "imp"]
	mimic.phases.append(burst)
	_save_new(mimic, ENEMIES + "mimic.tres")
	_save_new(_enemy("Imp", 12, 15, RANDOM, [_move("Scratch", 5, 1, 0, &"", 0, &"", 0, 3), _move("Jeer", 2, 1, 0, &"weakened", 1, &"", 0, 2)], {}, "imp"),
		ENEMIES + "imp.tres")
	# Commands its side (16), calls for help when alone, first of all, and shields everybody (16, 17, 1, 5).
	var call := _move("Call")
	call.summons = ["imp"]
	call.cooldown = 2
	call.rule_only = true
	call.first = true
	var bulwark := _move("Bulwark", 0, 1, 6)
	bulwark.helps = CardEnemyMove.Helps.EVERY_ALLY
	var summoner := _enemy("Summoner", 36, 40, RANDOM, [call, _move("Bolt", 10, 1, 0, &"", 0, &"", 0, 2), bulwark], {"command": 2}, "summoner")
	summoner.rules.append(CardEnemyRule.of(W.ALONE, "Call"))
	summoner.rules.append(CardEnemyRule.of(W.ALLY_HURT, "Bulwark", 40, &"", T.HARD))
	_save_new(summoner, ENEMIES + "summoner.tres")
	# Linked: they rise again unless all are down (18); they shield the worst hurt (16).
	var shroud := _move("Shroud", 0, 1, 7, &"", 0, &"", 0, 2)
	shroud.helps = CardEnemyMove.Helps.WORST_HURT_ALLY
	var dread := _move("Dread", 4, 1, 0, &"weakened", 1, &"", 0, 2)
	dread.not_twice_running = true
	_save_new(_enemy("Phantom Soldier", 18, 22, RANDOM, [_move("Strike", 7, 1, 0, &"", 0, &"", 0, 3), shroud, dread], {"linked": 2}, "phantom_soldier"),
		ENEMIES + "phantom_soldier.tres")
	# The hand: Entangled, and a card taken until it falls (15).
	var snare := _move("Snare", 5, 1, 0, &"entangled", 1, &"", 0, 2)
	snare.not_twice_running = true
	var pickpocket := _move("Pickpocket", 4, 1, 0, &"", 0, &"", 0, 2)
	pickpocket.steals = 1
	pickpocket.most_times = 2
	_save_new(_enemy("Ranger", 26, 30, RANDOM, [snare, pickpocket, _move("Arrow", 9, 1, 0, &"", 0, &"", 0, 3)], {}, "ranger"), ENEMIES + "ranger.tres")
	# Its intent unseen until it is hit (20); Confused (15).
	var bewilder := _move("Bewilder", 0, 1, 5, &"confused", 2, &"", 0, 2)
	bewilder.not_twice_running = true
	var sorcerer := _enemy("Sorcerer", 30, 34, RANDOM, [bewilder, _move("Hex Bolt", 11, 1, 0, &"", 0, &"", 0, 3),
		_move("Siphon", 6, 1, 0, &"", 0, &"might", 1, 2)], {}, "sorcerer")
	sorcerer.shows = CardEnemyDefinition.Shows.ONCE_HIT
	_save_new(sorcerer, ENEMIES + "sorcerer.tres")
	# An elite with a Toll on every card played (10), and Dazed in the deck (14).
	var peal := _move("Peal", 6)
	peal.adds_card = "dazed"
	peal.adds_count = 2
	_save_new(_enemy("Bellkeeper", 70, 76, CYCLE, [peal, _move("Clang", 14), _move("Hush", 0, 1, 12, &"weakened", 1)], {"toll": 1}, "sorcerer"),
		ENEMIES + "bellkeeper.tres")
	# An elite with Overtime (10), a Burn in the hand (14), and a rule for a player low on health (5, 22).
	var embers := _move("Embers", 6, 1, 0, &"", 0, &"", 0, 2)
	embers.adds_card = "burn"
	embers.adds_to = CardEnemyMove.Pile.HAND
	var stoke := _move("Stoke", 0, 1, 8, &"", 0, &"might", 2, 1)
	stoke.not_twice_running = true
	var warden := _enemy("Ash Warden", 80, 86, RANDOM, [embers, _move("Searing Slam", 17, 1, 0, &"", 0, &"", 0, 2), stoke], {"overtime": 8}, "barbarian")
	warden.rules.append(CardEnemyRule.of(W.PLAYER_HEALTH_UNDER, "Searing Slam", 40, &"", T.ELITE))
	_save_new(warden, ENEMIES + "ash_warden.tres")
	# An elite that changes its mind whenever an attack hits it (11), and Wounds the deck (14).
	var maul := _move("Maul", 15, 1, 0, &"", 0, &"", 0, 2)
	maul.adds_card = "wound"
	maul.adds_to = CardEnemyMove.Pile.DRAW
	var howl := _move("Howl", 0, 1, 10, &"", 0, &"might", 2, 1)
	howl.not_twice_running = true
	_save_new(_enemy("Bound Beast", 90, 96, RANDOM, [_move("Thrash", 5, 3, 0, &"", 0, &"", 0, 2), maul, howl,
		_move("Rend", 9, 1, 0, &"exposed", 2, &"", 0, 2)], {"reactive": 1}, "bound_beast"), ENEMIES + "bound_beast.tres")


func _encounters():
	for fight in [["hard_mimic", T.HARD, ["mimic"]], ["hard_summoner", T.HARD, ["summoner", "imp"]],
			["hard_phantoms", T.HARD, ["phantom_soldier", "phantom_soldier", "phantom_soldier"]], ["hard_ranger", T.HARD, ["ranger", "hired_bow"]],
			["hard_sorcerer", T.HARD, ["sorcerer", "gnawer"]], ["elite_bellkeeper", T.ELITE, ["bellkeeper"]],
			["elite_ash_warden", T.ELITE, ["ash_warden"]], ["elite_bound_beast", T.ELITE, ["bound_beast"]]]:
		var encounter := CardEncounterDefinition.new()
		encounter.tier = fight[1]
		for key in fight[2]:
			encounter.enemies.append(key)
		_save_new(encounter, ENCOUNTERS + fight[0] + ".tres")


## --- The ten there were ---


func _the_ten():
	_change("rat", _rat)
	_change("gnawer", _gnawer)
	_change("hired_bow", _hired_bow)
	_change("sellsword", _sellsword)
	_change("alchemist", _alchemist)
	_change("bomber", _bomber)
	_change("priest", _priest)
	_change("ogre", _ogre)
	_change("golem", _golem)
	_change("colossus", _colossus)


## Rats run as a pack (16), and Gnaw when you are not Weakened already (6).
func _rat(enemy: CardEnemyDefinition):
	_status_once(enemy, "pack", 1)
	var gnaw := enemy.move_named("Gnaw")
	if gnaw != null:
		gnaw.lean_when = W.PLAYER_LACKS
		gnaw.lean_status = &"weakened"
		gnaw.lean_factor = 3.0


## The Gnawer opens with a hiss, and never hisses twice running (1, 2).
func _gnawer(enemy: CardEnemyDefinition):
	var hiss := enemy.move_named("Hiss")
	if hiss != null:
		hiss.first = true
		hiss.not_twice_running = true


## The Hired Bow takes aim first, and in a harder fight looses at a player low on health (1, 5, 22).
func _hired_bow(enemy: CardEnemyDefinition):
	var aim := enemy.move_named("Take Aim")
	if aim != null:
		aim.first = true
	_rule_once(enemy, CardEnemyRule.of(W.PLAYER_HEALTH_UNDER, "Loose", 25, &"", T.HARD))


## The Sellsword taunts a player behind a wall of Block, and never bashes twice running (5, 2).
func _sellsword(enemy: CardEnemyDefinition):
	var bash := enemy.move_named("Shield Bash")
	if bash != null:
		bash.not_twice_running = true
	_rule_once(enemy, CardEnemyRule.of(W.PLAYER_BLOCK_AT_LEAST, "Taunt", 10, &"", T.HARD))


## The Alchemist drinks once, when hurt; poisons a player not yet poisoned; and slimes the deck (5, 2, 6, 14).
func _alchemist(enemy: CardEnemyDefinition):
	var drink := enemy.move_named("Drink")
	if drink != null:
		drink.heal = 10
		drink.most_times = 1
		drink.rule_only = true
		_rule_once(enemy, CardEnemyRule.of(W.ITS_HEALTH_UNDER, "Drink", 50))
	var flask := enemy.move_named("Toxic Flask")
	if flask != null:
		flask.lean_when = W.PLAYER_LACKS
		flask.lean_status = &"poison"
		flask.lean_factor = 3.0
	if enemy.move_named("Sticky Flask") == null:
		var sticky := _move("Sticky Flask", 3)
		sticky.adds_card = "slimed"
		sticky.adds_count = 2
		enemy.moves.append(sticky)


## The Bomber's Bomb counts down (3), and its toss leaves a Burn (14).
func _bomber(enemy: CardEnemyDefinition):
	var bomb := enemy.move_named("Bomb")
	if bomb != null:
		bomb.wind_up = 1
	var toss := enemy.move_named("Toss")
	if toss != null:
		toss.adds_card = "burn"
		toss.adds_count = 1


## The Priest mends the worst hurt ally, blesses it, and takes offence at Powers (16, 5, 2, 9).
func _priest(enemy: CardEnemyDefinition):
	_status_once(enemy, "curiosity", 2)
	var blessing := enemy.move_named("Blessing")
	if blessing != null:
		blessing.helps = CardEnemyMove.Helps.WORST_HURT_ALLY
	if enemy.move_named("Mend") == null:
		var mend := _move("Mend")
		mend.heal = 8
		mend.helps = CardEnemyMove.Helps.WORST_HURT_ALLY
		mend.cooldown = 2
		mend.rule_only = true
		enemy.moves.append(mend)
	_rule_once(enemy, CardEnemyRule.of(W.ALLY_HURT, "Mend", 50))


## The Ogre roars first, and Skills enrage it (1, 8).
func _ogre(enemy: CardEnemyDefinition):
	_status_once(enemy, "enrage", 2)
	var roar := enemy.move_named("Roar")
	if roar != null:
		roar.first = true


## The Golem sleeps, gaining Block, until hit or three turns pass (12).
func _golem(enemy: CardEnemyDefinition):
	_status_once(enemy, "asleep", 3)
	enemy.sleep_block = 8


## The Colossus curls up when hit hard (13), and at half health rises to its full height: no more than 30 a round, and its Crush
## counts down (4, 19, 3).
func _colossus(enemy: CardEnemyDefinition):
	_status_once(enemy, "mode_shift", 40)
	enemy.curl_block = 20
	enemy.curl_spines = 3
	enemy.curl_turns = 2
	enemy.curl_grows = 10
	if not enemy.phases.is_empty():
		return
	var rise := CardEnemyPhase.new()
	rise.health_under = 50
	rise.line = "The Colossus rises to its full height!"
	rise.clears_harm = true
	rise.statuses = {"might": 2, "invincible": 30}
	var crush := _move("Crush", 28)
	crush.wind_up = 1
	rise.moves.append(_move("Sweep", 9, 2))
	rise.moves.append(_move("Quake", 6, 1, 0, &"weakened", 2))
	rise.moves.append(crush)
	rise.moves.append(_move("Stamp", 12, 1, 12))
	rise.pattern = CYCLE
	enemy.phases.append(rise)


## Loads enemy `key`, lets `how` change it, and saves it where it stands.
func _change(key: String, how: Callable):
	var path := ENEMIES + key + ".tres"
	if not ResourceLoader.exists(path):
		push_warning("no %s to change" % path)
		return
	var enemy: CardEnemyDefinition = load(path)
	how.call(enemy)
	var error := ResourceSaver.save(enemy, path)
	if error != OK:
		push_error("could not save %s (%d)" % [path, error])
		return
	changed_files += 1


func _status_once(enemy: CardEnemyDefinition, key: String, amount: int):
	var statuses := enemy.starting_statuses.duplicate()
	for already in statuses:
		if str(already) == key:
			return
	statuses[key] = amount
	enemy.starting_statuses = statuses


func _rule_once(enemy: CardEnemyDefinition, rule: CardEnemyRule):
	for already in enemy.rules:
		if already != null and already.move == rule.move and already.when == rule.when:
			return
	enemy.rules.append(rule)
