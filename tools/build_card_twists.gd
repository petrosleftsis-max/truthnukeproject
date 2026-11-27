extends SceneTree
## Writes the card game's content for the designer's "try them all" of 2026-11-27 (docs/proposals_2026-11-27_card_hacking.md
## sections 4 to 6): Tethers (twist 7: three cards, an enemy's own, the Leech and the Severer, a relic for a third), the Message and
## the words it can be given (twist 10: data/card_message_words/, and an event offering one), each gate's own starting relic, the
## Blessings, and the party's passives as rare relics (twist 15). Every name and number is a placeholder (PROPOSAL), the designer's to
## change in the editor. Run from a project whose classes are imported:
##     godot --headless --path . --import
##     godot --headless --path . --script res://tools/build_card_twists.gd
## A new file is written only where there is none; a gate's starting relic is changed only while it is still Field Dressing, so
## running it again changes nothing.

const CARDS := "res://data/cards/"
const ENEMIES := "res://data/card_enemies/"
const ENCOUNTERS := "res://data/card_encounters/"
const EVENTS := "res://data/card_events/"
const RELICS := "res://data/card_relics/"
const CHARACTERS := "res://data/card_characters/"
const WORDS := "res://data/card_message_words/"
const T := CardEncounterDefinition.Tier
const K := CardEffect.Kind
const R := CardRelicDefinition.Rarity
const WHEN := CardRelicDefinition.When

var written := 0
var changed_files := 0
var kept := 0


func _init():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORDS))
	_tethers()
	_message()
	_relics()
	_gates()
	print("card twists: %d written, %d changed, %d already there" % [written, changed_files, kept])
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


func _effect(kind: CardEffect.Kind, amount: int, upgraded: int = -1, status: StringName = &"", hits: int = 1) -> CardEffect:
	return CardEffect.of(kind, amount, upgraded, hits, -1, status)


func _tether(card_name: String, rarity: CardDefinition.Rarity, cost: int, target: CardDefinition.Target, strength: int,
		upgraded_strength: int, effects: Array, snaps: Array, flavour: String) -> CardDefinition:
	var card := CardDefinition.new()
	card.name = card_name
	card.type = CardDefinition.Type.TETHER
	card.rarity = rarity
	card.cost = cost
	card.target = target
	card.tether_strength = strength
	card.upgraded_tether_strength = upgraded_strength
	for effect in effects:
		card.effects.append(effect)
	for effect in snaps:
		card.snap_effects.append(effect)
	card.flavour = flavour
	return card


## --- Tethers (twist 7) ---


func _tethers():
	var enemy := CardDefinition.Target.ENEMY
	_save_new(_tether("Leash", CardDefinition.Rarity.UNCOMMON, 1, enemy, 3, 4, [_effect(K.APPLY, 1, -1, &"weakened")],
		[_effect(K.DAMAGE, 6, 9)], "Held short, it cannot swing."), CARDS + "leash.tres")
	_save_new(_tether("Siphon", CardDefinition.Rarity.UNCOMMON, 1, enemy, 3, -1, [_effect(K.DRAIN, 2, 3)], [],
		"Its strength, a little at a time, into you."), CARDS + "siphon.tres")
	_save_new(_tether("Guard Link", CardDefinition.Rarity.COMMON, 1, CardDefinition.Target.ALLY, 3, -1, [_effect(K.BLOCK, 4, 6)],
		[_effect(K.BLOCK, 4, 6)], "A line between you and whoever needs it more (yourself, alone)."), CARDS + "guard_link.tres")
	# The enemy's own: tied by the Leech, draining whoever it holds.
	var line := _tether("Leech Line", CardDefinition.Rarity.STARTER, 0, CardDefinition.Target.NONE, 3, -1, [_effect(K.DRAIN, 2)], [],
		"Hit what holds it, and it comes loose.")
	line.enemy_only = true
	_save_new(line, CARDS + "leech_line.tres")
	# The Leech ties it; the Severer cuts yours.
	var latch := CardEnemyMove.of("Latch")
	latch.ties = "leech_line"
	latch.first = true
	latch.cooldown = 2
	var leech := CardEnemyDefinition.new()
	leech.name = "Leech"
	leech.max_hp_least = 24
	leech.max_hp_most = 28
	leech.pattern = CardEnemyDefinition.Pattern.RANDOM
	leech.moves.append(latch)
	leech.moves.append(CardEnemyMove.of("Bite", 6, 1, 0, &"", 0, &"", 0, 2))
	leech.moves.append(CardEnemyMove.of("Swell", 0, 1, 6, &"", 0, &"might", 1))
	leech.borrow_picture_from = "imp"
	_save_new(leech, ENEMIES + "leech.tres")
	var sever := CardEnemyMove.of("Sever", 8)
	sever.cuts_tethers = 1
	sever.not_twice_running = true
	sever.weight = 2
	var severer := CardEnemyDefinition.new()
	severer.name = "Severer"
	severer.max_hp_least = 40
	severer.max_hp_most = 46
	severer.pattern = CardEnemyDefinition.Pattern.RANDOM
	severer.moves.append(sever)
	var cleave := CardEnemyMove.of("Cleave", 12)
	cleave.not_twice_running = true
	severer.moves.append(cleave)
	severer.moves.append(CardEnemyMove.of("Guard", 0, 1, 10))
	severer.borrow_picture_from = "pit_champion"
	_save_new(severer, ENEMIES + "severer.tres")
	for fight in [["hard_leeches", ["leech", "leech"]], ["hard_severer", ["severer", "rat"]]]:
		var encounter := CardEncounterDefinition.new()
		encounter.tier = T.HARD
		for key in fight[1]:
			encounter.enemies.append(key)
		_save_new(encounter, ENCOUNTERS + fight[0] + ".tres")
	# A third Tether held at once.
	var spool := CardRelicDefinition.new()
	spool.name = "Spool"
	spool.rarity = R.UNCOMMON
	spool.more_tether_slots = 1
	spool.flavour = "More line than you will ever need."
	_save_new(spool, RELICS + "spool.tres")


