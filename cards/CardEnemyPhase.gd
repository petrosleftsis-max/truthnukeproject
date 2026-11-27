extends Resource
class_name CardEnemyPhase
## A phase of a card game enemy's (docs/card_game.md "How enemies choose"): once its health falls under Health Under percent of
## its most, it starts, once a fight: it says its Line, takes its statuses and Block, may throw off what harms it, and from its next
## choice fights with these moves, pattern and rules. Or it splits into others and is gone.

## Its health under this percent of its most starts it.
@export_range(1, 99) var health_under := 50
## What it says as the phase starts (shown over it). Empty: nothing.
@export var line := ""
## Its moves from now on; empty keeps the ones it has.
@export var moves: Array[CardEnemyMove] = []
## How it chooses among them (with Moves set).
@export var pattern: CardEnemyDefinition.Pattern = CardEnemyDefinition.Pattern.CYCLE
## Its rules from now on, in place of the ones before; empty keeps them.
@export var rules: Array[CardEnemyRule] = []
## Statuses it takes as the phase starts (CardStatus keys -> amounts).
@export var statuses := {}
## Block it gains as the phase starts.
@export var block := 0
## It throws off every harmful status as the phase starts.
@export var clears_harm := false
## It splits into these (data/card_enemies/ keys), each with as much health as it has left (no more than their own most), and is
## gone. Empty: no split.
@export var splits_into: Array[String] = []
