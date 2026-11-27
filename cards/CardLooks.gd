extends Resource
class_name CardLooks
## The card game's pictures: data/card_looks.tres, edited in the inspector like the rest of its data (docs/card_game.md "Slots"; the
## designer, 2026-11-26: "Anything that uses music, sound or art, will be slots for me to fill in later"). Every one is a slot;
## while it is empty the game draws a stand-in of its own in code (CardIcon). A card's, an enemy's and a relic's own pictures are in
## their own files; its sounds and music are in audio/sound_bank.tres ("The card game").

const PATH := "res://data/card_looks.tres"

static var _looks: CardLooks = null

@export_group("Cards")
## The back of a card, seen in the piles, flying from the draw pile and as a reward is turned over. Drawn at 150 x 212.
@export var card_back: Texture2D
## Behind a card's words, by its type (stretched over the whole card, 150 x 212; the rarity's edge is drawn over it).
@export var card_face_attack: Texture2D
@export var card_face_skill: Texture2D
@export var card_face_power: Texture2D
## A Status card's (Wound, Dazed, Slimed, Burn: what enemies put in the player's piles).
@export var card_face_status: Texture2D
## A Tether's (twist 7), and the Message's own (twist 10).
@export var card_face_tether: Texture2D
@export var card_face_message: Texture2D

@export_group("A fight")
## Behind the whole fight (1280 x 680 or so, stretched).
@export var fight_background: Texture2D
## The player's own picture on their side (about 150 x 170). Empty: a plain stand-in.
@export var player_picture: Texture2D
## The energy orb (about 84 x 84), Block's shield (about 40 x 40).
@export var energy_orb: Texture2D
@export var block_shield: Texture2D
## An enemy's intent: an attack, a heavy one (12 or more), Block, growing stronger, putting a status on the player, and nothing
## known (about 40 x 40 each).
@export var intent_attack: Texture2D
@export var intent_attack_heavy: Texture2D
@export var intent_block: Texture2D
@export var intent_grow: Texture2D
@export var intent_curse: Texture2D
@export var intent_unknown: Texture2D
## And (2026-11-27, docs/proposals_2026-11-27_card_ai.md): asleep, curled up, helping an ally (Block or a status for them),
## mending, calling others in, putting a card in the player's piles, taking cards from their hand, and a countdown's mark.
@export var intent_asleep: Texture2D
@export var intent_curled: Texture2D
@export var intent_help: Texture2D
@export var intent_heal: Texture2D
@export var intent_summon: Texture2D
@export var intent_card: Texture2D
@export var intent_steal: Texture2D
@export var intent_countdown: Texture2D

@export_group("Statuses")
## Each status's badge (about 26 x 26). Empty: its first letter in a circle of its colour.
@export var status_might: Texture2D
@export var status_footing: Texture2D
@export var status_ward: Texture2D
@export var status_spines: Texture2D
@export var status_frenzy: Texture2D
@export var status_exposed: Texture2D
@export var status_weakened: Texture2D
@export var status_brittle: Texture2D
@export var status_poison: Texture2D
@export var status_entangled: Texture2D
@export var status_confused: Texture2D
## The enemies' traits (2026-11-27).
@export var status_enrage: Texture2D
@export var status_curiosity: Texture2D
@export var status_overtime: Texture2D
@export var status_toll: Texture2D
@export var status_reactive: Texture2D
@export var status_asleep: Texture2D
@export var status_mode_shift: Texture2D
@export var status_curled: Texture2D
@export var status_invincible: Texture2D
@export var status_command: Texture2D
@export var status_pack: Texture2D
@export var status_linked: Texture2D
@export var status_holding: Texture2D
@export var status_scanned: Texture2D
@export var status_glutton: Texture2D

@export_group("Hacking")
## An enemy's intent while it is encrypted (Scan it to see; about 44 x 44).
@export var intent_encrypted: Texture2D
## Behind the map on the second and third layers of a system (the first is Map Background; stretched).
@export var map_background_2: Texture2D
@export var map_background_3: Texture2D
## Over the whole screen, faintly: lines across it, as on an old monitor (tiled), and a glitch's torn bars (stretched, flashed).
@export var scanlines: Texture2D
@export var glitch_bars: Texture2D
## The trace meter's frame (about 260 x 22) and a code fragment found (about 64 x 64).
@export var trace_meter: Texture2D
@export var fragment: Texture2D
## A Tether held on the table (twist 7): its small card (about 70 x 54, its name and strength drawn over it), and the line drawn
## from its holder to whom it holds (stretched along, about 32 tall). An enemy's intent to tie one on you, and to cut yours.
@export var tether_card: Texture2D
@export var tether_thread: Texture2D
@export var intent_tether: Texture2D
@export var intent_cut: Texture2D
## The run's first choice, a Blessing (twist 15; about 120 x 120 each), and a word of the truth for the Message (twist 10; about
## 64 x 64).
@export var blessing: Texture2D
@export var message_word: Texture2D

@export_group("Blows and bits")
## A blow's slash across whoever it hits (drawn about 160 x 40, turned along the blow).
@export var hit_slash: Texture2D
## What flies: a spark off a blow, an ember off a card burning away, a drop of poison, a spike of Spines, a shard of broken Block,
## a coin (each small, about 8 to 16 across).
@export var spark: Texture2D
@export var ember: Texture2D
@export var drop: Texture2D
@export var spike: Texture2D
@export var shard: Texture2D
@export var coin: Texture2D

@export_group("The map and the rooms")
## Behind the map (stretched).
@export var map_background: Texture2D
## Each kind of room on the map (about 44 x 44; the boss's drawn bigger), and the marker of where the player is.
@export var room_fight: Texture2D
@export var room_elite: Texture2D
@export var room_rest: Texture2D
@export var room_shop: Texture2D
@export var room_event: Texture2D
@export var room_chest: Texture2D
@export var room_boss: Texture2D
@export var map_marker: Texture2D
## A rest's fire (about 120 x 140, flickered by the game), and the chest of a treasure room, shut and open (about 180 x 140).
@export var rest_fire: Texture2D
@export var chest_closed: Texture2D
@export var chest_open: Texture2D


## The looks, read once; a blank set (every stand-in) when the file is missing.
static func now() -> CardLooks:
	if _looks == null:
		_looks = load(PATH) as CardLooks if ResourceLoader.exists(PATH) else null
		if _looks == null:
			_looks = CardLooks.new()
	return _looks


## The picture in slot `slot` ("intent_block", "status_poison"...), or null.
static func picture(slot: StringName) -> Texture2D:
	var found = now().get(slot)
	return found as Texture2D if found is Texture2D else null
