extends SceneTree
## Writes the card game's content for Prometheus's hacking (the designer, 2026-11-27: the twists read as hacking, co-op, and the
## gates as characters; docs/card_game.md "Hacking"): the ten gates' decks (data/card_characters/), Scan and Deep Scan, the Glitch
## the trace puts in, cards for a partner (co-op only), loud cards and half-read code marked on cards there were, the Devourer and
## the Core with their sentries, each layer's boss, and six of the network's oddities as events. Every name, number and deck is a
## placeholder, the designer's to change in the editor (they make the cards). Run from a project whose classes are imported:
##     godot --headless --path . --import
##     godot --headless --path . --script res://tools/build_hack_content.gd
## A new file is written only where there is none; a card or encounter there was is changed where it stands, and only what this
## adds, so running it again changes nothing.

const CARDS := "res://data/cards/"
const ENEMIES := "res://data/card_enemies/"
const ENCOUNTERS := "res://data/card_encounters/"
const EVENTS := "res://data/card_events/"
const CHARACTERS := "res://data/card_characters/"
const W := CardEnemyRule.When
const T := CardEncounterDefinition.Tier
const K := CardEffect.Kind
const A := CardEventOption.Action

var written := 0
var changed_files := 0
var kept := 0


func _init():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CHARACTERS))
	_cards()
	_loud_and_half_read()
	_enemies()
	_encounters()
	_events()
	_characters()
	print("hack content: %d written, %d changed, %d already there" % [written, changed_files, kept])
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


## Loads `path`, lets `how` change it (true if it did), and saves it again only then.
func _change(path: String, how: Callable):
	if not ResourceLoader.exists(path):
		push_warning("no %s to change" % path)
		return
	var resource := load(path)
	if not how.call(resource):
		kept += 1
		return
	var error := ResourceSaver.save(resource, path)
	if error != OK:
		push_error("could not write %s (%d)" % [path, error])
		return
	changed_files += 1


func _effect(kind: CardEffect.Kind, amount: int, upgraded: int = -1, status: StringName = &"") -> CardEffect:
	return CardEffect.of(kind, amount, upgraded, 1, -1, status)


func _card(card_name: String, type: CardDefinition.Type, rarity: CardDefinition.Rarity, cost: int, target: CardDefinition.Target,
		effects: Array, flavour: String) -> CardDefinition:
	var card := CardDefinition.new()
	card.name = card_name
	card.type = type
	card.rarity = rarity
	card.cost = cost
	card.target = target
	for effect in effects:
		card.effects.append(effect)
	card.flavour = flavour
	return card


## --- Cards ---


func _cards():
	var S := CardDefinition.Type.SKILL
	# Scan (twist 6): an encrypted enemy's intent seen. Every gate's deck starts with one.
	var scan := _card("Scan", S, CardDefinition.Rarity.STARTER, 0, CardDefinition.Target.ENEMY,
		[_effect(K.APPLY, 1, -1, &"scanned"), _effect(K.DRAW, 1)], "Read what it is about to do.")
	_save_new(scan, CARDS + "scan.tres")
	var deep := _card("Deep Scan", S, CardDefinition.Rarity.UNCOMMON, 1, CardDefinition.Target.ALL_ENEMIES,
		[_effect(K.APPLY, 1, -1, &"scanned"), _effect(K.DRAW, 1), _effect(K.APPLY, 1, 2, &"exposed")], "All of it, laid open.")
	deep.upgraded_cost = 0
	deep.effects[2].struck = true
	_save_new(deep, CARDS + "deep_scan.tres")
	# The Glitch the trace puts in every deck at 75 (twist 3): a dead draw, gone at the end of the turn it is drawn.
	var glitch := _card("Glitch", CardDefinition.Type.STATUS, CardDefinition.Rarity.STARTER, 0, CardDefinition.Target.NONE, [],
		"Something in the code that should not be there.")
	glitch.unplayable = true
	glitch.ethereal = true
	_save_new(glitch, CARDS + "glitch.tres")
	# For a partner (co-op only): what they give goes to the other player.
	var ally := CardDefinition.Target.ALLY
	for made in [["shared_shield", _card("Shared Shield", S, CardDefinition.Rarity.COMMON, 1, ally, [_effect(K.BLOCK, 7, 10)], "Cover them.")],
			["handoff", _card("Handoff", S, CardDefinition.Rarity.UNCOMMON, 0, ally, [_effect(K.DRAW, 2, 3)], "Pass them what they need.")],
			["patch_up", _card("Patch Up", S, CardDefinition.Rarity.UNCOMMON, 1, ally, [_effect(K.HEAL, 5, 8)], "Hold still.")],
			["uplink", _card("Uplink", S, CardDefinition.Rarity.UNCOMMON, 1, ally, [_effect(K.GAIN, 2, 3, &"might")], "Lend them your strength.")],
			["overclock", _card("Overclock", S, CardDefinition.Rarity.RARE, 1, ally, [_effect(K.ENERGY, 2, 3)], "Run hot, for both of you.")]]:
		var card: CardDefinition = made[1]
		card.coop_only = true
		card.exhausts = made[0] in ["handoff", "patch_up", "uplink", "overclock"]
		_save_new(card, CARDS + made[0] + ".tres")


