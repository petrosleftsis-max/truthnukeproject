# Sound plan

What is heard where. The designer listened to the plan and gave the go-ahead on 2026-11-06, with the
changes written in here. **All of it is built.** The sounds are placeholders behind fillable slots:
a move's Sound, Impact Sound and Travel Sound, a condition's Tick Sound, a boss's Reveal Sound, Second
Reveal Sound and Phase Sound, an Interactable's Use Sound, `pictures/feedback.tres`, and
`audio/sound_bank.tres` for everything else (`SoundBank`, played through `GameSounds`).

## Where the files are

- **The designer's originals are not on GitHub.** The designer keeps them on their own drive, so the
  repository stays small. The Git-ignored folders are `audio/sfx/New folder/` (the originals),
  `audio/sfx/fights/`, `moves/`, `world/`, `menus/` (the copies the game uses) and `audio/ambience/`.
  The `.import` files are tracked, since they say how each sound is imported.
- **On another machine:** fetch the originals into `audio/sfx/New folder/`, then run this from the
  project folder. `tools/sfx_list.txt` says what goes where.

  ```bash
  powershell -ExecutionPolicy Bypass -File tools/place_sfx.ps1
  ```

- **A clone without the sounds plays on in silence.** Moves load without them
  (`SkillDatabase._carry_on_without_them`).
- **Nothing is converted.** Godot compresses a sound in the exported game anyway. The only change to a
  file is the extended WAV header on five of them, whose format tag is set to plain PCM. Godot refuses
  the extended header, and no sample changes.
- **Import settings do the rest:** `edit/trim` cuts silence at both ends, except the clocks, which
  loop on their beat. `edit/normalize` raises the quiet ones: `tiny_bells`, `weak_wind_damage`,
  `flicking_through_pages`, `turn_paper` and `glossary_page`. A sound may outlast its move. Change
  either setting in the editor's Import dock.

