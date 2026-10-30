# Where we are

A handoff for a new Claude session, local or in the cloud. Read this, then
`CLAUDE.md` (which a session loads by itself) and the plans named below. Last
updated 2026-10-30, after Steps 2 and 3 of the network play (LAN, and online
by UPnP), the designer's additions to it, and the placeholder projectiles.
Steps 4 and 5 wait on the designer.

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
- Tests: `tests/run.sh` (all 141 suites) or `tests/run.sh outside familiar`.
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
2. **LAN** (`multiplayer/Net.gd`) - built 2026-10-30 (CLAUDE.md "Network
   play"; suite `net`, which starts a second headless Godot). What is in it:
   - hosting, joining and finding games, and seating players across machines;
   - joining a game under way, a fight too, and following the host's scene and
     Campaign;
   - walking together, the joiner's presses done on the host, and what it aims
     or chooses on its own screen;
   - pings both ways, and the host's guards shown on the joiner;
   - menus that stop nothing over a network, and what the joiner's menus change
     going to the host;
   - fights replayed from the moves with a checksum;
   - conversations whose answers both pick;
   - whom each plays, chosen on joining and changed by asking (Party
     Management), and the host kicking;
   - the familiar, hacks and quick times across;
   - leaving mid-fight.

   Still to come: trying it on two real machines. Not across yet: the
   point-and-click pictures, stores, and a dragged body's pace
   (`docs/multiplayer_plan.md` "Added after Step 3").
3. **Online by ENet + UPnP** - built 2026-10-30: hosting asks the router to
   open the game to the internet, and the Players panel names a virtual LAN
   app (Tailscale, ZeroTier, Radmin VPN) when it will not. Not yet tried
   against a real router.
4. **WebRTC on desktop** - once the designer has a signalling server and a TURN
   relay hosted.
5. **Steam** (GodotSteam) - once the game is on Steam.

The designer answered Step 2's two questions (2026-10-29): a player leaving
mid-fight hands their characters to the other player, not the AI; and over a
network an open menu does not stop the world carrying on (local co-op still
holds the game for both).

## Done recently (newest first)

- **Placeholder projectiles** (the designer, 2026-10-30, "go ahead with what you
  suggested ... add traces following behind"): `combat/Projectile.gd`, CLAUDE.md
  "Projectiles", suite `projectile`. Every move but a melee blow, one at its
  user's own tile or one that moves somebody is seen going from its user to
  where it was aimed:
  - an orb in its element's colour, a trail behind it, a burst where it
    lands;
  - a bolt, an arc over what is in the way, a streak along a line, or a fan of
    three for a cone.

  The blow lands as it arrives. Each move has Projectile Style, Texture, Scene
  and Colour slots. The designer also asked for ways to make moves land
  harder: `docs/move_feel_proposals.md` (all PROPOSAL).
- **The designer's additions to network play** (2026-10-30;
  `docs/multiplayer_plan.md` "Added after Step 3"):
  - The joiner chooses whom to play on joining; the host keeps at least one.
  - Party Management in the pause menu, on a map and in a fight: a change is
    asked of the other player, and made only if they agree. In a fight it
    waits for one of the host's characters' turns and goes with the moves.
  - The host can kick the joiner out.
  - Conversations: both pick the answer; picked differently, both pick again.
  - A joiner seated mid-fight comes into the fight: it plays it through from
    its beginning, fast, until it stands where the host's does.
  - What the joiner aims and chooses on a map is its own, on its own screen,
    and only the result goes to the host: a throw, a click on a guard, a
    readied cone, the guard a move is used on, who goes unseen, the Outside
    Spell's choice.
  - Alithia's familiar is shared.
  - A hack or a quick time on a map is played by whoever it is for. Over a
    network neither pauses.
- **Online by ENet + UPnP** (network play Step 3): hosting asks the router to
  open the game's port (on a thread), the Players panel shows the address to
  send or points at a virtual LAN app, and the port is shut on leaving. The
  suite checks the panel, not a real router.
- **LAN, the first part** (network play Step 2, items 1-2): the `Net` autoload
  hosts and joins over ENet, a host's beacon is heard by Look for games, the
  joiner is seated as the second player on its own machine, whom each steers is
  the host's to set, and a machine leaving takes its player with it. The
  Players panel has the network half. Suite `net` plays the joiner in a second
  Godot. Then the joiner follows the host: it joins a game under way onto the
  host's map, goes wherever the host goes, has the host's Campaign, and goes
  back to the title screen when either leaves. Then the two walk together
  (each group walked on its own machine, the other's a puppet), the joiner's
  E, G, Tab and stealth keys are done on the host as the joiner's player, and
  pings go both ways. Then guards: on a watched map only the host's watch
  decides, and the joiner's guards, doors and lamps show what it says. Over a
  network a menu stops nothing (the designer's answer) - only that machine's
  own party stands. Then fights: played on both machines from one seed, each
  player's moves sent to the other, questions answered on the decider's machine,
  and every turn checked to be the same on both. Conversations run on the host
  and are shown on the joiner, who chooses when it is theirs. A player leaving
  mid-fight hands their characters to the other (the designer's answer).
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
   The additions of 2026-10-30 were built with these defaults (PROPOSAL):
   - the host keeps at least one character when the joiner chooses;
   - over a network, whoever began a conversation presses on through its
     lines, and plays any quick time in it;
   - local co-op still lets whoever began a conversation choose (the
     designer's "both pick" was about a network game);
   - a fight joined under way is played through at 8 times the speed;
   - a change of hands in a fight waits for one of the host's characters'
     turns.
7. **Projectiles and how moves feel:** the projectiles' timings (0.16-0.5 s
   by distance, a fifth longer for an arc) and the Automatic styles are
   PROPOSAL. The ways to make moves land harder are all in
   `docs/move_feel_proposals.md`, its "What to try first" a suggested order -
   the designer picks.
8. **OPEN rows in the ledger**, among them:
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
