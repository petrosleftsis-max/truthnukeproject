extends Resource
class_name CardEnemyDefinition
## An enemy of the card game: one file in data/card_enemies/, keyed by its file name (docs/card_game.md). How it chooses: its rules
## first (CardEnemyRule), then an opening move, then its pattern, each move within its own limits (CardEnemyMove); its phases
## (CardEnemyPhase) change all of that as its health falls. Its traits are statuses it starts with (CardStatus: Enrage, Asleep,
## Mode Shift, Linked...).

enum Pattern {
	## Its moves in order, round and round.
	CYCLE,
	## A move at random by Weight, never the same one three times running.
	RANDOM,
}
## What the player sees of what it will do.
enum Shows {
	## Its intent, as every enemy.
	INTENT,
	## Nothing: a question mark, all fight.
	NOTHING,
	## Nothing until it is hit, each time it chooses anew.
	ONCE_HIT,
}

@export var name := ""
## Its health, somewhere between these two each fight.
@export var max_hp_least := 10
@export var max_hp_most := 12
@export var moves: Array[CardEnemyMove] = []
@export var pattern: Pattern = Pattern.RANDOM
## Statuses it starts every fight with (CardStatus keys -> amounts): its traits among them (Enrage, Asleep, Mode Shift...).
@export var starting_statuses := {}
## Its picture (a slot): none, and the portrait of the main game's combatant named in Borrow Picture From, if any.
@export var picture: Texture2D
@export var borrow_picture_from := ""

@export_group("How it chooses")
## Checked in order each time it chooses, before its pattern (CardEnemyRule).
@export var rules: Array[CardEnemyRule] = []
## Each starts once, as its health falls under its share (CardEnemyPhase).
@export var phases: Array[CardEnemyPhase] = []
## What the player sees of what it will do.
@export var shows: Shows = Shows.INTENT

@export_group("Asleep and curled up")
## Block it gains each turn it sleeps (Asleep).
@export var sleep_block := 0
## Mode Shift curling it up: the Block it gains as it curls (and again each turn curled), the Spines it has while curled, how many
## of its turns it stays curled, and how much more health the next curl takes.
@export var curl_block := 20
@export var curl_spines := 3
@export var curl_turns := 2
@export var curl_grows := 10


func picture_now() -> Texture2D:
	if picture != null:
		return picture
	if borrow_picture_from != "":
		var tree := Engine.get_main_loop() as SceneTree
		var combatants = tree.root.get_node_or_null("/root/CombatantDatabase") if tree != null else null
		if combatants != null and combatants.combatants.has(borrow_picture_from):
			return combatants.combatants[borrow_picture_from].portrait()
	return null


## Its move called `move_name` (among `among`, else its own), or null.
func move_named(move_name: String, among: Array = []) -> CardEnemyMove:
	for move in (among if not among.is_empty() else moves):
		if move != null and move.name == move_name:
			return move
	return null
