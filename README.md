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
* **Arena Mode** — every encounter, playable directly, with the party you
  have left from the last one. *Reset party* puts everyone back on their feet.
* **Dungeon Demo** — the sewer, the lab and the city fight one after another,
  everyone at level 20 (Enfina joins in the sewer, as in the story), resting
  between each, with a store at the rests (see Making a dungeon).
* **Continue** and **Load Game** — once there is a save (see Saving).
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
of them. Hover anyone on the map, or a face in the turn queue (down the right of
the screen, in the order turns come), to see who they are; click a face to find
them. A greyed-out skill can still be pressed to see
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
| Items | `data/items/*.tres` | an ItemDefinition each (a GateNadeDefinition for a Gate Nade) |
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
| `art/` | Every image. `characters/<name>/` holds a character's animations (`idle/`, `walk/`, `attack/`, `skill/`), their frame set (`<name>_frames.tres`) and their menu picture; `enemies/<kind>/` the same for each enemy; `icons/` skill and item icons; `objects/` things on the battlefield; `portraits/` faces for conversations; `terrain/` tile sheets; `ui/` menu and HUD pieces; `app_icon/` the game's icon; `editor_icons/` the icons the editor shows for the game's own node and resource types |
| `audio/` | Music and sound effects |
| `data/` | What the game is made of, as resources: `characters/` (the party), `enemies/`, `objects/` (things on the battlefield), `hacks/` (Prometheus's hacks), `skills/`, `items/`, `conditions/`, `passives/`, `subclasses/` (the paths), `factions/`, `equipment/`, `stores/`, `encounters/`, `dungeons/`, `clues/`, the `glossary/`, and the `databases/` scripts that read them |
| `dialogue/` | Conversations |
| `maps/` | Battle maps (`*_terrain`, `*_fight`), maps to walk around (`*_explore`, `church`), the stealth stages (`stealth_stages/`) and the tile set |
| `pictures/` | Point-and-click pictures, and `feedback.tres` for their sounds and cursors |
| `scenes/` | The game's own screens: the title screen, the battle, walking around, story screens |
| `demos/` | Scenes to open and press F6 on to try something: the stealth demo, the stealth stages, the clues demo |
| `campaign/`, `combat/`, `control/`, `exploration/`, `hacking/`, `ui/` | The code: the playthrough's state, the fights, the grid and camera, walking around (stealth and pictures too), the hacking minigames, and the screens |
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

A combatant knows exactly what their file lists, and nothing else. The action
panel has twelve buttons; somebody with more skills than that on one tab gets
them on a shelf that scrolls, the way spells are shown.

**Ignores Defense** (under Power) is how much of the target's Defense the
skill's hits go straight through, in percent. A hit works out to
`(WeaponBase + 0.7 x Stat) x Power x 40 / (40 + Defense)`, and the Defense in
that is lowered by the share ignored. It's worth more the tougher the target,
so it suits a caster who does less than the others to most enemies but more
to the well armoured. It applies to the hit only; a burn it leaves still meets
all of their Defense.

A skill with **Is Reactive** ticked is a reaction too: offered when somebody
leaves its user's reach on their own turn. With more than one (Enfina's
Greatsword and Grab), the player picks which; the AI takes the one it rates
highest.

**Declared** makes a skill one that is called on one turn and lands on the
next. Calling it costs nothing - the turn goes on, action and all - and marks
the tiles it will come down on: orange for the other side's, gold for the
party's. It lands at the start of its user's next turn once everybody on the
other side has had a turn since. For anybody with one turn a round that is
simply their next turn; a boss with two waits a turn longer, so the party always
gets its chance. It lands on exactly the marked tiles, wherever its user has
gone since, and that spends the turn's action (and any gate it costs). Anybody
who has moved off the marked tiles by then is missed. A stunned, staggered or
confused turn loses it. Only one can be waiting at a time; the turn
queue says who is readying what. Enemies call theirs before the rest of their
turn. Examples: **Ground Pound**, **Rockfall**, Prometheus's **Meteor** (level 15)
and Enfina's **Earthsplitter** (level 14).

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
bag after the fight, the same as anything else the party carries. While a Steal
is aimed, hovering anybody on the other side shows what they carry - in reach
or not, saying why not when it cannot be used on them.

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
show on his Secondary tab, and their previews say which passive allows it. With
both of his actions still there, using an item asks which one to spend.
`nade_juggler.tres` lets him throw any Gate Nade, and as a secondary action (below).