A `_damage` sound plays as a blow lands (a move's Impact Sound). An `_attack` sound plays as it is cast
(its Sound).

## Fights opening and closing

| Sound | Where |
| --- | --- |
| `bass_jump_start_drop` | "Conflict Endless", opening every fight |
| `bass_drop_and_downer_fast` | "Will Subdued", on a win |
| `bass_drop_and_downer_slow` | "Will Broken", on a loss |
| `bass_drop_and_downer_medium` | "They Got Away", and being caught on a stealth map |
| `bass_rattling` | A boss's reveal, under the silhouette, for any boss with no sound of its own |
| `erysichthon_growl` and `eerie_revelation_2` | Erysichthon's reveal; the growl again as a phase begins |
| `tiny_bells` | The Bellkeeper's reveal |
| `bass_tone_downer_reverb` | A boss going down |
| `flatline` | One of the party falling |
| `enemy_die` | Any enemy falling |

## Moves

| Sound | Moves |
| --- | --- |
| `weak_fire_damage` | Fire Burst, Flame Fan, Fire Blast, Kindled Bite, Burn Bottle, Flammable Limb, Trailblaze, and Burn's tick |
| `medium_fire_damage` | Burner, Fire Breath, Flame Edge, Wildfire, Tartarus Flame, Stolen Sun |
| `weak_ice_attack` | Frost Round, Frost Bottle |
| `medium_ice_attack` | Frost Edge, Frost Breath, Frozen River |
| `heavy_ice_attack` | Glacial Tide |
| `medium_water_damage` | Water Spike, River Flow |
| `weak_wind_damage` | Zephyr Dart, Wind Shot, Gust Blast, Wind Swoon, Wind Vacuum, Gale Bottle; as cast, Mist Step, Hermes Step, Hover, Growth |
| `heavy_electric_damage` | Lightning Bolt, Storm Cloud, Storm Edge, Lightning Breath, Ire of Sophia, Gnostic Tempest |
| `weak_idol_damage` | Votive Flame, Holy Splash, Holy Lance, Accusation, Holy Spear |
| `medium_idol_damage` | Piercing Light, Censure, Judgement Hammer |
| `heavy_idol_damage` | Judgment, Divine Verdict, Revelation |
| `seismic_slam` | Ground Pound, Rockfall, Stone Edge |
| `cyrus_pistol` | Gun, Burning Shot, Combined Load, Corrosive Round, Frost Round's shot, Poison Dart, Venom Fan, Warning Shot, Venomous Shot |
| `rapier` | Rapier, Blink Strike, Follow Up Attack |
| `projectile` | Anything that flies with no travel sound of its own |
| `flicking_through_pages` | Prometheus's Study |
| `turn_paper` | Prometheus learning a spell from a book |

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

## Menus

| Sound | Where |
| --- | --- |
| `interface_interact` | Every menu button |
| `ping_down` | Pings |
| `bag_open` | The inventory opening |
| `inventory_shuffle` | Moving an item, wearing gear, swapping containers |
| `rummage_through_suitcase` | Loot, Search the Fallen, Rummage, Steal (the first 1.6 seconds) |
| `coin` | Buying, selling, finding gold, Bribe |
| `glossary_page` | Every page in a menu: the Journal, the character sheet, the Glossary |

## Not used, on the designer's word

`metallic_scrape`, `necromantic_scream`, `pandoras_laugh`, `punchline`.

## Waiting

- **A "sword" sound from the designer:** it goes on what `metallic_scrape` would have been on: Sweep
  Strike, Chain Hook, Disarm. They keep Metal Strike until then.
- **Not placed, not answered yet:** `frog`, `train_passby`, `funny_boing_1`, `funny_boing_2`.
- **`audio/ambience/`:** 39 long files, not used. The game has no ambience slot, only music.

## What is still on old or stand-in sounds

- **Metal Strike:** Greatsword Attack, Light Swing, Shoving Strike, Shield Bash, Stunning Blow, Hamstring,
  Pin Down, Hurl, Battle Cry, Daunting Roar, Self Destruct, Savage Bite, Ravenous Bite, Rending Claws, Rib Maws.
- **Debris:** the four bombs, Crystal Bottle, Caucasus Shard, Crystalise, Rock Throw.
- **Small Gun Shot:** the enemy's Nail Projectile.
- **SciFi Water:** Devour.
- **Stand-ins drawn in code:** heals, misses, grazes, shatters, slams into walls, poison, acid and plasma,
  mind spells, and the stealth map's heartbeat.

## The day's sounds (2026-11-07)

Empty slots in the SoundBank's "The day" group, looped outdoors each at its hour by `LightView` (silence until filled): `birds_at_dawn`, `insects_at_dusk`, `crickets_at_night`, `rain_falling`.

## The weather's sounds and the steps (2026-11-07)

More empty slots: `wind_blowing` (looped while a wind, a sandstorm or a blizzard blows), `thunder` (after a storm's flash of
lightning), and the SoundBank's "Steps" group, `footstep` and `footstep_wet` (Footsteps: a step on dry ground, and a louder,
splashing one in the rain under the open sky). The steps have generated stand-ins (PlaceholderSounds "step" and "step_wet")
until there is a sound in the slot; the wind and the thunder are silence until then.

## The reveal, lightning, and every slot at once (2026-11-12)

`codex_reveal` (the SoundBank's "The character sheet" group): the first time the sheet shows a kind of creature studied, as what it is
comes up. A stand-in (PlaceholderSounds "reveal", three rising notes) until filled. `thunder` now also follows lightning striking the
field in a thunderstorm (a hazard), right after its flash. `docs/sound_slots.md` lists every slot the game has - the bank, the
pictures, the conditions that tick, and each move's launch, travel and impact - with what is in it: yours, a stand-in, or silence.
Run `perl` on the script named at its top to make it again after placing sounds.
