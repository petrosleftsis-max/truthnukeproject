@icon("res://art/editor_icons/sound_bank.svg")
extends Resource
class_name SoundBank
## The sounds that belong to no one move: audio/sound_bank.tres, played through GameSounds.
## Every slot can be filled or changed here, and an empty one is silent, or falls back on a
## stand-in where the game has always had one. A move's own sounds are on the move, and a
## picture's in pictures/feedback.tres.

@export_group("Fights opening and closing")
## "Conflict Endless", unless the encounter's Card Sound says otherwise.
@export var card_opening: AudioStream
## "Will Subdued".
@export var card_victory: AudioStream
## "Will Broken".
@export var card_defeat: AudioStream
## "They Got Away" and "Nobody Stands".
@export var card_fled: AudioStream
## A boss lighting up in its reveal, for a boss with no Reveal Sound of its own.
@export var boss_reveal: AudioStream

@export_group("Falling")
@export var boss_falls: AudioStream
## One of the party, as their name comes across the screen.
@export var party_falls: AudioStream
@export var enemy_falls: AudioStream

@export_group("Moves")
## What flies, for a move with no Travel Sound of its own.
@export var travel: AudioStream
## Something of the map breaking in a fight: a barrel, a crate - whatever the TileSet gives Health (Combat "Things that break").
## Empty: a stand-in.
@export var thing_breaks: AudioStream

@export_group("The day")
## Looped outdoors, each at its hour (LightView). An empty one is silence, as all of these are until there is a sound for it.
@export var birds_at_dawn: AudioStream
@export var insects_at_dusk: AudioStream
@export var crickets_at_night: AudioStream
@export var rain_falling: AudioStream
## Looped while the wind blows hard (a wind, a sandstorm, a blizzard).
@export var wind_blowing: AudioStream
## After a storm's flash of lightning.
@export var thunder: AudioStream

@export_group("Steps")
## A step on the ground, and on wet ground in the rain, which is louder (Footsteps). Empty: a stand-in, made on the spot.
@export var footstep: AudioStream
@export var footstep_wet: AudioStream

@export_group("The character sheet")
## The first time a kind of creature's sheet shows it studied, as what it is comes up (CharacterSheet "A new kind, studied").
## Empty: a stand-in, made on the spot.
@export var codex_reveal: AudioStream

@export_group("Hacks and the world")
@export var hack_failed: AudioStream
## Looped while a hack's clock runs.
@export var hack_clock: AudioStream
## Looped for a hack's last seconds, and through a quick time.
@export var hack_clock_urgent: AudioStream
## A hack solved. A picture's puzzle has its own slot in pictures/feedback.tres.
@export var solved: AudioStream
## Using something on the map: a lever, a Use on a thing in a fight.
@export var mechanism_used: AudioStream
## A door, a strongbox or a mechanism opening, a magic trap going off.
@export var mechanism_opened: AudioStream
## Caught on a stealth map, for a map with no Caught Sound of its own.
@export var caught: AudioStream
## The Levels page unveiling what lies past ΛΗΘΗ.
@export var levels_unveiled: AudioStream

@export_group("On a map")
## A door swinging open or shut, and coming to rest shut (StealthDoor). Empty: a stand-in, made on the spot, as all of these are.
@export var door_creak: AudioStream
@export var door_shut: AudioStream
## Something taken from where it lay, as it lands in the bag (StealthPickup).
@export var picked_up: AudioStream
## A lamp put out.
@export var lamp_out: AudioStream
## A breakable wall coming down.
@export var wall_breaks: AudioStream
## Something landing in water.
@export var water_splash: AudioStream
## A soft tick as a line of a conversation types out, pitched for who speaks (DialogueBalloon).
@export var voice_tick: AudioStream
## A button refused: something that cannot be done just now.
@export var refused: AudioStream
## The place's own bed, looping quietly under everything (SoundFollows): a room's hush indoors, drips underground. Out of doors the
## day's own sound plays. Empty: silence, not a stand-in.
@export var indoors: AudioStream
@export var underground: AudioStream
## A low pulse under the music while a watched map is on edge, faster when Alarmed (SoundFollows). Empty: a stand-in heartbeat.
@export var danger: AudioStream
## A guard's step, heard from where they walk while near (Footsteps "A guard heard before seen"). Empty: a stand-in.
@export var guard_step: AudioStream
## A takedown landing: a muffled thump (StealthWatch "A takedown that lands"). Empty: a stand-in.
@export var takedown: AudioStream
## Something thrown landing, and skittering (StealthWatch "A thrown thing flies"). Empty: a stand-in.
@export var clatter: AudioStream
## A hiding spot stirred by somebody going in or out: a bush's rustle, and the creak of anything else (HidingSpot). Empty: stand-ins.
@export var rustle: AudioStream
@export var creak: AudioStream
## A body dragged along the ground, a moment of it a step (StealthWatch "A body dragged"). Empty: a stand-in.
@export var body_drag: AudioStream

