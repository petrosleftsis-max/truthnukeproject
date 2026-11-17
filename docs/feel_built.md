# How the game feels: what was built from the proposals of 2026-11-16

The designer, 2026-11-16, on `docs/proposals_2026-11-16.md`: "in general i love all of these recommendations", with a line for
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

## 4. Depth, the next steps

`DepthPiece` "The next steps of depth". How to put each on a map is in `docs/depth_on_maps.md`. The Light stage's yard has one
of each.

- **Dappled shade under a tree.** The crown's shadow on the ground and on whoever stands under it, with gaps of light that drift
  with the wind. By day; none at night; it leans the way the sun's shadows lean. `SHADE_MOST` 0.34, `SHADE_GROWS`.
- **A crown that sways.** It leans and rocks the way the wind blows, a little even in still air, and in a strong wind leaves are
  shaken loose. `SWAY_STILL_TILES`, `SWAY_TILES`, `SWAY_TURN`, `LEAVES_FROM_WIND`, `LEAVES_EVERY`.
- **The far away, hazier.** A piece Behind is mixed towards a pale haze, 14% always and up to 50% more in mist, and a Picture is
  softened a little. `HAZE_ALWAYS`, `HAZE_IN_MIST`, `HAZE_SOFT`, `HAZE_PALE`.
- **Things at the screen's edge.** A new Kind, **Edge**: drawn dark and soft at the very front, over the weather, sliding fastest
  as the view moves (0.35), and faded to 22% while one of the party is under it. Its placeholder is a bough.
  `Depth.PIECE_MOVES_EDGE`, `EDGE_DARK`, `EDGE_FADED`, `EDGE_SOFT`.
- **More that stands.** Five new Kinds: **Crate, Pillar, Statue, Lamp Post, Railing**. Each stands on the south edge of its
  tile, among the figures: whoever is in front is drawn over it, whoever is behind under it and seen through it. As wide as its
  Size Tiles and as tall as its Height, or its kind's own while Height is left at 192 (210, 400, 340, 400, 110; a person is about
  330). In a fight it is handed to the fighters' own layer so it sorts with them. `STAND_HEIGHTS`.
  **It stops nobody by itself**: whether a tile can be walked is the tile's to say, on a map and in a fight alike. Put it on a
  tile that already stops walkers, or accept that a thin thing (a railing, a lamp post) is walked past. **A question for the
  designer: should a thing that stands stop people by itself? That would be a rule, for maps and fights both.**
- **A step down that looks like one.** Whoever on a map comes to stand on something lifted is drawn up on it and goes up or comes
  down with a short hop and a puff of dust; a vault lands in a puff of dust too. `DepthView.MAP_HOP_SECONDS`.
  **Today nothing on a map walks onto raised ground**: it stops a walker there as it does in a fight (only a climber goes up, in
  a fight). So this shows only for whoever goes over it (Fly) or is put there. It is built so that the day raised ground can be
  climbed on a map, it already looks right; whether it can is a rule, the designer's.

### Wall tops and faces drawn: what that item means

Nothing to build: it is the artist's, and the slots are already there (`docs/depth_on_maps.md`, "Sizes for the artist").

A wall is drawn as two pictures. Its **top** is the tile's own picture from the tileset, lifted 192 pixels. Its **face** is the
strip under the top's south edge, down to the ground: the part of the wall that looks at the player. Today the top is the old
flat wall tile and the face is a plain darker strip made in code, so walls read as grey slabs. With pictures:

- `art/terrain/depth/wall_face.png`, 256 x 192: the wall as seen from the front (stones, bricks, a plinth at the bottom, a lip at
  the top). One picture serves every wall; it repeats along the wall, so its left and right edges should meet.
