extends RefCounted
class_name CardUnlocks
## What the hacking game has been opened up by: the code fragments of each gate's deck found so far, and so which characters can
## be played (the designer, 2026-11-27, twist 4: "This can also be how the decks are acquired, by getting fragments of a code"), and
## the half-read cards (CardEffect.struck) read once. Kept in Campaign's flags, so a save keeps them.
##
## A fragment is found by a conversation or a pickup (`do Hacking.find_fragment("hermes")`), by a hack that gives one
## (HackDefinition.fragment_of), or by a Memento in a run (an event's Fragment).

const FRAGMENTS := "card_fragments:%s"
const READ := "card_read:%s"
## For a suite or a demo: every character open whatever has been found.
static var all_open := false


static func _campaign() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("/root/Campaign") if tree != null else null


## The fragments of `character`'s deck found so far.
static func fragments(character: String) -> int:
	var campaign := _campaign()
	return int(campaign.flags.get(FRAGMENTS % character, 0)) if campaign != null else 0


## One more fragment of `character`'s deck found. True if that one opened it.
static func add_fragment(character: String) -> bool:
	var campaign := _campaign()
	var definition := CardDatabase.character(character)
	if campaign == null or definition == null:
		return false
	var was := unlocked(character)
	campaign.set_flag(FRAGMENTS % character, mini(fragments(character) + 1, maxi(definition.fragments_needed, 1)))
	return not was and unlocked(character)


## Whether `character` can be played: all its fragments found (or none needed).
static func unlocked(character: String) -> bool:
	var definition := CardDatabase.character(character)
	if definition == null:
		return false
	return all_open or definition.fragments_needed <= 0 or fragments(character) >= definition.fragments_needed


## The characters that can be played, by gate.
static func unlocked_keys() -> Array:
	return CardDatabase.characters_in_order().filter(func(key): return unlocked(key))


## A character still locked, the one nearest to opening (fewest fragments left), or "" when all are open: where a Memento's
## fragment goes.
static func nearest_locked() -> String:
	var best := ""
	var best_left := 999
	for key in CardDatabase.characters_in_order():
		if unlocked(key):
			continue
		var left: int = CardDatabase.character(key).fragments_needed - fragments(key)
		if left < best_left:
			best_left = left
			best = key
	return best


## Whether card `key`'s half-read words have been read (it has been played once, in any run).
static func read(key: String) -> bool:
	var campaign := _campaign()
	return campaign != null and campaign.flag(READ % key)


static func mark_read(key: String):
	var campaign := _campaign()
	if campaign != null:
		campaign.set_flag(READ % key)