### Gate Nades

A Gate Nade is a spell sealed in a shell, the way a scroll is in other games.
Throw one and the spell goes off with no gate opened and no level needed; then
it's gone. Only somebody who knows the spell, or could learn it, can throw it:
the spell is in their skills (at any level) or on any of their paths. A
Revitalizer Gate Nade is Alithia's to throw, not Prometheus's or Enfina's. On
anybody else's panel it is greyed out, saying why.

To add one, right-click `data/items/` → **New Resource** → `GateNadeDefinition`
and name its **Spell** by key (`fireball`). When the game starts the nade takes
on that spell's whole shape: its reach, area, effects, damage type, the action
it costs, and its sound. It keeps its own:
- **name** and **description**, made up from the spell if left empty
- **icon**
- **Item Power**: a nade is as strong as itself, whoever throws it, like a bomb
- **Price**

A change to the spell changes every nade of it, and a spell key that doesn't
exist is reported at startup.

Two passive switches change that:
- **Any Gate Nade** throws any of them, whatever spell is inside.
- **Gate Nades As Secondary** throws them with the secondary action where the
  spell would take the main one.

Cyrus's **Nade Juggler** has both.

The examples are the Fireball, Heal, Crystalise and Revitalizer Gate Nades,
which the travelling merchant sells. Their power and prices are placeholders. Like every
consumable they wear the consumable icon, told apart by their letter badges.

### Hacking

Prometheus hacks: wards, seals and machines, on maps and in pictures, from
conversations, and in fights. Anybody with a passive's **Can Hack** can; his
is **Prying Mind**. A hack is a `HackDefinition`, saved in `data/hacks/` or set
straight onto what is being hacked, and it is one of three minigames:

- **Rewrite the Rule.** The spell's sheet, line by line ("Targets: Intruders",
  "Reach: 4"), each with what it has to end up as. Change them within a budget
  of **Edits** and commit. A line can be **Locked Until** another changes, and a
  **Balanced** sheet's watched lines have to keep their sum. For a real puzzle,
  give lines **Pushes**: each step of one drags others with it, every number
  stays between its ends, and every step costs edits, a step back included,
  with **Start Over** giving them back. Then the order of the steps is the
  puzzle.
- **Node Infiltration.** Cross a grid of nodes to the core before the moves run
  out, without a sentinel catching him. Every layout is made fresh and checked
  to have a way through.
- **Tuning the Resonance.** Turn up to three dials until his wave matches the
  thing's, then lock it.

How it plays out:
- **Tries** are written for an Intellect of 30. He gets more with more Intellect
  and fewer with less, never under one. Each retry's cost (**Strain** to his
  health, **Alert** on a stealth map, or nothing) shrinks the same way: twice
  the tries is half the cost a try.
- **Time Limit** gives each try a clock; 0 means none. On a stealth map, **World
  Keeps Moving** lets the guards carry on while he works; otherwise everything
  waits.
- **Gates** buy a **hint** (a line's answer, the way through, where a dial has
  to be) or **simplify** it once (no locks or balance, a sentinel gone, twice
  the tolerance). In a fight they come out of his gates there and then;
  elsewhere, out of the next fight's. The screen shows how many he has left
  through each gate. A hint is only paid for when it shows something new: on a
  step-by-step sheet, the next step is shown once for where the sheet stands,
  and the button waits for a move before it sells another. With no way through
  left this try, it says so, for nothing.
