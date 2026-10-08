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
* **Dungeon Demo** — the sewer, the lab and the city fight one after another,
  everyone at level 3 (Enfina joins in the sewer, as in the story), resting
  between each (see Making a dungeon).
* **Options** — fullscreen, fake fullscreen (a borderless window over the
  whole screen) or windowed, remembered between runs; window size, which goes
  back to a window; separate volume for music and sound effects; and how fast
  enemy turns play (also in the pause menu).

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

### With a controller

Pick up a pad and the game switches to it; touch the keyboard or move the mouse
and it switches back. Everything that names a key - the bar, the prompts, the
tooltips - names the pad's buttons instead, as an Xbox, PlayStation or Nintendo
pad prints them.

The pad has a **pointer**, which is the mouse: whatever it is over lights up as
it would under the mouse, and **A** clicks there. It stays out of the way where
it is not needed.

| | Walking about and sneaking | A fight | A picture |
| --- | --- | --- | --- |
| Left stick | walk - pushed only a little way, creep | the cursor, a tile at a time | the pointer |
| Right stick | the pointer: on a guard, his round; aiming, where to throw | move the view | the pointer |
| D-pad | Up vault, Down ambush, Right put on the next disguise, Left take it off (aiming: what to throw) | the cursor, a tile at a time | |
| A | use, talk (aiming: throw; on the HUD: click) | click: walk, aim, press | click |
| B | stop aiming | stop aiming; out of the skill panel | back, put the item down |
| X (Square) / Y | take down, drag, put down / pick pockets | the skill panel / end the turn | |
| LB / RB | listen / dash | the skill before / after; aiming or placing the party, the tile before / after | turn a dial back / on |
| LT / RT | patience (held) / throw | danger view (held) / next skill tab | |
| Right stick click | swap the leader | out to the whole map and back | |

**In a fight** the pointer sits on a tile, the cursor, and goes from tile to
tile - any tile on the map, walkable or not, since a click further off than a
walk reaches still does something. While a skill is aimed it goes only between
whoever it can hit; an area skill, or one with nobody in reach, goes between
every tile it could go instead; placing the party, only the tiles they can be
placed on. Pressed a way, it jumps to the nearest of those tiles that way,
over any gap cover leaves, and **LB** / **RB** go through all of them in turn.
The view follows it, keeping it clear of the HUD.

**X** (Square) opens the skill panel along the bottom - the skills and their
tabs, **Undo Move** and **End Turn** (**Begin Battle**, placing the party) - for
the D-pad to go round and **A** to press. A skill picked there is aimed on the
map; **B** puts the aim away and goes back to the panel, and **B** or **X**
again goes back to the map.

**B** in a conversation skips it, asking first - as the Skip button now does
too.

**View** opens the menus - the journal, inventory and character sheet,
whichever this place has (in a fight the sheet comes first) - and **LB** /
**RB** go from one to the next while one is open. **Menu** pauses. In a menu
the D-pad and left stick go from button to button and **A** presses; the right
stick brings the pointer out for anything that only answers the mouse, such as
the inventory's slots.

The buttons are actions in **Project Settings > Input Map**, keyboard and pad
side by side, so either can be rebound there. `control/Pad.gd` is the pointer
and the button names; `tests/pad_test_driver.gd` plays every row above.

## The shape of it

Everything a designer sets lives in resources and scenes, not in code. Adding a
character, a skill, a fight or a conversation needs no scripting.

| What | Where | Edited as |
| --- | --- | --- |
| Characters | `data/characters/*.tres`, `data/enemies/*.tres` | a CombatantDefinition each: the party, and everybody they fight |
| Skills | `data/skills/*.tres` | a SkillDefinition each |
| Items | `data/items/*.tres` | an ItemDefinition each |
| Passive skills | `data/passives/*.tres` | a PassiveDefinition, listed under a character's **Passives** |
| Fights | `data/encounters/*.tres` | an EncounterDefinition: a map, who starts where, and the music |
| Maps | `maps/*_terrain.tscn` | a TileMap; tile data says what blocks whom and what it costs to cross |
| Conditions | `data/conditions/*.tres` | poisons, stuns, buffs and what they do |
| Conversations | `dialogue/*.dialogue` | Dialogue Manager scripts |

