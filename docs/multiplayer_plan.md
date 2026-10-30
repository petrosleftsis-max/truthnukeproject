# Multiplayer - the build plan

The designer's request of 2026-10-29: each player chooses which characters they
control; everyone moves on the same map at the same time in exploration;
dialogues are synced. Local co-op first, then LAN and online.

This file is the plan to build from. Local co-op is done; everything from
Step 0 on is approved and waiting to be built (the designer, 2026-10-29: "I want
all of these ... like the seeded rng"). Build in the order below - each step
leans on the one before.

## Decisions (2026-10-29)

| What | Decided |
| --- | --- |
| Players | Two at most. |
| Release | **Download only, for Windows, macOS and Linux.** The browser build is dropped: the game has got too heavy for it. |
| Fights over a network | **Replayed on every machine** from the moves made, with a **seeded fight RNG**. |
| LAN | Yes: host / join by address, the host found by broadcast. |
| Online, first | Godot's own networking (ENet) over the internet, the host's router opened by **UPnP**; a **virtual LAN app** (Tailscale, ZeroTier, Radmin VPN) for anybody UPnP fails for. |
| Online, also | **WebRTC** on desktop (needs a signalling server, STUN, TURN - the designer hosts them) and **Steam** (GodotSteam - only once the game is on Steam). |
| Still open, built as defaults (PROPOSAL) | One shared zooming camera with a leash; both players on one map; a conversation chosen by whoever started it; in local co-op a menu holds the game for both, and is the opener's alone. |
| A player leaving mid-fight | **The other player takes their characters** (not the AI). |
| Menus over a network | **An open menu does not stop the world** carrying on for the other player (local co-op still holds the game for both). |

## Where it stands

- **Built: local co-op** (`multiplayer/Coop.gd`, `multiplayer/Pings.gd`,
  `ui/players_panel.gd`, `ui/familiar_request.gd`; CLAUDE.md "Co-op"; suite
  `coop`). Players join on the title screen or from the pause menu and pick
  whom they steer (`Campaign.controllers`, saved); a walking group each, one
  camera, a leash; fight turns, menus, conversations and reaction questions go
  to whoever's they are (`Coop.focus`, the gate); a player left steering nobody
  is offered the party to share out; pings; the other player can ask for
  Alithia's familiar.
- **Ready for the network, already in the code:**
  - `Coop.players[i].peer` (the machine a player is on), `Coop.local_peer`,
    `Coop.networked`, `Coop.is_local(id)`, `Coop.local_players()`.
  - `ExplorationParty.puppet` (no input) and `ExplorationParty.walk_to(at,
    facing_left, walking)` (put where another machine says, the line trailing).
  - `Pings.pinged(player, at, label)` signal and `Pings.show_ping(...)` for a ping
    from another machine.
  - `ReactionPrompt._decider` - who answers a question in a fight.
  - `PlayersPanel` asks `/root/Net` for `make_panel()` and shows it under the
    players: Host / Join go there.
- **Built: Step 0** (download only, 2026-10-29): `tools/release.sh` builds
  Windows, macOS and Linux.
- **Built: Step 1** (the seeded fight RNG, 2026-10-29): `Combat.rng`,
  `seed_rolls`, `_shuffle`, `fight_state`; CLAUDE.md "Rolls in a fight"; suite
  `rolls`.
- **Step 2 under way** (2026-10-30): `multiplayer/Net.gd` hosts, joins, finds
  games by their beacon, and seats players across machines; the joiner joins a
  game under way and follows the host's scene and Campaign (items 1-4 below;
  `ui/net_panel.gd`; suite `net`, which plays the joiner in a second Godot).
  Items 5-12 to come.
- **Not built:** the rest of Step 2, and Steps 3-5 below.

## Step 0 - download only (small; done 2026-10-29)