- `art/terrain/depth/top_<column>_<row>.png`, 256 x 256: the top of one kind of wall tile, seen from above, in place of its
  tileset picture (`<column>_<row>` is the tile's place in the tileset picture, from 0).
- `art/terrain/depth/face_<column>_<row>.png` or `face.png`, 256 x 96: the same for the face under raised ground.
- Any of them may have a **normal map** beside it, the same name with `_n` before `.png`. With one, a lamp carried past rakes
  across the stones instead of lighting the wall as a flat card.

Dropping a file there is all it takes: the next run draws it. This is the single change that would most lift how the maps look.

## 5. Water

`LightView` "Water, the next steps"; `CombatantSprite` "Wading".

- **A waterline.** Whoever wades has the water drawn over their legs, to the ankle by the shore and to the knee out in the middle,
  with a bright line where it meets them that rocks a little. Their legs show through, dimmed. `WADE_ANKLE_TILES` 0.1,
  `WADE_KNEE_TILES` 0.3, `CombatantSprite.WADE_ALPHA`, `WADE_HALF_WIDTH`.
- **Depth by colour.** Paler by the shore, darker 1.6 tiles out from it. The shader's `deep_tiles`, `deep_dark` 0.3,
  `shore_pale` 0.16; `LightView.WATER_DEEP_TILES` for the waterline's depth.
- **The world mirrored.** The walls north of the water and whatever stands over it (a tree, a thing that stands, an arch, a
  balcony, a roof) upside down in it, at 30%. `MIRROR_WORLD`, `MIRROR_REACH_TILES`.
- **Something landing in it.** A ring, drops thrown up and a splash heard: a blow landing on somebody standing in water, a blast
  over it, a body falling in it, a thrown thing coming down in it. `LightView.land_in_water`.
- Wet prints (section 1) are told every frame walked, so crossing even one tile of water wets the next steps.

## 6. A blow, from the side of whoever throws it (experiments, each with a switch)

`MoveFeel` "A blow, from the side of whoever throws it"; `CombatantSprite` "Striking"; `Combat._play_the_move`. The designer:
"Some of these are experimental because the characters already have attack animations". So each has a switch in `MoveFeel`
(`strikes`, `faces`, `gathers`, `tells`), and somebody with an animation of their own for the move gets half of the motion
(`OWN_ANIMATION_SHARE` 0.5) over it and is not waited for any longer than before.

- **Wind-up and follow-through.** The figure as drawn leans back, goes into the blow and settles over 0.42 s: a lean of up to 0.1
  radians about its feet and a step of the drawing, no new frames. `STRIKE_SECONDS`, `STRIKE_LANDS`, `STRIKE_BACK_TILES`,
  `STRIKE_LEAN`, `strike_curve`.
- **Stepping in.** A melee blow steps 0.3 of a tile towards its target and back; anything else only reaches 0.08.
  `STRIKE_STEP_TILES`, `STRIKE_REACH_TILES`. The node never leaves its tile: only the picture moves.
- **Somebody with no animation of their own** (most enemies) is given the 0.19 s it takes the blow to land, so the blow
  lands as they reach it. Nothing else in a fight's timing changed.
- **Facing.** Whoever uses a move turns to face where it is aimed, and whoever a blow from the other side lands on turns to
  whoever threw it. Only the picture: facing is not a rule.
- **The caster's light.** A spell lights its caster in its own colour as it gathers, rings closing in on them, brighter the
  deeper its gate. MoveFeel's `gather`.
- **Resisted and vulnerable, felt.** A blow resisted lands with a dull thud and a pale arc glancing off; one they are vulnerable
  to rings, with a bright ring in its colour. `MoveFeel.resisted`, `vulnerable`, from `Combat.show_damage`.

**To judge by eye, since the party has animations:** whether the half-strength lean over Cyrus's and Enfina's own attack
animations helps or fights them. If it fights them, `OWN_ANIMATION_SHARE` at 0 leaves their animations alone and keeps the
motion for everybody without one.

## 7. The pad in your hands (built last, as the designer asked)

- **Rumble** (`control/Rumble.gd`, with its dial in Comfort since part 1; nothing on a keyboard): a blow is a tap, a heavy one
  (a third of their health or more) or a felling one a thump, a scratch (under 4%) nothing (`Combat.show_damage`); a long low roll
  for thunder (`LightView._storm`) and for a wall coming down; a heartbeat, two soft beats a second, while anybody of the party
  standing is at a fifth of their health or less (`combat_ui._near_death_beats`, `NEAR_DEATH`). It stops as a fight ends and as a
  menu comes up.
- **A press a moment early still counts.** End Turn or a skill's key pressed while the last of something plays out on the
  player's own turn is kept a fifth of a second and acted on as it ends (combat_ui `_keep_early`, `_play_early`,
  `EARLY_SECONDS`); a click let go of meanwhile aims at, or walks to, the tile it was on, by a path worked out afresh (CController
  "A press a moment early"). Pressed earlier than that, it is let go.