- **Failing** (out of tries, or walking away after a try has failed) can do any
  of these:
  - **Raises Alert** puts the stealth map up a level.
  - **Sets Off** makes the thing go off on him.
  - **Locks For Good** means it can never be tried again.

  Walking away (the button, Escape, the pad's back button or a right click)
  before a try has failed costs nothing.

Where a hack goes:
- **Any interactable** and **any picture hotspot** has a **Hack**: it does
  nothing until hacked, then works as usual and stays hacked.
- **A conversation:** `do Hacking.start("archive_ward")`, then
  `if Hacking.succeeded("archive_ward")`. A failure leaves flags to branch on:
  `Hacking.set_off_by(...)` and `Hacking.locked(...)`.
- **In a fight**, his **Hack** skill on a foe winding up a declared move:
  - won, the move comes to nothing and a boss is staggered
  - lost, it may go off early

  A declared skill can carry its own **Hack**; otherwise the Hack skill's is
  used (**Unpick the Spell**).
- **A thing on the map** (`BattleObjectDefinition`) with a **Hack** has to be
  hacked before it can be Used. Failing can set it off on the party.

Five examples stand near where the party arrives on the laboratory map
(Prometheus on the title screen): the Archive Ward, the Vault Terminal, the
Humming Seal, the Binding Circle (a hard Rewrite: its lines drag each other,
and the cheapest way through spends every edit), and the workbench's
strongbox, a hack-locked spot in a picture. Further down the room, five more
Rewrite sheets in rising order - the Furnace Seal, the Choir Lock, the Sluice
Engine, the Mirror Ward and the Clockwork Door - each with its fewest steps in
its prompt. The `hacking` suite checks every Rewrite sheet in `data/hacks/` can
be done within its edits, and that a step-by-step one cannot with any fewer.
Their numbers, and the Intellect the tries are written for, are
placeholders.

### Adding a fight

Right-click `data/encounters/` → **New Resource** → `EncounterDefinition`, give it a
terrain scene, then lay the combatants out in `tools/encounter_editor.tscn`:
select the encounter, drag the markers onto the map, press **Save spawns to
encounter**. It refuses to save anything unplayable and says what is wrong, so a
saved encounter always runs. **Add a way out** puts down a marker for a tile a
broken enemy runs for (see Getting away below); drag it into place, and Save
keeps those too.

Each spawn carries its own level, weapon base and defence, so the same character
can be brought in weak early and dangerous later. Those are what a fight from
Arena Mode uses. In the story, the party fights at the level it has reached
and with the gear it is wearing (see Levels and Equipment); a slot with nothing
in it keeps the spawn's own weapon or defence. A party spawn can also name the
**Subclass** (path) it fights on, from level 5.

**Party Reaches Level** makes the fight a milestone: won in the story, the
party goes up to that level. **Gold Reward** is what winning it pays, in the
story or a dungeon.

**Starting Items** on a spawn is what that fighter brings, picked from a dropdown
of the items there are. An enemy uses theirs: a potion is drunk when they are
badly hurt, a bomb or bottle thrown like any skill. Only the first four they can
use in a fight come with them (a pebble or a disguise is no use there). Look at
an enemy in a fight and their Items tab shows what they carry, which is what
Cyrus's **Steal** takes.

### Sizes

A combatant's **Size** is Tiny, Small, Human (the default), Large, Enormous,
Monstrous or Gigantic. A Human fills one tile. Each step down is half as wide,
so a Small one is half a tile and a Tiny one a quarter. Each step up is twice as
wide: Large 2 × 2 tiles, Enormous 4 × 4, Monstrous 8 × 8. Gigantic is 16 × 16 or
bigger: **Gigantic Span** says how many tiles a side.

- **Small and Tiny share.** Up to four Small or sixteen Tiny fit on a tile,
  mixed as they like, but only with their own side. An area catches all of them.
  A single-target skill hits whichever one the pointer was nearest.
- **Big ones cover a square.** A spawn's position is the top-left tile of its
  square. Every tile of the square is it: hitting any of them hits it, once. It
  is measured from, and reaches from, every edge. It walks only where the whole
  square fits.
- **Monstrous and up ignore the map.** Walls, holes and cover don't stop them.
  They move and see as a flier would, so only what stops a flier stops them.
  They still can't walk through anybody.
- **Bodies are cover by size.** Somebody blocks the view of anybody up to one
  size bigger than they are. A Human sees over rats, but an imp doesn't. Nobody
  Human sees past an ogre, but a behemoth does.

There's no shoving by size yet; a push moves a big one like anybody else, if
its square fits where it lands. The encounter editor draws each marker's
square and refuses a spawn that doesn't fit. **Big and Small** (lab map: rats, imps, an ogre,
a stone golem and a behemoth) and **The Colossus** (sixteen tiles across) in
Arena Mode show them all.

### Immunities, turns and auras

These belong to any combatant, boss or not, in their file:

- **Immunities.** **Immune To Conditions** lists conditions that never take
  hold; drag them in from `data/conditions/`. **Immune To** covers the rest:
  - being shoved or teleported
  - being stolen from
  - being weakened (a lowered stat or resistance)
  - lingering wounds
  - being studied
  - having their movement changed
  - having their boons dispelled

  A damage type is a resistance of 100. Whatever they shrug off shows "Immune"
  over them and says so in the log. The stone golem, an ordinary enemy, can't be
  poisoned or shoved.
- **Turns Per Round.** More than one puts them in the order again, spread
  through the round, with a face in the turn queue for each.
- **Auras** are on passives (**Aura Radius**, **Aura On Foes**, **Aura On
  Allies**). Whoever starts a turn within reach has that condition for the turn.
  The reach is tinted on the board: violet for the other side's, blue for the
  party's.

### Bosses

A combatant with a **Boss** (`BossDefinition`, in their file) is a boss,
whatever their size:

- **Its entrance.** When the fight starts, or when it arrives, its name and
  **Title** come up across the middle of the screen and its **Music** starts.
- **Its bar.** A bar of its own sits along the top: its health, with a mark
  where each phase begins, and its stagger bar underneath.
- **Phases** (`BossPhase`) begin as its health falls past each one's **At
  Health**, each announced across the screen. A phase can:
  - add or take away skills and passives
  - change how it fights (**AI Function**) or its **Turns Per Round**
  - swap its stagger bar
  - clear what's on it
  - gain or lose immunities
  - call help to its side (**Summons**)
  - start or stop arena hazards
  - change the music
- **The stagger bar** (`StaggerDefinition`) fills from whatever the fight wants:
  - **Per Damage**, optionally only for some **Damage Types**
  - **Per Hit**
  - **Per Blocked Condition**: the stuns it shrugs off
  - particular skills (**From Skills**)
  - more **While Readying** a declared move, which rewards interrupting it
  - a hazard catching it, or a thing on the map going off

  **Drain Per Round** turns it into a burst check. Full, the boss is staggered:
  - it loses its next turn (**Turns Lost**), whatever it's immune to
  - its declared move is cancelled
  - it's hit harder (**Damage Taken**) until that lost turn ends

  Then the bar starts again, bigger by **Grows By**. The **Hint** under the bar
  tells the player what to do.

Two examples in Arena Mode:
- **The Ash Warden** is Large, with two turns a round and an aura of choking
  ash. It has three phases: ash falling on the party, then imps arriving and a
  burst-only bar, and its armour cracks so it can be stunned at last. Powder
  kegs stand nearby.
- **The Bellkeeper** is half a tile wide and shrugs off every kind of control.
  Only its three bells fill its bar. In its second phase the floor rings and the
  bar switches to a burst bar.

All of their numbers are placeholders.

### The arena

An encounter's **Hazards** (`HazardDefinition`) run from the first round; a
boss's phase can start more. There are two kinds:
- **Falling** marks its tiles in magenta at the top of a round and comes down on
  them at the top of the next, so everybody has a turn to get clear.
- **Ground** is marked a round ahead too, then turns red and hurts whoever starts
  a turn on it until its time is up.

A hazard aims at open tiles anywhere, at the party, at anybody, or at fixed
tiles, every so many rounds. It deals damage of a type, can put on a condition,
and can **Stagger** a boss caught in it, so luring the boss under the rocks is
a tactic.

### Things on the map

A `BattleObjectDefinition` in `data/objects/` is a bell, a pillar, a keg:
something placed in a fight like a combatant, on the enemy side. It takes no
turns, belongs to nobody, never keeps a fight going, and blocks movement and
sight like a body its size.

- While anything usable is on the map, the party gets **Use** (the `use`
  skill): from beside it, the main action. Used on nothing, Use is refused and
  costs nothing.
- **Breakable** ones can also be hit until they go.
- Either way it **sets off**:
  - every boss on the field gains its **Stagger**
  - its blast (**Blast Radius**, **Damage**, **Condition**) catches whoever it
    should
  - once its **Uses** are spent, it's gone.

Hover one for its description. The bell and the powder keg are the examples,
with placeholder pictures in `art/objects/`.

### Dealing with enemies

There is more to a fight than hitting people. Everything below is a switch on
the creature (`CombatantDefinition`), a skill, or an encounter, so any of it can
be given to anybody. To try most of it, pick **Hired Blades** or **The Bound
Golem** from Arena Mode.