@export_group("Wandering")
## The proposals of 2026-11-19, sections 2 and 3. Empty: a stand-in each. A secret found; a mark that only the dark or a light shows,
## seen; a rest taken at a rest spot; a journey by Iris's rainbow; a foe on the roam that has seen the party; a climb up onto raised
## ground; a room of the archive changing out of sight; the dream-place opening; something forgotten to Lethe; a gate's voice.
@export var secret_found: AudioStream
@export var mark_seen: AudioStream
@export var rest: AudioStream
@export var rainbow: AudioStream
@export var roamer_sees: AudioStream
@export var climb: AudioStream
@export var shift: AudioStream
@export var dream: AudioStream
@export var lethe: AudioStream
@export var gate_voice: AudioStream
## Beds of sound for a place (SoundArea): wind out in the open, a city's murmur, drips underground, the dream's own. Looped quietly.
@export var ambience_wind: AudioStream
@export var ambience_city: AudioStream
@export var ambience_drips: AudioStream
@export var ambience_dream: AudioStream
## Steps by what is underfoot (SoundArea's surface): stone, wood, grass. Water's is step_wet.
@export var step_stone: AudioStream
@export var step_wood: AudioStream
@export var step_grass: AudioStream

@export_group("Voices in a fight")
## One of each for everybody, pitched for who it is as their voice ticks are (SoundFollows.voice_pitch): an effort with a blow
## they throw, a cry when they are hurt, a breath when they are healed. A creature's own (CombatantDefinition's Voice) is played in
## its place, as it is. Empty: silence, not a stand-in.
@export var voice_effort: AudioStream
@export var voice_hurt: AudioStream
@export var voice_healed: AudioStream

@export_group("Menus")
## Every button there is, but those that say otherwise (GameSounds.quiet).
@export var menu_press: AudioStream
@export var ping: AudioStream
@export var bag_open: AudioStream
## Moving something in the bags, wearing something, swapping containers.
@export var item_moved: AudioStream
## Looting, Rummaging, Stealing: a slice of it, at a random place.
@export var rummage: AudioStream
## Buying, selling, gold found.
@export var coin: AudioStream
## A page turned in the sheet or the Glossary. The Journal's is in pictures/feedback.tres.
@export var page: AudioStream
## A spell learned from a book.
@export var learned_spell: AudioStream

