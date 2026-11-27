extends Resource
class_name CardDefinition
## A card of the card game (docs/card_game.md): one file in data/cards/, keyed by its file name. Its text is written from its
## effects, so changing a number in an effect changes what the card says.

enum Type {
	## Deals damage.
	ATTACK,
	## Everything else that is played and gone to the discard pile.
	SKILL,
	## Played once, and stays in effect for the rest of the fight: it leaves the deck for that fight.
	POWER,
	## Not the player's: put into their piles by enemies (Wound, Dazed, Slimed, Burn), never offered or sold, and gone when the
	## fight is (docs/proposals_2026-11-27_card_ai.md, item 14).
	STATUS,
	## Played onto its target, it stays on the table holding it (the designer's twist 7, 2026-11-27): at the end of each of its
	## holder's turns it does its Effects and frays by 1; at 0 it snaps and does its Snap Effects. Pressed, it is let go early (and
	## snaps). The same card played onto the same target again renews it. An enemy's (Enemy Only) is tied by its move (CardEnemyMove
	## Ties) and breaks as its holder is hurt (CardBattle.TETHER_BREAK_DAMAGE).
	TETHER,
}
enum Rarity { STARTER, COMMON, UNCOMMON, RARE }

## A number the fight has made higher than printed, and lower (describe's `marked`).
const HIGHER := Color("8fd6a0")
const LOWER := Color("e07a6a")
enum Target {
	## One enemy, chosen as it is played.
	ENEMY,
	## Every enemy.
	ALL_ENEMIES,
	## Nobody in particular (block, draw, the player's own statuses).
	NONE,
	## Your partner in co-op: its Block, mending, drawing, energy and statuses go to them (to yourself when you play alone).
	ALLY,
}

@export var name := ""
@export var type: Type = Type.ATTACK
@export var rarity: Rarity = Rarity.COMMON
## Energy to play it.
@export var cost := 1
## Its cost once upgraded; -1 keeps Cost.
@export var upgraded_cost := -1
@export var target: Target = Target.ENEMY
@export var effects: Array[CardEffect] = []
## Played, it is gone for the rest of the fight rather than going to the discard pile.
@export var exhausts := false
## It cannot be played (a Wound, a Dazed, a Burn).
@export var unplayable := false
## Still in the hand as the turn ends, it is exhausted rather than discarded (a Dazed).
@export var ethereal := false
## Still in the hand as the turn ends, it costs the player this much health (a Burn).
@export var burns := 0
## Whose card it is: a character's key (data/card_characters/), offered only to them; "" for everybody's.
@export var character := ""
## Offered only in co-op (a card for your partner).
@export var coop_only := false
## How loud it is: played, the system's trace rises this much (CardRun.trace, the designer's twist 3).
@export_range(0, 20) var trace := 0
## Its picture (a slot for the artist): none, and the card draws a stand-in in its type's colour.
@export var picture: Texture2D
## A line under its rules, in italics. Nothing to the rules.
@export_multiline var flavour := ""

@export_group("Tether")
## A Tether's strength: how many of its holder's turns it holds before it snaps (it frays by 1 at the end of each).
@export_range(1, 12) var tether_strength := 3
## Its strength once upgraded; -1 keeps Tether Strength.
@export var upgraded_tether_strength := -1
## What it does as it snaps: frayed through, or let go early (not when it is cut, broken or loose).
@export var snap_effects: Array[CardEffect] = []
## An enemy's Tether, tied by a move of theirs (CardEnemyMove.ties): never the player's to win, buy or be offered.
@export var enemy_only := false


func cost_for(upgraded: bool) -> int:
	return upgraded_cost if upgraded and upgraded_cost >= 0 else cost


func name_for(upgraded: bool) -> String:
	return name + ("+" if upgraded else "")


func type_name() -> String:
	return ["Attack", "Skill", "Power", "Status", "Tether"][type]


## Whether it can ever be won, bought or offered (no starters, no Status cards, no enemy's Tether).
func offered() -> bool:
	return rarity != Rarity.STARTER and type != Type.STATUS and not enemy_only


## A Tether's strength, upgraded or not.
func strength_for(upgraded: bool) -> int:
	return upgraded_tether_strength if upgraded and upgraded_tether_strength >= 0 else tether_strength


## Whether upgrading it changes anything (a card that cannot be upgraded further is still worth knowing about).
func upgrades() -> bool:
	if upgraded_cost >= 0 and upgraded_cost != cost:
		return true
	if type == Type.TETHER and upgraded_tether_strength >= 0 and upgraded_tether_strength != tether_strength:
		return true
	for effect in effects + snap_effects:
		if (effect.upgraded_amount >= 0 and effect.upgraded_amount != effect.amount) or (effect.upgraded_times >= 0 and effect.upgraded_times != effect.times):
			return true
	return false