## --- The Message (twist 10) ---


func _word(key: String, line: String, effect: CardEffect, step: int, weight: int = 1):
	var word := CardMessageWord.new()
	word.line = line
	word.effect = effect
	word.step = step
	word.weight = weight
	_save_new(word, WORDS + key + ".tres")


func _message():
	var card := CardDefinition.new()
	card.name = "The Message"
	card.type = CardDefinition.Type.SKILL
	card.rarity = CardDefinition.Rarity.STARTER
	card.cost = 1
	card.target = CardDefinition.Target.ALL_ENEMIES
	card.effects.append(_effect(K.DRAW, 1))
	card.flavour = "What the Messengers carry. Nearly empty, until the truth is found."
	_save_new(card, CARDS + "the_message.tres")
	_word("forget", "The system was built to forget.", _effect(K.DRAW, 1), 1)
	_word("walls", "Its walls are only code.", _effect(K.DAMAGE, 4), 2, 2)
	_word("lost", "Nothing is lost for good.", _effect(K.BLOCK, 5), 2, 2)
	_word("read", "Every program can be read.", _effect(K.APPLY, 1, -1, &"exposed"), 1)
	_word("fire", "Fire was stolen once, and can be again.", _effect(K.ENERGY, 1), 1)
	_word("gods", "The gods are only programs.", _effect(K.APPLY, 1, -1, &"weakened"), 1)
	_word("found", "The messengers have already found the truth.", _effect(K.HEAL, 3), 2)
	_word("names", "Everything here has a name, and names can be spoken.", _effect(K.GAIN, 1, -1, &"might"), 1)
	_word("dark", "The dark is only what has not been read yet.", _effect(K.GAIN, 1, -1, &"footing"), 1)
	_word("door", "Every lock was made by someone who wanted out.", _effect(K.DAMAGE, 2, -1, &"", 2), 1)
	_word("rot", "What is hidden rots.", _effect(K.APPLY, 2, -1, &"poison"), 1)
	# An event of its own for it: the rest offer to listen as well (CardEventDefinition.offers_a_word).
	var event := CardEventDefinition.new()
	event.title = "A Voice in the Wires"
	event.text = "Somewhere under the hum, a voice repeats a sentence it was never meant to finish."
	var write := CardEventOption.new()
	write.label = "Write it down (the Message)"
	write.outcome = "You write it down, word for word. It means more each time you read it."
	write.action = CardEventOption.Action.MESSAGE
	event.options.append(write)
	var sell := CardEventOption.new()
	sell.label = "Sell it to whoever is listening (50 gold; trace +5)"
	sell.outcome = "Something buys it from you. You hear it somewhere else, later."
	sell.gold = 50
	sell.trace = 5
	event.options.append(sell)
	var fade := CardEventOption.new()
	fade.label = "Let it fade"
	fade.outcome = "It goes on, more quietly, without you."
	event.options.append(fade)
	_save_new(event, EVENTS + "voice_in_the_wires.tres")


## --- Relics: each gate's own, the Blessings, the party's passives (twist 15) ---


