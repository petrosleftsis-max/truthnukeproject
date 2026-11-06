# Where we are

A handoff for a new Claude session, local or in the cloud. Read this, then
`CLAUDE.md` (which a session loads by itself) and the plans named below. Last
updated 2026-11-06, after the designer's message of that day (see "Done
recently"); before that 2026-10-31, after Steps 2 and 3 of the network play (LAN, and online
by UPnP), the designer's additions to it, the pictures, stores and dragging
across the network, the placeholder projectiles, and everything in
`docs/move_feel_proposals.md` but moves coming down from above or up from
below - and then pictures searched together, stores shared, and the camera
drawn to the other player's conversation; then the designer's round of
2026-10-31: co-op on one screen under the network's rules (a picture both
players', a pointer each; the camera drawn to a conversation), Party
Management for whoever joins and with portraits, the host's address copied with
a button, the familiar's own key, attacking moves starting placed fights, the
outside Spells tab as the fight's with the Gates of Iris, Invisibility only
there, and Cover Leap gone. Steps 4 and 5 wait on the designer.

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
- Tests: `tests/run.sh` (all 160 suites) or `tests/run.sh outside familiar`.
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
   - the point-and-click pictures and stores, opened on the screen of whoever
     they are for, and a dragged body's pace and creeping on the joiner's own
     screen (2026-10-31);
   - pictures both players search together, stores both shop at out of one
     purse, and the camera drawn to the other's conversation (2026-10-31);
   - one player to a machine, on any device; their own lead and camera, no leash;
     zoom, sheets and faces open on anybody's turn; the other's character walking
     smoothly; the same conversation on both; each other's tile in a fight
     (`PROTOCOL` 6, 2026-11-05);
   - leaving mid-fight.

   Still to come: trying it on two real machines (the README's "Two players"
   says how, one PC included).
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

- **The designer's message of 2026-11-07** (ledger rows of that date; CLAUDE.md "Aimed on a map", "Letting go of a
  tether", "Ways of its own", "All Knowing", "Light", "The clock and the calendar"; `docs/light_on_maps.md`;
  suites `aimed`, `letgo`, `ways`, `newspells`, `clock`; stage 9):
  - Damaging moves and traps on a map are aimed (MapAim). A hit starts the fight and whoever it hit takes it before
    anybody's turn. A wall takes no fight. The Great Snare is aimed, and a trap that bursts starts a fight.
  - A right click on what a tether holds ends it, at any point. Another player's needs them to agree.
  - A fifth level of smarts, All Knowing, reads the party's kits and prepared spells. The Ash Warden has it.
  - Commanders, grudges, hunters, bodyguards, packs, fears, learning, greed, moods by phase, per creature.
  - Alithia: Sleep, Calm, Suggestion, Detect Magic, Arcane Eye. Prometheus can learn Mesmerise.
  - All the light ideas, projectiles giving light, illusions stopping or giving light, a clock and a calendar, time
    seen going by, and a stage to look at all of it.
  - Phantom Wall is placed by two points, along eight directions, up to its length of five, and is drawn along
    the line it was placed on, a diagonal corner to corner.
  - Fallen Friend is a reaction now: a blow that would fell an ally never lands, and they go down looking dead.
  - Alithia has Unbowed I-VII: Fear at 1, Confused 8, Compelled 16, Blind and Deafened 24, Dazed 33, Choking Ash 46,
    Stunned 56.
  - Illusions are seen through one by one: her side walks through a Phantom Wall or across False Ground, and whoever
    of the other side sees that, and anybody Trained or smarter, ignores that illusion from then on (Combat "Seen
    through, one by one").
  - A fight with nobody in it no longer starts: a ward that is sure, with nobody left who would fight, raises the
    alert once instead.
  - Going without tiles: three sizes of it in `docs/proposals_2026-11-07.md` section 13. Nothing built.
- **The designer's message of 2026-11-06** (ledger rows of that date; CLAUDE.md "Illusions", "The AI's mind",
  "Light", "Sounds", "Spells have no levels"; suites `illusions`, `aimind`, `light`, `audio`):
  - Sounds: all of `docs/sound_plan.md`, placed as they are and kept off GitHub.
  - Light: Bright, Dim, Dark; Ambient; time of day changing during play; lamps, braziers, lanterns, Burn.
  - Nine illusions on the Illusory Shepherd's path: Phantom Noise, Phantom Wall, Seeming, False Ground, Phantom
    Killer, Fallen Friend, Phantom Company, Mislead, Weird. Cyrus can put on a fitting disguise while hidden.
  - The enemy's mind: all 14 ideas, four levels of smarts, and four dials per creature.
  - Mindfulness contests on Ecstasy and Terror. Fireball gone, Wildfire in its place. Spells have no levels.
