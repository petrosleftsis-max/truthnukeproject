# Putting depth on a map

To see all of this working, play Stealth Stages, stage 9, Light. The yard has a terrace, a barrel, a tree, a balcony and
a gate with an arch over it; the hall has a roof, and a door in each way in; the town below shows all round the map.
Two signs say what is what ("Depth" by the terrace, "Layers" in the middle of the yard). Below is how to do each of them yourself.

None of it changes who can see, reach or walk where. That is still the tiles' **Blocks**, as ever. Depth only draws
what the rules already say. Every picture is a placeholder until the artist's is put in its slot, and every number here
is a proposal.

## 1. Raised ground and walls: nothing to do

A tile is drawn by what its Blocks says:

| Blocks | What it is | How it is drawn |
| --- | --- | --- |
| stops a walker, not a flier, not see-through | High ground | Lifted 80 pixels, with a face under its south edge |
| stops a flier too | A wall | Lifted 160 pixels, with a face |
| see-through (water, a railing) | Neither | Flat |
| stops no walker | Floor | Flat |

Whoever stands behind something lifted is seen through it, in a patch as tall as they are drawn. In a fight, whoever
climbs up is drawn up there. A wall that can be broken stands as tall as a wall until it is broken.

A door (a StealthDoor) is as tall as the walls beside it, shut or open, and is drawn by which way its wall runs:

| The door is in | Shut | Open |
| --- | --- | --- |
| a wall running east to west (it faces us) | It fills its tile, its front showing all the way up, its top only a leaf thick | A leaf along the west side of its frame |
| a wall running north to south (we look along it) | A leaf seen edge on, from wall to wall, at the side its building is on | Flat against the north side of the way, its face to us, its ring at the end towards the outside |

Nothing has to be set: a door with a wall to its north and to its south is the second kind. Its building is the side with a
roof (a DepthPiece of Kind Roof) over the tile next to the door; with no roof on either side, the side not under the open
sky. Where neither tells, the leaf stands in the middle of its tile.

To paint raised ground, use the stone floor's **alternative 1** in the TileMap editor (the same picture as the floor, a
step up). In a layout typed for the LayoutPainter or the stage builder it is the letter `r`.

## 2. Say something different for one kind of tile

Open `maps/tilesets/terrain_tileset.tres`, select the tile, and look at its custom data:

| Field | What it does |
| --- | --- |
| Lift | 0: as its Blocks says. Above 0: lifted that many pixels. Below 0: never lifted. |
| Stands | A thing standing on the floor, like a barrel. Its floor stays flat, and the thing is cut out and drawn 1.3 times bigger, standing. |

## 3. Layers: a DepthPiece

Add a **DepthPiece** node on the tile you want, in the terrain scene so it shows in the map and in its fights. The
editor draws the ground it stands over as an outline, and where it will be drawn.

| Field | What it does |
| --- | --- |
| Picture | The artist's picture. Empty: a placeholder drawn in code, by Kind. |
| Kind | Arch, Roof, Balcony, Tree or Backdrop. See below for what each does besides its placeholder. |
| Size Tiles | How much ground it stands over, right and down from its tile. For a Tree: how big its crown is. |
| Layer | In Front: over everybody. Behind: under the ground, seen only where no tile is painted. |
| Height | In Front: how many pixels above the ground it is drawn. 160 rests it on the walls, 80 on raised ground. For a Tree: how tall its trunk is. |
| Moves | How far it slides against the ground as the view moves. Leave it below 0 for "as its kind does": a Tree 0.12, anything Behind 0.5, the rest stay put because they rest on walls. |
| Fades | Whether it is seen through about whoever is under it. Off: always whole. |
| Everywhere | Behind only: shown wherever no tile is painted, all round the map and however far the view goes. Size Tiles are not used, and a Picture is repeated side by side. |

What each kind is for:

- **Roof**: put it over a room's floor (not its walls), Height 160. It fades away whole while one of the party is under
  it or within two tiles, and comes back when they leave, so a room reads as indoors from outside. It darkens with the
  sky at night whatever lights the room. It goes well with an AmbientArea set to Interior over the same room
  (`docs/light_on_maps.md`), which is what makes the room Dim to the rules; the roof is only the picture.
- **Arch**: over a way that faces us, through a wall running east to west or between two gateposts, Height 160. Its top
  joins the walls' tops and its front shows over the way. Whoever walks under it is seen through it. Do not put one
  over a way through a wall running north to south: only its top shows there, and it reads as a lid or a shut door.
  Leave such a way open, or put a real door in it (a StealthDoor).
- **Balcony**: a floor jutting from a wall, at whatever Height. Nobody can stand on it; it is only to look at.
- **Tree**: put the node where the trunk stands, ideally on a tile nobody can walk on (raised ground makes a planter:
  the trunk starts on top of it). The crown is Size Tiles big and its trunk leans a little as the view moves.
- **Backdrop**: set Layer to Behind, and tick Everywhere for one that shows all round the map with no end: roofs far
  below, a sky, the sea. It shows wherever no tile is painted and lags after the view, which makes it read as far away.
  Without Everywhere it shows only inside its Size Tiles, for a pit or a window onto something. Keep it after the
  TileMap in the scene tree (where a new node goes anyway), and remember that it shows in every unpainted gap, the rock
  between rooms included.

Whoever the player can see under a piece In Front is seen through it in a round patch, the same as behind a wall. A
thing to be found (a sparkle) shows through a tree, an arch or a balcony, but not through a roof: a roof hides the
indoors until somebody comes near.

## 4. Sizes for the artist

A tile is 256 pixels. A person is about 330 pixels tall (the size of Cyrus's idle animation).

| Slot | Where | Size |
| --- | --- | --- |
| A face under raised ground | `art/terrain/depth/face_<column>_<row>.png` for one kind of tile, `face.png` for the rest | 256 x 80 |
| A wall's face | `art/terrain/depth/wall_face.png` | 256 x 160 |
| A tile's top, in place of its own picture | `art/terrain/depth/top_<column>_<row>.png` | 256 x 256 |
| A thing that Stands, alone | `art/terrain/depth/object_<column>_<row>.png` | Any; a barrel about 200 x 250, its foot's middle at the bottom |
| A normal map for any of those | The same name with `_n` before `.png` | The same size |
| A roof | The DepthPiece's Picture | 256 a tile, each way |
| An arch over a one-tile way | Picture | 256 x 256 for the slab; wider if it should overhang |
| A balcony | Picture | 256 a tile, each way |
| A tree's crown, seen from above | Picture | 768 x 768 for a crown three tiles across |
| A backdrop, Everywhere | Picture | Any size that repeats cleanly side by side and top to bottom, such as 1024 x 1024 |
| A backdrop seen through its Size Tiles | Picture | Its Size Tiles plus 4 tiles each way, 256 a tile; it is stretched to fit, so half that size is fine for something far and hazy |

`<column>_<row>` is the tile's place in the tileset picture, counted from 0. If the wall or raised-ground heights
change, the two face sizes change with them.

## 5. What it does not do yet

- A tree's trunk is drawn over everybody, like its crown, and seen through about whoever it covers. It does not sort
  among the figures.
- Mist, clouds' shadows and the aurora lie over the map's own ground only, not over a backdrop past it. Rain, snow and
  the rest fall everywhere.
- A roof fades by distance alone, so it also fades for somebody standing outside a shut door.
- Nothing here blocks or opens anything. If a roofed room should be dark inside, or a tree should stop a walker, that is
  an AmbientArea and the tile under the trunk.
