# Where we are

A handoff for a new Claude session, local or in the cloud. Read this, then
`CLAUDE.md` (which a session loads by itself) and the plans named below. Last
updated 2026-10-30, during Step 2 of the network play (LAN: hosting, joining
and players built).

## How the designer works with Claude

- Only what the designer approves is built. Anything else is a PROPOSAL,
  written into `docs/design_status_ledger.csv` (13 columns; add rows as text so
  the other rows are not re-quoted). When asked to "suggest before building",
  answer in chat and build nothing.
- Report mismatches between docs and code; never change code to match a doc.
  Never edit `docs/handoff_0.1/`.
- Files are written without a BOM and with LF line endings. Refer to the
  designer as they/them.
- Commit and push at the end of every piece of work. Kill processes by pid.
  Never shut down or restart the computer.
- Tests: `tests/run.sh` (all 139 suites) or `tests/run.sh outside familiar`.
  In the cloud, five suites fail on untouched code too, for environment
  reasons: audio, encmusic (the music `.wav` files are not in git), gear,
  editor, sweep. Locally, with the music present, audio and encmusic may pass.
- `tools/context/decisions_part.md` and `rules_part.md` feed
  `docs/perplexity_combat_context.md`. Rebuild it with `tests/run.sh refdump`,
  then `perl tools/context/rebuild_context.pl <work>/logs/refdump_data.md`.

## Next to build (approved, 2026-10-29)

The designer wants all of the network play, and is carrying on with it in a
local session. **`docs/multiplayer_plan.md` is the plan** - decisions, then
Steps 0-5 with what to change where and how to test it. In order:

0. **Download only** - done 2026-10-29: `tools/release.sh` builds Windows,
   macOS and Linux (the designer asked for the last two the same day);
   CLAUDE.md "Releasing" and the README's "Exporting" match.
1. **The seeded fight RNG** - done 2026-10-29: every roll in a fight through
   `Combat.rng`, seeded from the encounter's "seed" (CLAUDE.md "Rolls in a
   fight"; suite `rolls`).
2. **LAN** (`multiplayer/Net.gd`) - under way (2026-10-30): hosting, joining,
   finding games and seating players across machines are built (CLAUDE.md
   "Network play"; suite `net`, which starts a second headless Godot). Still to
   come, in the plan's order: the host's scene and state followed, walking
   synced, the joiner's presses played on the host, guards run by the host,
   fights replayed from the moves with a checksum, conversations mirrored,
   menus, pings, leaving.
3. **Online by ENet + UPnP**, with a virtual LAN app (Tailscale, ZeroTier,
   Radmin VPN) as the fallback players are told about.
4. **WebRTC on desktop** - once the designer has a signalling server and a TURN
   relay hosted.
5. **Steam** (GodotSteam) - once the game is on Steam.

The designer answered Step 2's two questions (2026-10-29): a player leaving
mid-fight hands their characters to the other player, not the AI; and over a
network an open menu does not stop the world carrying on (local co-op still
holds the game for both).

## Done recently (newest first)

- **LAN, the first part** (network play Step 2, items 1-2): the `Net` autoload
  hosts and joins over ENet, a host's beacon is heard by Look for games, the
  joiner is seated as the second player on its own machine, whom each steers is
  the host's to set, and a machine leaving takes its player with it. The
  Players panel has the network half. Suite `net` plays the joiner in a second
  Godot. Nothing of the game itself is shared yet (scenes, walking, fights).
- **The seeded fight RNG** (network play Step 1): all 16 rolls in Combat.gd
  through `Combat.rng`, seeded from the encounter's "seed" meta or at random;
  `fight_state()` writes a fight down for a replay to be checked by. Suite
  `rolls`. For one player nothing changes.
