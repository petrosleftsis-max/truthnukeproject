# Multiplayer - the plan

The designer's request of 2026-10-29: each player chooses which characters they
control; everyone moves on the same map at the same time in exploration;
dialogues are synced. Local co-op first, then LAN and online.

## Where it stands (2026-10-29)

- **Built: local co-op, two players at most** (the designer: "up to two
  players"). `multiplayer/Coop.gd`, `ui/players_panel.gd`, CLAUDE.md "Co-op".
  Players join on the title screen or from the pause menu; each picks whom they
  steer; a walking group each, one camera, a leash; fight turns, menus and
  conversations go to whoever's they are; a player left steering nobody is
  offered the party to share out again. Pings (`multiplayer/Pings.gd`).
- **Not built: the seeded fight RNG** - the designer asked for it to be
  explained first. See "Randomness" below.
- **Not built: LAN.** Its fights depend on the RNG decision: either every
  machine replays the fight from the moves made (needs the seeded RNG), or the
  host plays every fight and sends the results (no RNG, more to send, clients
  wait on the host for everything they see).
- **Not built: online** (WebRTC, a relay, or Steam) - not asked for yet.

## What the game is built on now, and what that means

- **One party, one leader.** `ExplorationParty` walks a leader with the rest
  trailing along its path; `Campaign.party_order` says who leads. Co-op needs a
  walking group per player.
- **One pointer.** `Pad` drives the real mouse cursor, so a pad is a mouse.
  There is one mouse, so only one player at a time can point.
- **Global input.** `Pad.direction` and the actions read every device at once.
  Co-op needs input read per device (`InputEvent.device`).
- **Global state.** `Campaign` is an autoload changed from everywhere, and
  `Campaign.snapshot` already captures a whole run. That helps networking: one
  machine owns the state and sends snapshots.
- **Pauses.** Menus and choices pause the tree (`MenuPause`, the journal, the
  pictures). With several players, one player's inventory would freeze
  everyone.
- **Combat is turn-based** and every action goes through
  `use_skill(skill, attacker, tile)`. That is a clean seam for sending actions
  between machines.
- **Randomness:** Combat makes 13 calls to the global RNG (`randf`/`randi`):
  the hit roll, contests, damage and heal ranges, which way a wind blows, the
  AI's coin flips, a line an enemy says. Each machine's global RNG is seeded
  differently, so two machines playing the same fight from the same moves roll
  differently and drift apart. A seeded `RandomNumberGenerator` that every roll
  goes through, with the same seed sent to every machine at the start of the
  fight, makes the rolls - and so the whole fight - come out the same
  everywhere. It changes nothing for one player: rolls stay random, because the
  seed itself is random each fight. (Not built - waiting on the designer.)
- **Real-time stealth** (guards seeing and filling meters every frame) cannot be
  replayed identically on several machines. One machine has to run it and
  send the results.

## How I would build it

### Step 1 - groundwork (no visible change)

- **Who controls whom:** `Campaign.controller_of` (character -> player, saved).
  One player owns everyone, as now.
- **Input per player:** each player has a device (keyboard and mouse, or a pad
  number). `Pad.direction` takes a player and reads only their device. Actions
  are checked against the event's device.
- **Commands:** every player action becomes a small command - walk direction,
  interact, use a move outside a fight, use a skill in a fight, a dialogue
  choice. The local player runs them at once. Later the network carries the
  same commands. This is the most important refactor: everything after it
  builds on it.
- **One seeded RNG** for Combat (`Combat.rng`), with every roll going through it.

### Step 2 - local co-op (2 to 4 players, one screen)

- **A lobby** before a map: players join by pressing a button on their pad,
  then pick characters (a character card each, like the path picker).
- **Exploration:** a walking group per player, each with its own leader and
  followers. One shared camera frames everybody and zooms out to a limit; a
  leash stops anyone walking off screen. Stealth works as now: a guard sees
  whoever is in his view, and any one player caught starts the fight for all
  (`build_fight` already places everyone where they stand).
- **Fights:** turn-based as now. On a character's turn, their player's device
  drives the pointer and the panel. The turn banner and the panel's frame show
  whose turn it is.
- **Dialogue:** one shared balloon. The player who started the conversation
  chooses (PROPOSAL); the others see the choice highlighted.
- **Menus:** one player at a time, and the game holds for everyone (as now),
  with a "Player 2 is in the inventory" note. Split-screen menus are much
  more work.
- **Saves:** one save, made by the run, as now.

### Step 3 - LAN

- **Godot's high-level multiplayer** (`MultiplayerAPI`, `ENetMultiplayerPeer`):
  host a game or join by IP. On LAN, the host can be found with a UDP
  broadcast.
- **The host decides everything.** The host runs `Campaign`, the guards and the
  fights. Clients send commands and receive results.
- **Joining:** the host sends `Campaign.snapshot` and the map. The client builds
  the same scene from it.
- **Exploration:** each client moves its own characters at once, for
  responsiveness, and sends their positions. The host checks them against
  walkability and broadcasts them. The host also sends guard positions, moods
  and meters about 10-20 times a second (`MultiplayerSynchronizer`).
- **Fights - replayed on every machine:** a command (who, which skill, which
  tile) goes to all machines, and each runs `use_skill` with the shared seed.
  After every turn a checksum of everyone's health and conditions is compared.
  If they differ, the host's state is sent over and replaces the client's.
- **Dialogue:** the host runs Dialogue Manager. Lines and choices go to every
  machine, and the chooser's pick comes back.
- **Pauses** cannot hold a networked game. In multiplayer, menus do not pause;
  the world goes on (PROPOSAL), as in most online games.

### Step 4 - online

- **The same code, another transport.** Over the internet, routers block
  direct connections:
  - **WebRTC** (`WebRTCMultiplayerPeer`) plus a small signalling server. It is
    the only way the itch.io browser build can connect, since browsers cannot
    use ENet.
  - **A relay server** (WebSocket): simplest, works everywhere, and costs a
    server.
  - **Steam** (GodotSteam): matchmaking and connections done for you, but
    only if the game ships on Steam.
- **Also needed:** dropping out and rejoining, a timeout when a player
  disconnects (their characters handed to the host or the AI), and keeping
  things fair between players at different distances.

### Testing

The harness can start two headless games on one machine, a host and a client
on localhost. A suite would play both and compare `Campaign.snapshot` and
positions after scripted steps. Local co-op is tested by sending input events
with different device numbers.

## Cost and risk

- **Step 1** touches input, the party and Combat's randomness across the game.
  It is about the size of the moves-outside work, all three phases together.
- **Step 2** is a moderate step on top of it.
- **Steps 3 and 4** are the biggest change this project has had. Every feature
  added afterwards has to be made network-aware, and every suite would want a
  networked twin. Doing Step 1 early keeps that cost down.
- **Real-time stealth over the network** is the hardest part. Guards fill their
  meters from what they see, so a client's view of who is seen can lag behind
  the host's.

## Questions for the designer

1. Camera for local co-op: one shared, zooming camera with a leash, or split
   screen?
2. Can players split up on a map, or even go to different maps?
3. Dialogue: who chooses - whoever started it, the host, or a vote?
4. Menus in multiplayer: hold the game for everyone, or let the world go on?
5. How many players: 2, or up to 4 (one per character)? **Answered: two.**
6. Online: desktop only, the itch.io browser build too, or Steam?
7. A player who leaves mid-fight: do the AI or the host take their characters?
8. LAN fights: replay them on every machine (the seeded RNG), or let the host
   play every fight and send the results?

Built as defaults until answered (PROPOSAL): 1 a shared zooming camera with a
leash; 2 together on one map; 3 whoever started it; 4 hold the game for
everyone, the menu theirs alone.