A file's name is its key - `data/skills/fireball.tres` is `"fireball"` - and
saving one in its folder is all it takes to add it: the databases read their
folders when the game starts, so there is no list to fill in. They are
autoloads, so `SkillDatabase.skills["fireball"]`, `ItemDatabase.item("pebble")`
and `CombatantDatabase.combatants["cyrus"]` work from anywhere.

### Where things are

| Folder | What is in it |
| --- | --- |
| `art/` | Every image. `characters/<name>/` holds a character's animations (`idle/`, `walk/`, `attack/`, `skill/`), their frame set (`<name>_frames.tres`) and their menu picture; `enemies/<kind>/` the same for each enemy; `icons/` skill and item icons; `portraits/` faces for conversations; `terrain/` tile sheets; `ui/` menu and HUD pieces; `app_icon/` the game's icon; `editor_icons/` the icons the editor shows for the game's own node and resource types |
| `audio/` | Music and sound effects |
| `data/` | What the game is made of, as resources: `characters/` (the party), `enemies/`, `skills/`, `items/`, `conditions/`, `passives/`, `encounters/`, `clues/`, the `glossary/`, and the `databases/` scripts that read them |
| `dialogue/` | Conversations |
| `maps/` | Battle maps (`*_terrain`, `*_fight`), maps to walk around (`*_explore`, `church`), the stealth stages (`stealth_stages/`) and the tile set |
| `pictures/` | Point-and-click pictures, and `feedback.tres` for their sounds and cursors |
| `scenes/` | The game's own screens: the title screen, the battle, walking around, story screens |
| `demos/` | Scenes to open and press F6 on to try something: the stealth demo, the stealth stages, the clues demo |
| `campaign/`, `combat/`, `control/`, `exploration/`, `ui/` | The code: the playthrough's state, the fights, the grid and camera, walking around (stealth and pictures too), and the screens |
| `tools/` | Editor tools and build scripts: the encounter editor (`encounter_editor.tscn`), the stage builder, the layout painter and void filler, `release.sh` |
| `tests/` | The test suites (see `tests/README.md`) |
| `docs/` | Notes and the store image - not part of the game |

In the editor's FileSystem dock the main folders are coloured - art purple,
data blue, maps green, dialogue yellow, pictures orange, scenes red, demos teal,
tools grey - and the game's own kinds of node and resource have icons of their
own: a sword on a skill, a magnifier on a clue, a figure with a vision cone on a
Guard. A new class gets one with `@icon("res://art/editor_icons/<name>.svg")`
at the top of its script.

### Adding a skill

1. Right-click `data/skills/` → **New Resource** → `SkillDefinition`, and fill it in.
   Damage lives on the skill itself, under **Power**: whether it deals damage,
   how hard, which attribute it scales from, and of what element. **Effects** is
   for everything else it does - a condition, a heal, a shove, a lingering
   wound.
   Its file name is its key: `sweep_strike.tres` is `"sweep_strike"`.
2. Add that key to whichever characters know it, in their **Skills** list
   (`data/characters/` or `data/enemies/` - double-click one to edit it).

A combatant knows exactly what their file lists, and nothing else.

A skill aimed at the fallen - Alithia's **Resuscitate** - has **Targets Fallen**
ticked and a **Revive** effect: how much of their health they come back with,
and how much less of everything but their movement they are afterwards. That
weakening is for good: it compounds each time, and carries from fight to fight
until the party is started over.