- **The designer's lists of 2026-11-05** (ledger rows of that date; CLAUDE.md "Shoves, foreseen",
  "Spells and what they rest on", "Preparing spells", "What opens and closes a fight", "Join
  codes"; suites `enchant`, `spellstwo`, `outsidespells`, `preparespells`, `shoveaim`, `hazards`,
  `fightcards`, `joincode`):
  - Alithia's Compel, Steady Heart, Ecstasy, Silence, Mesmerise, Restorative Aura, Four Reflections
    (Illusory Shepherd), Composure, Clear Sight, Terror, Elemental Ward, Shared Burden. Prometheus's
    Turn Aside, Flame Fan (Elemental Vanguard), Storm Cloud (Elemental Conductor), Light Void, Ravenous
    Dark, Unveil, Great Snare, Company Unseen (the new Gates of Mnemosyne), Cling, each with a book.
    Burner, River Flow, Wind Swoon and Crystalise are areas that leave ground behind. Votive Flame
    reveals. Cyrus's Night Eyes.
  - Tethers: size in every preview, gone when they hold nothing, 5 a second on a map, a tether can hold
    ground. Darkness is a rule now (zones only: map lighting is a proposal), with who sees in it.
  - Preparing spells: 5 to 35 by level, at a long rest and as the Dungeon Demo begins, locks, a window per
    player, and a Prepared page on the sheet.
  - The shove preview (figure, arrow, burst, damage) for every shove. Title cards, the boss reveal in all
    four parts, entrances and warning tiles, falls, the party's falls with an optional last word. Three
    hazards: Demolition Charge, Gale Urn, Tar Cauldron. Packed join codes. `PROTOCOL` 7.
- **The designer's long list of 2026-11-04, and two more on 2026-11-05** (ledger
  rows of those dates; CLAUDE.md "The fight's view", "What aiming shows", "Stealth
  mode", "Find Familiar", "One player to a machine", "What the other machine may
  send"; suites `openly`, `combatview`, and new sections in `coop`, `net`, `saves`,
  `hitpreview`):
  - Cyrus can Interact as a secondary action (Quick Hands).
  - The camera frames a blow, leans after what flies, kicks as it lands and glides
    to the start of a player's own turn; late arrivals are shown one at a time.
  - A blink's tile lights up; a blast's range shows while aiming and on the tooltip
    (Titanfall, Tremor); a prediction shows on anybody a skill only cannot get to.
  - End Turn holds for 2 seconds as a player's turn opens.
  - Stealth mode: only Cyrus creeping, anybody invisible and the familiar slip by
    unseen; anybody else walking within 8 tiles of a guard is noticed. Creep is a
    toggle. The familiar shows its true sight and hides on Cyrus's spots.
  - Every multiplayer error on the list, and a security pass over the network and
    the saves.
  - Prone: free to lie down, half movement to get up; half from ranged moves and
    areas, double from melee; Undo Move takes it back. Cyrus's Low Shot and the
    Saboteur's Kip-Up. The Ranger goes prone (the Goes Prone tick); Erysichthon never
    will: it is immune. Undo Move no longer leaves a walk's bonuses behind.
  - **Suggested, not built, waiting on the designer:** title cards at the start and
    end of a fight, a more impactful entrance for enemies, showing deaths, and a
    shove prediction ("Waiting on the designer", item 9).