**Studying.** Enfina's **Measured Eye** (`studies_on_hit` on a passive) studies
whoever her blows land on, the way Study does. Only the Study skill opens the
character sheet; a blow just says so in the log.

**Intuition** is Alithia's secondary action. It reads an enemy's next turn
from the planner its turn would use - where it will stand, what it will use,
where it lands - and marks it on the map in teal. The enemy is then **held to
it**: step off the marked tiles and the blow lands on nothing; take the tile it
meant to stand on and it has to think again.

**Nerve.** Each enemy has a **Nerve** (Nerve group). What shakes it is added up
at the start of its turns:

| What | How much |
| --- | --- |
| its leader (**Leads**) down | 40 |
| half its side down | 25 |
| hurt / badly hurt | 15 / 30 |
| the last of its side | 30 |
| afraid (Fear) | 20 |
| Intimidated | what Intimidate shook |

At its Nerve or more it breaks: it **flees**, or **surrenders** where it stands
(**When Broken**). Immune to **Breaking** never breaks. The bosses are, and so
is the golem. The numbers are the `NERVE_*` constants in `combat/Combat.gd`.

**Ways out.** An encounter's **Escape Points** (The Arena group, placed with
**Add a way out** in the encounter editor) are the tiles a fleeing enemy runs
for. It gets away the moment it stands on one, however many turns that takes.

- It heads for the nearest by the ground it can cross.
- It spends its actions on getting there sooner: Run or anything else that adds
  to its walk, a blink that puts it nearer, and Slip Past when it is leaving
  somebody's reach.
- Somebody standing on a way out shuts it.
- Held (Grab), it has to break free first.

They are drawn on the map, brighter while somebody is running. Hired Blades has
two.

With no ways out, nobody gets away. A broken enemy says it looks for a way out
and finds none, then just keeps away from the party. Anybody placed in such an
encounter who would run when broken (When Broken: Flee, not immune to
Breaking) is named twice:

- in the encounter editor's status: a note, not a block on saving
- in Godot's Output when the fight starts

Fix it with a way out, or with When Broken: Surrender.

**Getting away.** What comes of one that flees is the creature's own **When
Fled**:

- **Gone**: nothing more.
- **Comes back**: back where it left, **Back After Rounds** later, its nerve
  steadied, with whoever **Brings Back** names. The Hired Bow comes back with a
  sellsword.
- **Fight lost**: the messenger who must not reach the gate. The fight ends in
  defeat, whoever is left standing.

**Fled Flag** is set either way, for a conversation afterwards. If the last
enemy runs, the fight is won before any of them come back.

**Taken alive.** Every enemy who falls is knocked out and taken alive. The
exceptions are anybody immune to **Being Taken Alive** (the golem) and anybody
who blew themselves up. After a won fight, the results offer **Question the
prisoners**, one row per kind that still has something to tell:

- whatever clues and gold they give up (Dealing With Them group)
- who they answer to
- leverage on their kind

Then **let go** or **hand over**, counted in the flags `prisoners_released` /
`prisoners_handed_over`. Between a dungeon's fights they are questioned before
the rest instead. A creature can have an **Interrogation Dialogue** of its own
in place of the plain questioning.

**Deciding in a conversation instead.** Tick **Dialogue Decides Prisoners** on
the encounter (When It Ends group). Its **Victory Dialogue** then decides, and
the results offer no questioning. The conversation can read how the fight went
and act on it. A key is a combatant key; leave it out for everybody:

| In the dialogue | What it does |
| --- | --- |
| `Campaign.taken_alive("sellsword")` | how many were taken alive and not yet dealt with |
| `Campaign.got_away("hired_bow")` | how many got away |
| `Campaign.fell("sellsword")` | how many fell for good (the party's own too) |
| `Campaign.questioned("sellsword")` | whether one has been questioned already |
| `do Campaign.question("sellsword")` | questions one, like the panel does |
| `do Campaign.let_go("sellsword")` | lets them go (a number after the key: only that many) |
| `do Campaign.hand_over()` | hands them all to the watch |

`dialogue/lab_hired_blades_after.dialogue` is the example, on Hired Blades.

**Intimidate, Persuade, Deceive** (Enfina, Alithia, Cyrus) are contested, and
only work on somebody the party has **leverage** on: their faction known, one of
their kind questioned, or a clue in their **Leverage Clues**. They live on a
**Skills** tab that only appears when one of them can be used on somebody in the
fight.

- Intimidate frightens and shakes their nerve.
- Persuade makes them lose a turn, unless they are hurt first.
- Deceive turns their next turn on the nearest of their own side.

**Bribes and parleys.** Somebody with a **Bribe Price** can be paid out of a
fight with **Bribe**, offered as a secondary action while one is fighting. A
conversation on an `EncounterInteractable` can settle things before the fight
with `do` lines, then `do Campaign.accept_encounter()`:

- `Campaign.parley_remove("sellsword", 2)`: two of them stay out of it
- `Campaign.bribe("hired_bow")`: one bought out
- `Campaign.bribe("sellsword", true)`: one bought onto the party's side, at
  twice the price
- `Campaign.parley_surprise()`: they start caught off guard
- `Campaign.parley_call_off()`: no fight at all, the trigger cleared as if won

Backing away drops what was agreed. `dialogue/lab_hired_blades_parley.dialogue`
is the example, on the lab map beside the sellswords' contract.

**Changing sides.** Somebody bought or rebound fights for the party, played by
the AI (`switch_sides`). They turn back when their turns run out, or when the
party falls.

**Rebinding.** A creature with **Bound To** and a **Rebind Hack** (the golem)
can have its binding hacked by Prometheus: Hack aimed at it plays the Rewrite
sheet, and if he wins it fights for the party for **Rebind Turns** of its turns
(0: the rest of the fight).

**Body parts.** Somebody big can have **Parts** (`BodyPartDefinition`): tiles
that can be aimed at, each with a share of their health. Broken, a part:

- **Rooted**: the legs go, and they never move again
- **Weakened**: the arms go, and every hit of theirs lands for less
- **Exposed**: an armour plate goes, and every hit on them lands for more
- **Staggered**: a boss's weak point, added to its stagger bar
- **Disarmed**: the skills in **Disarms** are gone

Parts are outlined while aiming, and the hit preview names the one aimed at. The
golem, the behemoth and the Ash Warden have them.

**Hurl** (Enfina and the Barbarian) grabs somebody beside you, up to one size
bigger (**Lifts Sizes Above**), and throws them **Throw Range** tiles, one more
for every 30 Physical. Thrown into somebody, both are hurt. Immune to being
thrown or shoved, nobody is picked up. The AI throws when it can hit two.

**Climb** (Enfina) climbs onto something Monstrous or bigger. Up there:

- nobody can reach her
- she is carried wherever it goes
- every blow on it lands, and 25% harder

It spends its main action trying to shake her off, which hurts whether it
works or not. **Climb Down** jumps off.

**Grab** (Enfina and the Barbarian) takes hold of somebody beside you, up to
one size bigger, as a main action or as a reaction. As a reaction it's offered
beside the swing when somebody leaves your reach, and the one grabbed is dragged
back and their walk ends. Grabbed, they're **Grappled** (a condition with
**Holds** ticked): they can't move, but can still act. **Break Free** is their
main action.

Getting hold and breaking free are the same contest, Physical against
Physical: 50% against somebody as strong, a point more for every point of
Physical more than the other (20-80%, the `GRIP_*` constants). Grab rolls it in
place of its accuracy, and the hover shows it. The grip also ends if:

- the holder is not beside them, is down, or climbs onto something
- either of them is teleported, shoved, thrown or blown along
- the holder grabs somebody else (one at a time)

Grab then Hurl is the throw that can't be walked away from. A held enemy fights
from where it stands if it can hit anybody from there; otherwise, or when it's
running, it spends its main action breaking free. Immune to the Grappled
condition, nobody is held.

**Taunts** are not a skill but something an encounter does: the **Taunted**
condition ties whoever has it to whoever put it on them, and anything of theirs
that hurts has to catch the taunter. The **Pit Champion**'s **Challenge** aura
is the example; a skill or an object's aura can put it on too.

### Quick time events

A `QuickTimeDefinition` (`data/quick_times/`) is a press against the clock.
There are four kinds:

- **Press**: one button
- **Sequence**: several in order
- **Mash**: one button, many times
- **Timing**: stop a sweeping marker in the zone

The four buttons are WASD, the arrow keys, or the pad's face buttons.