A skill with a **Steal** effect - Cyrus's **Steal** - takes what an enemy has to
hand and puts it in the thief's bag, into the four front slots first so it can be
used straight away. Anything that doesn't fit there goes further back in the bag,
for after the fight. If the bag is full, the enemy keeps it. **Steal Count**
limits how many items it takes; 0 means all of them. Stolen items stay in the
bag after the fight, the same as anything else the party carries.

### Adding a passive skill

A passive is something a character does without pressing anything, so it never
appears on the action panel - the character sheet lists it under **Passive
Skills** instead, name and description written out in full.

1. Right-click `data/passives/` → **New Resource** → `PassiveDefinition`. Give it a
   name and a description, and choose **Active When**: always, or only once
   its condition holds.
2. Under **What it does**, switch on what it grants.
3. Add it to the character's **Passives** list, in their file in
   `data/characters/` or `data/enemies/`.

The Mimic's `data/passives/mimicry.tres` is the example: always active, and it is
what lets the Mimic cast a copied spell without opening a gate. Cyrus has two
more: `light_footed.tres` lets him use Stealth, Slip Past and Run as a secondary
action too, and `quick_hands.tres` does the same for items. Those skills still
show on his Secondary tab, and their previews say which passive allows it.

### Adding a fight

Right-click `data/encounters/` → **New Resource** → `EncounterDefinition`, give it a
terrain scene, then lay the combatants out in `tools/encounter_editor.tscn`:
select the encounter, drag the markers onto the map, press **Save spawns to
encounter**. It refuses to save anything unplayable and says what is wrong, so a
saved encounter always runs.

Each spawn carries its own level, weapon base and defence, so the same character
can be brought in weak early and dangerous later.

**Starting Items** on a spawn is what that fighter brings, picked from a dropdown
of the items there are. An enemy uses theirs: a potion is drunk when they are
badly hurt, a bomb or bottle thrown like any skill. Only the first four they can
use in a fight come with them (a pebble or a disguise is no use there). Look at
an enemy in a fight and their Items tab shows what they carry, which is what
Cyrus's **Steal** takes.

### Making a dungeon

A dungeon is fights one after another with a rest between each - the **Dungeon
Demo** on the title screen is `data/dungeons/dungeon_demo.tres`, a
`DungeonDefinition`. Open it in the inspector:

* **Party** - who goes in, leader first, and their level on the maps. The maps'
  own parties and handed-out kit are not used: the party starts carrying
  nothing, and keeps whatever it picks up and does not use.
* **Stages** - in order, each a `DungeonStage`: a **Map** to walk until its
  fight, or none to go straight into the fight. **Encounter** is the fight;
  on a map it is fought instead of the one the map starts by itself, named in
  **Replaces** - so the map keeps its conversations and loot, and only the fight
  at the end is the dungeon's. The demo's three are copies of the story's fights
  in `data/encounters/dungeon_demo/`, every player tile and enemy at level 3
  (with the City Fight's level 3 weapon base and defences), two more enemies in
  the sewer and three fewer in the city.
* **Resting** - after every fight but the last, everyone is back to full health
  (and back on their feet, with **Rest Revives**). Gates spent stay spent from
  one fight to the next; the rest offers to bring some back for whoever is in
  **Gate Recovery For**, at **Gate Recoveries** rests in the run, with **Gate
  Recovery Points** to spend at **Gate Costs** each (0, then World, Hermes,
  Yaldabaoth).

Winning a stage's fight plays its own closing conversation first, then the rest,
then the next stage. Winning the last ends the dungeon and goes back to the
title screen; losing any of them offers to start the dungeon again.

### Making a stealth map

A stealth map is an exploration map with guards on it, played in real time: the
party has to stay out of their sight, and if a guard is sure of them, the fight
starts right where everyone is standing.

**To try one**, open `demos/try_stealth_demo.tscn` and press **F6**: Cyrus in
the lab, a locker with a disguise in it, a notice board to look at closely
(the point-and-click example), and three guards between him and the far corner
- a Priest who knows his own robes, a Barbarian no disguise fools, and one any
disguise does. `demos/stealth_demo.tscn` is how it is put together.

1. Build the map as an **instance of a battle terrain** - the way
   `maps/crossroads_explore.tscn` is an instance of `maps/crossroads_terrain.tscn` - so a
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
`data/items/priest_robes.tres`), handed out like any item:
`do Campaign.give_item("cyrus", "priest_robes")`. On a stealth map a bar along
the top lists them: **1-9** puts one on - three seconds standing still,
shuffling into it, and any guard who sees him at it knows him at once - and then he
looks like that character. **H** takes it off again at once, out of every
guard's sight only. A disguise never shows up in a fight's Items panel. In
one, the view tinted on the ground says whose gaze matters: purple for a guard
who sees through it, amber for one who would stop him with questions first,
a faint grey for one it fools. Pointing at a disguise on the bar shows the
same for it before it is on.

