extends RefCounted
class_name CardHack
## A hack played as the card game (the designer, 2026-11-27: "from now on this is the main hacking minigame"; Hacking.run makes one
## from a HackDefinition whose Minigame is Cards). It says how long the hack is, what is fought, who plays it, and how strong the
## hacker comes in; CardGame plays it over the world (CardGame.open_hack) and says how it went (CardGame.hack_done).

## How long a hack is: one fight; a short layer (SHORT_FLOORS floors and its boss); a whole layer (CardRun.FLOORS and its boss);
## the whole system (CardRun.MOST_LAYERS layers).
enum Length { FIGHT, SHORT, LAYER, FULL }
const SHORT_FLOORS := 6

var length: Length = Length.FIGHT
## For one fight: the encounter (data/card_encounters/ key), or "" for one of `tier` on `layer` at random.
var encounter := ""
var tier: CardEncounterDefinition.Tier = CardEncounterDefinition.Tier.EASY
## The layer of the system it is on (1 to 3): how hard and how dark its fights are.
var layer := 1
## Who plays it (data/card_characters/ keys): chosen on the screen when empty.
var characters: Array = []
var challenge := 0
var trace := 0
var seed := 0
## The players' health a share of their gate's (the hacker's Intellect: Hacking.health_share_for).
var health_share := 1.0
## How many play it on this screen: two when the main game has two players here (the designer, 2026-11-27: "During a dungeon or
## story mode, both players still get to play the hacking game together"); over a network both machines play it together anyway.
var players := 1


func one_fight() -> bool:
	return length == Length.FIGHT


func layers() -> int:
	return CardRun.MOST_LAYERS if length == Length.FULL else 1


func floors() -> int:
	match length:
		Length.SHORT:
			return SHORT_FLOORS
		Length.FIGHT:
			return 3
	return CardRun.FLOORS


## The encounter of a hack of one fight: its own, else one of its tier on its layer.
func encounter_key(rng: RandomNumberGenerator) -> String:
	if encounter != "" and CardDatabase.encounters().has(encounter):
		return encounter
	var pool := CardDatabase.bosses_of(layer) if tier == CardEncounterDefinition.Tier.BOSS else CardDatabase.encounters_for(tier, layer)
	return pool[rng.randi_range(0, pool.size() - 1)] if not pool.is_empty() else ""


static func length_name(of: Length) -> String:
	return ["One fight", "A short layer", "A layer", "The whole system"][of]