In a fight one hangs off a skill (**Quick Time**):

- **For the Attacker**, done in time, the party's use lands harder: Hurl's
  throw.
- **For the Defender**, done in time, it lands softer on the party: bracing
  against Ground Pound.

In a conversation:

```
do QuickTime.start("dodge_the_bolt")
if QuickTime.passed
```

It also sets the flag `qte:<key>`. The sellswords' contract on the lab map is
the example. Headless (the tests), nobody can press anything, so it counts as
missed: the game as it was before.

### The enemy codex

The Journal's **Enemy Codex** has a page for every enemy in `data/enemies/`,
written when somebody with **Keeps Codex** (Enfina and Prometheus) studies one,
by Study or by Enfina's blows. A boss has a second page, written when one of
them studies it again past its first phase (or, with no phases, while it is
staggered). It shows the boss's **Codex Second Page** text, its phases and its
stagger bar. The pages are worked out from the creature itself (`CodexPage`), so
they never disagree with it. They are stored as flags (`codex:<key>`), so they
are saved.

### Making a dungeon

A dungeon is fights one after another with a rest between each - the **Dungeon
Demo** on the title screen is `data/dungeons/dungeon_demo.tres`, a
`DungeonDefinition`. Open it in the inspector:

* **Party** - who goes in, leader first, and their **Level** - on the maps and in
  every fight; the fights' own tiles' levels are not used. The maps'
  own parties and handed-out kit are not used: the party starts carrying
  nothing, and keeps whatever it picks up and does not use.