## Loud cards raise the trace as they are played (twist 3); half-read code is struck out until played once (twist 4).
func _loud_and_half_read():
	for loud in [["crushing_blow", 2], ["cleave", 2], ["flurry", 1], ["last_stand", 3], ["plague", 2], ["fortress", 1]]:
		_change(CARDS + loud[0] + ".tres", _set_trace.bind(int(loud[1])))
	for half in ["heavy_swing", "venom_strike", "rally", "deep_breath"]:
		_change(CARDS + half + ".tres", _strike_last)


func _set_trace(card: CardDefinition, amount: int) -> bool:
	if card.trace == amount:
		return false
	card.trace = amount
	return true


func _strike_last(card: CardDefinition) -> bool:
	if card.effects.size() < 2 or card.effects[-1].struck:
		return false
	card.effects[-1].struck = true
	return true


## --- Enemies: the Devourer (twist 11), the Core and its sentries ---


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


func _enemies():
	# The Devourer: a program that eats his code. What it holds makes it hit harder; a Status card chokes it and it spits all of it
	# out; each quarter of its health lost, one card falls back out (the Glutton status). It feeds you its own bile to choke on.
	var devour := _move("Devour")
	devour.steals = 2
	devour.first = true
	devour.not_twice_running = true
	var gnash := _move("Gnash", 7, 1, 0, &"", 0, &"", 0, 2)
	gnash.damage_per_held = 3
	var bile := _move("Regurgitate", 4)
	bile.adds_card = "slimed"
	bile.adds_count = 2
	bile.adds_to = CardEnemyMove.Pile.DRAW
	bile.not_twice_running = true
	var digest := _move("Digest", 0, 1, 12, &"", 0, &"might", 2)
	digest.cooldown = 2
	var gorge := _move("Gorge", 10)
	gorge.damage_per_held = 4
	gorge.rule_only = true
	gorge.not_twice_running = true
	var devourer := _enemy("The Devourer", 170, 180, CardEnemyDefinition.Pattern.RANDOM, [devour, gnash, bile, digest, gorge], {"glutton": 1}, "glutton")
	devourer.rules.append(CardEnemyRule.of(W.IT_HAS, "Gorge", 3, &"holding"))
	var starving := CardEnemyPhase.new()
	starving.health_under = 50
	starving.line = "It is starving. It eats faster."
	starving.statuses = {"might": 2}
	devourer.phases.append(starving)
	_save_new(devourer, ENEMIES + "devourer.tres")
	# Sentries: small watchers the Core calls; they shield each other.
	var guard := _move("Shield", 0, 1, 6)
	guard.helps = CardEnemyMove.Helps.WORST_HURT_ALLY
	_save_new(_enemy("Sentry", 18, 22, CardEnemyDefinition.Pattern.RANDOM, [_move("Ping", 5, 1, 0, &"", 0, &"", 0, 2), _move("Flag", 0, 1, 0, &"exposed", 1),
		guard], {}, "kindled_hound"), ENEMIES + "sentry.tres")
	# The Core: the system's heart. It shows nothing until Scanned; it calls sentries, and late on rewrites itself (encrypted again).
	var overclock := _move("Overclock", 28)
	overclock.wind_up = 1
	var call := _move("Spawn Sentries")
	call.summons = ["sentry", "sentry"]
	call.rule_only = true
	call.most_times = 1
	var core := _enemy("The Core", 230, 240, CardEnemyDefinition.Pattern.CYCLE, [_move("Purge", 12), _move("Trace Route", 6, 1, 0, &"exposed", 2),
		_move("Recompile", 0, 1, 16, &"", 0, &"might", 2), overclock, call], {}, "illusory_dragon")
	core.shows = CardEnemyDefinition.Shows.NOTHING
	core.rules.append(CardEnemyRule.of(W.ITS_HEALTH_UNDER, "Spawn Sentries", 60))
	var rewrite := CardEnemyPhase.new()
	rewrite.health_under = 30
	rewrite.line = "The Core rewrites itself."
	rewrite.clears_harm = true
	rewrite.statuses = {"might": 3}
	core.phases.append(rewrite)
	_save_new(core, ENEMIES + "core.tres")


## --- Each layer's boss, and a fight of sentries ---