@export_group("The card game")
## The card game's own (docs/card_game.md "Slots"; the designer, 2026-11-26: every sound a slot to fill). Empty: a stand-in each
## (PlaceholderSounds), but the fire's crackle, a loop, silent until filled.
## A card: drawn (played a little higher each card of a hand), shuffled in, swept to the discard pile, burnt away as it exhausts.
@export var card_drawn: AudioStream
@export var card_shuffled: AudioStream
@export var card_discarded: AudioStream
@export var card_exhausted: AudioStream
## A card played, by its type.
@export var card_played_attack: AudioStream
@export var card_played_skill: AudioStream
@export var card_played_power: AudioStream
## The pointer coming onto a card of the hand.
@export var card_hover: AudioStream
## A blow landing, and a heavy one (a quarter of somebody's health or more, or the last); played higher each hit of a flurry.
@export var card_hit: AudioStream
@export var card_hit_heavy: AudioStream
## Block gained, struck, and broken by a hit.
@export var card_block_gained: AudioStream
@export var card_block_struck: AudioStream
@export var card_block_broken: AudioStream
## A status put on: a good one, a bad one. Poison biting, Spines biting back, health mended.
@export var card_status_good: AudioStream
@export var card_status_bad: AudioStream
@export var card_poison: AudioStream
@export var card_spines: AudioStream
@export var card_mend: AudioStream
## Energy filling at the start of a turn.
@export var card_energy_filled: AudioStream
## An enemy falling.
@export var card_enemy_falls: AudioStream
## How enemies choose and their traits (2026-11-27, docs/proposals_2026-11-27_card_ai.md): one waking, a countdown ticking, one
## curling up, a phase beginning, a card put in your deck, cards taken from your hand, one called or split into the fight, one of
## the Linked rising again, and Overtime ending your turn.
@export var card_woke: AudioStream
@export var card_countdown: AudioStream
@export var card_curled: AudioStream
@export var card_phase: AudioStream
@export var card_junk: AudioStream
@export var card_stolen: AudioStream
@export var card_summoned: AudioStream
@export var card_rose: AudioStream
@export var card_overtime: AudioStream
## Prometheus's hacking (2026-11-27, the designer's twists and juice): a terminal's beep (a room entered, a choice made), a card's
## code typing across as it is played (each few letters), a hit tearing the picture, an enemy decrypted (Scanned), the Devourer
## choking, the trace rising, and a code fragment found.
@export var card_terminal_beep: AudioStream
@export var card_code_tick: AudioStream
@export var card_glitch: AudioStream
@export var card_scanned: AudioStream
@export var card_choked: AudioStream
@export var card_trace_rose: AudioStream
@export var card_fragment: AudioStream
## The designer's "try them all" (2026-11-27): a Tether tied, fraying, snapping and cut (twist 7); the Message given a word, and
## spoken whole at the last boss (twist 10); a Blessing chosen (twist 15).
@export var card_tether_tied: AudioStream
@export var card_tether_frayed: AudioStream
@export var card_tether_snapped: AudioStream
@export var card_tether_cut: AudioStream
@export var card_message_grows: AudioStream
@export var card_truth_spoken: AudioStream
@export var card_blessing: AudioStream
## End Turn pressed, "Your Turn", "Enemy Turn".
@export var card_end_turn: AudioStream
@export var card_your_turn: AudioStream
@export var card_enemy_turn: AudioStream
## A fight beginning, an elite and the boss coming in (with their names), a fight won, a fight lost.
@export var card_fight_begins: AudioStream
@export var card_elite_arrives: AudioStream
@export var card_boss_arrives: AudioStream
@export var card_fight_won: AudioStream
@export var card_fight_lost: AudioStream
## A reward card turned over, a rare one; a card taken into the deck.
@export var card_reward_turned: AudioStream
@export var card_reward_rare: AudioStream
@export var card_taken: AudioStream
## Gold coming in (a tick a coin), gold paid out.
@export var card_gold: AudioStream
@export var card_gold_spent: AudioStream
## A relic gained, and one doing its thing.
@export var card_relic_gained: AudioStream
@export var card_relic_used: AudioStream
## A step along the map, going into a room, a chest opened, a card upgraded, a card taken out of the deck.
@export var card_map_step: AudioStream
@export var card_room_entered: AudioStream
@export var card_chest_opened: AudioStream
@export var card_upgraded: AudioStream
@export var card_removed: AudioStream
## An event's text typing out, a tick every other letter.
@export var card_text_tick: AudioStream
## The fire at a rest, looped while there. Silent until filled.
@export var card_rest_fire: AudioStream
## The card game's music: on the map, in a fight, against an elite, against the boss. Empty: whatever was playing carries on.
@export var card_music_map: AudioStream
@export var card_music_fight: AudioStream
@export var card_music_elite: AudioStream
@export var card_music_boss: AudioStream