* **Stages** - in order, each a `DungeonStage`: a **Map** to walk until its
  fight, or none to go straight into the fight. **Encounter** is the fight;
  on a map it is fought instead of the one the map starts by itself, named in
  **Replaces** - so the map keeps its conversations and loot, and only the fight
  at the end is the dungeon's. The demo's three are copies of the story's fights
  in `data/encounters/dungeon_demo/`, every player tile and enemy at level 20
  (with the City Fight's weapon base and defences), two more enemies in
  the sewer and three fewer in the city.
* **Resting** - after every fight but the last, everyone is back to full health
  (and back on their feet, with **Rest Revives**). Gates spent stay spent from
  one fight to the next; the rest offers to bring some back for whoever is in
  **Gate Recovery For**, at **Gate Recoveries** rests in the run, with **Gate
  Recovery Points** to spend at **Gate Costs** each (0, then World, Hermes,
  Yaldabaoth). With a **Store**, the rest offers a visit to it, to spend what
  the fights' **Gold Reward** paid.

Winning a stage's fight plays its own closing conversation first, then the rest,
then the next stage. Winning the last ends the dungeon and goes back to the
title screen; losing any of them offers to start the dungeon again.

### Levels

There are 20 levels. A level decides a character's attributes (the main one
climbs from 10 at level 1 to 85 at level 20, the secondary half that), their
health (**Max Hp** at level 1 to **Max Hp Level 20**, the same step each level),
their gates (`Stats.GATES_BY_LEVEL`: Hermes opens at 5, Yaldabaoth at 9) and
which of their skills they know (each skill's **Required Level**). The old three
levels map onto it: level 2 is now 10, level 3 is 20.

The party levels up at milestones in the story, not by experience: a
conversation saying `do Campaign.reach_level(5)`, a fight whose **Party Reaches
Level** is set being won, or walking onto a map whose MapSetup **Level** is
higher than theirs (a map's level is the least the party is by then). Health
grows by what the level adds, so a wounded party stays as wounded.

### Paths (subclasses)

At level 5 each of the party chooses one of three paths, for good - Cyrus's
Swashbuckler, Gunner and Bombardier; Prometheus's Spellsword, Demolitionist and
Abjurer; Alithia's Punisher, Carer and Illusionist; Enfina's Berserker, Guardian
and Controller. The map asks once nothing else is going on, one of the party at
a time; the character sheet has a **Choose a path** button too. A MapSetup with
**Asks For Paths** off (the stealth stages) never asks.

A path is a `SubclassDefinition` in `data/subclasses/`: a description, the
**Skills** it teaches (each at its own Required Level) and its **Passives** (each
from its own **Required Level**). Which paths are whose is the character's
**Subclasses** list, in the order the choice shows them. Most of what a path does
is a switch on a PassiveDefinition - more movement or defence, a skill reaching
further, a free item every fight, a step after a skill, amplified spells, a ward
reaction, overheal, stronger heals, being empowered by a condition, guarding
allies - so a new path is mostly ticking boxes. New ones need no code.

Overheal is health on top of health: taken first, never stacking, gone by the
end of the fight. An image (**Mirror Image**) is one point of health and no
turns; enemies go for it as they would for whoever it is of. **Confused**
(`data/conditions/confused.tres`) plays its victim's turn for them, at whoever is
nearest, friend or foe.

### Factions

An enemy's **Faction** names a `FactionDefinition` in `data/factions/`. A clue
with the faction under **Reveals Factions** makes the party know it: from then
on every member has their sheet open from the start of a fight, and the party
hits them harder by **Known Damage Bonus** (0.15 to start). No enemy has a
faction yet - which sides there are is the story's to say.

### Equipment

A weapon, armour and a charm for each of the party: `EquipmentDefinition`s in
`data/equipment/`. A weapon's **Weapon Base** and armour's **Defense** stand in
for a story fight's own numbers; a charm adds its **Passive**. Armour is **Light**
or **Heavy** - a label for now, both wear the same. **For Characters** limits who
can use it. Gear the party owns and is not wearing waits in a shared stash; put it
on from the character sheet (C), a button a slot. Give gear with
`do Campaign.give_gear("fencers_rapier")`.

### Gold and stores

One purse for the party (`Campaign.gold`, shown on the inventory screen). Fights
pay their **Gold Reward**; a conversation can `do Campaign.give_gold(30)`. A
`StoreDefinition` in `data/stores/` lists its **Stock** (items and gear alike)
and buys back at its **Sell Rate** of the price. Prices are the goods' own -
**Price** on an ItemDefinition or EquipmentDefinition - so a thing costs the same
everywhere; 0 means no store deals in it. Open one with a **StoreInteractable**
on a map, `do Campaign.open_store("travelling_merchant")`, or a dungeon's
**Store**. Bought items go into the bag of the first of the party with room;
bought gear into the stash.

### Saving

Escape → **Save Game** on any map that is not a stealth map, never in a fight:
three slots. Before every fight begun from a map - or a dungeon's fight with no
map - the game saves on its own, into the oldest of three automatic slots; a
fight begun on a stealth map saves the moment the party walked onto it. **Load
Game** in the pause menu and on the title screen loads any of the six, and
**Continue** the latest. Saves are in `user://saves/`. Everything the run has come
to is in one - `Campaign.snapshot` - and loading puts the party back where it
stood (`Campaign.restore`).

### Making a stealth map

A stealth map is an exploration map with guards on it, played in real time: the
party has to stay out of their sight, and if a guard is sure of them, the fight
starts right where everyone is standing.

**To try one**, open `demos/try_stealth_demo.tscn` and press **F6**: Cyrus in
the lab, a locker with a disguise in it, a notice board to look at closely
(the point-and-click example), and four guards between him and the far corner
- a Priest who knows his own robes, a Barbarian no disguise fools, a hall sentry who stands his post, and one any
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
- **Planting evidence.** Something with **Frames** ticked (the Stolen
  Signet) can be slipped into the pockets of a guard who hasn't noticed you.
  It's the pick-pocket key, once there's nothing left to lift.
  - The next watchman or captain to get a good look at him (2 seconds in view,
    within 4 tiles) finds it and marches him off.
  - Neither can be drawn aside on the way. The framed one is gone for good, and
    the other is back on his beat after 12 seconds.
- **Guards at a post.** A guard with no **Patrol** stands where he is put.
  **Glance Every** above 0 holds his gaze still instead of sweeping it, and now
  and then (that many seconds, give or take a third) he glances **Glance
  Degrees** aside for **Glance Seconds**. A post you can time. The demo's east
  Barbarian and hall sentry stand like this.
- **What small talk can ask.** A guard's **Small Talk** conversation can call
  `Campaign.stealth_watch`:
  - `.send_away(30)`: off to the far end of the beats for 30 seconds
  - `.tell_patrol()`, or `.tell_patrol("OtherGuard")`: his round, or another's,
    drawn from now on
  - `.hand_over()`: what's in his pockets, as if picked

  The demo's east Barbarian offers all three.
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