func _encounters():
	for fight in [["boss_devourer", T.BOSS, ["devourer"], 2], ["boss_core", T.BOSS, ["core"], 3], ["hard_sentries", T.HARD, ["sentry", "sentry", "sentry"], 0]]:
		var encounter := CardEncounterDefinition.new()
		encounter.tier = fight[1]
		for key in fight[2]:
			encounter.enemies.append(key)
		encounter.layer = fight[3]
		_save_new(encounter, ENCOUNTERS + fight[0] + ".tres")
	_change(ENCOUNTERS + "boss_colossus.tres", _first_layer)


func _first_layer(encounter: CardEncounterDefinition) -> bool:
	if encounter.layer == 1:
		return false
	encounter.layer = 1
	return true


## --- The network's oddities (twist 14) ---


func _option(label: String, outcome: String, action: CardEventOption.Action = A.NONE, gold: int = 0, hp: int = 0, trace: int = 0,
		fragment: bool = false, adds: String = "") -> CardEventOption:
	var option := CardEventOption.new()
	option.label = label
	option.outcome = outcome
	option.action = action
	option.gold = gold
	option.hp = hp
	option.trace = trace
	option.fragment = fragment
	option.adds_card = adds
	return option


func _event(key: String, title: String, text: String, options: Array):
	var event := CardEventDefinition.new()
	event.title = title
	event.text = text
	for option in options:
		event.options.append(option)
	_save_new(event, EVENTS + key + ".tres")


func _events():
	_event("looping_corridor", "The Looping Corridor", "The same hallway of code, again. The same flickering lamp, again. Something wants you to stay.", [
		_option("Walk on, and on (lose 6 health; trace -10)", "You walk until the loop forgets you. Nobody saw you go.", A.NONE, 0, -6, -10),
		_option("Break the loop (trace +8; a card)", "You force it open. Loud, but something was caught in it.", A.CARD_REWARD, 0, 0, 8),
		_option("Turn back", "You step back the way you came.")])
	_event("shifting_room", "The Shifting Room", "Walls of data rearrange themselves as you watch. A card in your hand begins to change with them.", [
		_option("Let it rewrite a card", "The room rewrites it while you hold it.", A.TRANSFORM_CARD),
		_option("Hold everything still (trace +5; upgrade a card)", "You hold on until it gives. It noticed.", A.UPGRADE_CARD, 0, 0, 5),
		_option("Leave before it notices", "You slip out between two of its shapes.")])
	_event("talking_thing", "The Talking Thing", "A process speaks to you in a voice it stole from someone. It offers to trade.", [
		_option("Trade (pay 40 gold; a relic)", "It takes the gold and leaves something behind.", A.RANDOM_RELIC, -40),
		_option("Listen (75 gold; a Glitch in your deck)", "It tells you its secrets, and leaves one of them inside you.", A.NONE, 75, 0, 0, false, "glitch"),
		_option("Ignore it", "It goes on talking after you have gone.")])
	_event("notes_on_the_wall", "Notes on the Wall", "Someone was here before you. Their notes are scrawled across the code: what the struck-out lines mean.", [
		_option("Read them (every half-read card in your deck read)", "The crossed-out words come clear.", A.READ_ALL),
		_option("Copy them out (trace +6; a card)", "You take the time to copy one of their tricks.", A.CARD_REWARD, 0, 0, 6),
		_option("Leave them", "You leave them for whoever comes next.")])
	_event("memento", "A Memento", "Something kept, wrapped in a loop of its own: a piece of another gate's code.", [
		_option("Take it (a code fragment; trace +10)", "It fits nowhere in your deck yet. But it is a piece of something.", A.NONE, 0, 0, 10, true),
		_option("Leave it be (trace -5)", "You leave no mark on it.", A.NONE, 0, 0, -5)])
	_event("stash", "A Stash", "A hidden partition, full of what someone hid from the system.", [
		_option("Take the gold (60 gold; trace +5)", "You empty it.", A.NONE, 60, 0, 5),
		_option("Take a card", "One of them is worth keeping.", A.CARD_REWARD),
		_option("Wipe it, leaving no trace (trace -10)", "Nothing was ever here.", A.NONE, 0, 0, -10)])


## --- The ten gates as characters (placeholder decks; the playstyles are suggestions) ---


