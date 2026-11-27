extends Resource
class_name CardEncounterDefinition
## Who a fight of the card game is against: one file in data/card_encounters/ (docs/card_game.md).

enum Tier {
	## The run's first fights.
	EASY,
	## Its later ones.
	HARD,
	## An elite's room: tougher, and a relic for winning.
	ELITE,
	## The end of the run.
	BOSS,
}

@export var tier: Tier = Tier.EASY
## The enemies, by their file names in data/card_enemies/, left to right.
@export var enemies: Array[String] = []
## The layer of the system it belongs to (1, 2, 3: the twist "down through a system's layers"), played as written there; 0 for any
## layer, made harder the deeper it is (CardBattle.LAYER_HEALTH, LAYER_MIGHT). A boss is its layer's.
@export_range(0, 3) var layer := 0
