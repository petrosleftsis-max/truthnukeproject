extends SceneTree
## Writes the card game's first content (docs/card_game.md) into data/cards/, data/card_enemies/, data/card_encounters/,
## data/card_relics/ and data/card_events/: placeholders to play with, every name and number the designer's to change in the
## editor afterwards. Run once, from a project whose classes are imported:
##     godot --headless --path . --import
##     godot --headless --path . --script res://tools/build_card_content.gd
## Running it again writes the same files over any changes made to them since.

const A := CardDefinition.Type.ATTACK
const S := CardDefinition.Type.SKILL
const P := CardDefinition.Type.POWER
const STARTER := CardDefinition.Rarity.STARTER
const COMMON := CardDefinition.Rarity.COMMON
const UNCOMMON := CardDefinition.Rarity.UNCOMMON
const RARE := CardDefinition.Rarity.RARE
const ENEMY := CardDefinition.Target.ENEMY
const ALL := CardDefinition.Target.ALL_ENEMIES
const NONE := CardDefinition.Target.NONE

## key: [name, type, rarity, cost, upgraded cost (-1 same), target, effects, exhausts]. An effect: [kind, amount, upgraded amount,
## hits, upgraded hits, status].
const CARDS := {
	"thrust": ["Thrust", A, STARTER, 1, -1, ENEMY, [["DAMAGE", 6, 9]], false],
	"guard": ["Guard", S, STARTER, 1, -1, NONE, [["BLOCK", 5, 8]], false],
	"heavy_swing": ["Heavy Swing", A, STARTER, 2, -1, ENEMY, [["DAMAGE", 9, 12], ["APPLY", 2, 3, 1, -1, "exposed"]], false],
	"twin_cut": ["Twin Cut", A, COMMON, 1, -1, ENEMY, [["DAMAGE", 4, 5, 2, 2]], false],
	"sweep": ["Sweep", A, COMMON, 1, -1, ALL, [["DAMAGE", 6, 9]], false],
	"lunge": ["Lunge", A, COMMON, 0, -1, ENEMY, [["DAMAGE", 3, 5], ["DRAW", 1, 1]], false],
	"feint": ["Feint", A, COMMON, 1, -1, ENEMY, [["DAMAGE", 6, 8], ["APPLY", 1, 2, 1, -1, "weakened"]], false],
	"riposte": ["Riposte", A, COMMON, 1, -1, ENEMY, [["DAMAGE", 5, 7], ["BLOCK", 5, 7]], false],
	"crushing_blow": ["Crushing Blow", A, COMMON, 2, -1, ENEMY, [["DAMAGE", 13, 17]], false],
	"brace": ["Brace", S, COMMON, 1, -1, NONE, [["BLOCK", 8, 11]], false],
	"second_wind": ["Second Wind", S, COMMON, 1, -1, NONE, [["BLOCK", 6, 8], ["DRAW", 1, 1]], false],
	"poison_vial": ["Poison Vial", S, COMMON, 1, -1, ENEMY, [["APPLY", 4, 6, 1, -1, "poison"]], false],
	"study": ["Study", S, COMMON, 1, -1, NONE, [["DRAW", 2, 3]], false],
	"flurry": ["Flurry", A, UNCOMMON, 1, -1, ENEMY, [["DAMAGE", 2, 3, 4, 4]], false],
	"cleave": ["Cleave", A, UNCOMMON, 2, -1, ALL, [["DAMAGE", 11, 15]], false],
	"venom_strike": ["Venom Strike", A, UNCOMMON, 1, -1, ENEMY, [["DAMAGE", 5, 7], ["APPLY", 3, 4, 1, -1, "poison"]], false],
	"shield_wall": ["Shield Wall", S, UNCOMMON, 2, -1, NONE, [["BLOCK", 13, 17]], false],
	"taunt": ["Taunt", S, UNCOMMON, 1, -1, ALL, [["APPLY", 2, 3, 1, -1, "weakened"]], false],
	"expose": ["Expose", S, UNCOMMON, 0, -1, ENEMY, [["APPLY", 2, 3, 1, -1, "exposed"]], true],
	"rally": ["Rally", S, UNCOMMON, 1, 0, NONE, [["ENERGY", 2, 2], ["DRAW", 1, 1]], true],
	"battle_hymn": ["Battle Hymn", P, UNCOMMON, 1, -1, NONE, [["GAIN", 2, 3, 1, -1, "might"]], false],
	"steady_footing": ["Steady Footing", P, UNCOMMON, 1, -1, NONE, [["GAIN", 2, 3, 1, -1, "footing"]], false],
	"iron_ward": ["Iron Ward", P, UNCOMMON, 2, -1, NONE, [["GAIN", 3, 4, 1, -1, "ward"]], false],
	"last_stand": ["Last Stand", A, RARE, 2, -1, ENEMY, [["DAMAGE", 28, 36]], true],
	"deep_breath": ["Deep Breath", S, RARE, 0, -1, NONE, [["ENERGY", 2, 3], ["DRAW", 2, 2]], true],
	"fortress": ["Fortress", S, RARE, 3, 2, NONE, [["BLOCK", 24, 24]], false],
	"plague": ["Plague", S, RARE, 2, -1, ALL, [["APPLY", 6, 8, 1, -1, "poison"]], false],
	"war_chant": ["War Chant", P, RARE, 2, 1, NONE, [["GAIN", 1, 1, 1, -1, "frenzy"]], false],
}

