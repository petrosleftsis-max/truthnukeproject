---
name: card-game-direction
description: "The Slay-the-Spire-like card game (cards/): since 2026-11-27 the MAIN hacking minigame; gates as characters, all chosen twists (7/10/15 too), one-screen and network co-op, hacks for both built; 2/5/9/12 not wanted; the gates' own cards are the designer's"
metadata:
  node_type: memory
  type: project
  originSessionId: 322dee5d-0ec4-44ab-8eeb-9bb32627375c
  modified: 2026-11-27T15:54:21.908Z
---

On 2026-11-26 the designer asked for "a card game that is like a Slay the Spire type of game"; the baseline, its juice and on
2026-11-27 all 22 enemy-AI suggestions were built (docs/card_game.md, cards/, data/card*, suite `cards`).

**Decided 2026-11-27: Prometheus's hacking, and "from now on this is the main hacking minigame"** ("Keep the other minigames in the
code, we might use them later on"). Built that day (docs/proposals_2026-11-27_card_hacking.md): the ten gates (World..Yaldabaoth)
as characters "of equal power but different gameplay", unlocked by code fragments; twists 1, 3, 4, 6, 8, 11, 13, 14, 16 and the
hacking juice. Then the same afternoon **"try them all"** (section 8): twist 7 Tethers, twist 10 the Message (the designer: not an
auto win, the player chooses how it grows from an event's random offers), twist 15 all three ways (each gate's own starting relic -
placeholder picks; the Blessings as the run's first choice; the party's passives as rare relics), both hands at once, each player on
their own device, the rooms together, network co-op (lockstep: one seed, moves numbered by the host), and every card hack played by
both players ("During a dungeon or story mode, both players still get to play the hacking game together").

Not wanted: 2 (gates are characters, not energy), 5 ("another minigame"), 9 ("No"), 12 ("not yet"). The gates' own cards and
playstyles are the designer's ("except for the playstyles of each gate, which I'll refine later"; "I'll make cards according to them
on a later date") - not mine to write unasked. More Blessings: remind them ([[remind-more-blessings]]).

**Why:** the designer chooses the twists and makes the cards; every number is PROPOSAL until they play it.

**How to apply:** build only what they chose; keep content in data files and the rules engine (CardBattle, CardRun) free of nodes
(the screen plays `beat`s back). CardBattle/CardRun are multi-player: `player`/`hand`/`deck`... are properties onto the active
player (`active`, `me`). End a room with `_done_here`; a room builder uses `_room()`, `_button`, `_here0` (halves); a player's
action goes through `CardGame.act` and starts with `_sending` (network); never roll randomness in a screen builder (both machines
must roll the same). Every new sound, tune or picture is a slot with a stand-in. Related: [[placeholder-assets-with-slots]].