**The rest of the kit.** Every key below has a button on the same bar, which
only shows when there is something to do with it:

- **T - throw.** An item with **Distraction Radius** set (`data/items/pebble.tres`)
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
  two needs two spots together. **Look** is the picture drawn there. Throwing
  from one gives him away: anybody with the spot in view knows him at once (a
  red ring at his feet while aiming says somebody has). A ghost of
  Cyrus stands where a guard out looking for him thinks he is, with a ring as
  far as the spots he will look into.
- **Left click - take down, right click - pick pockets.** Right behind a guard
  who has no idea he is there; the click can land on him, or anywhere else if
  he is the only one. A guard's **Pockets** lists item keys to lift; **Picked Flag** is
  set when they are lifted, which a locked door's **Requires Flag** can wait on.
  A takedown is heard: guards within 5 tiles come to see what it was.
  Somebody knocked out is not in the fight, and stays where they fell - until
  another guard finds them. Found, the map goes a level more on edge and can
  never be settled below that level again, and the finder goes over and brings
  them round (3 seconds); knock the finder out on his way and the body is there
  to be found again, without putting the map up twice.
- **Bodies.** A body's pockets can be picked too. Left click beside one to
  drag it after you at half pace - no dashing, no changing clothes, and any
  guard who sees you at it knows you at once - and left click again to put it
  down. Put down beside a free hiding spot, it goes in it, and that spot is no
  good for hiding in any more - but a body never quite fits: a guard who comes
  within 2 tiles of the spot with it in view notices the boot sticking out.
- **Alert.** Every investigation puts the map more on edge (Calm, Wary,
  Alarmed on the bar), a found body a level, a captain's shout all the way. The
  effects grow smoothly with it rather than switching on at a level: at the
  top, guards walk 40% quicker, see 20 degrees wider either side and grow sure
  60% quicker. It never eases by itself. It settles a level - never below where
  a found body pinned it - by a word with a guard (**E** beside one a disguise
  fools, when E is not for something else in reach: a line each, 2 seconds
  standing still, once a guard; a guard's **Small Talk** conversation plays
  instead, if he has one), by a conversation (`do Campaign.settle_alert()`), or
  by using anything with **Settles Alert** ticked (an all-clear horn, a duty
  board). **Starting Alert** on
  the StealthSetup has a map begin Wary or Alarmed.
- **Q - Cat's Ears.** With **Guards Seen Only In Sight** ticked on the
  StealthSetup, a guard is only drawn while Cyrus has a line to them, is right
  beside them, or they are growing sure of him. Q hears every guard through
  the walls for 4 seconds, then needs 4 more to recover. A guard's round is
  drawn while listening, or with the pointer on him - but only once it has been
  found out: set his **Route Known Flag** from whatever tells it (a duty roster
  to read, a pocket, a conversation).