func _relic(key: String, relic_name: String, rarity: CardRelicDefinition.Rarity, when: CardRelicDefinition.When, effect: CardEffect,
		flavour: String, learned_from: String = ""):
	var relic := CardRelicDefinition.new()
	relic.name = relic_name
	relic.rarity = rarity
	relic.when = when
	relic.effect = effect
	relic.flavour = flavour
	relic.learned_from = learned_from
	_save_new(relic, RELICS + key + ".tres")


func _relics():
	# Each gate's own starting relic, named for a passive of the main game's (placeholders: the designer refines the gates).
	_relic("gate_iron_hide", "Iron Hide", R.STARTER, WHEN.FIGHT_START, _effect(K.BLOCK, 6), "World's: steady from the first blow.")
	_relic("gate_quick_hands", "Quick Hands", R.STARTER, WHEN.FIRST_TURN, _effect(K.DRAW, 2), "Hermes's: there before anybody else.")
	_relic("gate_dot_master", "DoT Master", R.STARTER, WHEN.FIGHT_START, _effect(K.APPLY, 2, -1, &"poison"), "Pandora's: what comes out of the box.")
	_relic("gate_bandolier", "Bandolier", R.STARTER, WHEN.FIGHT_WON, _effect(K.GOLD, 12), "Charon's: the ferryman's fee, taken after every crossing.")
	_relic("gate_bulwark", "Bulwark", R.STARTER, WHEN.TURN_START, _effect(K.BLOCK, 2), "Tartarus's: the walls of the pit.")
	_relic("gate_drills", "Drills", R.STARTER, WHEN.FIGHT_START, _effect(K.GAIN, 2, -1, &"spines"), "Nemesis's: whoever strikes her pays.")
	_relic("gate_contest_insight", "Contest Insight", R.STARTER, WHEN.FIRST_TURN, _effect(K.ENERGY, 1), "Sophia's: she read the fight before it began.")
	_relic("gate_agile", "Agile", R.STARTER, WHEN.FIGHT_START, _effect(K.GAIN, 1, -1, &"footing"), "Ogdoad's: eight ways to stand.")
	_relic("gate_measured_eye", "Measured Eye", R.STARTER, WHEN.FIGHT_START, _effect(K.APPLY, 1, -1, &"scanned"), "Gnosis's: every one of them, read.")
	_relic("gate_elemental_affinity", "Elemental Affinity", R.STARTER, WHEN.FIGHT_START, _effect(K.GAIN, 1, -1, &"might"), "Yaldabaoth's: the demiurge's hand on the code.")
	# The Blessings, the run's first choice after the gate (the designer will add more).
	_relic("blessing_iron", "Blessing of Iron", R.BLESSING, WHEN.PICKED_UP, _effect(K.MAX_HP, 10), "Given in a dream, for one run.")
	_relic("blessing_patient", "Blessing of the Patient", R.BLESSING, WHEN.FIRST_TURN, _effect(K.ENERGY, 1), "Given in a dream, for one run.")
	_relic("blessing_swift", "Blessing of the Swift", R.BLESSING, WHEN.FIRST_TURN, _effect(K.DRAW, 2), "Given in a dream, for one run.")
	# The party's passives as rare relics, for every gate: what Prometheus learned from the Messengers.
	_relic("night_hunter", "Night Hunter", R.RARE, WHEN.ENEMY_FALLS, _effect(K.ENERGY, 1), "One down, and on to the next.", "Cyrus's Night Hunter")
	_relic("mercy", "Mercy", R.RARE, WHEN.TURN_START, _effect(K.HEAL, 2), "A little mended, every turn.", "Alithia's Mercy")
	_relic("breaker", "Breaker", R.RARE, WHEN.FIGHT_START, _effect(K.GAIN, 2, -1, &"might"), "Through, not around.", "Enfina's Breaker")
	_relic("meditate", "Meditate", R.RARE, WHEN.FIRST_TURN, _effect(K.ENERGY, 2), "Ready before it begins.", "Prometheus's Meditate")


func _gates():
	var relics := {"world": "gate_iron_hide", "hermes": "gate_quick_hands", "pandora": "gate_dot_master", "charon": "gate_bandolier",
		"tartarus": "gate_bulwark", "nemesis": "gate_drills", "sophia": "gate_contest_insight", "ogdoad": "gate_agile",
		"gnosis": "gate_measured_eye", "yaldabaoth": "gate_elemental_affinity"}
	for key in relics:
		var path: String = CHARACTERS + key + ".tres"
		if not ResourceLoader.exists(path):
			push_warning("no %s" % path)
			continue
		var character: CardCharacterDefinition = load(path)
		if character.starting_relic != "field_dressing":
			kept += 1
			continue
		character.starting_relic = relics[key]
		var error := ResourceSaver.save(character, path)
		if error != OK:
			push_error("could not write %s (%d)" % [path, error])
			continue
		changed_files += 1
