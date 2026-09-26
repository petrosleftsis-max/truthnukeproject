# Messengers of Truth

A turn-based tactical RPG in Godot 4.7: a party of characters, a grid, and
fights you win by positioning as much as by damage. Between fights there is a
map to walk around, people to talk to, and doors that stay shut until you have
found what opens them.

## Running it

Open the project in Godot 4.7 or later and press F5. The game starts on the
main menu.

* **Play** — four ways in: an introduction and tutorial, an intermediate
  fight, a hard one, and a narrative scene from later in the story.
* **Battle Select** — every encounter, playable directly, with the party you
  have left from the last one. *Reset party* puts everyone back on their feet.
* **Options** — window size, separate volume for music and sound effects,
  and how fast enemy turns play (also in the pause menu).

To work on one battle, open `scenes/game.tscn` and press F6; it plays whichever
encounter its **Fallback Encounter** names.

In a battle: **Space** ends the turn, **1-9** pick a skill, **Tab** moves to the
next skill tab, **Backspace** takes a walk back, **C** opens the character
sheet and **Esc** the menu. Hold **Shift** to see every tile an enemy could
reach and hit next turn, and which tiles set off a reaction when you step out
of them. Hover anyone on the map, or a face in the turn queue, to see who they
are; click a face to find them. A greyed-out skill can still be pressed to see
its reach, its area and what it would do - including a teammate's, from their
portrait - without using it. While a skill is aimed, a portrait or a face in
the queue can be clicked in place of the person on the map; hovering one that
it cannot be used on says why. A click outside the blue reach, on the map or a
face, does nothing and aiming carries on.

## The shape of it

Everything a designer sets lives in resources and scenes, not in code. Adding a
character, a skill, a fight or a conversation needs no scripting.

| What | Where | Edited as |
| --- | --- | --- |
| Characters | `databases/combatant_database.tscn` | a dictionary of key → CombatantDefinition |
| Skills | `databases/skill_database.tscn` | a dictionary of key → SkillDefinition |
| Passive skills | `passives/*.tres` | a PassiveDefinition, listed under a character's **Passives** |
| Fights | `encounters/*.tres` | an EncounterDefinition: a map, who starts where, and the music |
| Maps | `scenes/*_terrain.tscn` | a TileMap; tile data says what blocks whom and what it costs to cross |
| Conditions | `conditions/*.tres` | poisons, stuns, buffs and what they do |
| Conversations | `Dialogue/*.dialogue` | Dialogue Manager scripts |

Both databases are autoloads, so `SkillDatabase.skills["fireball"]` and
`CombatantDatabase.combatants["cyrus"]` work from anywhere.

### Adding a skill

1. Right-click `skills/` → **New Resource** → `SkillDefinition`, and fill it in.
   Damage lives on the skill itself, under **Power**: whether it deals damage,
   how hard, which attribute it scales from, and of what element. **Effects** is
   for everything else it does - a condition, a heal, a shove, a lingering
   wound.
2. Add it to **Skills** in `databases/skill_database.tscn` under a short key.
3. Add that key to whichever characters know it, in their **Skills** list.

A combatant knows exactly what their database entry lists, and nothing else.

### Adding a passive skill

A passive is something a character does without pressing anything, so it never
appears on the action panel - the character sheet lists it under **Passive
Skills** instead, name and description written out in full.

1. Right-click `passives/` → **New Resource** → `PassiveDefinition`. Give it a
   name and a description, and choose **Active When**: always, or only once
   its condition holds.
2. Under **What it does**, switch on what it grants.
3. Add it to the character's **Passives** list in
   `databases/combatant_database.tscn`.

The Mimic's `passives/mimicry.tres` is the example: always active, and it is
what lets the Mimic cast a copied spell without opening a gate. Cyrus has two
more: `light_footed.tres` lets him use Stealth, Slip Past and Run as a secondary
action too, and `quick_hands.tres` does the same for items. Those skills still
show on his Secondary tab, and their previews say which passive allows it.

### Adding a fight

Right-click `encounters/` → **New Resource** → `EncounterDefinition`, give it a
terrain scene, then lay the combatants out in `scenes/encounter_editor.tscn`:
select the encounter, drag the markers onto the map, press **Save spawns to
encounter**. It refuses to save anything unplayable and says what is wrong, so a
saved encounter always runs.

Each spawn carries its own level, weapon base and defence, so the same character
can be brought in weak early and dangerous later.

### Writing a conversation

Dialogue Manager scripts live in `Dialogue/`. Beyond its own syntax, this game
adds four things a script can steer directly:

```
do Music.play("Scott Buckley - Childhood")   # and stop, pause, fade_out
do Actors.enter("barbarian", "gate")         # walk someone in from off-map
do Actors.walk("cyrus", 13, 13)              # the line waits until they arrive
do Campaign.set_flag("read_the_notice")      # remember it for the rest of the game
if Campaign.flag("read_the_notice")          # and read it back anywhere
```

`Dialogue/walking_example.dialogue` and `Dialogue/flag_example.dialogue` are
runnable examples of the last two.

Flags are also how a door waits on a lever: any Interactable can **set** a flag
when used and **require** one before it works, with a message for when it
refuses. That needs no script at all.

## Audio

Drop tracks into `audio/music/` and name them in an encounter's **Music** field
or from dialogue. `.ogg` and `.mp3` are the formats to prefer: they stream, they
are a fraction of the size, and they import in moments.

**A warning about `.wav`.** Some tools export WAVs with a *streamed* header -
the file's size fields are left at `0xFFFFFFFF` because the writer never seeks
back to fill them in. Godot reads those literally, tries to load four gigabytes
out of a fifty-megabyte file, and the editor hangs on "(re)importing assets"
with no way out but Task Manager. If that happens, the file is the cause, not
Godot. Re-export it as `.ogg` or `.mp3`, or as a WAV from a tool that finalises
its header.

## Exporting

The builds are for itch.io: `tools/release.sh` makes both and zips each the
way itch wants it, and `--publish` pushes them there.

`export_presets.cfg` is gitignored - it can hold signing credentials - so
export settings do not travel with the repo. On a fresh clone, recreate two
presets, named exactly as the script asks for them:

* **Windows Desktop**, with **Embed PCK** off - the script checks for the
  `.pck` beside the `.exe` - and **Application → Icon** set to
  `res://imagese/icon/icon.ico`, which is what the exported `.exe` uses.
* **Web**, with **Thread Support** off. A threaded web build needs headers
  itch does not send by default, and fails to start without them.
`config/icon` in the project settings is a different thing: it covers the
project manager, the editor, and the window while the game runs.

`imagese/icon/icon.ico` holds 16/24/32/48/64/128/256px, so Windows has a real
image at every size rather than downscaling one. Rebuild it if the art changes.

Exporting needs the export templates for your exact Godot version: **Editor →
Manage Export Templates**.

## Credits

Tilesets by DENZI, CC-BY-SA 3.0:
https://opengameart.org/content/denzis-32x32-orthogonal-tilesets

Typefaces: [Alegreya Sans](https://github.com/huertatipografica/Alegreya-Sans),
copyright The Alegreya Sans Project Authors, and
[Cinzel](https://github.com/NDISCOVER/Cinzel), copyright The Cinzel Project
Authors - both SIL Open Font License 1.1, with the licences beside them in
`fonts/`.