- **Ctrl - creep.** Held (or kept on with the bar's button), the party walks at
  45% pace without a sound. A **NoisyFloor** patch - gravel, puddles, broken
  glass - is heard at every step otherwise: guards turn to gravel and puddles,
  and come to look at glass.
- **P - Patience.** Held (the key, or the bar's button), time runs twice as
  fast - everybody's, his too - for waiting out a patrol. Let go, or have a
  conversation, a menu or a catch hold the game, and it is back to normal.
- **F - ambush.** Within 2.5 tiles of a guard who has no idea he is there, F
  starts the fight on his terms: everybody who had not noticed anything loses
  their first turn (the Caught Off Guard condition).
- **Poisons.** An item with **Poison** set: an **Emetic** sends a guard off to
  be sick at the nearest **RetchSpot** for five minutes, seeing nothing; a
  **Sedative** drops him where he stands, a body like any other; a **Disease**
  leaves him too ill to move for five minutes and brings the nearest guard to
  see to him, both watching half as wide. **Poison Onset** says when it takes
  hold: **Instant**, **Shortly** (5 seconds) or **Delayed** (15). **Poison
  Shootable** makes it a dart, thrown with T at a guard (T again while aiming
  picks the next thing to throw); otherwise it goes into an **Edible** - a
  supper left out for its **Eater**, who comes for it after **Eaten After
  Seconds** - with E: three seconds standing still, stirring it in, and
  anybody who sees him at it knows him at once. Nothing is used up if he is
  stopped.
- **Doors, lamps and things lying about.** A **StealthDoor** shut stops walking
  and sight (E opens and shuts it; **Requires Flag** locks it); guards walk
  through, holding it open as they pass. **Dark** on the StealthSetup makes a
  map dark but for its **Lamp**s and the torches on its walls: a guard makes
  somebody out in the dark only within **Dark Sight Tiles**. E puts a lamp out
  quietly; a pebble landing beside it knocks it out. A **StealthPickup** is
  something to take; a **PlantSpot** somewhere to leave something.
- **Guards notice what has changed.** A door left open that should be shut, a
  lamp out that should be lit, something gone that should be there, a hiding
  spot with a boot sticking out: a guard who sees it goes to look - the map a
  little more on edge - and puts it right.
- **Guard life.** A **GuardChat** has two guards meet every so often to talk,
  their view narrower for it; within **Earshot Tiles** (twice that listening)
  the party overhears it a line at a time, and every line heard sets
  **Overheard Flag**. When one of them is not there to meet - knocked out, sick
  - the other goes looking. A guard with **Asleep** ticked sees nothing, can be
  robbed and taken down from any side, and wakes to a noise near enough. A
  **Civilian** never fights: sure of somebody - or seeing a takedown, a body, a
  body dragged - they run to the nearest guard and tell him, and he goes
  hunting. Stop them first and nobody is told.
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
  were - up to twice as quick at the top of Alarmed - or not at all if that is
  0. Whoever could hit somebody in the party on his first turn - walk his
  Movement across the battle terrain, then a damaging skill (or a bomb in his
  pockets) in range, with a clear line past arm's length - is there from the
  start however far off he is. 0 for Joins Within Tiles means everybody, all
  at once. Any enemy spawn in
  any encounter can arrive late the same way - **Arrives On Round** on the
  SpawnDefinition. **Reinforcements** are sent for when the map was already on
  edge: half of them on round 3 of a Wary map, all of them on round 2 of an
  Alarmed one. A guard fights with whatever is still in his pockets - a potion
  drunk when badly hurt, a bomb thrown - and nothing that was lifted; any enemy
  spawn's **Starting Items** work that way.
- **Questions.** A guard with **Questions** set stops somebody in a disguise
  they doubt at half sure and plays that conversation. If it sets **Passed
  Flag** he waves them on for good; if not, he is sure.
- **The ghost bonus.** A **StealthGoal** node is the way out: walking into it
  sets **Completed Flag**, and **Ghost Flag** as well if no guard ever so much
  as began to notice anybody. "Unseen" on the bar says it is still on. Leaving
  the map by it shows a card: a rank - **Ghost** (never noticed), **Shadow**
  (noticed, never caught) or **Brawler** (it came to a fight) - the tally, and
  the objectives.
- **Objectives.** A **StealthObjective** node is something to do besides
  getting out, listed under the bar: a flag to set, something to carry off, no
  takedowns, never Alarmed, nobody harmed, or the map Calm on the way out.
  None of them stops anybody leaving.
- **Restart Stage.** In the pause menu on a stealth map - or in the fight a
  catch started there - it puts everything back as it was when the party
  walked onto the map and starts it over.

Whatever a click would do right now is shown in a small prompt right over
whoever it would be done to, with a ring at their feet - and, behind somebody
who can't be taken down, it says so. **Can Be Taken Down** on a Guard sets
that; a ward never can be.

**After a fight.** Caught, the map is written down before the fight starts,
and walking back in carries on from there: the guards who fought and lost are
gone, anybody who never reached the fight is still on watch, bodies nobody had
found lie where they were (or stay in their hiding spots), found ones are up
again, picked pockets stay picked, doors, lamps and suppers are as they were
left, the disguise stays on and the map is as on edge as it was. Only the ghost
bonus is gone - caught is noticed.

Most of the numbers - reach, throw range, how long the ears last, how much
each alert level adds - are constants at the top of
`exploration/StealthWatch.gd`.

**Stealth stages.** **Stealth Stages** on the title screen lists seven short
maps to play on their own: 1 has the tools (throwing, hiding, pockets, a
takedown), 2 the ward, the hound and the captain, 3 getting Enfina out, 4
disguises and a checkpoint that asks questions, 5 a dark archive (lamps, doors,
noisy floors, a sleeping porter and a duty roster), 6 poisons and two guards who
meet to talk, and 7 a camp on edge to settle in disguise, with an ambush at
the gate. In all of them, guards are seen only when Cyrus could see them, so Q
is worth pressing.
Reaching a stage's way out goes back to the list, which says how it went - a
**StealthGoal** with **Ends At Menu** ticked does that. The list is
`STEALTH_STAGES` in `ui/main_menu.gd`. From the editor,
`demos/try_stealth_stages.tscn` with **F6** opens the same stages without the
title screen, and the lab demo too.

**Laying out a stage.** Two tools paint a map in the lab's style from text,
one character a tile: `#` wall, `T` wall with a torch, `b` and `o` barrels,
anything else floor (letters make handy markers). The walls are worked out
from where the floor is.

- In the editor, add a **LayoutPainter** node beside a TileMap, type the
  layout into **Layout** and tick **Paint Now**. Touch up by hand afterwards.
- The test stages are built by `tools/build_stealth_stages.gd`, which carves
  each layout out of rock a rectangle at a time and places the guards, spots
  and conversations on it. Running it rebuilds `maps/stealth_stages/` and overwrites any
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
   hands over its **Gives Item** and **Gives Clue**, plays its **Dialogue**,
   sets its flag, and then opens another picture or goes to a map. Something
   to pick up: Gives Item, with **Sets Flag** and **Hidden Once Flag** both set
   to the same flag so it is gone once taken.
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

**To try everything below**, press **Clues Demo** on the title screen (or open
`demos/try_pictures_demo.tscn` and press F6): Captain Vell's office, built in
`pictures/clues_*.tscn`.

**How much a picture gives away.** A Picture's **Hover Hints** is how much
hovering shows: an outline and a name (the default), only the name, or nothing
at all until clicked - for a picture meant to be searched. **Show Progress**
puts "Noticed 3 of 7" under the title, and things already clicked get a tick
and "(seen)". The cursor carries a sign saying what a click will do - look,
take, talk, use, go, turn a dial, move a piece - worked out from what the
hotspot does, or set by its **Verb**.

**Clues and the journal.** A clue is a **ClueDefinition** saved in `data/clues/`,
its file name its key: a **Title** and **Text** for the journal. A hotspot's
**Gives Clue**, a solved puzzle, or `do Campaign.learn_clue("ledger_count")` in
a conversation puts it in the journal (J, or the Journal button under a
picture), with a note in the corner of the screen. When it is learned it can
set a flag (**Sets Flag** - a guard's Route Known Flag, a door's Requires Flag)
and open the sheets of combatants in every fight from then on (**Reveals
Combatants** - the letter that says what the gate guard is weak to).
Conversations ask `if Campaign.knows_clue("ledger_count")`.

**Working things out.** A clue with two others under **From Clues** is a
deduction: nothing hands it over - the player picks those two in the journal
and presses Connect.

**Showing something in a conversation.**

```
do Journal.present("What do you show the captain?")
if Journal.presented == "skimming"
	Captain: ...where did you get that?
elif Journal.presented == ""
	Captain: Well?
else
	Captain: And what is that supposed to prove?
```

The player picks a clue or an item from the bag; `Journal.presented` is its
key, or "" if they backed out.

**Locks and torn letters.** A **Puzzle** node holds the parts of something to
work out by hand, and says what solving it does (**Solved Flag**, **Solved
Text**, **Gives Clue**, **Gives Item**):

- **PuzzleDial**: click (or roll the wheel) to turn it through its **Values**;
  right when it shows its **Answer**. Drawn as a numbered tumbler until you give
  it **Value Textures**.
- **PuzzlePiece** and **PuzzleSlot**: drag the piece; let go near a free slot
  and it snaps in. Right when it sits in its own **Slot**. The torn strip of a
  letter, a jar for the shelf. Put its art under it; without any it is a plain
  card with its **Placeholder Text** on.

Solved, it holds still, and stays solved the next time the picture opens.

**Putting things together.** An item with two others under **Made From** is
made by putting them together - pick one up from the bag under a picture and
click the other, or click one then the other in the party's bags (I). Both are
used up; its **Combine Text** says what happened.

**Hidden details.** Tick **Reveals Hidden Details** on an item (a magnifying
glass, a lamp) and it becomes a lens: picked up from the bag under a picture,
it is held round the pointer. A Hotspot or PictureLayer marked **Hidden
Detail** can only be found, or seen, under it - writing pressed into a blotter,
a mark under the dust. A hidden hotspot, once clicked, stays found.

**Sounds, cursors and animation - yours, when you have them.** Everything the
pictures and the journal play or draw comes from `pictures/feedback.tres`: a
slot per sound (look, take, talk, a dial turning, a piece snapping in, a clue
learned, a puzzle solved...) and per cursor sign. An empty slot plays a short
generated blip or draws a simple glyph, so drop your own in as they are made.
The same file turns animation off and sets how long a zoom or a fade takes. A
Hotspot can also have its own **Click Sound**, and play your own animation on a
click (**Animation Player** and **Click Animation**); a PictureLayer with an
AnimationPlayer under it plays your **appear** and **disappear** in place of
its fade.

### Writing a conversation

Dialogue Manager scripts live in `dialogue/`. Beyond its own syntax, this game
adds four things a script can steer directly:

```
do Music.play("Scott Buckley - Childhood")   # and stop, pause, fade_out
do Actors.enter("barbarian", "gate")         # walk someone in from off-map
do Actors.walk("cyrus", 13, 13)              # the line waits until they arrive
do Campaign.set_flag("read_the_notice")      # remember it for the rest of the game
if Campaign.flag("read_the_notice")          # and read it back anywhere
```

`dialogue/walking_example.dialogue` and `dialogue/flag_example.dialogue` are
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
  `res://art/app_icon/icon.ico`, which is what the exported `.exe` uses.
* **Web**, with **Thread Support** off. A threaded web build needs headers
  itch does not send by default, and fails to start without them.
`config/icon` in the project settings is a different thing: it covers the
project manager, the editor, and the window while the game runs.

`art/app_icon/icon.ico` holds 16/24/32/48/64/128/256px, so Windows has a real
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
