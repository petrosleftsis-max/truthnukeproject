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

### Making a stealth map

A stealth map is an exploration map with guards on it, played in real time: the
party has to stay out of their sight, and if a guard is sure of them, the fight
starts right where everyone is standing.

**To try one**, open `scenes/try_stealth_demo.tscn` and press **F6**: Cyrus in
the lab, a locker with a disguise in it, a notice board to look at closely
(the point-and-click example), and three guards between him and the far corner
- a Priest who knows his own robes, a Barbarian no disguise fools, and one any
disguise does. `scenes/stealth_demo.tscn` is how it is put together.

1. Build the map as an **instance of a battle terrain** - the way
   `explore_crossroads.tscn` is an instance of `crossroads_terrain.tscn` - so a
   tile on the map is the same tile in the fight.
2. Add a **StealthSetup** node. Point **Battle Terrain** at that terrain. Leave
   **Backup** empty for a fight alone, or list who comes running (and at which
   waypoint), since that depends on the story beat.
3. Add a **Guard** node per guard: which combatant they are and at what level,
   which way they face, and a **Patrol** of waypoint names to walk between.
   They stop at each waypoint and look about, and see a 160-degree cone as far
   as the walls let them - the same walls that block a shot in combat.
   **Recognises** says which disguises fool them: their own role only (a Priest
   knows every Priest), any disguise, or none.

A guard's meter fills while anyone is in their view - fast up close, slower far
off - and drains when they break the line. The screen feels it too: amber
creeps in round the edges as the fullest meter fills (red once a guard is
sure), and the camera leans in slightly while anyone is looking. A heartbeat
quickens and the music muffles as a meter fills; off-screen guards growing
sure get an arrow at the screen's edge; and Cyrus starts, a "!" over him, the
moment a guard first sees him.

Guards react. One who sees somebody stops and turns to them; lose them before
the meter fills and the guard stares after them, then - once it drains - walks
to where they were last seen and searches there with a 340-degree view instead
of 160, before going back to their beat (**Search Seconds** on the Guard sets
how long). Caught, time crawls for a moment, the screen shakes, the guard
flashes and a sting plays before the fight. The heartbeat and sting are
synthesised stand-ins until **Heartbeat Sound** and **Caught Sound** on the
StealthSetup are given real ones. **Shift** dashes three tiles in a
blink, then needs five seconds to recover; a guard who sees the dash grows sure
three times as fast, so it is for crossing gaps nobody is watching. The
numbers are the constants at the top of `exploration/StealthWatch.gd`. The
mouse wheel zooms in and out on a stealth map - an ordinary map keeps one
framing - and the view stays centred on the party either way. Everything a guard can see is tinted
on the map. Win the fight and the guards are gone when the party walks back in.

**Disguises** are items with **Disguise As** set to a combatant key (see
`items/priest_robes.tres`), handed out like any item:
`do Campaign.give_item("cyrus", "priest_robes")`. On a stealth map a bar along
the top lists them: **1-9** puts one on - three seconds standing still,
shuffling into it, and any guard who sees him at it knows him at once - and then he
looks like that character. **H** takes it off again at once, out of every
guard's sight only. A disguise never shows up in a fight's Items panel.

**The rest of the kit.** Every key below has a button on the same bar, which
only shows when there is something to do with it:

- **T - throw.** An item with **Distraction Radius** set (`items/pebble.tres`)
  can be thrown up to 7 tiles along a clear line: click where. Guards within
  its radius of where it lands go and look. A **Shift** dash is a noise too -
  guards within 4 tiles turn to it.
- **V - vault.** Beside a barrel, with free floor straight across it, V hops
  over. Anything a tile's **Blocks** stops walkers on (0) but not fliers on
  (1) can be vaulted; a wall stops fliers too, and cannot.
- **Hiding spots.** A **HidingSpot** node on a floor tile hides whoever stands
  on it from any guard not right beside it - unless the guard saw somebody and
  is going to look: then he sees into every spot within 3 tiles of where he
  saw them, a body stuffed into one included. One person each, so a party of
  two needs two spots together. **Look** is the picture drawn there.
- **Left click - take down, right click - pick pockets.** Right behind a guard
  who has no idea he is there; the click can land on him, or anywhere else if
  he is the only one. A guard's **Pockets** lists item keys to lift; **Picked Flag** is
  set when they are lifted, which a locked door's **Requires Flag** can wait on.
  A takedown is heard: guards within 3 tiles come to see what it was.
  Somebody knocked out is not in the fight, and stays where they fell - until
  another guard's view falls on them, which sends the map to Alarmed.
- **Bodies.** A body's pockets can be picked too. Left click beside one to
  drag it after you at half pace - no dashing, no changing clothes, and any
  guard who sees you at it knows you at once - and left click again to put it
  down. Put down beside a free hiding spot, it goes in it: never found, and
  that spot is no good for hiding in any more.
- **Alert.** Every investigation puts the map more on edge (Calm, Wary,
  Alarmed on the bar), a found body or a captain's shout all the way. The
  effects grow smoothly with it rather than switching on at a level: at the
  top, guards walk 40% quicker, see 20 degrees wider either side and grow sure
  60% quicker. It fades by itself at the StealthSetup's **Alert Fades Per
  Second** - 50 seconds from the top to calm, as the stages have it.