## key: [name, least health, most health, pattern (CYCLE or RANDOM), moves, starting statuses, borrow picture from]. A move:
## [name, damage, hits, block, status given to the player, amount, status taken, amount, weight].
const ENEMIES := {
	"rat": ["Rat", 11, 15, "RANDOM", [["Bite", 6, 1, 0, "", 0, "", 0, 3], ["Gnaw", 3, 1, 0, "weakened", 1, "", 0, 2]], {}, "rat"],
	"gnawer": ["Gnawer", 14, 18, "RANDOM", [["Claw", 4, 2, 0, "", 0, "", 0, 3], ["Hiss", 0, 1, 4, "", 0, "might", 1, 1]], {}, "gnawer"],
	"hired_bow": ["Hired Bow", 18, 22, "CYCLE", [["Take Aim", 0, 1, 6, "", 0, "might", 1, 1], ["Loose", 9, 1, 0, "", 0, "", 0, 1],
		["Volley", 4, 2, 0, "", 0, "", 0, 1]], {}, "hired_bow"],
	"sellsword": ["Sellsword", 30, 34, "RANDOM", [["Slash", 11, 1, 0, "", 0, "", 0, 3], ["Shield Bash", 6, 1, 6, "", 0, "", 0, 2],
		["Taunt", 0, 1, 0, "exposed", 2, "", 0, 1]], {}, "sellsword"],
	"priest": ["Priest", 24, 28, "CYCLE", [["Smite", 7, 1, 0, "", 0, "", 0, 1], ["Blessing", 0, 1, 0, "", 0, "ward", 2, 1],
		["Condemn", 5, 1, 0, "brittle", 2, "", 0, 1]], {}, "priest"],
	"bomber": ["Bomber", 20, 24, "CYCLE", [["Light the Fuse", 0, 1, 5, "", 0, "", 0, 1], ["Bomb", 15, 1, 0, "", 0, "", 0, 1],
		["Toss", 6, 1, 0, "", 0, "", 0, 1]], {}, "bomber"],
	"alchemist": ["Alchemist", 22, 26, "RANDOM", [["Toxic Flask", 0, 1, 0, "poison", 4, "", 0, 2], ["Acid Splash", 7, 1, 0, "", 0, "", 0, 2],
		["Drink", 0, 1, 8, "", 0, "", 0, 1]], {}, "alchemist"],
	"ogre": ["Ogre", 58, 64, "CYCLE", [["Roar", 0, 1, 0, "", 0, "might", 2, 1], ["Smash", 16, 1, 0, "", 0, "", 0, 1],
		["Stomp", 8, 1, 0, "exposed", 2, "", 0, 1], ["Smash", 16, 1, 0, "", 0, "", 0, 1]], {}, "ogre"],
	"golem": ["Golem", 66, 72, "CYCLE", [["Harden", 0, 1, 14, "", 0, "", 0, 1], ["Slam", 13, 1, 0, "", 0, "", 0, 1],
		["Crush", 7, 2, 0, "", 0, "", 0, 1]], {"spines": 3}, "golem"],
	"colossus": ["Colossus", 160, 170, "CYCLE", [["Rise", 0, 1, 12, "", 0, "might", 2, 1], ["Sweep", 9, 2, 0, "", 0, "", 0, 1],
		["Quake", 6, 1, 0, "weakened", 2, "", 0, 1], ["Crush", 28, 1, 0, "", 0, "", 0, 1], ["Brace", 0, 1, 20, "", 0, "", 0, 1]], {}, "colossus"],
}

