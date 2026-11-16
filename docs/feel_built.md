# How the game feels: what was built from the proposals of 2026-11-16

The designer, 2026-11-17, on `docs/proposals_2026-11-16.md`: "in general i love all of these recommendations", with a line for
each section (kept at the bottom of this file, word for word). This file says what was built, where its code is, what to try,
and every number that can be turned. **Every number here is a PROPOSAL** until the designer has played with it. All of it is view
and feel: nothing rolls on a fight's dice, nothing is sent to another machine, nothing changes a rule. All art and sound made for
it is a placeholder behind a slot, listed under "Slots" at the end. The suite is `feel`.

## 12. Comfort (built first, so every effect has its dial)

Options has a **Comfort** group, on the title screen (Options, Comfort) and in the pause menu (Options, Comfort):

| Dial | What it turns | Code |
| --- | --- | --- |
| Screen shake | Every shake of the view, in a fight and on a map | `CameraController.shake` |
| Flashes | Screen flashes: a white-out, lightning near and far | `MoveFeel.screen_flash`, `LightView._flash_the_sky`, `far_lightning_now` |
| Camera sway | The map camera's trailing, looking ahead and easing into rooms; a fight's lean and kick | `ExplorationScene._soften_view`, `CameraController.lean_after`, `kick` |
| Rumble | A controller's rumble | `Rumble` |
| Slow motion (switch) | The world slowing at a last blow, a boss felled, a stagger | `Combat.slow_motion` |

Kept in `user://settings.cfg` under `[comfort]`. `Comfort` (`ui/comfort.gd`) is what an effect asks: `Comfort.share(Comfort.SHAKE)`
gives 0 to 1. `ComfortDials` (`ui/comfort_dials.gd`) is the group itself. The hurt vignette is left alone: it says something
happened to the party, so it is information, not decoration.

## 1. Walking on a map

- **Ease in and out.** The party sets off at 35% of its pace and reaches all of it in 0.12 s; let go, it glides 0.09 s and stops
  (about a seventh of a tile). Turning is instant. A dash, a retreat and another machine's player go as they went.
  `ExplorationParty` "Weight, and followers with a mind": `EASE_IN_SECONDS`, `EASE_OUT_SECONDS`, `EASE_FROM`.
- **Followers with a mind.** Once the leader has stood 0.5 s, those behind step out of the line, alternately to either side
  (0.3 of a tile) and a little closer (0.12), onto ground they fit on, and fall back in as the leader sets off.
  `FAN_AFTER_SECONDS`, `FAN_TILES`, `FAN_CLOSER_TILES`, `FAN_RATE`, `FAN_BACK_RATE`; `ExplorationParty.fans` turns it off for a map.
- **Wet prints.** Coming out of a map's water, the next 7 steps leave dark prints, each fainter, gone in 7 s.
  `Footsteps.WET_PRINTS`, `LightView.leave_wet_print`, `PRINT_WET_SECONDS`.
- **A dash you can feel.** The leader is drawn a fifth longer along the dash, a streak is left behind and a skid of dust is thrown
  where it ends. `ExplorationParty.DASH_STRETCH`, `MapFeel` "streak" and "skid", `CombatantSprite.stretch_along`.
- **Not built, as the designer said:** steps by what is underfoot (needs sounds), idle life (needs an idle variation each).

## 2. The map's camera

`ExplorationScene` "The map's camera, softer". Headless the view is fixed to the leader as it was.

- **A soft follow.** The view trails the leader and settles: `FOLLOW_RATE` 9 (about a ninth of a second behind).
- **Looking ahead.** It leans up to 0.9 of a tile the way the party walks, and comes back 0.6 s after they stop.
  `LOOK_AHEAD_TILES`, `LOOK_AHEAD_RATE`, `LOOK_AHEAD_HOLD`.
- **Rooms that frame themselves.** In a small enclosed place (36 tiles of floor or fewer, counted without passing from under a
  roof to the open sky) the view eases in by 10%; back out in the open. `ROOM_MOST_TILES`, `ROOM_ZOOM`, `ROOM_RATE`,
  `small_room_at`.
- **A look about.** Hold **Left Alt** (the new action `look_about`) and the walking keys slide the view up to 4 tiles; nobody
  walks meanwhile. On a pad, push the pointer (the right stick) to the edge of the screen. `LOOK_ABOUT_TILES`, `LOOK_ABOUT_EDGE`.
- **Arriving.** Coming onto a map by one of its ways in, the view starts 1.6 tiles outside it and glides to the party over a
  second. `ARRIVE_TILES`, `ARRIVE_SECONDS`, `ARRIVE_RATE`.
- With several groups on one screen (co-op) the view frames them all, softly, and does none of the rest.

## 3. Things to use and to find

- **A door that swings.** Open and shut over 0.2 s with a creak, and a thud as it comes to rest shut. Only the drawing swings:
  whether it can be walked or seen through changes at once, as before. `StealthDoor` "Swinging": `SWING_SECONDS`, `swing()`.
- **In reach, it shows.** What the interact key would use gets a soft outline, and the key and the word slide in beside it.
  `ReachMark` (`exploration/ReachMark.gd`), `ExplorationScene._mark_in_reach`. The banner at the top of the screen still says the
  same thing: **say if it should go now.**
- **Picked up.** What is taken rises and flies to the leader's portrait, shrinking, and lands with a tick.
  `MapFeel.fly_to_bag`, `StealthPickup._fly_off`.
- **A lamp put out.** A puff of smoke that leans with the wind, its own glow dying over 0.45 s; the map's dark comes in as it
  already did. `Lamp` "Put out, seen": `GLOW_OUT_SECONDS`, `GLOW_IN_SECONDS`.
- **A wall broken.** Rubble thrown away from whoever broke it, dust hanging where it stood, the view shaken and kicked that way.
  `ExplorationScene._wall_comes_down`, `WALL_SHAKE`, `WALL_KICK`. The rubble's picture is a slot (below).

## Slots (placeholder until the designer fills them)

| What | Where | Size or kind |
| --- | --- | --- |
| A door's creak, its thud | `audio/sound_bank.tres`: On a map, Door Creak, Door Shut | Sound |
| Something picked up | On a map, Picked Up | Sound |
| A lamp put out | On a map, Lamp Out | Sound |
| A wall coming down | On a map, Wall Breaks | Sound |
| Rubble | `art/fx/rubble.png` | 64 x 64, a few stones on nothing |

While a slot is empty a stand-in made in code plays (`PlaceholderSounds`), or a shape is drawn (`MapFeel`).

## What the designer said, 2026-11-17

1. "Do all except for whatever needs me to find sounds and art for (which i believe is steps by and idle life?)"
2. "Do all"
3. "do all, i'll add a rubble picture on a later date"
4. "Do all, i'll add pictures for things at the screen's edge and more that stands on a later date. explain the wall tops and
   faces drawn"
5. "do all"
6. "do all. Some of these are experimental because the characters already have attack animations"
7. "Do all of these but do them last"
8. "Do all, but for choosing the look give your own suggestions"
9. "do all"
10. "do all, altho im uncertain if i'll like the speaker steps up"
11. "add all"
12. "Add all"
