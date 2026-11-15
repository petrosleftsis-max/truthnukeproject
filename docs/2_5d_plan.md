# 2.5D: the plan, and where it stands

Job 1 of `docs/fable_brief.md`: A (raised ground shown), B (layers and parallax) and C (light that knows height), chosen by the
designer and their artist on 2026-11-13. View only: nothing here may change who can see, reach or walk where.

This file is kept current after every step, so another session can take over. Read "Where it stands" first.

## Where it stands

| Step | State |
| --- | --- |
| Reading, the plan told and agreed | Done, 2026-11-13 |
| "Before" screenshots | Done (in the session's scratch folder; taken again by `shot_driver.gd`, below) |
| A. Raised ground, shown | Built, approved with three changes (below) and committed, 2026-11-13 |
| C. Light that knows height | Built, approved ("i really like how things are you may proceed") and committed, 2026-11-13 |
| The sewer's channel no longer high ground (a rule; the designer: "thats fine, do the change in the sewer water") | Built and committed with B, 2026-11-14. The full pass with it found two suites whose guards were placed counting on the channel to hide the party (`alarm`, `outsidespells`): their setups were moved, their checks left as they were |
| B. Layers and parallax, with roofs | Built, liked ("i really like them all") with changes asked for, all built (below), and committed, 2026-11-14 |
| Docs (`docs/depth_on_maps.md`, the ledger, CLAUDE.md, `docs/where_we_are.md`) | Done |
| The full pass after B | 170 of 172; the two were timing under load and pass alone (Log) |
| **The designer's second round, 2026-11-14** (below) | **Built, screenshots sent, waiting for their OK; then commit and push. Read `Log` for the full pass** |

A, C and B are committed and pushed. The second round is in the working tree, not committed.

**The designer's second round, 2026-11-14** (one message; each is a ledger row):
- "Oh I didn't realise that's the arch. Then have the fog not go over the arch, tree and walls, so they can pop out more. Keep as
  is for thick fog": only a thick fog's mist rises over them now, from where the rules call the weather thick
  (`LightView.HIGH_MIST_FROM` 0.5, `Light.thick`); a thinner one and a night's low mist stay on the ground.
- "I forgot the ability is actually called might eyes, I meant his glowing eyes, revert the dark being lighter when he leads":
  `LightView.night_eyes` is back exactly as it was, and the glowing eyes are gone (`CombatantSprite._Eyes`).
- "The door is a bit misleading. It would have been perfect if it was on the north or south of a building, but looks weird when a
  closed door is facing me when it's on the left or right of a building, especially when when it's open, it looks like it
  actually blocks their way, even though it doesn't. Also the door would be the same height as the wall": a door is as tall as
  its wall shut or open, and drawn by which way its wall runs (`StealthDoor.depth_footprint`; "Doors" below). Every door on the
  stages was in a wall we look along, so the Light stage has a store off the yard with one that faces us (StoreDoor (6, 7)).
- "The hitboxes of the characters are a bit too big... Maybe a simple solution is to have a small hitbox at their feet": the box
  that stops the party at walls is 0.14 of a tile to either side of the point they stand on, 0.06 above and 0.3125 below
  (`ExplorationParty.body_corners`). That point still never leaves walkable ground, since it says which tile they are on.
- "The cutaway doesn't look right for the size of Cyrus' idle animation, will it be right when I change all the animations to that
  size?": it is an oval as tall as whoever it is about now, by each figure's own frame (`Depth.cut_shape`), so yes.
- "The two doors should start closed": they do.
- "I'd like for there to be reflections in the water and effects when the characters walk on it. Also the ripples aren't perfectly
  round, they get cut off in the middle of the body of water": rings from whoever wades, figures mirrored, the rain's rings whole
  (`LightView` "Wading, and figures mirrored in the water").
- "Can you show me an example of 256?": eight pictures sent, four views at 160 and at 256. `Depth.WALL_LIFT` is still 160.

**Doors** (`StealthDoor.depth_footprint(side_on)`, `DepthView._keep_the_uprights`). "Side on" is a wall to the door's north and to
its south: the way through goes east and west.

| | Shut | Open |
| --- | --- | --- |
| Facing us (a wall running east to west) | Fills its tile, its front showing, as before | A leaf along the west side of its frame |
| Side on (a wall we look along) | A leaf seen edge on, from wall to wall | Flat against the north side of the way, its face to us |

**Asked of the designer, not answered yet** (each is a ledger row's NextAction):
- how tall walls should be drawn, having seen 256 beside 160. Do not change `Depth.WALL_LIFT` without their word;
- whether the two kinds of door read right;
- whether the "fog" weather itself, at its thickest, should stay under walls, arch and tree too (it is what "thick" means here);
- whether the cutaway reads right now, or what looked wrong if not;
- whether the town should stay out of some unpainted gaps (the rock round the cellar);
- the new numbers by feel: the box at the feet, the wading rings and the mirror's strength.

**Do not shut the PC down at the end.** The designer first asked for it "when done", then took that back the same day
(2026-11-13): "Don't turn off my pc when you're done".

## What the designer decided along the way (2026-11-13)

- The plan as told, all of it ("These all sound great").
- **Walls are lifted, and the cutaway keeps people in view** ("I actually like cutaway, let's go with this for now"): whoever stands
  behind something lifted is seen through it in a round patch. The other ways shown (lift only what hides nobody, a silhouette
  through, a flat-view key, marks on top) are not built. The page with all five: https://claude.ai/artifact/Koogd3qhr6kQS66wVNrwDM
- **Barrels are things on the map, not raised ground** ("the barrels themselves, although climbable indeed, don't make sense to be
  lifted as they are just objects on the map... should we draw them bigger?"). Suggested and built for A's screenshots, **to be
  confirmed with them**: per tile in the TileSet, high ground is either raised ground (lifted, with a face) or a thing standing on
  the floor (its floor flat, the thing drawn bigger and standing).
- **A approved with three changes** ("Go ahead with the following changes"), all built:
  - "Sewer water: good catch, it isn't supposed to be": the channel stays flat in the drawing. **Still to ask:** whether its Blocks
    should change too, so the rules stop counting it as high ground (a rule, so theirs to say; asked 2026-11-13).
  - "A door is just a placeholder of a single colour right? It should be easy to lift when appropriate": a shut StealthDoor and a
    BreakableWall still standing are drawn as tall as a wall (`Depth.UPRIGHTS`, `DepthView._keep_the_uprights`).
  - "Could the mist and fog sometimes be higher?": thick mist rises over what is lifted (`LightView.high_mist_of`, `_high_mist`).
- **Roofs** that fade when the party walks under or close to them: "Do it if it would be a good way to show what area is indoors".
  It is; they are part of B (a DepthPiece of Kind Roof over an indoor area, fading when a party member is under it or within a few
  tiles; figures the player can see under it show through by the cutaway, so a roof hides nothing the player could see before).

## What the code had (found while reading)

- High ground is a rule already (`Combat.is_high`: a tile whose Blocks stops a walker, not a flier, and is not see-through) and it
  is on most maps: the barrels (atlas 5:2, 6:2, 5:3, 6:3) and three green tiles (3:0, 3:1, 4:1), which on the crossroads are the
  **sewer's channel**, lying low, not raised.
- Nobody was drawn higher for standing up there; only the hop arced.
- In a fight figures are in the y-sorted `Combatants` layer; on a map every figure had a fixed z near 20.
- The shade is under the figures; anything over it darkens itself from `CombatantSprite.shade_map`.
- Walls and high ground are light occluders, yet the tiles themselves are lit by the real lights (seen in the screenshots).
- LightView is invisible on a map with nothing to show, so depth is not its child.
- The art is seen from straight above: a barrel tile is floor with a barrel on it; the laboratory's wall piece (2:3, 3:3) is half
  wall and half floor.
- Headless, `LightView.shown()` is false and none of this is made.

## A, as built

| File | What |
| --- | --- |
| `combat/Depth.gd` (`Depth`) | The decisions, static, no nodes: `kind_of_blocks`, `kind_at`, `lift_at` (the TileSet's Lift), `stands_at` (its Stands), `lifts_of`, `standers_of`, `face_under`, `z_at`, `stands_behind`, `opens_a_cutaway`, `slot`. The numbers: `RAISED_LIFT` 80, `WALL_LIFT` 160, `OBJECT_SCALE` 1.3, the cutaway's (`CUT_TILES` 0.62, `CUT_ALPHA` 0.16). `walls_lifted` is the switch for walls. `TOP_STAND_INS`: the half-floor wall pieces are drawn, lifted, as the whole block. |
| `combat/DepthView.gd` (`DepthView`) | The drawing. Made beside the LightView by `Combat._begin_light` (rows into the Combatants layer) and `ExplorationScene._begin_light` (rows by absolute z), moved to be the TileMap's first child. `_Row`: one row of lifted tiles and standing things, sorted from its north edge. `RAISED_SHADER`: the shade's darkness and the cutaways. `_sort_the_figures`: z for everybody on a map, the cutaways, things lying on raised ground. `_cast_the_shadows`: the ledge shadows' mask, with the sun's lean. `_cut_out`: a barrel cut out of its tile until the artist draws one alone. `height_at`: how high whoever stands there is drawn. |
| `combat/CombatantSprite.gd` | In the group `Depth.FIGURES`; "Up on raised ground": `ground_lift`, `set_ground_lift`, `_home`; `hop(kind, seconds, to_lift)`. |
| `combat/Combat.gd` | `depth_view`; `place_sprites` sets each figure's lift from `comb.up`. |
| `control/CController.gd` | The hop's `to_lift`; the health bar goes up with them; the pointed-at tile is a cutaway (`depth_view.more_cuts`). |
| `exploration/ExplorationParty.gd` | `PARTY_Z_BOTTOM` 20 and `PARTY_Z_TOP` 620: everybody on a map is between them. The map things that sat at `PARTY_Z_TOP - n` are at `PARTY_Z_BOTTOM - n` (eleven files in `exploration/`). |
| `exploration/Interactable.gd` | In the group `Depth.THINGS`: drawn over raised ground it lies on, seen through a wall in front of it. |
| `maps/tilesets/terrain_tileset.tres` | Two new custom data layers: **Lift** (float; below 0 never lifted: the three green tiles; above 0 that many pixels) and **Stands** (bool: the four barrel tiles). Two new tiles: the stone floor's alternative 1 (3:2/1, 4:2/1) with a barrel's Blocks: **raised ground**. |
| `tools/stage_painter.gd`, `tools/build_stealth_stages.gd` | "r" paints raised ground; the Light stage's yard has a terrace (14..16, 18..19), a barrel beside it (13, 18) and a sign (SignDepth). Only `stealth_9.tscn` and `stealth_9_terrain.tscn` were brought back from the rebuild. |
| `tests/depth_test_driver.gd`, `tests/suites.txt` | Suite `depth`, 67 checks, clean. |

Slots so far (`art/terrain/depth/`): `face_<column>_<row>.png` and `face.png` (256 x 80), `wall_face.png` (256 x 160),
`top_<column>_<row>.png` (256 x 256), `object_<column>_<row>.png` (a thing alone, standing; its foot's middle goes on the tile's
foot, any size, a barrel about 200 x 250).

Known, and left for later or for the designer:
- Clouds' shadows lie on the ground, not on what is lifted.
- A shut door in a wall running north to south shows only its top (its front is behind the wall to its south), a brown square.
- A thing's cut-out has a hard edge; it is a stand-in.
- Fliers are drawn as before, not higher.

## Still to build

### C. Light that knows height: built

Found first: the real lights never reach what stands inside a wall's or a barrel's own square, so normals for them were no use.
What is lifted is lit in its own shader instead (CLAUDE.md "Light that knows height"):

- each row is three nodes (tops, faces, things standing), one shader, three materials (`kind`);
- `_tell_the_lamps`: the nearest eight of `CombatantSprite.light_points` every frame, so the light moves and breathes with them;
- `_gate_the_light`: where a lamp reaches by the rule (`LightMap.glow`; `LightMap.version` is new), so nothing is lit through a
  wall; a face asks of the floor in front of it and takes that floor's shade;
- a thing standing is lit round, on the side the lamp is;
- a slot's `_n.png` normal map makes a face face as it says (`Depth.slot`);
- `_shade_the_feet`: the floor shaded at the foot of every wall and raised edge (`FOOT_SHADE` 0.42).
- Not built, on purpose: extra shadows off ledges away from lamps. The lamps' real shadows already fall off every wall, barrel
  and terrace (they are occluders), and a second one beside it read as a mistake.

Numbers (PROPOSAL): `LAMP_GAIN` 1.6, `LAMP_HEIGHT_TILES` 0.5, `GATE_FROM` 0.04, `FOOT_SHADE` 0.42.

### B. Layers and parallax: built and committed

**The designer's changes of 2026-11-14, all built.** They took the grey arch slab over the hall's way for a door ("the door isnt on
the same tile as its drawing, and id like the option to open the door again as well"; "the effects like the fog go behind the door,
even tho they go over the walls"), found the town's edge ("doesnt show all around the map... i can still see the end of the
background") and asked for the Night Eyes view to go ("also remove the night eyes visual effect"). So:
- the two arches over the hall's ways are gone, each way has a real `StealthDoor` (HallDoor (18, 15), CellarDoor (32, 15), shut to
  begin with), and the arch is over a gate in the yard (YardGate (3, 17), between gateposts at (2, 17) and (4, 17)), drawing its
  front where that faces us (`_front_shows`);
- a door in a wall running north to south was not stood up but drawn flat on its tile (replaced the same day: "Doors" above);
- the weather is at `LightView.SKY_Z`, over the pieces (a thick fog's mist only, since the second round); mist, clouds and aurora
  are kept to the map's own ground;
- a piece Behind is drawn over the shade, kept off painted tiles by a mask, and with **Everywhere** has no end (TownBelow);
- `LightView.night_eyes` was taken out, by a misreading: put back the same day, and the glowing eyes taken out in its place.

As built (it differs from the table below, which was the plan, in three ways): a piece has a **Height** (pixels over the ground,
160 rests it on the walls; a tree's trunk); **Moves** below 0 means "as its kind does", and only a Tree (0.12) and anything Behind
(0.5) move by themselves, because a roof, an arch and a balcony rest on walls, which do not move; and a piece Behind is seen only
through the ground it stands over (its Size Tiles are a window), its picture drawn 4 tiles bigger each way so it never runs out.
The decisions are in `Depth` ("B. Layers and parallax": `piece_moves`, `piece_offset`, `roof_opens`, the groups `PARTY` and
`PIECES`, `PIECE_Z_FRONT` 620, `PIECE_Z_BEHIND` -50), the node is `exploration/DepthPiece.gd`, `LightView.open_sky_colour` is new
(a roof darkens with the sky, whatever lights the room under it), and `ExplorationParty` and `Combat.create_combatant` put the
party's figures in `Depth.PARTY`. A thing to be found under a roof is not seen through it (a roof is there to hide the indoors
until somebody comes near); under anything else it is. On the Light stage (`_light_the_stage`, `depth_piece`): RoofOverHall
(19, 8) 13 x 15, ArchToHall (18, 15), ArchToCellar (32, 15), YardTree (9, 11) on a planter of raised ground, HallBalcony
(16, 20) 2 x 3 at 120, TownBelow (0, 0) 33 x 7 Behind, and a sign, SignLayers (7, 13). The real project was imported for the new
class and icon (`.uid`, `.import`). The headless camera's middle is not kept, so the suite holds the tree still for its cutaway.

`exploration/DepthPiece.gd` (`DepthPiece`, `@tool`, an editor icon), placed on a tile; in a terrain scene it shows in the map and its
fights.

| Field | What it does |
| --- | --- |
| Picture | The artist's picture. Empty: a placeholder drawn in code by Kind. |
| Kind | Arch, Roof, Balcony, Tree, Backdrop: only what the placeholder looks like. |
| Size Tiles | How much ground it stands over, right and down from its tile. |
| Layer | In Front (over the figures) or Behind (under the ground, seen where no tile is painted). |
| Moves | How far it moves against the ground as the view moves: in front 0.12, behind 0.5 (PROPOSAL). In place when the view is centred on it. |
| Fades | In front: a cutaway about each figure the player can see under it (the designer's pick), and for a Roof the whole of it fades while one of the party is under it or within a few tiles. |

On the Light stage: an arch over the way from the yard into the hall, a tree in the yard, far roofs behind the yard's north wall,
and a roof over the hall.

Sizes for the artist: an arch over a one-tile way 768 x 512; a tree's crown 768 x 768; a balcony 256 a tile x 128; a roof 256 a
tile each way; a backdrop 2048 x 512.

### Then

The suite grows with each part; the full pass clean; CLAUDE.md section; `docs/depth_on_maps.md` ("Putting depth on a map", in the
manner of `docs/light_on_maps.md`); a ledger row for each decision (the lifts, walls lifted with the cutaway, things that stand,
the sewer kept flat, the new raised-ground tile, sorting on maps, each of the piece's numbers); `docs/where_we_are.md`.

## How the screenshots are taken

A scratch copy of the project (without `.git`, `export`, `tests` and the sound folders), with `shot_driver.gd` as its last autoload
`T` and a user folder of its own, run windowed at 1280 x 720 with `MOT_SHOT_DIR` set. The driver opens the Light stage, the
crossroads and the laboratory as maps and four fights, hides the HUD, places the party and saves the viewport. It and `shoot.sh`
are in the session's scratch folder; they are a page of code and quick to write again.

## Log

- 2026-11-13: read everything; plan told. The designer agreed, chose the cutaway with walls lifted, asked for roofs in B.
- 2026-11-13: A built. Found on the way: the lifted pieces' shader squared its colour (COLOR already holds the picture); the real
  lights do fall on tiles inside occluders, so the rows take them too; the green tiles are the sewer's channel, kept flat by the
  TileSet's new Lift; barrels made things that stand, after the designer's remark. Suite `depth` clean.
- 2026-11-13: the full pass with A in the working tree: all 172 suites clean, no script errors.
- 2026-11-13: the designer approved A with three changes (the channel flat, doors lifted, mist that rises). Built; `depth` and the
  suites that touch doors, light and weather clean (depth atmos clock light figures weather daysky aimed net outside stages
  stealthworld). CLAUDE.md has a Depth section and the ledger ten rows. A committed and pushed.
- 2026-11-13: C built. Suite `depth` clean with its checks; a full pass started; screenshots sent. Waiting for the designer's OK.
- 2026-11-13: the designer asked "Does the cutaway work for creatures that are bigger than human". It did not quite: it was about
  their top-left tile. Now about the middle of what they cover (`DepthView.body_middle`, `_covered`), and somebody big is drawn
  over barrels and raised ground among their own feet (`_keep_the_big_over`). Checked in `depth` (93 checks, clean).
- 2026-11-13: the designer approved C and the sewer's rules change. Their power went out and cut the full pass off (clean as far
  as it had got). C committed and pushed.
- 2026-11-13: the sewer's channel made water to the rules (Blocks see-through). A full pass started with it.
- 2026-11-13: B built: `DepthPiece`, the Light stage's pieces, `depth` grown to 135 checks, clean. The designer, meanwhile: "the
  real size of the human size creatures will be the size of the idle animation of cyrus" (384 x 384 a frame, the figure about
  330 pixels tall, 1.3 tiles). Screenshots sent with two of the walls at 160 and at 256 beside a person. Waiting for their OK.
- 2026-11-14: the full pass with C and the sewer change: 170 of 172 clean; `alarm` and `outsidespells` each failed one check, both
  on the crossroads, both from guards now seeing across the channel (they pass with the old tiles). Their setups were moved: one
  guard turned his back, two were placed out of sight of the first's post.
- 2026-11-14: the designer liked B and asked for the changes listed under B above; all built. `depth` 146 checks, clean, with
  `daysky atmos weather clock light figures stages stealthworld alarm outsidespells guardlife`. B and the sewer change committed
  and pushed. The last full pass started.
- 2026-11-14: the full pass after B: 170 of 172. `spacebar` ("space works again") and `depth` ("nothing is cut away with nobody
  under it") each failed one check under the pass's load and pass alone and together; `depth`'s waits were given frames to
  settle, and `cuts_now` a copy of its own (it had been handing out the shader's padded list).
- 2026-11-14 and 15: the designer's second round (above), all built. `depth atmos walk clock figures` clean (178, and the new
  checks in each). Fifteen screenshots sent. The full pass with it: see the next line; if there is none, it is still to be read.
- 2026-11-15: the full pass with the second round: 170 of 172, the same two checks as after B. `spacebar` was the test's own: a
  press before its menu checks ended a turn for real and the fight went on to an enemy's, so the last press was rightly refused
  ("their turn false"). It now makes it the hero's turn before those checks (`make_it_their_turn`), and is clean. `depth`'s check
  ("nothing is cut away with nobody under it") now says whom each cut is about; under load, and after the nine suites that come
  before it in a pass, it was clean all three times, so its cause is not found yet. Fable's limit ran out here, and a Claude Code
  session on Opus 5.5 took over: a new full pass started. Its result: see the next line.