- **The designer's round of 2026-10-31** (ledger rows of that date; CLAUDE.md
  "Co-op", "Network play", "Moves outside a fight", "Stealth maps"; suites
  `coop`, `outside`, `invisibility`, `net`, `csv`):
  - **Co-op on one screen follows the network's rules.** A picture or puzzle is
    both players' whoever opened it: the keyboard's player keeps the mouse, the
    other gets a pointer of their own (A, LB/RB, B; their own hand for the bag).
    A conversation draws the one camera to whoever began it. A conversation cut
    off by a scene change no longer leaves its starter with the focus for good -
    likely why player 2's presses went unheard.
  - **Party Management** comes up in co-op whenever somebody joins the party
    (on both machines over a network), and shows each character's portrait.
    Each player has a slot edged in their colour; Player 2's shows dashed
    while nobody plays in it, saying how to join (the pad's button as printed -
    Cross on a DualSense - and, hosting, "or from another machine"), so the
    panel shows it is up to two players. The title screen's Players panel too.
  - **Hosting:** a Copy button beside each address to give. Look for games needs
    nothing typed - it hears hosts on the same network.
  - **The familiar's own key:** R (a pad's L3) to it and back; Tab is who leads.
    **Find Familiar is cast from the Spells tab only**, as the other spells
    are: G no longer casts it, and the stealth bar's button for it shows only
    while one is out, to let it go (the designer: "Casting the familiar
    shouldn't have its own key").
  - **Attacking moves out of a fight** start a placed fight in reach, the move
    its opening blow (walls: still spells, items and Enfina). The blow is free,
    but a spell spends its gate as normal; with none left it cannot strike.
  - **The Spells tab out of a fight** is the fight's (a shelf a gate, castings
    at its start), with a shelf for the Gates of Iris first; Out Of Combat Only
    drops the gates left empty. **Invisibility** is there, not on the stealth
    bar; it is only offered to somebody who knows it (it had been offered to a
    Prometheus who had not learned it), and Prometheus knows it from the start
    for now - not so in story mode.
  - **Cover Leap removed** (it was the progression sheet's "Light Cover Leap"),
    and Lands In Cover with it. `PROTOCOL` 5.
- **Pictures searched together, stores shared, the camera drawn to a
  conversation** (the designer, 2026-10-31; `docs/multiplayer_plan.md` "Added
  after Step 3", CLAUDE.md "Network play"; suite `net`):
  - Both players may have the same point-and-click picture open, each on their
    own screen; the other walks up and opens it too (an eye over a player's
    head on the other's map says they are looking). What either finds, takes,
    turns or solves is the other's at once; each sees the other's pointer and
    what their clicks say; dials and pieces move on both. Two reaching for one
    thing at once: the first gets it, the other is told.
  - A conversation's picture opens on both; whoever began the conversation
    closes it for both.
  - A store is each player's own and both may have the same one open; every
    deal is made on the host out of the one purse, both stores redraw, and the
    last of the gold is bought once.
  - The joiner's changes - a picture's as they are made, a menu's as it closes -
    are laid over the host's player's (flags and bags entry by entry, gold by
    how much), so neither undoes the other. The Journal opens from a picture
    over a network again.
  - A conversation one player begins glides the other's camera to them, and
    back once it ends (`CAMERA_GLIDE`, `CAMERA_BACK_SECONDS`: PROPOSAL).
  - Not yet tried on two real machines.
- **How moves are felt** (the designer, 2026-10-30: everything in
  `docs/move_feel_proposals.md` "except ... moves that come down from above
  (hammers, suns) or up from below (spikes)"; built 2026-10-31):
  `combat/MoveFeel.gd`, the new parts of `combat/Projectile.gd`, CLAUDE.md
  "Projectiles", suite `projectile`. All of it placeholder art and sound,
  drawn or generated in code behind slots - the designer makes the real ones.
  - A flash at the hand as a move leaves (muzzle, glyph, swish, roar, puff),
    and a burst in each element's own way where it lands.
  - Each move's look: SkillDefinition's Projectile Look (tracer, twin tracers,
    dart, rock, nail, burning limb, great orb, swirl, vacuum, code, chain, bag,
    drops, candle, speech bubble, jet), Hand Look, Impact Look (40 of them:
    swooshes, claws, stars over a stunned head, a seal, a column of light, a
    dome, a storm...) and Ground Mark; the proposals' moves have theirs set.
  - Three new styles: Beam, Spray (the breaths, Censure, the roars), Back To
    User.
  - A miss flies on past, a graze bursts dimly, a copy taking the blow
    shatters (`Projectile.verdict`).
  - Weight from the numbers: hit-stop and shake by the share of health taken,
    the longest for a kill, slow motion for the last of a side or a boss.
  - The number says what happened (bigger for a big share, "Graze", cracked
    when resisted, a jagged star when weak to it).
  - Marks on the ground fading over two rounds; a condition's mark flying into
    its strip on the HUD; a mend's motes and the health bar seen filling;
    sound in three (launch, travel, impact - slots, stand-ins while empty).
  - The fight's own moments: a line from a readied move to whoever set it off,
    a "!" and a face for a reaction, a declared move's glyphs turning faster as
    it comes due and landing harder, a crack on a staggered boss's bar, a part
    struck flashing, a zone spreading out from where it landed. Shoves kick up
    dust and thud into walls; a summon bounds out of its caller; a thrown body
    goes over on an arc; a stolen or looted thing flies to its taker.
- **Pictures, stores and dragging, across the network** (2026-10-31;
  `docs/multiplayer_plan.md` "Added after Step 3"): a point-and-click picture or
  a store opened for the joiner's player opens on the joiner's screen, and what
  it changes goes back to the host (a hotspot sending the party to a map sends
  the host there). Over a network a picture stops nothing - only its own
  machine's party stands, as for a menu - and a press made while a menu or a
  picture is open is that menu's. A dragged body slows the dragger's own group
  on its own machine; each group creeps on its own player's keys, and the
  joiner's creeping is told to the host so its steps go unheard there too. The
  share-out offer is only made on the stranded player's own machine.
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
   - (answered 2026-10-31: the opener is free, but a spell spends its gate);
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
   which enemies Protect Their Own. Over a network (2026-10-31): two players
   changing one thing at the same moment - the first stands, the other is
   undone and told (a PROPOSAL rule, the ledger's "what the joiner changes");
   how fast the camera glides to a conversation (CAMERA_GLIDE 4,
   CAMERA_BACK_SECONDS 1). On one screen (2026-10-31): the keyboard's player
   keeping the mouse; the familiar's to-and-back key (R, a pad's L3). Answered
   2026-10-31: the second pointer's buttons are to be tried (APPROVED_TRIAL);
   Party Management for whoever joins only in multiplayer; an opening blow at
   a placed fight lands wherever the fight puts everybody, free but for a
   spell's gate. The network itself is approved - see "Next to
   build". **Itch is left alone** - nothing published, the page untouched -
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
7. **Projectiles and how moves feel:** built, but every timing and size is
   PROPOSAL - the projectiles' (0.16-0.5 s by distance, a fifth longer for an
   arc; a beam's hold, a spray's half second), how long each look plays,
   the weight (no stop under 8% of somebody's health, a heavy blow from 25%,
   0.18 s for a kill, slow motion 0.3 s at 40%), a mark lasting two rounds, a
   number up to 1.6 times as big. The Automatic choices too (a glyph for every
   spell, a column for every mend, a scorch for every fire move). Which look
   each move has is the designer's to change in its skill file. Moves coming
   down from above or up from below were left out, as asked.
8. **OPEN rows in the ledger**, among them:
   - Deep Corrosion's duration (5 vs the handoff's 3);
   - Corrosive Round at 41 equal to the Gun;
   - Venom Fan vs Exposing Shot;
   - Tripwire's burst;
   - Resuscitate's gate;
   - boss control resistance.
9. **Sounds:** the designer's "sword" sound goes on Sweep Strike, Chain Hook and Disarm when it comes.
   Not placed, no answer yet: `frog`, `train_passby`, `funny_boing_1` and `_2`. No ambience slot yet.

10. **Waiting on the designer's choices, 2026-11-07:** `docs/proposals_2026-11-07.md`, which the designer is reading:
   everything not yet chosen there, Enfina's depth and Prometheus's new schools included. Whether Phantom Noise is strong enough for Iris. Every illusion's and every AI dial's number,
   to test by feel. The Great Snare's x1.2 and hold. Which creature has which way of its own.


## Good to know

- **For story mode, when it is made:** Prometheus knows Invisibility from the
  start for now (`starting_spells`; the designer, 2026-10-31: "when we actually
  start making the story mode, he won't know it here yet") - take it out, or
  give it by the story, then. Its book is at the travelling merchant.
- To try the familiar with guards: Stealth Stages, stage 8, The Familiar
  (Alithia and Cyrus at level 10; grates, an arcane ward, a cracked wall).
  It is built by `tools/build_stealth_stages.gd` (`stage_familiar`). Or use any
  story map she is on; the familiar works there now, without guards.
- A map that is not a stealth map names its familiar's animal in its
  MapSetup's Familiar Form.
- The designer works on Windows. Godot is found by `tools/find_godot.sh`.
  Close Godot before pulling, so the editor does not write old scripts back.