Done as below; the README's "Exporting" says it too, and `encmusic` speaks of
"the build" rather than the web build (it still reads every preset's exclude
filter). The designer then asked for **macOS and Linux** as well (2026-10-29):
`tools/release.sh` builds all three - a Linux x86_64 binary and a universal
macOS `.app` signed ad hoc (not notarized: that needs an Apple developer
account) beside Windows - packs them (Windows `.zip`, Linux `.tar.gz` that keeps
the game runnable, the Mac Godot's own `.zip`) and pushes the channels
`windows`, `linux` and `mac`, the last two with `--fix-permissions`. The presets
are in the README's "Exporting". A Mac and a PC in one fight is the reason for
the floating-point note under "Cost and risk". Two things went otherwise than
planned: the `.gdignore` in `export/` stays (without it the Mac build's own
icon, made in `export/tmp`, went into its pack), and the Mac export makes its
`.app` in `export/tmp` rather than the system's temp folder, where on the
designer's PC it stalled for good writing the 170 MB program.

- `tools/release.sh`: drop the Web export, its zip and its butler push
  (`"$ITCH:web"`); keep Windows. `export/web` and the "keep the web build's
  icons out of the Windows export" step go with it. Keep the itch upload of the
  Windows build.
- CLAUDE.md "Releasing": only the **Windows Desktop** preset is needed now.
- One place in the game checks for the web: `ui/game_settings.gd` skips
  restoring the window mode there. Harmless; it can stay. The single-threaded
  export setting no longer matters.
- Optional, the designer's call: ship the music. The three `.wav` tracks are
  git-ignored (126 MB); converted to Ogg Vorbis they would be a fraction of that
  and could go in the repo and the build. `audio/Music.gd` already plays on in
  silence without them.
- On itch the designer stops showing the browser version (their settings page).
  Players of the browser version keep their saves in the browser; they do not
  carry over to the download.

## Step 1 - the seeded fight RNG (small, do it before LAN; done 2026-10-29)

Done as below. Combat.gd had 16 rolls, not 13; all go through `rng` now, and
`_seed_wanted`'s `randi()` - a fight with no seed picking its own - is the one
global roll left, on purpose. Nothing else the fight calls rolls: CController
has none, and QuickTime's and Hacking's own generators set the player a
challenge - over a network what the player makes of it is sent as an answer
(Step 2, 8). Beside the rolls, `fight_state()` writes the fight down as text
(round, whose turn, everybody's side, health, tile, standing and conditions,
floats to four places) - what the suite compares, and what Step 2's checksum
will hash. The suite is `rolls`: one seed rolls and shuffles the same; a fight
takes its encounter's seed and picks its own without; Combat.gd and
CController.gd are read for global rolls; and one fight (two of the party
against three, everybody's aim 40 worse, since at level 8 every blow lands
and no roll would matter) is played twice from one seed - the global generator
seeded otherwise and the enemies at another speed the second time - and comes
out the same after every turn, while from another seed it does not. Put back on
the global generator, the hit roll failed all three of those checks.

Why: two machines playing the same fight from the same moves roll differently
(each machine's global RNG has its own seed) and drift apart. With one seeded
generator for every roll in a fight, and the same seed on every machine, the
whole fight comes out the same everywhere, so only the moves need sending. For
one player nothing changes - the seed is random each fight.

- In `combat/Combat.gd`, before `_ready`, add a "Rolls" section:

  ```gdscript
  ## --- Rolls ---
  ##
  ## Every roll in a fight - to hit, contests, damage ranges, which way the wind
  ## blows, the AI's choices - comes out of this one generator, so a fight begun
  ## from the same seed rolls the same on every machine (multiplayer/Net.gd).
  ## Nothing in a fight calls randf, randi or shuffle by itself.
  var rng := RandomNumberGenerator.new()
  ## The seed this fight rolls from.
  var fight_seed := 0


  ## The encounter's "seed" meta - a networked fight's - else any.
  func _seed_wanted() -> int:
  	if encounter != null and encounter.has_meta("seed"):
  		return int(encounter.get_meta("seed"))
  	return randi()


  func seed_rolls(value: int):
  	fight_seed = value
  	rng.seed = value


  ## `array` shuffled in place by the fight's own rolls.
  func _shuffle(array: Array):
  	for i in range(array.size() - 1, 0, -1):
  		var j := rng.randi() % (i + 1)
  		var kept = array[i]
  		array[i] = array[j]
  		array[j] = kept
  ```

- In `_ready`, `randomize()` becomes `seed_rolls(_seed_wanted())`.
- Every roll goes through `rng` (13 places in Combat.gd today - find them with
  `grep -n "randf\|randi\|shuffle()\|pick_random" combat/Combat.gd`):
  `randi() % 100` -> `rng.randi() % 100` (hit rolls, chances to break free and
  the like), `randi_range(` -> `rng.randi_range(` (damage, heal and shake
  ranges), `randf()` -> `rng.randf()`, `x[randi() % x.size()]` -> `rng.randi()`
  (a lookup, an enemy's line), and `options.shuffle()` / `open.shuffle()` /
  `standing.shuffle()` -> `_shuffle(...)` (the wind's way, where the late come
  in). Also look in `control/CController.gd` and anything else the fight calls
  (`grep -rn "randf\|randi\|shuffle\|pick_random" combat control`) - a roll that
  changes the fight anywhere breaks the replay. Purely visual randomness can
  stay global: today that is `control/FutureShards.gd` (the shards flying) and
  `control/CameraController.gd` (the shake).
- `tests/enemies_test_driver.gd` calls `seed(7)` before breaking free: make it
  `combat.seed_rolls(7)`.
- A test (in `coop` or a new suite): the same seed gives the same rolls and the
  same shuffles; and a fight played twice from the same seed and the same moves
  ends the same (compare every combatant's hp, position and conditions).

## Step 2 - LAN (the big one)

A `Net` autoload (`multiplayer/Net.gd`, after `Coop` in the autoload list).
Godot's high-level multiplayer (`MultiplayerAPI`, `ENetMultiplayerPeer`, `@rpc`).
**The host decides**: it owns `Campaign`, the guards and the scene; the other
machine sends what its player does and shows what it is told.

Items 1 and 2 are built (2026-10-30). As built: `host(port, bind_ip)` takes an
address to bind to (the test's 127.0.0.1); the beacon reads `MOT-HOST|protocol|
port|name`; the hello carries `PROTOCOL` and `build_key()` (the protocol, the
Godot version and every move, character and item by name), and another version
or a full table is turned away; the joiner's machine seats one player, with the
first device it names. One change from the plan: the Players panel listens for
games only when Look for games is pressed - listening on the network is what
brings up Windows' firewall question, and a game on one screen should never ask.

1. **Hosting and joining.** `host(port := 24700)` / `join(address, port)` /
   `leave()`; `active()`, `is_host()`. Hosting sets `Coop.networked`,
   `Coop.local_peer = 1` and the host's own players' `peer`. LAN discovery: the
   host broadcasts `MOT-HOST|name|port` once a second on UDP 24701
   (`PacketPeerUDP`, broadcast enabled); the Join list listens. Typing an address
   must always work too (virtual LANs often do not pass broadcasts on).
   `make_panel()` gives the Players panel its Host / Join / found games part.
2. **Players across machines.** On connecting, the joiner sends its local
   devices; the host `Coop.join(device, name, peer)` for each and sends the whole
   `Coop.players` and `Campaign.controllers` to everybody, again whenever they
   change. Choosing characters on the joiner is a request to the host. Still two
   players at most - one per machine, as a rule.
Items 3 and 4 are built (2026-10-30). As built: `Campaign.net_state()` is the
live state (a stealth map's too, not its checkpoint) with the map, where the
party is going and the encounter as data; `Campaign.apply` puts it on. A joiner
seated while the host is on a map comes straight there with the party and bags
as they stand and where the host's party stands; one seated during a fight
comes in at the next change of scene rather than into a fight already played
partway (that would need every move so far). After a change the host keeps
sending Campaign - when it changes, and every three seconds anyway - and the
joiner holds what arrives while it is still changing scene, so a map coming up
does to the state what the host's did. On the joiner a map sets off nothing it
is walked into and offers no paths: the host's does. Leaving, or the host
leaving, sends the joiner to the title screen.

3. **Joining a game under way.** The host sends everything `Campaign.snapshot`
   holds plus `current_map`, `party_order`, `return_position` and the encounter if
   in a fight. `Campaign.restore` changes scene by itself - add an `apply(state)`
   that sets the state without, and let the joiner change to the host's scene.
4. **Following the host's scene.** Every scene change goes through
   `SceneTransition.change_scene(path)` except `ExplorationScene.reload_map`
   (`reload_current_scene` - route it through the same hook). On the host, a
   change sends `{path, state}` to the joiner, which applies the state and
   changes too. A joiner never changes scene on its own.
5. **Presses from the joiner.** Its key and pad presses are sent to the host and
   played there as the joiner's player: give the event `device =
   REMOTE_DEVICE_BASE + player id` (say 9000 + id) and teach
   `Coop.player_of_event` to read it; actions in the input map have device -1
   (all), so they still match. Clicks on the map do not carry over (screen
   positions differ) - send what they mean instead (a tile, a move on the panel:
   `OutsideMoves.use(scene, key, move)` is one call to forward).
6. **Walking.** Each machine walks its own player's group (responsive) and sends
   the leader's position, facing and walking 15-20 times a second (unreliable,
   ordered); the other machine's copy of that group is a `puppet` and
   `walk_to`s it. The host checks positions against `is_walkable` before
   passing them on.
7. **Guards (stealth maps).** Only the host runs `StealthWatch`'s brain and the
   guards' `_process`. The joiner gets each guard's position, facing, mood,
   suspicion and the alert level ~10 times a second and draws them; its guards
   are puppets (a `puppet` switch on StealthWatch and Guard that skips the
   deciding and keeps the drawing - `_refresh_seen` can still run, since sight is
   worked out from position and facing alone). Caught: the host builds the
   fight (`build_fight`) and sends it with the scene change. Send resources as
   plain data - script path plus stored properties, loading scripts only from
   `res://` - never `bytes_to_var_with_objects` on what another machine sent.
8. **Fights - replayed.** The host picks the seed and puts it on the encounter
   (`encounter.set_meta("seed", ...)`) before sending it. On the player's turn
   their machine sends each action - walk to a tile, use a skill at a tile, end
   turn, ready, undo - and **both** machines run it (`@rpc("any_peer",
   "call_local", "reliable")`), queued until that machine's Combat is waiting for
   that combatant's input. Map the choke points in `control/CController.gd` first
   (where a click becomes a move, a `use_skill`, an end of turn). AI turns need
   nothing sent: the seed makes them the same. Questions mid-action
   (`ReactionPrompt` - its `_decider` says whose; the container to steal from,
   the gate to cast through, what to lift) are answered on the decider's machine
   and the answer sent. After every turn each machine checksums every
   combatant's hp, position, alive and conditions; the host compares, and on a
   difference sends its values to patch the joiner's (and logs it - it means
   something rolled outside `rng`).
9. **Conversations.** The host runs Dialogue Manager; each line and its
   responses go to the joiner, shown in a simple balloon there; whoever has the
   focus (whoever started it) advances and chooses, and a choice made on the
   joiner comes back to the host.
10. **Menus.** The inventory, the sheet and the stores change `Campaign`: on the
    joiner they send what they do to the host, or open read-only - decide which
    per menu. Over a network a menu does not hold the game (the designer,
    2026-10-29, Decisions): the world carries on for the other player.
    `MenuPause._apply` is the one place to change.
11. **Pings** go both ways (`Pings.pinged` -> rpc -> `show_ping`).
12. **Leaving.** A dropped joiner's characters go to the host's player
    (`Coop.leave`) - mid-fight too: the other player takes them, not the AI
    (the designer, 2026-10-29); the host leaving ends the game for the joiner, back to the
    title screen with a note (`Campaign.to_main_menu(panel, note)`).

**Testing two machines in one suite:** the driver (an autoload, see
tests/README.md) starts a second headless Godot on the same copy with
`OS.create_process(OS.get_executable_path(), ["--headless", "--path",
ProjectSettings.globalize_path("res://"), "--", "--net-client"])`. The same
driver sees `--net-client` in `OS.get_cmdline_user_args()` and plays the joiner,
writing its own result file; the host waits for it and copies its lines into its
own log, which is what `run.sh` reads. Connect on 127.0.0.1. Check: joining
gives the same `Campaign.snapshot`; walking shows on the other side; a press on
the joiner happens on the host; a fight played from the same moves ends with the
same checksum; a conversation's choice made on the joiner is the one taken.

## Step 3 - online by Godot's own networking (small, after LAN)

The same code as LAN; only reaching the host is new.

- Hosting tries **UPnP**: `var upnp := UPNP.new()`, `upnp.discover()`,
  `upnp.add_port_mapping(24700, 24700, "Messengers of Truth", "UDP")`, and
  `upnp.delete_port_mapping(24700, "UDP")` on leaving. Show the host's public
  address (`upnp.query_external_address()`) for them to send their friend.
- It fails on some connections (mobile, providers that share one address among
  many homes). Then the Players panel says so, and points to a **virtual LAN
  app**: Tailscale, ZeroTier or Radmin VPN - both install it, join the same
  network, and use LAN with the address the app shows. Put the same in the
  README for players.

## Step 4 - WebRTC on desktop (after Step 3; needs the designer's servers)

- **webrtc-native**, Godot's official GDExtension, in `addons/` - a build for
  this Godot version (4.7.2). Desktop needs it; it is not built into the engine
  there.
- **A signalling server**: a small WebSocket program that introduces two
  players and hands out a room code (Godot's demo projects have
  `webrtc_signaling` to start from). The designer hosts it (a small rented
  server, or a free tier) and gives its address.
- **STUN**: a free public one (`stun:stun.l.google.com:19302`) - one line of
  settings.
- **TURN**: a relay for the players a direct link fails for - `coturn` on the
  same server, or a paid relay. A turn-based fight sends very little.
- In the game: `WebRTCMultiplayerPeer` in place of `ENetMultiplayerPeer`;
  everything above Step 2's transport stays. Host shows a room code; the friend
  types it.

## Step 5 - Steam (only once the game is on Steam)

- **GodotSteam** (a GDExtension build matching Godot 4.7.2), its
  `SteamMultiplayerPeer` in place of ENet. Steam does lobbies, "join friend"
  invites and relays traffic - nothing to host. Needs the game's Steam app id
  (480, Spacewar, for trying it out) and Steam's fee for listing a game.

## Cost and risk

- Step 0 and Step 1 are small and safe; Step 1 changes no behaviour for one
  player, but a missed roll only shows over a network - the checksum test is
  what catches it.
- With macOS (Apple Silicon is ARM) and Linux builds, the two machines in a
  fight may have different processors and maths libraries. Adding, subtracting,
  multiplying, dividing and square roots round the same everywhere; `sin`,
  `cos`, `atan2`, `pow` and the like may differ in the last bit, so a decision
  resting on them can, rarely, go the other way on the other machine. The
  checksum after every turn (Step 2, 8) catches it, and the host's values patch
  it.
- Step 2 is the biggest change this project has had. Every feature added after
  it has to be network-aware. The hardest part is real-time stealth: the
  joiner's view of who is seen lags the host's by the network's delay.
- Steps 3-5 are each a new way to connect, on top of Step 2.