- **Holding to repeat.** Holding a direction on the board already stepped the cursor on (a first step, a pause of 0.35 s, then a
  step every 0.11 s); now, held on, it steps faster, down to half that over the next second (`Pad.STEP_FASTEST_SHARE`,
  `STEP_SPEEDS_UP`).

## 8. The interface in motion, and its look

`ui/ui_feel.gd` (`UiFeel`), listened for once from the SceneTransition autoload, so every button and panel in the game has it;
`ui/sky_look.gd` (`SkyLook`) for the look. A control with the meta `no_feel` is left alone, and headless nothing moves.

- **Buttons that answer.** A button swells 4.5% under the pointer and dips to 95% when pressed, about its own size: one the game
  keeps bigger comes back to that, never to 1. A press on one that cannot be pressed shakes its head with a small dull sound.
  `HOVER`, `PRESS`, `SHAKE_DEGREES`, `SHAKE_SECONDS`.
- **Panels that arrive.** A panel coming up fades in over 0.11 s. It only fades: the HUD's parts are scaled and placed by the
  interface's size (Options), so a panel is never grown or moved. `ARRIVE_SECONDS`.
- **Whose turn.** As a turn of the party's begins, the action bar deals itself in, a button every 0.022 s, and their face in the
  queue swells past its place and settles there. `DEAL_EVERY`, `DEAL_SECONDS`, `STEP_FORWARD`.
- **Numbers that count.** Gold (in the bags and a store) and health (on the portraits) count to their new value over 0.35 s; a
  gate's castings pop as one is spent or given back. `COUNT_SECONDS`, `POP`.