## What it does, in words. `battle` and `who` (an enemy's index, or -1) work the numbers out as they stand in a fight: the
## player's Might and Footing, Weakened and Brittle on them, Exposed on the enemy pointed at. `marked` colours a number the fight
## has changed (BBCode, for a RichTextLabel): green when higher than printed, red when lower.
func describe(upgraded: bool, battle = null, who: int = -1, marked: bool = false, card_key: String = "", entry: Dictionary = {}) -> String:
	var lines: Array[String] = []
	var on_target := "every enemy" if target == Target.ALL_ENEMIES else "the enemy"
	var for_ally := target == Target.ALLY
	# Half-read code (twist 4): an effect struck out until the card has run once.
	var read := card_key == "" or is_read(card_key)
	if type == Type.TETHER:
		return _describe_tether(upgraded, battle, who, marked, read)
	for effect in effects:
		var amount := effect.amount_for(upgraded)
		var times := effect.times_for(upgraded)
		if effect.struck and not read:
			lines.append(STRUCK)
			continue
		var line := _effect_line(effect, amount, times, on_target, for_ally, battle, who, marked)
		if line != "":
			lines.append(line)
	# The Message (twist 10): the words the run has given it, each its own line; one struck out while there is room for more.
	if card_key == MESSAGE or entry.has("message"):
		var message: Dictionary = entry.get("message", {})
		var words: Array = message.get("words", [])
		var spoken: bool = battle != null and bool(battle.get("truth_spoken"))
		for word in words:
			var effect: CardEffect = word.get("effect")
			if effect == null:
				continue
			var said := _effect_line(effect, int(word.get("amount", effect.amount)), effect.times, on_target, false, battle, who, marked)
			if said != "":
				lines.append(said)
		if words.size() < MESSAGE_MOST_WORDS:
			lines.append(STRUCK)
		if spoken:
			lines.append("The truth spoken: every word twice.")
		lines.append("Never removed or rewritten.")
	if type == Type.POWER:
		lines.append("Lasts the whole fight.")
	if unplayable:
		lines.append("Cannot be played.")
	if burns > 0:
		lines.append("In your hand as your turn ends: lose %d health." % burns)
	if ethereal:
		lines.append("Ethereal: in your hand as your turn ends, it is exhausted.")
	if exhausts:
		lines.append("Exhaust.")
	return "\n".join(lines)


## What a half-read effect shows until the card has run once.
const STRUCK := "[s]#### ### ######[/s]"
## The Message (the designer's twist 10, 2026-11-27): the card in every deck that the run's events write into (CardRun), and how
## many words it can hold.
const MESSAGE := "the_message"
const MESSAGE_MOST_WORDS := 6
## An enemy's Tether on a player loses a strand for every this much health its holder loses (twist 7).
const TETHER_BREAK_DAMAGE := 6


## One effect of this card's kind in words, at `amount` (the Message's word, offered or grown).
func effect_words(effect: CardEffect, amount: int) -> String:
	return _effect_line(effect, amount, effect.times, "every enemy" if target == Target.ALL_ENEMIES else "the enemy", false, null, -1, false)


## One effect in words. `on_target` names whom it lands on ("the enemy", "every enemy"); `for_ally`: a card for the partner.
func _effect_line(effect: CardEffect, amount: int, times: int, on_target: String, for_ally: bool, battle, who: int, marked: bool) -> String:
	if for_ally:
		var for_partner := _for_partner(effect, amount)
		if for_partner != "":
			return for_partner
	match effect.kind:
		CardEffect.Kind.DAMAGE:
			var shown := amount
			if battle != null and not battle.players.is_empty():
				shown = battle.attack_damage(battle.player, battle.enemies[who] if who >= 0 and who < battle.enemies.size() else {}, amount)
			var each := "%s damage" % _number(shown, amount, marked)
			return "Deal %s%s%s." % [each, (" %d times" % times) if times > 1 else "", " to every enemy" if on_target == "every enemy" else ""]
		CardEffect.Kind.BLOCK:
			var shown_block := amount
			if battle != null and not battle.players.is_empty():
				shown_block = battle.block_gained(battle.player, amount)
			return "Gain %s Block." % _number(shown_block, amount, marked)
		CardEffect.Kind.DRAW:
			return "Draw %d card%s." % [amount, "" if amount == 1 else "s"]
		CardEffect.Kind.ENERGY:
			return "Gain %d energy." % amount
		CardEffect.Kind.APPLY:
			return "Give %s %d %s." % [on_target, amount, CardStatus.name_of(effect.status)]
		CardEffect.Kind.GAIN:
			return "Gain %d %s." % [amount, CardStatus.name_of(effect.status)]
		CardEffect.Kind.HEAL:
			return "Mend %d health." % amount
		CardEffect.Kind.LOSE_HP:
			return "Lose %d health." % amount
		CardEffect.Kind.MAX_HP:
			return "Gain %d most health." % amount
		CardEffect.Kind.GOLD:
			return "Gain %d gold." % amount
		CardEffect.Kind.DRAIN:
			return "Drain %d health from %s." % [amount, on_target]
	return ""