- **Q - Cat's Ears.** With **Guards Seen Only In Sight** ticked on the
  StealthSetup, a guard is only drawn while Cyrus has a line to them, is right
  beside them, or they are growing sure of him. Q hears every guard through
  the walls for 4 seconds, then needs 4 more to recover.
- **Guard Kind.** A **Watchman** is everything above. A **Dog** has no cone -
  it smells anybody within **Smell Tiles**, walls or not, hiding spot or not,
  and no disguise fools it. A **Ward** (a statue, a charm) turns on the spot
  at **Ward Turn Degrees** a second, sees through every disguise, never moves,
  can't be taken down and never fights. A **Captain** is a watchman whose
  shout, once he is sure, alarms the map and brings every guard within **Shout
  Tiles** into the fight from the first round.
- **Who fights.** **Joins Within Tiles** on the StealthSetup: only guards that
  close to where he was caught (and whoever caught him) start the fight; the
  rest arrive a round later for every **Tiles Per Late Round** further off they
  were, or not at all if that is 0. 0 for Joins Within Tiles means everybody,
  all at once. Any enemy spawn in any encounter can arrive late the same way -
  **Arrives On Round** on the SpawnDefinition.
- **Questions.** A guard with **Questions** set stops somebody in a disguise
  they doubt at half sure and plays that conversation. If it sets **Passed
  Flag** he waves them on for good; if not, he is sure.
- **The ghost bonus.** A **StealthGoal** node is the way out: walking into it
  sets **Completed Flag**, and **Ghost Flag** as well if no guard ever so much
  as began to notice anybody. "Unseen" on the bar says it is still on.

Whatever a click would do right now is shown in a small prompt right over
whoever it would be done to, with a ring at their feet - and, behind somebody
who can't be taken down, it says so. **Can Be Taken Down** on a Guard sets
that; a ward never can be.

**After a fight.** Caught, the map is written down before the fight starts,
and walking back in carries on from there: the guards who fought and lost are
gone, anybody who never reached the fight is still on watch, bodies lie where
they were (or stay in their hiding spots), picked pockets stay picked, the
disguise stays on and the map is as on edge as it was. Only the ghost bonus is
gone - caught is noticed.

Most of the numbers - reach, throw range, how long the ears last, how much
each alert level adds - are constants at the top of
`exploration/StealthWatch.gd`.

**Stealth stages.** **Stealth Stages** on the title screen lists four short
maps to play on their own: 1 has the tools (throwing, hiding, pockets, a
takedown), 2 the ward, the hound and the captain, 3 getting Enfina out, and 4
disguises and a checkpoint that asks questions. In all four, guards are seen
only when Cyrus could see them, so Q is worth pressing.
Reaching a stage's way out goes back to the list, which says how it went - a
**StealthGoal** with **Ends At Menu** ticked does that. The list is
`STEALTH_STAGES` in `ui/main_menu.gd`. From the editor,
`scenes/try_stealth_stages.tscn` with **F6** opens the same stages without the
title screen, and the lab demo too.

**Laying out a stage.** Two tools paint a map in the lab's style from text,
one character a tile: `#` wall, `T` wall with a torch, `b` and `o` barrels,
anything else floor (letters make handy markers). The walls are worked out
from where the floor is.

- In the editor, add a **LayoutPainter** node beside a TileMap, type the
  layout into **Layout** and tick **Paint Now**. Touch up by hand afterwards.
- The test stages are built by `tools/build_stealth_stages.gd`, which carves
  each layout out of rock a rectangle at a time and places the guards, spots
  and conversations on it. Running it rebuilds `stages/` and overwrites any
  hand edits there:

  ```bash
  godot --headless --path . res://tools/build_stealth_stages.tscn
  ```

  Each stage is two scenes: `stealth_N_terrain.tscn` is the map alone, which
  the fight is played on, and `stealth_N.tscn` puts the guards on it. Once built
  they are ordinary scenes to open and change.

### Making a point-and-click picture

A close look at something - a desk, a room, a mural - where the player hovers
over things to see what they are and clicks them.

1. New scene with a **Picture** node as its root, sized to your artwork, and a
   **TextureRect** under it holding the image. Give the Picture a **Title** to
   show above it.
2. Add a **Hotspot** over each thing that can be clicked, sized to cover it.
   Hovering names it (**Display Name**); clicking says its **Examine Text**,
   plays its **Dialogue**, sets its flag, and then opens another picture or
   goes to a map.
3. For an item puzzle, set **Takes Item** to an item key. The player picks the
   item from the bag along the bottom and clicks the hotspot; the right one
   sets **Item Sets Flag** (used up, unless you untick that), anything else gets
   the wrong-item line.
4. To make the picture change, give an image (a **PictureLayer**) or a
   hotspot **Shown While Flag** or **Hidden Once Flag** - the drawer drawn open
   once the key is used, the letter gone once taken.

Open it from a map with a **PictureInteractable** (walk up, press E), or from a
conversation with `do Pictures.open("res://pictures/desk.tscn")`, which waits
until the pictures are closed. **Esc** or right-click goes back a picture (or
puts down a held item first).

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
