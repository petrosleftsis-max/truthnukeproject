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