- **Download only, for Windows, macOS and Linux** (network play Step 0):
  `tools/release.sh` builds the three (no browser build), packs them
  (`.zip`, `.tar.gz`, the Mac's own `.zip`) and pushes the channels `windows`,
  `linux` and `mac` to itch. The Mac build is signed ad hoc, not notarized, so
  macOS asks before it first opens. Neither has been run on a Mac or a Linux
  machine yet.
- **Local co-op, two players** (`multiplayer/Coop.gd`, CLAUDE.md "Co-op",
  suite `coop`): Players on the title screen and the pause menu; a group
  each on a map, one camera, a leash; turns, menus and conversations go to
  whoever's they are; a player left steering nobody is offered the party to
  share out. **Pings** (Z; in co-op a pad's Share). The other player can ask
  Alithia's player for her familiar (Tab) while it is off her shoulder.
  LAN and online are not built.
- **The readied "steps into an area" trigger is a great cone** (12 tiles,
  respects blocking), in fights and on maps.
- **Breakable walls act as walls** until broken (sight for every size, cover,
  guards' routes, nothing aimed at them but a wall-breaking blow).
- **Smarter enemy readies** (PROPOSAL): scored by what they would do; casters
  only within reach; the cone down the party's way in; Protects Its Own on the
  Ranger and the Hired Bow.
- **Stay Here** (X / pad Touchpad) and **moves readied on a map** (lost when
  out of sight).

- **Moves outside a fight, all three phases** (`docs/outside_combat_plan.md`;
  `exploration/OutsideMoves.gd`, `ui/outside_moves_panel.gd`; suite `outside`).
  - The map's action bar shows the leader's moves, gates and noise.
  - Each skill has an Outside Use: mend, revive, speed, blind, scare, confuse,
    read, switch off magic, ambush or break a wall, blink, fly, lure, hiding
    spot, trap.
  - Marks: Out Of Combat (lets the spell pay from Iris first) and Noise.
  - U (pad Share) hides the UI.
- **Find Familiar** works on any map (`exploration/FamiliarKeeper.gd`). E while
  steering sends it to Alithia's shoulder. The first casting after a long rest
  is free.
- **Magic sensors** (`Guard.Kind.SENSOR`) and **small gaps** (Blocks 4) on
  stealth maps.
- **Paths** change only at a long rest. The character sheet was redesigned
  (Sheet / Moves / Levels).
- **Disarm, Deep Corrosion and Light Swing** handoff done.

## Waiting on the designer

1. **Outside moves, PROPOSAL values** (ledger):
   - durations: blind 12 s, scare 15, confuse 20, switch off 60, fly 20, cover
     60; hurry x1.5 for 20 s (Quicken 60);
   - the 30 s cooldown on gateless moves;
   - Iris paying first for marked spells;
   - heals landing on the worst hurt (no picker);
   - the ambush opener being free;
   - walls breaking to any damage;
   - U / Share for Hide UI;
   - lures landing ahead (no aiming yet).
2. **Moves not placed in the outside table yet:** Cleanse, Persuade, Deceive,
   Steal, Hack, Catalyst, Trailblaze, Grab, Slip Past, Sanctuary of Light,
   Recant, Illusory Dragon, Grand Design.
3. **Spells to mark Out Of Combat, and Noise for every move:** 142 moves have
   none set.
4. **Find Familiar values:** learned at level 1; the rat, cat and raven numbers;
   a sensor raising the alert a whole level.
5. **Secondary stats** (asked about earlier, answered in chat, no decision yet):
   more uses for each secondary stat, a table of which stat each contest
   tests, and a stat point system that does not depend on gear.
6. **Multiplayer values:** local co-op is built with the plan's defaults
   (PROPOSAL) for its open questions. Also open: which pad button pings (none
   is free; Share for now in co-op), the 10-tile leash, the 12-tile cone, and
   which enemies Protect Their Own. The network itself is approved - see "Next
   to build". **Itch is left alone** - nothing published, the page untouched -
   until the designer says (2026-10-30: more work on the game first); then the
   browser version comes off and the Mac and Linux builds go up. Shipping the
   music as Ogg Vorbis, and notarizing the Mac build (an Apple developer
   account), are theirs to decide (`docs/multiplayer_plan.md` Step 0).
7. **OPEN rows in the ledger**, among them:
   - Deep Corrosion's duration (5 vs the handoff's 3);
   - Corrosive Round at 41 equal to the Gun;
   - Venom Fan vs Exposing Shot;
   - Tripwire's burst;
   - Resuscitate's gate;
   - boss control resistance.

## Good to know

- To try the familiar with guards: Stealth Stages, stage 8, The Familiar
  (Alithia and Cyrus at level 10; grates, an arcane ward, a cracked wall).
  It is built by `tools/build_stealth_stages.gd` (`stage_familiar`). Or use any
  story map she is on; the familiar works there now, without guards.
- A map that is not a stealth map names its familiar's animal in its
  MapSetup's Familiar Form.
- The designer works on Windows. Godot is found by `tools/find_godot.sh`.
  Close Godot before pulling, so the editor does not write old scripts back.
