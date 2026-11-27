extends Resource
class_name CardCharacterDefinition
## One of the hacking game's characters: a gate of Prometheus's (the designer, 2026-11-27: "The characters will be the ones
## mentioned in the gates (world, Hermes, pandora, yaldabaoth, etc) they'll be of equal power but different gameplay which will be
## unlocked throughout the game's progress"). One file in data/card_characters/, keyed by its file name; unlocked by finding the
## code fragments of its deck (CardUnlocks). Its own cards are those whose Character is its key; the rest are everybody's.

@export var name := ""
## The gate it is (Stats.GATE_NAMES' index: 1 World ... 10 Yaldabaoth): its order and its colour.
@export_range(1, 10) var gate := 1
## Its health as a run starts.
@export var health := 60
## The cards it starts with (data/cards/ keys).
@export var starting_deck: Array[String] = []
## Its first relic (data/card_relics/ key), or "".
@export var starting_relic := ""
## How it plays, in a line or two: what the character select says.
@export_multiline var playstyle := ""
## Code fragments of its deck to find before it can be played (CardUnlocks); 0: open from the start.
@export_range(0, 12) var fragments_needed := 3
## Its picture (a slot): none, and a stand-in in its gate's colour.
@export var picture: Texture2D


func colour() -> Color:
	return Stats.gate_colour(gate)