## A Tether's words: its strength, what it does each turn it holds, what it does as it snaps.
func _describe_tether(upgraded: bool, battle, who: int, marked: bool, read: bool) -> String:
	var lines: Array[String] = []
	var on := "the enemy"
	if enemy_only:
		on = "you"
	elif target == Target.ALLY:
		on = "your partner"
	elif target == Target.NONE:
		on = "you"
	lines.append("Tether, strength %d." % strength_for(upgraded))
	var each: Array[String] = []
	for effect in effects:
		if effect.struck and not read:
			each.append(STRUCK)
			continue
		each.append(_tether_line(effect, effect.amount_for(upgraded), effect.times_for(upgraded), on, battle, who, marked))
	if not each.is_empty():
		lines.append(("At the end of each of its turns: " if enemy_only else "At the end of each of your turns: ") + " ".join(each))
	var snaps: Array[String] = []
	for effect in snap_effects:
		snaps.append(_tether_line(effect, effect.amount_for(upgraded), effect.times_for(upgraded), on, battle, who, marked))
	if not snaps.is_empty():
		lines.append("As it snaps: " + " ".join(snaps))
	if enemy_only:
		lines.append("Every %d health its holder loses cuts a strand." % TETHER_BREAK_DAMAGE)
	else:
		lines.append("Frays by 1 each turn. Press it to let go early.")
	if exhausts:
		lines.append("Exhaust.")
	return "\n".join(lines)


## One effect of a Tether's, in words: what lands on whoever it holds (`on`), and what comes to its holder.
func _tether_line(effect: CardEffect, amount: int, times: int, on: String, battle, who: int, marked: bool) -> String:
	match effect.kind:
		CardEffect.Kind.DAMAGE:
			if enemy_only:
				return "You lose %d%s." % [amount, (" %d times" % times) if times > 1 else ""]
			return _effect_line(effect, amount, times, on, false, battle, who, marked)
		CardEffect.Kind.APPLY:
			return "Give %s %d %s." % [on, amount, CardStatus.name_of(effect.status)]
		CardEffect.Kind.DRAIN:
			if enemy_only:
				return "It drains %d of your health." % amount
			return "Drain %d health from %s." % [amount, on]
		CardEffect.Kind.BLOCK, CardEffect.Kind.HEAL, CardEffect.Kind.GAIN, CardEffect.Kind.DRAW, CardEffect.Kind.ENERGY:
			if on == "your partner":
				var partner := _for_partner(effect, amount)
				if partner != "":
					return partner
			return _effect_line(effect, amount, times, on, false, battle, who, marked)
	return _effect_line(effect, amount, times, on, false, battle, who, marked)


## Whether some of it is half-read (struck out until it has run).
func half_read() -> bool:
	return effects.any(func(effect): return effect != null and effect.struck)


## Whether card `key`'s half-read words have been read (CardUnlocks.read, which writes it). Read from Campaign by its path, so this
## class leans on no database and a tool run with --script can still save cards.
static func is_read(key: String) -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var campaign = tree.root.get_node_or_null("/root/Campaign") if tree != null else null
	return campaign != null and campaign.flag("card_read:%s" % key)


## An effect aimed at your partner, in words ("" when it is not one that goes to them).
static func _for_partner(effect: CardEffect, amount: int) -> String:
	match effect.kind:
		CardEffect.Kind.BLOCK:
			return "Your partner gains %d Block." % amount
		CardEffect.Kind.HEAL:
			return "Your partner mends %d health." % amount
		CardEffect.Kind.DRAW:
			return "Your partner draws %d card%s." % [amount, "" if amount == 1 else "s"]
		CardEffect.Kind.ENERGY:
			return "Your partner gains %d energy." % amount
		CardEffect.Kind.GAIN:
			return "Your partner gains %d %s." % [amount, CardStatus.name_of(effect.status)]
	return ""


## A number as a card shows it: coloured (`marked`) when the fight has made it higher or lower than `printed`.
static func _number(shown: int, printed: int, marked: bool) -> String:
	if not marked or shown == printed:
		return str(shown)
	return "[color=#%s]%d[/color]" % [(HIGHER if shown > printed else LOWER).to_html(false), shown]