## key: [tier, enemies].
const ENCOUNTERS := {
	"easy_rats": ["EASY", ["rat", "rat"]],
	"easy_gnawer": ["EASY", ["gnawer"]],
	"easy_bow": ["EASY", ["hired_bow"]],
	"easy_mixed": ["EASY", ["rat", "gnawer"]],
	"hard_sellsword": ["HARD", ["sellsword"]],
	"hard_priest": ["HARD", ["priest", "rat"]],
	"hard_bomber": ["HARD", ["bomber", "hired_bow"]],
	"hard_alchemist": ["HARD", ["alchemist", "gnawer"]],
	"hard_pack": ["HARD", ["gnawer", "gnawer", "rat"]],
	"elite_ogre": ["ELITE", ["ogre"]],
	"elite_golem": ["ELITE", ["golem"]],
	"boss_colossus": ["BOSS", ["colossus"]],
}

## key: [name, when, effect [kind, amount, status], rarity].
const RELICS := {
	"field_dressing": ["Field Dressing", "FIGHT_WON", ["HEAL", 6, ""], "STARTER"],
	"iron_buckle": ["Iron Buckle", "FIGHT_START", ["BLOCK", 10, ""], "COMMON"],
	"quick_boots": ["Quick Boots", "FIRST_TURN", ["DRAW", 2, ""], "COMMON"],
	"spare_lantern": ["Spare Lantern", "FIRST_TURN", ["ENERGY", 1, ""], "COMMON"],
	"bile_vial": ["Vial of Bile", "FIGHT_START", ["APPLY", 3, "poison"], "COMMON"],
	"heart_charm": ["Heart Charm", "PICKED_UP", ["MAX_HP", 8, ""], "COMMON"],
	"lucky_coin": ["Lucky Coin", "FIGHT_WON", ["GOLD", 8, ""], "COMMON"],
	"whetstone": ["Whetstone", "FIGHT_START", ["GAIN", 1, "might"], "UNCOMMON"],
	"hobnail_boots": ["Hobnail Boots", "FIGHT_START", ["GAIN", 1, "footing"], "UNCOMMON"],
	"old_shield": ["Old Shield", "TURN_START", ["BLOCK", 3, ""], "UNCOMMON"],
	"heralds_horn": ["Herald's Horn", "FIGHT_START", ["APPLY", 1, "weakened"], "RARE"],
}

## key: [title, text, options]. An option: [label, outcome, gold, hp, max hp, action].
const EVENTS := {
	"shrine": ["A Quiet Shrine", "Candles burn low before a weathered statue. Someone has left a bowl for offerings, and a whetstone worn thin.",
		[["Kneel and pray (lose 7 health, upgrade a card)", "Something steadies your hands.", 0, -7, 0, "UPGRADE_CARD"],
		["Leave", "You leave the candles to burn.", 0, 0, 0, "NONE"]]],
	"pack": ["An Abandoned Pack", "A traveller's pack lies by the road, its straps cut.",
		[["Search it (choose a card)", "Something useful, under the spare socks.", 0, 0, 0, "CARD_REWARD"],
		["Take the coin purse (40 gold)", "Light, but it jingles.", 40, 0, 0, "NONE"]]],
	"stranger": ["The Stranger", "A stranger in a grey coat offers to lighten your load - for a price.",
		[["Pay 50 gold (remove a card)", "The stranger pockets the coins, and something you carried is gone.", -50, 0, 0, "REMOVE_CARD"],
		["Decline", "The stranger shrugs and walks on.", 0, 0, 0, "NONE"]]],
	"tonic": ["Bitter Tonic", "A peddler swears this tonic will make you strong. It smells like a swamp.",
		[["Drink it (5 most health)", "Vile. You feel sturdier all the same.", 0, 0, 5, "NONE"],
		["Sell it on (30 gold)", "Someone else's swamp now.", 30, 0, 0, "NONE"],
		["Leave", "You keep walking.", 0, 0, 0, "NONE"]]],
}


