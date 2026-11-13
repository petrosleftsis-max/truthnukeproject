# Work for Fable

Written on 2026-11-13 by the Claude Code session that built the light and the weather, for a fresh session on Claude Fable. Read this
first, then `CLAUDE.md` (the project's rules and its map of the code) and `docs/where_we_are.md`. The first job is the one the designer
and their artist chose; the others are worth doing when it is done, or alongside it if the designer says so.

## Ground rules (the designer's; they hold for every job)

- Numbers you bring in are PROPOSAL until the designer approves them. Balance is theirs: never retune a skill, an enemy or a price to
  make a test pass, and never bend a test to pass.
- Art is the designer's and their artist's. Whatever you draw is a placeholder behind a slot (a path where their picture takes its
  place), and the size they should draw it at is written down.
- Fight rolls come only from `Combat.rng`. `combat/Combat.gd` and `control/CController.gd` call no global `randf`, `randi` or `shuffle`
  at all, even for something only to look at: the `rolls` suite reads them as text. Elsewhere, view code may.
- Enums are append-only. The renderer is gl_compatibility, Godot 4.7.2: a canvas shader gets no particle's own position from a
  CPUParticles2D, and reads the screen only through a BackBufferCopy.
- Tests: `tests/run.sh` for all of them, `tests/run.sh <suite>` for one; `tests/suites.txt` lists them. Give each run its own
  `MOT_TEST_WORK` and `MOT_TEST_USER_DIR`; never two runs in one work folder, never the `net` suite in two runs at once (fixed ports).
  Read the `_err.txt` logs as well as the summary.
- After adding a `class_name` script or a picture, run `godot --headless --path . --import` in the project, but only when no editor
  has it open, and commit the `.uid` and `.import` files: the designer starts the game from the Project Manager, which scans nothing.
- Committing means pushing to GitHub, on main. Nothing goes to itch.io.
- Leave the designer's own Godot windows alone; run builders and tools in a scratch copy.
- Another Claude Code session may be working in this folder. The designer says who has which files; don't edit the same ones.

## Job 1: 2.5D, depth with the art we have

**What was chosen.** Section 22 of `docs/proposals_2026-11-07.md`: A, B and C together, chosen by the designer and their artist on
2026-11-13 after seeing one courtyard drawn each way (https://claude.ai/artifact/L8hZ6z3w7b3n9TNPsaMKYH, drawn in plain shapes, not the
game's art; the designer can open it). D (isometric) and E (a 3D stage) were not chosen.

**It is only how things look.** The rules already know who is up (CLAUDE.md "Heights"); who can see, reach or walk where must not
change.

### What there is to build on

- **Tiles:** 256-pixel squares, in one `TileMap` (layer 0) per terrain scene. The TileSet (`maps/tilesets/terrain_tileset.tres`) has
  custom data Cost, Blocks and Climb: Climb marks high ground, Blocks what stops walking, sight and light.
- **Heights and floors:** CLAUDE.md "Heights", CController "Heights" and "Floors on the screen": `climb_tiles`, `is_high`, `comb.up`,
  `raised_at`, `Combat.elevation`. Floors are separate regions of the same TileMap, one shown at a time.
- **Figures:**
  - In a fight, figures stand in a y-sorted `Combatants` layer under the TileMap (`Combat.combatant_layer`), sorted by where their feet
    are. Their lift for height is the sprite's own `offset`, and stepping on or off high ground arcs (`CombatantSprite.hop`, CController
    "Hops").
  - On a map, the party is drawn by `ExplorationParty` at a fixed z (`PARTY_Z_TOP`), not sorted with the world.
- **Light** (`combat/LightView.gd`):
  - The shade is drawn a pixel a tile, under the figures. The lights are real `PointLight2D`s, with shadows from occluders made from the
    Blocks tiles. Over and under the ground go the sky's layers and the ground's own: wet, snow, water, mist.
  - Its order matters: what lies on the ground is drawn before the shade, what hangs in the air after it.
  - `CombatantSprite` lights and shades the figures: rim light, shadows leaning with the sun (`shadow_lean`), `light_points`.
  - Normal maps are used already wherever the art has them (`docs/light_on_maps.md`, "Normal maps").
- **Maps:** exploration maps instance a terrain scene, and a fight loads its encounter's terrain, so anything put on a terrain shows in
  both. The stealth stages are made by `tools/build_stealth_stages.gd`. Stage 9, the Light stage, is where to show this work: it has a
  yard, a roofed hall with windows and a dark cellar, and raised ground can go in its yard.

### What to make

- **A. Raised ground, shown.**
  - Where high ground has lower ground to its south, draw a face under its edge: a cliff, a crate's front.
  - Throw a shadow down off its edge onto the low side, leaning with the sun.
  - Draw figures up there higher; much of this exists.
  - Sort the nearer figure over the further one, on maps as well as in fights.
- **B. Layers and parallax.**
  - A map can have pieces in front (an arch, a roof, a balcony, a tree) that move a little against the ground as the view moves, and
    pieces behind that move the other way.
  - Whatever stands in front of a figure fades while the figure is behind it.
  - Probably a node to place for it, the way the other map nodes are placed, with how far it moves and whether it fades.
- **C. Light that knows height.**
  - Shade the foot of every wall.
  - Light walls from the side they face by the lamps near them.
  - Throw shadows down off ledges.
  - The figures' rounded light exists already.
  - Use normal maps once the art has them, and a drawn stand-in until then.

Every picture this needs gets a slot and a size for the artist: faces and ledge shadows for each kind of ground, the pieces in front, and
anything for the foot of walls that code doesn't draw. The interface page's "Art to ask for" table shows the form they're used to.

### What done looks like

- **The Light stage shows all three:**
  - raised ground with its faces and shadows;
  - a roof or an arch that fades when the party walks behind it;
  - layers that move as the view does;
  - walls shaded at their feet and lit from the side by a lamp.
- **Every existing map and fight still draws right:** no faces where there is no high ground, nothing fading where nothing is in front.
- **It works everywhere:** in a fight and on a map, by day and by night, and in every weather.
- **Tests and pictures:**
  - a suite for what it decides (which tiles get faces, what fades and when);
  - the full pass clean;
  - screenshots before and after for the designer.
- **Docs:**
  - a section in CLAUDE.md;
  - a how-to for the designer in the manner of `docs/light_on_maps.md` ("Putting depth on a map");
  - a row for each decision in `docs/design_status_ledger.csv`, with its 13 columns.

A suggested order: A, then C, then B. A and C need nothing new on the maps; B needs the new node and things placed with it.

## Other jobs worth Fable's time

### Level-64 balance: proposals only

The party beats Sixty-Four (`data/encounters/level_64_showdown.tres`) too easily. Whoever acts first wins; area spells and Illusory
Guardian carry it; party health at 64 is still undecided. `docs/progression.csv` is the power level everything is pitched against.

What to do:
- Use the lab (`docs/lab_sequence.md`, the `aicompare` probe in `tests/probes`) to find out why.
- Come back with proposals and their numbers, each a PROPOSAL row in the ledger.
- Change nothing in the data: the designer sets the numbers.

### A deep review of `combat/Combat.gd`

It is about 20,000 lines of rules. Look for two kinds of problem:
- **Rule bugs:** where the code and CLAUDE.md or the docs disagree.
- **What would make two machines differ in co-op:**
  - a roll outside `Combat.rng`;
  - an order that depends on how a Dictionary was filled or where a node sits in the tree;
  - a decision only one machine makes;
  - time or frame counts inside a rule.

Report each one with its file and line and why it's wrong. Fix the clear ones, with a test for each.

### Performance, only if the game feels slow

The light and the weather now draw many layers. The shade reads the screen, the grade copies it, and there are particles, reflections,
water and mist on top. Measure on the designer's PC and in the web build before changing anything, and keep every look as it is.