- **The look: T, "K, lighter"** (the designer, 2026-11-17: "Do T: K, Lighter"; the looks of 2026-11-13 on the interface page).
  Every panel is K's smooth blue night, deeper at the top, with stars strewn over it as real ones are (a few gathered about
  places, fewer and dimmer lower down, a few bright), and at its lower left corner a few small pixels have come loose, the rest of
  its edge smooth. Each panel's stars are its own and stay put while it is open. Buttons are pills of light on it, the main one
  (End Turn) filled and a skill's slot a rounded square; bars are dark with a pale blue fill (a health bar keeps its own colours);
  tabs, a text field and a menu match. The screens that drew their own cards (the journal, the title and its menus, the sheet,
  the bags, the glossary, a conversation's answers, the stage card, the turn banner, the gate tags, the action marks) take its
  colours (`SkyLook.INK`, `ACCENT`, `PANEL`, `CARD`, `CARD_LIT`, `CARD_EDGE`). Put on the theme as the game starts, after the
  fonts (`SkyLook.apply`). Numbers: `STAR_AREA` 1500 (square pixels of sky to a star), `STARS_MOST` 140, `STARS_GATHERED` 0.3,
  `STARS_BRIGHT` 0.04, `LOOSE_SHARE` 0.22 of the width (at most `LOOSE_MOST` 80 pixels), `CRUMBS` 12.

## 9. Sound that follows the picture

`audio/SoundFollows.gd` (`SoundFollows`), a child of the Music autoload, with effects of its own on the Music and SFX buses (a
low-pass on each, an amplifier on the music, a reverb on the rest), so the volume dials are never touched. "The view" is the
middle of the screen on the map or fight shown.

- **Muffled when it should be.** The music and the world dull behind a menu (to 900 Hz), in slow motion (1,500), indoors while
  it rains outside (2,400) and with the view in the dark (3,600), eased in octaves. `MENU_HZ`, `SLOW_HZ`, `RAIN_INDOORS_HZ`,
  `DARK_HZ`, `EASE`.
- **Music that gives way.** It dips 9 dB for a line in a bubble (as long as the bubble is up), a boss's reveal (3.5 s) and somebody
  falling (1.2 s), and comes back over 0.7 s. `GIVE_WAY_DB`, `GIVE_WAY_HOLD`, `GIVE_WAY_BACK`, `REVEAL_SECONDS`, `FALL_SECONDS`.
- **Echo by place.** A tail on every sound but the music: wetter underground (a map with no open sky at all; 0.24, a big room)
  than in a hall (under a roof; 0.12), none out of doors. `ECHO_HALL`, `ECHO_UNDERGROUND`, `ROOM_HALL`, `ROOM_UNDERGROUND`.
- **A voice for each speaker.** A soft tick every second letter as a line types out (not for a space or a mark, nor a line with a
  voice of its own), pitched for who speaks: Cyrus 0.86, Alithia 1.2, Enfina 1.02, Prometheus 0.78, anybody else a pitch made
  from their name, the same every time. `VOICE_EVERY`, `VOICE_DB`, `VOICES`.
- **Sound by place.** A bed under it all, the room's hush indoors and drips underground: the sound bank's Indoors and Underground,
  **silent until filled** (a made-up noise looping would be worse than nothing). Out of doors the day's own sound plays already.
- **Music that follows the danger.** On a watched map the music already muffles as a guard grows sure (StealthWatch); with the
  whole map on edge a low pulse beats under it, every 1.15 s when Wary and 0.72 s when Alarmed (the sound bank's Danger, a
  stand-in heartbeat meanwhile). `DANGER_EVERY`, `DANGER_DB`.

## 10. Conversations

`DialogueBalloon` "Conversations, felt"; `ExplorationScene` "The map's camera, softer" (`TALK_ZOOM`).

- **Words that move.** Nothing to build: write them into the line. `[shake]these words[/shake]` shake, `[wave]these[/wave]` wave
  (the text's own effects; `[shake rate=12 level=6]` and `[wave amp=30 freq=4]` turn them up or down), and `[speed=0.4]` makes
  what follows come slowly (the conversation's own; 1 is the usual pace).
- **The speaker steps up.** Whoever speaks is lit on the map and whoever has spoken in the conversation before them is dimmed;
  as the conversation ends everybody is as they were. A portrait bobs as it changes to somebody else's. **Its switch**, as the
  designer was unsure of it: `DialogueBalloon.speaker_steps_up` (true now); off, nobody is lit or dimmed and the bob stays.
  `SPEAKER_LIT`, `OTHERS_DIMMED`, `STEP_SECONDS`, `BOB`; `CombatantSprite.talk_tint`.
- **The camera listens.** Over a long exchange the map's camera pushes in, 7% over 20 seconds, and lets go after. A line tagged
  `[#bars]` brings bars in at the top and the bottom of the screen (8.5% of it each); the next line without the tag takes them
  away. `TALK_ZOOM`, `TALK_PUSH_SECONDS`, `BARS_SHARE`, `BARS_SECONDS`.

## 11. Life about the place

`exploration/MapLife.gd` (`MapLife`, a node with an editor icon), placed on a map or on a terrain (then its fights have it too),
over a patch of ground: **Size Tiles** right and down from its tile. Its **Kind**:

- **Birds** (Count of them) peck and hop about the patch; as one of the party comes within 2.6 tiles they take off away from
  them, their shadows under them, and come back 18 s after once the party is 5 tiles off.
- **Rats** scurry about the patch and bolt from the party within 2.2 tiles, back after 12 s.
- **Cat** sits on its tile, drawn up on a wall top if that is where it is, its head turned to the party; it leaps off from 1.5
  tiles and comes back after 15 s.
- **Grass** (Count of tufts) bends with the wind, away from whoever walks through it, and away from a blast: an area blow landing
  in a fight (MoveFeel's area impacts) or a wall broken on a map (`MapLife.blast_at`).
- **Chatter**: whoever **Speaker** names (or the node itself) says the next of its **Lines** in a bubble every 9 to 17 s while
  the party is within 6 tiles and nobody is in a conversation.

Birds, rats and grass only go on bare floor in the patch (Depth's FLOOR), never on a wall or a barrel. Banners are brushed aside
by whoever walks within a tile of them, and pushed by a blast (`WindBanner.push`). **Moths** circle a lamp at night while it
burns with the dark about it (`LightView._add_moths`, `MOTHS`, `MOTHS_FROM_DARK`). On the Light stage: birds by the sundial,
grass by the gate and along the pond, a cat on the yard's north wall, the Torch Bearer talking to himself (placeholder lines);
in the laboratory, rats in the first corridor. Only to look at: nothing here is seen or heard by a guard or stops anybody.
`FLEE_TILES`, `BACK_FROM_TILES`, `BACK_SECONDS`, `GRASS_WIND`, `GRASS_PUSHED`, `CHATTER_EVERY`, `CHATTER_TILES` (PROPOSAL).

## Slots (placeholder until the designer fills them)

| What | Where | Size or kind |
| --- | --- | --- |
| A door's creak, its thud | `audio/sound_bank.tres`: On a map, Door Creak, Door Shut | Sound |
| Something picked up | On a map, Picked Up | Sound |
| A lamp put out | On a map, Lamp Out | Sound |
| A wall coming down | On a map, Wall Breaks | Sound |
| Rubble | `art/fx/rubble.png` | 64 x 64, a few stones on nothing |
| Something landing in water | On a map, Water Splash | Sound |
| A thing at the screen's edge | The DepthPiece's Picture (Kind Edge) | Large: 1024 x 1024 for one four tiles across; it is drawn dark and softened, so a plain shape with a clear outline is enough |
| A crate, a pillar, a statue, a lamp post, a railing | The DepthPiece's Picture (those Kinds) | 256 wide a tile of Size Tiles, and as tall as its Height (210, 400, 340, 400, 110 to begin with); its foot at the bottom edge |
| A door, shut, seen edge on, open in a side wall | `art/terrain/depth/door_shut.png`, `door_edge.png`, `door_open.png`, or a door's own Pictures | 256 x 448, 41 x 448, 256 x 233 (`docs/depth_on_maps.md` says what each part is) |
| A button refused | On a map, Refused | Sound |
| A line typing out | On a map, Voice Tick (one sound, pitched for each speaker) | A short soft tick |
| A room's hush, drips underground | On a map, Indoors, Underground | Loops, quiet; silent until filled |
| The danger's pulse | On a map, Danger | A low beat, played once a beat |
| A bird, a rat, a cat, a tuft of grass | A MapLife's Picture, else `art/fx/birds.png`, `rats.png`, `cat.png`, `grass.png` | Drawn at its own size: a bird about 48 x 32, a rat 64 x 32, a cat sitting 96 x 128, a tuft 64 x 64, each standing on its bottom edge's middle; facing right (turned round to face left) |
| A moth | `art/fx/moth.png` | 8 x 8, pale |
| The night behind every panel (T) | `art/ui/sky/night.png` | 8 x 256, stretched across a panel top to bottom |
| A bright star | `art/ui/sky/star_bright.png` | 8 x 8; the small stars are pixels the game strews |
| A panel's frame | `art/ui/sky/frame.png` | 96 x 96, corners 32: a nine-slice drawn over the panel's edge (the loose pixels are then the frame's to draw) |
| A tooltip's and a menu's frame | `art/ui/sky/tooltip_frame.png` | 48 x 48, corners 14 |
| A button | `art/ui/sky/button_normal.png`, `_hover`, `_pressed`, `_disabled`, `_focus` | 64 x 32, corners 10 |
| The main button (End Turn) | `art/ui/sky/main_button_normal.png` and the same states | 64 x 32, corners 10 |
| A tab | `art/ui/sky/tab.png`, `tab_chosen.png` | 64 x 28, corners 8 |

While a slot is empty a stand-in made in code plays (`PlaceholderSounds`), or a shape is drawn (`MapFeel`).

## What the designer said, 2026-11-16

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