func _init():
	for folder in ["res://data/cards", "res://data/card_enemies", "res://data/card_encounters", "res://data/card_relics", "res://data/card_events"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var written := 0
	for key in CARDS:
		var row: Array = CARDS[key]
		var card := CardDefinition.new()
		card.name = row[0]
		card.type = row[1]
		card.rarity = row[2]
		card.cost = row[3]
		card.upgraded_cost = row[4]
		card.target = row[5]
		var effects: Array[CardEffect] = []
		for spec in row[6]:
			effects.append(_effect(spec))
		card.effects = effects
		card.exhausts = row[7]
		written += _save(card, "res://data/cards/%s.tres" % key)
	for key in ENEMIES:
		var row: Array = ENEMIES[key]
		var enemy := CardEnemyDefinition.new()
		enemy.name = row[0]
		enemy.max_hp_least = row[1]
		enemy.max_hp_most = row[2]
		enemy.pattern = CardEnemyDefinition.Pattern[row[3]]
		var moves: Array[CardEnemyMove] = []
		for spec in row[4]:
			moves.append(CardEnemyMove.of(spec[0], spec[1], spec[2], spec[3], StringName(spec[4]), spec[5], StringName(spec[6]), spec[7], spec[8]))
		enemy.moves = moves
		var statuses := {}
		for status in row[5]:
			statuses[StringName(status)] = row[5][status]
		enemy.starting_statuses = statuses
		enemy.borrow_picture_from = row[6]
		written += _save(enemy, "res://data/card_enemies/%s.tres" % key)
	for key in ENCOUNTERS:
		var row: Array = ENCOUNTERS[key]
		var encounter := CardEncounterDefinition.new()
		encounter.tier = CardEncounterDefinition.Tier[row[0]]
		var enemies: Array[String] = []
		enemies.assign(row[1])
		encounter.enemies = enemies
		written += _save(encounter, "res://data/card_encounters/%s.tres" % key)
	for key in RELICS:
		var row: Array = RELICS[key]
		var relic := CardRelicDefinition.new()
		relic.name = row[0]
		relic.when = CardRelicDefinition.When[row[1]]
		relic.effect = CardEffect.of(CardEffect.Kind[row[2][0]], row[2][1], -1, 1, -1, StringName(row[2][2]))
		relic.rarity = CardRelicDefinition.Rarity[row[3]]
		written += _save(relic, "res://data/card_relics/%s.tres" % key)
	for key in EVENTS:
		var row: Array = EVENTS[key]
		var event := CardEventDefinition.new()
		event.title = row[0]
		event.text = row[1]
		var options: Array[CardEventOption] = []
		for spec in row[2]:
			var option := CardEventOption.new()
			option.label = spec[0]
			option.outcome = spec[1]
			option.gold = spec[2]
			option.hp = spec[3]
			option.max_hp = spec[4]
			option.action = CardEventOption.Action[spec[5]]
			options.append(option)
		event.options = options
		written += _save(event, "res://data/card_events/%s.tres" % key)
	print("Card content written: %d files." % written)
	quit(0)


func _effect(spec: Array) -> CardEffect:
	var hits: int = spec[3] if spec.size() > 3 else 1
	var upgraded_hits: int = spec[4] if spec.size() > 4 else -1
	var status := StringName(spec[5]) if spec.size() > 5 else &""
	return CardEffect.of(CardEffect.Kind[spec[0]], spec[1], spec[2], hits, upgraded_hits, status)


func _save(resource: Resource, path: String) -> int:
	var error := ResourceSaver.save(resource, path)
	if error != OK:
		push_error("Could not write %s (%d)." % [path, error])
		return 0
	return 1
