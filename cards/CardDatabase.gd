extends RefCounted
class_name CardDatabase
## Everything the card game is made of, read from its data folders the first time it is asked for (DataFolder): cards, enemies,
## encounters, relics and events, each keyed by its file name (docs/card_game.md).

const CARDS := "res://data/cards/"
const ENEMIES := "res://data/card_enemies/"
const ENCOUNTERS := "res://data/card_encounters/"
const RELICS := "res://data/card_relics/"
const EVENTS := "res://data/card_events/"
const CHARACTERS := "res://data/card_characters/"
## The words the Message can be given (twist 10).
const MESSAGE_WORDS := "res://data/card_message_words/"
## The character a run is played with when none is chosen (a suite, an old call).
const FIRST_CHARACTER := "world"

## The deck a run starts with (card keys), and the relic.
const STARTING_DECK := ["thrust", "thrust", "thrust", "thrust", "thrust", "guard", "guard", "guard", "guard", "heavy_swing"]
const STARTING_RELIC := "field_dressing"

static var _cards := {}
static var _enemies := {}
static var _encounters := {}
static var _relics := {}
static var _events := {}
static var _characters := {}
static var _message_words := {}
static var _read := false


static func _read_all():
	if _read:
		return
	_read = true
	_cards = DataFolder.read(CARDS, CardDefinition)
	_enemies = DataFolder.read(ENEMIES, CardEnemyDefinition)
	_encounters = DataFolder.read(ENCOUNTERS, CardEncounterDefinition)
	_relics = DataFolder.read(RELICS, CardRelicDefinition)
	_events = DataFolder.read(EVENTS, CardEventDefinition)
	_characters = DataFolder.read(CHARACTERS, CardCharacterDefinition)
	_message_words = DataFolder.read(MESSAGE_WORDS, CardMessageWord)


static func message_words() -> Dictionary:
	_read_all()
	return _message_words


static func message_word(key: String) -> CardMessageWord:
	return message_words().get(key)


static func cards() -> Dictionary:
	_read_all()
	return _cards


static func enemies() -> Dictionary:
	_read_all()
	return _enemies


static func encounters() -> Dictionary:
	_read_all()
	return _encounters


static func relics() -> Dictionary:
	_read_all()
	return _relics


static func events() -> Dictionary:
	_read_all()
	return _events


static func characters() -> Dictionary:
	_read_all()
	return _characters


static func character(key: String) -> CardCharacterDefinition:
	return characters().get(key)


## The characters' keys by their gate (World first).
static func characters_in_order() -> Array:
	var keys := characters().keys()
	keys.sort_custom(func(a, b): return characters()[a].gate < characters()[b].gate)
	return keys


static func card(key: String) -> CardDefinition:
	return cards().get(key)


static func enemy(key: String) -> CardEnemyDefinition:
	return enemies().get(key)


static func relic(key: String) -> CardRelicDefinition:
	return relics().get(key)


## The keys of the cards of `rarity` that can be won or bought (no starters, no Status cards): everybody's, and `character`'s own
## (none of another character's); a co-op card only when `together`.
static func cards_of(rarity: CardDefinition.Rarity, character: String = "", together: bool = false) -> Array:
	var found := []
	for key in cards():
		if cards()[key].rarity == rarity and offered_to(key, character, together):
			found.append(key)
	return found


## Whether card `key` may be won or bought by `character` (everybody's, or their own; a co-op card only `together`).
static func offered_to(key: String, character: String = "", together: bool = false) -> bool:
	var definition: CardDefinition = cards().get(key)
	return definition != null and definition.offered() and (definition.character == "" or definition.character == character) \
		and (together or not definition.coop_only)


## The keys of the boss encounters of layer `layer` (any layer's when it has none of its own).
static func bosses_of(layer: int) -> Array:
	var own := encounters_of(CardEncounterDefinition.Tier.BOSS).filter(func(key): return encounters()[key].layer == layer)
	return own if not own.is_empty() else encounters_of(CardEncounterDefinition.Tier.BOSS)


## The keys of the encounters of `tier` for layer `layer`: those written for any layer and those for it.
static func encounters_for(tier: CardEncounterDefinition.Tier, layer: int) -> Array:
	var found := encounters_of(tier).filter(func(key): return encounters()[key].layer == 0 or encounters()[key].layer == layer)
	return found if not found.is_empty() else encounters_of(tier)


## The keys of the encounters of `tier`.
static func encounters_of(tier: CardEncounterDefinition.Tier) -> Array:
	return encounters().keys().filter(func(key): return encounters()[key].tier == tier)


## Reads the folders again (for a suite, after writing to them).
static func reload():
	_read = false
	_read_all()