func _characters():
	var gates := [
		["world", "World", 1, ["thrust", "thrust", "thrust", "thrust", "thrust", "guard", "guard", "guard", "guard", "heavy_swing", "scan"],
			"Steady and plain: strikes, guards, a heavy swing.\nThe first deck, and the measure of the others: a little of everything, nothing it leans on. Suggested cards: plain attacks and Block that grow with upgrades, and a card or two rewarding a balanced turn (an Attack and a Skill played together)."],
		["hermes", "Hermes", 2, ["thrust", "thrust", "thrust", "thrust", "guard", "guard", "guard", "guard", "lunge", "twin_cut", "scan"],
			"Fast and light: many cheap cards a turn, drawing as it goes.\nThe messenger: cards that cost nothing, drawing, and a bonus for every few cards played in a turn (a Relay: every third card draws one). Suggested cards: zero-cost attacks, cards that grow cheaper as the turn goes, a finisher dealing more for every card played this turn. Weak against Overtime and Toll."],
		["pandora", "Pandora", 3, ["thrust", "thrust", "thrust", "thrust", "guard", "guard", "guard", "guard", "poison_vial", "feint", "scan"],
			"Opens the box: poisons and curses on the enemy, and her own junk turned into weapons.\nWhat comes out cannot be put back: Poison, Weakened and Exposed on the enemies, and Status cards in her own deck (Wounds, Glitches) played for effects rather than dead draws. Suggested cards: one growing stronger for each Status card in the deck, one throwing a Status card at an enemy, a Power that draws a card whenever a Status card is drawn."],
		["charon", "Charon", 4, ["thrust", "thrust", "thrust", "thrust", "guard", "guard", "guard", "guard", "crushing_blow", "study", "scan"],
			"Pays the ferryman: health for power, cards exhausted for good.\nThe toll: cards paid for in health rather than energy, strong effects for exhausting a card (ferried across), and gold that counts in a fight. Suggested cards: one costing 3 health and hitting hard, cards that exhaust a card from the hand for a bonus, a Power mending a little whenever a card is exhausted."],
		["tartarus", "Tartarus", 5, ["thrust", "thrust", "thrust", "thrust", "guard", "guard", "guard", "guard", "brace", "heavy_swing", "scan"],
			"The pit: Block piled high and kept, enemies held down.\nNothing gets out: Block that stays from turn to turn, Entangled and Brittle on the enemy, slow heavy blows that land through Block. Suggested cards: a Power keeping Block between turns (Slay the Spire's Barricade), a blow dealing damage equal to your Block, cards that Entangle."],
		["nemesis", "Nemesis", 6, ["thrust", "thrust", "thrust", "thrust", "guard", "guard", "guard", "guard", "riposte", "riposte", "scan"],
			"Retribution: hurts whoever hurts her.\nSpines, blows struck back when struck, and damage growing with the damage taken this fight (a grudge). Suggested cards: Riposte's kin, a Grudge status adding to every hit for each hit taken, a Taunt that draws every enemy's attack to her (in co-op, keeping the partner safe)."],
		["sophia", "Sophia", 7, ["thrust", "thrust", "thrust", "thrust", "guard", "guard", "guard", "guard", "study", "second_wind", "scan"],
			"Wisdom: knows her deck, betters it in the fight, reads the code sooner.\nLooking ahead (the next cards seen, some discarded), a card in the hand upgraded for the fight, cards played back from the discard pile, half-read code read as it is drawn. Suggested cards: Study and Deep Breath's kin, one upgrading every card in the hand, a Power drawing one more card a turn."],
		["ogdoad", "Ogdoad", 8, ["thrust", "thrust", "thrust", "thrust", "guard", "guard", "guard", "guard", "twin_cut", "twin_cut", "scan"],
			"The eight: pairs and cycles.\nCards that come in twos (playing one draws its twin), effects that change on even and odd turns, and a count to eight that pays off on every eighth card played. Suggested cards: twins sharing a name, a Power counting the cards played, a card stronger on an even turn."],
		["gnosis", "Gnosis", 9, ["thrust", "thrust", "thrust", "thrust", "guard", "guard", "guard", "guard", "feint", "scan", "scan"],
			"Knowledge revealed: scans, sees what is coming, strikes at it.\nThe Scan deck: bonuses against Scanned enemies, Second Sight of its own (the plan after the next), and punishing what it foresees: more damage to an enemy about to attack, Block for exactly what is coming. Suggested cards: one Scanning every enemy and drawing, one cancelling a foreseen move, cards stronger against a Scanned enemy."],
		["yaldabaoth", "Yaldabaoth", 10, ["thrust", "thrust", "thrust", "thrust", "guard", "guard", "guard", "guard", "sweep", "crushing_blow", "scan"],
			"The demiurge: rewrites the code, makes and corrupts cards; loud.\nCards in the hand rewritten into others, cards copied, a card corrupted to be stronger and louder (raising the trace each time it is played). High risk, a high trace. Suggested cards: one turning the hand into random cards a rarity higher, a Power copying the first card played each turn, loud cards that pay off big."],
	]
	for gate in gates:
		var character := CardCharacterDefinition.new()
		character.name = gate[1]
		character.gate = gate[2]
		character.health = 60
		for key in gate[3]:
			character.starting_deck.append(key)
		character.starting_relic = "field_dressing"
		character.playstyle = gate[4]
		character.fragments_needed = 0 if gate[0] == "world" else 3
		_save_new(character, CHARACTERS + gate[0] + ".tres")
