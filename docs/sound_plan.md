# Sound plan

The designer's new sounds, in `audio/sfx/New folder/`, and where each would go. **Nothing is wired up
yet: this waits on the designer's go-ahead** (asked for 2026-11-05: "first tell me where you are
thinking of putting them"). This covers the 50 files in the folder at the time of writing.

These placements go by each file's name, length and loudness shape. Nobody has listened to them
while writing this, so some may turn out wrong.

A `_damage` sound would play as a blow lands (a move's Impact Sound), and an `_attack` sound as it is
cast (its Sound).

## Fights opening and closing

| Sound | Where |
| --- | --- |
| `bass_jump_start_drop` | "Conflict Endless", opening every fight |
| `bass_drop_and_downer_fast` | "Will Subdued", on a win |
| `bass_drop_and_downer_slow` | "Will Broken", on a loss |
| `bass_drop_and_downer_medium` | "They Got Away", and being caught on a stealth map |
| `bass_rattling` | A boss's reveal, under the silhouette, for any boss with no sound of its own |
| `erysichtonGrowl` | Erysichthon's reveal, and his phases beginning |
| `tiny_bells` | The Bellkeeper's reveal |
| `bass_tone_downer_reverb` | A boss going down |
| `flatline` | One of the party falling, with their name across the screen |
| `enemyDie` | Any enemy falling |

## Moves

| Sound | Moves |
| --- | --- |
| `weak_fire_damage` | Fire Burst, Flame Fan, Fire Blast, Kindled Bite, and Burn's tick |
| `medium_fire_damage` | Burner, Fire Breath, Flame Edge, Fireball, Wildfire, Tartarus Flame, Stolen Sun |
| `weak_ice_attack` | Frost Round, Frost Bottle |
| `medium_ice_attack` | Frost Edge, Frost Breath, Frozen River |
| `heavy_ice_attack` | Glacial Tide |
| `medium_water_damage` | Water Spike, River Flow |
| `weak_wind_damage` | Zephyr Dart, Wind Shot, Gust Blast, Wind Swoon, Wind Vacuum, Gale Bottle, and the movement spells now on Wind Howl (Mist Step, Hermes Step, Hover, Growth) |
| `heavy_electric_damage` | Lightning Bolt, Storm Cloud, Storm Edge, Lightning Breath, Ire of Sophia |
| `weak_idol_damage` | Votive Flame, Holy Splash, Holy Lance, Accusation, Holy Spear |
| `medium_idol_damage` | Piercing Light, Censure, Judgement Hammer |
| `strong_idol_damage` | Judgment, Divine Verdict, Revelation |
| `seismic_slam` | Ground Pound, Rockfall, Stone Edge |
| `metallic_scrape` | Sweep Strike, Chain Hook, Disarm |
| `cyrus_pistol` | Gun, Burning Shot, Combined Load, Corrosive Round, Frost Round's shot, Poison Dart, Venom Fan, Warning Shot, Venomous Shot |
| `rapier` | Rapier, Blink Strike, Follow Up Attack |
| `projectile` | Anything that flies with no travel sound of its own |
| `necromantic_scream` | Terror, Dread Breath, Ravenous Dark |
| `pandoras_laugh` | Dread Visage, Bewilder |
| `punchline` | Sass Club landing |

Frost Round appears twice on purpose: `cyrus_pistol` as he fires and `weak_ice_attack` as it lands.

## Hacks, puzzles and the world

| Sound | Where |
| --- | --- |
| `glitch_corrupted_data` | A hack failing or locking out, and InstaHack |
| `clock_sound` | A hack's clock running |
| `clock_sound_urgent` | A hack's last 10 seconds, and quick time events |
| `puzzle_success` | A picture's puzzle solved, a hack solved |
| `mechanism_interact` | A dial turned, a piece snapping in, using a lever |
| `mechanism_activation` | A door, strongbox or mechanism opening, a magic trap going off |
| `eerie_revelation_1` | A deduction made in the Journal |
| `eerie_revelation_2` | The ΛΗΘΗ unveiling on the Levels page |
| `sci-fi_ping_down` | Pings |

## Menus

| Sound | Where |
| --- | --- |
| `interface_interact` | Every menu button |
| `bag_open` | The inventory opening |
| `inventoryShuffle` | Moving an item, wearing gear, swapping containers |
| `rumage_through_suitcase` | Loot, Search the Fallen, Rummage, Steal (a slice, not all 8 seconds) |
| `coin` | Buying, selling, finding gold, Bribe |
| `flicking_through_pages` | The Journal or Codex opening |
| `turnPaper` | Turning a page in the Journal or the character sheet |
| `glossaryPage` | Opening a Glossary topic |

## Not placed: the designer's call

| Sound | Thoughts |
| --- | --- |
| `frog` | Nothing in the game is a frog yet. A joke in a picture, or a future familiar? |
| `train_passby` | No train in the game yet. An ambience on a city map, which needs a new "ambient sound" slot on maps? |
| `funny_boing_1`, `funny_boing_2` | Sass Club with `punchline`, a joke hotspot in a picture, or a Compel order to fall prone? |

## `audio/ambience/`

This folder appeared too: 39 long files, 3.0 GB. The game has no ambience slot yet, only music, so
these would need one: a looping sound on each map (`MapSetup`), under the music. Nothing here is placed.
Two are not ambience by their names: `weak_metal_damage` and `metal_scrape_low`, which would suit the
Metal element and heavy doors.

**These cannot go to GitHub as they are.** It refuses any file over 100 MB, and some of these are several
times that (`mall` runs over 11 minutes). They would have to be shortened into loops and converted first.

## What this leaves on old or stand-in sounds

The designer wants the old sounds gone, and these have nothing new yet:

- **Metal Strike:** Greatsword Attack, Light Swing, Shoving Strike, Shield Bash, Stunning Blow, Hamstring,
  Pin Down, Hurl, Battle Cry, Daunting Roar, Self Destruct, Savage Bite, Ravenous Bite, Rending Claws, Rib Maws.
- **Debris:** the four bombs, Crystal Bottle, Caucasus Shard, Crystalise, Rock Throw.
- **Small Gun Shot:** the enemy's Nail Projectile.
- **SciFi Water:** Devour.
- **Stand-ins drawn in code:** heals, misses, grazes, shatters, slams into walls, poison, acid and plasma,
  and the stealth map's heartbeat.

## Practical points

1. **Five files will not import.** `glossaryPage`, `projectile`, `punchline`, `sci-fi_ping_down` and
   `turnPaper` are plain 24-bit PCM with an extended header that Godot's importer skipped in the test
   harness. Rewriting the header fixes it without changing the audio, and re-exporting as ordinary PCM
   would too.
2. **Size.** The folder is 245 MB (mostly 96 kHz and 192 kHz, 24-bit), and `.git` is 85 MB today. In a
   build the import shrinks them. In the repository they stay full size, so there are two options:
   - Commit them as they are: simple, and every clone grows by about 245 MB.
   - Commit trimmed copies at 48 kHz, 16-bit, about 40 MB, and keep the originals out of git, as the
     music is. *Recommended.*
3. **Long tails.** The idol damage files run 15 to 17 seconds and `necromantic_scream` 27, with silence
   or long fades at the end. A blow's sound should be over by the next turn, so these would be cut
   with a quick fade once they have dropped by 20 dB: about 4 seconds for weak idol, 6 to 7 for medium
   and strong, 12 for the scream. The clocks would be cut to a short loop.
4. **Quiet ones.** `glossaryPage`, `flicking_through_pages`, `tiny_bells`, `turnPaper`, `weak_wind_damage` and
   `pandoras_laugh` peak at about -16 to -22 dB where the rest are near 0, so they would be raised to match.
5. **Names.** The project keeps files and folders in snake_case with no spaces, so these would move to
   `audio/sfx/fights/`, `moves/`, `world/` and `menus/`, with `enemyDie` becoming `enemy_die` and so on.
6. **New hooks.** Menus, hacks, quick times, doors, the store, the inventory and an enemy falling have
   no sound slot today, so each needs one, as a fillable slot like the rest.
